package io.busystack.busydata.administration;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.sessions.SessionRegistry;
import java.sql.*;
import java.util.concurrent.CancellationException;
import java.util.function.BooleanSupplier;

/** Explicit bounded inspection, without touching the console transaction. */
public final class Capabilities {
    private Capabilities(){}
    public static CapabilityList inspect(SessionRegistry.Session session,CapabilityRequest request,BooleanSupplier cancelled)throws Exception {
        verify(session,request);
        check(cancelled);
        var result=session.metadata(view->{
            var metadata=view.connection.getMetaData();
            int major=metadata.getDatabaseMajorVersion(),minor=metadata.getDatabaseMinorVersion();
            var reply=CapabilityList.newBuilder().setBackendInstance(request.getContext().getInstanceId()).setSessionId(session.id)
                .setContextRevision(request.getContextRevision()).setSessionRevision(request.getSessionRevision())
                .setProduct(bounded(metadata.getDatabaseProductName(),128)).setVersion(bounded(metadata.getDatabaseProductVersion(),512))
                .setMajorVersion(Math.max(0,major)).setMinorVersion(Math.max(0,minor))
                .setAvailability("Explicit independent read probes; object privileges and modifying actions remain subject to server enforcement and fresh review. Temporary/session-local objects are inspected through their owning console.");
            boolean pg=session.profile.getEngine()==Engine.POSTGRESQL;
            add(reply,"transactions","Transactions",metadata.supportsTransactions()?CapabilityState.CAPABILITY_AVAILABLE:CapabilityState.CAPABILITY_UNSUPPORTED,
                "JDBC reports transaction support. DDL and execution-backed plans retain the engine's actual commit behavior.");
            add(reply,"metadata","Schema navigation",CapabilityState.CAPABILITY_LIMITED,"Visible catalogs only; missing object privileges and session-local visibility are checked by the selected operation.");
            probe(reply,view,"plans","Estimated execution plans",view.adapter.toolSql(ToolRequest.newBuilder().setKind(ToolKind.EXPLAIN).setSql("SELECT 1").build()),cancelled);
            boolean actuals=pg?major>=9:session.profile.getEngine()==Engine.MARIADB?major>10||major==10&&minor>=1:major>8||major==8&&(minor>0||patch(metadata.getDatabaseProductVersion())>=18);
            add(reply,"actual-plans","Execution-backed plans",actuals?CapabilityState.CAPABILITY_LIMITED:CapabilityState.CAPABILITY_UNSUPPORTED,
                actuals?"Supported server syntax; executes the reviewed SQL. Available measurements and privileges depend on the target statement.":"This server version predates the adapter's execution-backed plan syntax.");
            probe(reply,view,"activities","Sessions and activity",pg?"SELECT pid FROM pg_stat_activity LIMIT 1":"SELECT ID FROM information_schema.PROCESSLIST LIMIT 1",cancelled);
            if(pg) {
                check(cancelled);
                try(var statement=view.connection.createStatement()) {
                    statement.setQueryTimeout(5);
                    try(var rows=statement.executeQuery("SELECT r.rolsuper OR pg_has_role(current_user,'pg_read_all_stats','USAGE') FROM pg_roles r WHERE r.rolname=current_user")) {
                        if(rows.next()&&!rows.getBoolean(1))limit(reply,"activities","Other users' session details can be masked; own-session visibility does not imply permission to cancel or terminate another principal.");
                    }
                }
            }
            probe(reply,view,"locks","Lock inspection",pg?"SELECT pid FROM pg_locks LIMIT 1":session.profile.getEngine()==Engine.MYSQL?"SELECT REQUESTING_ENGINE_TRANSACTION_ID FROM performance_schema.data_lock_waits LIMIT 1":"SELECT requesting_trx_id FROM information_schema.INNODB_LOCK_WAITS LIMIT 1",cancelled);
            diagnostic(reply,view,"query-statistics","Query statistics",ToolKind.QUERY_STATISTICS,cancelled);
            diagnostic(reply,view,"index-diagnostics","Index diagnostics",ToolKind.INDEX_DIAGNOSTICS,cancelled);
            probe(reply,view,"principals","Users and roles inspection",pg?"SELECT rolname FROM pg_roles LIMIT 1":"SELECT User,Host FROM mysql.user LIMIT 1",cancelled);
            add(reply,"grants","Grants and inherited roles",CapabilityState.CAPABILITY_LIMITED,"Read-first inspection exposes visible direct grants and supported inheritance paths; effective permissions and changes are evaluated per exact principal and object.");
            add(reply,"editing","Staged row editing",session.profile.getReadOnly()?CapabilityState.CAPABILITY_DISABLED:CapabilityState.CAPABILITY_LIMITED,
                session.profile.getReadOnly()?"The read-only profile rejects modifying operations.":"Requires verified direct-table provenance, a complete unique row identity, optimistic checks and reviewed parameterized changes.");
            add(reply,"schema-changes","Object design and migration",session.profile.getReadOnly()?CapabilityState.CAPABILITY_DISABLED:CapabilityState.CAPABILITY_LIMITED,
                session.profile.getReadOnly()?"The read-only profile permits inspection, but rejects DDL application.":"Supported properties produce reviewed DDL. Dependencies, unsupported differences, object privileges and implicit commits remain explicit.");
            add(reply,"transfers","Import and export",session.profile.getReadOnly()?CapabilityState.CAPABILITY_LIMITED:CapabilityState.CAPABILITY_AVAILABLE,
                session.profile.getReadOnly()?"Retained/direct read exports are available; imports are disabled by the profile.":"Exports and imports use bounded reviewed jobs; source, target, conversion and commit policies are checked per operation.");
            check(cancelled);verify(session,request);
            if(reply.getEntriesCount()>16||reply.build().getSerializedSize()>32768)throw new IllegalStateException("Capability inspection budget exceeded");
            return reply.build();
        });
        verify(session,request);return result;
    }
    private static void verify(SessionRegistry.Session session,CapabilityRequest request) {
        if(!session.id.equals(request.getSessionId())||session.contextRevision!=request.getContextRevision()||session.revision!=request.getSessionRevision())throw new IllegalStateException("Capability execution context changed; refresh session status and inspect again");
        if(session.state==TransactionState.UNKNOWN_TRANSACTION||session.state==TransactionState.DISCONNECTED)throw new IllegalStateException("Disconnect the uncertain session before opening another console; no capability SQL was submitted");
    }
    private static void diagnostic(CapabilityList.Builder reply,SessionRegistry.Session view,String id,String label,ToolKind kind,BooleanSupplier cancelled)throws Exception {
        check(cancelled);
        try {
            String sql=DiagnosticTools.sqlOnConnection(view,ToolRequest.newBuilder().setKind(kind).build());
            sql=sql.endsWith("LIMIT 500")?sql.substring(0,sql.length()-9)+"LIMIT 1":sql+" LIMIT 1";
            probe(reply,view,id,label,sql,cancelled);
        }catch(UnsupportedOperationException unavailable){add(reply,id,label,CapabilityState.CAPABILITY_UNAVAILABLE,
            kind==ToolKind.QUERY_STATISTICS?"Required query instrumentation is not installed/enabled; this is not empty workload data.":"Performance Schema instrumentation is disabled; this is not empty workload data.");}
        catch(SQLException failure){sqlFailure(reply,id,label,failure);}
    }
    private static void probe(CapabilityList.Builder reply,SessionRegistry.Session view,String id,String label,String sql,BooleanSupplier cancelled)throws Exception {
        check(cancelled);
        try(var statement=view.connection.createStatement()) {
            statement.setQueryTimeout(5);statement.setMaxRows(1);
            try(var rows=statement.executeQuery(sql)) {
                boolean empty=!rows.next();
                reply.addEntries(Capability.newBuilder().setId(id).setLabel(label).setState(CapabilityState.CAPABILITY_AVAILABLE)
                    .setDetail(empty?"Read probe succeeded; no visible records are currently collected.":"Read probe succeeded; visible records exist. No row values are retained in this inspector.").setDataChecked(true).setEmpty(empty));
            }
        }catch(SQLException failure){sqlFailure(reply,id,label,failure);}
        check(cancelled);
    }
    private static void sqlFailure(CapabilityList.Builder reply,String id,String label,SQLException failure)throws SQLException {
        String state=failure.getSQLState()==null?"":failure.getSQLState();
        if(state.startsWith("08"))throw failure;
        boolean denied=state.equals("42501")||state.startsWith("28")||failure.getErrorCode()==1142||failure.getErrorCode()==1143||failure.getErrorCode()==1227||failure.getErrorCode()==1044;
        boolean missing=state.equals("42P01")||state.equals("42S02")||state.equals("42703")||failure.getErrorCode()==1054||failure.getErrorCode()==1109;
        add(reply,id,label,denied?CapabilityState.CAPABILITY_DENIED:missing?CapabilityState.CAPABILITY_UNSUPPORTED:CapabilityState.CAPABILITY_UNAVAILABLE,
            (denied?"The selected principal lacks this inspection permission":missing?"This server lacks the adapter's required catalog or column":"The inspection is unavailable; review server instrumentation/configuration")+" (SQLSTATE "+state+").");
    }
    private static void add(CapabilityList.Builder reply,String id,String label,CapabilityState state,String detail){reply.addEntries(Capability.newBuilder().setId(id).setLabel(label).setState(state).setDetail(detail));}
    private static void limit(CapabilityList.Builder reply,String id,String detail){for(int i=0;i<reply.getEntriesCount();i++)if(reply.getEntries(i).getId().equals(id)){reply.setEntries(i,reply.getEntries(i).toBuilder().setState(CapabilityState.CAPABILITY_LIMITED).setDetail(detail));return;}}
    private static void check(BooleanSupplier cancelled){if(cancelled.getAsBoolean())throw new CancellationException("Capability inspection cancelled");}
    private static String bounded(String value,int limit){return value==null?"":value.substring(0,Math.min(value.length(),limit));}
    private static int patch(String version){var match=java.util.regex.Pattern.compile("^8\\.0\\.(\\d{1,4})(?:\\D|$)").matcher(version);return match.find()?Integer.parseInt(match.group(1)):0;}
}
