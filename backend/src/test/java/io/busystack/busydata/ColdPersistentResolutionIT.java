package io.busystack.busydata;

import io.busystack.busydata.adapters.JdbcAdapter;
import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.results.ResultStore;
import io.busystack.busydata.schema.*;
import io.busystack.busydata.sessions.SessionRegistry;
import java.lang.reflect.*;
import java.nio.file.Path;
import java.sql.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

/** Missing comparison evidence must not manufacture physical resolution uncertainty. */
class ColdPersistentResolutionIT {
    @TempDir Path root;
    private static final String PARENT="cold_persistent_parent",CHILD="cold_persistent_child",VIEW="cold_persistent_view";
    private static final class Transport {
        final AtomicInteger opens=new AtomicInteger(),metadataOpens=new AtomicInteger(),rulesReads=new AtomicInteger(),showReads=new AtomicInteger();
        final Map<String,AtomicInteger> exact=new ConcurrentHashMap<>(),marked=new ConcurrentHashMap<>();
        Connection open(JdbcAdapter adapter,OpenRequest request,Integer port)throws Exception {
            Connection actual=adapter.connect(request,port);opens.incrementAndGet();
            if(request.getProfile().getReadOnly())metadataOpens.incrementAndGet();
            return (Connection)Proxy.newProxyInstance(Connection.class.getClassLoader(),new Class[]{Connection.class},(proxy,method,args)->{
                Object result=invoke(actual,method,args);
                if(method.getName().equals("createStatement")&&result instanceof Statement statement)return wrap(statement,null);
                if(Set.of("prepareStatement","prepareCall").contains(method.getName())&&args!=null&&args[0] instanceof String sql&&result instanceof PreparedStatement statement)return wrap(statement,sql);
                return result;
            });
        }
        private Object wrap(Statement actual,String preparedSql){
            Class<?> contract=actual instanceof CallableStatement?CallableStatement.class:actual instanceof PreparedStatement?PreparedStatement.class:Statement.class;
            return Proxy.newProxyInstance(contract.getClassLoader(),new Class[]{contract},(proxy,method,args)->{
                if(Set.of("execute","executeQuery","executeUpdate","executeLargeUpdate").contains(method.getName())){
                    String sql=args!=null&&args.length>0&&args[0] instanceof String text?text:preparedSql;
                    if(sql!=null){
                        String upper=sql.stripLeading().toUpperCase(Locale.ROOT);
                        if(upper.contains("FROM JSON_TABLE("))rulesReads.incrementAndGet();
                        if(upper.startsWith("SHOW CREATE "))showReads.incrementAndGet();
                        var counter=exact.get(sql);if(counter!=null)counter.incrementAndGet();
                        for(var entry:marked.entrySet())if(sql.contains(entry.getKey()))entry.getValue().incrementAndGet();
                    }
                }
                return invoke(actual,method,args);
            });
        }
        String selection(String fields,String table){
            String marker="cold-persistent-"+UUID.randomUUID();
            String sql="SELECT "+fields+" /* "+marker+" */ FROM "+table;
            exact.put(sql,new AtomicInteger());marked.put(marker,new AtomicInteger());return sql;
        }
        void once(){
            assertFalse(exact.isEmpty());
            exact.forEach((sql,count)->assertEquals(1,count.get(),"Each exact user SELECT crosses the real transport once"));
            marked.forEach((marker,count)->assertEquals(1,count.get(),"No metadata-side/direct/prepared replay may carry the original SELECT marker"));
        }
        private static Object invoke(Object target,Method method,Object[] args)throws Throwable{
            try{return method.invoke(target,args);}catch(InvocationTargetException failed){throw failed.getCause();}
        }
    }
    private static void rawSeed(SessionRegistry.Session session)throws Exception {
        session.lock.lock();try(var sql=session.connection.createStatement()){
            sql.execute("CREATE TABLE "+session.adapter.quote(PARENT)+"(id INTEGER PRIMARY KEY)");
            sql.execute("CREATE TABLE "+session.adapter.quote(CHILD)+"(id INTEGER PRIMARY KEY,parent_id INTEGER,CONSTRAINT cold_persistent_link FOREIGN KEY(parent_id) REFERENCES "+session.adapter.quote(PARENT)+"(id))");
            sql.executeUpdate("INSERT INTO "+session.adapter.quote(PARENT)+" VALUES(1)");
            sql.executeUpdate("INSERT INTO "+session.adapter.quote(CHILD)+" VALUES(7,1)");
            sql.execute("CREATE VIEW "+session.adapter.quote(VIEW)+" AS SELECT id,parent_id FROM "+session.adapter.quote(CHILD));
        }finally{session.lock.unlock();}
    }
    private static ResultStore.Result select(EngineFixture fixture,SessionRegistry.Session session,String sql)throws Exception{
        var job=fixture.execute(session,sql);assertEquals(JobState.COMPLETED,job.state,job.info().toString());
        assertEquals(1,job.info().getResultsCount());var result=fixture.results.get(job.info().getResults(0).getResultId());
        assertTrue(result.fetchFinished);assertEquals(1,result.rows());
        assertEquals(List.of("7","1"),result.read(0).getValuesList().stream().map(Value::getSignedInteger).toList());return result;
    }
    private static void resolution(MetadataPlatform platform,SessionRegistry.Session session,MetadataState state,long epoch){
        assertEquals(state,platform.capture(session).sessionResolution().state());
        assertEquals(epoch,platform.sessionResolutionEpoch(session));
        assertEquals(epoch,platform.capture(session).sessionResolution().epoch());
    }
    private static void noColdAcquisition(Transport transport,int opens){
        assertEquals(opens,transport.opens.get(),"Cold user SQL must not open another physical connection");
        assertEquals(0,transport.metadataOpens.get(),"No private independent metadata connection is authorized by a cold SELECT");
        assertEquals(0,transport.rulesReads.get(),"No full native identifier corpus may be bootstrapped by a cold SELECT");
    }
    @ParameterizedTest @ValueSource(strings={"MYSQL","MARIADB"})
    void coldPersistentTableAndViewStayAvailableUntilExplicitL2ThenNewChildSupportsRelatedRows(String engine)throws Exception {
        var transport=new Transport();
        try(var fixture=new EngineFixture(root,engine,transport::open)){
            var session=fixture.open();rawSeed(session);var platform=fixture.metadata.metadataPlatform();
            var initial=platform.publishedSnapshot(session);assertTrue(initial.identities().isEmpty());assertTrue(initial.catalogCoverage().isEmpty());assertFalse(initial.rules().complete());
            resolution(platform,session,MetadataState.AVAILABLE,0);assertTrue(platform.capture(session).sessionResolution().verified().isEmpty());
            int opened=transport.opens.get();long context=session.contextRevision;var physical=session.connection;String owner=session.id;
            session.lock.lock();try{
                long revision=session.revision;
                var classification=OwnedTemporarySource.verify(platform,session,"busydata","busydata",CHILD,System.nanoTime()+TimeUnit.SECONDS.toNanos(10),null);
                assertEquals(MetadataState.UNAVAILABLE,classification.state());assertFalse(classification.available());
                assertEquals(revision,session.revision);assertEquals(context,session.contextRevision);assertSame(physical,session.connection);assertEquals(owner,session.id);
                resolution(platform,session,MetadataState.AVAILABLE,0);assertTrue(platform.capture(session).sessionResolution().verified().isEmpty());
            }finally{session.lock.unlock();}
            noColdAcquisition(transport,opened);assertSame(initial,platform.publishedSnapshot(session));assertTrue(transport.showReads.get()>0,"A genuine owned SHOW completed; missing rules alone must not retire its resolution owner");
            String table=session.adapter.table("busydata","busydata",CHILD),view=session.adapter.table("busydata","busydata",VIEW);
            String coldSql=transport.selection("id,parent_id",table),viewSql=transport.selection("id,parent_id",view);
            var cold=select(fixture,session,coldSql);var coldProof=cold.metadataProof();var coldRow=cold.read(0);
            assertEquals(MetadataState.UNAVAILABLE,coldProof.state());assertFalse(coldProof.capturedStructure());
            var coldView=select(fixture,session,viewSql);assertEquals(MetadataState.UNAVAILABLE,coldView.metadataProof().state());assertFalse(coldView.metadataProof().capturedStructure());
            resolution(platform,session,MetadataState.AVAILABLE,0);assertTrue(platform.capture(session).sessionResolution().verified().isEmpty());
            assertSame(initial,platform.publishedSnapshot(session));assertFalse(platform.publishedSnapshot(session).rules().complete());assertEquals(context,session.contextRevision);assertSame(physical,session.connection);assertEquals(owner,session.id);noColdAcquisition(transport,opened);transport.once();
            var related=new RelatedRows(platform,fixture.results);
            var request=RelatedRowsRequest.newBuilder().setSessionId(session.id).setDocumentId("cold-persistent-document").setResultId(cold.id).build();
            var unavailable=RelatedRowsTestRequests.list(related,session,request);assertEquals("incomplete-metadata",unavailable.getAvailability());assertEquals(0,unavailable.getRelationshipsCount());noColdAcquisition(transport,opened);

            // Explicit user-style central introspection, not a parent SELECT or
            // per-keystroke/native-rule workaround, supplies the required L2.
            fixture.introspectionLevel(session,IntrospectionLevel.STRUCTURE);
            new Explorer(fixture.metadata).refreshContext(session,MetadataPlatform.RefreshMode.FULL);
            assertTrue(platform.publishedSnapshot(session).rules().complete());assertTrue(transport.metadataOpens.get()>0);assertTrue(transport.rulesReads.get()>0);
            assertTrue(platform.capture(session).complete(new MetadataScope("busydata","busydata",CHILD,ObjectKind.COLUMN),IntrospectionLevel.STRUCTURE));
            resolution(platform,session,MetadataState.AVAILABLE,0);
            assertEquals(coldProof,cold.metadataProof(),"A later refresh cannot invent execution-time proof for an old result");assertEquals(coldRow,cold.read(0));
            var stillUnavailable=RelatedRowsTestRequests.list(related,session,request);assertEquals("incomplete-metadata",stillUnavailable.getAvailability());assertEquals(0,stillUnavailable.getRelationshipsCount());
            int afterRefreshOpens=transport.opens.get(),afterRefreshRules=transport.rulesReads.get();
            String freshSql=transport.selection("id,parent_id",table);var fresh=select(fixture,session,freshSql);
            assertTrue(fresh.metadataProof().available(),()->fresh.metadataProof().state()+":"+fresh.metadataProof().availability());
            var choices=RelatedRowsTestRequests.list(related,session,request.toBuilder().setResultId(fresh.id).build());
            assertEquals("available",choices.getAvailability());assertEquals(1,choices.getRelationshipsCount());var choice=choices.getRelationships(0);
            assertEquals("available",choice.getAvailability());assertFalse(choice.getIncoming());assertEquals("cold_persistent_link",choice.getName());
            assertEquals(PARENT,choice.getBrowse().getTable());assertEquals("busydata",choice.getBrowse().getCatalog());assertEquals("busydata",choice.getBrowse().getSchema());assertFalse(choice.getBrowse().getMetadataObjectIdentity().isEmpty());
            assertEquals(fresh.id,choice.getBrowse().getOriginResultId());assertEquals(1,choice.getBrowse().getConditionsCount());
            assertEquals("id",choice.getBrowse().getConditions(0).getColumn());assertEquals(ValuePredicate.EQUAL,choice.getBrowse().getConditions(0).getPredicate());assertEquals("1",choice.getBrowse().getConditions(0).getValue().getSignedInteger());
            assertEquals(3,fixture.jobs.list(session.id).size(),"Only cold child, cold view and fresh child SELECT jobs exist; no parent SELECT repairs resolution");
            assertEquals(Set.of(coldSql,viewSql,freshSql),Set.of(cold.sourceSql,coldView.sourceSql,fresh.sourceSql),"Retained execution provenance preserves exactly the three selected SQL documents after terminal Job text cleanup");
            assertEquals(afterRefreshOpens,transport.opens.get());assertEquals(afterRefreshRules,transport.rulesReads.get());assertEquals(coldProof,cold.metadataProof());assertEquals(coldRow,cold.read(0));resolution(platform,session,MetadataState.AVAILABLE,0);transport.once();
        }
    }
    @ParameterizedTest @ValueSource(strings={"MYSQL","MARIADB"})
    void coldPersistentObservationCannotEraseOrReplaceAnExistingUnknownResolution(String engine)throws Exception {
        var transport=new Transport();
        try(var fixture=new EngineFixture(root,engine,transport::open)){
            var session=fixture.open();rawSeed(session);var platform=fixture.metadata.metadataPlatform();var initial=platform.publishedSnapshot(session);assertFalse(initial.rules().complete());
            int opened=transport.opens.get();long context=session.contextRevision;var physical=session.connection;String owner=session.id;long epoch;
            session.lock.lock();try{
                epoch=platform.markSessionResolutionUnknown(session,"The exact owning physical session needs explicit reconciliation");assertTrue(epoch>0);
                var unknown=platform.capture(session).sessionResolution();assertTrue(unknown.verified().isEmpty());long revision=session.revision;
                var classification=OwnedTemporarySource.verify(platform,session,"busydata","busydata",CHILD,System.nanoTime()+TimeUnit.SECONDS.toNanos(10),null);
                assertEquals(MetadataState.UNAVAILABLE,classification.state());assertFalse(classification.available());assertEquals(revision,session.revision);assertEquals(context,session.contextRevision);assertSame(physical,session.connection);assertEquals(owner,session.id);
                assertEquals(unknown,platform.capture(session).sessionResolution(),"Missing comparison evidence must not add a verified entry, clear UNKNOWN or replace its epoch");
            }finally{session.lock.unlock();}
            noColdAcquisition(transport,opened);assertSame(initial,platform.publishedSnapshot(session));
            String sql=transport.selection("id,parent_id",session.adapter.table("busydata","busydata",CHILD));var result=select(fixture,session,sql);
            assertEquals(MetadataState.UNAVAILABLE,result.metadataProof().state());assertFalse(result.metadataProof().capturedStructure());
            resolution(platform,session,MetadataState.UNKNOWN,epoch);assertTrue(platform.capture(session).sessionResolution().verified().isEmpty());assertTrue(platform.capture(session).sessionResolution().owned().isEmpty());
            assertSame(initial,platform.publishedSnapshot(session));assertFalse(platform.publishedSnapshot(session).rules().complete());assertEquals(context,session.contextRevision);assertSame(physical,session.connection);assertEquals(owner,session.id);assertEquals(1,fixture.jobs.list(session.id).size());noColdAcquisition(transport,opened);transport.once();
        }
    }
}
