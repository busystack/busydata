package io.busystack.busydata;

import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import java.nio.file.Path;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

/** Synthetic owned facts on real PostgreSQL physical sessions and real public publication fences. */
class OwnedMetadataPublicationRaceIT {
    @TempDir Path root;
    private static final IdentifierRules RULES=new IdentifierRules(Engine.POSTGRESQL,0);
    private static final String SCHEMA="synthetic_owned_scope",NAME="owned_rows";
    private static MetadataScope scope(String catalog){return new MetadataScope(catalog,SCHEMA,"",ObjectKind.TABLE,NAME,true,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED);}
    private static SchemaObject object(String catalog,String name,String nativeId,boolean temporary){
        var value=SchemaObject.newBuilder().setCatalog(catalog).setSchema(SCHEMA).setName(name).setKind(ObjectKind.TABLE).setSubtype(ObjectSubtype.ORDINARY_TABLE).putProperties("nativeId",nativeId);
        if(temporary)value.putProperties("temporary","true");return value.build();
    }
    private static MetadataPlatform.Branch branch(MetadataScope scope,io.busystack.busydata.sessions.SessionRegistry.Session owner,SchemaObject... values){
        return new MetadataPlatform.Branch(List.of(values),new MetadataCoverage(scope,IntrospectionLevel.STRUCTURE,MetadataState.AVAILABLE,true,"synthetic-owned-fixture",owner.revision,owner.contextRevision,System.currentTimeMillis(),""));
    }
    private static MetadataSnapshot owned(MetadataPlatform platform,io.busystack.busydata.sessions.SessionRegistry.Session owner,Map<MetadataScope,MetadataPlatform.Branch> branches)throws Exception{
        owner.lock.lock();try(var maintenance=platform.ownedMaintenance(owner)){return platform.publishTemporaryInventory(owner,platform.beginRefresh(owner),RULES,branches);}finally{owner.lock.unlock();}
    }
    private static MetadataObject one(MetadataSnapshot snapshot,String catalog){var values=snapshot.resolve(catalog,SCHEMA,ObjectKind.TABLE,"",NAME,true);assertEquals(1,values.size());return values.getFirst();}
    @ParameterizedTest @ValueSource(strings={"creation","removal"})
    void aPreparedDurableCandidateCannotOverwriteANewerOwnedTransition(String transition)throws Exception{
        var armed=new AtomicBoolean();var prepared=new CountDownLatch(1);var release=new CountDownLatch(1);
        var platform=MetadataPublicationTestAccess.instrumented(root.resolve("publication"),()->{
            if(!armed.compareAndSet(true,false))return;prepared.countDown();try{if(!release.await(10,TimeUnit.SECONDS))throw new AssertionError("Missing controlled candidate release");}
            catch(InterruptedException failure){Thread.currentThread().interrupt();throw new AssertionError(failure);}
        });
        try(var fixture=new EngineFixture(root.resolve("physical-owner"),"POSTGRESQL");var workers=Executors.newFixedThreadPool(2)){
            var owner=fixture.open();var observer=fixture.open();String catalog=owner.context.catalog();var exact=scope(catalog);var permanent=object(catalog,NAME,"1",false);var temporary=object(catalog,NAME,"2",true);
            platform.publish(observer,platform.beginRefresh(observer),RULES,Map.of(exact,branch(exact,observer,permanent)),false);
            var original=platform.publishedSnapshot(observer);var heldPermanent=one(original,catalog);
            var heldOwned=transition.equals("removal")?owned(platform,owner,Map.of(exact,branch(exact,owner,temporary))):null;
            var global=new MetadataScope(catalog,SCHEMA,"",ObjectKind.TABLE);var added=object(catalog,"older_global_candidate","3",false);long ticket=platform.beginRefresh(observer);armed.set(true);
            var candidate=workers.submit(()->{try{platform.publish(observer,ticket,RULES,Map.of(global,branch(global,observer,permanent,added)),false);return (Throwable)null;}catch(Throwable failure){return failure;}});
            try{
                assertTrue(prepared.await(5,TimeUnit.SECONDS),"The durable candidate must already be built and own its writer gate");
                var accepted=workers.submit(()->owned(platform,owner,transition.equals("creation")?Map.of(exact,branch(exact,owner,temporary)):Map.of())).get(2,TimeUnit.SECONDS);
                assertFalse(candidate.isDone(),"Owned publication must complete before the durable candidate is released");
                if(transition.equals("creation"))assertEquals(owner.id,one(accepted,catalog).identity().sessionOwner());
                else {assertEquals(heldPermanent.identity().key(),one(accepted,catalog).identity().key());assertTrue(one(accepted,catalog).identity().sessionOwner().isEmpty());assertEquals(0,platform.sessionOverlayCount(),"A fully retired inventory must not retain a duplicate durable model");}
                release.countDown();assertInstanceOf(MetadataPlatform.SupersededRefresh.class,candidate.get(5,TimeUnit.SECONDS),"A prepared candidate may be rejected, but cannot revive an older overlay");
                assertSame(heldPermanent,one(platform.publishedSnapshot(observer),catalog));assertTrue(platform.publishedSnapshot(observer).resolve(catalog,SCHEMA,ObjectKind.TABLE,"","older_global_candidate",true).isEmpty());
                assertEquals(one(accepted,catalog).identity().key(),one(platform.capture(owner),catalog).identity().key());
                assertSame(heldPermanent,one(original,catalog));
                if(heldOwned!=null)assertEquals(owner.id,one(heldOwned,catalog).identity().sessionOwner(),"A held old owned snapshot stays immutable after removal");
            }finally{release.countDown();candidate.get(10,TimeUnit.SECONDS);}
        }finally{release.countDown();}
    }
    @ParameterizedTest @ValueSource(strings={"cancellation","session-end","configuration","native-barrier","resolution"})
    void preparedOwnedFactsCannotOutliveTheirPhysicalAndPolicyAuthority(String race)throws Exception{
        var armed=new AtomicBoolean();var prepared=new CountDownLatch(1);var release=new CountDownLatch(1);
        var platform=MetadataPublicationTestAccess.instrumented(root.resolve("publication"),()->{
            if(!armed.compareAndSet(true,false))return;prepared.countDown();try{if(!release.await(10,TimeUnit.SECONDS))throw new AssertionError("Missing controlled owned candidate release");}
            catch(InterruptedException failure){Thread.currentThread().interrupt();throw new AssertionError(failure);}
        });
        try(var fixture=new EngineFixture(root.resolve("physical-owner"),"POSTGRESQL");var workers=Executors.newFixedThreadPool(2)){
            var owner=fixture.open();var observer=fixture.open();String catalog=owner.context.catalog();var exact=scope(catalog);var permanent=object(catalog,NAME,"1",false);var temporary=object(catalog,NAME,"2",true);var rejected=object(catalog,NAME,"3",true);
            platform.publish(observer,platform.beginRefresh(observer),RULES,Map.of(exact,branch(exact,observer,permanent)),false);
            var old=owned(platform,owner,Map.of(exact,branch(exact,owner,temporary)));var held=one(old,catalog);
            var cancelled=io.grpc.Context.current().withCancellation();armed.set(true);
            var candidate=workers.submit(cancelled.wrap(()->{try{return (Object)owned(platform,owner,Map.of(exact,branch(exact,owner,rejected)));}catch(Throwable failure){return failure;}}));
            MetadataPlatform.ExternalMutation mutation=null;
            try{
                assertTrue(prepared.await(5,TimeUnit.SECONDS));
                switch(race){
                    case "cancellation"->cancelled.cancel(null);
                    case "session-end"->workers.submit(owner::close).get(2,TimeUnit.SECONDS);
                    case "configuration"->{
                        var policy=platform.configuration(observer);var changed=new MetadataConfiguration(policy.revision()+1,policy.includedCatalogs(),policy.excludedCatalogs(),policy.includedSchemas(),policy.excludedSchemas(),policy.systemObjects(),policy.kinds(),policy.includePatterns(),List.of(NAME),policy.defaultLevel(),policy.scopeLevels());
                        workers.submit(()->{platform.configure(observer,changed);return true;}).get(2,TimeUnit.SECONDS);
                    }
                    case "native-barrier"->mutation=workers.submit(()->{observer.lock.lock();try{return platform.beginExternalMutation(observer);}finally{observer.lock.unlock();}}).get(2,TimeUnit.SECONDS);
                    case "resolution"->platform.markSessionResolutionUnknown(owner,"A newer controlled physical resolution epoch retired the prepared owned view");
                    default->throw new AssertionError("Unknown owned publication race");
                }
                release.countDown();var outcome=candidate.get(5,TimeUnit.SECONDS);assertInstanceOf(Throwable.class,outcome,"Old owned candidates cannot adopt new authority or silently retry");
                if(race.equals("cancellation"))assertInstanceOf(CancellationException.class,outcome);
                assertEquals(held.identity().key(),one(old,catalog).identity().key());assertEquals(owner.id,one(old,catalog).identity().sessionOwner());
                assertTrue(platform.publishedSnapshot(observer).identities().values().stream().noneMatch(value->!value.identity().sessionOwner().isEmpty()),"Owned facts never enter the durable source");
                if(!owner.physicalEnded())assertTrue(platform.capture(owner).identities().values().stream().noneMatch(value->value.identity().nativeKey().equals("3")),"The rejected owned identity cannot appear after its authority changed");
                else assertEquals(0,platform.sessionOverlayCount());
            }finally{
                release.countDown();if(mutation!=null){observer.lock.lock();try{platform.finishExternalMutation(observer,mutation,false,false);}finally{observer.lock.unlock();}}
                candidate.get(10,TimeUnit.SECONDS);cancelled.close();
            }
        }finally{release.countDown();}
    }
    @Test void unrelatedPhysicalOwnersCanPublishWithoutRetiringEachOthersCapturedContext()throws Exception{
        var armed=new AtomicBoolean();var prepared=new CountDownLatch(1);var release=new CountDownLatch(1);
        var platform=MetadataPublicationTestAccess.instrumented(root.resolve("publication"),()->{if(armed.compareAndSet(true,false)){prepared.countDown();try{if(!release.await(10,TimeUnit.SECONDS))throw new AssertionError("Missing owner release");}catch(InterruptedException failure){Thread.currentThread().interrupt();throw new AssertionError(failure);}}});
        try(var fixture=new EngineFixture(root.resolve("physical-owner"),"POSTGRESQL");var workers=Executors.newFixedThreadPool(2)){
            var first=fixture.open();var second=fixture.open();String catalog=first.context.catalog();var exact=scope(catalog);var permanent=object(catalog,NAME,"1",false);
            platform.publish(second,platform.beginRefresh(second),RULES,Map.of(exact,branch(exact,second,permanent)),false);var held=platform.capture(second);armed.set(true);
            var paused=workers.submit(()->owned(platform,first,Map.of(exact,branch(exact,first,object(catalog,NAME,"2",true)))));
            try{assertTrue(prepared.await(5,TimeUnit.SECONDS));var accepted=workers.submit(()->owned(platform,second,Map.of(exact,branch(exact,second,object(catalog,NAME,"3",true))))).get(2,TimeUnit.SECONDS);assertEquals(second.id,one(accepted,catalog).identity().sessionOwner());assertFalse(paused.isDone());release.countDown();var firstView=paused.get(5,TimeUnit.SECONDS);assertEquals(first.id,one(firstView,catalog).identity().sessionOwner());assertEquals(second.id,one(platform.capture(second),catalog).identity().sessionOwner());assertSame(one(held,catalog),one(platform.publishedSnapshot(second),catalog));}
            finally{release.countDown();paused.get(10,TimeUnit.SECONDS);}
        }finally{release.countDown();}
    }
    @Test void pendingOrdinaryDdlWithholdsQualifiedStructureOnlyFromItsOwnerUntilResolution()throws Exception{
        var platform=new MetadataPlatform();try(var fixture=new EngineFixture(root,"POSTGRESQL")){
            var owner=fixture.open();var other=fixture.open();String catalog=owner.context.catalog();var tableScope=new MetadataScope(catalog,"public","",ObjectKind.TABLE,"pending_rows",true,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED);var columnScope=new MetadataScope(catalog,"public","pending_rows",ObjectKind.COLUMN);
            var table=SchemaObject.newBuilder().setCatalog(catalog).setSchema("public").setName("pending_rows").setKind(ObjectKind.TABLE).build();var column=SchemaObject.newBuilder().setCatalog(catalog).setSchema("public").setTable("pending_rows").setName("old_column").setKind(ObjectKind.COLUMN).build();
            platform.publish(other,platform.beginRefresh(other),RULES,Map.of(tableScope,branch(tableScope,other,table),columnScope,branch(columnScope,other,column)),false);var captured=platform.capture(owner);assertTrue(captured.complete(columnScope,IntrospectionLevel.STRUCTURE));
            owner.lock.lock();try{platform.markSessionResolutionUnknown(owner,"Uncommitted public ALTER changed columns");platform.markSessionStale(owner,"Uncommitted public ALTER requires transaction resolution");}finally{owner.lock.unlock();}
            var pending=platform.capture(owner);assertTrue(pending.relationLookupAvailable(catalog,"public","pending_rows",true),"Qualified name visibility alone is not structural proof");assertEquals(MetadataState.STALE,pending.coverage(columnScope).orElseThrow().state());assertFalse(pending.complete(columnScope,IntrospectionLevel.STRUCTURE));assertTrue(platform.capture(other).complete(columnScope,IntrospectionLevel.STRUCTURE));assertTrue(captured.complete(columnScope,IntrospectionLevel.STRUCTURE));
            owner.lock.lock();try(var maintenance=platform.ownedMaintenance(owner)){platform.discardPendingStructure(owner);}finally{owner.lock.unlock();}
            assertTrue(platform.capture(owner).complete(columnScope,IntrospectionLevel.STRUCTURE));assertEquals(0,platform.sessionOverlayCount());assertEquals(MetadataState.STALE,pending.coverage(columnScope).orElseThrow().state(),"Old captured views cannot adopt later transaction resolution");
        }
    }
}
