package io.busystack.busydata;

import io.busystack.busydata.analysis.language.*;
import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class RelationshipCompletenessTest {
    private record Fixture(MetadataSnapshot snapshot,MetadataObject relationship){}
    private static MetadataScope scope(String table,ObjectKind kind){return new MetadataScope("database","public",table,kind);}
    private static MetadataObject object(String table,String name,ObjectKind kind,Map<String,String> properties){return MetadataObject.from("source","profile","",new IdentifierRules(Engine.POSTGRESQL,0),SchemaObject.newBuilder().setCatalog("database").setSchema("public").setTable(table).setName(name).setKind(kind).putAllProperties(properties).build(),IntrospectionLevel.STRUCTURE,1,1);}
    private static MetadataCoverage complete(MetadataScope scope){return new MetadataCoverage(scope,IntrospectionLevel.STRUCTURE,MetadataState.AVAILABLE,true,"fingerprint",1,1,1,"");}
    private static Fixture fixture(){
        var objects=new ArrayList<MetadataObject>();objects.add(object("","child",ObjectKind.TABLE,Map.of()));objects.add(object("","parent",ObjectKind.TABLE,Map.of()));
        objects.add(object("child","parent_id",ObjectKind.COLUMN,Map.of("type","integer")));objects.add(object("parent","id",ObjectKind.COLUMN,Map.of("type","integer")));
        var relationship=object("child","fk_parent",ObjectKind.FOREIGN_KEY,Map.of("relationshipVerified","true","columnCount","1","column.0","parent_id","referencedColumn.0","id","referencedCatalog","database","referencedSchema","public","referencedTable","parent"));objects.add(relationship);
        var coverage=new HashMap<MetadataScope,MetadataCoverage>();for(String table:List.of("child","parent"))for(ObjectKind kind:List.of(ObjectKind.COLUMN,ObjectKind.FOREIGN_KEY))coverage.put(scope(table,kind),complete(scope(table,kind)));coverage.put(scope("",ObjectKind.TABLE),complete(scope("",ObjectKind.TABLE)));
        return new Fixture(new MetadataSnapshot("source","profile",1,1,1,new IdentifierRules(Engine.POSTGRESQL,0),objects,coverage),relationship);
    }
    private static MetadataSnapshot withCoverage(Fixture fixture,MetadataCoverage replacement){var before=fixture.snapshot();var coverage=new HashMap<>(before.coverage());coverage.put(replacement.scope(),replacement);return new MetadataSnapshot(before.source(),before.profileId(),2,1,2,before.rules(),before.identities().values(),coverage);}
    private static CompletionService.Batch joins(MetadataSnapshot snapshot){String sql="SELECT * FROM public.child c JOIN public.parent p ON ";return new SemanticDocument(sql,Engine.POSTGRESQL).completeBatch(sql.length(),new ResolutionContext("database","public",List.of("public"),true,snapshot.revision(),1,snapshot.rules(),snapshot),Map.of());}
    @Test void completeNativeComponentsEnableRelationshipAndJoin(){var f=fixture();assertTrue(f.snapshot().relationshipComplete(f.relationship()));assertTrue(f.snapshot().incomingComplete());assertTrue(joins(f.snapshot()).items().stream().anyMatch(item->item.getKind().equals("join")));}
    @Test void staleForeignKeyCoverageCannotOfferAFormerlyVerifiedJoin(){var f=fixture();var stale=withCoverage(f,complete(scope("child",ObjectKind.FOREIGN_KEY)).stale("DDL is pending"));assertEquals(MetadataState.AVAILABLE,f.relationship().state(),"The retained native object is immutable");assertFalse(stale.relationshipComplete(f.relationship()));assertFalse(stale.incomingComplete());var batch=joins(stale);assertTrue(batch.items().stream().noneMatch(item->item.getKind().equals("join")));assertTrue(batch.metadataIncomplete());}
    @Test void targetColumnsMustHaveStructuralCoverage(){var f=fixture();var target=scope("parent",ObjectKind.COLUMN);var names=withCoverage(f,new MetadataCoverage(target,IntrospectionLevel.NAMES,MetadataState.AVAILABLE,true,"names",1,1,1,""));assertFalse(names.relationshipComplete(f.relationship()));assertFalse(names.incomingComplete());}
    @Test void missingReferencedColumnCannotEstablishVerifiedIdentity(){var f=fixture();var objects=f.snapshot().identities().values().stream().filter(object->!(object.identity().kind()==ObjectKind.COLUMN&&object.identity().parent().equals("parent"))).toList();var snapshot=new MetadataSnapshot("source","profile",2,1,2,f.snapshot().rules(),objects,f.snapshot().coverage());assertFalse(snapshot.relationshipComplete(f.relationship()));assertFalse(snapshot.incomingComplete());}
    @Test void unverifiedRelationshipDoesNotMakeIncomingEnumerationComplete(){var f=fixture();var properties=new HashMap<>(f.relationship().properties());properties.put("relationshipVerified","false");var foreign=object("child","fk_parent",ObjectKind.FOREIGN_KEY,properties);var objects=new ArrayList<>(f.snapshot().identities().values());objects.remove(f.relationship());objects.add(foreign);var snapshot=new MetadataSnapshot("source","profile",2,1,2,f.snapshot().rules(),objects,f.snapshot().coverage());assertFalse(snapshot.relationshipComplete(foreign));assertFalse(snapshot.incomingComplete());}
    @Test void partialComponentListsNeverBecomeGeneratedPredicates(){var f=fixture();var properties=new HashMap<>(f.relationship().properties());properties.put("columnCount","2");var foreign=object("child","fk_parent",ObjectKind.FOREIGN_KEY,properties);var objects=new ArrayList<>(f.snapshot().identities().values());objects.remove(f.relationship());objects.add(foreign);var snapshot=new MetadataSnapshot("source","profile",2,1,2,f.snapshot().rules(),objects,f.snapshot().coverage());assertFalse(snapshot.relationshipComplete(foreign));assertTrue(joins(snapshot).items().stream().noneMatch(item->item.getKind().equals("join")));}
    @Test void foreignSnapshotObjectsCannotAuthorizeRelationshipIdentity(){var f=fixture();var forged=object("child","fk_parent",ObjectKind.FOREIGN_KEY,f.relationship().properties());assertNotSame(forged,f.relationship());assertFalse(f.snapshot().relationshipComplete(forged));}
}
