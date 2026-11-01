package io.busystack.busydata.schema;

import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.results.ResultStore;
import io.busystack.busydata.sessions.SessionRegistry;
import java.util.*;

/** Verified FK navigation returns a typed browse intention for explicit review. */
public final class RelatedRows {
    private static final int MAX_RELATIONSHIPS=128,MAX_REPLY_BYTES=512*1024;
    private final MetadataPlatform metadata;
    private final ResultStore results;
    public RelatedRows(MetadataPlatform metadata,ResultStore results){this.metadata=metadata;this.results=results;}
    public RelatedRowsReply list(SessionRegistry.Session session,RelatedRowsRequest request)throws Exception {
        if(!session.lock.tryLock())throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.UNAVAILABLE);
        try{
            checkPhysicalOwner(session,request);
            var source=ownedSource(session,request);checkRequestedRevision(session,request.getSnapshotRevision());source=verifyWitness(session,source);
            return listOwned(session,request,metadata.capture(session),source);
        }finally{session.lock.unlock();}
    }
    /** Native witness reads precede a brief exact published-revision capture. */
    public void verifyBrowse(SessionRegistry.Session session,BrowseRequest request,long acceptedRevision)throws Exception {
        if(!session.lock.isHeldByCurrentThread())throw new IllegalStateException("Physical-session ownership is required for related browse verification");
        var origin=RelatedRowsRequest.newBuilder().setSessionId(request.getSessionId()).setResultId(request.getOriginResultId()).setSourceRow(request.getOriginSourceRow()).setSnapshotRevision(request.getMetadataSnapshotRevision()).setDocumentId(request.getDocumentId()).build();
        var source=ownedSource(session,origin);checkRequestedRevision(session,acceptedRevision);source=verifyWitness(session,source);var snapshot=metadata.capture(session);
        if(snapshot.revision()!=acceptedRevision)throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.STALE);
        var choices=listOwned(session,origin,snapshot,source);
        var choice=choices.getRelationshipsList().stream().filter(c->c.getIdentity().equals(request.getOriginRelationshipIdentity())&&c.getAvailability().equals("available")).findFirst().orElseThrow(()->new IllegalArgumentException("Related-row identity or source row is unavailable"));
        var expected=choice.getBrowse();
        if(expected.getMetadataSnapshotRevision()!=request.getMetadataSnapshotRevision()||!expected.getCatalog().equals(request.getCatalog())||!expected.getSchema().equals(request.getSchema())||!expected.getTable().equals(request.getTable())||!expected.getConditionsList().equals(request.getConditionsList())||!expected.getMetadataObjectIdentity().equals(request.getMetadataObjectIdentity()))throw new IllegalArgumentException("Related-row typed predicate does not match the retained key");
    }
    private record VerifiedSource(ResultStore.Result result,RetainedMetadataProof proof,String availability){}
    /** Reject a superseded physical request before retained-witness or catalog work.
     * Presence is explicit because an initial revision may legitimately be zero. */
    private static void checkPhysicalOwner(SessionRegistry.Session session,RelatedRowsRequest request){
        if(io.grpc.Context.current().isCancelled()||Thread.currentThread().isInterrupted())throw new java.util.concurrent.CancellationException("Related-row lookup cancelled");
        if(!request.getSessionId().equals(session.id))throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.INVALID_OWNER);
        if(!request.hasExpectedSessionRevision()||!request.hasExpectedContextRevision()||request.getExpectedSessionRevision()<0||request.getExpectedContextRevision()<0||request.getSnapshotRevision()<0||request.getSourceRow()<0)throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.MALFORMED_REQUEST);
        if(request.getExpectedSessionRevision()!=session.revision||request.getExpectedContextRevision()!=session.contextRevision)throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.INVALID_REVISION);
        if(session.state==TransactionState.UNKNOWN_TRANSACTION)throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.TRANSACTION_UNKNOWN);
        if(session.physicalEnded()||session.state==TransactionState.DISCONNECTED)throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.INVALID_OWNER);
    }
    private void checkRequestedRevision(SessionRegistry.Session session,long revision){
        if(revision!=0&&metadata.capture(session).revision()!=revision)throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.STALE);
    }
    /** No catalog reference crosses the native retained-witness check. */
    private VerifiedSource ownedSource(SessionRegistry.Session session,RelatedRowsRequest request)throws Exception {
        var result=results.get(request.getResultId());
        if(!result.sourceSessionId.equals(session.id)||!result.fetchFinished||result.columns.isEmpty())throw new IllegalArgumentException("Related rows require a finished result from this physical session");
        var retained=result.metadataProof();
        if(!retained.available())return new VerifiedSource(result,retained,retained.state()==MetadataState.STALE?"stale":retained.state()==MetadataState.DENIED?"denied":"incomplete-metadata");
        return new VerifiedSource(result,retained,"");
    }
    private VerifiedSource verifyWitness(SessionRegistry.Session session,VerifiedSource source)throws Exception {
        if(!source.availability().isEmpty())return source;var result=source.result();var retained=source.proof();
        try{result.verifyMetadataWitness(session,null);}catch(io.busystack.busydata.rpc.WorkbenchFailure unavailable){
            return new VerifiedSource(result,retained,unavailable.reason()==io.busystack.busydata.rpc.WorkbenchFailure.Reason.STALE?"stale":"incomplete-metadata");
        }
        return new VerifiedSource(result,retained,"");
    }
    private RelatedRowsReply listOwned(SessionRegistry.Session session,RelatedRowsRequest request,MetadataSnapshot snapshot,VerifiedSource source)throws Exception {
        var result=source.result();
        if(request.getSnapshotRevision()!=0&&request.getSnapshotRevision()!=snapshot.revision())throw new IllegalStateException("Relationship metadata snapshot changed");
        var first=result.columns.getFirst();
        var out=RelatedRowsReply.newBuilder().setResultId(result.id).setSourceRow(request.getSourceRow()).setSnapshotRevision(snapshot.revision())
            .setBackendInstance(request.getContext().getInstanceId()).setProfileId(session.profile.getId()).setMetadataSourceIdentity(snapshot.source())
            .setSessionId(session.id).setSessionRevision(session.revision).setContextRevision(session.contextRevision).setMetadataConfigurationRevision(snapshot.configurationRevision());
        var retained=source.proof();
        if(!source.availability().isEmpty())return out.setAvailability(source.availability()).build();
        var current=RetainedMetadataProof.capture(snapshot,result.columns,session.targetProfile(),session.id,session.context);
        if(!current.available())return out.setAvailability(current.state()==MetadataState.STALE?"stale":"incomplete-metadata").build();
        if(!retained.samePhysicalStructure(current))return out.setAvailability("stale").build();
        if(!first.getProvenanceKnown()||first.getTable().isEmpty())return out.setAvailability("unknown-provenance").build();
        String catalog=first.getCatalog().isEmpty()?session.context.catalog():first.getCatalog();
        String schema=session.profile.getEngine()==Engine.POSTGRESQL?first.getSchema():catalog;
        var columns=new HashMap<String,Integer>();
        for(int i=0;i<result.columns.size();i++){
            var c=result.columns.get(i);String cCatalog=c.getCatalog().isEmpty()?session.context.catalog():c.getCatalog();
            if(!c.getProvenanceKnown()||!c.getTable().equals(first.getTable())||!cCatalog.equals(catalog)||!c.getSchema().equals(first.getSchema())||c.getBaseColumn().isEmpty()||columns.putIfAbsent(c.getBaseColumn(),i)!=null)
                return out.setAvailability("ambiguous-provenance").build();
        }
        var row=result.read(request.getSourceRow());
        out.setAvailability(snapshot.outgoingComplete(catalog,schema,first.getTable())&&snapshot.incomingComplete()?"available":"incomplete-metadata");
        try(var lease=result.lease()){
            return buildRelationships(out,snapshot,catalog,schema,first.getTable(),(relationship,incoming)->choice(session,request,snapshot,relationship,incoming,columns,row));
        }
    }
    /** Pure mapping under the caller's retained-result lease. The already
     * stamped header and every repeated-message tag/length count toward the cap. */
    static RelatedRowsReply buildRelationships(RelatedRowsReply.Builder out,MetadataSnapshot snapshot,String catalog,String schema,String table,java.util.function.BiFunction<MetadataObject,Boolean,RelatedRelationship> choice){
        checkCancelled();
        var limited=out.clone().clearRelationships().setAvailability("relationship-budget-exceeded").build();
        if(limited.getSerializedSize()>MAX_REPLY_BYTES)throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.MALFORMED_REQUEST);
        long bytes=out.build().getSerializedSize();int count=out.getRelationshipsCount();
        if(bytes>MAX_REPLY_BYTES||count>MAX_RELATIONSHIPS)return limited(out);
        for(boolean incoming:new boolean[]{false,true})for(var relationship:incoming?snapshot.incoming(catalog,schema,table):snapshot.outgoing(catalog,schema,table)){
            checkCancelled();if(count>=MAX_RELATIONSHIPS)return limited(out);
            var next=choice.apply(relationship,incoming);checkCancelled();
            long addition=com.google.protobuf.CodedOutputStream.computeMessageSize(RelatedRowsReply.RELATIONSHIPS_FIELD_NUMBER,next);
            if(bytes+addition>MAX_REPLY_BYTES)return limited(out);
            out.addRelationships(next);bytes+=addition;count++;
        }
        checkCancelled();return out.build();
    }
    private static RelatedRowsReply limited(RelatedRowsReply.Builder out){return out.clearRelationships().setAvailability("relationship-budget-exceeded").build();}
    private static void checkCancelled(){if(Thread.currentThread().isInterrupted()||io.grpc.Context.current().isCancelled())throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.CANCELLED);}
    private RelatedRelationship choice(SessionRegistry.Session session,RelatedRowsRequest request,MetadataSnapshot snapshot,MetadataObject relationship,boolean incoming,Map<String,Integer> columns,Row row){
        var out=RelatedRelationship.newBuilder().setIdentity(relationship.identity().key()).setName(relationship.displayName()).setIncoming(incoming);
        var p=relationship.properties();
        if(!snapshot.relationshipComplete(relationship))return out.setAvailability("incomplete-metadata").build();
        String catalog=incoming?relationship.identity().catalog():p.getOrDefault("referencedCatalog","");
        String schema=incoming?relationship.identity().schema():p.getOrDefault("referencedSchema","");
        String table=incoming?relationship.identity().parent():p.getOrDefault("referencedTable","");
        if(catalog.isEmpty()||schema.isEmpty()||table.isEmpty()||session.profile.getEngine()==Engine.POSTGRESQL&&!catalog.equals(session.context.catalog()))return out.setAvailability("unsupported-target").build();
        var targets=snapshot.namespace(catalog,schema,ObjectKind.TABLE,"").stream().filter(o->o.identity().name().equals(table)).toList();
        if(targets.size()!=1)return out.setAvailability("incomplete-metadata").build();
        var browse=BrowseRequest.newBuilder().setSessionId(session.id).setDocumentId(request.getDocumentId()).setCatalog(catalog).setSchema(schema).setTable(table).setRowLimit(10000)
            .setMetadataSnapshotRevision(snapshot.revision()).setMetadataObjectIdentity(targets.getFirst().identity().key())
            .setOriginRelationshipIdentity(relationship.identity().key()).setOriginResultId(request.getResultId()).setOriginSourceRow(request.getSourceRow());
        int count;try{count=Integer.parseInt(p.getOrDefault("columnCount","0"));}catch(NumberFormatException invalid){return out.setAvailability("incomplete-metadata").build();}
        if(count<1||count>32)return out.setAvailability("relationship-budget-exceeded").build();
        for(int i=0;i<count;i++){
            String source=p.get((incoming?"referencedColumn.":"column.")+i),target=p.get((incoming?"column.":"referencedColumn.")+i);
            Integer position=columns.get(source);if(position==null||target==null||target.isEmpty())return out.setAvailability("key-not-projected").build();
            var value=row.getValues(position);
            if(value.hasNullValue())return out.setAvailability("null-key-component").build();
            if(value.getTruncated()||!value.getValueId().isEmpty()||value.getSerializedSize()>8192)return out.setAvailability("value-truncated-or-limited").build();
            browse.addConditions(RowCondition.newBuilder().setColumn(target).setPredicate(ValuePredicate.EQUAL).setValue(value));
        }
        return out.setBrowse(browse).setAvailability("available").build();
    }
}
