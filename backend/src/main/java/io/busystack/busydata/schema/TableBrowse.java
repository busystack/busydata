package io.busystack.busydata.schema;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.sessions.SessionRegistry;
import io.busystack.busydata.results.Values;
import io.busystack.busydata.jobs.Jobs;
import io.busystack.busydata.safety.Safety;
import io.busystack.busydata.adapters.JdbcAdapter;
import io.busystack.busydata.metadata.MetadataPlatform;
import io.busystack.busydata.metadata.MetadataSnapshot;
import io.busystack.busydata.metadata.PgTemporaryBrowseProof;
import io.busystack.busydata.rpc.WorkbenchFailure;
import java.util.*;
import java.security.MessageDigest;
import java.nio.charset.StandardCharsets;

/** Generated browsing is an explicit reviewed job, never an Explorer side effect. */
public final class TableBrowse {
    /** Operation-local scalars; a queued browse never retains a whole catalog. */
    public record Binding(SessionRegistry.Session owner,Profile profile,JdbcAdapter.LiveContext context,long sessionRevision,long contextRevision,String source,long generation,long metadataRevision,long configurationRevision) {
        private static Binding capture(SessionRegistry.Session session,MetadataSnapshot snapshot,long generation){return new Binding(session,session.targetProfile(),session.context,session.revision,session.contextRevision,snapshot.source(),generation,snapshot.revision(),snapshot.configurationRevision());}
        private void verifySession(SessionRegistry.Session session,MetadataPlatform metadata){
            metadata.requirePersistentMetadata(session);
            if(owner!=session||session.physicalEnded()||session.state==TransactionState.DISCONNECTED||session.state==TransactionState.UNKNOWN_TRANSACTION||!profile.equals(session.targetProfile()))throw new WorkbenchFailure(WorkbenchFailure.Reason.INVALID_OWNER);
            if(session.revision!=sessionRevision||session.contextRevision!=contextRevision||!context.equals(session.context))throw new WorkbenchFailure(WorkbenchFailure.Reason.INVALID_REVISION);
            if(metadata.configuration(session).revision()!=configurationRevision)throw new WorkbenchFailure(WorkbenchFailure.Reason.STALE);
            if(metadata.publicationRevision(session).owner()!=generation)throw new WorkbenchFailure(WorkbenchFailure.Reason.STALE);
        }
        private void verify(SessionRegistry.Session session,MetadataPlatform metadata){
            verifySession(session,metadata);var current=metadata.capture(session);
            verifySession(session,metadata);
            if(!source.equals(current.source())||metadataRevision!=current.revision()||configurationRevision!=current.configurationRevision())throw new WorkbenchFailure(WorkbenchFailure.Reason.STALE);
        }
        private Binding accepted(MetadataSnapshot snapshot){return new Binding(owner,profile,context,sessionRevision,contextRevision,snapshot.source(),generation,snapshot.revision(),configurationRevision);}
    }
    public record Prepared(String sql,List<RowCondition> conditions,Map<String,Integer> jdbcTypes,Map<String,SchemaObject> nativeColumns,Binding binding,PgTemporaryBrowseProof pgTemporaryProof) {}
    /** Entry points require an unlocked caller. Metadata acquisition occurs
     * outside this operation's physical-session generation/approval lease. */
    private record AcquiredColumns(Binding binding,Map<String,Integer> columns,Map<String,SchemaObject> nativeColumns){}
    private record Selection(Binding binding,boolean ownedTemporary,ObjectKind kind){}
    public static Prepared prepare(SessionRegistry.Session session,BrowseRequest request,Explorer explorer)throws Exception {
        var acquired=acquireColumns(session,request,explorer);
        if(!session.lock.tryLock())throw new IllegalStateException("Physical session is busy; review browsing when it is available");
        try{return prepareOwned(session,request,explorer,acquired);}finally{session.lock.unlock();}
    }
    private static AcquiredColumns acquireColumns(SessionRegistry.Session session,BrowseRequest request,Explorer explorer)throws Exception {
        requireSelectionFields(request);
        if(!request.getSessionId().equals(session.id)||session.lock.isHeldByCurrentThread())throw new WorkbenchFailure(WorkbenchFailure.Reason.INVALID_OWNER);
        Binding initial;
        if(!session.lock.tryLock())throw new IllegalStateException("Physical session is busy; review browsing when it is available");
        try{
            explorer.metadata().requirePersistentMetadata(session);
            if(request.getDocumentId().isBlank() || request.getDocumentId().length()>128 || request.getRowLimit()<1 || request.getRowLimit()>1_000_000 || request.getConditionsCount()>32 || request.getOrderCount()>32)
                throw new IllegalArgumentException("Browse owner, row limit or condition budget invalid");
            if(session.profile.getEngine()==Engine.POSTGRESQL && !request.getCatalog().isEmpty() && !request.getCatalog().equals(session.context.catalog()))
                throw new IllegalArgumentException("PostgreSQL browsing is limited to the connected catalog");
            var selected=captureSelection(session,request,explorer);
            initial=selected.binding();verifyConfiguredSelection(session,request,explorer,selected.kind());
            verifyPhysicalTarget(session,request,explorer,selected.ownedTemporary(),selected.kind(),null);
        }finally{session.lock.unlock();}
        var scope=ExploreRequest.newBuilder().setCatalog(request.getCatalog()).setSchema(request.getSchema()).setTable(request.getTable());
        var columns=new LinkedHashMap<String,Integer>();var nativeColumns=new LinkedHashMap<String,SchemaObject>();
        String continuation="";long pageRevision=-1;
        do {
            var page=scope.setKind(ObjectKind.COLUMN).setIntrospectionLevel(2).setLimit(500).setContinuation(continuation).build();
            initial.verifySession(session,explorer.metadata());
            SchemaObjects metadata;
            try{metadata=explorer.explore(session,page);}
            catch(Explorer.ContinuationFailure stale){initial.verifySession(session,explorer.metadata());throw new WorkbenchFailure(WorkbenchFailure.Reason.STALE);}
            initial.verifySession(session,explorer.metadata());
            if(metadata.getSessionRevision()!=initial.sessionRevision()||metadata.getContextRevision()!=initial.contextRevision())throw new WorkbenchFailure(WorkbenchFailure.Reason.INVALID_REVISION);
            if(metadata.getMetadataConfigurationRevision()!=initial.configurationRevision()||pageRevision!=-1&&pageRevision!=metadata.getMetadataSnapshotRevision())throw new WorkbenchFailure(WorkbenchFailure.Reason.STALE);
            pageRevision=metadata.getMetadataSnapshotRevision();
            if(metadata.getAvailability().startsWith("limited") || metadata.getObjectsCount()==0)throw new IllegalStateException("Complete column metadata required for browsing");
            for(var column:metadata.getObjectsList()) {
                if(columns.size()>=2048||columns.putIfAbsent(column.getName(),Integer.parseInt(column.getPropertiesOrThrow("jdbcType")))!=null)throw new IllegalStateException("Column metadata exceeds the exact identity budget");
                nativeColumns.put(column.getName(),column);
            }
            continuation=metadata.getContinuation();
            if(!metadata.getComplete()&&continuation.isEmpty())throw new IllegalStateException("Column metadata is incomplete");
        }while(!continuation.isEmpty());
        var binding=acceptColumns(session,request,explorer,initial,pageRevision);
        return new AcquiredColumns(binding,Map.copyOf(columns),Map.copyOf(nativeColumns));
    }
    /** The full central view stays local to pure checks; no native read retains it. */
    private static Selection captureSelection(SessionRegistry.Session session,BrowseRequest request,Explorer explorer){
        long generation=explorer.metadata().publicationRevision(session).owner();var captured=explorer.metadata().capture(session);
        var binding=Binding.capture(session,captured,generation);binding.verifySession(session,explorer.metadata());verifyRequestedSnapshot(request,captured);
        return new Selection(binding,selectedTemporary(session,request,captured),captured.identity(request.getMetadataObjectIdentity()).orElseThrow(()->new WorkbenchFailure(WorkbenchFailure.Reason.STALE)).identity().kind());
    }
    private static Binding acceptColumns(SessionRegistry.Session session,BrowseRequest request,Explorer explorer,Binding initial,long pageRevision){
        initial.verifySession(session,explorer.metadata());var captured=explorer.metadata().capture(session);
        if(captured.revision()!=pageRevision||captured.configurationRevision()!=initial.configurationRevision())throw new WorkbenchFailure(WorkbenchFailure.Reason.STALE);
        verifyRequestedSnapshot(request,captured);var binding=initial.accepted(captured);binding.verify(session,explorer.metadata());return binding;
    }
    private static boolean selectedTemporary(SessionRegistry.Session session,BrowseRequest request,MetadataSnapshot captured){
        var selected=request.getMetadataObjectIdentity().isEmpty()?null:captured.identity(request.getMetadataObjectIdentity()).orElse(null);
        return selected!=null&&selected.identity().sessionOwner().equals(session.id)&&"true".equals(selected.properties().get("temporary"));
    }
    private static Selection currentSelection(SessionRegistry.Session session,BrowseRequest request,Explorer explorer,Binding binding){
        binding.verify(session,explorer.metadata());var current=explorer.metadata().capture(session);verifyRequestedSnapshot(request,current);
        var selected=current.identity(request.getMetadataObjectIdentity()).orElseThrow(()->new WorkbenchFailure(WorkbenchFailure.Reason.STALE));
        var result=new Selection(binding,selectedTemporary(session,request,current),selected.identity().kind());binding.verify(session,explorer.metadata());return result;
    }
    private static SchemaObject typeEvidence(SessionRegistry.Session session,Explorer explorer,Binding binding,SchemaObject column){
        binding.verify(session,explorer.metadata());var current=explorer.metadata().capture(session);
        var evidence=io.busystack.busydata.metadata.EditTypeEvidence.forColumn(current,column);binding.verify(session,explorer.metadata());return evidence;
    }
    private static Prepared prepareOwned(SessionRegistry.Session session,BrowseRequest request,Explorer explorer,AcquiredColumns acquired)throws Exception {
        if(!session.lock.isHeldByCurrentThread())throw new IllegalStateException("Physical session ownership is required for generated browse preparation");
        var binding=acquired.binding();binding.verify(session,explorer.metadata());
        var selection=currentSelection(session,request,explorer,binding);boolean temporary=selection.ownedTemporary();
        verifyConfiguredSelection(session,request,explorer,selection.kind());
        // No full central snapshot is retained across this native observation.
        verifyPhysicalTarget(session,request,explorer,temporary,selection.kind(),null);binding.verify(session,explorer.metadata());
        var columns=acquired.columns();var nativeColumns=acquired.nativeColumns();
        PgTemporaryBrowseProof pgTemporaryProof=null;
        if(session.profile.getEngine()==Engine.POSTGRESQL&&!session.context.temporarySchema().isEmpty()) {
            var selected=nativeColumns.values().iterator().next();
            // Exact selected identities still require a fresh native owned
            // proof; matching cached revisions cannot detect raw TEMP DDL.
            if(selected.getCatalog().equals(session.context.catalog())&&selected.getSchema().equals(session.context.temporarySchema()))
                pgTemporaryProof=PgTemporaryBrowseProof.acquire(explorer,session,selected.getCatalog(),selected.getSchema(),selected.getTable(),request.getMetadataObjectIdentity(),null,System.nanoTime()+java.util.concurrent.TimeUnit.SECONDS.toNanos(10));
            else if(temporary)throw new WorkbenchFailure(WorkbenchFailure.Reason.STALE);
            binding.verify(session,explorer.metadata());
        }
        String sql="SELECT * FROM "+session.adapter.table(request.getCatalog(),request.getSchema(),request.getTable());
        var predicates=new ArrayList<String>();var conditions=new ArrayList<RowCondition>();
        for(var condition:request.getConditionsList()) {
            if(!columns.containsKey(condition.getColumn())) throw new IllegalArgumentException("Filter column does not belong to the selected object");
            String operator=switch(condition.getPredicate()) {
                case EQUAL -> " = ?"; case NOT_EQUAL -> " <> ?"; case LESS -> " < ?"; case GREATER -> " > ?";
                case IS_NULL -> " IS NULL"; case IS_NOT_NULL -> " IS NOT NULL";
                default -> throw new IllegalArgumentException("Unsupported predicate");
            };
            if(condition.getValue().getSerializedSize()>8192 || condition.getValue().getTruncated() || !condition.getValue().getValueId().isEmpty()) throw new IllegalArgumentException("Filter value exceeds bounded exact-value policy");
            var normalized=condition;
            if(condition.getPredicate()!=ValuePredicate.IS_NULL&&condition.getPredicate()!=ValuePredicate.IS_NOT_NULL&&!condition.getValue().hasNullValue()){
                var evidence=typeEvidence(session,explorer,binding,nativeColumns.get(condition.getColumn()));
                var value=EditValues.convert(condition.getValue(),evidence,session.profile.getEngine(),request.getOriginRelationshipIdentity().isEmpty()?null:condition.getValue());
                if(value.hasArray()){io.busystack.busydata.results.ArrayParameters.validate(value);try{io.busystack.busydata.results.ArrayParameters.requireContext(value,binding.context(),evidence.getPropertiesOrDefault("arrayElementBaseName","").isEmpty()?evidence.getPropertiesOrDefault("arrayElementType",""):evidence.getPropertiesOrDefault("arrayElementBaseName",""));}catch(java.sql.SQLFeatureNotSupportedException unsupported){throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.UNSUPPORTED);}}
                normalized=condition.toBuilder().setValue(value).build();
            }
            conditions.add(normalized);predicates.add(session.adapter.quote(condition.getColumn())+operator);
        }
        if(!predicates.isEmpty()) sql+=" WHERE "+String.join(" AND ",predicates);
        var order=new ArrayList<String>();var seen=new HashSet<String>();
        for(var item:request.getOrderList()) {
            if(!columns.containsKey(item.getColumn()) || !seen.add(item.getColumn())) throw new IllegalArgumentException("Sort requires distinct verified column identities");
            order.add(session.adapter.quote(item.getColumn())+(item.getDescending()?" DESC":" ASC"));
        }
        if(!order.isEmpty()) sql+=" ORDER BY "+String.join(", ",order);
        binding.verify(session,explorer.metadata());
        return new Prepared(sql,List.copyOf(conditions),Map.copyOf(columns),Map.copyOf(nativeColumns),binding,pgTemporaryProof);
    }
    private static void verifyPhysicalTarget(SessionRegistry.Session session,BrowseRequest request,Explorer explorer,boolean ownedTemporary,ObjectKind selectedKind,Jobs.Job job)throws Exception {
        if(session.profile.getEngine()!=Engine.POSTGRESQL){
            String catalog=request.getCatalog().isEmpty()?session.context.catalog():request.getCatalog();
            String schema=request.getSchema().isEmpty()?catalog:request.getSchema();
            var physical=OwnedTemporarySource.verify(explorer.metadata(),session,catalog,schema,request.getTable(),System.nanoTime()+java.util.concurrent.TimeUnit.SECONDS.toNanos(10),job);
            if(!physical.available())physical.requirePersistent();
            if(physical.available()&&physical.kind()==io.busystack.busydata.metadata.MetadataSnapshot.PhysicalRelationKind.PERSISTENT&&physical.nativeObjectKind()!=selectedKind){
                explorer.metadata().markStaleEffects(session,List.of(DdlEffect.newBuilder().setOperation("ALTER").setCatalog(catalog).setSchema(schema).setName(request.getTable()).setKind(selectedKind).build()),"Native relation kind changed; explicitly refresh the selected metadata");
                throw new WorkbenchFailure(WorkbenchFailure.Reason.STALE);
            }
            // Kind equality cannot preserve a selected TEMP structure after
            // the native observation retired its definition or exact owner.
            // Fail before any column acquisition can replace that selection.
            if(physical.kind()==io.busystack.busydata.metadata.MetadataSnapshot.PhysicalRelationKind.TEMPORARY
                    &&(!ownedTemporary||!physical.reusesOwnedShape(explorer.metadata(),session)))
                throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.STALE);
            if(physical.kind()!=io.busystack.busydata.metadata.MetadataSnapshot.PhysicalRelationKind.TEMPORARY){physical.requirePersistent();if(ownedTemporary)throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.STALE);}
        }
    }
    private static void requireSelectionFields(BrowseRequest request){
        if(request.getMetadataSnapshotRevision()<=0||!request.getMetadataObjectIdentity().matches("[0-9a-f]{64}"))throw new WorkbenchFailure(WorkbenchFailure.Reason.MALFORMED_REQUEST);
        for(String identifier:List.of(request.getCatalog(),request.getSchema(),request.getTable()))if(identifier.isEmpty()||identifier.length()>256||identifier.indexOf('\0')>=0)throw new WorkbenchFailure(WorkbenchFailure.Reason.MALFORMED_REQUEST);
    }
    private static void verifyConfiguredSelection(SessionRegistry.Session session,BrowseRequest request,Explorer explorer,ObjectKind kind){
        var policy=explorer.metadata().configuration(session);
        if(!MetadataPlatform.permitsInspection(policy,session.profile.getEngine(),session.context,request.getCatalog(),request.getSchema(),request.getTable(),kind)
                ||!MetadataPlatform.permitsInspection(policy,session.profile.getEngine(),session.context,request.getCatalog(),request.getSchema(),request.getTable(),ObjectKind.COLUMN))throw new WorkbenchFailure(WorkbenchFailure.Reason.DENIED);
    }
    private static void verifyRequestedSnapshot(BrowseRequest request,MetadataSnapshot captured){
        requireSelectionFields(request);
        if(captured.revision()!=request.getMetadataSnapshotRevision())throw new WorkbenchFailure(WorkbenchFailure.Reason.STALE);
        var selected=captured.identity(request.getMetadataObjectIdentity()).orElseThrow(()->new WorkbenchFailure(WorkbenchFailure.Reason.STALE));var identity=selected.identity();
        if(!Set.of(ObjectKind.TABLE,ObjectKind.VIEW).contains(identity.kind())||!identity.catalog().equals(request.getCatalog())||!identity.schema().equals(request.getSchema())||!identity.name().equals(request.getTable()))throw new WorkbenchFailure(WorkbenchFailure.Reason.INVALID_OWNER);
        if(selected.state()!=io.busystack.busydata.metadata.MetadataState.AVAILABLE)throw new WorkbenchFailure(selected.state()==io.busystack.busydata.metadata.MetadataState.STALE?WorkbenchFailure.Reason.STALE:WorkbenchFailure.Reason.INCOMPLETE_METADATA);
        if(!selected.level().includes(io.busystack.busydata.metadata.IntrospectionLevel.STRUCTURE)
                ||!captured.complete(new io.busystack.busydata.metadata.MetadataScope(identity.catalog(),identity.schema(),identity.name(),ObjectKind.COLUMN),io.busystack.busydata.metadata.IntrospectionLevel.STRUCTURE))throw new WorkbenchFailure(WorkbenchFailure.Reason.INCOMPLETE_METADATA);
        if(!request.getOriginRelationshipIdentity().isEmpty()) {
            var relationship=captured.identity(request.getOriginRelationshipIdentity()).orElseThrow(()->new WorkbenchFailure(WorkbenchFailure.Reason.STALE));
            if(relationship.identity().kind()!=ObjectKind.FOREIGN_KEY||request.getOriginResultId().isEmpty())throw new IllegalArgumentException("Related browse requires its retained relationship owner");
            if(!captured.relationshipComplete(relationship))throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.INCOMPLETE_METADATA);
        }
    }
    static String fingerprint(BrowseRequest request,Binding binding,String nativeProof) throws Exception {
        var digest=MessageDigest.getInstance("SHA-256");
        digest.update(request.toBuilder().clearContext().clearApprovalToken().clearExecutionId().build().toByteArray());
        digest.update(binding.profile().toByteArray());
        digest.update((binding.sessionRevision()+":"+binding.contextRevision()+":"+binding.source()+":"+binding.generation()+":"+binding.metadataRevision()+":"+binding.configurationRevision()).getBytes(StandardCharsets.UTF_8));
        digest.update(nativeProof.getBytes(StandardCharsets.UTF_8));
        return HexFormat.of().formatHex(digest.digest());
    }
    private static String fingerprint(BrowseRequest request,Prepared prepared)throws Exception {
        return fingerprint(request,prepared.binding(),prepared.pgTemporaryProof()==null?"":prepared.pgTemporaryProof().fingerprint());
    }
    public static Approval review(SessionRegistry.Session session,BrowseRequest request,Explorer explorer,Safety safety) throws Exception {
        return review(session,request,explorer,safety,null);
    }
    public static Approval review(SessionRegistry.Session session,BrowseRequest request,Explorer explorer,Safety safety,RelatedRows related) throws Exception {
        var acquired=acquireColumns(session,request,explorer);
        if(!session.lock.tryLock())throw new IllegalStateException("Physical session is busy; review browsing when it is available");
        try{
            var prepared=prepareVerified(session,request,explorer,related,acquired);
            String token=safety.issue(fingerprint(request,prepared));
            try{prepared.binding().verify(session,explorer.metadata());}catch(Exception stale){safety.discard(token);throw stale;}
            var approval=Approval.newBuilder().addStatements(prepared.sql()).setToken(token).setExpiresUnixMs(System.currentTimeMillis()+120_000);
            if(prepared.binding().profile().getEnvironment()==Environment.PRODUCTION)approval.addRisks("PRODUCTION: "+prepared.binding().profile().getHost()+"/"+prepared.binding().context().catalog());
            return approval.build();
        }finally{session.lock.unlock();}
    }
    public static Jobs.Job submit(SessionRegistry.Session session,BrowseRequest request,Explorer explorer,Safety safety,Jobs jobs) throws Exception {
        return submit(session,request,explorer,safety,jobs,null);
    }
    public static Jobs.Job submit(SessionRegistry.Session session,BrowseRequest request,Explorer explorer,Safety safety,Jobs jobs,RelatedRows related) throws Exception {
        var acquired=acquireColumns(session,request,explorer);
        if(!session.lock.tryLock())throw new IllegalStateException("Physical session is busy; review browsing when it is available");
        try{
        var prepared=prepareVerified(session,request,explorer,related,acquired);
        safety.consume(request.getApprovalToken(),fingerprint(request,prepared));
        prepared.binding().verify(session,explorer.metadata());
        return jobs.submitSql(session,request.getExecutionId(),prepared.sql(),job->{
            verifyPrepared(session,request,explorer,related,prepared,job);
            job.documentId=request.getDocumentId();job.sourceSql=prepared.sql();
            try(var statement=session.adapter.catalogStatement(session.connection,prepared.sql())) {
                statement.setQueryTimeout(session.profile.getQueryTimeoutSeconds()==0?60:session.profile.getQueryTimeoutSeconds());
                statement.setMaxRows((int)request.getRowLimit());statement.setFetchSize(16);
                int index=1;var arrays=new ArrayList<java.sql.Array>();
                try{
                    for(var condition:prepared.conditions())if(condition.getPredicate()!=ValuePredicate.IS_NULL&&condition.getPredicate()!=ValuePredicate.IS_NOT_NULL){
                        var value=condition.getValue();var column=prepared.nativeColumns().get(condition.getColumn());int type=prepared.jdbcTypes().get(condition.getColumn());
                        if(value.hasArray()){
                            int oid;try{oid=Integer.parseUnsignedInt(column.getPropertiesOrDefault("nativeTypeId",""));}catch(NumberFormatException unavailable){throw new IllegalArgumentException("Verified array type identity is unavailable");}
                            arrays.add(io.busystack.busydata.results.ArrayParameters.bind(statement,index++,value,oid,session.context));
                        }else{
                            if(type==java.sql.Types.DISTINCT||Set.of("e","d").contains(column.getPropertiesOrDefault("nativeTypeKind",""))||value.hasEngineValue()&&!column.getPropertiesOrDefault("nativeTypeId","").isEmpty())type=java.sql.Types.OTHER;
                            Values.bind(statement,index++,value,type);
                        }
                    }
                    job.statement=statement;job.checkCancel();
                    try(var rows=statement.executeQuery()){jobs.fetch(job,rows,0,request.getRowLimit());}
                }finally{for(var array:arrays)array.free();}
            } finally { job.statement=null; }
        });
        }finally{session.lock.unlock();}
    }
    private static Prepared prepareVerified(SessionRegistry.Session session,BrowseRequest request,Explorer explorer,RelatedRows related,AcquiredColumns acquired)throws Exception {
        var prepared=prepareOwned(session,request,explorer,acquired);
        verifyPreparedOwners(session,request,explorer,related,prepared);
        return prepared;
    }
    private static void verifyPrepared(SessionRegistry.Session session,BrowseRequest request,Explorer explorer,RelatedRows related,Prepared prepared,Jobs.Job job)throws Exception {
        verifyPreparedOwners(session,request,explorer,related,prepared);
        if(prepared.pgTemporaryProof()!=null)prepared.pgTemporaryProof().verify(explorer,session,job,System.nanoTime()+java.util.concurrent.TimeUnit.SECONDS.toNanos(10));
        if(session.profile.getEngine()!=Engine.POSTGRESQL){
            var selected=currentSelection(session,request,explorer,prepared.binding());
            verifyPhysicalTarget(session,request,explorer,selected.ownedTemporary(),selected.kind(),job);
        }
        prepared.binding().verify(session,explorer.metadata());
    }
    private static void verifyPreparedOwners(SessionRegistry.Session session,BrowseRequest request,Explorer explorer,RelatedRows related,Prepared prepared)throws Exception {
        prepared.binding().verify(session,explorer.metadata());
        if(!request.getOriginRelationshipIdentity().isEmpty()){
            if(related==null)throw new IllegalArgumentException("Related browsing requires its retained source owner");
            related.verifyBrowse(session,request,prepared.binding().metadataRevision());
        }
        prepared.binding().verify(session,explorer.metadata());
    }
}
