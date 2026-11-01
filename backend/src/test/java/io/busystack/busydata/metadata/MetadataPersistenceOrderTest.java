package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

/** Cache locality reuses the immutable lookup index, independently of live order. */
class MetadataPersistenceOrderTest {
    private static final IdentifierRules RULES=new IdentifierRules(Engine.POSTGRESQL,0);
    private static final MetadataScope TABLES=new MetadataScope("db","app","",ObjectKind.TABLE);
    private static MetadataObject object(String name){return MetadataObject.from("source","profile","",RULES,SchemaObject.newBuilder().setCatalog("db").setSchema("app").setKind(ObjectKind.TABLE).setName(name).putProperties("nativeId",name).build(),IntrospectionLevel.STRUCTURE,1,1);}
    private static MetadataSnapshot snapshot(List<MetadataObject> objects){return new MetadataSnapshot("source","profile",1,1,1,RULES,objects,Map.of(TABLES,new MetadataCoverage(TABLES,IntrospectionLevel.STRUCTURE,MetadataState.AVAILABLE,true,"fixture",1,1,1,"")));}
    @Test void persistenceUsesStableShaOrderWithoutChangingEncounterOrderOrReferences(){
        var sorted=List.of(object("one"),object("two"),object("three"),object("four"),object("five"),object("six")).stream().sorted(Comparator.comparing(value->value.identity().key())).toList();
        var encountered=sorted.reversed();var model=snapshot(encountered);var other=snapshot(sorted);
        assertEquals(sorted,model.persistenceObjects());assertEquals(other.persistenceObjects(),model.persistenceObjects());assertEquals(encountered,model.identities().values().stream().toList());
        assertEquals(encountered.stream().map(value->value.identity().name()).toList(),model.objects().stream().map(SchemaObject::getName).toList());
        for(int i=0;i<sorted.size();i++){assertSame(sorted.get(i),model.persistenceObjects().get(i));if(i>0)assertTrue(model.persistenceObjects().get(i-1).identity().key().compareTo(model.persistenceObjects().get(i).identity().key())<0);}
        assertEquals(encountered,model.identities().values().stream().toList(),"Persistence iteration cannot reorder a live reader");
    }
    @Test void persistenceViewCannotMutateTheLookupAndContainsEachIdentityOnce(){
        var one=object("one");var two=object("two");var model=snapshot(List.of(two,one,two));var view=model.persistenceObjects();assertEquals(2,view.size());assertEquals(Set.of(one,two),Set.copyOf(view));
        assertThrows(UnsupportedOperationException.class,()->view.add(one));assertThrows(UnsupportedOperationException.class,()->view.set(0,two));assertThrows(UnsupportedOperationException.class,()->view.remove(0));
        var iterator=view.iterator();iterator.next();assertThrows(UnsupportedOperationException.class,iterator::remove);
        for(var object:view)assertSame(object,model.identities().get(object.identity().key()));assertEquals(2,model.identities().size());
    }
    @Test void allLightweightSnapshotViewsShareTheSamePersistenceArrayView(){
        var base=snapshot(List.of(object("two"),object("one")));var stale=new HashMap<>(base.catalogCoverage());stale.replaceAll((scope,state)->state.stale("Inline invalidation"));var latest=base.withCoverage(2,stale);
        var resolution=new MetadataSnapshot.SessionResolution(MetadataState.UNKNOWN,"session",1,"Owned resolution unknown",Map.of());
        var views=List.of(latest,base.withSessionResolution(3,resolution),base.withIdentifierAvailability(false),base.withPublicationRevision(4),base.withConfigurationPublication(5,base,latest));
        for(var view:views){assertSame(base.persistenceObjects(),view.persistenceObjects());assertSame(base.identities(),view.identities());assertEquals(base.estimatedBytes(),view.estimatedBytes());}
        assertTrue(base.complete(TABLES,IntrospectionLevel.STRUCTURE));assertFalse(latest.complete(TABLES,IntrospectionLevel.STRUCTURE));
    }
}
