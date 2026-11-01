package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class ExternalOverlayRetirementTest {
    private static final String SESSION="physical";
    private static final MetadataScope TABLE=new MetadataScope("db","public","",ObjectKind.TABLE,"t",true,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED);
    private static final MetadataScope COLUMN=new MetadataScope("db","public","t",ObjectKind.COLUMN);
    private static final MetadataScope TEMP_TABLE=new MetadataScope("db","pg_temp_5","",ObjectKind.TABLE);
    private static final MetadataScope TEMP_COLUMN=new MetadataScope("db","pg_temp_5","local",ObjectKind.COLUMN);
    private static final Set<MetadataScope> SCOPES=Set.of(TABLE,COLUMN,TEMP_TABLE,TEMP_COLUMN);
    private static final Profile PROFILE=Profile.newBuilder().setId("profile").setEngine(Engine.POSTGRESQL).setDatabase("db").build();
    private static final List<Column> COLUMNS=List.of(Column.newBuilder().setOrdinal(1).setCatalog("db").setSchema("public").setTable("t").setBaseColumn("id").setProvenanceKnown(true).build());
    private static MetadataSnapshot snapshot(long revision,String generation,boolean temporary){
        var rules=new IdentifierRules(Engine.POSTGRESQL,0);var objects=new ArrayList<MetadataObject>();var coverage=new HashMap<MetadataScope,MetadataCoverage>();
        objects.add(MetadataObject.from("source","profile","",rules,SchemaObject.newBuilder().setCatalog("db").setSchema("public").setName("t").setKind(ObjectKind.TABLE).putProperties("nativeId","1").putProperties("nativeGeneration",generation).putProperties("nativeGenerationAvailability","AVAILABLE").build(),IntrospectionLevel.STRUCTURE,1,1));
        objects.add(MetadataObject.from("source","profile","",rules,SchemaObject.newBuilder().setCatalog("db").setSchema("public").setTable("t").setName("id").setKind(ObjectKind.COLUMN).putProperties("nativeId","1:1").putProperties("type","integer").putProperties("jdbcType","4").build(),IntrospectionLevel.STRUCTURE,1,1));
        for(var scope:List.of(TABLE,COLUMN))coverage.put(scope,new MetadataCoverage(scope,IntrospectionLevel.STRUCTURE,MetadataState.AVAILABLE,true,"persistent",1,1,1,""));
        if(temporary){
            for(var kind:List.of(ObjectKind.TABLE,ObjectKind.COLUMN)){var wire=SchemaObject.newBuilder().setKind(kind).setCatalog("db").setSchema("pg_temp_5").setName(kind==ObjectKind.TABLE?"local":"id").setTable(kind==ObjectKind.TABLE?"":"local").putProperties("temporary","true").build();objects.add(MetadataObject.from("source","profile",SESSION,rules,wire,IntrospectionLevel.STRUCTURE,1,1));}
            for(var scope:List.of(TEMP_TABLE,TEMP_COLUMN))coverage.put(scope,new MetadataCoverage(scope,IntrospectionLevel.STRUCTURE,MetadataState.AVAILABLE,true,"temporary",1,1,1,""));
        }
        return new MetadataSnapshot("source","profile",revision,1,1,rules,objects,coverage);
    }
    @Test void nativeBoundaryAndNewDurablePublicationCannotRevivePersistentOverlay(){
        MetadataSnapshot overlay;try{var prior=snapshot(2,"1:100",true);overlay=MetadataSnapshot.compose(snapshot(1,"1:100",false),prior.identities().values(),SCOPES,prior.catalogCoverage(),Set.of(),2,1,1,Long.MAX_VALUE);}catch(java.util.concurrent.TimeoutException impossible){throw new AssertionError(impossible);}assertTrue(RetainedMetadataProof.capture(overlay,COLUMNS,PROFILE,SESSION).available());
        var retired=MetadataPlatform.retirePersistentOverlay(overlay,SCOPES,SESSION);assertSame(overlay.identities(),retired.identities());
        assertFalse(retired.complete(COLUMN,IntrospectionLevel.STRUCTURE));assertTrue(overlay.complete(COLUMN,IntrospectionLevel.STRUCTURE));
        assertSame(overlay.catalogCoverage().get(TEMP_TABLE),retired.catalogCoverage().get(TEMP_TABLE));assertSame(overlay.catalogCoverage().get(TEMP_COLUMN),retired.catalogCoverage().get(TEMP_COLUMN));
        var fresh=snapshot(5,"1:200",false);var captured=MetadataPlatform.rebaseOverlay(fresh,retired,SCOPES,SESSION);
        assertFalse(RetainedMetadataProof.capture(captured,COLUMNS,PROFILE,SESSION).available());assertEquals(MetadataState.STALE,captured.coverage(COLUMN).orElseThrow().state());
        assertSame(overlay.resolve("db","pg_temp_5",ObjectKind.TABLE,"","local",true).getFirst(),captured.resolve("db","pg_temp_5",ObjectKind.TABLE,"","local",true).getFirst());
        assertSame(overlay.catalogCoverage().get(TEMP_COLUMN),captured.catalogCoverage().get(TEMP_COLUMN));assertTrue(captured.complete(TEMP_COLUMN,IntrospectionLevel.STRUCTURE));
        assertEquals(overlay.identities().size(),captured.identities().size(),"Pending persistent identities remain inspectable rather than being erased");
    }
}
