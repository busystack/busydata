package io.busystack.busydata.administration;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.sessions.SessionRegistry;

/** Missing instrumentation, denied access and empty statistics are distinct. */
public final class DiagnosticTools {
 private DiagnosticTools(){}
 public static String sql(SessionRegistry.Session session,ToolRequest request)throws Exception {
  if(request.getKind()!=ToolKind.QUERY_STATISTICS && request.getKind()!=ToolKind.INDEX_DIAGNOSTICS)return session.adapter.toolSql(request);
  return session.metadata(view->sqlOnConnection(view,request));
 }
 /** Fixed inspection on an already owned independent metadata connection. */
 public static String sqlOnConnection(SessionRegistry.Session view,ToolRequest request)throws Exception {
   if(view.profile.getEngine()==Engine.POSTGRESQL && request.getKind()==ToolKind.QUERY_STATISTICS) {
    String schema;
    try(var statement=view.connection.createStatement()){statement.setQueryTimeout(5);try(var rows=statement.executeQuery("SELECT n.nspname FROM pg_extension e JOIN pg_namespace n ON n.oid=e.extnamespace WHERE e.extname='pg_stat_statements'")){if(!rows.next())throw new UnsupportedOperationException("Query statistics unavailable: pg_stat_statements is not installed in this database. Review extension/preload configuration with a database administrator; BusyData does not install it automatically.");schema=rows.getString(1);}}
    return view.adapter.toolSql(request).replace("FROM pg_stat_statements", "FROM "+view.adapter.table("",schema,"pg_stat_statements"));
   }
   if(view.profile.getEngine()!=Engine.POSTGRESQL)try(var statement=view.connection.createStatement()){statement.setQueryTimeout(5);try(var rows=statement.executeQuery("SELECT @@performance_schema")){if(!rows.next()||!rows.getBoolean(1))throw new UnsupportedOperationException("Query/index instrumentation unavailable: Performance Schema is disabled. Its configuration may require a reviewed server restart; empty data is not treated as evidence of absent workload.");}}
   return view.adapter.toolSql(request);
 }
}
