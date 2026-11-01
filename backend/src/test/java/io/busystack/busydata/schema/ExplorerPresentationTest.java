package io.busystack.busydata.schema;

import io.busystack.busydata.NativeCaseFixtures;
import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

/** Synthetic immutable views exercise response authority, without catalog IO. */
class ExplorerPresentationTest {
    private static final MetadataScope COLUMNS=new MetadataScope("db","db","t",ObjectKind.COLUMN);
    private static MetadataSnapshot snapshot(IdentifierRules rules,MetadataScope scope){
        var object=MetadataObject.from("source","profile","",rules,SchemaObject.newBuilder().setCatalog("db").setSchema("db").setTable("t").setName("Exact").setKind(scope.kind()).build(),IntrospectionLevel.STRUCTURE,1,1);
        var coverage=new MetadataCoverage(scope,IntrospectionLevel.STRUCTURE,MetadataState.AVAILABLE,true,"fixture",1,1,1,"");
        return new MetadataSnapshot("source","profile",1,1,1,rules,List.of(object),Map.of(scope,coverage));
    }
    private static void assertPresentation(MetadataSnapshot snapshot,MetadataScope scope,MetadataState expected){
        var response=Explorer.scopePresentation(snapshot,scope).build();
        assertEquals(expected.name(),response.getMetadataState());assertTrue(response.getAvailability().startsWith(expected.name().toLowerCase(Locale.ROOT)+": "));
        assertFalse(response.getAvailability().endsWith(": "));assertFalse(response.getComplete());
        assertEquals(1,snapshot.select(scope).size(),"Unavailable authority must retain inspectable candidates for the existing page path");
        assertEquals(expected.name(),snapshot.projection(snapshot.select(scope).getFirst()).getMetadataState());
        assertTrue(snapshot.catalogCoverage().get(scope).complete(),"Presentation must not overwrite immutable acquisition facts");
    }
    @Test void filesystemUnsupportedTriggerKeepsItsTypedEnvelopeAndCandidate(){
        var scope=new MetadataScope("db","db","t",ObjectKind.TRIGGER);
        var model=snapshot(NativeCaseFixtures.rules(Engine.MARIADB,1,"fixture",true),scope);
        assertPresentation(model,scope,MetadataState.UNSUPPORTED);
        assertEquals("unsupported: "+model.coverage(scope).orElseThrow().limitation(),Explorer.scopePresentation(model,scope).getAvailability());
    }
    @Test void physicalAffinityUnavailableDoesNotBecomeUnknown(){
        var model=snapshot(NativeCaseFixtures.rules(Engine.MYSQL,1),COLUMNS).withIdentifierAvailability(false);
        assertPresentation(model,COLUMNS,MetadataState.UNAVAILABLE);
        assertEquals("unavailable: "+model.coverage(COLUMNS).orElseThrow().limitation(),Explorer.scopePresentation(model,COLUMNS).getAvailability());
    }
    @Test void actualUnknownSessionResolutionPreservesItsOwnReason(){
        var model=snapshot(NativeCaseFixtures.rules(Engine.MARIADB,1),COLUMNS).withSessionResolution(2,new MetadataSnapshot.SessionResolution(MetadataState.UNKNOWN,"owner",1,"Physical visibility requires verification",Map.of()));
        assertPresentation(model,COLUMNS,MetadataState.UNKNOWN);
        assertEquals("unknown: Physical visibility requires verification",Explorer.scopePresentation(model,COLUMNS).getAvailability());
        var noReason=model.withSessionResolution(3,new MetadataSnapshot.SessionResolution(MetadataState.UNKNOWN,"owner",2,"",Map.of()));
        assertEquals("unknown: Metadata coverage is unknown",Explorer.scopePresentation(noReason,COLUMNS).getAvailability());
    }
    @Test void availableEnvelopeAndRawPagingAuthorityRemainAvailable(){
        var model=snapshot(NativeCaseFixtures.rules(Engine.MYSQL,1),COLUMNS);var response=Explorer.scopePresentation(model,COLUMNS).build();
        assertEquals("AVAILABLE",response.getMetadataState());assertEquals("available",response.getAvailability());
        assertTrue(model.scopeResolutionAvailable(COLUMNS));assertTrue(model.catalogCoverage().get(COLUMNS).complete());
        assertTrue(model.complete(COLUMNS,IntrospectionLevel.STRUCTURE));assertEquals(1,model.select(COLUMNS).size());
    }
}
