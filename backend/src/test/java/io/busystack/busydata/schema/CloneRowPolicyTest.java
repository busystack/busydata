package io.busystack.busydata.schema;

import io.busystack.busydata.metadata.TableStructure;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.rpc.WorkbenchFailure;
import java.sql.Types;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class CloneRowPolicyTest {
    private static final Value NULL=Value.newBuilder().setNullValue(Null.getDefaultInstance()).build();
    private static final Value USED=Value.newBuilder().setText("used").build();
    private static SchemaObject.Builder object(ObjectKind kind,String name){return SchemaObject.newBuilder().setCatalog("db").setSchema("schema").setTable("rows").setKind(kind).setName(name);}
    private static SchemaObject column(String name){return object(ObjectKind.COLUMN,name).putProperties("generated","NO").putProperties("identityKind","").build();}
    private static SchemaObject constraint(String name,String type){return object(ObjectKind.CONSTRAINT,name).putProperties("type",type).build();}
    private static SchemaObject index(String name,boolean primary,boolean distinct,List<String> keys,List<String> included){
        var index=object(ObjectKind.INDEX,name).putProperties("indexStructureVersion","2").putProperties("uniquenessAvailability","AVAILABLE").putProperties("uniqueness","UNIQUE")
            .putProperties("primary",Boolean.toString(primary)).putProperties("uniqueNullsPolicy",distinct?"DISTINCT":"NOT_DISTINCT").putProperties("indexStateAvailability","AVAILABLE")
            .putProperties("valid","true").putProperties("ready","true").putProperties("live","true").putProperties("partial","false").putProperties("predicateAvailability","ABSENT")
            .putProperties("columnComponentsComplete","true").putProperties("columnCount",Integer.toString(keys.size()+included.size())).putProperties("keyColumnCount",Integer.toString(keys.size()));
        var all=new ArrayList<>(keys);all.addAll(included);
        for(int ordinal=0;ordinal<all.size();ordinal++)index.putProperties("column."+ordinal,all.get(ordinal)).putProperties("included."+ordinal,Boolean.toString(ordinal>=keys.size())).putProperties("keyKind."+ordinal,"COLUMN");
        return index.build();
    }
    private static TableStructure table(List<SchemaObject> constraints,List<SchemaObject> indexes,Set<String> generated){
        var columns=new ArrayList<SchemaObject>();columns.add(column("id").toBuilder().putProperties("identityKind","a").build());
        for(String name:List.of("a","b","payload"))columns.add(column(name).toBuilder().putProperties("generated",generated.contains(name)?"YES":"NO").build());
        var types=new HashMap<String,Integer>();for(var column:columns)types.put(column.getName(),Types.VARCHAR);
        return new TableStructure(types,generated,List.of(Set.of("id")),"physical","recovery","native","AVAILABLE",columns,constraints,List.of(),indexes);
    }
    private static SchemaObject primary(){return index("primary",true,true,List.of("id"),List.of());}
    private static void fails(WorkbenchFailure.Reason reason,TableStructure table,Map<String,Value> row){assertEquals(reason,assertThrows(WorkbenchFailure.class,()->CloneRowPolicy.omitted(table,row)).reason());}
    @Test void nativePgAndMysqlKindsExcludeNonNullUniqueButKeepOrdinaryNull(){
        for(var kinds:List.of(List.of("p","u"),List.of("PRIMARY KEY","UNIQUE"))){
            var table=table(List.of(constraint("pk",kinds.get(0)),constraint("uq",kinds.get(1))),List.of(primary(),index("nullable_unique",false,true,List.of("a"),List.of())),Set.of("id"));
            var omitted=CloneRowPolicy.omitted(table,Map.of("id",USED,"a",USED,"payload",NULL));
            assertTrue(omitted.containsAll(Set.of("id","a")));assertFalse(omitted.contains("payload"));
        }
    }
    @Test void onlyVerifiedDistinctNullKeepsExplicitNullIntent(){
        for(boolean distinct:List.of(false,true)){
            var table=table(List.of(constraint("pk","p")),List.of(primary(),index("standalone",false,distinct,List.of("a"),List.of())),Set.of("id"));
            assertEquals(!distinct,CloneRowPolicy.omitted(table,Map.of("a",NULL)).contains("a"));
        }
    }
    @Test void compositeNullAndIncludedColumnDoNotBecomeDuplicateKeyValues(){
        var table=table(List.of(constraint("pk","p")),List.of(primary(),index("composite",false,true,List.of("a","b"),List.of("payload"))),Set.of("id"));
        var omitted=CloneRowPolicy.omitted(table,Map.of("a",NULL,"b",USED,"payload",USED));
        assertFalse(omitted.contains("a"));assertTrue(omitted.contains("b"));assertFalse(omitted.contains("payload"));
    }
    @Test void primaryIncludedAttributesRemainOrdinaryValues(){
        var table=table(List.of(constraint("pk","p")),List.of(index("pk_include",true,true,List.of("id"),List.of("payload"))),Set.of("id"));
        var omitted=CloneRowPolicy.omitted(table,Map.of("id",USED,"payload",USED));assertTrue(omitted.contains("id"));assertFalse(omitted.contains("payload"));
    }
    @Test void jdbcIdentityContainingIncludedPayloadDoesNotTurnItIntoACloneKey(){
        var original=table(List.of(constraint("pk","p")),List.of(primary(),index("unique_include",false,true,List.of("a"),List.of("payload"))),Set.of("id"));
        var table=new TableStructure(original.types(),original.generated(),List.of(Set.of("id"),Set.of("a","payload")),original.signature(),original.recoverySignature(),original.nativeGeneration(),original.nativeGenerationAvailability(),original.columns(),original.constraints(),original.relationships(),original.indexes());
        var omitted=CloneRowPolicy.omitted(table,Map.of("a",USED,"payload",USED));assertTrue(omitted.contains("a"));assertFalse(omitted.contains("payload"));assertEquals(List.of(Set.of("id"),Set.of("a","payload")),table.identities());
    }
    @Test void partialExpressionAndInvalidUniqueDefinitionsAreExplicitlyUnsupported(){
        var plain=index("unique",false,true,List.of("a"),List.of());
        for(var invalid:List.of(plain.toBuilder().putProperties("partial","true").putProperties("predicateAvailability","LIMITED").build(),
                plain.toBuilder().putProperties("keyKind.0","EXPRESSION").removeProperties("column.0").build(),plain.toBuilder().putProperties("valid","false").build())){
            fails(WorkbenchFailure.Reason.UNSUPPORTED,table(List.of(constraint("pk","p")),List.of(primary(),invalid),Set.of("id")),Map.of("a",USED));
        }
    }
    @Test void absentNullPolicyOrTruncatedComponentsNeverAcquireDefaultSemantics(){
        var plain=index("unique",false,true,List.of("a"),List.of());
        for(var invalid:List.of(plain.toBuilder().removeProperties("uniqueNullsPolicy").build(),plain.toBuilder().putProperties("columnComponentsComplete","false").build(),
                plain.toBuilder().removeProperties("column.0").build(),plain.toBuilder().putProperties("included.0","true").build())){
            fails(WorkbenchFailure.Reason.INCOMPLETE_METADATA,table(List.of(constraint("pk","p")),List.of(primary(),invalid),Set.of("id")),Map.of("a",NULL));
        }
    }
    @Test void generatedUniqueRequiresAPreservedPlainDistinctNullWitness(){
        var generated=index("generated_unique",false,true,List.of("a"),List.of());
        fails(WorkbenchFailure.Reason.UNSUPPORTED,table(List.of(constraint("pk","p")),List.of(primary(),generated),Set.of("id","a")),Map.of("a",USED));
        var composite=index("generated_composite",false,true,List.of("a","b"),List.of());
        var safe=table(List.of(constraint("pk","p")),List.of(primary(),composite),Set.of("id","a"));
        assertFalse(CloneRowPolicy.omitted(safe,Map.of("a",USED,"b",NULL)).contains("b"));
        var competing=index("not_distinct",false,false,List.of("b"),List.of());
        fails(WorkbenchFailure.Reason.UNSUPPORTED,table(List.of(constraint("pk","p")),List.of(primary(),composite,competing),Set.of("id","a")),Map.of("a",USED,"b",NULL));
    }
    @Test void unprojectedUniqueValuesRemainUnsetAndEditableIdentitiesAreNotBroadened(){
        var table=table(List.of(constraint("pk","p")),List.of(primary(),index("nullable_unique",false,true,List.of("a"),List.of())),Set.of("id"));
        assertTrue(CloneRowPolicy.omitted(table,Map.of("payload",USED)).contains("a"));assertEquals(List.of(Set.of("id")),table.identities());
    }
    @Test void anotherScopeOrMissingBackingPrimaryCannotSupplyCloneEvidence(){
        var foreign=index("foreign",false,true,List.of("a"),List.of()).toBuilder().setSchema("another").build();
        fails(WorkbenchFailure.Reason.INCOMPLETE_METADATA,table(List.of(constraint("pk","p")),List.of(primary(),foreign),Set.of("id")),Map.of());
        fails(WorkbenchFailure.Reason.INCOMPLETE_METADATA,table(List.of(constraint("pk","p")),List.of(),Set.of("id")),Map.of());
    }
}
