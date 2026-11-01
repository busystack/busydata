package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.rpc.WorkbenchService;
import io.busystack.busydata.schema.Explorer;
import io.busystack.busydata.schema.RelatedRows;
import io.grpc.Status;
import io.grpc.stub.StreamObserver;
import java.nio.file.Path;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

class RelatedRowsIT {
    @TempDir Path root;
    static final class Reply<T> implements StreamObserver<T>{T value;Throwable error;public void onNext(T next){value=next;}public void onError(Throwable failure){error=failure;}public void onCompleted(){}}
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void compositeRelationshipsRemainTypedReviewedAndBoundToTheirSource(String engine)throws Exception {
        try(var f=new EngineFixture(root,engine)){
            var session=f.open();
            f.execute(session,"CREATE TABLE parent_rows(a INTEGER,b INTEGER,PRIMARY KEY(a,b)); CREATE TABLE child_rows(id INTEGER PRIMARY KEY,a INTEGER,b INTEGER,c INTEGER,d INTEGER,CONSTRAINT link_one FOREIGN KEY(a,b) REFERENCES parent_rows(a,b),CONSTRAINT link_two FOREIGN KEY(c,d) REFERENCES parent_rows(a,b)); INSERT INTO parent_rows VALUES(1,2),(3,4); INSERT INTO child_rows VALUES(10,1,2,3,4),(20,NULL,2,NULL,4)");
            var service=new WorkbenchService(f.sessions,f.jobs,f.results,f.metadata,f.safety,f.analysis,()->{});
            var context=Context.newBuilder().setInstanceId(service.instance).setProtocolVersion(WorkbenchService.PROTOCOL).setRequestId("metadata").build();
            var refreshed=new Reply<MetadataSettingsReply>();service.metadataSettings(MetadataSettingsRequest.newBuilder().setContext(context).setSessionId(session.id).setSessionRevision(session.revision).setContextRevision(session.contextRevision).setExpectedConfigurationRevision(1).setAction(MetadataSettingsAction.FULL_METADATA_REFRESH).build(),refreshed);assertNull(refreshed.error,()->String.valueOf(refreshed.error));
            String child=session.adapter.table(session.context.catalog(),f.schema(),"child_rows"),parent=session.adapter.table(session.context.catalog(),f.schema(),"parent_rows");
            var children=f.results.get(f.execute(session,"SELECT id,a,b,c,d FROM "+child+" ORDER BY id").info().getResults(0).getResultId());
            var parents=f.results.get(f.execute(session,"SELECT a,b FROM "+parent+" ORDER BY a").info().getResults(0).getResultId());
            var request=RelatedRowsRequest.newBuilder().setContext(context).setSessionId(session.id).setResultId(children.id).setDocumentId("related-document");
            var related=new Reply<RelatedRowsReply>();RelatedRowsTestRequests.call(service,session,request.build(),related);assertNull(related.error);assertEquals(2,related.value.getRelationshipsCount(),()->{
                var snapshot=f.metadata.metadataPlatform().capture(session);var current=io.busystack.busydata.metadata.RetainedMetadataProof.capture(snapshot,children.columns,session.targetProfile(),session.id,session.context);
                return "Outgoing availability="+related.value.getAvailability()+" retained="+children.metadataProof().state()+":"+children.metadataProof().availability()+" current="+current.state()+":"+current.availability()+" retainedGeneration="+children.metadataProof().nativeGeneration()+" currentGeneration="+current.nativeGeneration()+" tableIdentityEqual="+children.metadataProof().tableIdentity().equals(current.tableIdentity())+" generationEqual="+children.metadataProof().nativeGeneration().equals(current.nativeGeneration())+" columnsEqual="+children.metadataProof().columns().equals(current.columns())+" retainedColumnFingerprints="+children.metadataProof().columns().entrySet().stream().collect(java.util.stream.Collectors.toMap(java.util.Map.Entry::getKey,entry->entry.getValue().fingerprint()))+" currentColumnFingerprints="+current.columns().entrySet().stream().collect(java.util.stream.Collectors.toMap(java.util.Map.Entry::getKey,entry->entry.getValue().fingerprint()))+" outgoingIndexSize="+snapshot.outgoing("busydata",f.schema(),"child_rows").size()+" incomingParentIndexSize="+snapshot.incoming("busydata",f.schema(),"parent_rows").size()+" snapshot="+snapshot.revision()+" resolution="+snapshot.sessionResolution().state()+" scopes="+snapshot.coverage().values().stream().filter(c->c.scope().parent().equals("parent_rows")||c.scope().parent().equals("child_rows")).map(c->c.scope().kind()+":"+c.scope().parent()+":"+c.state()+":"+c.complete()+":"+c.limitation()).toList();
            });
            assertEquals(service.instance,related.value.getBackendInstance());assertEquals(session.profile.getId(),related.value.getProfileId());
            assertEquals(session.metadataSourceIdentity,related.value.getMetadataSourceIdentity());
            assertEquals(session.id,related.value.getSessionId());assertEquals(session.revision,related.value.getSessionRevision());assertEquals(session.contextRevision,related.value.getContextRevision());
            assertEquals(f.metadata.metadataPlatform().configuration(session).revision(),related.value.getMetadataConfigurationRevision());assertTrue(related.value.getSnapshotRevision()>0);
            for(var relationship:related.value.getRelationshipsList()){
                assertFalse(relationship.getIncoming());assertEquals("available",relationship.getAvailability());assertEquals(2,relationship.getBrowse().getConditionsCount());
                assertTrue(relationship.getBrowse().getConditionsList().stream().allMatch(c->c.getPredicate()==ValuePredicate.EQUAL&&c.getValue().hasSignedInteger()));
            }
            var browse=related.value.getRelationships(0).getBrowse();
            var forged=new Reply<Approval>();service.reviewBrowse(browse.toBuilder().setContext(context).setConditions(0,browse.getConditions(0).toBuilder().setValue(Value.newBuilder().setSignedInteger("999"))).build(),forged);assertEquals(Status.Code.INVALID_ARGUMENT,Status.fromThrowable(forged.error).getCode());
            int beforeReview=f.jobs.list("").size();
            var reviewed=new Reply<Approval>();service.reviewBrowse(browse.toBuilder().setContext(context).build(),reviewed);assertNull(reviewed.error,()->String.valueOf(reviewed.error));assertEquals(beforeReview,f.jobs.list("").size());
            var submitted=new Reply<JobInfo>();service.browse(browse.toBuilder().setContext(context).setApprovalToken(reviewed.value.getToken()).setExecutionId(UUID.randomUUID().toString()).build(),submitted);assertNull(submitted.error);var job=f.jobs.get(submitted.value.getJobId());EditingIT.await(job);assertEquals(JobState.COMPLETED,job.state);assertEquals(1,job.info().getResults(0).getFetchedRows());assertEquals(beforeReview+1,f.jobs.list("").size());
            var incoming=new Reply<RelatedRowsReply>();RelatedRowsTestRequests.call(service,session,request.setResultId(parents.id).build(),incoming);assertNull(incoming.error);assertEquals(2,incoming.value.getRelationshipsCount(),()->{
                var snapshot=f.metadata.metadataPlatform().capture(session);var current=io.busystack.busydata.metadata.RetainedMetadataProof.capture(snapshot,parents.columns,session.targetProfile(),session.id,session.context);
                return "Incoming availability="+incoming.value.getAvailability()+" retained="+parents.metadataProof().state()+":"+parents.metadataProof().availability()+" current="+current.state()+":"+current.availability()+" retainedGeneration="+parents.metadataProof().nativeGeneration()+" currentGeneration="+current.nativeGeneration()+" tableIdentityEqual="+parents.metadataProof().tableIdentity().equals(current.tableIdentity())+" generationEqual="+parents.metadataProof().nativeGeneration().equals(current.nativeGeneration())+" columnsEqual="+parents.metadataProof().columns().equals(current.columns())+" retainedColumnFingerprints="+parents.metadataProof().columns().entrySet().stream().collect(java.util.stream.Collectors.toMap(java.util.Map.Entry::getKey,entry->entry.getValue().fingerprint()))+" currentColumnFingerprints="+current.columns().entrySet().stream().collect(java.util.stream.Collectors.toMap(java.util.Map.Entry::getKey,entry->entry.getValue().fingerprint()))+" incomingIndexSize="+snapshot.incoming("busydata",f.schema(),"parent_rows").size()+" snapshot="+snapshot.revision()+" resolution="+snapshot.sessionResolution().state()+" scopes="+snapshot.coverage().values().stream().filter(c->c.scope().parent().equals("parent_rows")||c.scope().parent().equals("child_rows")).map(c->c.scope().kind()+":"+c.scope().parent()+":"+c.state()+":"+c.complete()+":"+c.limitation()).toList();
            });assertTrue(incoming.value.getRelationshipsList().stream().allMatch(RelatedRelationship::getIncoming));
            var nulls=new Reply<RelatedRowsReply>();RelatedRowsTestRequests.call(service,session,request.setResultId(children.id).setSourceRow(1).build(),nulls);assertTrue(nulls.value.getRelationshipsList().stream().allMatch(r->r.getAvailability().equals("null-key-component")&&!r.hasBrowse()));
            var invalid=new Reply<RelatedRowsReply>();RelatedRowsTestRequests.call(service,session,request.setSourceRow(999).build(),invalid);assertEquals(Status.Code.INVALID_ARGUMENT,Status.fromThrowable(invalid.error).getCode());
            var foreign=f.open();var wrongOwner=new Reply<RelatedRowsReply>();RelatedRowsTestRequests.call(service,foreign,request.setSessionId(foreign.id).setSourceRow(0).build(),wrongOwner);assertEquals(Status.Code.INVALID_ARGUMENT,Status.fromThrowable(wrongOwner.error).getCode());
            var beforeDisposal=new Reply<RelatedRowsReply>();RelatedRowsTestRequests.call(service,session,request.setSessionId(session.id).setSourceRow(0).build(),beforeDisposal);assertNull(beforeDisposal.error);
            var disposalBrowse=beforeDisposal.value.getRelationshipsList().stream().filter(item->item.getAvailability().equals("available")).findFirst().orElseThrow().getBrowse();
            var disposalReview=new Reply<Approval>();service.reviewBrowse(disposalBrowse.toBuilder().setContext(context).build(),disposalReview);assertNull(disposalReview.error);
            f.results.dispose(children.id);
            int beforeDisposedSubmit=f.jobs.list("").size();var disposedSubmit=new Reply<JobInfo>();service.browse(disposalBrowse.toBuilder().setContext(context).setApprovalToken(disposalReview.value.getToken()).setExecutionId(UUID.randomUUID().toString()).build(),disposedSubmit);assertNotNull(disposedSubmit.error);assertEquals(beforeDisposedSubmit,f.jobs.list("").size(),"A disposed retained key cannot create a browse job");
            var disposed=new Reply<RelatedRowsReply>();RelatedRowsTestRequests.call(service,session,request.build(),disposed);assertNotNull(disposed.error);
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void retainedKeysNeverAcquireRelationshipsFromAReplacementPhysicalTable(String engine)throws Exception {
        try(var f=new EngineFixture(root,engine)) {
            var session=f.open();var external=f.open();var explorer=new Explorer(f.metadata);f.introspectionLevel(session,io.busystack.busydata.metadata.IntrospectionLevel.NAMES);
            f.execute(session,"CREATE TABLE parent_before(id INTEGER PRIMARY KEY); CREATE TABLE parent_after(id INTEGER PRIMARY KEY); CREATE TABLE retained_child(id INTEGER PRIMARY KEY,parent_id INTEGER,CONSTRAINT retained_link FOREIGN KEY(parent_id) REFERENCES parent_before(id)); INSERT INTO parent_before VALUES(1); INSERT INTO parent_after VALUES(1); INSERT INTO retained_child VALUES(10,1)");
            String table=session.adapter.table(session.context.catalog(),f.schema(),"retained_child");
            var unwarmed=f.results.get(f.execute(session,"SELECT id,parent_id FROM "+table).info().getResults(0).getResultId());
            var initialProofState=unwarmed.metadataProof().state();
            assertTrue(Set.of(io.busystack.busydata.metadata.MetadataState.UNAVAILABLE,io.busystack.busydata.metadata.MetadataState.NOT_REQUESTED).contains(initialProofState),"Missing evidence retains its unavailable/not-requested state; no source authority was retired");
            var retainedBeforeRefresh=unwarmed.read(0).getValuesList();
            assertFalse(unwarmed.metadataProof().available(),"No metadata was captured before this result executed");
            f.introspectionLevel(session,io.busystack.busydata.metadata.IntrospectionLevel.STRUCTURE);explorer.refreshContext(session);
            var related=new RelatedRows(f.metadata.metadataPlatform(),f.results);
            var request=RelatedRowsRequest.newBuilder().setSessionId(session.id).setDocumentId("physical-related-owner").setResultId(unwarmed.id).build();
            var unavailable=RelatedRowsTestRequests.list(related,session,request);assertEquals("incomplete-metadata",unavailable.getAvailability());assertEquals(0,unavailable.getRelationshipsCount());
            assertEquals(retainedBeforeRefresh,unwarmed.read(0).getValuesList());
            assertEquals(initialProofState,unwarmed.metadataProof().state());
            var source=f.results.get(f.execute(session,"SELECT id,parent_id FROM "+table).info().getResults(0).getResultId());assertTrue(source.metadataProof().available());request=request.toBuilder().setResultId(source.id).build();
            var before=RelatedRowsTestRequests.list(related,session,request);assertEquals(1,before.getRelationshipsCount());assertEquals("parent_before",before.getRelationships(0).getBrowse().getTable());
            // Genuine external DDL bypasses BusyData smart-refresh notifications.
            try(var statement=external.connection.createStatement()) {
                statement.execute("DROP TABLE retained_child");
                statement.execute("CREATE TABLE retained_child(id INTEGER PRIMARY KEY,parent_id INTEGER,CONSTRAINT retained_link FOREIGN KEY(parent_id) REFERENCES parent_after(id))");
                statement.executeUpdate("INSERT INTO retained_child VALUES(10,1)");
            }
            explorer.refreshFragment(session,session.context.catalog(),f.schema(),"retained_child",ObjectKind.TABLE);
            var stale=RelatedRowsTestRequests.list(related,session,request);assertEquals("stale",stale.getAvailability());assertEquals(0,stale.getRelationshipsCount());
            var fresh=f.results.get(f.execute(session,"SELECT id,parent_id FROM "+table).info().getResults(0).getResultId());assertTrue(fresh.metadataProof().available());
            var after=RelatedRowsTestRequests.list(related,session,request.toBuilder().setResultId(fresh.id).build());assertEquals(1,after.getRelationshipsCount());assertEquals("parent_after",after.getRelationships(0).getBrowse().getTable());
        }
    }

}
