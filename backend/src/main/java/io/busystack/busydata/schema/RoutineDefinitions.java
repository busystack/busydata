package io.busystack.busydata.schema;

import com.google.gson.*;
import io.busystack.busydata.metadata.MetadataState;
import io.busystack.busydata.metadata.NativeRoutineSource;
import io.busystack.busydata.protocol.Engine;
import io.busystack.busydata.sessions.SessionRegistry;
import java.sql.*;
import java.util.*;
import java.util.concurrent.*;

final class RoutineDefinitions {
    private static final ExecutorService cancellation=Executors.newVirtualThreadPerTaskExecutor();
    static JsonObject capture(SessionRegistry.Session session,String schema,SnapshotBudget working)throws SQLException {
        var definitions=new TreeMap<String,JsonObject>();boolean postgres=session.profile.getEngine()==Engine.POSTGRESQL;long bytes=0,deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(30);
        check(deadline);
        String preflight=postgres?"SELECT COUNT(*),COALESCE(SUM(OCTET_LENGTH(pg_get_functiondef(p.oid))),0) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname=? AND p.prokind IN ('f','p')":"SELECT COUNT(*),COALESCE(SUM(OCTET_LENGTH(ROUTINE_DEFINITION)),0) FROM information_schema.ROUTINES WHERE BINARY ROUTINE_SCHEMA=BINARY ?";
        try(var statement=session.adapter.catalogStatement(session.connection,preflight)){statement.setString(1,schema);try(var rows=statement.executeQuery()){if(!rows.next())throw new SQLException("Routine resource inspection unavailable");if(rows.getLong(1)>1000||rows.getLong(2)>6_291_456)throw new IllegalArgumentException("Routine definitions exceed the schema snapshot count/byte budget");}}
        String sql=postgres?"SELECT p.proname,pg_get_function_identity_arguments(p.oid),p.prokind::text,pg_get_functiondef(p.oid),pg_get_function_result(p.oid) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname=? AND p.prokind IN ('f','p') ORDER BY p.proname,pg_get_function_identity_arguments(p.oid)":"SELECT ROUTINE_NAME,'',ROUTINE_TYPE,NULL,DTD_IDENTIFIER FROM information_schema.ROUTINES WHERE BINARY ROUTINE_SCHEMA=BINARY ? ORDER BY BINARY ROUTINE_NAME,BINARY ROUTINE_TYPE";
        try(var statement=session.adapter.catalogStatement(session.connection,sql)){statement.setString(1,schema);statement.setQueryTimeout(10);statement.setFetchSize(1);try(var rows=statement.executeQuery()){while(rows.next()) {
            check(deadline);
            if(definitions.size()>=1000)throw new IllegalArgumentException("Routine snapshot limit is 1000");
            String name=working.retain(rows.getString(1)),arguments=working.retain(rows.getString(2)),kind=working.retain(rows.getString(3)),definition=rows.getString(4);
            if(!postgres)definition=nativeDefinition(session,schema,name,kind,deadline);
            working.retain(definition);
            if(definition!=null){bytes+=definition.length()*3L;if(bytes>8_388_608)throw new IllegalArgumentException("Routine definition snapshot byte budget exceeded");}
            var entry=new JsonObject();
            if(definition!=null)try{definition=DefinitionBinding.qualifyRoutine(session,schema,name,definition);}catch(IllegalArgumentException unsupported){entry.addProperty("bindingUnavailable","Native routine identity could not be verified; retain the definition and review it separately");}
            entry.addProperty("name",name);entry.addProperty("arguments",arguments);entry.addProperty("kind",kind);entry.addProperty("definition",definition);entry.addProperty("returnType",working.retain(rows.getString(5)));entry.add("access",RoutineAccess.capture(session,schema,name,arguments,kind,working));
            check(deadline);
            definitions.put(postgres?name+"("+arguments+")":kind+":"+name,entry);
        }}}
        check(deadline);var result=new JsonObject();definitions.forEach(result::add);return result;
    }
    /** Uses the shared bounded source decoder while preserving the caller's
     * physical-session ownership and the existing larger artifact budget. */
    private static String nativeDefinition(SessionRegistry.Session session,String schema,String name,String kind,long deadline)throws SQLException {
        if(!Set.of("FUNCTION","PROCEDURE").contains(kind))throw new SQLException("Native routine kind is unavailable","55000");
        check(deadline);
        try(var query=session.adapter.catalogStatement(session.connection,"SHOW CREATE "+kind+" "+session.adapter.table("",schema,name))){
            query.setMaxRows(2);query.setQueryTimeout((int)Math.min(10,Math.max(1,TimeUnit.NANOSECONDS.toSeconds(deadline-System.nanoTime())+1)));
            var context=io.grpc.Context.current();io.grpc.Context.CancellationListener listener=ignored->{try{query.cancel();}catch(SQLException ignoredFailure){}};
            context.addListener(listener,cancellation);
            try(var rows=query.executeQuery()){
                check(deadline);if(!rows.next())throw new SQLException("Native routine source is unavailable","55000");
                if(!name.equals(rows.getString(1)))throw new SQLException("Native routine source identity changed","55000");
                var source=NativeRoutineSource.readDefinitionField(session,query,rows,3,NativeRoutineSource.MAX_ARTIFACT_BYTES,deadline);
                if(source.text()!=null&&source.state()!=MetadataState.AVAILABLE)throw new IllegalArgumentException("Routine definition exceeds or cannot establish the schema snapshot byte budget");
                if(rows.next())throw new SQLException("Native routine source identity is ambiguous","55000");
                NativeRoutineSource.checkWarnings(session.profile.getEngine(),query,session.connection,rows,kind.equals("FUNCTION"));
                return source.text();
            }finally{context.removeListener(listener);}
        }
    }
    private static void check(long deadline)throws SQLTimeoutException {
        if(io.grpc.Context.current().isCancelled()||Thread.currentThread().isInterrupted())throw new CancellationException("Routine schema capture cancelled");
        if(System.nanoTime()>deadline)throw new SQLTimeoutException("Routine schema capture deadline exceeded");
    }
    static String script(String sql,boolean postgres) {
        if(postgres)return sql+";";
        String marker="_bd_end_";int sequence=0;while(sql.contains(marker)){marker="_bd"+(++sequence)+"_";if(marker.length()>16)throw new IllegalArgumentException("Cannot choose a procedural delimiter");}
        return "DELIMITER "+marker+"\n"+sql+marker+"\nDELIMITER ;\n";
    }
}
