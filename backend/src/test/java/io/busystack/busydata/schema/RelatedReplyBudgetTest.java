package io.busystack.busydata.schema;

import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.rpc.WorkbenchFailure;
import java.util.*;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

/** Synthetic indexed metadata and real protobuf reply construction only: JDBC 0.
 * Caller provenance and native values remain covered by the live-engine RelatedRows ITs. */
class RelatedReplyBudgetTest {
    private static final int BYTES=512*1024;
    private static final String SOURCE="c".repeat(64),PROFILE="p".repeat(128);
    private record Fixture(MetadataSnapshot snapshot,List<MetadataObject> order){}
    // This mapper-only fixture supplies synthetic verified relationships, as required
    // by the authoritative incoming index. Native verification remains in the ITs.
    private static Fixture fixture(int outgoing,int incoming){
        var rules=new IdentifierRules(Engine.POSTGRESQL,0);var objects=new ArrayList<MetadataObject>();
        for(int index=0;index<outgoing+incoming;index++){
            boolean in=index>=outgoing;String parent=in?"child_"+index:"t",target=in?"t":"parent";
            var object=SchemaObject.newBuilder().setCatalog("db").setSchema("public").setTable(parent).setName("fk_"+index).setKind(ObjectKind.FOREIGN_KEY)
                .putProperties("relationshipVerified","true").putProperties("referencedCatalog","db").putProperties("referencedSchema","public").putProperties("referencedTable",target).putProperties("columnCount","1").putProperties("column.0","id").putProperties("referencedColumn.0","id").build();
            objects.add(MetadataObject.from(SOURCE,PROFILE,"",rules,object,IntrospectionLevel.STRUCTURE,1,1));
        }
        var snapshot=new MetadataSnapshot(SOURCE,PROFILE,7,11,123,rules,objects,Map.of());var order=new ArrayList<>(snapshot.outgoing("db","public","t"));order.addAll(snapshot.incoming("db","public","t"));
        assertEquals(outgoing,snapshot.outgoing("db","public","t").size());assertEquals(incoming,snapshot.incoming("db","public","t").size());return new Fixture(snapshot,List.copyOf(order));
    }
    private static RelatedRowsReply.Builder header(){
        return RelatedRowsReply.newBuilder().setResultId("11111111-1111-4111-8111-111111111111").setSourceRow(999999).setSnapshotRevision(7).setAvailability("available")
            .setBackendInstance("22222222-2222-4222-8222-222222222222").setProfileId(PROFILE).setMetadataSourceIdentity(SOURCE).setSessionId("33333333-3333-4333-8333-333333333333")
            .setSessionRevision(13).setContextRevision(17).setMetadataConfigurationRevision(11);
    }
    private static RelatedRelationship choice(MetadataObject relationship,boolean incoming,String payload){
        var value=Value.newBuilder().setText(payload).build();assertTrue(value.getSerializedSize()<=8192);
        var browse=BrowseRequest.newBuilder().setSessionId("33333333-3333-4333-8333-333333333333").setDocumentId("source-document").setCatalog("db").setSchema("public").setTable(incoming?relationship.identity().parent():"parent")
            .setMetadataSnapshotRevision(7).setMetadataObjectIdentity("d".repeat(64)).setOriginRelationshipIdentity(relationship.identity().key()).setOriginResultId("11111111-1111-4111-8111-111111111111").setOriginSourceRow(999999)
            .addConditions(RowCondition.newBuilder().setColumn("id").setPredicate(ValuePredicate.EQUAL).setValue(value));
        return RelatedRelationship.newBuilder().setIdentity(relationship.identity().key()).setName(relationship.displayName()).setIncoming(incoming).setAvailability("available").setBrowse(browse).build();
    }
    private static boolean incoming(MetadataObject relationship){return !relationship.identity().parent().equals("t");}
    private static RelatedRowsReply expected(List<RelatedRelationship> values){return header().addAllRelationships(values).build();}
    private static RelatedRowsReply mapped(Fixture fixture,List<RelatedRelationship> values,AtomicInteger calls){
        var byIdentity=new HashMap<String,RelatedRelationship>();for(var item:values)byIdentity.put(item.getIdentity(),item);
        return RelatedRows.buildRelationships(header(),fixture.snapshot(),"db","public","t",(relationship,incoming)->{calls.incrementAndGet();var item=byIdentity.get(relationship.identity().key());assertEquals(incoming.booleanValue(),item.getIncoming());return item;});
    }
    private static List<RelatedRelationship> values(Fixture fixture,String payload){return fixture.order().stream().map(item->choice(item,incoming(item),payload)).toList();}
    private static RelatedRelationship payload(RelatedRelationship item,int length){return item.toBuilder().setBrowse(item.getBrowse().toBuilder().setConditions(0,item.getBrowse().getConditions(0).toBuilder().setValue(Value.newBuilder().setText("x".repeat(length))))).build();}
    /** Tune valid <=8000-byte exact text values using the independent generated
     * protobuf size oracle, including all ownership stamps and nested prefixes. */
    private static List<RelatedRelationship> exactBytes(Fixture fixture,int target){
        var values=new ArrayList<>(values(fixture,""));assertTrue(expected(values).getSerializedSize()<target);
        for(int index=0;index<values.size()&&expected(values).getSerializedSize()<target;index++){
            var original=values.get(index);int low=0,high=8000;
            while(low<high){int middle=(low+high+1)/2;values.set(index,payload(original,middle));if(expected(values).getSerializedSize()<=target)low=middle;else high=middle-1;}
            values.set(index,payload(original,low));
        }
        assertEquals(target,expected(values).getSerializedSize());return List.copyOf(values);
    }
    private static void limited(RelatedRowsReply reply){assertEquals("relationship-budget-exceeded",reply.getAvailability());assertEquals(0,reply.getRelationshipsCount());assertTrue(reply.getSerializedSize()<=BYTES);assertEquals(header().getMetadataSourceIdentity(),reply.getMetadataSourceIdentity());assertEquals(header().getMetadataConfigurationRevision(),reply.getMetadataConfigurationRevision());assertEquals(header().getBackendInstance(),reply.getBackendInstance());}

    @ParameterizedTest @ValueSource(ints={128,129})
    void combinedIncomingAndOutgoingFanoutIsCompleteOrExplicitlyLimited(int total){
        var fixture=fixture(64,total-64);var values=values(fixture,"漢");var calls=new AtomicInteger();var reply=mapped(fixture,values,calls);
        if(total==128){assertEquals(expected(values),reply);assertEquals(64,reply.getRelationshipsList().stream().filter(RelatedRelationship::getIncoming).count());}else limited(reply);
        assertEquals(128,calls.get());assertEquals(total,fixture.order().size());
    }
    @ParameterizedTest @ValueSource(ints={-1,0,1})
    void serializedByteBoundaryIncludesStampedHeaderAndEveryChoicePrefix(int delta){
        var fixture=fixture(64,64);var values=exactBytes(fixture,BYTES+delta);var calls=new AtomicInteger();var reply=mapped(fixture,values,calls);
        if(delta<=0){assertEquals(expected(values),reply);assertEquals(BYTES+delta,reply.getSerializedSize());}else limited(reply);
        assertTrue(calls.get()<=128);
    }
    @ParameterizedTest @ValueSource(booleans={false,true})
    void cancellationBeforeOrDuringMappingNeverReturnsPartialChoices(boolean during)throws Exception {
        var fixture=fixture(64,64);var calls=new AtomicInteger();var context=io.grpc.Context.current().withCancellation();var previous=context.attach();
        try{
            if(!during)context.cancel(null);
            var failure=assertThrows(WorkbenchFailure.class,()->RelatedRows.buildRelationships(header(),fixture.snapshot(),"db","public","t",(item,incoming)->{calls.incrementAndGet();context.cancel(null);return choice(item,incoming,"exact");}));
            assertEquals(WorkbenchFailure.Reason.CANCELLED,failure.reason());assertEquals(during?1:0,calls.get());
        }finally{context.detach(previous);context.close();}
    }
    @Test void interruptionRemainsSetAndRejectsBeforeChoiceCallback(){
        var fixture=fixture(1,0);var calls=new AtomicInteger();Thread.currentThread().interrupt();
        try{var failure=assertThrows(WorkbenchFailure.class,()->mapped(fixture,values(fixture,"exact"),calls));assertEquals(WorkbenchFailure.Reason.CANCELLED,failure.reason());assertTrue(Thread.currentThread().isInterrupted());assertEquals(0,calls.get());}finally{Thread.interrupted();}
    }
    @Test void invalidOversizedOwnershipHeaderCannotProduceAnOversizedReply(){
        var fixture=fixture(0,0);var failure=assertThrows(WorkbenchFailure.class,()->RelatedRows.buildRelationships(header().setResultId("x".repeat(BYTES)),fixture.snapshot(),"db","public","t",(item,incoming)->{throw new AssertionError("No choices exist");}));assertEquals(WorkbenchFailure.Reason.MALFORMED_REQUEST,failure.reason());
    }
}
