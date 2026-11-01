package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.*;
import java.util.*;
import java.util.concurrent.atomic.AtomicBoolean;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class MetadataIdentityIndexTest {
    private static final IdentifierRules RULES=new IdentifierRules(Engine.POSTGRESQL,0);
    private static MetadataObject object(String name,int id,String comment){return MetadataObject.from("source","profile","",RULES,SchemaObject.newBuilder().setCatalog("db").setSchema("public").setName(name).setKind(ObjectKind.TABLE).putProperties("nativeId",Integer.toString(id)).putProperties("remarks",comment).build(),IntrospectionLevel.STRUCTURE,1,1);}
    private static MetadataSnapshot snapshot(long revision,List<MetadataObject> objects){return new MetadataSnapshot("source","profile",revision,1,123,RULES,objects,Map.of());}
    @Test void exactLookupAndEveryOrderedViewMatchThePublishedEncounterOrder(){
        var first=object("z",1,"first");var second=object("a",2,"second");var third=object("m",3,"third");var source=List.of(first,second,third);var model=snapshot(1,source);var identities=model.identities();
        var expected=source.stream().map(value->value.identity().key()).toList();
        assertEquals(expected,new ArrayList<>(identities.keySet()));assertEquals(source,new ArrayList<>(identities.values()));assertEquals(expected,identities.entrySet().stream().map(Map.Entry::getKey).toList());
        assertEquals(expected,identities.keySet().parallelStream().toList());assertEquals(source,identities.values().parallelStream().toList());
        var traversed=new ArrayList<String>();identities.forEach((key,value)->{traversed.add(key);assertSame(value,identities.get(new String(key)));assertTrue(identities.entrySet().contains(Map.entry(key,value)));});assertEquals(expected,traversed);
        assertEquals(List.of("z","a","m"),model.objects().stream().map(SchemaObject::getName).toList());assertEquals(List.of("a","m","z"),model.namespace("db","public",ObjectKind.TABLE,"").stream().map(value->value.identity().name()).toList(),"Namespace sorting is independent of encounter order");
        assertNull(identities.get(null));assertFalse(identities.containsKey(null));assertFalse(identities.containsValue(null));assertNull(identities.get("missing"));assertNull(identities.get(7));
        var expectedMap=new LinkedHashMap<String,MetadataObject>();for(var value:source)expectedMap.put(value.identity().key(),value);assertEquals(expectedMap,identities);assertEquals(expectedMap.hashCode(),identities.hashCode());
    }
    @Test void mapEntriesAndAllViewsRejectMutationBeforeCallingSuppliedFunctions(){
        var value=object("t",1,"");var map=snapshot(1,List.of(value)).identities();String key=value.identity().key();var invoked=new AtomicBoolean();
        assertThrows(UnsupportedOperationException.class,()->map.put(key,value));assertThrows(UnsupportedOperationException.class,()->map.remove(key));assertThrows(UnsupportedOperationException.class,map::clear);
        assertThrows(UnsupportedOperationException.class,()->map.compute(key,(ignored,current)->{invoked.set(true);return current;}));assertFalse(invoked.get());assertThrows(UnsupportedOperationException.class,()->map.replaceAll((ignored,current)->{invoked.set(true);return current;}));assertFalse(invoked.get());
        assertThrows(UnsupportedOperationException.class,()->map.keySet().remove(key));assertThrows(UnsupportedOperationException.class,()->map.values().remove(value));assertThrows(UnsupportedOperationException.class,()->map.entrySet().clear());
        var entry=map.entrySet().iterator().next();assertThrows(UnsupportedOperationException.class,()->entry.setValue(value));var iterator=map.keySet().iterator();iterator.next();assertThrows(UnsupportedOperationException.class,iterator::remove);
        var empty=snapshot(1,List.of()).identities();assertThrows(UnsupportedOperationException.class,empty::clear);assertThrows(UnsupportedOperationException.class,()->empty.computeIfAbsent("missing",ignored->{invoked.set(true);return value;}));assertFalse(invoked.get());
    }
    @Test void oldReadersKeepTheirIndexAndSessionViewsShareItAcrossPublication(){
        var original=object("t",1,"original");var stable=object("u",2,"stable");var before=snapshot(1,List.of(original,stable));var replacement=object("t",1,"replacement");var after=snapshot(2,List.of(replacement,stable));
        assertSame(original,before.identities().get(original.identity().key()));assertSame(replacement,after.identities().get(original.identity().key()));assertSame(stable,after.identities().get(stable.identity().key()));assertEquals("original",before.objects().getFirst().getPropertiesOrThrow("remarks"));
        var visible=before.withSessionResolution(3,new MetadataSnapshot.SessionResolution(MetadataState.UNKNOWN,"owner",1,"Inspect owned context",Map.of()));assertSame(before.identities(),visible.identities());assertSame(before.identities(),before.withCoverage(4,Map.of()).identities());assertSame(original,visible.identities().get(original.identity().key()));
    }
    @Test void equalDuplicatesKeepTheFirstPositionAndLastMapValue(){
        var first=object("t",1,"same");var equal=object("t",1,"same");var other=object("u",2,"");assertNotSame(first,equal);assertEquals(first,equal);
        var model=snapshot(1,List.of(first,other,equal));assertEquals(2,model.identities().size());assertSame(equal,model.identities().get(first.identity().key()));assertSame(equal,model.identities().values().iterator().next());assertEquals(List.of(first.identity().key(),other.identity().key()),new ArrayList<>(model.identities().keySet()));
    }
    @Test void conflictingIdentitiesNeverProduceAPartiallyBuiltIndex(){
        var first=object("t",1,"before");var changed=object("t",1,"after");assertThrows(IllegalArgumentException.class,()->snapshot(1,List.of(first,changed)));assertEquals("before",first.properties().get("remarks"));
    }
}
