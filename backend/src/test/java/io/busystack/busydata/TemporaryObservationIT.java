package io.busystack.busydata;

import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.*;
import io.busystack.busydata.sessions.SessionRegistry;
import java.nio.file.Path;
import java.lang.reflect.*;
import java.sql.*;
import java.util.*;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

/** Genuine native definition/owned-shape controls; no mocked engine acceptance. */
class TemporaryObservationIT {
    @TempDir Path root;
    private static final String TABLE="native_observation_temp";
    /** Counts real transport calls on every physical connection, including
     * direct metadata-side execution which would not create a second Job. */
    private static final class SelectTransportCounter {
        volatile String exact="",marker="";final AtomicInteger exactExecutions=new AtomicInteger(),markedExecutions=new AtomicInteger();
        Connection open(io.busystack.busydata.adapters.JdbcAdapter adapter,OpenRequest request,Integer port)throws Exception{
            var actual=adapter.connect(request,port);
            return (Connection)Proxy.newProxyInstance(Connection.class.getClassLoader(),new Class[]{Connection.class},(proxy,method,args)->{
                var value=invoke(actual,method,args);
                if(method.getName().equals("createStatement")&&value instanceof Statement statement)return wrap(statement,null);
                if(Set.of("prepareStatement","prepareCall").contains(method.getName())&&args!=null&&args[0] instanceof String sql&&value instanceof PreparedStatement statement)return wrap(statement,sql);
                return value;
            });
        }
        private Object wrap(Statement actual,String preparedSql){
            Class<?> contract=actual instanceof CallableStatement?CallableStatement.class:actual instanceof PreparedStatement?PreparedStatement.class:Statement.class;
            return Proxy.newProxyInstance(contract.getClassLoader(),new Class[]{contract},(proxy,method,args)->{
                if(Set.of("execute","executeQuery","executeUpdate","executeLargeUpdate").contains(method.getName())){
                    String sql=args!=null&&args.length>0&&args[0] instanceof String text?text:preparedSql;
                    if(sql!=null){if(!exact.isEmpty()&&sql.equals(exact))exactExecutions.incrementAndGet();if(!marker.isEmpty()&&sql.contains(marker))markedExecutions.incrementAndGet();}
                }
                return invoke(actual,method,args);
            });
        }
        private static Object invoke(Object target,Method method,Object[] args)throws Throwable{try{return method.invoke(target,args);}catch(InvocationTargetException failed){throw failed.getCause();}}
        void once(){assertEquals(1,exactExecutions.get(),"The exact selected SQL must cross the transport once");assertEquals(1,markedExecutions.get(),"No direct or prepared replay may carry the unique SELECT marker");}
    }
    private static long deadline(){return System.nanoTime()+TimeUnit.SECONDS.toNanos(10);}
    private static OwnedTemporarySource.Classification observe(MetadataPlatform platform,SessionRegistry.Session session)throws Exception{return OwnedTemporarySource.verify(platform,session,"busydata","busydata",TABLE,deadline(),null);}
    private static void acquire(EngineFixture fixture,SessionRegistry.Session session,OwnedTemporarySource.Classification classified)throws Exception{
        var platform=fixture.metadata.metadataPlatform();try(var maintenance=platform.ownedMaintenance(session)){SessionMetadataOverlay.refresh(new Explorer(platform),session,"busydata","busydata",TABLE,null,deadline(),classified);}
    }
    private static void seed(EngineFixture fixture,SessionRegistry.Session session)throws Exception{
        fixture.introspectionLevel(session,IntrospectionLevel.STRUCTURE);
        session.lock.lock();try(var sql=session.connection.createStatement()){
            sql.execute("CREATE TABLE "+session.adapter.quote(TABLE)+"(id INTEGER PRIMARY KEY,n INTEGER)");sql.execute("INSERT INTO "+session.adapter.quote(TABLE)+" VALUES(99,999)");
        }finally{session.lock.unlock();}
        fixture.warm(session,TABLE);
        session.lock.lock();try(var sql=session.connection.createStatement()){
            sql.execute("CREATE TEMPORARY TABLE "+session.adapter.quote(TABLE)+"(id INTEGER PRIMARY KEY,n VARCHAR(40))");sql.execute("INSERT INTO "+session.adapter.quote(TABLE)+" VALUES(1,'temp')");
        }finally{session.lock.unlock();}
        var job=fixture.execute(session,"SELECT id,n FROM "+session.adapter.quote(TABLE));assertEquals(JobState.COMPLETED,job.state);var result=fixture.results.get(job.info().getResults(0).getResultId());assertEquals("temp",result.read(0).getValues(1).getText());assertFalse(result.metadataProof().capturedStructure(),"A source digest cannot authorize temporary-table editing");
    }
    @ParameterizedTest @ValueSource(strings={"MYSQL","MARIADB"})
    void unchangedObservationPreservesRevisionAndSingleSourceWhileOrdinarySelectExecutesOnce(String engine)throws Exception{
        var transport=new SelectTransportCounter();
        try(var fixture=new EngineFixture(root,engine,transport::open)){
            var session=fixture.open();seed(fixture,session);var platform=fixture.metadata.metadataPlatform();long stable;
            session.lock.lock();try{
                var before=platform.capture(session);stable=before.revision();assertTrue(before.ownedRelationAvailable("busydata","busydata",TABLE,true));
                var actual=observe(platform,session);assertTrue(actual.available());assertTrue(actual.definition().complete());assertTrue(actual.reusesOwnedShape(platform,session));assertEquals(stable,platform.capture(session).revision());
                assertEquals(1,before.resolve("busydata","busydata",ObjectKind.TABLE,"",TABLE,true).size());assertTrue(platform.publishedSnapshot(session).identities().values().stream().allMatch(value->value.identity().sessionOwner().isEmpty()));
            }finally{session.lock.unlock();}
            transport.marker="temporary-observation-exact-"+UUID.randomUUID();transport.exact="SELECT id,n /* "+transport.marker+" */ FROM "+session.adapter.quote(TABLE);
            assertEquals(0,transport.exactExecutions.get());assertEquals(0,transport.markedExecutions.get());
            var selected=fixture.execute(session,transport.exact);assertEquals(JobState.COMPLETED,selected.state);transport.once();assertEquals(2,fixture.jobs.list(session.id).size());assertEquals(stable,platform.capture(session).revision(),"Ordinary execution must not publish equivalent temporary structure");
            var other=fixture.open();other.lock.lock();try(var sql=other.connection.createStatement();var rows=sql.executeQuery("SELECT n FROM "+other.adapter.quote(TABLE)+" WHERE id=99")){assertTrue(rows.next());assertEquals(999,rows.getInt(1));assertFalse(rows.next());assertFalse(platform.capture(other).identities().values().stream().anyMatch(value->value.identity().sessionOwner().equals(session.id)));}finally{other.lock.unlock();}
            transport.once();
        }
    }
    @ParameterizedTest @ValueSource(strings={"MYSQL","MARIADB"})
    void opaqueAndSameEpochReplacedEvidenceMustAcquireAgain(String engine)throws Exception{
        try(var fixture=new EngineFixture(root,engine)){
            var session=fixture.open();seed(fixture,session);var platform=fixture.metadata.metadataPlatform();session.lock.lock();try{
                var before=platform.capture(session);var held=platform.temporaryObservation(session,"busydata","busydata",TABLE);
                platform.markSessionResolutionUnknown(session,"A real opaque boundary needs fresh owned evidence");assertFalse(platform.temporaryObservationCurrent(session,held,"busydata","busydata",TABLE));
                var fresh=observe(platform,session);assertTrue(fresh.available());assertFalse(fresh.reusesOwnedShape(platform,session));assertFalse(platform.capture(session).ownedRelationAvailable("busydata","busydata",TABLE,true));assertTrue(before.ownedRelationAvailable("busydata","busydata",TABLE,true));acquire(fixture,session,fresh);
                assertTrue(observe(platform,session).reusesOwnedShape(platform,session));var current=platform.temporaryObservation(session,"busydata","busydata",TABLE);long epoch=platform.sessionResolutionEpoch(session);
                platform.invalidateSessionRelation(session,"busydata","busydata",TABLE);assertTrue(platform.markSessionRelationVerified(session,epoch,"busydata","busydata",TABLE,MetadataSnapshot.PhysicalRelationKind.TEMPORARY));assertEquals(epoch,platform.sessionResolutionEpoch(session));assertFalse(platform.temporaryObservationCurrent(session,current,"busydata","busydata",TABLE),"Private record replacement must retire a held observation inside the same epoch");
                var replaced=observe(platform,session);assertFalse(replaced.reusesOwnedShape(platform,session));acquire(fixture,session,replaced);assertTrue(observe(platform,session).reusesOwnedShape(platform,session));assertEquals(1,fixture.jobs.list(session.id).size());
            }finally{session.lock.unlock();}
        }
    }
    @ParameterizedTest @ValueSource(strings={"MYSQL","MARIADB"})
    void rawAlterBeyondTheHeaderRetiresTheShapeBeforeAnyUserQuery(String engine)throws Exception{
        try(var fixture=new EngineFixture(root,engine)){
            var session=fixture.open();seed(fixture,session);var platform=fixture.metadata.metadataPlatform();session.lock.lock();try{
                var prior=observe(platform,session);assertTrue(prior.reusesOwnedShape(platform,session));long revision=session.revision,context=session.contextRevision;
                try(var sql=session.connection.createStatement()){sql.execute("ALTER TABLE "+session.adapter.quote(TABLE)+" ADD COLUMN extra DECIMAL(30,9) DEFAULT 7.000000001");}
                assertEquals(revision,session.revision);assertEquals(context,session.contextRevision);var changed=observe(platform,session);assertTrue(changed.available());assertTrue(changed.definition().complete());assertNotEquals(prior.definition().sha256(),changed.definition().sha256());assertFalse(changed.reusesOwnedShape(platform,session));assertFalse(platform.capture(session).ownedRelationAvailable("busydata","busydata",TABLE,true));acquire(fixture,session,changed);
                var snapshot=platform.capture(session);assertTrue(snapshot.ownedRelationAvailable("busydata","busydata",TABLE,true));assertEquals(3,snapshot.select(new MetadataScope("busydata","busydata",TABLE,ObjectKind.COLUMN)).size());assertTrue(observe(platform,session).reusesOwnedShape(platform,session));assertEquals(1,fixture.jobs.list(session.id).size(),"Native observation must never replay the original SELECT");
                try(var sql=session.connection.createStatement();var row=sql.executeQuery("SELECT id,n FROM "+session.adapter.quote(TABLE))){assertTrue(row.next());assertEquals(1,row.getInt(1));assertEquals("temp",row.getString(2));assertFalse(row.next());}
            }finally{session.lock.unlock();}
        }
    }
    @ParameterizedTest @ValueSource(strings={"MYSQL","MARIADB"})
    void partialRendererNeverReceivesAReusableDigest(String engine)throws Exception{
        try(var fixture=new EngineFixture(root,engine)){
            var session=fixture.open();seed(fixture,session);var platform=fixture.metadata.metadataPlatform();session.lock.lock();try{
                if(fixture.engine==Engine.MARIADB)try(var set=session.connection.prepareStatement("SET SESSION sql_mode=?")){set.setString(1,"NO_FIELD_OPTIONS");set.execute();}
                else try(var set=session.connection.createStatement()){set.execute("SET SESSION show_gipk_in_create_table_and_information_schema=OFF");}
                session.refresh();var partial=observe(platform,session);assertTrue(partial.available());assertEquals(MetadataState.PARTIAL,partial.definition().availability());assertTrue(partial.definition().sha256().isEmpty());assertFalse(partial.reusesOwnedShape(platform,session));acquire(fixture,session,partial);
                var repeat=observe(platform,session);assertFalse(repeat.reusesOwnedShape(platform,session));assertTrue(repeat.definition().sha256().isEmpty());assertFalse(platform.capture(session).ownedRelationAvailable("busydata","busydata",TABLE,true),"Partial evidence retains normal retirement instead of promoting a cached shape");assertEquals(1,fixture.jobs.list(session.id).size());
            }finally{session.lock.unlock();}
        }
    }
    @ParameterizedTest @ValueSource(strings={"MYSQL","MARIADB"})
    void unobservedRawSqlModeChangeCannotCertifySourceUnderCachedContext(String engine)throws Exception{
        try(var fixture=new EngineFixture(root,engine)){
            var session=fixture.open();seed(fixture,session);var platform=fixture.metadata.metadataPlatform();session.lock.lock();try{
                var before=platform.capture(session);String original=session.context.sqlMode();long revision=session.revision,context=session.contextRevision;
                try(var set=session.connection.prepareStatement("SET SESSION sql_mode=?")){set.setString(1,"ANSI_QUOTES");set.execute();}
                assertEquals(original,session.context.sqlMode());assertEquals(revision,session.revision);assertEquals(context,session.contextRevision);
                var stale=observe(platform,session);assertEquals(MetadataState.STALE,stale.state());assertFalse(stale.available());assertFalse(stale.definition().complete());assertTrue(stale.definition().sha256().isEmpty());assertFalse(platform.capture(session).ownedRelationAvailable("busydata","busydata",TABLE,true));assertTrue(before.ownedRelationAvailable("busydata","busydata",TABLE,true));assertEquals(1,fixture.jobs.list(session.id).size());
                // Reconciliation is explicit; the classifier never updates the
                // session's context or reruns the selected statement itself.
                session.refresh();var current=observe(platform,session);assertTrue(current.available());assertFalse(current.reusesOwnedShape(platform,session));acquire(fixture,session,current);assertTrue(observe(platform,session).reusesOwnedShape(platform,session));
            }finally{session.lock.unlock();}
        }
    }
    @ParameterizedTest @ValueSource(strings={"MYSQL","MARIADB"})
    void completeDefinitionAtNamesLevelNeverCertifiesUnacquiredColumns(String engine)throws Exception{
        try(var fixture=new EngineFixture(root,engine)){
            var session=fixture.open();seed(fixture,session);var platform=fixture.metadata.metadataPlatform();fixture.introspectionLevel(session,IntrospectionLevel.NAMES);session.lock.lock();try{
                var physical=observe(platform,session);assertTrue(physical.available());assertTrue(physical.definition().complete());assertFalse(physical.reusesOwnedShape(platform,session));acquire(fixture,session,physical);
                var names=platform.capture(session);assertTrue(names.ownedRelationAvailable("busydata","busydata",TABLE,false));assertFalse(names.ownedRelationAvailable("busydata","busydata",TABLE,true));var repeated=observe(platform,session);assertTrue(repeated.definition().complete());assertFalse(repeated.reusesOwnedShape(platform,session),"Full native source is no replacement for requested structural acquisition");assertFalse(platform.capture(session).complete(new MetadataScope("busydata","busydata",TABLE,ObjectKind.COLUMN),IntrospectionLevel.STRUCTURE));assertEquals(1,fixture.jobs.list(session.id).size());
            }finally{session.lock.unlock();}
        }
    }

}
