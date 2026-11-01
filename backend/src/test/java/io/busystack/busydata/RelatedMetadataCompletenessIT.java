package io.busystack.busydata;

import io.busystack.busydata.analysis.language.*;
import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.*;
import java.nio.file.Path;
import java.util.*;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

class RelatedMetadataCompletenessIT {
    @TempDir Path root;
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void staleIncomingConstraintCannotOfferJoinOrRelatedBrowseAfterColumnsAreFresh(String engine)throws Exception{
        try(var f=new EngineFixture(root,engine)){
            var session=f.open();String parent=session.adapter.table("busydata",f.schema(),"parent_rows"),child=session.adapter.table("busydata",f.schema(),"child_rows");
            f.execute(session,"CREATE TABLE "+parent+"(id INTEGER PRIMARY KEY); CREATE TABLE "+child+"(id INTEGER PRIMARY KEY,parent_id INTEGER,CONSTRAINT fk_parent FOREIGN KEY(parent_id) REFERENCES "+parent+"(id)); INSERT INTO "+parent+" VALUES(1); INSERT INTO "+child+" VALUES(1,1)");
            f.warm(session,"parent_rows","child_rows");var result=f.results.get(f.execute(session,"SELECT id FROM "+parent).info().getResults(0).getResultId());assertTrue(result.metadataProof().available(),result.metadataProof().toString());
            var related=new RelatedRows(f.metadata.metadataPlatform(),f.results);var request=RelatedRowsRequest.newBuilder().setSessionId(session.id).setResultId(result.id).setSourceRow(0).setDocumentId("related-source").build();
            var before=RelatedRowsTestRequests.list(related,session,request);var navigation=before.getRelationshipsList().stream().filter(item->item.getIncoming()&&item.getAvailability().equals("available")).findFirst().orElseThrow();
            // Model a known parent alteration, then re-inspect only its own
            // columns. The incoming child constraint is deliberately still stale.
            var effect=DdlEffect.newBuilder().setOperation("ALTER").setCatalog("busydata").setSchema(f.schema()).setName("parent_rows").setKind(ObjectKind.TABLE).build();
            f.metadata.metadataPlatform().markStaleEffects(session,List.of(effect),"Incoming constraint awaits refresh");
            new Explorer(f.metadata).explore(session,ExploreRequest.newBuilder().setCatalog("busydata").setSchema(f.schema()).setTable("parent_rows").setKind(ObjectKind.COLUMN).setIntrospectionLevel(2).build());
            var snapshot=f.metadata.metadataPlatform().capture(session);assertTrue(snapshot.complete(new MetadataScope("busydata",f.schema(),"parent_rows",ObjectKind.COLUMN),IntrospectionLevel.STRUCTURE));assertTrue(snapshot.complete(new MetadataScope("busydata",f.schema(),"child_rows",ObjectKind.COLUMN),IntrospectionLevel.STRUCTURE));assertFalse(snapshot.outgoingComplete("busydata",f.schema(),"child_rows"));
            var reply=RelatedRowsTestRequests.list(related,session,request);assertTrue(reply.getRelationshipsList().stream().allMatch(item->!item.getAvailability().equals("available")&&!item.hasBrowse()));
            String sql="SELECT * FROM "+child+" c JOIN "+parent+" p ON ";var batch=new SemanticDocument(sql,f.engine,session.context.lexical()).completeBatch(sql.length(),new ResolutionContext("busydata",f.schema(),session.context.searchPath(),true,snapshot.revision(),snapshot.configurationRevision(),snapshot.rules(),snapshot),Map.of());
            assertTrue(batch.metadataIncomplete());assertTrue(batch.items().stream().noneMatch(item->item.getKind().equals("join")));
            var forgedFresh=navigation.getBrowse().toBuilder().setMetadataSnapshotRevision(snapshot.revision()).build();assertThrows(io.busystack.busydata.rpc.WorkbenchFailure.class,()->TableBrowse.prepare(session,forgedFresh,new Explorer(f.metadata)));
        }
    }
    @ParameterizedTest @org.junit.jupiter.params.provider.MethodSource("targetCoverageCases")
    void targetWithoutDeclaredStructureCannotOfferAnUnusableBrowse(String engine,boolean missingColumns)throws Exception{
        try(var fixture=new EngineFixture(root,engine)){
            var owner=fixture.open();String parent=owner.adapter.table("busydata",fixture.schema(),"target_parent"),child=owner.adapter.table("busydata",fixture.schema(),"source_child");
            fixture.execute(owner,"CREATE TABLE "+parent+"(id INTEGER PRIMARY KEY); CREATE TABLE "+child+"(id INTEGER PRIMARY KEY,parent_id INTEGER,CONSTRAINT target_fk FOREIGN KEY(parent_id) REFERENCES "+parent+"(id)); INSERT INTO "+parent+" VALUES(1); INSERT INTO "+child+" VALUES(7,1)");
            fixture.warm(owner,"target_parent","source_child");var retained=fixture.results.get(fixture.execute(owner,"SELECT id,parent_id FROM "+child).info().getResults(0).getResultId());assertTrue(retained.metadataProof().available());
            var platform=fixture.metadata.metadataPlatform();var related=new RelatedRows(platform,fixture.results);var request=RelatedRowsRequest.newBuilder().setSessionId(owner.id).setDocumentId("target-coverage").setResultId(retained.id).setSourceRow(0).build();
            var available=RelatedRowsTestRequests.list(related,owner,request).getRelationshipsList().stream().filter(item->!item.getIncoming()&&item.getAvailability().equals("available")).findFirst().orElseThrow();
            var before=platform.capture(owner);var target=before.resolve("busydata",fixture.schema(),ObjectKind.TABLE,"","target_parent",true).getFirst();
            MetadataScope scope;MetadataPlatform.Branch branch;
            if(missingColumns){scope=new MetadataScope("busydata",fixture.schema(),"target_parent",ObjectKind.COLUMN);branch=new MetadataPlatform.Branch(List.of(),new MetadataCoverage(scope,IntrospectionLevel.STRUCTURE,MetadataState.UNAVAILABLE,false,"",owner.revision,owner.contextRevision,0,"Target columns were not acquired"));}
            else{scope=new MetadataScope("busydata",fixture.schema(),"",ObjectKind.TABLE,"target_parent",true,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED);branch=new MetadataPlatform.Branch(List.of(before.projection(target)),new MetadataCoverage(scope,IntrospectionLevel.NAMES,MetadataState.AVAILABLE,true,"names-only-target",owner.revision,owner.contextRevision,System.currentTimeMillis(),""));}
            platform.publish(owner,platform.beginRefresh(owner),before.rules(),Map.of(scope,branch),false);
            var current=platform.capture(owner);assertTrue(current.resolve("busydata",fixture.schema(),ObjectKind.TABLE,"","target_parent",true).size()==1);
            if(!missingColumns){assertEquals(IntrospectionLevel.NAMES,current.identity(target.identity().key()).orElseThrow().level());assertFalse(current.complete(new MetadataScope("busydata",fixture.schema(),"target_parent",ObjectKind.COLUMN),IntrospectionLevel.STRUCTURE),"A names-only parent replacement retires its previous structural child coverage");}
            int jobs=fixture.jobs.list("").size();var choice=RelatedRowsTestRequests.list(related,owner,request).getRelationshipsList().stream().filter(item->item.getIdentity().equals(available.getIdentity())).findFirst().orElseThrow();assertEquals("incomplete-metadata",choice.getAvailability());assertFalse(choice.hasBrowse());assertEquals(jobs,fixture.jobs.list("").size());assertEquals("1",retained.read(0).getValues(1).getSignedInteger());
        }
    }
    static java.util.stream.Stream<org.junit.jupiter.params.provider.Arguments> targetCoverageCases(){return java.util.stream.Stream.of("POSTGRESQL","MYSQL","MARIADB").flatMap(engine->java.util.stream.Stream.of(false,true).map(missing->org.junit.jupiter.params.provider.Arguments.of(engine,missing)));}

}
