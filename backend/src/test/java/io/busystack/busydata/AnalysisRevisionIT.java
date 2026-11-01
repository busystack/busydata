package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.rpc.WorkbenchService;
import io.grpc.Status;
import io.grpc.stub.StreamObserver;
import java.nio.file.Path;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

/** Actual RPC implementation, catalogs, and physical sessions; no mock adapter. */
class AnalysisRevisionIT {
    private static void warm(WorkbenchService service,io.busystack.busydata.sessions.SessionRegistry.Session session,Context context,String... namespaces){
        var read=new Reply<MetadataSettingsReply>();service.metadataSettings(MetadataSettingsRequest.newBuilder().setContext(context).setSessionId(session.id).setSessionRevision(session.revision).setContextRevision(session.contextRevision).build(),read);assertNull(read.error);
        long configuration=read.value.getConfigurationRevision();
        if(namespaces.length>0){
            var settings=read.value.getConfiguration().toBuilder();
            if(session.profile.getEngine()==Engine.POSTGRESQL)settings.clearIncludedSchemas().addAllIncludedSchemas(java.util.List.of(namespaces));else settings.clearIncludedCatalogs().addAllIncludedCatalogs(java.util.List.of(namespaces));
            var saved=new Reply<MetadataSettingsReply>();service.metadataSettings(MetadataSettingsRequest.newBuilder().setContext(context).setSessionId(session.id).setSessionRevision(session.revision).setContextRevision(session.contextRevision).setExpectedConfigurationRevision(configuration).setAction(MetadataSettingsAction.SAVE_METADATA_SETTINGS).setConfiguration(settings).build(),saved);assertNull(saved.error);configuration=saved.value.getConfigurationRevision();
        }
        var refreshed=new Reply<MetadataSettingsReply>();service.metadataSettings(MetadataSettingsRequest.newBuilder().setContext(context).setSessionId(session.id).setSessionRevision(session.revision).setContextRevision(session.contextRevision).setExpectedConfigurationRevision(configuration).setAction(MetadataSettingsAction.FULL_METADATA_REFRESH).build(),refreshed);assertNull(refreshed.error,()->String.valueOf(refreshed.error));
    }
    private static Analysis awaitCompletion(WorkbenchService service,io.busystack.busydata.sessions.SessionRegistry.Session session,AnalysisRequest request,String label)throws Exception {
        assertEquals(0,request.getMetadataSnapshotRevision(),"Each independent analysis read captures its own immutable metadata snapshot");
        long deadline=System.nanoTime()+java.util.concurrent.TimeUnit.SECONDS.toNanos(20);String last="No analysis response";
        while(System.nanoTime()<deadline){
            assertEquals(session.id,request.getSessionId());assertEquals(session.revision,request.getSessionRevision());assertEquals(session.contextRevision,request.getContextRevision());
            var reply=new Reply<Analysis>();dispatch(service,request,reply);
            if(reply.error!=null){
                // A background publication during this pure cached analysis must
                // reject its stale reply. Request a new read without upgrading
                // the original physical-session or context revision.
                assertEquals(Status.Code.FAILED_PRECONDITION,Status.fromThrowable(reply.error).getCode());
                var trailers=Status.trailersFromThrowable(reply.error);assertNotNull(trailers);
                var key=io.grpc.Metadata.Key.of(io.busystack.busydata.rpc.WorkbenchFailure.TRAILER,io.grpc.Metadata.ASCII_STRING_MARSHALLER);
                assertEquals(io.busystack.busydata.rpc.WorkbenchFailure.Reason.INVALID_REVISION.wire(),trailers.get(key));
                assertEquals(session.revision,request.getSessionRevision());assertEquals(session.contextRevision,request.getContextRevision());
                last="Rejected stale captured metadata revision";
            }else{
                last="availability="+reply.value.getAvailability()+", snapshot="+reply.value.getMetadataSnapshotRevision()+", diagnostics="+reply.value.getDiagnosticsList().stream().map(Diagnostic::getCode).toList();
                if(reply.value.getCompletionsList().stream().anyMatch(c->c.getLabel().equals(label)))return reply.value;
            }
            Thread.sleep(20);
        }
        fail("Acknowledged metadata refresh never published the expected column: "+last);return null;
    }
    private static void dispatch(io.busystack.busydata.rpc.WorkbenchService service,AnalysisRequest request,io.grpc.stub.StreamObserver<Analysis> out){
        if(request.getOperation()==AnalysisOperation.SYMBOL_RESOLUTION)service.resolveSqlSymbol(request,out);else service.completeSql(request,out);
    }
    @TempDir Path root;
    private static final class Reply<T> implements StreamObserver<T> {
        T value;Throwable error;boolean completed;
        public void onNext(T value){this.value=value;}
        public void onError(Throwable error){this.error=error;}
        public void onCompleted(){completed=true;}
    }
    private static Object invoke(Object target,java.lang.reflect.Method method,Object[] arguments)throws Throwable {
        try{return method.invoke(target,arguments);}catch(java.lang.reflect.InvocationTargetException failure){throw failure.getCause();}
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void staleTreeContinuationHasAnExplicitRestartStatus(String engine)throws Exception {
        try(var fixture=new EngineFixture(root,engine)) {
            var session=fixture.open();fixture.execute(session,"CREATE TABLE restart_a(id integer); CREATE TABLE restart_b(id integer)");
            var service=new WorkbenchService(fixture.sessions,fixture.jobs,fixture.results,fixture.metadata,fixture.safety,fixture.analysis,()->{});
            var context=Context.newBuilder().setProtocolVersion(WorkbenchService.PROTOCOL).setInstanceId(service.instance).setRequestId("tree-restart").build();
            var request=ExploreRequest.newBuilder().setContext(context).setSessionId(session.id).setKind(ObjectKind.TABLE).setCatalog("busydata").setSchema(fixture.schema()).setLimit(1).build();
            var first=new Reply<SchemaObjects>();service.explore(request,first);assertNull(first.error);assertFalse(first.value.getComplete());
            var stale=new Reply<SchemaObjects>();service.explore(request.toBuilder().setContinuation(first.value.getContinuation()).setSchema("another_scope").build(),stale);
            assertNull(stale.value);assertFalse(stale.completed);
            var error=(io.grpc.StatusRuntimeException)stale.error;
            assertEquals(Status.Code.FAILED_PRECONDITION,error.getStatus().getCode());
            assertEquals("restart-enumeration",error.getTrailers().get(io.grpc.Metadata.Key.of("busydata-metadata-reason",io.grpc.Metadata.ASCII_STRING_MARSHALLER)));
            var retry=new Reply<SchemaObjects>();service.explore(request.toBuilder().setRefresh(true).build(),retry);
            assertNull(retry.error);assertEquals("restart_a",retry.value.getObjects(0).getName());assertEquals(TransactionState.IDLE,session.state);
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void explicitSymbolResolutionKeepsNativeScopeAndNeverScansUnrelatedSchemas(String engine)throws Exception {
        try(var fixture=new EngineFixture(root,engine)) {
            var session=fixture.open();fixture.execute(session,"CREATE TABLE customers(id integer); CREATE VIEW customer_view AS SELECT id FROM customers");
            if(fixture.engine==Engine.POSTGRESQL)fixture.execute(session,"CREATE SCHEMA audit; CREATE TABLE audit.customers(other integer); CREATE DATABASE second_database");
            else fixture.execute(session,"CREATE DATABASE audit; CREATE TABLE audit.customers(other integer)");
            var service=new WorkbenchService(fixture.sessions,fixture.jobs,fixture.results,fixture.metadata,fixture.safety,fixture.analysis,()->{});
            var context=Context.newBuilder().setProtocolVersion(WorkbenchService.PROTOCOL).setInstanceId(service.instance).setRequestId("symbol-reference").build();
            warm(service,session,context,fixture.schema(),"audit");
            String sql="SELECT * FROM audit.customers";
            var request=AnalysisRequest.newBuilder().setContext(context).setDocumentId("symbol-document").setDocumentVersion(9).setSql(sql)
                .setCaretUtf16(sql.indexOf("customers")+3).setSessionId(session.id).setEngine(fixture.engine).setContextRevision(session.contextRevision).setSessionRevision(session.revision).setOperation(AnalysisOperation.SYMBOL_RESOLUTION).build();
            var reply=new Reply<Analysis>();dispatch(service,request,reply);assertNull(reply.error);assertTrue(reply.completed);
            var symbol=reply.value.getSymbol();assertTrue(symbol.getComplete());assertEquals(1,symbol.getCandidatesCount());assertEquals(fixture.profile.getId(),symbol.getProfileId());
            var target=symbol.getCandidates(0);assertEquals("audit",target.getSchema());assertEquals(fixture.engine==Engine.POSTGRESQL?"busydata":"audit",target.getCatalog());assertEquals("customers",target.getName());
            assertEquals("busydata",session.connection.getCatalog());assertEquals(TransactionState.IDLE,session.state);assertEquals(1,fixture.sessions.size());
            assertTrue(reply.value.getCompletionsList().isEmpty());assertTrue(target.getPropertiesMap().isEmpty());assertTrue(target.getDefinition().isEmpty());
            String statements="SELECT c.id FROM "+fixture.schema()+".customers c; SELECT c.other FROM audit.customers c";
            for(boolean first:new boolean[]{true,false}) {
                int caret=first?statements.indexOf("c.id")+1:statements.indexOf("c.other")+1;
                var separate=new Reply<Analysis>();dispatch(service,request.toBuilder().setSql(statements).setCaretUtf16(caret).build(),separate);
                assertNull(separate.error);assertEquals(first?fixture.schema():"audit",separate.value.getSymbol().getCandidates(0).getSchema());
                assertTrue(separate.value.getSymbol().getSpan().getStartUtf16()<=caret);assertTrue(separate.value.getSymbol().getSpan().getEndUtf16()>=caret);
            }
            String changedContext=(fixture.engine==Engine.POSTGRESQL?"SET search_path=audit":"USE audit")+"; SELECT * FROM customers";
            var contextChoice=new Reply<Analysis>();dispatch(service,request.toBuilder().setSql(changedContext).setCaretUtf16(changedContext.length()-2).build(),contextChoice);
            assertNull(contextChoice.error);assertEquals("ambiguous",contextChoice.value.getSymbol().getAvailability());assertTrue(contextChoice.value.getSymbol().getCandidatesList().isEmpty());
            String viewSql="SELECT * FROM "+fixture.schema()+".customer_view";
            var view=new Reply<Analysis>();dispatch(service,request.toBuilder().setSql(viewSql).setCaretUtf16(viewSql.length()-2).build(),view);
            assertNull(view.error);assertEquals(ObjectKind.VIEW,view.value.getSymbol().getCandidates(0).getKind());
            for(String text:java.util.List.of("SELECT 'audit.customers'", "SELECT 1 /* audit.customers */")) {
                var literal=new Reply<Analysis>();dispatch(service,request.toBuilder().setSql(text).setCaretUtf16(text.indexOf("customers")+3).build(),literal);
                assertNull(literal.error);assertTrue(literal.value.getSymbol().getCandidatesList().isEmpty());
            }
            var stale=new Reply<Analysis>();dispatch(service,request.toBuilder().setSessionRevision(session.revision+1).build(),stale);
            assertNotNull(stale.error);assertNull(stale.value);
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void acknowledgedDdlInvalidatesAnalysisBeforeTheRemainingScriptFinishes(String engine)throws Exception {
        var reached=new java.util.concurrent.CountDownLatch(1);var release=new java.util.concurrent.CountDownLatch(1);
        try(var fixture=new EngineFixture(root,engine,(adapter,request,port)->{
            var physical=adapter.connect(request,port);
            return (java.sql.Connection)java.lang.reflect.Proxy.newProxyInstance(java.sql.Connection.class.getClassLoader(),new Class[]{java.sql.Connection.class},(proxy,method,args)->{
                Object answer=invoke(physical,method,args);if(!method.getName().equals("createStatement"))return answer;
                var statement=(java.sql.Statement)answer;
                return java.lang.reflect.Proxy.newProxyInstance(java.sql.Statement.class.getClassLoader(),new Class[]{java.sql.Statement.class},(p,m,a)->{
                    if(m.getName().equals("execute")&&a!=null&&a.length>0&&a[0] instanceof String sql&&sql.contains("analysis gate")){
                        reached.countDown();if(!release.await(20,java.util.concurrent.TimeUnit.SECONDS))throw new java.sql.SQLException("Fixture gate deadline");
                    }
                    return invoke(statement,m,a);
                });
            });
        })) {
            var session=fixture.open();fixture.execute(session,"CREATE TABLE analysis_gate(id INTEGER PRIMARY KEY)");
            var service=new WorkbenchService(fixture.sessions,fixture.jobs,fixture.results,fixture.metadata,fixture.safety,fixture.analysis,()->{});
            var context=Context.newBuilder().setProtocolVersion(WorkbenchService.PROTOCOL).setInstanceId(service.instance).setRequestId("inflight-analysis").build();
            warm(service,session,context);
            String sql="SELECT a. FROM analysis_gate a";
            var request=AnalysisRequest.newBuilder().setContext(context).setDocumentId("exact-document").setDocumentVersion(7).setSql(sql)
                .setCaretUtf16(sql.indexOf(". ")+1).setSessionId(session.id).setEngine(fixture.engine).setContextRevision(session.contextRevision).setSessionRevision(session.revision).build();
            var initial=new Reply<Analysis>();dispatch(service,request,initial);assertNull(initial.error);
            // The PostgreSQL raw executor intentionally bypasses Statement.execute. Gate on
            // an observed native server wait rather than a JDBC proxy that it never calls.
            // https://www.postgresql.org/docs/17/functions-admin.html#FUNCTIONS-ADVISORY-LOCKS
            // https://www.postgresql.org/docs/17/monitoring-stats.html#MONITORING-PG-STAT-ACTIVITY-VIEW
            boolean postgres=fixture.engine==Engine.POSTGRESQL;
            try(var gate=postgres?java.sql.DriverManager.getConnection("jdbc:postgresql://"+fixture.database.getHost()+":"+fixture.database.getMappedPort(5432)+"/busydata","busydata","fixture"):null) {
            long gateKey=0x4275737944617461L;
            if(postgres)try(var lock=gate.prepareStatement("SELECT pg_catalog.pg_advisory_lock(?)")){
                lock.setLong(1,gateKey);try(var rows=lock.executeQuery()){assertTrue(rows.next());}
            }
            String gateSql=postgres?"SELECT 42 FROM pg_catalog.pg_advisory_xact_lock("+gateKey+") /* analysis gate */":"SELECT 42 /* analysis gate */";
            var job=fixture.submit(session,"ALTER TABLE analysis_gate ADD COLUMN actual_new_column INTEGER; "+gateSql);
            Throwable primary=null;
            try {
                if(postgres)awaitNativeAnalysisGate(gate);else assertTrue(reached.await(20,java.util.concurrent.TimeUnit.SECONDS));
                assertTrue(session.revision>request.getSessionRevision());
                var stale=new Reply<Analysis>();dispatch(service,request,stale);
                assertEquals(Status.Code.FAILED_PRECONDITION,Status.fromThrowable(stale.error).getCode());assertNull(stale.value);
                var current=new Reply<Analysis>();dispatch(service,request.toBuilder().setSessionRevision(session.revision).build(),current);
                assertNull(current.error);awaitCompletion(service,session,request.toBuilder().setSessionRevision(session.revision).build(),"actual_new_column");
            }catch(Throwable failure){primary=failure;throw failure;}
            finally{
                release.countDown();
                if(postgres)try(var unlock=gate.prepareStatement("SELECT pg_catalog.pg_advisory_unlock(?)")){
                    unlock.setLong(1,gateKey);try(var rows=unlock.executeQuery()){assertTrue(rows.next());assertTrue(rows.getBoolean(1));}
                }
                try{var finished=job.finished.get(20,java.util.concurrent.TimeUnit.SECONDS);assertEquals(JobState.COMPLETED,finished.getState(),()->"Gated script outcome: "+finished);}
                catch(Throwable cleanup){if(primary!=null)primary.addSuppressed(cleanup);else throw cleanup;}
            }
            }
            try(var statement=session.connection.createStatement();var rows=statement.executeQuery("SELECT actual_new_column FROM analysis_gate")){assertFalse(rows.next());}
        }finally{release.countDown();}
    }
    private static void awaitNativeAnalysisGate(java.sql.Connection gate)throws Exception {
        long deadline=System.nanoTime()+java.util.concurrent.TimeUnit.SECONDS.toNanos(20);
        try(var activity=gate.prepareStatement("SELECT EXISTS (SELECT 1 FROM pg_catalog.pg_stat_activity WHERE pid<>pg_catalog.pg_backend_pid() AND datname=pg_catalog.current_database() AND query LIKE ? AND wait_event_type='Lock')")) {
            activity.setQueryTimeout(5);activity.setString(1,"%/* analysis gate */%");
            while(System.nanoTime()<deadline) {
                try(var rows=activity.executeQuery()){assertTrue(rows.next());if(rows.getBoolean(1))return;}
                Thread.sleep(20);
            }
        }
        fail("The PostgreSQL statement never reached its native advisory-lock gate");
    }

    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void catalogRefreshAndExecutedDdlInvalidateBoundAnalysis(String engine)throws Exception {
        try(var fixture=new EngineFixture(root,engine)) {
            var session=fixture.open();fixture.execute(session,"CREATE TABLE analysis_revision(id INTEGER PRIMARY KEY)");
            var service=new WorkbenchService(fixture.sessions,fixture.jobs,fixture.results,fixture.metadata,fixture.safety,fixture.analysis,()->{});
            var context=Context.newBuilder().setProtocolVersion(WorkbenchService.PROTOCOL).setInstanceId(service.instance).setRequestId("analysis-regression").build();
            warm(service,session,context);
            String sql="SELECT a. FROM analysis_revision a";
            var request=AnalysisRequest.newBuilder().setContext(context).setDocumentId("exact-document").setDocumentVersion(7)
                .setSql(sql).setCaretUtf16(sql.indexOf(". ")+1).setSessionId(session.id).setEngine(fixture.engine)
                .setContextRevision(session.contextRevision).setSessionRevision(session.revision).build();
            var initial=new Reply<Analysis>();dispatch(service,request,initial);
            assertNull(initial.error);assertTrue(initial.completed);assertTrue(initial.value.getCompletionsList().stream().anyMatch(c->c.getLabel().equals("id")));
            fixture.execute(session,"ALTER TABLE analysis_revision ADD COLUMN actual_new_column INTEGER");
            var stale=new Reply<Analysis>();dispatch(service,request,stale);
            assertEquals(Status.Code.FAILED_PRECONDITION,Status.fromThrowable(stale.error).getCode());assertNull(stale.value);
            // Large snapshots must not bypass identity checks through a bounded
            // completion fallback, even when they cannot be fully analyzed.
            var large=new Reply<Analysis>();dispatch(service,request.toBuilder().setSql("SELECT 1"+" ".repeat(262145)).build(),large);
            assertEquals(Status.Code.FAILED_PRECONDITION,Status.fromThrowable(large.error).getCode());
            var fresh=request.toBuilder().setSessionRevision(session.revision).build();
            var updated=new Reply<Analysis>();dispatch(service,fresh,updated);
            assertNull(updated.error);assertEquals(fresh.getSessionRevision(),updated.value.getSessionRevision());
            awaitCompletion(service,session,fresh,"actual_new_column");
            long before=session.revision;
            var refreshed=new Reply<SchemaObjects>();service.explore(ExploreRequest.newBuilder().setContext(context).setSessionId(session.id).setKind(ObjectKind.TABLE).setRefresh(true).build(),refreshed);
            assertNull(refreshed.error);assertTrue(session.revision>before);assertEquals(session.revision,refreshed.value.getSessionRevision());
            var refreshedStale=new Reply<Analysis>();dispatch(service,fresh,refreshedStale);
            assertEquals(Status.Code.FAILED_PRECONDITION,Status.fromThrowable(refreshedStale.error).getCode());
            assertEquals(TransactionState.IDLE,session.state);assertEquals(1,fixture.sessions.size());
        }
    }    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void warmLanguageOperationsNeverAcquireJdbcConnections(String engine)throws Exception {
        var opened=new java.util.concurrent.atomic.AtomicInteger();
        try(var fixture=new EngineFixture(root,engine,(adapter,request,port)->{opened.incrementAndGet();return adapter.connect(request,port);})){
            var session=fixture.open();fixture.execute(session,"CREATE TABLE cached_language(id INTEGER PRIMARY KEY)");
            var service=new WorkbenchService(fixture.sessions,fixture.jobs,fixture.results,fixture.metadata,fixture.safety,fixture.analysis,()->{});
            var context=Context.newBuilder().setProtocolVersion(WorkbenchService.PROTOCOL).setInstanceId(service.instance).setRequestId("cached-language").build();warm(service,session,context);
            int before=opened.get();
            for(var operation:java.util.List.of(AnalysisOperation.COMPLETION,AnalysisOperation.DIAGNOSTICS,AnalysisOperation.PARAMETER_INFORMATION,AnalysisOperation.FORMAT)){
                String sql=operation==AnalysisOperation.PARAMETER_INFORMATION?"SELECT abs(1)":"SELECT c.id FROM cached_language c";
                var request=AnalysisRequest.newBuilder().setContext(context).setDocumentId("cached-document").setDocumentVersion(1).setSessionId(session.id).setSessionRevision(session.revision).setContextRevision(session.contextRevision).setEngine(fixture.engine).setSql(sql).setCaretUtf16(sql.length()-1).setOperation(operation).build();var reply=new Reply<Analysis>();
                switch(operation){case COMPLETION->service.completeSql(request,reply);case DIAGNOSTICS->service.diagnoseSql(request,reply);case PARAMETER_INFORMATION->service.sqlParameterInformation(request,reply);case FORMAT->service.formatSql(request,reply);default->throw new AssertionError();}
                assertNull(reply.error);assertEquals(before,opened.get(),"Warm editor operation acquired a live database connection");assertTrue(reply.value.getMetadataSnapshotRevision()>0);
            }
        }
    }

}
