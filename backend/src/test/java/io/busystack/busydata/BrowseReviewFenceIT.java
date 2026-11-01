package io.busystack.busydata;

import io.busystack.busydata.adapters.JdbcAdapter;
import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.rpc.WorkbenchService;
import io.busystack.busydata.rpc.WorkbenchFailure;
import io.busystack.busydata.schema.*;
import io.grpc.Status;
import java.lang.reflect.*;
import java.nio.file.Path;
import java.sql.*;
import java.util.*;
import java.util.concurrent.atomic.*;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

/** Review acquisitions cannot silently replace the metadata owner selected by the caller. */
class BrowseReviewFenceIT {
    @TempDir Path root;
    @FunctionalInterface private interface Effect {void run()throws Exception;}
    private static final class DefinitionGate {
        final AtomicReference<Effect> next=new AtomicReference<>();
        final AtomicReference<Connection> physicalOwner=new AtomicReference<>();
        final AtomicInteger fired=new AtomicInteger();
        final AtomicInteger connections=new AtomicInteger(),jdbcCalls=new AtomicInteger();
        final AtomicInteger browsePrepared=new AtomicInteger(),browseExecuted=new AtomicInteger();
        Connection connect(JdbcAdapter adapter,OpenRequest request,Integer port)throws Exception {
            var actual=adapter.connect(request,port);connections.incrementAndGet();
            boolean owned=!request.getProfile().getReadOnly()&&physicalOwner.compareAndSet(null,actual);
            return (Connection)Proxy.newProxyInstance(Connection.class.getClassLoader(),new Class[]{Connection.class},(proxy,method,args)->{
                if(owned)jdbcCalls.incrementAndGet();Object value=invoke(actual,method,args);
                if(owned&&method.getName().equals("prepareStatement")&&args!=null&&args[0] instanceof String sql&&value instanceof PreparedStatement statement){
                    boolean definition=sql.startsWith("SHOW CREATE TABLE ")&&sql.contains("browse_parent");
                    boolean browse=sql.startsWith("SELECT * FROM ")&&sql.contains("browse_parent");
                    if(browse)browsePrepared.incrementAndGet();
                    if(definition||browse)return Proxy.newProxyInstance(PreparedStatement.class.getClassLoader(),new Class[]{PreparedStatement.class},(prepared,operation,parameters)->{
                        if(browse&&operation.getName().equals("executeQuery"))browseExecuted.incrementAndGet();
                        Object result=invoke(statement,operation,parameters);
                        if(definition&&operation.getName().equals("executeQuery")){
                            var effect=next.getAndSet(null);if(effect!=null){fired.incrementAndGet();effect.run();}
                        }
                        return result;
                    });
                }
                return value;
            });
        }
    }
    private static Object invoke(Object owner,Method method,Object[] arguments)throws Throwable {
        try{return method.invoke(owner,arguments);}catch(InvocationTargetException failure){throw failure.getCause();}
    }
    private static void setup(EngineFixture fixture,io.busystack.busydata.sessions.SessionRegistry.Session session)throws Exception {
        fixture.execute(session,"CREATE TABLE browse_parent(id INTEGER PRIMARY KEY); CREATE TABLE browse_child(id INTEGER PRIMARY KEY,parent_id INTEGER,CONSTRAINT browse_link FOREIGN KEY(parent_id) REFERENCES browse_parent(id)); INSERT INTO browse_parent VALUES(1); INSERT INTO browse_child VALUES(10,1)");
        fixture.warm(session,"browse_parent","browse_child");
    }
    private static BrowseRequest request(EngineFixture fixture,io.busystack.busydata.sessions.SessionRegistry.Session session){
        var snapshot=fixture.metadata.metadataPlatform().capture(session);
        var relation=snapshot.namespace("busydata",fixture.schema(),ObjectKind.TABLE,"").stream().filter(object->object.identity().name().equals("browse_parent")).findFirst().orElseThrow();
        return BrowseRequest.newBuilder().setSessionId(session.id).setDocumentId("browse-review-owner").setCatalog("busydata").setSchema(fixture.schema()).setTable("browse_parent").setRowLimit(10).setMetadataSnapshotRevision(snapshot.revision()).setMetadataObjectIdentity(relation.identity().key()).build();
    }
    private static void publishSameColumns(EngineFixture fixture,io.busystack.busydata.sessions.SessionRegistry.Session session)throws Exception {
        var platform=fixture.metadata.metadataPlatform();var before=platform.capture(session);var scope=new MetadataScope("busydata",fixture.schema(),"browse_parent",ObjectKind.COLUMN);
        var values=before.select(scope).stream().map(before::projection).toList();assertFalse(values.isEmpty());
        var coverage=new MetadataCoverage(scope,IntrospectionLevel.STRUCTURE,MetadataState.AVAILABLE,true,MetadataFingerprint.objects(values),session.revision,session.contextRevision,System.currentTimeMillis(),"");
        platform.publish(session,platform.beginRefresh(session),before.rules(),Map.of(scope,new MetadataPlatform.Branch(values,coverage)),false);
        assertTrue(platform.capture(session).revision()>before.revision(),"Even equivalent facts are a distinct accepted publication");
    }
    @ParameterizedTest @ValueSource(strings={"MYSQL","MARIADB"})
    void publicationInsideRealShowCreateRejectsRelatedReviewBeforeTokenOrJob(String engine)throws Exception {
        var gate=new DefinitionGate();
        try(var fixture=new EngineFixture(root,engine,gate::connect)){
            var session=fixture.open();setup(fixture,session);
            var retained=fixture.results.get(fixture.execute(session,"SELECT id,parent_id FROM browse_child").info().getResults(0).getResultId());
            var related=new RelatedRows(fixture.metadata.metadataPlatform(),fixture.results);
            var choices=RelatedRowsTestRequests.list(related,session,RelatedRowsRequest.newBuilder().setSessionId(session.id).setDocumentId("related-review-owner").setResultId(retained.id).build());
            var browse=choices.getRelationshipsList().stream().filter(choice->choice.getAvailability().equals("available")).findFirst().orElseThrow().getBrowse();
            long selected=browse.getMetadataSnapshotRevision();int jobs=fixture.jobs.list("").size();
            var service=new WorkbenchService(fixture.sessions,fixture.jobs,fixture.results,fixture.metadata,fixture.safety,fixture.analysis,()->{});
            var context=Context.newBuilder().setInstanceId(service.instance).setProtocolVersion(WorkbenchService.PROTOCOL).setRequestId("browse-publication-fence").build();
            gate.next.set(()->publishSameColumns(fixture,session));
            var reply=new RelatedRowsIT.Reply<Approval>();service.reviewBrowse(browse.toBuilder().setContext(context).build(),reply);
            assertEquals(1,gate.fired.get(),"The real owning-session classifier must cross the publication gate once");
            assertNotNull(reply.error,"A request for the old metadata owner cannot receive a token for the new one");assertNull(reply.value);
            assertEquals(Status.Code.FAILED_PRECONDITION,Status.fromThrowable(reply.error).getCode());
            var trailers=Status.trailersFromThrowable(reply.error);assertNotNull(trailers);
            assertEquals("stale",trailers.get(io.grpc.Metadata.Key.of(WorkbenchFailure.TRAILER,io.grpc.Metadata.ASCII_STRING_MARSHALLER)));
            assertTrue(fixture.metadata.metadataPlatform().capture(session).revision()>selected);
            assertEquals(jobs,fixture.jobs.list("").size(),"Review rejection cannot create or replay a SQL job");
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void incompleteSelectedStructureIsRejectedBeforeJdbcOrApproval(String engine)throws Exception {
        var counter=new DefinitionGate();
        try(var fixture=new EngineFixture(root,engine,counter::connect)){
            var session=fixture.open();setup(fixture,session);var platform=fixture.metadata.metadataPlatform();
            platform.markStale(session,"Explicit fixture reconciliation is pending");
            var browse=request(fixture,session);int jobs=fixture.jobs.list("").size();
            assertFalse(platform.capture(session).complete(new MetadataScope("busydata",fixture.schema(),"browse_parent",ObjectKind.COLUMN),IntrospectionLevel.STRUCTURE));
            var service=new WorkbenchService(fixture.sessions,fixture.jobs,fixture.results,fixture.metadata,fixture.safety,fixture.analysis,()->{});
            var context=Context.newBuilder().setInstanceId(service.instance).setProtocolVersion(WorkbenchService.PROTOCOL).setRequestId("browse-incomplete-selection").build();
            int connections=counter.connections.get(),jdbcCalls=counter.jdbcCalls.get();
            var reply=new RelatedRowsIT.Reply<Approval>();service.reviewBrowse(browse.toBuilder().setContext(context).build(),reply);
            assertNotNull(reply.error);assertNull(reply.value,"Incomplete selected structure cannot receive an approval token");
            assertEquals(Status.Code.FAILED_PRECONDITION,Status.fromThrowable(reply.error).getCode());
            var trailers=Status.trailersFromThrowable(reply.error);assertNotNull(trailers);
            assertEquals(WorkbenchFailure.Reason.INCOMPLETE_METADATA.wire(),trailers.get(io.grpc.Metadata.Key.of(WorkbenchFailure.TRAILER,io.grpc.Metadata.ASCII_STRING_MARSHALLER)));
            assertEquals(connections,counter.connections.get(),"An invalid selection cannot acquire an independent metadata connection");
            assertEquals(jdbcCalls,counter.jdbcCalls.get(),"An invalid selection cannot query its physical connection");
            assertEquals(browse.getMetadataSnapshotRevision(),platform.capture(session).revision(),"Review cannot enrich or rebind an incomplete selected snapshot");
            assertEquals(jobs,fixture.jobs.list("").size());
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void unchangedReviewSubmitsOnceAndLaterRealDdlRejectsBeforeAnotherJob(String engine)throws Exception {
        var counter=new DefinitionGate();
        try(var dispatch=new JobDispatchGate();var fixture=new EngineFixture(root,engine,counter::connect,database->{},dispatch::decorate)){
            dispatch.attach(fixture.jobs);
            var session=fixture.open();setup(fixture,session);var explorer=new Explorer(fixture.metadata);var browse=request(fixture,session);
            int jobs=fixture.jobs.list("").size();var approval=TableBrowse.review(session,browse,explorer,fixture.safety);
            assertEquals(jobs,fixture.jobs.list("").size());
            io.busystack.busydata.jobs.Jobs.Job submitted;
            dispatch.arm();
            try{
                submitted=TableBrowse.submit(session,browse.toBuilder().setExecutionId(UUID.randomUUID().toString()).setApprovalToken(approval.getToken()).build(),explorer,fixture.safety,fixture.jobs);
                dispatch.assertHeld(submitted);
                assertThrows(IllegalArgumentException.class,()->TableBrowse.submit(session,browse.toBuilder().setExecutionId(UUID.randomUUID().toString()).setApprovalToken(approval.getToken()).build(),explorer,fixture.safety,fixture.jobs));
                assertEquals(0,counter.browsePrepared.get());assertEquals(0,counter.browseExecuted.get());
            }finally{dispatch.release();}
            EditingIT.await(submitted);assertEquals(JobState.COMPLETED,submitted.state,submitted.info().toString());assertEquals(jobs+1,fixture.jobs.list("").size());assertEquals(1,submitted.info().getResults(0).getFetchedRows());
            assertEquals(1,counter.browsePrepared.get());assertEquals(1,counter.browseExecuted.get(),"The unchanged accepted owner sends its generated SELECT exactly once");
            var current=request(fixture,session);var beforeDdl=TableBrowse.review(session,current,explorer,fixture.safety);
            fixture.execute(session,"ALTER TABLE browse_parent ADD COLUMN changed_after_review INTEGER");
            int afterDdl=fixture.jobs.list("").size();
            var failure=assertThrows(WorkbenchFailure.class,()->TableBrowse.submit(session,current.toBuilder().setExecutionId(UUID.randomUUID().toString()).setApprovalToken(beforeDdl.getToken()).build(),explorer,fixture.safety,fixture.jobs));
            assertEquals(WorkbenchFailure.Reason.STALE,failure.reason());
            assertEquals(afterDdl,fixture.jobs.list("").size(),"A stale review is rejected before admission, not as a failed browse job");
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void acceptedBrowseRejectsNewPublicationBeforeItsWorkerSendsSql(String engine)throws Exception {
        var counter=new DefinitionGate();
        try(var dispatch=new JobDispatchGate();var fixture=new EngineFixture(root,engine,counter::connect,database->{},dispatch::decorate)){
            dispatch.attach(fixture.jobs);
            var session=fixture.open();setup(fixture,session);var explorer=new Explorer(fixture.metadata);var browse=request(fixture,session);
            var approval=TableBrowse.review(session,browse,explorer,fixture.safety);int before=fixture.jobs.list("").size();
            String execution=UUID.randomUUID().toString();io.busystack.busydata.jobs.Jobs.Job accepted;
            dispatch.arm();
            try{
                accepted=TableBrowse.submit(session,browse.toBuilder().setExecutionId(execution).setApprovalToken(approval.getToken()).build(),explorer,fixture.safety,fixture.jobs);
                dispatch.assertHeld(accepted);assertSame(accepted,fixture.jobs.get(accepted.id));assertEquals(execution,accepted.execution);
                assertEquals(0,counter.browsePrepared.get());assertEquals(0,counter.browseExecuted.get());
                session.lock.lock();try{publishSameColumns(fixture,session);}finally{session.lock.unlock();}
                assertTrue(fixture.metadata.metadataPlatform().capture(session).revision()>browse.getMetadataSnapshotRevision());
            }finally{dispatch.release();}
            EditingIT.await(accepted);
            assertSame(accepted,fixture.jobs.get(accepted.id));assertEquals(execution,accepted.info().getExecutionId());
            assertEquals(JobState.FAILED,accepted.state,accepted.info().toString());assertEquals("stale",accepted.info().getErrorCode());
            assertEquals(0,accepted.info().getResultsCount());
            assertEquals(0,counter.browsePrepared.get(),"A stale queued owner must be refused before JDBC prepares its generated SELECT");
            assertEquals(0,counter.browseExecuted.get(),"The accepted job sends no SELECT and never replays it");
            assertEquals(before+1,fixture.jobs.list("").size(),"One admitted browse remains the same failed job");
        }
    }
}
