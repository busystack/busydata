package io.busystack.busydata.metadata;

import io.busystack.busydata.adapters.JdbcAdapter;
import io.busystack.busydata.protocol.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

/** Names reconcile absence and stale facts; exact acquisitions repair their own objects last. */
class MetadataPublicationPrecedenceTest {
    private static final IdentifierRules RULES=io.busystack.busydata.NativeCaseFixtures.rules(Engine.MYSQL,0);
    private static final MetadataScope NAMES=new MetadataScope("db","db","",ObjectKind.TABLE);
    private static MetadataScope table(String name){return new MetadataScope("db","db","",ObjectKind.TABLE,name,true,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED);}
    private static MetadataScope columns(String name){return new MetadataScope("db","db",name,ObjectKind.COLUMN);}
    private static MetadataCoverage coverage(MetadataScope scope,IntrospectionLevel level,boolean complete){return new MetadataCoverage(scope,level,complete?MetadataState.AVAILABLE:MetadataState.STALE,complete,"fingerprint",1,1,123,complete?"":"Opaque SQL requires reconciliation");}
    private static SchemaObject relation(String name){String id=name.equals("selected")?"11":"12";return SchemaObject.newBuilder().setCatalog("db").setSchema("db").setName(name).setKind(ObjectKind.TABLE).setSubtype(ObjectSubtype.ORDINARY_TABLE).putProperties("catalogFingerprint","unchanged-"+name).putProperties("nativeTableId",id).putProperties("nativeColumnEpoch","0").putProperties("nativeGeneration","innodb:"+id+":rows:0:"+"a".repeat(64)).putProperties("nativeGenerationAvailability","AVAILABLE").build();}
    private static MetadataObject object(SchemaObject wire,IntrospectionLevel level){return MetadataObject.from("source","profile","",RULES,wire,level,1,1);}
    private static MetadataObject column(String table){return object(SchemaObject.newBuilder().setCatalog("db").setSchema("db").setTable(table).setName("id").setKind(ObjectKind.COLUMN).putProperties("jdbcType","4").putProperties("jdbcNativeType","INT").putProperties("type","INT").putProperties("ordinal","1").build(),IntrospectionLevel.STRUCTURE);}
    private static MetadataSnapshot initial(){
        var coverage=new HashMap<MetadataScope,MetadataCoverage>();coverage.put(NAMES,coverage(NAMES,IntrospectionLevel.STRUCTURE,false));
        var objects=new ArrayList<MetadataObject>();
        for(String name:List.of("selected","unrequested")){objects.add(object(relation(name),IntrospectionLevel.STRUCTURE));objects.add(column(name));coverage.put(table(name),coverage(table(name),IntrospectionLevel.STRUCTURE,false));coverage.put(columns(name),coverage(columns(name),IntrospectionLevel.STRUCTURE,false));}
        return new MetadataSnapshot("source","profile",1,1,123,RULES,objects,coverage);
    }
    /** Evaluate normalized acquisition commands as immutable snapshot facts, with no connection. */
    private static MetadataSnapshot snapshot(MetadataSnapshot before,LinkedHashMap<MetadataScope,MetadataPlatform.Branch> branches){
        var entries=new LinkedHashMap<>(before.identities());var coverage=new HashMap<>(before.catalogCoverage());
        for(var entry:branches.entrySet()){
            var branch=entry.getValue();if(branch.coverage().complete()&&!branch.reuse()){
                entries.values().removeIf(entry.getKey()::contains);
                for(var object:branch.normalized())entries.put(object.identity().key(),object);
            }
            coverage.put(entry.getKey(),branch.coverage());
        }
        return new MetadataSnapshot("source","profile",2,1,124,RULES,entries.values(),coverage);
    }
    @Test void staleNamesCannotOverwriteFreshExactFactsOrReviveUnrequestedStructure()throws Exception {
        var before=initial();var acquired=List.of(object(relation("selected"),IntrospectionLevel.NAMES),object(relation("unrequested"),IntrospectionLevel.NAMES));
        var reconciled=MetadataNames.reconcile(before,NAMES,acquired,new MetadataNames.Evidence(Map.of(ObjectKind.COLUMN,Map.of("selected","fingerprint","unrequested","fingerprint")),Map.of(),Set.of(ObjectKind.COLUMN)),Long.MAX_VALUE);
        assertTrue(reconciled.objects().stream().allMatch(object->object.state()==MetadataState.STALE));
        assertTrue(reconciled.staleScopes().contains(table("selected")));
        var branches=new LinkedHashMap<MetadataScope,MetadataPlatform.Branch>();
        // Actual reconciliation stages invalidated exact scopes before its names
        // command; a subsequent put repairs the value but keeps this position.
        branches.put(table("selected"),MetadataPlatform.Branch.reused(coverage(table("selected"),IntrospectionLevel.STRUCTURE,false)));
        branches.put(table("unrequested"),MetadataPlatform.Branch.reused(coverage(table("unrequested"),IntrospectionLevel.STRUCTURE,false)));
        branches.put(NAMES,new MetadataPlatform.Branch(List.of(),coverage(NAMES,IntrospectionLevel.NAMES,true),reconciled.objects(),false));
        var fresh=object(relation("selected").toBuilder().putProperties("remarks","Fresh explicit inspection").build(),IntrospectionLevel.STRUCTURE);
        branches.put(table("selected"),new MetadataPlatform.Branch(List.of(),coverage(table("selected"),IntrospectionLevel.STRUCTURE,true),List.of(fresh),false));
        branches.put(columns("selected"),new MetadataPlatform.Branch(List.of(),coverage(columns("selected"),IntrospectionLevel.STRUCTURE,true),List.of(column("selected")),false));
        var oldOrder=snapshot(before,branches);
        assertEquals(MetadataState.STALE,oldOrder.resolve("db","db",ObjectKind.TABLE,"","selected",true).getFirst().state(),"The observed insertion order loses the freshly acquired relation even though its exact coverage is complete");
        assertTrue(oldOrder.complete(table("selected"),IntrospectionLevel.STRUCTURE));
        MetadataRefresh.namesBeforeDetails(branches,Set.of(NAMES));
        var published=snapshot(before,branches);
        assertSame(fresh,published.resolve("db","db",ObjectKind.TABLE,"","selected",true).getFirst());
        assertEquals(MetadataState.AVAILABLE,fresh.state());assertTrue(published.complete(table("selected"),IntrospectionLevel.STRUCTURE));assertTrue(published.complete(columns("selected"),IntrospectionLevel.STRUCTURE));
        assertEquals(IntrospectionLevel.NAMES,published.coverage(NAMES).orElseThrow().level());assertFalse(published.complete(NAMES,IntrospectionLevel.STRUCTURE));
        assertEquals(MetadataState.STALE,published.resolve("db","db",ObjectKind.TABLE,"","unrequested",true).getFirst().state());assertEquals(MetadataState.STALE,published.coverage(columns("unrequested")).orElseThrow().state());
        var profile=Profile.newBuilder().setId("profile").setEngine(Engine.MYSQL).setDatabase("db").build();var context=new JdbcAdapter.LiveContext("db","db",List.of("db"),"");
        assertTrue(RetainedMetadataProof.sourceTable(published,profile,"owner","SELECT id FROM db.selected",context).isPresent());
        var selected=Column.newBuilder().setOrdinal(1).setName("id").setBaseColumn("id").setTable("selected").setCatalog("db").setSchema("db").setJdbcType(4).setProvenanceKnown(true).build();
        assertTrue(RetainedMetadataProof.captureExecution(published,List.of(selected),profile,"owner","SELECT id FROM db.selected",context).available());
        assertEquals(MetadataState.AVAILABLE,before.resolve("db","db",ObjectKind.TABLE,"","selected",true).getFirst().state());assertFalse(before.complete(columns("selected"),IntrospectionLevel.STRUCTURE));
    }
}
