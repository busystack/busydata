package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.rpc.WorkbenchFailure;
import io.busystack.busydata.schema.Explorer;
import io.busystack.busydata.sessions.SessionRegistry;
import java.util.*;

/** Bounded protocol mapping and owner validation, independent of RPC orchestration. */
public final class MetadataRpc {
    private MetadataRpc(){}
    public static MetadataSettingsReply run(Explorer explorer,SessionRegistry.Session session,MetadataSettingsRequest request)throws Exception {
        if(!request.getSessionId().equals(session.id))throw new WorkbenchFailure(WorkbenchFailure.Reason.INVALID_OWNER);
        if(request.getSessionRevision()<0||request.getContextRevision()<0||request.getExpectedConfigurationRevision()<0||request.getExpectedSnapshotRevision()<0||request.getSerializedSize()>131072||request.getOffset()<0||request.getOffset()>100_000||request.getLimit()<0||request.getLimit()>128||request.getAction()==MetadataSettingsAction.UNRECOGNIZED)throw new WorkbenchFailure(WorkbenchFailure.Reason.MALFORMED_REQUEST);
        if(request.getSessionRevision()!=session.revision||request.getContextRevision()!=session.contextRevision)throw new WorkbenchFailure(WorkbenchFailure.Reason.INVALID_REVISION);
        long revision=session.revision,context=session.contextRevision;var platform=explorer.metadata();var current=platform.configuration(session);
        if(request.getAction()!=MetadataSettingsAction.READ_METADATA_SETTINGS&&request.getExpectedConfigurationRevision()!=current.revision())throw new WorkbenchFailure(WorkbenchFailure.Reason.INVALID_REVISION);
        switch(request.getAction()) {
            case SAVE_METADATA_SETTINGS->{
                MetadataConfiguration next;
                try{next=configuration(request.getConfiguration(),current.revision()+1);}
                catch(IllegalArgumentException malformed){throw new WorkbenchFailure(WorkbenchFailure.Reason.MALFORMED_REQUEST);}
                platform.configure(session,next);
            }
            case FULL_METADATA_REFRESH->explorer.refreshContext(session,MetadataPlatform.RefreshMode.FULL);
            case INCREMENTAL_METADATA_REFRESH->explorer.refreshContext(session,MetadataPlatform.RefreshMode.INCREMENTAL);
            case READ_METADATA_SETTINGS->{}
            default->throw new WorkbenchFailure(WorkbenchFailure.Reason.MALFORMED_REQUEST);
        }
        if(session.revision!=revision||session.contextRevision!=context)throw new WorkbenchFailure(WorkbenchFailure.Reason.INVALID_REVISION);
        current=platform.configuration(session);var snapshot=platform.capture(session);String cacheState=platform.cacheState(session);
        if(request.getOffset()>0&&request.getExpectedSnapshotRevision()!=snapshot.revision())throw new WorkbenchFailure(WorkbenchFailure.Reason.STALE);
        var out=settingsHeader(request,snapshot,current,cacheState);
        var scopes=snapshot.coverage().values().stream().sorted(Comparator.comparing((MetadataCoverage c)->c.scope().catalog()).thenComparing(c->c.scope().schema()).thenComparing(c->c.scope().kind().getNumber()).thenComparing(c->c.scope().parent()).thenComparing(c->c.scope().search())).toList();
        int limit=request.getLimit()==0?64:request.getLimit(),index=request.getOffset();
        if(index>scopes.size())throw new WorkbenchFailure(WorkbenchFailure.Reason.MALFORMED_REQUEST);
        while(index<scopes.size()&&out.getScopesCount()<limit) {
            var coverage=scopes.get(index++);var scope=coverage.scope();
            out.addScopes(MetadataScopeStatus.newBuilder().setCatalog(scope.catalog()).setSchema(scope.schema()).setParent(scope.parent()).setKind(scope.kind()).setLevel(coverage.level().number())
                .setState(coverage.state().name()).setComplete(coverage.complete()).setLastSuccessfulRefreshUnixMs(coverage.refreshedUnixMs()).setLimitation(coverage.limitation()).setObjectCount(snapshot.select(scope).size()));
        }
        out.setNextOffset(index).setComplete(index==scopes.size());
        platform.diagnostics(session).ifPresent(d->out.setRefreshStrategy(d.strategy()).setScannedScopes(d.scannedScopes()).setFetchedScopes(d.fetchedScopes()).setFetchedObjects(d.fetchedObjects()).setRefreshDurationMs(d.durationMs()));
        if(session.revision!=revision||session.contextRevision!=context)throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.INVALID_REVISION);
        var finalSnapshot=platform.capture(session);
        if(finalSnapshot.revision()!=snapshot.revision()||finalSnapshot.configurationRevision()!=current.revision()||!finalSnapshot.source().equals(snapshot.source())||platform.configuration(session).revision()!=current.revision())throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.INVALID_REVISION);
        return out.build();
    }
    /** One captured snapshot and its immutable matching policy form the wire
     * envelope. A later policy can never relabel earlier scope contents. */
    static MetadataSettingsReply.Builder settingsHeader(MetadataSettingsRequest request,MetadataSnapshot snapshot,MetadataConfiguration configuration,String cacheState){
        if(snapshot.configurationRevision()!=configuration.revision())throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.INVALID_REVISION);
        return MetadataSettingsReply.newBuilder().setBackendInstance(request.getContext().getInstanceId()).setProfileId(snapshot.profileId()).setSessionId(request.getSessionId())
            .setSessionRevision(request.getSessionRevision()).setContextRevision(request.getContextRevision()).setConfigurationRevision(configuration.revision()).setSnapshotRevision(snapshot.revision()).setMetadataSourceIdentity(snapshot.source()).setConfiguration(projection(configuration))
            .setCacheState(Set.of("REBUILT_CORRUPT","REBUILT_VERSION","WRITE_PENDING","WRITE_UNAVAILABLE").contains(cacheState)?cacheState:snapshot.coverage().isEmpty()?"UNAVAILABLE":snapshot.coverage().values().stream().allMatch(c->c.state()==MetadataState.AVAILABLE)?"AVAILABLE":"PARTIAL_OR_STALE");
    }
    public static MetadataConfiguration configuration(MetadataIntrospectionConfiguration source,long revision) {
        if(source.getIncludedCatalogsCount()+source.getExcludedCatalogsCount()+source.getIncludedSchemasCount()+source.getExcludedSchemasCount()+source.getScopeLevelsCount()>2048||source.getIncludePatternsCount()+source.getExcludePatternsCount()>64||source.getKindsCount()>ObjectKind.values().length)throw new IllegalArgumentException("Metadata configuration exceeds its scope budget");
        var levels=new LinkedHashMap<String,IntrospectionLevel>();
        for(var scope:source.getScopeLevelsList()) {
            for(String identifier:List.of(scope.getCatalog(),scope.getSchema()))if(identifier.length()>256||identifier.indexOf('\0')>=0)throw new IllegalArgumentException("Invalid introspection level scope");
            if(levels.put(MetadataConfiguration.scopeKey(scope.getCatalog(),scope.getSchema()),IntrospectionLevel.of(scope.getLevel()))!=null)throw new IllegalArgumentException("Duplicate introspection level scope");
        }
        var kinds=new HashSet<>(source.getKindsList());if(kinds.contains(ObjectKind.UNRECOGNIZED))throw new IllegalArgumentException("Unknown metadata object kind");
        if(kinds.size()!=source.getKindsCount())throw new IllegalArgumentException("Duplicate metadata object kind");
        return new MetadataConfiguration(revision,new HashSet<>(source.getIncludedCatalogsList()),new HashSet<>(source.getExcludedCatalogsList()),new HashSet<>(source.getIncludedSchemasList()),new HashSet<>(source.getExcludedSchemasList()),source.getSystemObjects(),kinds,source.getIncludePatternsList(),source.getExcludePatternsList(),IntrospectionLevel.of(source.getDefaultLevel()),levels);
    }
    public static MetadataIntrospectionConfiguration projection(MetadataConfiguration configuration) {
        var out=MetadataIntrospectionConfiguration.newBuilder().addAllIncludedCatalogs(configuration.includedCatalogs().stream().sorted().toList()).addAllExcludedCatalogs(configuration.excludedCatalogs().stream().sorted().toList())
            .addAllIncludedSchemas(configuration.includedSchemas().stream().sorted().toList()).addAllExcludedSchemas(configuration.excludedSchemas().stream().sorted().toList()).setSystemObjects(configuration.systemObjects())
            .addAllKinds(configuration.kinds().stream().sorted(Comparator.comparingInt(ObjectKind::getNumber)).toList()).addAllIncludePatterns(configuration.includePatterns()).addAllExcludePatterns(configuration.excludePatterns()).setDefaultLevel(configuration.defaultLevel().number());
        for(var entry:new TreeMap<>(configuration.scopeLevels()).entrySet()) {
            var scope=MetadataConfiguration.scopeParts(entry.getKey());out.addScopeLevels(MetadataScopeLevel.newBuilder().setCatalog(scope.get(0)).setSchema(scope.get(1)).setLevel(entry.getValue().number()));
        }
        return out.build();
    }
}
