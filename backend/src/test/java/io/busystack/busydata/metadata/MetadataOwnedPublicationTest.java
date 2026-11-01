package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.*;
import java.util.*;
import java.util.concurrent.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

/** Pure shadow/coverage contracts; native ownership and private-cache races have live fixtures. */
class MetadataOwnedPublicationTest {
    private static final IdentifierRules RULES=new IdentifierRules(Engine.POSTGRESQL,0);
    private static final MetadataOwnedPublication.Owner OWNER=new MetadataOwnedPublication.Owner("source","profile","session","db","pg_temp_1",1,2);
    private static final long DEADLINE=Long.MAX_VALUE;
    private static MetadataScope relation(String name){return new MetadataScope("db","public","",ObjectKind.TABLE,name,true,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED);}
    private static MetadataScope columns(String name){return new MetadataScope("db","public",name,ObjectKind.COLUMN);}
    private static MetadataCoverage available(MetadataScope scope,IntrospectionLevel level){return new MetadataCoverage(scope,level,MetadataState.AVAILABLE,true,"fixture",1,2,1,"");}
    private static SchemaObject table(String name,String nativeId,boolean temporary){
        var value=SchemaObject.newBuilder().setCatalog("db").setSchema("public").setName(name).setKind(ObjectKind.TABLE).setSubtype(ObjectSubtype.ORDINARY_TABLE).putProperties("nativeId",nativeId);
        if(temporary)value.putProperties("temporary","true");return value.build();
    }
    private static MetadataSnapshot durable(){
        var table=MetadataObject.from("source","profile","",RULES,table("rows","1",false),IntrospectionLevel.SOURCE,1,2);
        var column=MetadataObject.from("source","profile","",RULES,SchemaObject.newBuilder().setCatalog("db").setSchema("public").setTable("rows").setName("persistent_a").setKind(ObjectKind.COLUMN).putProperties("nativeId","1:1").putProperties("nativeType","integer").build(),IntrospectionLevel.STRUCTURE,1,2);
        var key=MetadataObject.from("source","profile","",RULES,SchemaObject.newBuilder().setCatalog("db").setSchema("public").setTable("rows").setName("old_fk").setKind(ObjectKind.FOREIGN_KEY).build(),IntrospectionLevel.STRUCTURE,1,2);
        var foreign=new MetadataScope("db","public","rows",ObjectKind.FOREIGN_KEY);
        return new MetadataSnapshot("source","profile",1,1,1,RULES,List.of(table,column,key),Map.of(relation("rows"),available(relation("rows"),IntrospectionLevel.SOURCE),columns("rows"),available(columns("rows"),IntrospectionLevel.STRUCTURE),foreign,available(foreign,IntrospectionLevel.STRUCTURE)));
    }
    private static MetadataPlatform.Branch branch(MetadataScope scope,IntrospectionLevel level,SchemaObject... values){return new MetadataPlatform.Branch(List.of(values),available(scope,level));}
    private static MetadataSnapshot compose(MetadataSnapshot durable,MetadataOwnedPublication.Result plan)throws Exception{
        return MetadataSnapshot.compose(durable,plan.facts(),plan.replacements(),plan.coverage(),plan.removedCoverage(),2,1,2,DEADLINE);
    }
    @Test void aTemporaryNamesOnlyRelationNeverBorrowsPersistentColumnsOrForeignKeys()throws Exception{
        var base=durable();var platform=new MetadataPlatform();try(var admission=platform.admitAcquisition()){
            var request=Map.of(relation("rows"),branch(relation("rows"),IntrospectionLevel.NAMES,table("rows","2",true)));
            var plan=MetadataOwnedPublication.prepare(OWNER,base,null,Set.of(),Map.of(),1,RULES,MetadataConfiguration.defaults(),request,true,false,admission,DEADLINE);var owned=compose(base,plan);
            assertEquals("session",owned.resolve("db","public",ObjectKind.TABLE,"","rows",true).getFirst().identity().sessionOwner());
            assertTrue(owned.namespace("db","public",ObjectKind.COLUMN,"rows").isEmpty());assertTrue(owned.outgoing("db","public","rows").isEmpty());
            assertEquals(MetadataState.NOT_REQUESTED,owned.catalogCoverage().get(columns("rows")).state());assertFalse(owned.complete(columns("rows"),IntrospectionLevel.STRUCTURE));
            assertEquals(1,base.namespace("db","public",ObjectKind.COLUMN,"rows").size());assertEquals(1,base.outgoing("db","public","rows").size());assertTrue(base.complete(columns("rows"),IntrospectionLevel.STRUCTURE));
        }
    }
    @Test void anEmptyVerifiedInventoryRetiresEveryTemporaryMaskAndRestoresTheExactDurableFacts()throws Exception{
        var base=durable();var platform=new MetadataPlatform();try(var first=platform.admitAcquisition();var second=platform.admitAcquisition()){
            var requested=Map.of(relation("rows"),branch(relation("rows"),IntrospectionLevel.NAMES,table("rows","2",true)));
            var created=MetadataOwnedPublication.prepare(OWNER,base,null,Set.of(),Map.of(),1,RULES,MetadataConfiguration.defaults(),requested,true,false,first,DEADLINE);var held=compose(base,created);
            var removed=MetadataOwnedPublication.prepare(OWNER,base,held,created.replacements(),Map.of(),2,RULES,MetadataConfiguration.defaults(),Map.of(),true,false,second,DEADLINE);
            assertTrue(removed.facts().isEmpty());assertTrue(removed.replacements().isEmpty());assertTrue(removed.coverage().isEmpty());assertTrue(removed.removedCoverage().isEmpty());
            assertEquals(created.replacements(),removed.removedTemporary());assertEquals("session",held.resolve("db","public",ObjectKind.TABLE,"","rows",true).getFirst().identity().sessionOwner());
            assertTrue(base.resolve("db","public",ObjectKind.TABLE,"","rows",true).getFirst().identity().sessionOwner().isEmpty());
        }
    }
    @Test void removingTemporaryInventoryPreservesAnUncommittedOrdinaryBranch()throws Exception{
        var base=durable();var platform=new MetadataPlatform();try(var first=platform.admitAcquisition();var second=platform.admitAcquisition()){
            var requests=new LinkedHashMap<MetadataScope,MetadataPlatform.Branch>();requests.put(relation("pending"),branch(relation("pending"),IntrospectionLevel.NAMES,table("pending","3",false)));requests.put(relation("rows"),branch(relation("rows"),IntrospectionLevel.NAMES,table("rows","2",true)));
            var created=MetadataOwnedPublication.prepare(OWNER,base,null,Set.of(),Map.of(),1,RULES,MetadataConfiguration.defaults(),requests,true,false,first,DEADLINE);var held=compose(base,created);var pending=held.resolve("db","public",ObjectKind.TABLE,"","pending",true).getFirst();
            var removed=MetadataOwnedPublication.prepare(OWNER,base,held,created.replacements(),Map.of(),2,RULES,MetadataConfiguration.defaults(),Map.of(),true,false,second,DEADLINE);var current=compose(base,removed);
            assertSame(pending,current.resolve("db","public",ObjectKind.TABLE,"","pending",true).getFirst());assertTrue(pending.identity().sessionOwner().isEmpty());
            assertEquals(base.resolve("db","public",ObjectKind.TABLE,"","rows",true).getFirst().identity().key(),current.resolve("db","public",ObjectKind.TABLE,"","rows",true).getFirst().identity().key());assertEquals(Set.of(relation("pending")),removed.replacements());
        }
    }
    @Test void freshOwnedColumnsSurviveTheirLaterTableBranchInNativeInventoryOrder()throws Exception{
        var base=durable();var platform=new MetadataPlatform();try(var admission=platform.admitAcquisition()){
            var values=new LinkedHashMap<MetadataScope,MetadataPlatform.Branch>();
            var column=SchemaObject.newBuilder().setCatalog("db").setSchema("public").setTable("rows").setName("temporary_b").setKind(ObjectKind.COLUMN).putProperties("nativeId","2:1").putProperties("temporary","true").build();
            values.put(columns("rows"),branch(columns("rows"),IntrospectionLevel.STRUCTURE,column));values.put(relation("rows"),branch(relation("rows"),IntrospectionLevel.STRUCTURE,table("rows","2",true)));
            var plan=MetadataOwnedPublication.prepare(OWNER,base,null,Set.of(),Map.of(),1,RULES,MetadataConfiguration.defaults(),values,true,false,admission,DEADLINE);var current=compose(base,plan);
            assertEquals(List.of("temporary_b"),current.namespace("db","public",ObjectKind.COLUMN,"rows").stream().map(value->value.identity().name()).toList());assertTrue(current.catalogCoverage().get(columns("rows")).complete());assertEquals(IntrospectionLevel.STRUCTURE,current.catalogCoverage().get(columns("rows")).level());
        }
    }
    @Test void deletingAnOwnedNamesBranchMasksInheritedChildrenInsteadOfReturningAFalseCompleteEmptyStructure()throws Exception{
        var base=durable();var platform=new MetadataPlatform();try(var admission=platform.admitAcquisition()){
            var plan=MetadataOwnedPublication.prepare(OWNER,base,null,Set.of(),Map.of(),1,RULES,MetadataConfiguration.defaults(),Map.of(relation("rows"),branch(relation("rows"),IntrospectionLevel.NAMES)),false,false,admission,DEADLINE);var current=compose(base,plan);
            assertTrue(current.resolve("db","public",ObjectKind.TABLE,"","rows",true).isEmpty());assertTrue(current.namespace("db","public",ObjectKind.COLUMN,"rows").isEmpty());assertTrue(current.outgoing("db","public","rows").isEmpty());assertFalse(current.complete(columns("rows"),IntrospectionLevel.STRUCTURE));assertEquals(MetadataState.STALE,current.catalogCoverage().get(columns("rows")).state());
        }
    }
    @Test void cancelledOrMismatchedOwnedAcquisitionCannotCreateAPlan()throws Exception{
        var base=durable();var platform=new MetadataPlatform();try(var admission=platform.admitAcquisition();var context=io.grpc.Context.current().withCancellation()){
            context.cancel(null);assertThrows(CancellationException.class,()->context.call(()->MetadataOwnedPublication.prepare(OWNER,base,null,Set.of(),Map.of(),1,RULES,MetadataConfiguration.defaults(),Map.of(),true,false,admission,DEADLINE)));
            var scope=relation("rows");var wrong=new MetadataCoverage(scope,IntrospectionLevel.NAMES,MetadataState.AVAILABLE,true,"fixture",2,2,1,"");
            assertThrows(IllegalStateException.class,()->MetadataOwnedPublication.prepare(OWNER,base,null,Set.of(),Map.of(),1,RULES,MetadataConfiguration.defaults(),Map.of(scope,new MetadataPlatform.Branch(List.of(table("rows","2",true)),wrong)),true,false,admission,DEADLINE));
            assertTrue(base.resolve("db","public",ObjectKind.TABLE,"","rows",true).getFirst().identity().sessionOwner().isEmpty());
        }
    }
    @Test void temporaryRetirementPreservesCollateralOrdinaryStalenessAndCoverageTombstones()throws Exception{
        var base=durable();var ordinary=MetadataObject.from("source","profile","",RULES,table("rows","3",false),IntrospectionLevel.NAMES,1,2);var temporary=MetadataObject.from("source","profile","session",RULES,table("other","4",true),IntrospectionLevel.NAMES,1,2);
        var other=relation("other");var foreign=new MetadataScope("db","public","rows",ObjectKind.FOREIGN_KEY);var stale=base.catalogCoverage().get(columns("rows")).stale("Names-only ordinary metadata did not certify old columns");
        var scopes=Set.of(relation("rows"),other);var prior=MetadataSnapshot.compose(base,List.of(ordinary,temporary),scopes,Map.of(relation("rows"),available(relation("rows"),IntrospectionLevel.NAMES),other,available(other,IntrospectionLevel.NAMES),columns("rows"),stale),Set.of(foreign),2,1,1,DEADLINE);
        var platform=new MetadataPlatform();try(var admission=platform.admitAcquisition()){
            var retired=MetadataOwnedPublication.prepare(OWNER,base,prior,scopes,Map.of(),1,RULES,MetadataConfiguration.defaults(),Map.of(),true,false,admission,DEADLINE);var current=compose(base,retired);
            assertSame(ordinary,current.resolve("db","public",ObjectKind.TABLE,"","rows",true).getFirst());assertEquals(MetadataState.STALE,current.catalogCoverage().get(columns("rows")).state());assertFalse(current.complete(columns("rows"),IntrospectionLevel.STRUCTURE));assertNull(current.catalogCoverage().get(foreign));assertTrue(retired.removedCoverage().contains(foreign));assertTrue(current.resolve("db","public",ObjectKind.TABLE,"","other",true).isEmpty());assertEquals(2,prior.localIdentities().size());
        }
    }
}
