package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.results.ResultStore;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicBoolean;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

/** Real private spools and deterministic locks; no database or native result is fabricated. */
class ExternalProofRegistrationTest {
    @TempDir Path root;
    private static final Profile PROFILE=Profile.newBuilder().setId("profile").setEngine(Engine.MYSQL).build();
    private static final List<Column> COLUMNS=List.of(Column.newBuilder().setOrdinal(1).setName("id").setJdbcType(4).build());
    private static MetadataPlatform.Source source(){return new MetadataPlatform.Source(MetadataSnapshot.empty("source","profile",io.busystack.busydata.NativeCaseFixtures.rules(Engine.MYSQL,0)));}
    private static RetainedMetadataProof proof(){return new RetainedMetadataProof("source",1,1,"db","db","t","table","generation",Map.of(1,new RetainedMetadataProof.ColumnProof("column","","INT","shape")),MetadataState.AVAILABLE,"");}
    private static MetadataPlatform.ProofFence fence(MetadataPlatform.Source source){return new MetadataPlatform.ProofFence("source",source.owner,source.proofEpoch);}
    private static MetadataPlatform.ExternalMutation begin(MetadataPlatform.Source source){synchronized(source){return MetadataPlatform.beginExternalMutation(source,"source","restore");}}
    private static void release(MetadataPlatform.Source source,MetadataPlatform.ExternalMutation token){synchronized(source){MetadataPlatform.finishExternalMutation(source,token,false,false,()->null);}}
    @Test void registrationBeforeNativeStartCannotFinalizeOldProofAndRetainsExactRows()throws Exception{
        var source=source();var fence=fence(source);
        try(var store=new ResultStore(root,1024*1024)){
            var result=store.create(COLUMNS,PROFILE,"session");result.append(Row.newBuilder().addValues(Value.newBuilder().setSignedInteger("7")).build());
            try(var prepared=store.prepareProof(result,proof())){
                assertFalse(result.metadataProof().available());var token=begin(source);store.invalidateExternalMetadataProof("source","Native restore");
                MetadataPlatform.publishRetainedProof(source,fence,prepared);release(source,token);
                assertEquals(MetadataState.STALE,result.metadataProof().state());assertFalse(result.metadataProof().capturedStructure());assertTrue(result.columns.getFirst().getMetadataIdentity().isEmpty());
                assertEquals(1,result.rows());assertEquals("7",result.read(0).getValues(0).getSignedInteger());
            }
        }
    }
    @Test void finalizationBeforeNativeStartIsFoundByIrreversibleInvalidation()throws Exception{
        var source=source();
        try(var store=new ResultStore(root,1024*1024)){
            var result=store.create(COLUMNS,PROFILE,"session");
            try(var prepared=store.prepareProof(result,proof())){MetadataPlatform.publishRetainedProof(source,fence(source),prepared);}
            assertTrue(result.metadataProof().available());assertEquals("column",result.columns.getFirst().getMetadataIdentity());
            var token=begin(source);store.invalidateExternalMetadataProof("source","Native restore");release(source,token);
            assertFalse(result.metadataProof().available());assertFalse(result.metadataProof().samePhysicalStructure(proof()));assertSame(result,store.get(result.id));
        }
    }
    @Test void sourceFinalizationNeverWaitsBehindAnotherResultsFileAllocation()throws Exception{
        var source=source();var block=new AtomicBoolean();var inFile=new CountDownLatch(1);var releaseFile=new CountDownLatch(1);
        try(var store=new ResultStore(root,1024*1024,Files::deleteIfExists,path->{
            assertFalse(Thread.holdsLock(source),"Private file creation must never own Source");
            if(block.compareAndSet(true,false)){inFile.countDown();try{if(!releaseFile.await(5,TimeUnit.SECONDS))throw new java.io.IOException("Missing file allocation release");}catch(InterruptedException failure){Thread.currentThread().interrupt();throw new java.io.IOException(failure);}}
            Files.createFile(path);
        });var worker=Executors.newFixedThreadPool(2)){
            var result=store.create(COLUMNS,PROFILE,"session");
            try(var prepared=store.prepareProof(result,proof())){
                block.set(true);var other=worker.submit(()->store.create(COLUMNS,PROFILE,"other"));assertTrue(inFile.await(5,TimeUnit.SECONDS));
                try{
                    var admitted=worker.submit(()->MetadataPlatform.publishRetainedProof(source,fence(source),prepared));
                    assertSame(result,admitted.get(2,TimeUnit.SECONDS),"Source proof completion cannot wait on ResultStore's file-allocation monitor");
                    var active=worker.submit(()->begin(source));var token=active.get(2,TimeUnit.SECONDS);release(source,token);
                }finally{releaseFile.countDown();}
                other.get(5,TimeUnit.SECONDS);
            }
        }finally{releaseFile.countDown();}
    }
    @Test void unusedProofQuotaReleaseOccursOnlyAfterSourceMonitorIsReleased()throws Exception{
        var source=source();var fence=fence(source);var block=new AtomicBoolean();var inFile=new CountDownLatch(1);var releaseFile=new CountDownLatch(1);var completed=new CountDownLatch(1);
        try(var store=new ResultStore(root,1024*1024,Files::deleteIfExists,path->{
            if(block.compareAndSet(true,false)){inFile.countDown();try{if(!releaseFile.await(5,TimeUnit.SECONDS))throw new java.io.IOException("Missing file allocation release");}catch(InterruptedException failure){Thread.currentThread().interrupt();throw new java.io.IOException(failure);}}Files.createFile(path);
        });var worker=Executors.newFixedThreadPool(3)){
            var result=store.create(COLUMNS,PROFILE,"session");var prepared=store.prepareProof(result,proof());var token=begin(source);release(source,token);
            block.set(true);var other=worker.submit(()->store.create(COLUMNS,PROFILE,"other"));assertTrue(inFile.await(5,TimeUnit.SECONDS));
            var publication=worker.submit(()->{try(prepared){MetadataPlatform.publishRetainedProof(source,fence,prepared);completed.countDown();}return true;});
            try{
                assertTrue(completed.await(2,TimeUnit.SECONDS));var status=worker.submit(()->{synchronized(source){return source.externalActive;}});assertEquals(0,status.get(2,TimeUnit.SECONDS));
                assertFalse(publication.isDone(),"Only the outside-Source quota release may wait on another allocation");
            }finally{releaseFile.countDown();}
            assertTrue(publication.get(5,TimeUnit.SECONDS));other.get(5,TimeUnit.SECONDS);assertFalse(result.metadataProof().available());
        }finally{releaseFile.countDown();}
    }
    @Test void terminalBarrierRemainsUntilAvailableAndRecoverableStaleProofsAreRetired()throws Exception{
        var source=source();var entered=new CountDownLatch(1);var retire=new CountDownLatch(1);var retired=new CountDownLatch(1);var releaseLease=new CountDownLatch(1);
        try(var store=new ResultStore(root,1024*1024);var worker=Executors.newSingleThreadExecutor()){
            var available=store.create(COLUMNS,PROFILE,"a",proof());var rollback=store.create(COLUMNS,PROFILE,"b",proof().invalidate("Uncommitted console DDL"));
            assertTrue(rollback.metadataProof().samePhysicalStructure(proof()));var fence=fence(source);var token=begin(source);
            var terminal=worker.submit(()->{
                entered.countDown();if(!retire.await(5,TimeUnit.SECONDS))throw new AssertionError("Missing retirement release");
                var witnesses=store.retireExternalMetadataProofs("source","Native terminal outcome");retired.countDown();
                if(!releaseLease.await(5,TimeUnit.SECONDS))throw new AssertionError("Missing terminal lease release");
                synchronized(source){MetadataPlatform.finishExternalMutation(source,token,true,true,()->{try{return ExternalMutationBarrierTest.acknowledgement(source,"restore");}catch(Exception error){throw new AssertionError(error);}});}
                ResultStore.closeRetiredMetadataWitnesses(witnesses);return true;
            });
            try{
                assertTrue(entered.await(5,TimeUnit.SECONDS));assertEquals(1,source.externalActive);
                assertFalse(MetadataPlatform.admitProof(source,fence,proof()).capturedStructure());assertFalse(MetadataPlatform.admitProof(source,fence,rollback.metadataProof()).capturedStructure());
                retire.countDown();assertTrue(retired.await(5,TimeUnit.SECONDS));assertEquals(1,source.externalActive,"Metadata retirement precedes last-lease release");
                assertFalse(available.metadataProof().capturedStructure());assertFalse(rollback.metadataProof().capturedStructure());
                releaseLease.countDown();assertTrue(terminal.get(5,TimeUnit.SECONDS));assertEquals(0,source.externalActive);
                assertFalse(rollback.metadataProof().samePhysicalStructure(proof()));assertFalse(available.metadataProof().samePhysicalStructure(proof()));
            }finally{retire.countDown();releaseLease.countDown();}
        }finally{retire.countDown();releaseLease.countDown();}
    }

}
