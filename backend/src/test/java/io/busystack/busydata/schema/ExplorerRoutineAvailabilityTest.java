package io.busystack.busydata.schema;

import io.busystack.busydata.NativeCaseFixtures;
import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

/** Direct collection uses the same authority reduction as incremental staging. */
class ExplorerRoutineAvailabilityTest {
    private static final MetadataScope SCOPE=new MetadataScope("db","db","",ObjectKind.ROUTINE);
    private static SchemaObject routine(String signature,String defaults,String source){return SchemaObject.newBuilder().setCatalog("db").setSchema("db").setName("f").setKind(ObjectKind.ROUTINE).setSubtype(ObjectSubtype.FUNCTION).setIdentifier("FUNCTION:f").setDefinition("known native source")
        .putProperties("signatureAvailability",signature).putProperties("parameterDefaultsAvailability",defaults).putProperties("sourceAvailability",source).putProperties("parameterCount","1").putProperties("parameter.0.name","arg").putProperties("parameter.0.mode","IN").putProperties("parameter.0.type","INTEGER").build();}
    private static RoutineFingerprintReader.Scan scan(SchemaObject object,MetadataState state){return new RoutineFingerprintReader.Scan(List.of(new RoutineFingerprintReader.Evidence(object,MetadataIdentity.digest("routine-fingerprint"),state)),MetadataIdentity.digest("namespace-fingerprint"),1,0,0);}
    private static MetadataSnapshot model(Engine engine,MetadataScope scope,MetadataPlatform.Branch branch){
        var rules=NativeCaseFixtures.rules(engine,0);var objects=branch.objects().stream().map(value->MetadataObject.from("source","profile","",rules,value,branch.coverage().level(),1,1)).toList();return new MetadataSnapshot("source","profile",1,1,1,rules,objects,Map.of(scope,branch.coverage()));
    }
    @Test void deniedSourceFingerprintRetainsNamesButCannotCertifyRequestedSource(){
        var object=routine("AVAILABLE","AVAILABLE","DENIED");var branch=Explorer.routineCollection(Engine.MYSQL,SCOPE,IntrospectionLevel.SOURCE,scan(object,MetadataState.DENIED),List.of(object),1,1);var model=model(Engine.MYSQL,SCOPE,branch);
        assertSame(object,branch.objects().getFirst());assertTrue(branch.normalized().isEmpty());assertEquals(IntrospectionLevel.NAMES,branch.coverage().level());assertTrue(model.complete(SCOPE,IntrospectionLevel.NAMES));assertFalse(model.complete(SCOPE,IntrospectionLevel.STRUCTURE));assertFalse(model.complete(SCOPE,IntrospectionLevel.SOURCE));
        assertEquals("PARTIAL",Explorer.scopePresentation(model,SCOPE,IntrospectionLevel.SOURCE).getMetadataState());assertTrue(Explorer.scopePresentation(model,SCOPE,IntrospectionLevel.SOURCE).getAvailability().contains("denied"));assertEquals("DENIED",model.objects().getFirst().getPropertiesOrThrow("sourceAvailability"));
    }
    @Test void partialDefaultsKeepKnownFieldsWithNamesOnlyAuthority(){
        var object=routine("UNSUPPORTED","UNSUPPORTED","AVAILABLE");var branch=Explorer.routineCollection(Engine.MARIADB,SCOPE,IntrospectionLevel.STRUCTURE,scan(object,MetadataState.AVAILABLE),List.of(object),1,1);var assessment=RoutineAvailability.assess(IntrospectionLevel.STRUCTURE,object.getPropertiesMap());var model=model(Engine.MARIADB,SCOPE,branch);
        assertEquals(assessment.level(),branch.coverage().level());assertEquals(MetadataState.PARTIAL,assessment.objectState());assertEquals(MetadataState.UNSUPPORTED,assessment.failure());assertFalse(model.complete(SCOPE,IntrospectionLevel.STRUCTURE));
        var retained=model.objects().getFirst();assertEquals("arg",retained.getPropertiesOrThrow("parameter.0.name"));assertEquals("IN",retained.getPropertiesOrThrow("parameter.0.mode"));assertEquals("INTEGER",retained.getPropertiesOrThrow("parameter.0.type"));assertEquals("1",retained.getPropertiesOrThrow("parameterCount"));assertEquals("known native source",retained.getDefinition());assertEquals("UNSUPPORTED",retained.getPropertiesOrThrow("signatureAvailability"));
    }
    @Test void sourceLimitKeepsCompleteStructureWithoutInventingCompleteSource(){
        var object=routine("AVAILABLE","AVAILABLE","LIMITED").toBuilder().clearDefinition().build();var branch=Explorer.routineCollection(Engine.MYSQL,SCOPE,IntrospectionLevel.SOURCE,scan(object,MetadataState.AVAILABLE),List.of(object),1,1);var model=model(Engine.MYSQL,SCOPE,branch);
        assertTrue(model.complete(SCOPE,IntrospectionLevel.STRUCTURE));assertFalse(model.complete(SCOPE,IntrospectionLevel.SOURCE));assertEquals(IntrospectionLevel.STRUCTURE,branch.coverage().level());assertEquals("PARTIAL",Explorer.scopePresentation(model,SCOPE,IntrospectionLevel.SOURCE).getMetadataState());assertEquals("AVAILABLE",Explorer.scopePresentation(model,SCOPE,IntrospectionLevel.STRUCTURE).getMetadataState());
    }
    @Test void completeFieldsAndEmptyNativeEnumerationKeepTheirPositiveControl(){
        var object=routine("AVAILABLE","AVAILABLE","AVAILABLE");var branch=Explorer.routineCollection(Engine.MYSQL,SCOPE,IntrospectionLevel.SOURCE,scan(object,MetadataState.AVAILABLE),List.of(object),1,1);var model=model(Engine.MYSQL,SCOPE,branch);
        assertTrue(model.complete(SCOPE,IntrospectionLevel.SOURCE));assertEquals("AVAILABLE",Explorer.scopePresentation(model,SCOPE,IntrospectionLevel.SOURCE).getMetadataState());
        var empty=new RoutineFingerprintReader.Scan(List.of(),MetadataIdentity.digest("empty-native-namespace"),0,0,0);var absent=Explorer.routineCollection(Engine.MYSQL,SCOPE,IntrospectionLevel.SOURCE,empty,List.of(),1,1);assertTrue(absent.coverage().complete());assertEquals(IntrospectionLevel.SOURCE,absent.coverage().level());
    }
    @Test void missingOrReplacementIdentityCannotBecomeAnAvailableEmptyBranch(){
        var object=routine("AVAILABLE","AVAILABLE","AVAILABLE");var scan=scan(object,MetadataState.AVAILABLE);
        assertThrows(Explorer.ContinuationFailure.class,()->Explorer.routineCollection(Engine.MYSQL,SCOPE,IntrospectionLevel.SOURCE,scan,List.of(),1,1));
        var replacement=object.toBuilder().setName("other").setIdentifier("FUNCTION:other").build();assertThrows(Explorer.ContinuationFailure.class,()->Explorer.routineCollection(Engine.MYSQL,SCOPE,IntrospectionLevel.SOURCE,scan,List.of(replacement),1,1));
    }
    @Test void rawTemporaryObjectsRemainAvailableForExistingPhysicalOwnerInjection(){
        var object=routine("AVAILABLE","AVAILABLE","AVAILABLE").toBuilder().setSchema("pg_temp_42").setIdentifier("f(integer)").putProperties("nativeId","42").build();var scope=new MetadataScope("db","pg_temp_42","",ObjectKind.ROUTINE);
        var branch=Explorer.routineCollection(Engine.POSTGRESQL,scope,IntrospectionLevel.SOURCE,scan(object,MetadataState.AVAILABLE),List.of(object),1,1);assertSame(object,branch.objects().getFirst());assertTrue(branch.normalized().isEmpty());
        var owned=MetadataObject.from("source","profile","physical-owner",new IdentifierRules(Engine.POSTGRESQL,0),branch.objects().getFirst(),branch.coverage().level(),1,1);assertEquals("physical-owner",owned.identity().sessionOwner());assertEquals("true",owned.properties().get("temporary"));
    }
}
