package io.busystack.busydata.metadata;

import io.busystack.busydata.jobs.Jobs;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.rpc.WorkbenchFailure;
import io.busystack.busydata.schema.Explorer;
import io.busystack.busydata.sessions.SessionRegistry;
import java.util.*;
import java.util.concurrent.CancellationException;
import java.util.concurrent.TimeUnit;

/**
 * Compact evidence from the central, published owning-PG-TEMP model. A live
 * check uses the same native adapters and normalization, but neither publishes
 * facts nor changes a metadata revision. Central scalar ownership fences,
 * collection admission and physical read cancellation bound each operation.
 */
public record PgTemporaryBrowseProof(MetadataPlatform.OwnedReadFence owner,String sessionId,String catalog,String schema,
        String table,String objectIdentity,ObjectKind kind,ObjectSubtype subtype,String nativeId,String nativeGeneration,
        String nativeGenerationAvailability,
        String columnFingerprint,String typeDependenciesFingerprint,String catalogFingerprint) {
    private static final int MAX_COLUMNS=2048;
    private static final long MAX_COLUMN_BYTES=8_388_608;

    /** One admitted operation; fresh evidence is not a metadata publication. */
    public static PgTemporaryBrowseProof acquire(Explorer explorer,SessionRegistry.Session session,
            String catalog,String schema,String table,String objectIdentity,Jobs.Job job,long deadline)throws Exception {
        requireOwner(session);if(!objectIdentity.matches("[0-9a-f]{64}"))throw new WorkbenchFailure(WorkbenchFailure.Reason.MALFORMED_REQUEST);
        var owner=explorer.metadata().ownedReadFence(session);
        try(var admission=explorer.metadata().admitAcquisition()) {
            owner.check(session);
            var proof=capture(explorer.metadata().capture(session),session,catalog,schema,table,objectIdentity,owner,admission);
            owner.check(session);proof.verifyNative(explorer,session,job,deadline,admission);owner.check(session);return proof;
        }
    }
    /** Pure extraction. No snapshot, rule map, source owner or column survives. */
    private static PgTemporaryBrowseProof capture(MetadataSnapshot snapshot,
            SessionRegistry.Session session,String catalog,String schema,
            String table,String objectIdentity,MetadataPlatform.OwnedReadFence owner,
            MetadataPlatform.AcquisitionAdmission admission) {
        requireOwner(session);
        if(!catalog.equals(session.context.catalog())||session.context.temporarySchema().isEmpty()
                ||!schema.equals(session.context.temporarySchema()))throw invalidOwner();
        if(!snapshot.identifierRulesAvailable())throw unavailable();
        var relation=snapshot.identity(objectIdentity).orElseThrow(PgTemporaryBrowseProof::stale);
        var identity=relation.identity();
        if(!Set.of(ObjectKind.TABLE,ObjectKind.VIEW).contains(identity.kind())||!identity.catalog().equals(catalog)
                ||!identity.schema().equals(schema)||!identity.name().equals(table)
                ||!identity.sessionOwner().equals(session.id)
                ||!"true".equals(relation.properties().get("temporary")))throw invalidOwner();
        if(relation.state()!=MetadataState.AVAILABLE||!relation.level().includes(IntrospectionLevel.STRUCTURE))throw unavailable();
        String nativeId=required(relation.properties(),"nativeId");
        String generation=relation.properties().getOrDefault("nativeGeneration","");
        String generationAvailability=required(relation.properties(),"nativeGenerationAvailability");
        boolean storageGeneration=generationAvailability.equals("AVAILABLE")&&!generation.isEmpty();
        boolean partitionWithoutFile=(identity.kind()==ObjectKind.TABLE&&identity.subtype()==ObjectSubtype.PARTITIONED_TABLE
                ||identity.kind()==ObjectKind.VIEW&&identity.subtype()==ObjectSubtype.REGULAR_VIEW)
                &&generationAvailability.equals("UNAVAILABLE")&&generation.isEmpty();
        if(!nativeId.equals(identity.nativeKey())||!storageGeneration&&!partitionWithoutFile)throw unavailable();
        String typeFingerprint=required(relation.properties(),"typeDependenciesFingerprint");
        String catalogFingerprint=required(relation.properties(),"catalogFingerprint");
        var scope=new MetadataScope(catalog,schema,table,ObjectKind.COLUMN);
        var coverage=snapshot.coverage(scope).orElseThrow(PgTemporaryBrowseProof::unavailable);
        if(!coverage.complete()||coverage.state()!=MetadataState.AVAILABLE
                ||!coverage.level().includes(IntrospectionLevel.STRUCTURE)
                ||!snapshot.scopeResolutionAvailable(scope))throw unavailable();
        var columns=new ArrayList<SchemaObject>();long bytes=0;
        for(var column:snapshot.select(scope)) {
            var id=column.identity();
            if(!id.sessionOwner().equals(session.id)||!id.catalog().equals(catalog)
                    ||!id.schema().equals(schema)||!id.parent().equals(table)
                    ||column.state()!=MetadataState.AVAILABLE
                    ||!column.level().includes(IntrospectionLevel.STRUCTURE)
                    ||!nativeId.equals(column.properties().get("parentNativeId")))throw unavailable();
            // The fingerprint deliberately uses the exact central projection;
            // no hand-maintained list of JDBC/native column facts is added.
            admission.reserveAdditional(512L+3L*column.estimatedBytes());
            var projected=column.projection(0,0);
            if(columns.size()>=MAX_COLUMNS||(bytes+=projected.getSerializedSize()+16)>MAX_COLUMN_BYTES)throw unavailable();
            columns.add(projected);
        }
        if(columns.isEmpty())throw unavailable();
        return new PgTemporaryBrowseProof(owner,session.id,catalog,schema,table,identity.key(),
                identity.kind(),identity.subtype(),nativeId,generation,generationAvailability,MetadataFingerprint.objects(columns),typeFingerprint,catalogFingerprint);
    }

    /** Adds native structural evidence to the existing reviewed fingerprint. */
    public String fingerprint() {
        return MetadataIdentity.digest("owned-pg-browse-v1",owner.fingerprint(),sessionId,catalog,schema,table,
                objectIdentity,Integer.toString(kind.getNumber()),Integer.toString(subtype.getNumber()),nativeId,nativeGeneration,nativeGenerationAvailability,columnFingerprint,typeDependenciesFingerprint,catalogFingerprint);
    }

    /**
     * Invoke under physical ownership before issuing/consuming approval, and
     * again inside the queued task immediately before preparing generated SQL.
     * ownerCheck must check the captured scalar owner; it may not rebind it.
     * The caller owns one bounded acquisition admission throughout this method.
     */
    public void verify(Explorer explorer,SessionRegistry.Session session,Jobs.Job job,long deadline)throws Exception {
        try(var admission=explorer.metadata().admitAcquisition()){verifyNative(explorer,session,job,deadline,admission);}
    }
    private void verifyNative(Explorer explorer,SessionRegistry.Session session,Jobs.Job job,long requestedDeadline,
            MetadataPlatform.AcquisitionAdmission admission)throws Exception {
        requireOwner(session);Runnable ownerCheck=()->owner.check(session);
        if(!session.id.equals(sessionId)||!catalog.equals(session.context.catalog())
                ||!schema.equals(session.context.temporarySchema()))throw invalidOwner();
        long deadline=Math.min(requestedDeadline,System.nanoTime()+TimeUnit.SECONDS.toNanos(10));
        check(ownerCheck,job,deadline);
        io.busystack.busydata.schema.OwnedTemporarySource.operation(session,deadline,job,nativeCheck->{
            // No captured snapshot/rules survive this or any following native read.
            var initial=NativeRelationReader.inspect(session,catalog,schema,table);
            nativeCheck.run();check(ownerCheck,job,deadline);if(!sameGeneration(initial))throw nativeStale(explorer.metadata(),session);
            var identityRequest=ExploreRequest.newBuilder().setCatalog(catalog).setSchema(schema).setKind(kind)
                    .setSearch(table).setExactName(true).setIntrospectionLevel(1).setLimit(1).build();
            var identities=explorer.fetchBranch(session,identityRequest,deadline,new Explorer.CollectionBudget(1,65_536,admission::reserveAdditional));
            nativeCheck.run();check(ownerCheck,job,deadline);
            if(identities.size()!=1||!nativeId.equals(identities.getFirst().getPropertiesOrDefault("nativeId",""))
                    ||identities.getFirst().getKind()!=kind||identities.getFirst().getSubtype()!=subtype
                    ||!catalogFingerprint.equals(identities.getFirst().getPropertiesOrDefault("catalogFingerprint","")))throw nativeStale(explorer.metadata(),session);
            var request=ExploreRequest.newBuilder().setCatalog(catalog).setSchema(schema)
                    .setTable(table).setKind(ObjectKind.COLUMN).setIntrospectionLevel(2).setLimit(500).build();
            var nativeColumns=explorer.fetchBranch(session,request,deadline,new Explorer.CollectionBudget(MAX_COLUMNS,MAX_COLUMN_BYTES,admission::reserveAdditional));
            nativeCheck.run();check(ownerCheck,job,deadline);
            String freshColumns;
            try{freshColumns=normalizeColumns(explorer.metadata(),session,nativeColumns,ownerCheck,admission);}
            catch(NativeDifference changed){throw nativeStale(explorer.metadata(),session);}
            // Normalization ends before another native statement. Only the digest
            // and bounded native columns remain; the latter can now be reclaimed.
            nativeColumns=null;
            nativeCheck.run();check(ownerCheck,job,deadline);
            String freshTypes=NativeTypeReader.namespaceFingerprints(session,schema,table,deadline).get(table);
            nativeCheck.run();check(ownerCheck,job,deadline);
            var finalIdentity=NativeRelationReader.inspect(session,catalog,schema,table);
            nativeCheck.run();check(ownerCheck,job,deadline);if(!sameGeneration(finalIdentity))throw nativeStale(explorer.metadata(),session);
            if(!initial.equals(finalIdentity)||!columnFingerprint.equals(freshColumns)
                    ||!typeDependenciesFingerprint.equals(freshTypes))throw nativeStale(explorer.metadata(),session);
            // Deliberately no publish, request epoch, refresh ticket, reconciliation,
            // acceptance of the new shape, or SQL retry on a mismatch.
            return null;
        });
        check(ownerCheck,job,deadline);
    }

    private String normalizeColumns(MetadataPlatform platform,SessionRegistry.Session session,
            List<SchemaObject> nativeColumns,Runnable ownerCheck,MetadataPlatform.AcquisitionAdmission admission) {
        ownerCheck.run();var snapshot=platform.capture(session);
        if(!snapshot.identifierRulesAvailable())throw unavailable();
        var normalized=new ArrayList<SchemaObject>();long bytes=0;
        for(var column:nativeColumns) {
            if(column.getKind()!=ObjectKind.COLUMN||!column.getCatalog().equals(catalog)
                    ||!column.getSchema().equals(schema)||!column.getTable().equals(table)
                    ||!nativeId.equals(column.getPropertiesOrDefault("parentNativeId","")))throw new NativeDifference();
            admission.reserveAdditional(1024L+4L*column.getSerializedSize()+128L*column.getPropertiesCount());
            var value=MetadataObject.from(snapshot.source(),snapshot.profileId(),session.id,
                    snapshot.rules(),column,IntrospectionLevel.STRUCTURE,session.revision,session.contextRevision).projection(0,0);
            if(normalized.size()>=MAX_COLUMNS||(bytes+=value.getSerializedSize()+16)>MAX_COLUMN_BYTES)throw unavailable();
            normalized.add(value);
        }
        if(normalized.isEmpty())throw new NativeDifference();
        String result=MetadataFingerprint.objects(normalized);ownerCheck.run();return result;
    }
    private static final class NativeDifference extends RuntimeException {}
    private boolean sameGeneration(Map<String,String> current) {
        return nativeGenerationAvailability.equals(current.get("nativeGenerationAvailability"))
                &&nativeId.equals(current.get("nativeId"))
                &&nativeGeneration.equals(current.getOrDefault("nativeGeneration",""));
    }
    private WorkbenchFailure nativeStale(MetadataPlatform platform,SessionRegistry.Session session){
        String reason="The native temporary relation changed outside tracked execution; reconcile the owning session metadata";
        owner.retireUnknown(session,reason);var failure=stale();
        try{platform.markSessionStale(session,reason);}
        catch(RuntimeException retirement){failure.addSuppressed(retirement);}
        return failure;
    }
    private static void requireOwner(SessionRegistry.Session session) {
        if(!session.lock.isHeldByCurrentThread()||session.profile.getEngine()!=Engine.POSTGRESQL)throw invalidOwner();
        if(session.physicalEnded()||session.state==TransactionState.DISCONNECTED
                ||session.state==TransactionState.UNKNOWN_TRANSACTION)throw stale();
    }
    private static void check(Runnable ownerCheck,Jobs.Job job,long deadline)throws Exception {
        if(job!=null)job.checkCancel();
        if(io.grpc.Context.current().isCancelled()||Thread.currentThread().isInterrupted())throw new CancellationException("Owned metadata verification cancelled");
        if(System.nanoTime()>=deadline)throw new WorkbenchFailure(WorkbenchFailure.Reason.TIMED_OUT);
        ownerCheck.run();
    }
    private static String required(Map<String,String> properties,String key) {
        String value=properties.getOrDefault(key,"");if(value.isEmpty())throw unavailable();return value;
    }
    private static WorkbenchFailure stale(){return new WorkbenchFailure(WorkbenchFailure.Reason.STALE);}
    private static WorkbenchFailure unavailable(){return new WorkbenchFailure(WorkbenchFailure.Reason.INCOMPLETE_METADATA);}
    private static WorkbenchFailure invalidOwner(){return new WorkbenchFailure(WorkbenchFailure.Reason.INVALID_OWNER);}
}
