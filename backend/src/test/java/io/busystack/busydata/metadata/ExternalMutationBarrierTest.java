package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.rpc.WorkbenchFailure;
import java.util.*;
import java.util.concurrent.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

/** The exact source coordination primitives, without JDBC, threads owned by a
 * server, a second metadata model, or a fabricated native acceptance claim. */
class ExternalMutationBarrierTest {
    private static final MetadataScope SCOPE=new MetadataScope("db","db","t",ObjectKind.COLUMN);
    private static MetadataPlatform.Source source(){
        var rules=io.busystack.busydata.NativeCaseFixtures.rules(Engine.MYSQL,0);
        var column=MetadataObject.from("source","profile","",rules,SchemaObject.newBuilder().setKind(ObjectKind.COLUMN).setCatalog("db").setSchema("db").setTable("t").setName("id").build(),IntrospectionLevel.STRUCTURE,1,1);
        var coverage=new MetadataCoverage(SCOPE,IntrospectionLevel.STRUCTURE,MetadataState.AVAILABLE,true,"shape",1,1,1,"");
        return new MetadataPlatform.Source(new MetadataSnapshot("source","profile",1,1,1,rules,List.of(column),Map.of(SCOPE,coverage)));
    }
    private static MetadataPlatform.ExternalMutation begin(MetadataPlatform.Source source,String session){synchronized(source){return MetadataPlatform.beginExternalMutation(source,"source",session);}}
    static MetadataPlatform.QueuedRefreshOwner acknowledgement(MetadataPlatform.Source source,String session)throws Exception{
        // Own private value constructors are read solely to supply immutable
        // scalar fixtures; production can create these only through Platform.
        var publication=MetadataPlatform.PublicationRevision.class.getDeclaredConstructor(String.class,long.class,long.class);publication.setAccessible(true);
        var queued=MetadataPlatform.QueuedRefreshOwner.class.getDeclaredConstructor(MetadataPlatform.PublicationRevision.class,String.class,long.class,long.class,long.class,long.class,long.class);queued.setAccessible(true);
        return queued.newInstance(publication.newInstance("source",source.owner,source.snapshot.get().revision()),session,source.tickets.get(),source.requestEpoch,1,1,1);
    }
    private static MetadataPlatform.ExternalCompletion finish(MetadataPlatform.Source source,MetadataPlatform.ExternalMutation token,String session,boolean started,boolean acknowledged){
        synchronized(source){return MetadataPlatform.finishExternalMutation(source,token,started,acknowledged,()->{try{return acknowledgement(source,session);}catch(Exception failure){throw new AssertionError(failure);}});}
    }
    private static void stale(Runnable operation){var failure=assertThrows(WorkbenchFailure.class,operation::run);assertEquals(WorkbenchFailure.Reason.STALE,failure.reason());}

    @Test void beforeLaunchInvalidationSharesIndexesAndNeverChangesHeldSnapshot(){
        var source=source();var held=source.snapshot.get();long ticket=MetadataPlatform.beginExplicitAcquisition(source,false);
        var token=begin(source,"a");assertEquals(1,source.externalActive);
        assertFalse(source.snapshot.get().complete(SCOPE,IntrospectionLevel.STRUCTURE));assertTrue(held.complete(SCOPE,IntrospectionLevel.STRUCTURE));assertSame(held.identities(),source.snapshot.get().identities());
        stale(()->MetadataPlatform.checkExternalPublication(source,ticket));stale(()->MetadataPlatform.beginExplicitAcquisition(source,false));
        finish(source,token,"a",false,false);assertEquals(0,source.externalActive);
        stale(()->MetadataPlatform.checkExternalPublication(source,ticket));assertFalse(source.snapshot.get().complete(SCOPE,IntrospectionLevel.STRUCTURE));
    }
    @Test void leasesAreBoundedAndSpawnFailureReleasesOnlyItsOwnLease(){
        var source=source();var a=begin(source,"a");var b=begin(source,"b");stale(()->begin(source,"c"));
        finish(source,b,"b",false,false);assertEquals(1,source.externalActive);assertEquals(1,source.externalMutations.size());
        finish(source,b,"b",false,false);assertEquals(1,source.externalActive);
        finish(source,a,"a",false,false);assertEquals(0,source.externalActive);assertFalse(source.externalRequiresExplicit);
    }
    @Test void bothSuccessfulRestoresUseOnlyTheFinalActualAcknowledgement(){
        var source=source();var a=begin(source,"a");var b=begin(source,"b");
        var first=finish(source,a,"a",true,true);assertFalse(first.ready());assertNotNull(first.acknowledgement());
        var last=finish(source,b,"b",true,true);assertTrue(last.ready());assertNotSame(first.acknowledgement(),last.acknowledgement());
        assertFalse(MetadataPlatform.externalWaveReady(source,first.wave(),first.acknowledgement()));assertTrue(MetadataPlatform.externalWaveReady(source,last.wave(),last.acknowledgement()));
    }
    @Test void anUnknownStartedRestorePoisonsSuccessInEitherTerminalOrder(){
        for(boolean unknownFirst:List.of(false,true)){
            var source=source();var a=begin(source,"a");var b=begin(source,"b");
            if(unknownFirst){finish(source,b,"b",true,false);assertFalse(finish(source,a,"a",true,true).ready());}
            else{assertNotNull(finish(source,a,"a",true,true).acknowledgement());assertFalse(finish(source,b,"b",true,false).ready());}
            assertEquals(0,source.externalActive);assertTrue(source.externalRequiresExplicit);assertNull(source.externalAck);stale(()->MetadataPlatform.checkQueuedAcquisition(source));
        }
    }
    @Test void successfulAckSurvivesOnlyNonmutatingPreparedReleaseWithoutNewOwner(){
        var source=source();var a=begin(source,"a");var b=begin(source,"b");var ack=finish(source,a,"a",true,true);
        long ticket=source.tickets.get(),revision=source.snapshot.get().revision();var released=finish(source,b,"b",false,false);
        assertTrue(released.ready());assertSame(ack.acknowledgement(),released.acknowledgement());assertEquals(ticket,source.tickets.get());assertEquals(revision,source.snapshot.get().revision());
    }
    @Test void newerExplicitRequestRetiresDeferredAckEvenWhenRefusedBeforeJdbc(){
        var source=source();var a=begin(source,"a");var b=begin(source,"b");var ack=finish(source,a,"a",true,true);
        stale(()->MetadataPlatform.beginExplicitAcquisition(source,false));var released=finish(source,b,"b",false,false);
        assertFalse(released.ready());assertNull(released.acknowledgement());assertFalse(MetadataPlatform.externalWaveReady(source,ack.wave(),ack.acknowledgement()));
    }
    @Test void acquisitionCompletedBeforeLaunchCannotPublishAcrossTheBarrier()throws Exception{
        var source=source();long ticket=MetadataPlatform.beginExplicitAcquisition(source,false);var acquired=new CountDownLatch(1);var release=new CountDownLatch(1);
        try(var worker=Executors.newSingleThreadExecutor()){
            var publication=worker.submit(()->{acquired.countDown();try{if(!release.await(5,TimeUnit.SECONDS))throw new AssertionError("Missing deterministic release");}catch(InterruptedException failure){throw new AssertionError(failure);}synchronized(source){MetadataPlatform.checkExternalPublication(source,ticket);}});
            assertTrue(acquired.await(5,TimeUnit.SECONDS));var token=begin(source,"restore");release.countDown();
            var failed=assertThrows(ExecutionException.class,()->publication.get(5,TimeUnit.SECONDS));assertInstanceOf(WorkbenchFailure.class,failed.getCause());assertEquals(WorkbenchFailure.Reason.STALE,((WorkbenchFailure)failed.getCause()).reason());
            finish(source,token,"restore",false,false);stale(()->MetadataPlatform.checkExternalPublication(source,ticket));
        }finally{release.countDown();}
    }
    @Test void incompleteOrBackgroundPublicationCannotClearUnknownOutcome(){
        var source=source();finish(source,begin(source,"restore"),"restore",true,false);stale(()->MetadataPlatform.checkQueuedAcquisition(source));
        MetadataPlatform.explicitPublication(source,false,true);stale(()->MetadataPlatform.checkQueuedAcquisition(source));
        MetadataPlatform.explicitPublication(source,true,false);stale(()->MetadataPlatform.checkQueuedAcquisition(source));
        long ticket=MetadataPlatform.beginExplicitAcquisition(source,false);MetadataPlatform.checkExternalPublication(source,ticket);MetadataPlatform.explicitPublication(source,true,true);MetadataPlatform.checkQueuedAcquisition(source);
    }
    @Test void proofCapturedBeforeRestoreCannotBePublishedDuringOrAfterItsWave(){
        var source=source();var fence=new MetadataPlatform.ProofFence("source",source.owner,source.proofEpoch);
        var proof=new RetainedMetadataProof("source",1,1,"db","db","t","table","generation",Map.of(1,new RetainedMetadataProof.ColumnProof("column","","INT","shape")),MetadataState.AVAILABLE,"");
        assertSame(proof,MetadataPlatform.admitProof(source,fence,proof));var token=begin(source,"restore");
        var during=MetadataPlatform.admitProof(source,fence,proof);assertEquals(MetadataState.STALE,during.state());assertFalse(during.capturedStructure());assertEquals("source",during.sourceKey());
        finish(source,token,"restore",true,true);assertFalse(MetadataPlatform.admitProof(source,fence,proof).available());assertFalse(during.samePhysicalStructure(proof));
    }
    @Test void recoverableStaleStructureCannotCrossTheNativeProofFence(){
        var source=source();var fence=new MetadataPlatform.ProofFence("source",source.owner,source.proofEpoch);
        var original=new RetainedMetadataProof("source",1,1,"db","db","t","table","generation",Map.of(1,new RetainedMetadataProof.ColumnProof("column","","INT","shape")),MetadataState.AVAILABLE,"");
        var rollback=original.invalidate("Ordinary console DDL");assertTrue(rollback.samePhysicalStructure(original));
        var token=begin(source,"restore");assertFalse(MetadataPlatform.admitProof(source,fence,rollback).capturedStructure());finish(source,token,"restore",false,false);
        assertFalse(MetadataPlatform.admitProof(source,fence,rollback).capturedStructure());assertTrue(rollback.capturedStructure(),"The original immutable evidence remains available only to its old reader");
    }

}
