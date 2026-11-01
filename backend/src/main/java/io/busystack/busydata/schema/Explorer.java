package io.busystack.busydata.schema;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.sessions.SessionRegistry;
import io.busystack.busydata.metadata.*;
import java.nio.charset.StandardCharsets;
import java.security.*;
import java.sql.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.function.Predicate;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

/** Bounded native catalog enumeration, separate from server-wide object search. */
public final class Explorer {
    public static final class ContinuationFailure extends IllegalArgumentException {
        public ContinuationFailure(){super("Metadata changed or its continuation expired; restart this branch");}
    }
    private final MetadataPlatform platform;
    private final byte[] continuationKey=new byte[32];
    private static final Semaphore admission=new Semaphore(4,true);
    private static final ExecutorService cancellation=Executors.newVirtualThreadPerTaskExecutor();
    public Explorer(MetadataPlatform platform){this.platform=Objects.requireNonNull(platform);new SecureRandom().nextBytes(continuationKey);}
    public Explorer(io.busystack.busydata.storage.MetadataStore metadata){this(Objects.requireNonNull(metadata).metadataPlatform());}
    public MetadataPlatform metadata(){return platform;}
    public MetadataSnapshot refreshContext(SessionRegistry.Session session)throws Exception{return refreshContext(session,MetadataPlatform.RefreshMode.INCREMENTAL);}
    public MetadataSnapshot refreshContext(SessionRegistry.Session session,MetadataPlatform.RefreshMode mode)throws Exception{return platform.coalesce(session,"context:"+mode,()->refreshProgram(session,refresh->refresh.context(session,mode)));}
    public MetadataSnapshot refreshFragment(SessionRegistry.Session session,String catalog,String schema,String table,ObjectKind kind)throws Exception{return platform.coalesce(session,"fragment:"+MetadataIdentity.digest(catalog,schema,table,kind.name()),()->refreshProgram(session,refresh->refresh.fragment(session,catalog,schema,table,kind)));}
    @FunctionalInterface private interface RefreshAction{MetadataSnapshot run(MetadataRefresh refresh)throws Exception;}
    private MetadataSnapshot refreshProgram(SessionRegistry.Session session,RefreshAction action)throws Exception{
        long revision=session.revision,context=session.contextRevision,deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(30);
        for(int attempt=0;;attempt++)try{return action.run(new MetadataRefresh(this,deadline));}
        catch(MetadataPlatform.SupersededRefresh superseded){if(session.revision!=revision||session.contextRevision!=context)throw new ContinuationFailure();if(attempt==2||System.nanoTime()>=deadline)throw superseded;}
    }
    public MetadataSnapshot refreshSessionOverlay(SessionRegistry.Session session)throws Exception{return SessionMetadataOverlay.refresh(this,session);}
    public MetadataSnapshot refreshTemporary(SessionRegistry.Session session,String catalog,String schema,String table)throws Exception{return SessionMetadataOverlay.refresh(this,session,catalog,schema,table);}

    /** Explorer is a paged presentation of the same immutable model used by analysis/editing. */
    public SchemaObjects explore(SessionRegistry.Session source,ExploreRequest request)throws Exception {
        validate(source,request);checkCancelled(io.grpc.Context.current());
        long acquisitionDeadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(30);
        if(request.getRefresh())source.advanceRevision();
        long revision=source.revision,context=source.contextRevision;
        if(request.getGlobalSearch())return search(source,request);
        String catalog=request.getCatalog().isEmpty()?(source.profile.getEngine()!=Engine.POSTGRESQL&&!request.getSchema().isEmpty()?request.getSchema():source.context.catalog()):request.getCatalog();
        String schema=request.getKind()==ObjectKind.CATALOG||request.getKind()==ObjectKind.SCHEMA?request.getSchema():request.getSchema().isEmpty()?(source.profile.getEngine()==Engine.POSTGRESQL?source.context.schema():catalog):request.getSchema();
        if(source.profile.getEngine()==Engine.POSTGRESQL){if(schema.equals("pg_temp"))schema=source.context.temporarySchema();if(schema.startsWith("pg_temp_")&&(!catalog.equals(source.context.catalog())||!schema.equals(source.context.temporarySchema())))throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.INVALID_OWNER);}
        schema=effectiveSchema(source,request,catalog,schema);
        boolean child=Set.of(ObjectKind.COLUMN,ObjectKind.INDEX,ObjectKind.CONSTRAINT,ObjectKind.FOREIGN_KEY,ObjectKind.TRIGGER).contains(request.getKind());
        var scope=new MetadataScope(request.getKind()==ObjectKind.CATALOG?"":catalog,schema,child?request.getTable():"",request.getKind(),!child&&!request.getTable().isEmpty()?request.getTable():request.getSearch(),!child&&!request.getTable().isEmpty()||request.getExactName(),request.getIdentifier(),request.getSubtype());
        var config=platform.configuration(source);
        IntrospectionLevel level=request.getIntrospectionLevel()==0?config.level(catalog,schema):IntrospectionLevel.of(request.getIntrospectionLevel());
        String continuationScope=digest(source.profile.getId()+"\0"+source.id+"\0"+revision+"\0"+context+"\0"+scope.key()+"\0"+level.number()+"\0"+config.revision());
        var snapshot=platform.capture(source);var coverage=snapshot.catalogCoverage().get(scope);
        if(request.getRefresh()){
            snapshot=refreshRequested(source,request,scope,level,snapshot);coverage=snapshot.catalogCoverage().get(scope);
        }
        if(!temporarySourceContextMatches(source,snapshot,scope,level))coverage=null;
        if(!request.getContinuation().isEmpty()&&(coverage==null||!coverage.complete()||!coverage.level().includes(level)))throw new ContinuationFailure();
        if(coverage==null||!coverage.complete()||!coverage.level().includes(level)) {
            snapshot=platform.coalesce(source,"explore:"+scope.key()+":"+level.number()+":"+request.getIndependentMetadata(),
                ()->acquireScope(source,request,scope,level,revision,context,config.revision(),acquisitionDeadline));
            coverage=Objects.requireNonNull(snapshot.catalogCoverage().get(scope));
        }
        checkScopeOwner(source,revision,context,config.revision());
        boolean resolutionAvailable=snapshot.scopeResolutionAvailable(scope);
        if(!resolutionAvailable&&!request.getContinuation().isEmpty())throw new ContinuationFailure();
        var out=scopePresentation(snapshot,scope,level)
            .setContextRevision(context).setSessionRevision(revision).setProfileId(source.profile.getId()).setSessionId(source.id).setInstanceId(request.getContext().getInstanceId())
            .setCatalog(catalog).setSchema(request.getSchema()).setParent(request.getTable()).setKind(request.getKind()).setSubtype(request.getSubtype())
            .setMetadataSnapshotRevision(snapshot.revision()).setMetadataConfigurationRevision(snapshot.configurationRevision()).setMetadataSourceIdentity(snapshot.source()).setIntrospectionLevel(coverage.level().number());
        if(request.getKind()==ObjectKind.CATALOG)out.setDefaultNamespace(catalog.equals(source.context.catalog())?source.context.catalog():coverage.defaultNamespace());
        if(request.getKind()==ObjectKind.SCHEMA)out.setDefaultNamespace(catalog.equals(source.context.catalog())?source.context.schema():coverage.defaultNamespace());
        if(!coverage.complete())return out.setComplete(false).setCountAvailability(MetadataCount.COUNT_UNAVAILABLE).build();
        var values=snapshot.select(scope);if(resolutionAvailable)out.setCountAvailability(MetadataCount.AUTHORITATIVE_TOTAL).setTotalCount(values.size());else out.setCountAvailability(MetadataCount.COUNT_UNAVAILABLE);
        var after=request.getContinuation().isEmpty()?SchemaObject.getDefaultInstance():decode(request.getContinuation(),continuationScope);
        if(!request.getContinuation().isEmpty()&&!after.getPropertiesOrDefault("fingerprint","").equals(coverage.fingerprint()))throw new ContinuationFailure();
        boolean more=false;int bytes=512;
        for(var value:values) {
            if(!after.getName().isEmpty()&&compare(value,after)<=0)continue;
            var object=snapshot.projection(value);
            if(request.getKind()==ObjectKind.CATALOG||request.getKind()==ObjectKind.SCHEMA)object=object.toBuilder().putProperties("defaultNamespace",Boolean.toString(object.getName().equals(out.getDefaultNamespace()))).build();
            if(out.getObjectsCount()==limit(request)||bytes+object.getSerializedSize()+16>524_288){more=true;break;}
            out.addObjects(object);bytes+=object.getSerializedSize()+16;
        }
        if(more&&resolutionAvailable&&coverage.level().includes(level)) {
            if(out.getObjectsCount()==0)throw new IllegalArgumentException("Metadata page cannot make progress within its byte budget");
            var last=out.getObjects(out.getObjectsCount()-1);
            out.setContinuation(encode(last.toBuilder().clearProperties().putProperties("scope",continuationScope).putProperties("fingerprint",coverage.fingerprint()).build()));
        }
        checkScopeOwner(source,revision,context,config.revision());
        if(platform.capture(source).revision()!=snapshot.revision())throw new ContinuationFailure();
        return out.setComplete(resolutionAvailable&&!more&&coverage.level().includes(level)).build();
    }
    /** Raw coverage controls acquisition and candidate paging; the response
     * reports the same effective authority as each projected object. */
    static SchemaObjects.Builder scopePresentation(MetadataSnapshot snapshot,MetadataScope scope){
        return scopePresentation(snapshot,scope,null);
    }
    static SchemaObjects.Builder scopePresentation(MetadataSnapshot snapshot,MetadataScope scope,IntrospectionLevel requested){
        var coverage=snapshot.coverage(scope).orElseThrow();var state=coverage.state();
        if(state==MetadataState.AVAILABLE&&requested!=null&&!coverage.level().includes(requested))state=MetadataState.PARTIAL;
        String limitation=coverage.limitation();
        if(state!=MetadataState.AVAILABLE&&limitation.isEmpty())limitation="Metadata coverage is "+state.name().toLowerCase(Locale.ROOT);
        return SchemaObjects.newBuilder().setMetadataState(state.name()).setAvailability(state==MetadataState.AVAILABLE?"available":state.name().toLowerCase(Locale.ROOT)+": "+limitation);
    }
    /** A superseded metadata read may reconcile; an execution or continuation never retries. */
    private MetadataSnapshot acquireScope(SessionRegistry.Session source,ExploreRequest request,MetadataScope scope,IntrospectionLevel level,long revision,long context,long configuration,long deadline)throws Exception {
        for(int attempt=0;;attempt++) {
            checkScopeOwner(source,revision,context,configuration);checkAcquisitionDeadline(deadline);
            var current=platform.capture(source);
            var publicationOwner=new ScopePublicationOwner(revision,context,configuration,current.source(),current.sessionResolution().epoch());
            if(usableScope(source,current,scope,level,configuration))return current;
            long ticket=platform.beginRefresh(source);
            var loaded=collect(source,request.toBuilder().clearRefresh().clearContinuation().setLimit(500).build(),scope,level,deadline);
            checkScopeOwner(source,revision,context,configuration);checkAcquisitionDeadline(deadline);
            boolean owned=loaded.sessionOwned()||!request.getIndependentMetadata()&&(!source.autoCommit||source.state==TransactionState.ACTIVE||loaded.objects().stream().anyMatch(o->o.getSchema().startsWith("pg_temp_")));
            try{return publishScope(source,ticket,loaded,scope,owned,publicationOwner);}
            catch(MetadataPlatform.SupersededRefresh superseded){
                checkScopeOwner(source,revision,context,configuration);checkAcquisitionDeadline(deadline);
                current=platform.capture(source);
                if(usableScope(source,current,scope,level,configuration))return current;
                if(attempt==2)throw superseded;
            }
        }
    }
    private record ScopePublicationOwner(long revision,long context,long configuration,String source,long resolutionEpoch){}
    /** Collection releases its JDBC ownership before returning. An owned
     * overlay still needs the same physical lease when its evidence is
     * atomically published; source-only changes must rebind their anchors. */
    private MetadataSnapshot publishScope(SessionRegistry.Session source,long ticket,Loaded loaded,MetadataScope scope,boolean owned,ScopePublicationOwner expected)throws Exception {
        if(!owned)return platform.publish(source,ticket,loaded.rules(),Map.of(scope,loaded.branch()),false);
        boolean acquired=false;
        if(!source.lock.isHeldByCurrentThread()){
            if(!source.lock.tryLock())throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.UNAVAILABLE);
            acquired=true;
        }
        try{
            checkScopeOwner(source,expected.revision(),expected.context(),expected.configuration());
            if(!source.metadataSourceIdentity.equals(expected.source())||!platform.capture(source).source().equals(expected.source())||platform.sessionResolutionEpoch(source)!=expected.resolutionEpoch())throw new ContinuationFailure();
            return platform.publish(source,ticket,loaded.rules(),Map.of(scope,loaded.branch()),true);
        }finally{if(acquired)source.lock.unlock();}
    }
    private boolean usableScope(SessionRegistry.Session source,MetadataSnapshot snapshot,MetadataScope scope,IntrospectionLevel level,long configuration){return snapshot.configurationRevision()==configuration&&temporarySourceContextMatches(source,snapshot,scope,level)&&Optional.ofNullable(snapshot.catalogCoverage().get(scope)).filter(coverage->coverage.complete()&&coverage.level().includes(level)).isPresent();}
    private static boolean temporarySourceContextMatches(SessionRegistry.Session source,MetadataSnapshot snapshot,MetadataScope scope,IntrospectionLevel level){
        if(source.profile.getEngine()==Engine.POSTGRESQL||scope.kind()!=ObjectKind.TABLE||!scope.exactName()||!level.includes(IntrospectionLevel.SOURCE))return true;
        for(var object:snapshot.select(scope))if(object.identity().sessionOwner().equals(source.id)&&"true".equals(object.properties().get("temporary")))return object.properties().containsKey("sourceSqlMode")&&object.properties().get("sourceSqlMode").equals(source.context.sqlMode());
        return true;
    }
    private void checkScopeOwner(SessionRegistry.Session source,long revision,long context,long configuration){
        checkCancelled(io.grpc.Context.current());
        if(source.physicalEnded()||source.revision!=revision||source.contextRevision!=context||source.state==TransactionState.DISCONNECTED||source.state==TransactionState.UNKNOWN_TRANSACTION||platform.configuration(source).revision()!=configuration)throw new ContinuationFailure();
    }
    private static void checkAcquisitionDeadline(long deadline)throws TimeoutException {if(System.nanoTime()>=deadline)throw new TimeoutException("Explorer metadata acquisition deadline exceeded");}
    private MetadataSnapshot refreshRequested(SessionRegistry.Session session,ExploreRequest request,MetadataScope scope,IntrospectionLevel level,MetadataSnapshot snapshot)throws Exception{
        String mode=request.getRefreshMode().isEmpty()?"FRAGMENT":request.getRefreshMode();
        if(mode.equals("FULL"))return refreshContext(session,MetadataPlatform.RefreshMode.FULL);
        if(mode.equals("INCREMENTAL"))return refreshContext(session,MetadataPlatform.RefreshMode.INCREMENTAL);
        String table=scope.parent().isEmpty()&&(scope.kind()==ObjectKind.TABLE||scope.kind()==ObjectKind.VIEW)&&scope.exactName()?scope.search():scope.parent();
        if(!request.getIndependentMetadata()&&!table.isEmpty()){
            boolean temporary=snapshot.namespace(scope.catalog(),scope.schema(),ObjectKind.TABLE,"").stream().anyMatch(o->o.identity().name().equals(table)&&o.identity().sessionOwner().equals(session.id)&&"true".equals(o.properties().get("temporary")));
            if(temporary){if(!session.lock.tryLock())throw new IllegalStateException("Owning temporary-object session is busy");try{return session.profile.getEngine()==Engine.POSTGRESQL?refreshSessionOverlay(session):refreshTemporary(session,scope.catalog(),scope.schema(),table);}finally{session.lock.unlock();}}
        }
        IntrospectionLevel structure=level==IntrospectionLevel.SOURCE?IntrospectionLevel.STRUCTURE:level;
        return platform.coalesce(session,"explorer-refresh:"+scope.key()+":"+structure,()->refreshProgram(session,refresh->{
            var selected=refresh.atLevel(structure);
            if(!table.isEmpty()){
                var kind=scope.kind()==ObjectKind.VIEW||!snapshot.resolve(scope.catalog(),scope.schema(),ObjectKind.VIEW,"",table,true).isEmpty()?ObjectKind.VIEW:ObjectKind.TABLE;
                return selected.fragment(session,scope.catalog(),scope.schema(),table,kind);
            }
            return selected.refresh(session,MetadataPlatform.RefreshMode.FRAGMENT,List.of(scope));
        }));
    }
    private static int compare(MetadataObject value,SchemaObject after) {
        int result=value.identity().name().compareTo(after.getName());if(result!=0)return result;
        result=value.identity().parent().compareTo(after.getTable());return result!=0?result:value.identity().signature().compareTo(after.getIdentifier());
    }
    private String effectiveSchema(SessionRegistry.Session source,ExploreRequest request,String catalog,String schema)throws Exception {
        if(request.getIndependentMetadata()||source.profile.getEngine()!=Engine.POSTGRESQL||!request.getSchema().isEmpty()||request.getTable().isEmpty()||source.context.temporarySchema().isEmpty()||!catalog.equals(source.context.catalog()))return schema;
        String temporary=source.context.temporarySchema();var snapshot=platform.capture(source);
        if(!snapshot.resolve(catalog,temporary,ObjectKind.TABLE,"",request.getTable(),true).isEmpty()||!snapshot.namespace(catalog,temporary,request.getKind(),request.getTable()).isEmpty())return temporary;
        var known=new MetadataScope(catalog,schema,request.getTable(),request.getKind(),request.getSearch(),request.getExactName(),request.getIdentifier(),request.getSubtype());
        if(!request.getRefresh()&&snapshot.coverage(known).filter(MetadataCoverage::complete).isPresent())return schema;
        if(!source.lock.tryLock())return schema;
        try {
            if(!source.autoCommit&&source.state!=TransactionState.ACTIVE)return schema;
            try(var query=source.adapter.catalogStatement(source.connection,"SELECT 1 FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=? AND c.relname=?")) {
                query.setString(1,temporary);query.setString(2,request.getTable());try(var rows=query.executeQuery()){return rows.next()?temporary:schema;}
            }
        }finally{source.lock.unlock();}
    }
    private record Loaded(MetadataPlatform.Branch branch,IdentifierRules rules,boolean sessionOwned) {
        Loaded(MetadataPlatform.Branch branch,IdentifierRules rules){this(branch,rules,false);}
        List<SchemaObject> objects(){return branch.objects();}
    }
    public boolean isOwnedTemporary(SessionRegistry.Session session,String catalog,String schema,String table){return ownedTemporary(session,catalog,schema,table).isPresent();}
    private Optional<MetadataObject> ownedTemporary(SessionRegistry.Session session,String catalog,String schema,String table) {
        if(session.profile.getEngine()==Engine.POSTGRESQL||table.isEmpty())return Optional.empty();
        String exactCatalog=catalog.isEmpty()?session.context.catalog():catalog,exactSchema=schema.isEmpty()?exactCatalog:schema;
        return platform.capture(session).resolve(exactCatalog,exactSchema,ObjectKind.TABLE,"",table,true).stream().filter(object->object.identity().sessionOwner().equals(session.id)&&"true".equals(object.properties().get("temporary"))).findFirst();
    }
    private Loaded collect(SessionRegistry.Session source,ExploreRequest request,MetadataScope scope,IntrospectionLevel level,long deadline)throws Exception {
        long revision=source.revision,context=source.contextRevision;
        String table=scope.parent().isEmpty()?(scope.kind()==ObjectKind.TABLE&&scope.exactName()?scope.search():""):scope.parent();
        var temporary=ownedTemporary(source,scope.catalog(),scope.schema(),table);
        if(temporary.isPresent()) {
            if(!source.lock.tryLock())throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.UNAVAILABLE);
            try {
                if(source.revision!=revision||source.contextRevision!=context||source.physicalEnded())throw new ContinuationFailure();
                var branch=SessionMetadataOverlay.branch(this,source,temporary.get(),scope,level,deadline);
                if(source.revision!=revision||source.contextRevision!=context||source.physicalEnded())throw new ContinuationFailure();
                return new Loaded(branch,platform.capture(source).rules(),true);
            }finally{source.lock.unlock();}
        }
        var exact=request.toBuilder().setIntrospectionLevel(level.number()).setSchema(scope.schema()).setSearch(scope.search()).setExactName(scope.exactName()).build();
        boolean physicalTemporary=source.profile.getEngine()==Engine.POSTGRESQL&&!source.context.temporarySchema().isEmpty()&&scope.schema().equals(source.context.temporarySchema());
        var capturedConfig=platform.configuration(source);
        Predicate<SchemaObject> admitted=object->capturedConfig.permits(object.getCatalog(),object.getSchema(),object.getKind(),object.getName())||physicalTemporary&&scope.catalog().equals(source.context.catalog())&&capturedConfig.kinds().contains(object.getKind());
        if(!request.getIndependentMetadata()&&physicalTemporary&&scope.catalog().equals(source.context.catalog())&&source.lock.tryLock())try {
            if(source.autoCommit||source.state==TransactionState.ACTIVE)return collectOnView(source,exact,scope,level,deadline,revision,context,platform.capture(source).rules(),admitted);
        }finally{source.lock.unlock();}
        return source.metadata(scope.catalog().isEmpty()?source.context.catalog():scope.catalog(),view->{try(var acquisition=new MetadataReadScope(view.connection,deadline)){try{var result=collectOnView(view,exact,scope,level,deadline,revision,context,platform.capture(source).rules(),admitted);acquisition.check();return result;}catch(Exception failure){acquisition.check();throw failure;}}});
    }
    private Loaded collectOnView(SessionRegistry.Session view,ExploreRequest request,MetadataScope scope,IntrospectionLevel level,long deadline,long revision,long context,IdentifierRules previous,Predicate<SchemaObject> admitted)throws Exception {
        var rules=view.isIndependentMetadataView()?NativeStructureReader.rules(view,previous,deadline):previous;
        try {
            if(request.getKind()==ObjectKind.ROUTINE){
                var scan=scanRoutineBranch(view,request,deadline,admitted);var values=fetchBranch(view,request,deadline,admitted);var verification=scanRoutineBranch(view,request,deadline,admitted);
                if(scan.count()!=verification.count()||!scan.fingerprint().equals(verification.fingerprint())||!scan.evidence().equals(verification.evidence()))throw new ContinuationFailure();
                return new Loaded(routineCollection(view.profile.getEngine(),scope,level,scan,values,revision,context),rules);
            }
            var scan=scanBranch(view,request);
            var values=fetchBranch(view,request,deadline,admitted);
            var verification=scanBranch(view,request);
            if(!scan.fingerprint().equals(verification.fingerprint()))throw new ContinuationFailure();
            String defaultNamespace=request.getKind()==ObjectKind.SCHEMA?view.context.schema():request.getKind()==ObjectKind.CATALOG?view.context.catalog():"";
            return new Loaded(new MetadataPlatform.Branch(values,new MetadataCoverage(scope,level,MetadataState.AVAILABLE,true,scan.fingerprint(),revision,context,System.currentTimeMillis(),"",defaultNamespace)),rules);
        }catch(MetadataLimit limited) {
            return new Loaded(new MetadataPlatform.Branch(List.of(),new MetadataCoverage(scope,level,MetadataState.LIMITED,false,"",revision,context,0,"Catalog byte/row budget reached; narrow the object scope")),rules);
        }
    }
    private record RoutineObjectKey(String catalog,String schema,String name,String signature,ObjectSubtype subtype,String nativeId){}
    private static RoutineObjectKey routineObjectKey(Engine engine,SchemaObject object){
        if(object.getKind()!=ObjectKind.ROUTINE||!object.getTable().isEmpty()||object.getIdentifier().isEmpty()||object.getSubtype()!=ObjectSubtype.FUNCTION&&object.getSubtype()!=ObjectSubtype.PROCEDURE)throw new ContinuationFailure();
        return new RoutineObjectKey(object.getCatalog(),object.getSchema(),object.getName(),object.getIdentifier(),object.getSubtype(),engine==Engine.POSTGRESQL?object.getPropertiesOrDefault("nativeId",""):"");
    }
    /** A single direct branch retains all known fields at the common proven
     * depth. Raw objects preserve the publisher's physical TEMP ownership. */
    static MetadataPlatform.Branch routineCollection(Engine engine,MetadataScope scope,IntrospectionLevel requested,RoutineFingerprintReader.Scan scan,List<SchemaObject> values,long revision,long context){
        if(scan.count()!=values.size()||scan.evidence().size()!=values.size())throw new ContinuationFailure();
        var evidence=new HashMap<RoutineObjectKey,RoutineFingerprintReader.Evidence>();
        for(var item:scan.evidence())if(evidence.put(routineObjectKey(engine,item.identity()),item)!=null)throw new ContinuationFailure();
        var level=requested;String limitation="";
        for(var value:values){
            var item=evidence.remove(routineObjectKey(engine,value));if(item==null)throw new ContinuationFailure();
            var availability=RoutineAvailability.assess(requested,value.getPropertiesMap(),item.state());
            if(availability.level().number()<level.number())level=availability.level();if(limitation.isEmpty()&&availability.failure()!=MetadataState.AVAILABLE)limitation=availability.limitation();
        }
        if(!evidence.isEmpty())throw new ContinuationFailure();
        return new MetadataPlatform.Branch(values,new MetadataCoverage(scope,level,MetadataState.AVAILABLE,true,scan.fingerprint(),revision,context,System.currentTimeMillis(),limitation));
    }
    private SchemaObjects search(SessionRegistry.Session source,ExploreRequest request)throws Exception {
        var result=nativeExplore(source,request.toBuilder().clearRefresh().build());
        var semanticObjects=result.getObjectsList().stream().map(object->Set.of(ObjectKind.TABLE,ObjectKind.VIEW,ObjectKind.SEQUENCE).contains(object.getKind())?object.toBuilder().clearTable().build():object).toList();
        var branches=new LinkedHashMap<MetadataScope,MetadataPlatform.Branch>();var before=platform.publishedSnapshot(source);
        for(var object:semanticObjects) {
            var known=before.resolve(object.getCatalog(),object.getSchema(),object.getKind(),object.getTable(),object.getName(),true).stream().filter(value->value.identity().signature().equals(object.getIdentifier())&&(object.getSubtype()==ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED||value.identity().subtype()==object.getSubtype())).toList();
            if(known.size()==1)continue; // Search discovers names; it does not refresh or downgrade inspected facts.
            var scope=new MetadataScope(object.getCatalog(),object.getSchema(),object.getTable(),object.getKind(),object.getName(),true,object.getIdentifier(),object.getSubtype());
            branches.put(scope,new MetadataPlatform.Branch(List.of(object),new MetadataCoverage(scope,IntrospectionLevel.NAMES,MetadataState.AVAILABLE,true,digest(object.toString()),source.revision,source.contextRevision,System.currentTimeMillis(),"")));
        }
        var snapshot=branches.isEmpty()?platform.capture(source):platform.publish(source,platform.beginRefresh(source),platform.capture(source).rules(),branches,false);
        var out=result.toBuilder().clearObjects().setMetadataSnapshotRevision(snapshot.revision()).setMetadataConfigurationRevision(snapshot.configurationRevision()).setMetadataSourceIdentity(snapshot.source()).setIntrospectionLevel(1).setMetadataState("PARTIAL");
        for(var object:semanticObjects)if(platform.configuration(source).permits(object.getCatalog(),object.getSchema(),object.getKind(),object.getName())){
            var matches=snapshot.resolve(object.getCatalog(),object.getSchema(),object.getKind(),object.getTable(),object.getName(),true).stream().filter(value->value.identity().signature().equals(object.getIdentifier())).toList();
            if(matches.size()!=1)throw new IllegalStateException("Search identity is not unique in the published metadata snapshot");out.addObjects(snapshot.projection(matches.getFirst()));
        }
        return out.build();
    }

    private SchemaObjects nativeExplore(SessionRegistry.Session source,ExploreRequest request)throws Exception {
        validate(source,request);
        if(request.getRefresh())source.advanceRevision();
        long revision=source.revision,contextRevision=source.contextRevision;
        if(request.getGlobalSearch())return ObjectSearch.search(source,request).toBuilder().setSessionRevision(revision).build();
        if(!admission.tryAcquire())throw new IllegalStateException("Metadata enumeration admission limit reached");
        try {
            String catalog=request.getCatalog().isEmpty()?(source.profile.getEngine()!=Engine.POSTGRESQL&&!request.getSchema().isEmpty()?request.getSchema():source.context.catalog()):request.getCatalog();
            String scope=digest(source.profile.getId()+"\0"+source.id+"\0"+revision+"\0"+contextRevision+"\0"+catalog+"\0"+request.toBuilder().clearContext().clearSessionId().clearRefresh().clearContinuation().clearLimit().clearExpectedSessionRevision().clearExpectedContextRevision().build());
            var after=request.getContinuation().isEmpty()?SchemaObject.getDefaultInstance():decode(request.getContinuation(),scope);
            SchemaObjects result=null;
            if(!request.getIndependentMetadata()&&catalog.equals(source.context.catalog())&&source.lock.tryLock())try {
                if(source.autoCommit||source.state==TransactionState.ACTIVE)result=inspect(source,request,scope,after);
            }finally{source.lock.unlock();}
            if(result==null) {
                result=source.metadata(catalog,view->inspect(view,request,scope,after));
                if(!request.getIndependentMetadata()&&catalog.equals(source.context.catalog()))result=result.toBuilder().setAvailability((result.getComplete()?"":result.getAvailability()+"; ")+"Persistent objects in the live context; busy/idle-manual console-local objects require a session refresh after execution").build();
            }
            if(source.state==TransactionState.DISCONNECTED||source.revision!=revision||source.contextRevision!=contextRevision)throw new IllegalStateException("Metadata owner changed; refresh the selected branch");
            result=result.toBuilder().setContextRevision(contextRevision).setSessionRevision(revision)
                .setProfileId(source.profile.getId()).setSessionId(source.id).setInstanceId(request.getContext().getInstanceId())
                .setCatalog(catalog).setSchema(request.getSchema()).setParent(request.getTable()).setKind(request.getKind()).setSubtype(request.getSubtype()).build();
            return result;
        }finally{admission.release();}
    }
    private static void validate(SessionRegistry.Session s,ExploreRequest r) {
        if(s.state==TransactionState.DISCONNECTED||s.state==TransactionState.UNKNOWN_TRANSACTION)throw new IllegalStateException("Session disconnected or uncertain");
        if(r.hasExpectedSessionRevision()&&r.getExpectedSessionRevision()!=s.revision||r.hasExpectedContextRevision()&&r.getExpectedContextRevision()!=s.contextRevision)throw new ContinuationFailure();
        if(r.getRefresh()&&!r.getContinuation().isEmpty())throw new IllegalArgumentException("Refresh requires a new metadata enumeration");
        if(!Set.of("","FULL","FRAGMENT","INCREMENTAL").contains(r.getRefreshMode())||!r.getRefreshMode().isEmpty()&&(!r.getRefresh()||r.getGlobalSearch()))throw new IllegalArgumentException("Metadata refresh mode requires an explicit supported tree refresh");
        for(String name:List.of(r.getCatalog(),r.getSchema(),r.getTable(),r.getSearch()))if(name.length()>256||name.indexOf('\0')>=0)throw new IllegalArgumentException("Invalid metadata scope or search");
        if(r.getContinuation().length()>RoutineIdentity.CONTINUATION_TEXT)throw new IllegalArgumentException("Metadata continuation exceeds its budget");
        if(r.getIdentifier().getBytes(StandardCharsets.UTF_8).length>RoutineIdentity.MAX_BYTES||r.getIdentifier().indexOf('\0')>=0)throw new IllegalArgumentException("Invalid native overload identity");
        if(!r.getIdentifier().isEmpty()&&r.getKind()!=ObjectKind.ROUTINE&&!(s.profile.getEngine()!=Engine.POSTGRESQL&&r.getKind()==ObjectKind.CONSTRAINT&&SchemaConstraints.nativeType(r.getIdentifier()))||r.getExactName()&&r.getSearch().isEmpty()||r.getGlobalSearch()&&(r.getExactName()||!r.getIdentifier().isEmpty()))throw new IllegalArgumentException("Exact identity lookup requires a supported tree scope");
        if(r.getSubtype()!=ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED&&(r.getGlobalSearch()||r.getKind()!=ObjectKind.ROUTINE||r.getSubtype()!=ObjectSubtype.FUNCTION&&r.getSubtype()!=ObjectSubtype.PROCEDURE))throw new IllegalArgumentException("Only routine tree scopes support function/procedure filtering");
        if(Integer.toUnsignedLong(r.getLimit())>500)throw new IllegalArgumentException("Metadata page limit is 500 objects");
    }
    private static int limit(ExploreRequest r){return r.getLimit()==0?128:r.getLimit();}
    private record Query(String sql,List<String> parameters,List<String> properties) {
        Query(String sql,List<String> parameters,String... properties){this(sql,parameters,List.of(properties));}
    }
    public record BranchScan(String fingerprint,long count){}
    public RoutineFingerprintReader.Scan scanRoutineBranch(SessionRegistry.Session view,ExploreRequest request,long deadline,Predicate<SchemaObject> admitted)throws Exception {
        if(request.getKind()!=ObjectKind.ROUTINE)throw new IllegalArgumentException("Routine fingerprint scope required");
        var query=query(view,request);var filtered=filtered(view,request,query);
        var level=request.getIntrospectionLevel()==0?IntrospectionLevel.STRUCTURE:IntrospectionLevel.of(request.getIntrospectionLevel());
        return RoutineFingerprintReader.scan(view,filtered.sql(),filtered.parameters(),level,deadline,admitted);
    }
    public BranchScan scanBranch(SessionRegistry.Session view,ExploreRequest request)throws Exception {
        var query=query(view,request);var filtered=filtered(view,request,query);var count=SchemaObjects.newBuilder();
        return new BranchScan(fingerprint(view,filtered.sql(),filtered.parameters(),query.properties(),count,request.getKind()),count.getTotalCount());
    }
    private static Query filtered(SessionRegistry.Session view,ExploreRequest request,Query query) {
        String name=view.profile.getEngine()==Engine.POSTGRESQL?"n COLLATE \"C\"":"BINARY n";
        String sql="SELECT * FROM ("+query.sql()+") metadata WHERE "+(request.getExactName()?name+" = ?":"LOWER(n) LIKE ? ESCAPE '!'");
        var parameters=new ArrayList<>(query.parameters());parameters.add(request.getExactName()?request.getSearch():"%"+request.getSearch().toLowerCase(Locale.ROOT).replace("!","!!").replace("%","!%").replace("_","!_")+"%");
        if(!request.getIdentifier().isEmpty()){sql+=" AND "+(view.profile.getEngine()==Engine.POSTGRESQL?"i COLLATE \"C\"":"BINARY i")+" = ?";parameters.add(request.getIdentifier());}
        if(request.getSubtype()!=ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED){sql+=" AND k = ?";parameters.add(request.getSubtype()==ObjectSubtype.FUNCTION?"FUNCTION":"PROCEDURE");}
        return new Query(sql,parameters,query.properties());
    }
    /** Resource accounting for one collection, independent of metadata semantics. */
    public static final class CollectionBudget {
        private final int objects;private final long bytes;private final java.util.function.LongConsumer allocations;private long driverScratch;
        public CollectionBudget(int objects,long bytes,java.util.function.LongConsumer allocations){if(objects<1||objects>MetadataSnapshot.MAX_OBJECTS||bytes<1||bytes>MetadataPlatform.MAX_TOTAL_BYTES)throw new IllegalArgumentException("Metadata collection budget is invalid");this.objects=objects;this.bytes=bytes;this.allocations=Objects.requireNonNull(allocations);}
        public int objects(){return objects;}public long bytes(){return bytes;}public java.util.function.LongConsumer allocations(){return allocations;}
        private void retain(SchemaObject object){allocations.accept(512L+4L*object.getSerializedSize()+128L*object.getPropertiesCount());}
        private void driverScratch(long bytes){if(bytes<0||bytes>MetadataPlatform.MAX_TOTAL_BYTES)throw new IllegalArgumentException("Driver metadata scratch exceeds its budget");if(bytes>driverScratch){allocations.accept(bytes-driverScratch);driverScratch=bytes;}}
    }
    public List<SchemaObject> fetchBranch(SessionRegistry.Session view,ExploreRequest request,long deadline,CollectionBudget budget)throws Exception {
        return fetchBranch(view,request,deadline,ignored->true,budget);
    }
    /** The refresh coordinator owns the metadata connection and publication transaction. */
    public List<SchemaObject> fetchBranch(SessionRegistry.Session view,ExploreRequest request,long deadline)throws Exception {
        return fetchBranch(view,request,deadline,ignored->true);
    }
    /** UI acquisition supplies the already captured physical-owner policy;
     * low-level adapter callers own admission of their explicit scope. */
    public List<SchemaObject> fetchBranch(SessionRegistry.Session view,ExploreRequest request,long deadline,Predicate<SchemaObject> admitted)throws Exception {
        return fetchBranch(view,request,deadline,admitted,new CollectionBudget(MetadataSnapshot.MAX_OBJECTS,MetadataPlatform.MAX_TOTAL_BYTES,ignored->{}));
    }
    private List<SchemaObject> fetchBranch(SessionRegistry.Session view,ExploreRequest request,long deadline,Predicate<SchemaObject> admitted,CollectionBudget budget)throws Exception {
        if(request.getKind()==ObjectKind.COLUMN&&request.getIntrospectionLevel()>=2)ColumnMetadataReader.preflight(view,request.getSchema().isEmpty()?view.context.schema():request.getSchema(),request.getTable());
        budget.allocations().accept(2_097_152); // fixed current-page/driver-row scratch, before native page allocation
        var values=new ArrayList<SchemaObject>();SchemaObject after=SchemaObject.getDefaultInstance();String scope=digest(request.toString());long retainedBytes=0;
        do {
            checkCancelled(io.grpc.Context.current());if(System.nanoTime()>deadline)throw new TimeoutException("Metadata refresh deadline exceeded");
            var page=inspect(view,request,scope,after,budget::driverScratch);
            if(!page.getComplete()&&page.getContinuation().isEmpty())throw new IllegalStateException(page.getAvailability());
            for(var object:page.getObjectsList()){
                if(values.size()>=budget.objects()||(retainedBytes+=object.getSerializedSize()+16)>budget.bytes())throw new IllegalArgumentException("Metadata refresh object/byte budget exceeded");
                if(request.getKind()!=ObjectKind.ROUTINE||admitted.test(object)){budget.retain(object);values.add(object);}
            }
            if(page.getContinuation().isEmpty())break;after=decode(page.getContinuation(),scope);
        }while(true);
        if(request.getIntrospectionLevel()<2)return List.copyOf(values);
        if((request.getKind()==ObjectKind.TABLE||request.getKind()==ObjectKind.VIEW&&view.profile.getEngine()==Engine.POSTGRESQL)&&!values.isEmpty())values=new ArrayList<>(NativeRelationReader.enrich(view,values));
        if((request.getKind()==ObjectKind.TABLE||request.getKind()==ObjectKind.VIEW)&&view.profile.getEngine()==Engine.POSTGRESQL&&!values.isEmpty()) {
            var fingerprints=NativeTypeReader.namespaceFingerprints(view,values.getFirst().getSchema(),request.getExactName()?request.getSearch():"",deadline);
            for(int index=0;index<values.size();index++){var object=values.get(index);String evidence=fingerprints.get(object.getName());if(evidence==null)throw new SQLException("Native type dependency fingerprint unavailable");values.set(index,object.toBuilder().putProperties("typeDependenciesFingerprint",evidence).build());}
        }
        if(request.getKind()==ObjectKind.SEQUENCE&&!values.isEmpty())values=new ArrayList<>(NativeSequenceReader.enrich(view,values));
        if(request.getKind()==ObjectKind.COLUMN&&!values.isEmpty())values=new ArrayList<>(ColumnMetadataReader.enrich(view,values,values.getFirst().getSchema(),request.getTable(),budget.allocations()));
        if(request.getKind()==ObjectKind.TYPE)for(int index=0;index<values.size();index++)values.set(index,NativeTypeReader.enrich(view,values.get(index),request.getIntrospectionLevel()));
        if(request.getKind()==ObjectKind.CONSTRAINT&&!values.isEmpty())values=new ArrayList<>(StructuralDetails.constraints(view,values,request.getSchema().isEmpty()?view.context.schema():request.getSchema(),request.getTable()));
        if(request.getKind()==ObjectKind.INDEX&&!values.isEmpty())values=new ArrayList<>(StructuralDetails.indexes(view,values,request.getSchema().isEmpty()?view.context.schema():request.getSchema(),request.getTable()));
        if(request.getKind()==ObjectKind.FOREIGN_KEY&&!values.isEmpty()) {
            var keys=NativeStructureReader.foreignKeys(view,view.context.catalog(),request.getSchema().isEmpty()?view.context.schema():request.getSchema(),request.getTable());
            var byName=new HashMap<String,SchemaObject>();for(var key:keys)byName.put(key.getName(),key);
            for(int index=0;index<values.size();index++){var value=values.get(index);var key=byName.get(value.getName());if(key==null)throw new SQLException("Foreign-key identity changed during refresh");values.set(index,value.toBuilder().putAllProperties(key.getPropertiesMap()).build());}
        }
        if(request.getKind()==ObjectKind.ROUTINE)for(int index=0;index<values.size();index++){
            var enriched=RoutineMetadataReader.enrichWithSource(view,values.get(index),null,deadline);var value=enriched.object();
            if(request.getIntrospectionLevel()==3&&view.profile.getEngine()!=Engine.POSTGRESQL){
                var source=enriched.source()==null?NativeRoutineSource.read(view,value,deadline):enriched.source();
                var projected=value.toBuilder().setDefinition(source.available()?source.definition():"").putProperties("sourceAvailability",source.available()?"AVAILABLE":source.state()==MetadataState.AVAILABLE?"UNAVAILABLE":source.state().name()).putProperties("sourceProvenance","native").build();
                if(projected.getSerializedSize()>65_536)projected=projected.toBuilder().clearDefinition().putProperties("sourceAvailability","LIMITED").build();value=projected;
            }
            values.set(index,value);
        }
        if(request.getIntrospectionLevel()==3)for(int index=0;index<values.size();index++) {
            var value=values.get(index);if(value.getKind()==ObjectKind.CATALOG||value.getKind()==ObjectKind.SCHEMA||value.getKind()==ObjectKind.TYPE||value.getKind()==ObjectKind.ROUTINE&&view.profile.getEngine()!=Engine.POSTGRESQL)continue;
            var definition=SchemaTools.definitionOnMetadataView(view,SchemaToolRequest.newBuilder().setAction(SchemaToolAction.OBJECT_DEFINITION).setCatalog(value.getCatalog()).setSchema(value.getSchema())
                .setTable(value.getTable().isEmpty()?value.getName():value.getTable()).setObjectName(value.getName()).setKind(value.getKind()).setIdentifier(value.getIdentifier()).build());
            var projected=value.toBuilder().putAllProperties(definition.getInspectedObject().getPropertiesMap()).setDefinition(definition.getDefinition()).putProperties("sourceAvailability",definition.getComplete()?"AVAILABLE":definition.getDefinition().isEmpty()?"UNAVAILABLE":"PARTIAL").putProperties("sourceProvenance",definition.getProvenance()).build();
            if(projected.getSerializedSize()>65_536)projected=projected.toBuilder().clearDefinition().putProperties("sourceAvailability","LIMITED").build();
            values.set(index,projected);
        }
        retainedBytes=0;for(var value:values)if((retainedBytes+=value.getSerializedSize()+16)>budget.bytes())throw new IllegalArgumentException("Enriched metadata byte budget exceeded");
        budget.allocations().accept(64L+16L*values.size());return List.copyOf(values);
    }
    private SchemaObjects inspect(SessionRegistry.Session s,ExploreRequest r,String scope,SchemaObject after)throws Exception {
        return inspect(s,r,scope,after,ignored->{});
    }
    private SchemaObjects inspect(SessionRegistry.Session s,ExploreRequest r,String scope,SchemaObject after,java.util.function.LongConsumer driverScratch)throws Exception {
        var out=SchemaObjects.newBuilder().setAvailability("available");
        if(r.getKind()==ObjectKind.CATALOG)out.setDefaultNamespace(s.context.catalog());
        if(r.getKind()==ObjectKind.SCHEMA)out.setDefaultNamespace(s.context.schema());
        Query q;
        try{q=query(s,r);}catch(MetadataLimit limited){return out.setComplete(false).setAvailability("limited: catalog byte/row budget reached; narrow the object scope").build();}
        boolean pg=s.profile.getEngine()==Engine.POSTGRESQL;
        String pattern="%"+r.getSearch().toLowerCase(Locale.ROOT).replace("!","!!").replace("%","!%").replace("_","!_")+"%";
        String name=pg?"n COLLATE \"C\"":"BINARY n",parent=pg?"p COLLATE \"C\"":"BINARY p",identity=pg?"i COLLATE \"C\"":"BINARY i";
        String filtered="SELECT * FROM ("+q.sql+") metadata WHERE "+(r.getExactName()?name+" = ?":"LOWER(n) LIKE ? ESCAPE '!'");
        var parameters=new ArrayList<>(q.parameters);parameters.add(r.getExactName()?r.getSearch():pattern);
        if(!r.getIdentifier().isEmpty()){filtered+=" AND "+identity+" = ?";parameters.add(r.getIdentifier());}
        if(r.getSubtype()!=ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED){filtered+=" AND k = ?";parameters.add(r.getSubtype()==ObjectSubtype.FUNCTION?"FUNCTION":"PROCEDURE");}
        var filteredParameters=List.copyOf(parameters);
        String fingerprint=fingerprint(s,filtered,filteredParameters,q.properties,out,r.getKind());
        if(!after.getName().isEmpty()&&!after.getPropertiesOrDefault("fingerprint","").equals(fingerprint))throw new ContinuationFailure();
        String sql=filtered+(after.getName().isEmpty()?"":" AND ("+name+","+parent+","+identity+")>(?,?,?)")+" ORDER BY "+name+","+parent+","+identity+" LIMIT ?";
        if(!after.getName().isEmpty()){parameters.add(after.getName());parameters.add(after.getTable());parameters.add(after.getIdentifier());}
        var context=io.grpc.Context.current();boolean more=false;int bytes=512;
        try(var statement=s.adapter.catalogStatement(s.connection,sql)) {
            int position=bind(statement,parameters);statement.setInt(position,limit(r)+1);
            io.grpc.Context.CancellationListener listener=ignored->{try{statement.cancel();}catch(SQLException ignoredFailure){}};
            context.addListener(listener,cancellation);
            try {
                checkCancelled(context);
                try(var rows=statement.executeQuery()) {
                    while(rows.next()) {
                        checkCancelled(context);
                        var value=SchemaObject.newBuilder().setCatalog(n(rows.getString("c"))).setSchema(n(rows.getString("s"))).setTable(n(rows.getString("p")))
                            .setName(rows.getString("n")).setIdentifier(n(rows.getString("i"))).setKind(r.getKind()).setSubtype(subtype(rows.getString("k")));
                        for(String property:q.properties)if(!property.startsWith("_"))value.putProperties(switch(property){case "column_default","type_default"->"default";case "generation_kind"->"generated";case "index_columns"->"column";case "reference_columns"->"referencedColumn";default->property;},n(rows.getString(property)));
                        if(q.properties.contains("_columnBytes")&&rows.getLong("_columnBytes")>n(rows.getString("index_columns")).getBytes(StandardCharsets.UTF_8).length)value.putProperties("previewAvailability","truncated; inspect the full native object definition");
                        if(q.properties.contains("_remarksBytes")){long actual=rows.getLong("_remarksBytes");value.putProperties("remarksBytes",Long.toString(actual)).putProperties("remarksAvailability",actual>n(rows.getString("remarks")).getBytes(StandardCharsets.UTF_8).length?"LIMITED":"AVAILABLE");}
                        if(q.properties.contains("_defaultBytes")&&rows.getLong("_defaultBytes")>n(rows.getString("column_default")).getBytes(StandardCharsets.UTF_8).length)value.putProperties("previewAvailability","truncated; inspect the full native object definition");
                        if((r.getKind()==ObjectKind.TABLE||r.getKind()==ObjectKind.VIEW)&&q.properties.contains("_version"))value.putProperties("catalogFingerprint",n(rows.getString("_version")));
                        if(r.getKind()==ObjectKind.ROUTINE)value.putProperties("type",rows.getString("k"));
                        var object=value.build();
                        if(object.getIdentifier().getBytes(StandardCharsets.UTF_8).length>RoutineIdentity.MAX_BYTES||object.getSerializedSize()>65_536)throw new IllegalArgumentException("Metadata object exceeds its identity/preview budget; narrow the scope");
                        if(out.getObjectsCount()==limit(r)||bytes+object.getSerializedSize()+16>524_288){more=true;break;}
                        out.addObjects(object);bytes+=object.getSerializedSize()+16;
                    }
                }
            }finally{context.removeListener(listener);}
        }
        if(r.getKind()==ObjectKind.COLUMN&&out.getObjectsCount()>0&&r.getIntrospectionLevel()!=1) {
            // Keep the driver's exact JDBC types for reviewed predicates and
            // temporal/null binding. Length admission ran before this call.
            var first=out.getObjects(0);var types=new HashMap<String,Map<String,String>>();
            for(var column:JdbcMetadataPatterns.columns(s,first.getCatalog(),first.getSchema(),first.getTable(),driverScratch))types.put(column.getName(),column.getPropertiesMap());
            for(int index=0;index<out.getObjectsCount();index++) {
                var object=out.getObjects(index);
                var type=types.get(object.getName());if(type==null)throw new SQLException("Exact JDBC column type unavailable; refresh the selected object");
                out.setObjects(index,object.toBuilder().removeProperties("previewAvailability").putAllProperties(type));
            }
        }
        // The aggregate and returned names must belong to one catalog state.
        if(!fingerprint.equals(fingerprint(s,filtered,filteredParameters,q.properties,SchemaObjects.newBuilder(),r.getKind())))throw new ContinuationFailure();
        if(more) {
            if(out.getObjectsCount()==0)throw new IllegalArgumentException("Metadata page cannot make progress within its byte budget");
            var last=out.getObjects(out.getObjectsCount()-1);
            out.setContinuation(encode(SchemaObject.newBuilder().setName(last.getName()).setTable(last.getTable()).setIdentifier(last.getIdentifier()).putProperties("scope",scope).putProperties("fingerprint",fingerprint).build()));
        }
        return out.setComplete(!more).build();
    }
    private static String fingerprint(SessionRegistry.Session s,String filtered,List<String> parameters,List<String> properties,SchemaObjects.Builder out,ObjectKind kind)throws Exception {
        boolean pg=s.profile.getEngine()==Engine.POSTGRESQL;
        String checksum=checksum(s,properties),value;
        try(var statement=s.adapter.catalogStatement(s.connection,"SELECT COUNT(*),"+checksum+" FROM ("+filtered+") metadata")) {
            bind(statement,parameters);var context=io.grpc.Context.current();
            io.grpc.Context.CancellationListener listener=ignored->{try{statement.cancel();}catch(SQLException ignoredFailure){}};
            context.addListener(listener,cancellation);
            try{checkCancelled(context);try(var rows=statement.executeQuery()) {
                if(!rows.next())throw new SQLException("Metadata count unavailable");
                out.setCountAvailability(MetadataCount.AUTHORITATIVE_TOTAL).setTotalCount(rows.getLong(1));
                value=rows.getString(1)+":"+rows.getString(2);
            }}finally{context.removeListener(listener);}
        }
        return !pg&&kind==ObjectKind.ROUTINE?MetadataIdentity.digest(value,RoutineFingerprintReader.fingerprint(s,filtered,parameters)):value;
    }
    private static String checksum(SessionRegistry.Session session,List<String> properties) {
        var fields=new ArrayList<>(List.of("c","s","p","n","i","k"));fields.addAll(properties);
        return session.profile.getEngine()==Engine.POSTGRESQL?"COALESCE(bit_xor(hashtextextended(ROW(metadata.*)::text,0)),0)":"COALESCE(SUM(CRC32(CONCAT_WS(CHAR(0),"+String.join(",",fields.stream().map(session.adapter::quote).toList())+"))),0)";
    }
    /** Fixed-size per-parent evidence; no columns, definitions or values enter Java. */
    public Map<String,String> scanParents(SessionRegistry.Session view,String catalog,String schema,ObjectKind kind,long deadline)throws Exception {
        if(!MetadataNames.CHILDREN.contains(kind))throw new IllegalArgumentException("A structural child kind is required");
        var request=ExploreRequest.newBuilder().setCatalog(catalog).setSchema(schema).setKind(kind).setIntrospectionLevel(2).build();
        var query=query(view,request,true);var result=new HashMap<String,String>();long bytes=0;
        try(var statement=view.adapter.catalogStatement(view.connection,"SELECT p,COUNT(*),"+checksum(view,query.properties())+" FROM ("+query.sql()+") metadata GROUP BY p")) {
            bind(statement,query.parameters());statement.setMaxRows(MetadataSnapshot.MAX_OBJECTS+1);var context=io.grpc.Context.current();
            io.grpc.Context.CancellationListener listener=ignored->{try{statement.cancel();}catch(SQLException ignoredFailure){}};context.addListener(listener,cancellation);
            try{checkCancelled(context);try(var rows=statement.executeQuery()){while(rows.next()) {
                checkCancelled(context);if(System.nanoTime()>deadline)throw new TimeoutException("Metadata fingerprint deadline exceeded");String parent=rows.getString(1),fingerprint=rows.getString(2)+":"+rows.getString(3);
                if(parent==null||parent.length()>256||result.size()>=MetadataSnapshot.MAX_OBJECTS||(bytes+=2L*(parent.length()+fingerprint.length())+80)>8_388_608)throw new IllegalArgumentException("Metadata parent fingerprint budget exceeded");
                if(result.put(parent,fingerprint)!=null)throw new SQLException("Duplicate metadata parent fingerprint");
            }}}finally{context.removeListener(listener);}
        }
        return Map.copyOf(result);
    }
    private static int bind(PreparedStatement statement,List<String> parameters)throws SQLException {int index=1;for(String value:parameters)statement.setString(index++,value);return index;}
    private static void checkCancelled(io.grpc.Context context){if(context.isCancelled())throw new CancellationException("Metadata request cancelled");}
    private static String n(String value){return value==null?"":value;}
    private static ObjectSubtype subtype(String nativeKind){return switch(n(nativeKind)) {
        case "r","BASE TABLE"->ObjectSubtype.ORDINARY_TABLE;case "p"->ObjectSubtype.PARTITIONED_TABLE;case "f"->ObjectSubtype.FOREIGN_TABLE;
        case "v","VIEW"->ObjectSubtype.REGULAR_VIEW;case "m"->ObjectSubtype.MATERIALIZED_VIEW;case "S","SEQUENCE"->ObjectSubtype.NATIVE_SEQUENCE;
        case "FUNCTION"->ObjectSubtype.FUNCTION;case "PROCEDURE"->ObjectSubtype.PROCEDURE;default->ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED;
    };}
    private static Query query(SessionRegistry.Session s,ExploreRequest r)throws SQLException {return query(s,r,false);}
    private static Query query(SessionRegistry.Session s,ExploreRequest r,boolean allParents)throws SQLException {
        boolean pg=s.profile.getEngine()==Engine.POSTGRESQL;
        String catalog=r.getCatalog().isEmpty()?s.context.catalog():r.getCatalog();
        String schema=r.getSchema().isEmpty()?(pg?s.context.schema():catalog):r.getSchema(),table=r.getTable();
        if(pg&&!catalog.equals(s.connection.getCatalog()))throw new SQLException("Requested metadata database is not the physical connection database","08006");
        if(!pg&&!r.getSchema().isEmpty()&&!schema.equals(catalog))throw new IllegalArgumentException("MySQL/MariaDB database and schema scopes must agree");
        if(pg&&r.getKind()!=ObjectKind.CATALOG&&r.getKind()!=ObjectKind.SCHEMA)try(var statement=s.adapter.catalogStatement(s.connection,"SELECT has_schema_privilege(oid,'USAGE') FROM pg_catalog.pg_namespace WHERE nspname=?")) {
            statement.setString(1,schema);try(var rows=statement.executeQuery()){if(rows.next()&&!rows.getBoolean(1))throw new SQLException("Permission denied for metadata schema "+schema+" in database "+catalog,"42501");}
        }
        if(pg&&r.getSchema().isEmpty()&&!table.isEmpty()&&!s.context.temporarySchema().isEmpty())try(var st=s.adapter.catalogStatement(s.connection,"SELECT 1 FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=? AND c.relname=?")) {
            st.setString(1,s.context.temporarySchema());st.setString(2,table);try(var rows=st.executeQuery()){if(rows.next())schema=s.context.temporarySchema();}
        }
        String viewFingerprint=r.getKind()==ObjectKind.VIEW?"CASE WHEN TABLE_TYPE='VIEW' THEN COALESCE((SELECT SHA2(CONCAT_WS(CHAR(0),v.VIEW_DEFINITION,v.CHECK_OPTION,v.SECURITY_TYPE,v.DEFINER),256) FROM information_schema.VIEWS v WHERE BINARY v.TABLE_SCHEMA=BINARY TABLES.TABLE_SCHEMA AND BINARY v.TABLE_NAME=BINARY TABLES.TABLE_NAME),'') ELSE '' END":"''";
        String relation=pg?"SELECT current_database() c,n.nspname s,'' p,c.relname n,'' i,c.relkind::text k,c.oid::text AS \"nativeId\",c.oid::text||':'||pg_catalog.pg_relation_filenode(c.oid)::text AS \"nativeGeneration\",c.oid::text||':'||c.xmin::text||':'||md5(COALESCE(obj_description(c.oid,'pg_class'),''))||':'||COALESCE((SELECT bit_xor(hashtextextended(ROW(w.*)::text,0))::text FROM pg_catalog.pg_rewrite w WHERE w.ev_class=c.oid),'')||':'||COALESCE((SELECT md5(ROW(seq.*)::text) FROM pg_catalog.pg_sequence seq WHERE seq.seqrelid=c.oid),'') AS _version,LEFT(COALESCE(obj_description(c.oid,'pg_class'),''),2048) remarks,OCTET_LENGTH(COALESCE(obj_description(c.oid,'pg_class'),'')) AS _remarksBytes FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=? AND c.relkind ":
            "SELECT TABLE_SCHEMA c,TABLE_SCHEMA s,'' p,TABLE_NAME n,'' i,TABLE_TYPE k,'' AS nativeId,SHA2(CONCAT_WS(CHAR(0),COALESCE(CAST(CREATE_TIME AS CHAR),''),TABLE_TYPE,COALESCE(ENGINE,''),COALESCE(ROW_FORMAT,''),COALESCE(TABLE_COLLATION,''),COALESCE(CREATE_OPTIONS,''),COALESCE(TABLE_COMMENT,''),"+viewFingerprint+"),256) AS _version,LEFT(COALESCE(TABLE_COMMENT,''),2048) remarks,OCTET_LENGTH(COALESCE(TABLE_COMMENT,'')) AS _remarksBytes FROM information_schema.TABLES WHERE TABLE_SCHEMA=? AND TABLE_TYPE=";
        String parent=pg?"current_database() c,n.nspname s,t.relname p,":"TABLE_SCHEMA c,TABLE_SCHEMA s,TABLE_NAME p,";
        var query=switch(r.getKind()) {
            case CATALOG->new Query(pg?"SELECT oid::text AS \"nativeId\",datname c,'' s,'' p,datname n,'' i,'' k,(datname=current_database())::text defaultNamespace FROM pg_catalog.pg_database WHERE datallowconn":"SELECT '' AS nativeId,SCHEMA_NAME c,SCHEMA_NAME s,'' p,SCHEMA_NAME n,'' i,'' k,CAST(SCHEMA_NAME=DATABASE() AS CHAR) defaultNamespace FROM information_schema.SCHEMATA",List.of(),"defaultNamespace","nativeId");
            case SCHEMA->{if(!pg)throw new IllegalArgumentException("MySQL/MariaDB schemas are databases; enumerate catalogs");yield new Query("SELECT oid::text AS \"nativeId\",current_database() c,nspname s,'' p,nspname n,'' i,'' k,has_schema_privilege(oid,'USAGE')::text accessible,(nspname=current_schema())::text defaultNamespace FROM pg_catalog.pg_namespace",List.of(),"accessible","defaultNamespace","nativeId");}
            case TABLE,VIEW,SEQUENCE->{
                if(r.getKind()==ObjectKind.SEQUENCE&&s.profile.getEngine()==Engine.MYSQL)throw new IllegalArgumentException("MySQL has no sequence objects");
                String kinds=pg?switch(r.getKind()){case TABLE->"IN ('r','p','f')";case VIEW->"IN ('v','m')";default->"='S'";}:switch(r.getKind()){case TABLE->"'BASE TABLE'";case VIEW->"'VIEW'";default->"'SEQUENCE'";};
                var parameters=new ArrayList<>(List.of(schema));String sql=relation+kinds;
                if(!pg&&r.getKind()==ObjectKind.SEQUENCE)sql="SELECT SEQUENCE_SCHEMA c,SEQUENCE_SCHEMA s,'' p,SEQUENCE_NAME n,'' i,'SEQUENCE' k,'' nativeId,CONCAT_WS(':',DATA_TYPE,NUMERIC_PRECISION,NUMERIC_PRECISION_RADIX,NUMERIC_SCALE,START_VALUE,MINIMUM_VALUE,MAXIMUM_VALUE,INCREMENT,CYCLE_OPTION) _version,'' remarks FROM information_schema.SEQUENCES WHERE SEQUENCE_SCHEMA=?";
                if(!table.isEmpty()){sql+=pg?" AND c.relname=?":r.getKind()==ObjectKind.SEQUENCE?" AND SEQUENCE_NAME=?":" AND TABLE_NAME=?";parameters.add(table);}
                yield new Query(sql,parameters,pg?List.of("nativeId","nativeGeneration","_version","remarks","_remarksBytes"):r.getKind()==ObjectKind.SEQUENCE?List.of("nativeId","_version","remarks"):List.of("nativeId","_version","remarks","_remarksBytes"));
            }
            case ROUTINE->new Query(pg?
                "SELECT current_database() c,n.nspname s,'' p,p.proname n,p.oid::text AS \"nativeId\","+RoutineIdentity.POSTGRES_KEY+" i,CASE WHEN p.prokind='p' THEN 'PROCEDURE' ELSE 'FUNCTION' END k,pg_catalog.nameconcatoid(p.proname,p.oid) AS specificName,p.xmin::text AS _version,pg_get_function_result(p.oid) AS returnType FROM "+RoutineIdentity.POSTGRES_FROM+" WHERE n.nspname=? AND "+RoutineIdentity.POSTGRES_VISIBLE:
                "SELECT ROUTINE_SCHEMA c,ROUTINE_SCHEMA s,'' p,ROUTINE_NAME n,'' AS nativeId,"+RoutineIdentity.MYSQL_KEY+" i,ROUTINE_TYPE k,SPECIFIC_NAME AS specificName,ROUTINE_DEFINITION IS NULL AS _sourceMissing,"+RoutineFingerprintReader.nativeVersionSql()+" AS _version,DTD_IDENTIFIER AS returnType FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA=?",List.of(schema),"nativeId","specificName","_version","returnType");
            case TYPE->{
                if(!pg)throw new UnsupportedOperationException("MySQL/MariaDB enum and set definitions belong to column-native types, without standalone type objects");
                yield new Query("SELECT current_database() c,n.nspname s,'' p,t.typname n,'' i,'' k,t.oid::text AS \"nativeId\",t.typtype::text AS \"nativeTypeKind\",format_type(t.typbasetype,t.typtypmod) AS \"baseType\",t.typnotnull::text AS \"notNull\",COALESCE(t.typdefault,'') AS type_default,t.typelem::text AS \"elementType\",t.typarray::text AS \"arrayType\",COALESCE(coll.collname,'') collation,t.xmin::text||':'||COALESCE((SELECT bit_xor(hashtextextended(ROW(e.*)::text,0))::text FROM pg_catalog.pg_enum e WHERE e.enumtypid=t.oid),'')||':'||COALESCE((SELECT bit_xor(hashtextextended(ROW(d.*)::text,0))::text FROM pg_catalog.pg_constraint d WHERE d.contypid=t.oid),'') AS _version FROM pg_catalog.pg_type t JOIN pg_catalog.pg_namespace n ON n.oid=t.typnamespace LEFT JOIN pg_catalog.pg_collation coll ON coll.oid=t.typcollation WHERE n.nspname=? AND t.typcategory<>'A' AND (t.typtype<>'c' OR EXISTS(SELECT 1 FROM pg_catalog.pg_class r WHERE r.oid=t.typrelid AND r.relkind='c')) AND has_type_privilege(t.oid,'USAGE')",List.of(schema),"nativeId","nativeTypeKind","baseType","notNull","type_default","elementType","arrayType","collation","_version");
            }
            case COLUMN->{
                if(!allParents){requireTable(table);if(r.getIntrospectionLevel()!=1)preflightColumns(s,schema,table);}
                yield new Query(pg?"SELECT "+parent+"a.attname n,a.attrelid::text||':'||a.attnum::text AS \"nativeId\",a.xmin::text||':'||COALESCE(d.xmin::text,'')||':'||md5(COALESCE(col_description(t.oid,a.attnum),'')) AS _version,'' i,'' k,format_type(a.atttypid,a.atttypmod) type,CASE WHEN a.attnotnull THEN 'NO' ELSE 'YES' END nullable,LEFT(COALESCE(pg_get_expr(d.adbin,d.adrelid),''),8192) AS column_default,OCTET_LENGTH(COALESCE(pg_get_expr(d.adbin,d.adrelid),'')) AS _defaultBytes,a.attnum::text ordinal,a.attgenerated::text generation_kind,a.attidentity::text AS \"autoIncrement\" FROM pg_catalog.pg_attribute a JOIN pg_catalog.pg_class t ON t.oid=a.attrelid JOIN pg_catalog.pg_namespace n ON n.oid=t.relnamespace LEFT JOIN pg_catalog.pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum WHERE n.nspname=? AND t.relname=? AND a.attnum>0 AND NOT a.attisdropped":
                    "SELECT "+parent+"COLUMN_NAME n,'' AS nativeId,SHA2(CONCAT_WS(CHAR(0),COALESCE(COLUMN_COMMENT,''),COALESCE(COLLATION_NAME,''),COALESCE(CHARACTER_SET_NAME,''),COALESCE(GENERATION_EXPRESSION,''),COALESCE(COLUMN_DEFAULT,''),COLUMN_TYPE,IS_NULLABLE,EXTRA,ORDINAL_POSITION),256) AS _version,'' i,'' k,COLUMN_TYPE type,IS_NULLABLE nullable,LEFT(COALESCE(COLUMN_DEFAULT,''),8192) AS column_default,OCTET_LENGTH(COALESCE(COLUMN_DEFAULT,'')) AS _defaultBytes,ORDINAL_POSITION ordinal,EXTRA generation_kind,CASE WHEN EXTRA LIKE '%auto_increment%' THEN 'YES' ELSE 'NO' END autoIncrement FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=? AND TABLE_NAME=?",List.of(schema,table),"nativeId","_version","type","nullable","column_default","_defaultBytes","ordinal","generation_kind","autoIncrement");
            }
            // Binary keys separate native spellings; retain raw group keys for
            // returned identifiers and MySQL ONLY_FULL_GROUP_BY validation.
            case INDEX->{if(!allParents)requireTable(table);yield new Query(pg?
                "SELECT "+parent+"idx.relname n,'' i,'' k,(NOT x.indisunique)::text AS \"nonUnique\",x.indnatts::text AS \"columnCount\",LEFT(parts.columns,8192) index_columns,OCTET_LENGTH(parts.columns) AS \"_columnBytes\",'"+NativeIndexReader.FINGERPRINT_VERSION+":'||x.xmin::text||':'||idx.xmin::text AS _version FROM pg_catalog.pg_index x JOIN pg_catalog.pg_class t ON t.oid=x.indrelid JOIN pg_catalog.pg_class idx ON idx.oid=x.indexrelid JOIN pg_catalog.pg_namespace n ON n.oid=t.relnamespace CROSS JOIN LATERAL (SELECT string_agg(pg_get_indexdef(x.indexrelid,position,true),', ' ORDER BY position) columns FROM generate_series(1,x.indnatts) position) parts WHERE n.nspname=? AND t.relname=?":
                "SELECT "+parent+"INDEX_NAME n,'' i,'' k,MIN(NON_UNIQUE) nonUnique,COUNT(*) columnCount,CONCAT_WS(':','"+NativeIndexReader.FINGERPRINT_VERSION+"',COALESCE(SUM(CRC32(CONCAT_WS(CHAR(0),COLUMN_NAME,SEQ_IN_INDEX,NON_UNIQUE,COLLATION,SUB_PART,INDEX_TYPE,INDEX_COMMENT))),0)"+(s.profile.getEngine()==Engine.MYSQL?",COALESCE(SUM(CRC32(CONCAT_WS(CHAR(0),COALESCE(EXPRESSION,''),IS_VISIBLE))),0)":",COALESCE(SUM(CRC32(COALESCE(IGNORED,''))),0)")+") _version,"+mysqlColumns("COLUMN_NAME","SEQ_IN_INDEX")+" index_columns,"+mysqlColumnBytes("COLUMN_NAME")+" _columnBytes FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=? AND TABLE_NAME=? GROUP BY BINARY TABLE_SCHEMA,BINARY TABLE_NAME,BINARY INDEX_NAME,TABLE_SCHEMA,TABLE_NAME,INDEX_NAME",List.of(schema,table),"nonUnique","columnCount","index_columns","_columnBytes","_version");}
            case CONSTRAINT->{if(!allParents)requireTable(table);yield new Query(pg?
                "SELECT "+parent+"con.conname n,'' i,'' k,con.oid::text AS \"nativeId\",con.contype::text type,con.xmin::text AS _version FROM pg_catalog.pg_constraint con JOIN pg_catalog.pg_class t ON t.oid=con.conrelid JOIN pg_catalog.pg_namespace n ON n.oid=t.relnamespace WHERE n.nspname=? AND t.relname=?":
                "SELECT "+parent+"CONSTRAINT_NAME n,CONSTRAINT_TYPE i,'' k,CONSTRAINT_TYPE type,CONCAT(COALESCE((SELECT SUM(CRC32(CONCAT_WS(CHAR(0),k.COLUMN_NAME,k.ORDINAL_POSITION,k.REFERENCED_TABLE_SCHEMA,k.REFERENCED_TABLE_NAME,k.REFERENCED_COLUMN_NAME))) FROM information_schema.KEY_COLUMN_USAGE k WHERE (tc.CONSTRAINT_TYPE='FOREIGN KEY' AND k.REFERENCED_TABLE_NAME IS NOT NULL OR tc.CONSTRAINT_TYPE IN ('PRIMARY KEY','UNIQUE') AND k.REFERENCED_TABLE_NAME IS NULL) AND BINARY k.CONSTRAINT_SCHEMA=BINARY tc.CONSTRAINT_SCHEMA AND BINARY k.TABLE_NAME=BINARY tc.TABLE_NAME AND BINARY k.CONSTRAINT_NAME=BINARY tc.CONSTRAINT_NAME),0),':',COALESCE((SELECT CRC32(cc.CHECK_CLAUSE) FROM information_schema.CHECK_CONSTRAINTS cc WHERE tc.CONSTRAINT_TYPE='CHECK' AND BINARY cc.CONSTRAINT_SCHEMA=BINARY tc.CONSTRAINT_SCHEMA AND BINARY cc.CONSTRAINT_NAME=BINARY tc.CONSTRAINT_NAME"+(s.profile.getEngine()==Engine.MARIADB?" AND BINARY cc.TABLE_NAME=BINARY tc.TABLE_NAME":"")+"),0)) AS _version FROM information_schema.TABLE_CONSTRAINTS tc WHERE TABLE_SCHEMA=? AND TABLE_NAME=?",List.of(schema,table),pg?List.of("nativeId","type","_version"):List.of("type","_version"));}
            case FOREIGN_KEY->{if(!allParents)requireTable(table);yield new Query(pg?
                "SELECT "+parent+"con.conname n,'' i,'' k,rn.nspname AS \"referencedSchema\",rt.relname AS \"referencedTable\",con.xmin::text AS _version,cardinality(con.conkey)::text AS \"columnCount\","+pgColumns("con.conkey","t.oid")+" index_columns,"+pgColumns("con.confkey","rt.oid")+" reference_columns FROM pg_catalog.pg_constraint con JOIN pg_catalog.pg_class t ON t.oid=con.conrelid JOIN pg_catalog.pg_namespace n ON n.oid=t.relnamespace JOIN pg_catalog.pg_class rt ON rt.oid=con.confrelid JOIN pg_catalog.pg_namespace rn ON rn.oid=rt.relnamespace WHERE n.nspname=? AND t.relname=? AND con.contype='f'":
                "SELECT "+parent+"CONSTRAINT_NAME n,'' i,'' k,MIN(REFERENCED_TABLE_SCHEMA) referencedSchema,MIN(REFERENCED_TABLE_NAME) referencedTable,COALESCE((SELECT CONCAT(rc.UPDATE_RULE,':',rc.DELETE_RULE) FROM information_schema.REFERENTIAL_CONSTRAINTS rc WHERE BINARY rc.CONSTRAINT_SCHEMA=BINARY KEY_COLUMN_USAGE.CONSTRAINT_SCHEMA AND BINARY rc.TABLE_NAME=BINARY KEY_COLUMN_USAGE.TABLE_NAME AND BINARY rc.CONSTRAINT_NAME=BINARY KEY_COLUMN_USAGE.CONSTRAINT_NAME),'') AS _version,COUNT(*) columnCount,"+mysqlColumns("COLUMN_NAME","ORDINAL_POSITION")+" index_columns,"+mysqlColumns("REFERENCED_COLUMN_NAME","ORDINAL_POSITION")+" reference_columns,"+mysqlColumnBytes("COLUMN_NAME")+" _columnBytes FROM information_schema.KEY_COLUMN_USAGE WHERE TABLE_SCHEMA=? AND TABLE_NAME=? AND REFERENCED_TABLE_NAME IS NOT NULL GROUP BY BINARY TABLE_SCHEMA,BINARY TABLE_NAME,BINARY CONSTRAINT_SCHEMA,BINARY CONSTRAINT_NAME,TABLE_SCHEMA,TABLE_NAME,CONSTRAINT_SCHEMA,CONSTRAINT_NAME",List.of(schema,table),pg?List.of("referencedSchema","referencedTable","columnCount","index_columns","reference_columns"):List.of("referencedSchema","referencedTable","_version","columnCount","index_columns","reference_columns","_columnBytes"));}
            case TRIGGER->{var parameters=new ArrayList<>(List.of(schema));if(!table.isEmpty())parameters.add(table);yield new Query(pg?
                "SELECT "+parent+"g.tgname n,'' i,'' k,g.xmin::text AS _version,concat_ws(', ',CASE WHEN (g.tgtype & 4)>0 THEN 'INSERT' END,CASE WHEN (g.tgtype & 8)>0 THEN 'DELETE' END,CASE WHEN (g.tgtype & 16)>0 THEN 'UPDATE' END,CASE WHEN (g.tgtype & 32)>0 THEN 'TRUNCATE' END) event FROM pg_catalog.pg_trigger g JOIN pg_catalog.pg_class t ON t.oid=g.tgrelid JOIN pg_catalog.pg_namespace n ON n.oid=t.relnamespace WHERE n.nspname=? AND NOT g.tgisinternal"+(table.isEmpty()?"":" AND t.relname=?"):
                "SELECT TRIGGER_SCHEMA c,TRIGGER_SCHEMA s,EVENT_OBJECT_TABLE p,TRIGGER_NAME n,'' i,'' k,SHA2(CONCAT_WS(CHAR(0),ACTION_STATEMENT,ACTION_TIMING,ACTION_ORDER,ACTION_ORIENTATION,SQL_MODE,DEFINER,CHARACTER_SET_CLIENT,COLLATION_CONNECTION,DATABASE_COLLATION),256) AS _version,EVENT_MANIPULATION event FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA=?"+(table.isEmpty()?"":" AND EVENT_OBJECT_TABLE=?"),parameters,"event","_version");}
            default->throw new IllegalArgumentException("Unsupported metadata object kind");
        };
        if(allParents) {
            String sql=query.sql.replace(" AND t.relname=?", "").replace(" AND TABLE_NAME=?", "");
            query=new Query(sql,List.of(schema),query.properties);
        }
        if(r.getIntrospectionLevel()==1){
            var retained=query.properties.stream().filter(property->(Set.of("nativeId","nativeGeneration","_version").contains(property)||r.getKind()==ObjectKind.CONSTRAINT&&property.equals("type")||r.getKind()==ObjectKind.ROUTINE&&property.equals("specificName"))).toList();
            query=new Query("SELECT c,s,p,n,i,k"+(retained.isEmpty()?"":","+String.join(",",retained.stream().map(s.adapter::quote).toList()))+" FROM ("+query.sql+") metadata_names",query.parameters,retained);
        }
        if(pg)return query;
        String sql=query.sql;
        for(String field:List.of("TABLE_SCHEMA","TABLE_NAME","ROUTINE_SCHEMA","ROUTINE_NAME","TRIGGER_SCHEMA","EVENT_OBJECT_TABLE","SEQUENCE_SCHEMA","SEQUENCE_NAME"))sql=sql.replace(field+"=?","BINARY "+field+"=BINARY ?");
        return new Query(sql,query.parameters,query.properties);
    }
    private static void requireTable(String table){if(table.isEmpty())throw new IllegalArgumentException("Table required");}
    private static String pgColumns(String keys,String table){return "(SELECT string_agg(quote_ident(a.attname),', ' ORDER BY key.position) FROM unnest("+keys+") WITH ORDINALITY key(number,position) JOIN pg_catalog.pg_attribute a ON a.attrelid="+table+" AND a.attnum=key.number)";}
    private static String mysqlQuotedColumn(String name){return "CONCAT(CHAR(96),REPLACE("+name+",CHAR(96),CONCAT(CHAR(96),CHAR(96))),CHAR(96))";}
    private static String mysqlColumns(String name,String order){return "GROUP_CONCAT("+mysqlQuotedColumn(name)+" ORDER BY "+order+" SEPARATOR ', ')";}
    private static String mysqlColumnBytes(String name){return "GREATEST(0,COALESCE(SUM(OCTET_LENGTH("+mysqlQuotedColumn(name)+")+2),0)-2)";}
    private static String digest(String text)throws GeneralSecurityException{return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(text.getBytes(StandardCharsets.UTF_8)));}
    private byte[] sign(byte[] bytes)throws GeneralSecurityException {var mac=Mac.getInstance("HmacSHA256");mac.init(new SecretKeySpec(continuationKey,"HmacSHA256"));return mac.doFinal(bytes);}
    private String encode(SchemaObject token)throws Exception {
        byte[] data=token.toByteArray();if(data.length>RoutineIdentity.CONTINUATION_BYTES-32)throw new IllegalArgumentException("Metadata continuation identity exceeds its budget");
        byte[] signed=Arrays.copyOf(data,data.length+32);System.arraycopy(sign(data),0,signed,data.length,32);return Base64.getUrlEncoder().withoutPadding().encodeToString(signed);
    }
    private SchemaObject decode(String encoded,String scope)throws Exception {
        try {
            byte[] signed=Base64.getUrlDecoder().decode(encoded);
            if(signed.length<32||signed.length>RoutineIdentity.CONTINUATION_BYTES)throw new IllegalArgumentException("Invalid metadata continuation");
            byte[] data=Arrays.copyOf(signed,signed.length-32);
            if(!MessageDigest.isEqual(sign(data),Arrays.copyOfRange(signed,data.length,signed.length)))throw new IllegalArgumentException("Metadata continuation is stale or belongs to another backend");
            var token=SchemaObject.parseFrom(data);
            if(!token.getPropertiesOrDefault("scope","").equals(scope))throw new IllegalArgumentException("Metadata continuation belongs to another scope or revision");
            return token;
        }catch(com.google.protobuf.InvalidProtocolBufferException|IllegalArgumentException invalid){throw new ContinuationFailure();}
    }
    // JDBC defaults must be admitted before materializing them.
    static void preflightColumns(SessionRegistry.Session session,String schema,String table)throws SQLException {
        String scope=session.profile.getEngine()==Engine.POSTGRESQL?"TABLE_SCHEMA=? AND TABLE_NAME=?":"BINARY TABLE_SCHEMA=BINARY ? AND BINARY TABLE_NAME=BINARY ?";
        try(var statement=session.adapter.catalogStatement(session.connection,"SELECT COUNT(*),COALESCE(SUM(OCTET_LENGTH(COALESCE(COLUMN_DEFAULT,''))+OCTET_LENGTH(COLUMN_NAME)+OCTET_LENGTH(DATA_TYPE)),0),COALESCE(MAX(OCTET_LENGTH(COLUMN_DEFAULT)),0) FROM information_schema.COLUMNS WHERE "+scope)) {
            statement.setString(1,schema);statement.setString(2,table);
            try(var rows=statement.executeQuery()) {
                if(!rows.next())throw new SQLException("Column resource inspection unavailable");
                if(rows.getLong(1)>2048||rows.getLong(2)>4_194_304||rows.getLong(3)>1_048_576)throw new MetadataLimit();
            }
        }
    }
}
