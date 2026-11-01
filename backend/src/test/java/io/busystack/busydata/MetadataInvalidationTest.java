package io.busystack.busydata;

import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class MetadataInvalidationTest {
    private static MetadataScope scope(String catalog,String schema,String parent,ObjectKind kind){return new MetadataScope(catalog,schema,parent,kind);}
    private static MetadataSnapshot fixture(Engine engine,int lowerCase){
        var rules=new IdentifierRules(engine,lowerCase);var coverage=new HashMap<MetadataScope,MetadataCoverage>();
        for(String catalog:List.of("database","other"))for(String schema:List.of("public","audit")){
            var names=scope(catalog,schema,"",ObjectKind.TABLE);coverage.put(names,state(names));
            for(String table:List.of("array_edit","array_copy","child"))for(ObjectKind kind:List.of(ObjectKind.COLUMN,ObjectKind.FOREIGN_KEY,ObjectKind.CONSTRAINT)){
                var child=scope(catalog,schema,table,kind);coverage.put(child,state(child));
            }
        }
        var foreign=SchemaObject.newBuilder().setCatalog("database").setSchema("audit").setTable("child").setName("fk_array_edit").setKind(ObjectKind.FOREIGN_KEY)
            .putProperties("referencedCatalog","database").putProperties("referencedSchema","public").putProperties("referencedTable","array_edit").putProperties("relationshipVerified","true").build();
        var object=MetadataObject.from("source","profile","",rules,foreign,IntrospectionLevel.STRUCTURE,1,1);
        return new MetadataSnapshot("source","profile",1,1,1,rules,List.of(object),coverage);
    }
    private static MetadataCoverage state(MetadataScope scope){return new MetadataCoverage(scope,IntrospectionLevel.STRUCTURE,MetadataState.AVAILABLE,true,"fingerprint",1,1,1,"");}
    private static DdlEffect effect(String operation,String name){return DdlEffect.newBuilder().setOperation(operation).setCatalog("database").setSchema("public").setName(name).setKind(ObjectKind.TABLE).build();}
    @Test void unrelatedCreateLeavesExistingStructuralColumnProofComplete(){
        var snapshot=fixture(Engine.POSTGRESQL,0);var selected=MetadataInvalidation.scopes(snapshot,List.of(effect("CREATE","array_copy")),"database","public");
        assertTrue(selected.contains(scope("database","public","",ObjectKind.TABLE)));
        assertTrue(selected.contains(scope("database","public","array_copy",ObjectKind.COLUMN)));
        assertFalse(selected.contains(scope("database","public","array_edit",ObjectKind.COLUMN)));
        assertFalse(selected.contains(scope("database","audit","child",ObjectKind.COLUMN)));
        assertTrue(snapshot.complete(scope("database","public","array_edit",ObjectKind.COLUMN),IntrospectionLevel.STRUCTURE),"The published input is immutable");
    }
    @Test void incomingRelationshipAndConstraintOwnersAreInvalidatedAcrossNamespaces(){
        var selected=MetadataInvalidation.scopes(fixture(Engine.POSTGRESQL,0),List.of(effect("ALTER","array_edit")),"database","public");
        assertTrue(selected.contains(scope("database","audit","child",ObjectKind.FOREIGN_KEY)));
        assertTrue(selected.contains(scope("database","audit","child",ObjectKind.CONSTRAINT)));
        assertFalse(selected.contains(scope("database","audit","child",ObjectKind.COLUMN)));
        assertFalse(selected.contains(scope("other","audit","child",ObjectKind.FOREIGN_KEY)));
    }
    @Test void tableCommentDoesNotDiscardUnchangedColumnAndRelationshipEvidence(){
        var selected=MetadataInvalidation.scopes(fixture(Engine.POSTGRESQL,0),List.of(effect("COMMENT","array_edit")),"database","public");
        assertTrue(selected.contains(scope("database","public","",ObjectKind.TABLE)));
        assertFalse(selected.contains(scope("database","public","array_edit",ObjectKind.COLUMN)));
        assertFalse(selected.contains(scope("database","audit","child",ObjectKind.FOREIGN_KEY)));
    }
    @Test void conservativePostgresEffectsCoverDependentNamespacesWithinTheirDatabase(){
        var snapshot=fixture(Engine.POSTGRESQL,0);var selected=MetadataInvalidation.scopes(snapshot,List.of(effect("DROP","array_edit").toBuilder().setConservative(true).build()),"database","public");
        assertTrue(selected.contains(scope("database","audit","child",ObjectKind.COLUMN)));
        assertFalse(selected.contains(scope("other","audit","child",ObjectKind.COLUMN)));
    }
    @Test void unknownMysqlCrossDatabaseEffectsCannotClaimUnchangedDependencies(){
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB)){
            var snapshot=fixture(engine,0);assertEquals(snapshot.coverage().keySet(),MetadataInvalidation.scopes(snapshot,List.of(effect("RENAME","array_edit").toBuilder().setConservative(true).build()),"database","public"));
        }
    }
    @Test void serverDerivedCaseRulesMatchTheSameNativeRelation(){
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB)){
            var selected=MetadataInvalidation.scopes(fixture(engine,2),List.of(effect("ALTER","ARRAY_EDIT").toBuilder().setCatalog("DATABASE").setSchema("PUBLIC").build()),"database","public");
            assertTrue(selected.contains(scope("database","public","array_edit",ObjectKind.COLUMN)));
            assertFalse(selected.contains(scope("database","public","array_copy",ObjectKind.COLUMN)));
        }
    }
    @Test void contextEffectsStayInsideTheCapturedNamespace(){
        var selected=MetadataInvalidation.scopes(fixture(Engine.POSTGRESQL,0),List.of(effect("CONTEXT","").toBuilder().setKind(ObjectKind.SCHEMA).setConservative(true).build()),"database","public");
        assertTrue(selected.contains(scope("database","public","array_edit",ObjectKind.COLUMN)));
        assertFalse(selected.contains(scope("database","audit","array_edit",ObjectKind.COLUMN)));
    }
}
