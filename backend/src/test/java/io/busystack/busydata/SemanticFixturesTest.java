package io.busystack.busydata;

import io.busystack.busydata.analysis.language.ResolutionContext;
import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class SemanticFixturesTest {
    private static final ResolutionContext COMPLETE=new ResolutionContext("fixture","public",List.of("public","audit"),true,7,3);
    private static SchemaObject table(){return SchemaObject.newBuilder().setKind(ObjectKind.TABLE).setName("Orders").setStableIdentity("display-label-is-not-identity").build();}
    private static SchemaObject column(){return SchemaObject.newBuilder().setKind(ObjectKind.COLUMN).setTable("Orders").setName("ExactColumn").putProperties("nativeType","numeric(38,12)").build();}

    @Test void centralIdentityUsesExactIdentifiersAndPublishedInputsAreImmutable(){
        var objects=new ArrayList<>(List.of(table(),column()));var context=SemanticFixtures.context(Engine.POSTGRESQL,objects,COMPLETE);objects.clear();
        var snapshot=context.snapshot();assertNotNull(snapshot);assertEquals(7,snapshot.revision());assertEquals(3,snapshot.configurationRevision());assertEquals(COMPLETE.searchPath(),context.searchPath());
        var relation=snapshot.resolve("fixture","public",ObjectKind.TABLE,"","Orders",true).getFirst();assertNotEquals("display-label-is-not-identity",relation.identity().key());assertEquals("Orders",relation.identity().name());assertTrue(snapshot.resolve("fixture","public",ObjectKind.TABLE,"","orders",true).isEmpty());
        var field=snapshot.resolve("fixture","public",ObjectKind.COLUMN,"Orders","ExactColumn",true).getFirst();assertEquals("numeric(38,12)",field.properties().get("nativeType"));assertTrue(snapshot.complete(new MetadataScope("fixture","public","Orders",ObjectKind.COLUMN),IntrospectionLevel.STRUCTURE));
        assertThrows(UnsupportedOperationException.class,()->snapshot.identities().clear());assertThrows(UnsupportedOperationException.class,()->field.properties().put("nativeType","float"));
        assertEquals(relation.identity().key(),SemanticFixtures.context(Engine.POSTGRESQL,List.of(table(),column()),COMPLETE).snapshot().resolve("fixture","public",ObjectKind.TABLE,"","Orders",true).getFirst().identity().key());
    }
    @Test void completeModelDeclaresEmptyEffectiveNamespacesWithoutInventingObjects(){
        var snapshot=SemanticFixtures.context(Engine.POSTGRESQL,List.of(table()),COMPLETE).snapshot();
        for(String schema:List.of("public","audit","pg_catalog"))for(var kind:List.of(ObjectKind.TABLE,ObjectKind.VIEW,ObjectKind.SEQUENCE,ObjectKind.ROUTINE))assertTrue(snapshot.complete(new MetadataScope("fixture",schema,"",kind),IntrospectionLevel.NAMES));
        assertEquals(1,snapshot.identities().size());assertTrue(snapshot.namespace("fixture","audit",ObjectKind.TABLE,"").isEmpty());assertTrue(snapshot.namespace("fixture","pg_catalog",ObjectKind.ROUTINE,"").isEmpty());
    }
    @Test void partialAndStaleInputsNeverAcquireCompleteCoverage(){
        var partial=new ResolutionContext("fixture","public",List.of("public"),false,0,0);
        var incomplete=SemanticFixtures.context(Engine.POSTGRESQL,List.of(table(),column()),partial);assertFalse(incomplete.complete());assertTrue(incomplete.snapshot().coverage().values().stream().noneMatch(MetadataCoverage::complete));assertEquals(0,incomplete.metadataRevision());assertEquals(0,incomplete.configurationRevision());
        var partialObject=SemanticFixtures.context(Engine.POSTGRESQL,List.of(table().toBuilder().setMetadataState("PARTIAL").build()),COMPLETE).snapshot();
        assertEquals(MetadataState.PARTIAL,partialObject.resolve("fixture","public",ObjectKind.TABLE,"","Orders",true).getFirst().state());assertEquals(MetadataState.PARTIAL,partialObject.coverage(new MetadataScope("fixture","public","",ObjectKind.TABLE)).orElseThrow().state());assertFalse(partialObject.complete(new MetadataScope("fixture","public","",ObjectKind.TABLE),IntrospectionLevel.NAMES));
        var staleColumn=column().toBuilder().setMetadataState("STALE").build();var stale=SemanticFixtures.context(Engine.POSTGRESQL,List.of(table(),staleColumn),COMPLETE).snapshot();
        assertEquals(MetadataState.STALE,stale.resolve("fixture","public",ObjectKind.COLUMN,"Orders","ExactColumn",true).getFirst().state());assertEquals(MetadataState.STALE,stale.coverage(new MetadataScope("fixture","public","Orders",ObjectKind.COLUMN)).orElseThrow().state());assertFalse(stale.complete(new MetadataScope("fixture","public","Orders",ObjectKind.COLUMN),IntrospectionLevel.STRUCTURE));
    }
    @Test void namesLevelDoesNotCreateStructuralColumnsOrAnOrphanParent(){
        var names=table().toBuilder().setIntrospectionLevel(1).build();var snapshot=SemanticFixtures.context(Engine.POSTGRESQL,List.of(names),COMPLETE).snapshot();
        assertTrue(snapshot.complete(new MetadataScope("fixture","public","",ObjectKind.TABLE),IntrospectionLevel.NAMES));assertFalse(snapshot.complete(new MetadataScope("fixture","public","Orders",ObjectKind.COLUMN),IntrospectionLevel.STRUCTURE));assertEquals(MetadataState.NOT_REQUESTED,snapshot.coverage(new MetadataScope("fixture","public","Orders",ObjectKind.COLUMN)).orElseThrow().state());
        var orphan=SemanticFixtures.context(Engine.POSTGRESQL,List.of(column()),COMPLETE).snapshot();assertTrue(orphan.namespace("fixture","public",ObjectKind.TABLE,"").isEmpty());assertEquals(1,orphan.identities().size());assertFalse(orphan.complete(new MetadataScope("fixture","public","Orders",ObjectKind.COLUMN),IntrospectionLevel.STRUCTURE));
    }
    @Test void nativeSnapshotAndItsRulesAreNeverReinterpreted(){
        var captured=SemanticFixtures.context(Engine.MYSQL,List.of(table()),new ResolutionContext("fixture","public",List.of("public"),true,9,2,NativeCaseFixtures.rules(Engine.MYSQL,1)));
        assertSame(captured,SemanticFixtures.context(Engine.MYSQL,List.of(),captured));assertEquals(1,captured.snapshot().rules().lowerCaseTableNames());
        assertEquals(1,captured.snapshot().resolve("fixture","public",ObjectKind.TABLE,"","orders",false).size());
    }
}
