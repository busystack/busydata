package io.busystack.busydata;

import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.rpc.WorkbenchFailure;
import java.nio.file.Path;
import java.lang.management.ManagementFactory;
import java.sql.DriverManager;
import java.util.concurrent.locks.LockSupport;
import org.junit.jupiter.api.Test;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

/** Synthetic facts, real public publication/fences, real physical PostgreSQL owner. */
class MetadataPublicationRaceIT {
    @TempDir Path root;
    private static final IdentifierRules RULES=new IdentifierRules(Engine.POSTGRESQL,0);
    @ParameterizedTest @ValueSource(strings={"invalidation","reservation","session-end","native-barrier","cancellation"})
    void preparedPublicationCannotOutliveTheAuthorityThatAdmittedIt(String race)throws Exception{
        var armed=new AtomicBoolean();var prepared=new CountDownLatch(1);var release=new CountDownLatch(1);
        var platform=MetadataPublicationTestAccess.instrumented(root.resolve("publication"),()->{
            if(!armed.compareAndSet(true,false))return;
            prepared.countDown();try{if(!release.await(10,TimeUnit.SECONDS))throw new AssertionError("Missing owned candidate release");}
            catch(InterruptedException problem){Thread.currentThread().interrupt();throw new AssertionError(problem);}
        });
        try(var fixture=new EngineFixture(root.resolve("physical-owner"),"POSTGRESQL");var workers=Executors.newFixedThreadPool(2)){
            var owner=fixture.open();var observer=fixture.open();String catalog=owner.context.catalog();var scope=new MetadataScope(catalog,"synthetic_scope","",ObjectKind.TABLE);
            var old=SchemaObject.newBuilder().setKind(ObjectKind.TABLE).setCatalog(catalog).setSchema("synthetic_scope").setName("retained_original").putProperties("nativeId","1").build();
            var initial=new MetadataCoverage(scope,IntrospectionLevel.STRUCTURE,MetadataState.AVAILABLE,true,"initial",owner.revision,owner.contextRevision,System.currentTimeMillis(),"");
            platform.publish(owner,platform.beginRefresh(owner),RULES,Map.of(scope,new MetadataPlatform.Branch(List.of(old),initial)),false);
            var original=platform.publishedSnapshot(observer);var retained=original.select(scope).getFirst();var oldAuthority=platform.publicationRevision(owner);
            var fresh=old.toBuilder().setName("candidate_only").putProperties("nativeId","2").build();var state=new MetadataCoverage(scope,IntrospectionLevel.STRUCTURE,MetadataState.AVAILABLE,true,"candidate",owner.revision,owner.contextRevision,System.currentTimeMillis(),"");var branch=Map.of(scope,new MetadataPlatform.Branch(List.of(old,fresh),state));
            var reservation=race.equals("reservation")?platform.reserveQueuedRefresh(owner,platform.queuedRefreshOwner(owner)):null;
            long ticket=reservation==null?platform.beginRefresh(owner):0;armed.set(true);
            var cancelled=io.grpc.Context.current().withCancellation();
            var candidate=workers.submit(cancelled.wrap(()->{try{if(reservation==null)platform.publish(owner,ticket,RULES,branch,false);else platform.publish(owner,reservation,RULES,branch,null);return (Throwable)null;}catch(Throwable failure){return failure;}}));
            MetadataPlatform.ExternalMutation token=null;
            try{
                assertTrue(prepared.await(5,TimeUnit.SECONDS),"The public production path must reach its prepared-candidate checkpoint");
                switch(race){
                    case "invalidation"->workers.submit(()->platform.markStaleIfRevision(owner,oldAuthority,"Explicit fixture invalidation")).get(2,TimeUnit.SECONDS);
                    case "reservation"->assertNotNull(workers.submit(()->platform.reserveRefresh(owner)).get(2,TimeUnit.SECONDS),"A newer explicit reservation must remain available during candidate preparation");
                    case "session-end"->workers.submit(owner::close).get(2,TimeUnit.SECONDS);
                    case "cancellation"->cancelled.cancel(null);
                    case "native-barrier"->{
                        token=workers.submit(()->{owner.lock.lock();try{return platform.beginExternalMutation(owner);}finally{owner.lock.unlock();}}).get(2,TimeUnit.SECONDS);
                        assertTrue(platform.externalMutationActive(observer));
                    }
                    default->throw new AssertionError("Unknown publication race");
                }
                release.countDown();var refused=candidate.get(5,TimeUnit.SECONDS);
                assertNotNull(refused,"A prepared publication must not silently rebuild or adopt authority after a conflict");
                if(race.equals("cancellation"))assertInstanceOf(CancellationException.class,refused);
                else assertTrue(refused instanceof IllegalStateException||refused instanceof WorkbenchFailure&&((WorkbenchFailure)refused).reason()==WorkbenchFailure.Reason.STALE,()->"Unexpected refusal type "+refused.getClass().getName());
                if(race.equals("reservation"))assertInstanceOf(MetadataPlatform.SupersededRefresh.class,refused);
                var after=platform.publishedSnapshot(observer);assertTrue(after.select(scope).stream().noneMatch(value->value.identity().name().equals("candidate_only")),"The losing candidate must never enter the real model");
                assertSame(retained,after.select(scope).stream().filter(value->value.identity().name().equals("retained_original")).findFirst().orElseThrow());
                if(race.equals("invalidation")||race.equals("native-barrier"))assertFalse(after.complete(scope,IntrospectionLevel.STRUCTURE),"A prepared candidate cannot erase actual invalidation");
                assertEquals(1,original.select(scope).size());assertTrue(original.complete(scope,IntrospectionLevel.STRUCTURE),"Held immutable facts remain unchanged");
                if(race.equals("cancellation")){assertEquals(original.revision(),after.revision());assertNotPersisted(root.resolve("publication"),"candidate_only");}
            }finally{
                release.countDown();if(token!=null){owner.lock.lock();try{platform.finishExternalMutation(owner,token,false,false);}finally{owner.lock.unlock();}}
                candidate.get(10,TimeUnit.SECONDS);cancelled.close();
            }
        }finally{release.countDown();}
    }
    private static void assertNotPersisted(Path cacheRoot,String name)throws Exception{
        try(var db=DriverManager.getConnection("jdbc:sqlite:"+cacheRoot.resolve("metadata_catalog.sqlite"));var query=db.prepareStatement("SELECT COUNT(*) FROM object WHERE name=?")){
            query.setString(1,name);try(var rows=query.executeQuery()){assertTrue(rows.next());assertEquals(0,rows.getLong(1),"Canceled metadata must never reach the real SQLite cache");}
        }
    }
    @Test void cancelledWriterAdmissionLeavesNoCandidateAndDoesNotWaitForTheOwningWriter()throws Exception{
        var armed=new AtomicBoolean();var prepared=new CountDownLatch(1);var release=new CountDownLatch(1);var calls=new AtomicInteger();Path cacheRoot=root.resolve("publication");
        var platform=MetadataPublicationTestAccess.instrumented(cacheRoot,()->{if(!armed.compareAndSet(true,false))return;calls.incrementAndGet();prepared.countDown();try{if(!release.await(10,TimeUnit.SECONDS))throw new AssertionError("Missing writer release");}catch(InterruptedException failure){Thread.currentThread().interrupt();throw new AssertionError(failure);}});
        try(var fixture=new EngineFixture(root.resolve("physical-owner"),"POSTGRESQL");var workers=Executors.newFixedThreadPool(2)){
            var owner=fixture.open();var scope=new MetadataScope(owner.context.catalog(),"synthetic_scope","",ObjectKind.TABLE);
            var original=SchemaObject.newBuilder().setKind(ObjectKind.TABLE).setCatalog(owner.context.catalog()).setSchema("synthetic_scope").setName("retained_original").putProperties("nativeId","1").build();
            var state=new MetadataCoverage(scope,IntrospectionLevel.STRUCTURE,MetadataState.AVAILABLE,true,"fixture",owner.revision,owner.contextRevision,System.currentTimeMillis(),"");
            platform.publish(owner,platform.beginRefresh(owner),RULES,Map.of(scope,new MetadataPlatform.Branch(List.of(original),state)),false);
            var accepted=original.toBuilder().setName("accepted_first").putProperties("nativeId","2").build();var rejected=original.toBuilder().setName("cancelled_only").putProperties("nativeId","3").build();long firstTicket=platform.beginRefresh(owner);armed.set(true);
            var first=workers.submit(()->platform.publish(owner,firstTicket,RULES,Map.of(scope,new MetadataPlatform.Branch(List.of(original,accepted),state)),false));
            var context=io.grpc.Context.current().withCancellation();Future<Throwable> second=null;
            try{
                assertTrue(prepared.await(5,TimeUnit.SECONDS));long secondTicket=platform.beginRefresh(owner);var waiter=new AtomicReference<Thread>();
                second=workers.submit(context.wrap(()->{waiter.set(Thread.currentThread());try{platform.publish(owner,secondTicket,RULES,Map.of(scope,new MetadataPlatform.Branch(List.of(original,rejected),state)),false);return (Throwable)null;}catch(Throwable failure){return failure;}}));
                long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(2);boolean entered=false;
                while(System.nanoTime()<deadline&&!second.isDone()){
                    var thread=waiter.get();var info=thread==null?null:ManagementFactory.getThreadMXBean().getThreadInfo(thread.threadId(),32);
                    if(info!=null&&(info.getThreadState()==Thread.State.WAITING||info.getThreadState()==Thread.State.TIMED_WAITING)&&Arrays.stream(info.getStackTrace()).anyMatch(frame->frame.getClassName().equals(MetadataPlatform.class.getName())&&frame.getMethodName().equals("enterWriter"))){entered=true;break;}LockSupport.parkNanos(TimeUnit.MILLISECONDS.toNanos(1));
                }
                assertTrue(entered,"The canceled request must actually be awaiting the real writer gate");context.cancel(null);
                assertInstanceOf(CancellationException.class,second.get(500,TimeUnit.MILLISECONDS),"Context cancellation must be acknowledged before the owning writer is released");
                assertFalse(first.isDone());assertEquals(1,calls.get(),"A canceled admission must not reach candidate preparation");assertNotPersisted(cacheRoot,"cancelled_only");
            }finally{release.countDown();context.close();first.get(10,TimeUnit.SECONDS);if(second!=null)second.get(10,TimeUnit.SECONDS);}
            assertTrue(platform.publishedSnapshot(owner).select(scope).stream().anyMatch(item->item.identity().name().equals("accepted_first")));assertNotPersisted(cacheRoot,"cancelled_only");
        }finally{release.countDown();}
    }

}
