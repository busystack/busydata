package io.busystack.busydata;

import io.busystack.busydata.adapters.JdbcAdapter;
import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class RetainedMetadataProofTest {
    private static final Profile PROFILE=Profile.newBuilder().setId("p").setEngine(Engine.POSTGRESQL).setDatabase("db").build();
    private static final List<Column> COLUMNS=List.of(Column.newBuilder().setOrdinal(1).setCatalog("db").setSchema("public").setTable("t").setBaseColumn("id").setProvenanceKnown(true).build());
    private static MetadataSnapshot snapshot(String generation,boolean earlierView) {
        var rules=new IdentifierRules(Engine.POSTGRESQL,0);var entries=new ArrayList<MetadataObject>();
        entries.add(MetadataObject.from("source","p","",rules,SchemaObject.newBuilder().setCatalog("db").setSchema("public").setName("t").setKind(ObjectKind.TABLE).putProperties("nativeId","1").putProperties("nativeGeneration",generation).putProperties("nativeGenerationAvailability","AVAILABLE").build(),IntrospectionLevel.STRUCTURE,1,1));
        entries.add(MetadataObject.from("source","p","",rules,SchemaObject.newBuilder().setCatalog("db").setSchema("public").setTable("t").setName("id").setKind(ObjectKind.COLUMN).putProperties("nativeId","1:1").putProperties("type","integer").putProperties("jdbcType","4").build(),IntrospectionLevel.STRUCTURE,1,1));
        if(earlierView)entries.add(MetadataObject.from("source","p","",rules,SchemaObject.newBuilder().setCatalog("db").setSchema("audit").setName("t").setKind(ObjectKind.VIEW).build(),IntrospectionLevel.STRUCTURE,1,1));
        var scope=new MetadataScope("db","public","t",ObjectKind.COLUMN);
        return new MetadataSnapshot("source","p",1,1,123,rules,entries,Map.of(scope,new MetadataCoverage(scope,IntrospectionLevel.STRUCTURE,MetadataState.AVAILABLE,true,"v",1,1,123,"")));
    }
    @Test void directSourceBindingRejectsViewAndUnverifiedEarlierNamespace() {
        var snapshot=snapshot("1:100",true);
        var context=new JdbcAdapter.LiveContext("db","audit",List.of("audit","public","pg_catalog"),"");
        var view=RetainedMetadataProof.captureExecution(snapshot,COLUMNS,PROFILE,"s","SELECT id FROM t",context);assertFalse(view.available());assertEquals(MetadataState.UNSUPPORTED,view.state(),view.availability());
        var qualified=RetainedMetadataProof.captureExecution(snapshot,COLUMNS,PROFILE,"s","SELECT id FROM public.t",context);assertTrue(qualified.available(),qualified.state()+": "+qualified.availability());
        assertFalse(RetainedMetadataProof.captureExecution(snapshot,COLUMNS,PROFILE,"s","SELECT id FROM audit.t",context).available());
        var ordinary=new JdbcAdapter.LiveContext("db","public",List.of("public"),"");
        var uninspected=RetainedMetadataProof.captureExecution(snapshot,COLUMNS,PROFILE,"s","SELECT id FROM t",ordinary);
        assertFalse(uninspected.available(),"Implicit pg_catalog absence cannot be inferred from an excluded namespace");assertEquals(MetadataState.PARTIAL,uninspected.state(),uninspected.availability());
    }
    @Test void knownNonDirectQueryShapesAreUnsupportedRatherThanMissingMetadata(){
        var snapshot=snapshot("1:100",false);var context=new JdbcAdapter.LiveContext("db","public",List.of("public"),"");
        var queries=List.of("UPDATE public.t SET id=1","SELECT 1","SELECT id FROM (SELECT id FROM public.t) q",
            "SELECT DISTINCT id FROM public.t","SELECT id FROM public.t GROUP BY id","SELECT id FROM public.t HAVING id>0",
            "SELECT t.id FROM public.t t JOIN public.t other ON t.id=other.id","WITH q AS (SELECT id FROM public.t) SELECT id FROM q",
            "SELECT id FROM public.t UNION SELECT id FROM public.t");
        for(int index=0;index<queries.size();index++){
            var proof=RetainedMetadataProof.captureExecution(snapshot,COLUMNS,PROFILE,"s",queries.get(index),context);
            assertFalse(proof.available());assertEquals(MetadataState.UNSUPPORTED,proof.state(),"Shape "+index+": "+proof.availability());
        }
    }
    @Test void typedStaleEvidenceCanReconcileOnlyAgainstExactPhysicalStructure() {
        var original=RetainedMetadataProof.capture(snapshot("1:100",false),COLUMNS,PROFILE,"s");assertTrue(original.available());
        var stale=original.invalidate("A localized human message");assertEquals(MetadataState.STALE,stale.state());assertTrue(stale.capturedStructure());assertTrue(stale.samePhysicalStructure(original));
        assertFalse(stale.samePhysicalStructure(RetainedMetadataProof.capture(snapshot("1:101",false),COLUMNS,PROFILE,"s")));
        var unavailable=RetainedMetadataProof.unavailable("An unrelated localized message").invalidate("Later message");assertEquals(MetadataState.UNAVAILABLE,unavailable.state());assertFalse(unavailable.capturedStructure());assertFalse(unavailable.samePhysicalStructure(original));
    }
    @Test void temporaryMySqlMetadataCannotBorrowPersistentInnoDbGeneration() {
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB)) {
            var rules=io.busystack.busydata.NativeCaseFixtures.rules(engine,0);var scope=new MetadataScope("db","db","t",ObjectKind.COLUMN);
            var entries=List.of(MetadataObject.from("source","p","s",rules,SchemaObject.newBuilder().setCatalog("db").setSchema("db").setName("t").setKind(ObjectKind.TABLE).putProperties("temporary","true").putProperties("nativeGeneration","persistent:1").putProperties("nativeGenerationAvailability","AVAILABLE").build(),IntrospectionLevel.STRUCTURE,1,1));
            var snapshot=new MetadataSnapshot("source","p",1,1,123,rules,entries,Map.of(scope,new MetadataCoverage(scope,IntrospectionLevel.STRUCTURE,MetadataState.AVAILABLE,true,"v",1,1,123,"")));
            var columns=List.of(COLUMNS.getFirst().toBuilder().setCatalog("db").setSchema("db").build());
            assertFalse(RetainedMetadataProof.capture(snapshot,columns,PROFILE.toBuilder().setEngine(engine).build(),"s").available());
        }
    }
    @Test void postgresArrayProofUsesTheCapturedInputContextWithoutJdbc(){
        var ordinary=snapshot("1:100",false);var column=ordinary.namespace("db","public",ObjectKind.COLUMN,"t").getFirst();
        var entries=new ArrayList<>(ordinary.identities().values());entries.remove(column);
        entries.add(MetadataObject.from("source","p","",ordinary.rules(),ordinary.projection(column).toBuilder().putProperties("jdbcType",Integer.toString(java.sql.Types.ARRAY)).putProperties("arrayElementType","date").putProperties("arrayElementTypeId","1082").build(),IntrospectionLevel.STRUCTURE,1,1));
        var arrays=new MetadataSnapshot("source","p",1,1,123,ordinary.rules(),entries,ordinary.coverage());var columns=List.of(COLUMNS.getFirst().toBuilder().setJdbcType(java.sql.Types.ARRAY).build());
        var iso=new JdbcAdapter.LiveContext("db","public",List.of("public"),"","",true,"","",true,"ISO, MDY");
        assertTrue(RetainedMetadataProof.captureExecution(arrays,columns,PROFILE,"s","SELECT id FROM public.t",iso).available());
        for(var context:List.of(new JdbcAdapter.LiveContext("db","public",List.of("public"),"","",true,"","",false,"ISO, MDY"),new JdbcAdapter.LiveContext("db","public",List.of("public"),"","",true,"","",true,"SQL, DMY"),new JdbcAdapter.LiveContext("db","public",List.of("public"),""))){
            var unavailable=RetainedMetadataProof.captureExecution(arrays,columns,PROFILE,"s","SELECT id FROM public.t",context);assertEquals(MetadataState.UNSUPPORTED,unavailable.state());assertFalse(unavailable.capturedStructure());
        }
    }
}
