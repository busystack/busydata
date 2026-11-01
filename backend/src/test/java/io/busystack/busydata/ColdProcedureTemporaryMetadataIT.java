package io.busystack.busydata;

import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import java.lang.reflect.*;
import java.nio.file.Path;
import java.sql.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;
import java.util.stream.Stream;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;
import static org.junit.jupiter.api.Assertions.*;

/** MySQL cannot inventory a temporary table created inside an opaque routine.
 * Native pre-stream classification must work before any durable catalog exists. */
class ColdProcedureTemporaryMetadataIT {
    @TempDir Path root;
    static Stream<Arguments> cases(){return Stream.of(0,1).flatMap(mode->Stream.of(Arguments.of(mode,false),Arguments.of(mode,true)));}
    private static Object invoke(Object target,Method method,Object[] args)throws Throwable{try{return method.invoke(target,args);}catch(InvocationTargetException failure){throw failure.getCause();}}
    @ParameterizedTest @MethodSource("cases")
    void firstSelectionAcquiresOnlyItsVerifiedNativeTemporaryIdentity(int mode,boolean qualified)throws Exception{
        var corpusBlocked=new CountDownLatch(1);var releaseCorpus=new CountDownLatch(1);var blockOnce=new AtomicBoolean(true);var corpusReads=new AtomicInteger();var showReads=new AtomicInteger();var ownerConnection=new AtomicBoolean();
        try(var fixture=new EngineFixture(root,"MYSQL",(adapter,request,port)->{
            var nativeConnection=adapter.connect(request,port);boolean command=!request.getProfile().getReadOnly()&&ownerConnection.compareAndSet(false,true);
            return (Connection)Proxy.newProxyInstance(Connection.class.getClassLoader(),new Class[]{Connection.class},(proxy,method,args)->{
                if(method.getName().equals("prepareStatement")&&args[0] instanceof String sql&&sql.startsWith("SELECT j.ord,j.ch")){
                    assertFalse(command,"The command owner never acquires the character corpus");corpusReads.incrementAndGet();
                    if(blockOnce.compareAndSet(true,false)){corpusBlocked.countDown();if(!releaseCorpus.await(10,TimeUnit.SECONDS))throw new SQLTimeoutException("Controlled native map release was not received");}
                }
                if(command&&method.getName().equals("prepareStatement")&&args[0] instanceof String sql&&sql.startsWith("SHOW CREATE TABLE "))showReads.incrementAndGet();
                return invoke(nativeConnection,method,args);
            });
        },container->container.withCommand("--character-set-server=utf8mb4","--collation-server=utf8mb4_unicode_ci","--lower-case-table-names="+mode))){
            var owner=fixture.open();fixture.introspectionLevel(owner,IntrospectionLevel.STRUCTURE);var platform=fixture.metadata.metadataPlatform();var original=platform.publishedSnapshot(owner);assertTrue(original.identities().isEmpty());assertFalse(original.rules().complete());
            owner.lock.lock();try(var ddl=owner.connection.createStatement()){ddl.execute("CREATE PROCEDURE make_cold_temp() BEGIN CREATE TEMPORARY TABLE `MiXeD`(id INTEGER PRIMARY KEY,n INTEGER); INSERT INTO `MiXeD` VALUES(1,7); END");}finally{owner.lock.unlock();}
            fixture.execute(owner,"CALL make_cold_temp()");assertTrue(corpusBlocked.await(5,TimeUnit.SECONDS),"The first durable refresh is held before acquiring native evidence");assertFalse(platform.publishedSnapshot(owner).rules().complete(),"No fixture warm-up may hide the cold pre-stream path");
            String requested=mode==0?"MiXeD":"MIXED";String source=qualified?owner.adapter.table("busydata","busydata",requested):owner.adapter.quote(requested);int showsBefore=showReads.get();
            var selected=fixture.execute(owner,"SELECT id,n FROM "+source);assertFalse(releaseCorpus.await(1,TimeUnit.MILLISECONDS));assertEquals(JobState.COMPLETED,selected.state,selected.info().toString());assertTrue(corpusReads.get()>=2,"A second independent metadata slot bootstraps the empty source while the old refresh is held");assertEquals(showsBefore+1,showReads.get(),"The observed SHOW is not retried to recapture a revision");
            var result=fixture.results.get(selected.info().getResults(0).getResultId());assertEquals("7",result.read(0).getValues(1).getSignedInteger());assertFalse(result.metadataProof().capturedStructure(),"Temporary selection never inherits durable editable provenance");
            var current=platform.capture(owner);var names=current.resolve("busydata","busydata",ObjectKind.TABLE,"",requested,true);assertEquals(1,names.size());var identity=names.getFirst().identity();assertEquals(owner.id,identity.sessionOwner());assertEquals(mode==0?"MiXeD":"mixed",identity.name(),"Owned identity follows the native CREATE header, never SHOW's alias field");assertEquals("AVAILABLE",names.getFirst().properties().get("nativeNameAvailability"));assertEquals("OWNED_NATIVE_CREATE_HEADER",names.getFirst().properties().get("nativeNameProvenance"));assertTrue(names.getFirst().source().isEmpty(),"Cold structural acquisition does not retain full native source");assertEquals(1,current.identities().values().stream().filter(value->value.identity().kind()==ObjectKind.TABLE&&value.identity().sessionOwner().equals(owner.id)&&current.rules().matches(ObjectKind.TABLE,value.identity().name(),requested,true)).count(),"Raw input spelling must not create a second logical temp identity");
            assertTrue(current.complete(new MetadataScope("busydata","busydata",identity.name(),ObjectKind.COLUMN),IntrospectionLevel.STRUCTURE));assertTrue(platform.publishedSnapshot(owner).identities().isEmpty(),"Owned columns and table never become durable cache data");assertFalse(original.rules().complete());assertTrue(original.identities().isEmpty());
            var later=fixture.execute(owner,"SELECT id,n FROM "+owner.adapter.quote("MiXeD"));assertEquals(JobState.COMPLETED,later.state);var after=platform.capture(owner);assertEquals(identity.key(),after.resolve("busydata","busydata",ObjectKind.TABLE,"","MiXeD",true).getFirst().identity().key());assertEquals(mode==0?"MiXeD":"mixed",identity.name(),"A held immutable identity cannot follow later reference spelling");
            releaseCorpus.countDown();
        }finally{releaseCorpus.countDown();}
    }
}
