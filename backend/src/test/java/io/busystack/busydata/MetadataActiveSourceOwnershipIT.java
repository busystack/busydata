package io.busystack.busydata;

import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.sessions.SessionRegistry;
import java.nio.file.*;
import java.util.*;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

/** Genuine pinned-engine catalog and physical-owner lifetimes. Closed distinct
 * profiles share one server/table; only their central metadata source keys differ. */
class MetadataActiveSourceOwnershipIT {
    private static final String TABLE="source_pin_rows";
    @TempDir Path root;
    private record Physical(long revision,long context,boolean autoCommit,TransactionState transaction,Object resolution){
        static Physical of(SessionRegistry.Session owner){return new Physical(owner.revision,owner.contextRevision,owner.autoCommit,owner.state,owner.context);}
        void unchanged(SessionRegistry.Session owner)throws Exception {
            assertEquals(revision,owner.revision);assertEquals(context,owner.contextRevision);assertEquals(autoCommit,owner.autoCommit);assertEquals(transaction,owner.state);assertEquals(resolution,owner.context);assertFalse(owner.physicalEnded());assertFalse(owner.connection.isClosed());
        }
    }
    private static SessionRegistry.Session open(EngineFixture fixture,Profile profile)throws Exception{return fixture.sessions.open(OpenRequest.newBuilder().setProfile(profile).setPassword("fixture").build());}
    private static void settled(MetadataPlatform platform,SessionRegistry.Session owner){
        var receipt=platform.cacheWriteReceipt(owner).orElseThrow();assertTrue(receipt.identity().matches(platform.publishedSnapshot(owner)));assertFalse(receipt.active());assertTrue(receipt.completed().isPresent());assertNull(receipt.completed().orElseThrow().failure());assertEquals(MetadataRepository.CommitOutcome.ACKNOWLEDGED,receipt.completed().orElseThrow().metrics().commitOutcome());assertEquals("AVAILABLE",platform.cacheState(owner));
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void activePhysicalOwnerKeepsOneRevisionDomainAcrossClosedSourceChurn(String engine)throws Exception {
        Path evidence=Files.createTempDirectory(Path.of("target"),"metadata-source-ownership-");var report=new LinkedHashMap<String,Object>();report.put("engine",engine);Throwable problem=null;
        try(var fixture=new EngineFixture(root,engine)){
            var profile=fixture.profile.toBuilder().setId("active-source-A").build();var owner=open(fixture,profile);var peer=open(fixture,profile);var platform=fixture.metadata.metadataPlatform();
            owner.lock.lock();try{try(var statement=owner.connection.createStatement()){statement.execute("CREATE TABLE "+owner.adapter.table("busydata",fixture.schema(),TABLE)+"(id INTEGER PRIMARY KEY,n INTEGER)");}owner.refresh();owner.advanceRevision();}finally{owner.lock.unlock();}
            fixture.warm(owner,TABLE);settled(platform,owner);var held=platform.publishedSnapshot(owner);assertTrue(held.revision()>0);assertFalse(held.identities().isEmpty());assertEquals(0,platform.sessionOverlayCount());
            assertSame(held,platform.publishedSnapshot(peer));assertEquals(owner.metadataSourceIdentity,peer.metadataSourceIdentity);
            fixture.sessions.close(peer.id,true);assertTrue(peer.physicalEnded());assertNull(peer.cleanupFailure());
            // Logical overlay retirement must never retire a live physical pin.
            platform.endSession(owner.id);var visible=platform.capture(owner);var state=Physical.of(owner);
            assertSame(held,platform.publishedSnapshot(owner));report.put("peerPhysicalEndPreservedLiveSource",true);report.put("logicalRetirementPreservedLiveSource",true);
            report.put("heldRevision",held.revision());report.put("heldConfigurationRevision",held.configurationRevision());report.put("heldCreatedUnixMs",held.createdUnixMs());report.put("sessionRevision",state.revision());report.put("contextRevision",state.context());
            var observations=new ArrayList<Map<String,Object>>();report.put("closedSourceChurn",observations);var identities=new HashSet<String>();identities.add(owner.metadataSourceIdentity);
            // B through I exceed the eight-Source cache limit while only A and
            // one churn connection are physically open at any instant.
            for(int index=1;index<=8;index++){
                var churn=open(fixture,fixture.profile.toBuilder().setId("closed-source-"+index).build());
                var row=new LinkedHashMap<String,Object>();row.put("ordinal",index);
                try{
                    assertTrue(identities.add(churn.metadataSourceIdentity));fixture.warm(churn,TABLE);settled(platform,churn);var published=platform.publishedSnapshot(churn);
                    row.put("revision",published.revision());row.put("configurationRevision",published.configurationRevision());row.put("createdUnixMs",published.createdUnixMs());
                    assertTrue(published.createdUnixMs()>held.createdUnixMs(),"Record a real oldest-A ordering before asserting the eviction regression");
                    var active=platform.publishedSnapshot(owner);row.put("activePublishedRevision",active.revision());row.put("sameActivePublishedReference",active==held);assertSame(held,active);assertSame(visible,platform.capture(owner));state.unchanged(owner);
                }finally{fixture.sessions.close(churn.id,true);row.put("physicalEnded",churn.physicalEnded());observations.add(row);}
                assertTrue(churn.physicalEnded());assertNull(churn.cleanupFailure());assertSame(held,platform.publishedSnapshot(owner));state.unchanged(owner);
            }
            report.put("closedSourceChurn",observations);report.put("distinctSourcesObserved",identities.size());assertEquals(9,identities.size());
            fixture.sessions.close(owner.id,true);assertTrue(owner.physicalEnded());assertNull(owner.cleanupFailure());report.put("ownerPhysicalEndObserved",true);
            // A is now the oldest inactive eligible Source. The next distinct
            // publication must evict it, rather than permanently pinning dead IDs.
            var next=open(fixture,fixture.profile.toBuilder().setId("after-owner-end-J").build());
            try{fixture.warm(next,TABLE);settled(platform,next);}finally{fixture.sessions.close(next.id,true);}
            var reopened=open(fixture,profile);
            try{
                assertNotEquals(owner.id,reopened.id);assertEquals(owner.metadataSourceIdentity,reopened.metadataSourceIdentity);
                var fresh=platform.publishedSnapshot(reopened);assertNotSame(held,fresh);assertEquals(0,fresh.revision());assertTrue(fresh.identities().isEmpty());var captured=platform.capture(reopened);assertTrue(captured.identities().isEmpty());report.put("postEvictionCapturedViewRevision",captured.revision());
                report.put("sameSourceKeyDifferentPhysicalOwner",true);report.put("postEvictionRevision",fresh.revision());report.put("postEvictionConfigurationRevision",fresh.configurationRevision());report.put("closedOwnerBecameEvictable",true);
            }finally{fixture.sessions.close(reopened.id,true);}
            assertTrue(held.revision()>0);assertFalse(held.identities().isEmpty());report.put("completed",true);
        }catch(Throwable failure){problem=failure;report.put("completed",false);throw failure;}
        finally{report.put("failed",problem!=null);Files.writeString(evidence.resolve("result.json"),new com.google.gson.GsonBuilder().setPrettyPrinting().create().toJson(report)+"\n");}
    }
}
