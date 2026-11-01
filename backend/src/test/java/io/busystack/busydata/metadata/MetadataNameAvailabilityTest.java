package io.busystack.busydata.metadata;

import io.busystack.busydata.NativeCaseFixtures;
import io.busystack.busydata.protocol.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

/** Name-only evidence must never recover stale structural authority. */
class MetadataNameAvailabilityTest {
    private static final IdentifierRules RULES=NativeCaseFixtures.rules(Engine.MARIADB,1);
    private static MetadataObject object(IdentifierRules rules,ObjectKind kind,ObjectSubtype subtype,String parent,String owner,MetadataState state,Map<String,String> properties){
        var value=MetadataObject.from("source","profile",owner,rules,SchemaObject.newBuilder().setCatalog("db").setSchema("db").setTable(parent).setName("Exact").setKind(kind).setSubtype(subtype).setIdentifier("captured-signature").putAllProperties(properties).build(),IntrospectionLevel.STRUCTURE,1,1);
        return new MetadataObject(value.identity(),value.displayName(),value.quotedIdentifier(),value.lookupKey(),value.properties(),value.source(),value.level(),state,1,1);
    }
    private static MetadataObject relation(IdentifierRules rules){return object(rules,ObjectKind.TABLE,ObjectSubtype.ORDINARY_TABLE,"","",MetadataState.STALE,Map.of("baseTableVerified","true"));}
    private static MetadataScope scope(MetadataObject object,boolean point,String signature,ObjectSubtype subtype){var i=object.identity();return new MetadataScope(i.catalog(),i.schema(),"",i.kind(),point?i.name():"",point,signature,subtype);}
    private static MetadataCoverage coverage(MetadataScope scope,MetadataState state){return new MetadataCoverage(scope,IntrospectionLevel.NAMES,state,state==MetadataState.AVAILABLE,"fixture",2,1,2,state==MetadataState.AVAILABLE?"":"Name evidence unavailable");}
    private static MetadataSnapshot snapshot(IdentifierRules rules,MetadataObject object,MetadataScope scope,MetadataState state){return new MetadataSnapshot("source","profile",2,1,2,rules,List.of(object),Map.of(scope,coverage(scope,state)));}

    @Test void broadAndExactNameScopesSupportActualSubtypeAndSignatureVariants(){
        var object=relation(RULES);
        for(boolean point:List.of(false,true))for(String signature:List.of("",object.identity().signature()))for(var subtype:List.of(ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED,object.identity().subtype())){
            var scope=scope(object,point,signature,subtype);var model=snapshot(RULES,object,scope,MetadataState.AVAILABLE);
            assertTrue(model.nameAvailable(object));assertSame(object,model.identities().get(object.identity().key()));
            assertEquals(MetadataState.STALE,object.state());assertFalse(model.complete(scope,IntrospectionLevel.STRUCTURE));
            assertEquals("STALE",model.projection(object).getMetadataState());assertTrue(model.namespace("db","db",ObjectKind.COLUMN,"Exact").isEmpty());
        }
    }
    @Test void freshDurableNamesDoNotClaimUnknownPhysicalResolutionOrStructuralProof(){
        var object=relation(RULES);var scope=scope(object,false,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED);
        var model=snapshot(RULES,object,scope,MetadataState.AVAILABLE).withSessionResolution(3,new MetadataSnapshot.SessionResolution(MetadataState.UNKNOWN,"owner",1,"Physical visibility is unknown",Map.of()));
        assertTrue(model.nameAvailable(object));assertFalse(model.scopeResolutionAvailable(scope));assertFalse(model.complete(scope,IntrospectionLevel.NAMES));
        assertFalse(model.relationResolutionAvailable("db","db","Exact","owner"));assertEquals(MetadataState.UNKNOWN,model.coverage(scope).orElseThrow().state());
        var column=Column.newBuilder().setOrdinal(1).setCatalog("db").setSchema("db").setTable("Exact").setBaseColumn("id").setProvenanceKnown(true).build();
        assertFalse(ExecutionMetadata.selected(model,List.of(column),Profile.newBuilder().setEngine(Engine.MARIADB).build(),"owner",null).proof(List.of(column)).available());
    }
    @Test void staleDeniedPartialAndMissingNameEvidenceNeverQualify(){
        var object=relation(RULES);var scope=scope(object,false,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED);
        for(var state:List.of(MetadataState.STALE,MetadataState.DENIED,MetadataState.PARTIAL,MetadataState.UNAVAILABLE))assertFalse(snapshot(RULES,object,scope,state).nameAvailable(object));
        var missing=new MetadataSnapshot("source","profile",2,1,2,RULES,List.of(object),Map.of());assertFalse(missing.nameAvailable(object));
        var filtered=new MetadataScope("db","db","",ObjectKind.TABLE,"Ex",false,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED);
        assertFalse(snapshot(RULES,object,filtered,MetadataState.AVAILABLE).nameAvailable(object),"Substring enumeration is not a direct namespace or exact-name proof");
        var other=scope(object,true,"another-signature",object.identity().subtype());assertFalse(snapshot(RULES,object,other,MetadataState.AVAILABLE).nameAvailable(object));
        var wrongSubtype=scope(object,true,"",ObjectSubtype.PARTITIONED_TABLE);assertFalse(snapshot(RULES,object,wrongSubtype,MetadataState.AVAILABLE).nameAvailable(object));
    }
    @Test void unavailableAffinityProvisionalRulesAndUnsupportedKindsRemainUnavailable(){
        var object=relation(RULES);var scope=scope(object,false,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED);
        assertFalse(snapshot(RULES,object,scope,MetadataState.AVAILABLE).withIdentifierAvailability(false).nameAvailable(object));
        var provisional=new IdentifierRules(Engine.MARIADB,1);var unverified=relation(provisional);assertFalse(snapshot(provisional,unverified,scope,MetadataState.AVAILABLE).nameAvailable(unverified));
        var filesystem=NativeCaseFixtures.rules(Engine.MARIADB,1,"filesystem",true);var trigger=object(filesystem,ObjectKind.TRIGGER,ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED,"","",MetadataState.STALE,Map.of());
        assertFalse(snapshot(filesystem,trigger,scope(trigger,false,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED),MetadataState.AVAILABLE).nameAvailable(trigger));
    }
    @Test void anOldEqualObjectReferenceAndDeniedObjectCannotBorrowCurrentNameEvidence(){
        var previous=relation(RULES);var current=relation(RULES);assertEquals(previous,current);assertNotSame(previous,current);
        var scope=scope(current,false,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED);var model=snapshot(RULES,current,scope,MetadataState.AVAILABLE);
        assertTrue(model.nameAvailable(current));assertFalse(model.nameAvailable(previous));assertFalse(model.nameAvailable(null));
        var denied=object(RULES,ObjectKind.TABLE,ObjectSubtype.ORDINARY_TABLE,"","",MetadataState.DENIED,Map.of());assertFalse(snapshot(RULES,denied,scope,MetadataState.AVAILABLE).nameAvailable(denied));
    }
    @Test void onlyPersistentParentlessRelationsCanUseNameEvidence(){
        for(var kind:List.of(ObjectKind.TABLE,ObjectKind.VIEW,ObjectKind.SEQUENCE)){
            var value=object(RULES,kind,ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED,"","",MetadataState.STALE,Map.of());var scope=scope(value,false,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED);
            assertTrue(snapshot(RULES,value,scope,MetadataState.AVAILABLE).nameAvailable(value));
            for(var invalid:List.of(object(RULES,kind,ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED,"parent","",MetadataState.STALE,Map.of()),object(RULES,kind,ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED,"","owner",MetadataState.STALE,Map.of()),object(RULES,kind,ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED,"","",MetadataState.STALE,Map.of("temporary","true"))))assertFalse(snapshot(RULES,invalid,scope,MetadataState.AVAILABLE).nameAvailable(invalid));
        }
        var pgRules=new IdentifierRules(Engine.POSTGRESQL,0);var temp=object(pgRules,ObjectKind.TABLE,ObjectSubtype.ORDINARY_TABLE,"","",MetadataState.STALE,Map.of());var id=temp.identity();
        var identity=new MetadataIdentity(id.source(),id.profileId(),id.catalog(),"pg_temp_42",id.kind(),id.subtype(),id.parent(),id.name(),id.signature(),id.sessionOwner(),id.nativeKey());
        var namespaced=new MetadataObject(identity,temp.displayName(),temp.quotedIdentifier(),temp.lookupKey(),temp.properties(),temp.source(),temp.level(),temp.state(),1,1);
        assertFalse(snapshot(pgRules,namespaced,scope(namespaced,false,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED),MetadataState.AVAILABLE).nameAvailable(namespaced));
    }
}
