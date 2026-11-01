package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.Explorer;
import io.busystack.busydata.sessions.SessionRegistry;
import java.sql.SQLException;
import java.util.*;
import java.util.concurrent.*;

/** Bounded two-stage refresh: fingerprint scan, then details only where changed. */
public final class MetadataRefresh {
    private record Relation(String catalog,String schema,String table){}
    private final Explorer adapter;
    private final MetadataPlatform platform;
    private final long programDeadline;
    private final IntrospectionLevel requestedLevel;
    private MetadataPlatform.RefreshReservation reservation;
    public MetadataRefresh(Explorer adapter){this(adapter,Long.MAX_VALUE);}
    public MetadataRefresh(Explorer adapter,long deadline){this(adapter,deadline,null,null);}
    public MetadataRefresh(Explorer adapter,long deadline,MetadataPlatform.RefreshReservation reservation){this(adapter,deadline,reservation,null);}
    private MetadataRefresh(Explorer adapter,long deadline,MetadataPlatform.RefreshReservation reservation,IntrospectionLevel level){this.adapter=adapter;platform=adapter.metadata();programDeadline=Math.min(deadline,System.nanoTime()+TimeUnit.SECONDS.toNanos(30));this.reservation=reservation;requestedLevel=level;}
    public MetadataRefresh atLevel(IntrospectionLevel level){return new MetadataRefresh(adapter,programDeadline,reservation,level);}
    private void reserve(SessionRegistry.Session session)throws Exception {check(programDeadline);if(reservation==null)reservation=platform.reserveRefresh(session);platform.checkRefreshReservation(session,reservation);}
    public MetadataSnapshot context(SessionRegistry.Session session,MetadataPlatform.RefreshMode mode)throws Exception {
        reserve(session);
        var config=platform.configuration(session);var scopes=new ArrayList<MetadataScope>();
        var catalogs=config.includedCatalogs().isEmpty()?Set.of(session.context.catalog()):config.includedCatalogs();
        for(String catalog:catalogs) {
            if(catalog.isEmpty())continue;
            var schemas=session.profile.getEngine()!=Engine.POSTGRESQL?List.of(catalog):config.includedSchemas().isEmpty()?(session.context.searchPath().isEmpty()?List.of(session.context.schema()):session.context.searchPath()):List.copyOf(config.includedSchemas());
            for(String schema:schemas)if(!schema.isEmpty()&&!schema.equals("pg_temp")&&!schema.startsWith("pg_temp_"))for(ObjectKind kind:List.of(ObjectKind.TABLE,ObjectKind.VIEW,ObjectKind.ROUTINE,ObjectKind.SEQUENCE,ObjectKind.TYPE))
                if(!(kind==ObjectKind.SEQUENCE&&session.profile.getEngine()==Engine.MYSQL)&&!(kind==ObjectKind.TYPE&&session.profile.getEngine()!=Engine.POSTGRESQL)&&config.permits(catalog,schema,kind,""))scopes.add(new MetadataScope(catalog,schema,"",kind));
        }
        return refresh(session,mode,scopes);
    }
    public MetadataSnapshot fragment(SessionRegistry.Session session,String catalog,String schema,String name,ObjectKind kind)throws Exception {
        reserve(session);
        catalog=catalog.isEmpty()?session.context.catalog():catalog;schema=schema.isEmpty()?(session.profile.getEngine()==Engine.POSTGRESQL?session.context.schema():catalog):schema;
        if(catalog.isEmpty()||schema.isEmpty())throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.UNAVAILABLE);
        if(session.profile.getEngine()==Engine.POSTGRESQL&&(schema.equals("pg_temp")||schema.startsWith("pg_temp_"))){if(!catalog.equals(session.context.catalog())||!schema.equals("pg_temp")&&!schema.equals(session.context.temporarySchema()))throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.INVALID_OWNER);if(!session.lock.tryLock())throw new IllegalStateException("Temporary metadata owner is busy");try{return adapter.refreshSessionOverlay(session);}finally{session.lock.unlock();}}
        var baseline=platform.publishedSnapshot(session);var scopes=new ArrayList<MetadataScope>();
        scopes.add(new MetadataScope(catalog,schema,"",kind,name,true,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED));
        if(kind==ObjectKind.TABLE||kind==ObjectKind.VIEW) {
            for(ObjectKind child:List.of(ObjectKind.COLUMN,ObjectKind.INDEX,ObjectKind.CONSTRAINT,ObjectKind.FOREIGN_KEY,ObjectKind.TRIGGER))scopes.add(new MetadataScope(catalog,schema,name,child));
            for(var incoming:baseline.incoming(catalog,schema,name)) {
                var identity=incoming.identity();for(ObjectKind child:List.of(ObjectKind.FOREIGN_KEY,ObjectKind.CONSTRAINT,ObjectKind.COLUMN))scopes.add(new MetadataScope(identity.catalog(),identity.schema(),identity.parent(),child));
                scopes.add(new MetadataScope(identity.catalog(),identity.schema(),"",ObjectKind.TABLE,identity.parent(),true,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED));
            }
            final String nativeCatalog=catalog,nativeSchema=schema;
            var incoming=session.metadata(catalog,view->{reserve(session);try(var acquisition=new MetadataReadScope(view.connection,programDeadline)){var found=NativeStructureReader.referencingRelations(view,nativeCatalog,nativeSchema,name);acquisition.check();return found;}});
            for(var relation:incoming)if(platform.configuration(session).permits(relation.catalog(),relation.schema(),ObjectKind.FOREIGN_KEY,relation.table())) {
                scopes.add(new MetadataScope(relation.catalog(),relation.schema(),relation.table(),ObjectKind.FOREIGN_KEY));
                scopes.add(new MetadataScope(relation.catalog(),relation.schema(),relation.table(),ObjectKind.COLUMN));
                scopes.add(new MetadataScope(relation.catalog(),relation.schema(),"",ObjectKind.TABLE,relation.table(),true,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED));
            }
        }
        var names=new LinkedHashSet<MetadataScope>();
        if(kind==ObjectKind.TABLE||kind==ObjectKind.VIEW)for(var cached:baseline.coverage().keySet())
            if((cached.kind()==ObjectKind.TABLE||cached.kind()==ObjectKind.VIEW)&&cached.parent().isEmpty()&&!cached.exactName()&&cached.signature().isEmpty()&&cached.catalog().equals(catalog)&&cached.schema().equals(schema)&&name.toLowerCase(Locale.ROOT).contains(cached.search().toLowerCase(Locale.ROOT)))names.add(cached);
        var primary=new HashSet<Relation>();
        for(var scope:scopes)if(scope.kind()==ObjectKind.TABLE&&scope.parent().isEmpty()&&scope.exactName())primary.add(new Relation(scope.catalog(),scope.schema(),scope.search()));
        var dependencies=new HashSet<Relation>();
        for(var source:primary)for(var relationship:baseline.outgoing(source.catalog(),source.schema(),source.table()))dependency(platform.configuration(session),relationship.properties(),dependencies);
        var requested=new ArrayList<>(names);requested.addAll(scopes);for(var target:dependencies)requested.addAll(dependencyScopes(target));
        return refresh(session,MetadataPlatform.RefreshMode.FRAGMENT,requested,names,Set.copyOf(primary),dependencies);
    }
    public MetadataSnapshot refresh(SessionRegistry.Session session,MetadataPlatform.RefreshMode mode,List<MetadataScope> requested)throws Exception {
        return refresh(session,mode,requested,Set.of(),Set.of(),new HashSet<>());
    }
    private MetadataSnapshot refresh(SessionRegistry.Session session,MetadataPlatform.RefreshMode mode,List<MetadataScope> requested,Set<MetadataScope> names,Set<Relation> primary,Set<Relation> dependencies)throws Exception {
        reserve(session);
        try(var admission=platform.admitAcquisition()){return refreshAdmitted(session,mode,requested,names,primary,dependencies,admission);}
    }
    private MetadataSnapshot refreshAdmitted(SessionRegistry.Session session,MetadataPlatform.RefreshMode mode,List<MetadataScope> requested,Set<MetadataScope> names,Set<Relation> primary,Set<Relation> dependencies,MetadataPlatform.AcquisitionAdmission admission)throws Exception {
        long started=System.nanoTime(),deadline=programDeadline,revision=reservation.revision(),context=reservation.contextRevision();
        if(requested.isEmpty()){platform.recordDiagnostics(session,reservation,new MetadataPlatform.RefreshDiagnostics(mode,0,0,0,0,0,"No visible configured resolution namespace; existing scopes retained"));return platform.capture(session);}
        var before=platform.publishedSnapshot(session);var config=platform.configuration(session);
        var branches=new LinkedHashMap<MetadataScope,MetadataPlatform.Branch>();var counts=new long[3];var routineSources=new long[2];
        var grouped=new LinkedHashMap<String,List<MetadataScope>>();
        for(var scope:requested)if(config.permits(scope.catalog(),scope.schema(),scope.kind(),scope.exactName()?scope.search():""))grouped.computeIfAbsent(scope.catalog(),k->new ArrayList<>()).add(scope);
        final IdentifierRules[] rules={null};
        var seen=new HashSet<MetadataScope>();
        while(!grouped.isEmpty()) {
            reserve(session);String currentCatalog=grouped.keySet().iterator().next();var pending=grouped.remove(currentCatalog);pending.removeIf(seen::contains);if(pending.isEmpty())continue;
            session.metadata(currentCatalog,view->{
                reserve(session);
                try(var acquisition=new MetadataReadScope(view.connection,deadline)){try{
                var acquiredRules=NativeStructureReader.rules(view,rules[0]==null?before.rules():rules[0],deadline);
                if(rules[0]!=null&&!rules[0].fingerprint().equals(acquiredRules.fingerprint()))throw new SQLException("Native identifier evidence changed across metadata scopes","HY000");
                rules[0]=acquiredRules;admission.reserveRules(acquiredRules);var queue=new ArrayDeque<>(pending);var evidence=new HashMap<String,MetadataNames.Evidence>();
                while(!queue.isEmpty()) {
                    check(deadline);var scope=queue.removeFirst();if(!seen.add(scope))continue;
                    boolean namesOnly=names.contains(scope);
                    var level=namesOnly?IntrospectionLevel.NAMES:requestedLevel==null?config.level(scope.catalog(),scope.schema()):requestedLevel;if(level==IntrospectionLevel.NAMES&&!scope.parent().isEmpty())continue;
                    var request=ExploreRequest.newBuilder().setKind(scope.kind()).setCatalog(scope.catalog()).setSchema(scope.schema()).setTable(scope.parent()).setSearch(scope.search())
                        .setExactName(scope.exactName()).setIdentifier(scope.signature()).setSubtype(scope.subtype()).setIntrospectionLevel(level.number()).setLimit(500).build();
                    var old=before.coverage(scope).orElse(null);List<SchemaObject> values;String fingerprint;boolean reused=false;
                    try {
                        if(scope.kind()==ObjectKind.ROUTINE){
                            java.util.function.Predicate<SchemaObject> permitted=identity->config.permits(identity.getCatalog(),identity.getSchema(),ObjectKind.ROUTINE,identity.getName());
                            var scan=adapter.scanRoutineBranch(view,request,deadline,permitted);counts[0]+=1+scan.count();routineSources[0]+=scan.nativeSourceReads();routineSources[1]+=scan.sourceBytes();
                            var routineLevel=level;
                            var staged=routineBranches(before,rules[0],scope,level,mode,config,scan.evidence(),scan.fingerprint(),revision,context,(item,point)->{
                                check(deadline);
                                var exact=request.toBuilder().setSearch(item.identity().getName()).setExactName(true).setIdentifier(item.identity().getIdentifier()).setSubtype(item.identity().getSubtype()).build();
                                var details=routineLevel==IntrospectionLevel.NAMES?List.of(item.identity()):adapter.fetchBranch(view,exact,deadline);
                                if(details.size()!=1||!routineIdentity(before,rules[0],details.getFirst()).equals(routineIdentity(before,rules[0],item.identity())))throw new Explorer.ContinuationFailure();
                                var state=routineCoverage(point,routineLevel,MetadataState.AVAILABLE,item.fingerprint(),revision,context,"");
                                return platform.normalizedBranch(session,rules[0],details,state,before,admission).normalized().getFirst();
                            });
                            var verification=adapter.scanRoutineBranch(view,request,deadline,permitted);counts[0]+=1+verification.count();routineSources[0]+=verification.nativeSourceReads();routineSources[1]+=verification.sourceBytes();
                            if(scan.count()!=verification.count()||!scan.fingerprint().equals(verification.fingerprint())||!scan.evidence().equals(verification.evidence()))throw new Explorer.ContinuationFailure();
                            branches.put(scope,staged.parent());branches.putAll(staged.points());counts[1]+=staged.fetchedScopes();counts[2]+=staged.fetchedObjects();
                            if(branches.size()>100_000||counts[2]>MetadataSnapshot.MAX_OBJECTS)throw new IllegalArgumentException("Metadata refresh scope/object budget exceeded");
                            continue;
                        }
                        MetadataNames.Evidence beforeEvidence=null;
                        if(namesOnly){beforeEvidence=evidence.get(scope.schema());if(beforeEvidence==null){beforeEvidence=scanEvidence(view,scope,config,deadline);counts[0]+=beforeEvidence.requestedKinds().size()+(view.profile.getEngine()==Engine.POSTGRESQL?1:0);evidence.put(scope.schema(),beforeEvidence);}}
                        var scan=adapter.scanBranch(view,request);counts[0]++;String rawFingerprint=scan.fingerprint();fingerprint=rawFingerprint;
                        boolean physicalScan=scope.kind()==ObjectKind.TABLE&&level.includes(IntrospectionLevel.STRUCTURE)&&view.profile.getEngine()!=Engine.POSTGRESQL;
                        if(physicalScan){var identities=before.select(scope).stream().map(before::projection).toList();fingerprint=MetadataIdentity.digest(rawFingerprint,NativeRelationReader.fingerprint(NativeRelationReader.enrich(view,identities)));counts[0]++;}
                        if(mode==MetadataPlatform.RefreshMode.INCREMENTAL&&before.rules().fingerprint().equals(rules[0].fingerprint())&&old!=null&&old.level().includes(level)&&old.fingerprint().equals(fingerprint)){values=scope.kind()==ObjectKind.TABLE||scope.kind()==ObjectKind.VIEW?before.select(scope).stream().map(before::projection).toList():List.of();level=old.level();reused=true;}
                        else {values=adapter.fetchBranch(view,request,deadline);counts[1]++;counts[2]+=values.size();if(!rawFingerprint.equals(adapter.scanBranch(view,request).fingerprint()))throw new Explorer.ContinuationFailure();if(physicalScan){fingerprint=MetadataIdentity.digest(rawFingerprint,NativeRelationReader.fingerprint(values));if(!NativeRelationReader.fingerprint(values).equals(NativeRelationReader.fingerprint(NativeRelationReader.enrich(view,values))))throw new Explorer.ContinuationFailure();}}
                        var coverage=new MetadataCoverage(scope,level,MetadataState.AVAILABLE,true,fingerprint,revision,context,System.currentTimeMillis(),"");
                        if(namesOnly) {
                            if(scope.kind()==ObjectKind.TABLE)values=NativeRelationReader.names(view,values);
                            verifyEvidence(view,scope,beforeEvidence,deadline);counts[0]+=beforeEvidence.requestedKinds().size()+(view.profile.getEngine()==Engine.POSTGRESQL?1:0);
                            if(!rawFingerprint.equals(adapter.scanBranch(view,request).fingerprint()))throw new Explorer.ContinuationFailure();counts[0]++;
                            if(scope.kind()==ObjectKind.TABLE){var verification=NativeRelationReader.names(view,values);if(!nativeNamesFingerprint(values).equals(nativeNamesFingerprint(verification)))throw new Explorer.ContinuationFailure();}
                            branches.put(scope,platform.reconciledNamesBranch(session,rules[0],values,coverage,before,beforeEvidence,branches,admission,deadline));
                        }else branches.put(scope,reused?MetadataPlatform.Branch.reused(coverage):platform.normalizedBranch(session,rules[0],values,coverage,before,admission));
                    }catch(MetadataLimit limited) {
                        branches.put(scope,new MetadataPlatform.Branch(List.of(),new MetadataCoverage(scope,level,MetadataState.LIMITED,false,"",revision,context,old==null?0:old.refreshedUnixMs(),"Native JDBC metadata resource budget exceeded; narrow or reduce the object metadata")));continue;
                    }catch(SQLException denied) {
                        String state=Objects.toString(denied.getSQLState(),"");if(!state.startsWith("42"))throw denied;
                        branches.put(scope,new MetadataPlatform.Branch(List.of(),new MetadataCoverage(scope,level,MetadataState.DENIED,false,"",revision,context,old==null?0:old.refreshedUnixMs(),"Metadata access unavailable; SQLSTATE "+state)));continue;
                    }
                    if(scope.kind()==ObjectKind.FOREIGN_KEY&&primary.contains(new Relation(scope.catalog(),scope.schema(),scope.parent())))for(var relationship:values) {
                        var found=new HashSet<Relation>();dependency(config,relationship.getPropertiesMap(),found);
                        for(var target:found)if(dependencies.add(target))for(var required:dependencyScopes(target))if(!seen.contains(required)) {
                            if(target.catalog().equals(currentCatalog))queue.add(required);else grouped.computeIfAbsent(target.catalog(),ignored->new ArrayList<>()).add(required);
                        }
                    }
                    boolean dependencyOnly=scope.kind()==ObjectKind.TABLE&&scope.exactName()&&dependencies.contains(new Relation(scope.catalog(),scope.schema(),scope.search()))&&!primary.contains(new Relation(scope.catalog(),scope.schema(),scope.search()));
                    if((scope.kind()==ObjectKind.TABLE||scope.kind()==ObjectKind.VIEW)&&level.includes(IntrospectionLevel.STRUCTURE)&&!dependencyOnly) {
                        var relationNames=new HashSet<String>();
                        for(var relation:values) {
                            relationNames.add(relation.getName());
                            for(ObjectKind child:List.of(ObjectKind.COLUMN,ObjectKind.INDEX,ObjectKind.CONSTRAINT,ObjectKind.FOREIGN_KEY,ObjectKind.TRIGGER))
                                if(config.permits(scope.catalog(),scope.schema(),child,relation.getName()))queue.add(new MetadataScope(scope.catalog(),scope.schema(),relation.getName(),child));
                        }
                        for(var previous:before.select(scope))if(!relationNames.contains(previous.identity().name()))for(ObjectKind child:List.of(ObjectKind.COLUMN,ObjectKind.INDEX,ObjectKind.CONSTRAINT,ObjectKind.FOREIGN_KEY,ObjectKind.TRIGGER)) {
                            var removed=new MetadataScope(scope.catalog(),scope.schema(),previous.identity().name(),child);
                            branches.put(removed,new MetadataPlatform.Branch(List.of(),new MetadataCoverage(removed,level,MetadataState.AVAILABLE,true,"deleted",revision,context,System.currentTimeMillis(),"")));
                        }
                    }
                    if(branches.size()>100_000||counts[2]>MetadataSnapshot.MAX_OBJECTS)throw new IllegalArgumentException("Metadata refresh scope/object budget exceeded");
                }
                acquisition.check();return null;
                }catch(Exception failure){acquisition.check();throw failure;}}
            });
        }
        check(deadline);
        if(session.revision!=revision||session.contextRevision!=context||session.state==TransactionState.DISCONNECTED||session.state==TransactionState.UNKNOWN_TRANSACTION)throw new IllegalStateException("Metadata source owner changed during refresh");
        namesBeforeDetails(branches,names);
        return platform.publish(session,reservation,rules[0]==null?before.rules():rules[0],branches,admission,programDeadline,snapshot->new MetadataPlatform.RefreshDiagnostics(mode,counts[0],counts[1],counts[2],Math.max(0,before.identities().size()-snapshot.identities().size()),TimeUnit.NANOSECONDS.toMillis(System.nanoTime()-started),(mode==MetadataPlatform.RefreshMode.INCREMENTAL?"native scoped identity/fingerprint scan; changed details only":"native configured scopes with atomic publication")+"; routine fingerprint source reads="+routineSources[0]+", bytes="+routineSources[1]));
    }
    @FunctionalInterface interface RoutineFetch {MetadataObject fetch(RoutineFingerprintReader.Evidence evidence,MetadataScope point)throws Exception;}
    record RoutineBranches(MetadataPlatform.Branch parent,Map<MetadataScope,MetadataPlatform.Branch> points,long fetchedScopes,long fetchedObjects){}
    /** Exact routine scopes share unchanged native objects, including source.
     * Only the caller's detail callback performs acquisition/admission. The
     * namespace precedes point coverage so removals and overloads publish once. */
    static RoutineBranches routineBranches(MetadataSnapshot before,IdentifierRules rules,MetadataScope scope,IntrospectionLevel level,MetadataPlatform.RefreshMode mode,MetadataConfiguration configuration,List<RoutineFingerprintReader.Evidence> evidence,String fingerprint,long revision,long context,RoutineFetch fetch)throws Exception {
        var points=new LinkedHashMap<MetadataScope,MetadataPlatform.Branch>();var identities=new LinkedHashMap<MetadataScope,RoutineFingerprintReader.Evidence>();
        for(var item:evidence){
            var identity=routineIdentity(before,rules,item.identity());
            if(!routineInScope(scope,identity))throw new SQLException("Routine fingerprint belongs to another requested scope");
            if(!configuration.permits(identity.catalog(),identity.schema(),identity.kind(),identity.name()))continue;
            if(identities.put(routinePoint(identity),item)!=null)throw new SQLException("Routine fingerprint identity is ambiguous");
            if(identities.size()>MetadataSnapshot.MAX_OBJECTS)throw new IllegalArgumentException("Routine metadata object budget exceeded");
        }
        if(identities.values().stream().anyMatch(item->item.state()!=MetadataState.AVAILABLE)){
            // Incomplete native evidence does not establish deletion or allow
            // an older exact source scope to remain authoritative.
            for(var old:before.catalogCoverage().entrySet())if(!old.getKey().equals(scope)&&old.getKey().kind()==ObjectKind.ROUTINE&&old.getKey().overlaps(scope)){
                var state=old.getValue();points.put(old.getKey(),new MetadataPlatform.Branch(List.of(),new MetadataCoverage(old.getKey(),state.level(),MetadataState.PARTIAL,false,state.fingerprint(),revision,context,state.refreshedUnixMs(),"Routine fingerprint evidence is incomplete")));
            }
            for(var entry:identities.entrySet())if(entry.getValue().state()!=MetadataState.AVAILABLE){var item=entry.getValue();points.put(entry.getKey(),new MetadataPlatform.Branch(List.of(),routineCoverage(entry.getKey(),level,item.state(),item.fingerprint(),revision,context,item.limitation())));}
            var direct=points.remove(scope);var coverage=direct==null?routineCoverage(scope,level,MetadataState.PARTIAL,fingerprint,revision,context,"Routine fingerprint evidence is incomplete"):direct.coverage();
            return new RoutineBranches(new MetadataPlatform.Branch(List.of(),coverage),Collections.unmodifiableMap(points),0,0);
        }
        var objects=new ArrayList<MetadataObject>(identities.size());long fetched=0;var parentLevel=IntrospectionLevel.SOURCE;
        for(var entry:identities.entrySet()){
            var point=entry.getKey();var item=entry.getValue();var identity=routineIdentity(before,rules,item.identity());var previous=before.identities().get(identity.key());var old=before.catalogCoverage().get(point);
            boolean reused=mode==MetadataPlatform.RefreshMode.INCREMENTAL&&before.rules().fingerprint().equals(rules.fingerprint())&&old!=null&&old.complete()&&old.state()==MetadataState.AVAILABLE&&old.level().includes(level)&&old.fingerprint().equals(item.fingerprint())&&previous!=null&&previous.identity().equals(identity)&&previous.state()==MetadataState.AVAILABLE&&previous.level().includes(old.level())&&(level!=IntrospectionLevel.NAMES||old.level()==IntrospectionLevel.NAMES);
            var object=reused?previous:fetch.fetch(item,point);
            if(!identity.equals(object.identity())||object.state()!=MetadataState.AVAILABLE||!object.level().includes(level))throw new SQLException("Exact routine details changed during acquisition");
            var pointLevel=reused?old.level():level;var availability=RoutineAvailability.assess(pointLevel,object.properties());object=RoutineAvailability.apply(object,availability);
            var state=availability.objectState()==MetadataState.PARTIAL?availability.failure():MetadataState.AVAILABLE;var supported=availability.level();if(state==MetadataState.AVAILABLE)pointLevel=supported;
            objects.add(object);if(!reused&&level.includes(IntrospectionLevel.STRUCTURE))fetched++;
            if(supported.number()<parentLevel.number())parentLevel=supported;
            var coverage=routineCoverage(point,pointLevel,state,item.fingerprint(),revision,context,state==MetadataState.AVAILABLE?"":availability.limitation());
            points.put(point,reused?MetadataPlatform.Branch.reused(coverage):new MetadataPlatform.Branch(List.of(),coverage,List.of(object),false));
        }
        // The scope includes the captured signature and kind, so deleting one
        // overload cannot remove a same-named function/procedure or new OID.
        for(var previous:before.select(scope)){
            var point=routinePoint(previous.identity());if(identities.containsKey(point))continue;
            points.put(point,new MetadataPlatform.Branch(List.of(),routineCoverage(point,IntrospectionLevel.SOURCE,MetadataState.AVAILABLE,MetadataIdentity.digest("deleted-routine",point.key()),revision,context,"")));
        }
        if(objects.isEmpty())parentLevel=level;
        var direct=points.remove(scope);
        if(direct!=null&&!direct.coverage().complete()&&!objects.isEmpty()){
            // A fully typed point is also a valid signature-exact NAMES
            // enumeration without its optional kind filter. Keep its typed
            // failure separate so known partial fields remain inspectable.
            var names=new MetadataScope(scope.catalog(),scope.schema(),"",ObjectKind.ROUTINE,scope.search(),true,scope.signature(),ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED);
            if(names.equals(scope))throw new SQLException("Routine point/name scopes are not distinct");
            points.putFirst(names,new MetadataPlatform.Branch(List.of(),routineCoverage(names,IntrospectionLevel.NAMES,MetadataState.AVAILABLE,fingerprint,revision,context,""),objects,false));
            return new RoutineBranches(new MetadataPlatform.Branch(List.of(),direct.coverage()),Collections.unmodifiableMap(points),fetched,fetched);
        }
        var coverage=direct==null?routineCoverage(scope,parentLevel,MetadataState.AVAILABLE,fingerprint,revision,context,""):direct.coverage();
        return new RoutineBranches(new MetadataPlatform.Branch(List.of(),coverage,objects,false),Collections.unmodifiableMap(points),fetched,fetched);
    }
    private static MetadataIdentity routineIdentity(MetadataSnapshot before,IdentifierRules rules,SchemaObject object)throws SQLException {
        if(object.getKind()!=ObjectKind.ROUTINE||!object.getTable().isEmpty()||object.getIdentifier().isEmpty()||object.getSubtype()!=ObjectSubtype.FUNCTION&&object.getSubtype()!=ObjectSubtype.PROCEDURE)throw new SQLException("Exact native routine identity is unavailable");
        String nativeKey=rules.engine()==Engine.POSTGRESQL?object.getPropertiesOrDefault("nativeId",""):"";if(rules.engine()==Engine.POSTGRESQL&&nativeKey.isEmpty())throw new SQLException("Native PostgreSQL routine identity is unavailable");
        return new MetadataIdentity(before.source(),before.profileId(),object.getCatalog(),object.getSchema(),ObjectKind.ROUTINE,object.getSubtype(),"",object.getName(),object.getIdentifier(),"",nativeKey);
    }
    private static boolean routineInScope(MetadataScope scope,MetadataIdentity identity){return scope.kind()==ObjectKind.ROUTINE&&scope.parent().isEmpty()&&(scope.catalog().isEmpty()||scope.catalog().equals(identity.catalog()))&&(scope.schema().isEmpty()||scope.schema().equals(identity.schema()))&&(scope.signature().isEmpty()||scope.signature().equals(identity.signature()))&&(scope.subtype()==ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED||scope.subtype()==identity.subtype())&&(scope.exactName()?scope.search().equals(identity.name()):identity.name().toLowerCase(Locale.ROOT).contains(scope.search().toLowerCase(Locale.ROOT)));}
    private static MetadataScope routinePoint(MetadataIdentity identity){return new MetadataScope(identity.catalog(),identity.schema(),"",ObjectKind.ROUTINE,identity.name(),true,identity.signature(),identity.subtype());}
    private static MetadataCoverage routineCoverage(MetadataScope scope,IntrospectionLevel level,MetadataState state,String fingerprint,long revision,long context,String limitation){return new MetadataCoverage(scope,level,state,state==MetadataState.AVAILABLE,fingerprint,revision,context,System.currentTimeMillis(),limitation);}
    /** Reconciliation can stage stale exact scopes before its broad names branch.
     * Replacing those keys with acquired details keeps their original map positions,
     * so explicitly move names ahead of every structural repair before publication.
     * Iterating the staging map keeps overlapping names branches deterministic. */
    static void namesBeforeDetails(LinkedHashMap<MetadataScope,MetadataPlatform.Branch> branches,Set<MetadataScope> names) {
        if(names.isEmpty())return;
        var ordered=new ArrayList<MetadataScope>();
        for(var scope:branches.keySet())if(names.contains(scope))ordered.add(scope);
        for(var scope:ordered.reversed())branches.putFirst(scope,branches.get(scope));
    }
    private static void dependency(MetadataConfiguration config,Map<String,String> properties,Set<Relation> targets) {
        if(!"true".equals(properties.get("relationshipVerified")))return;
        String catalog=properties.getOrDefault("referencedCatalog",""),schema=properties.getOrDefault("referencedSchema",""),table=properties.getOrDefault("referencedTable","");
        if(catalog.isEmpty()||schema.isEmpty()||table.isEmpty()||!config.permits(catalog,schema,ObjectKind.TABLE,table)||!config.permits(catalog,schema,ObjectKind.COLUMN,table))return;
        targets.add(new Relation(catalog,schema,table));
    }
    private static List<MetadataScope> dependencyScopes(Relation target){return List.of(new MetadataScope(target.catalog(),target.schema(),"",ObjectKind.TABLE,target.table(),true,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED),new MetadataScope(target.catalog(),target.schema(),target.table(),ObjectKind.COLUMN));}
    private MetadataNames.Evidence scanEvidence(SessionRegistry.Session view,MetadataScope scope,MetadataConfiguration configuration,long deadline)throws Exception {
        var parents=new EnumMap<ObjectKind,Map<String,String>>(ObjectKind.class);
        var requested=new HashSet<ObjectKind>();
        for(ObjectKind kind:MetadataNames.CHILDREN)if(configuration.kinds().contains(kind)){check(deadline);requested.add(kind);parents.put(kind,adapter.scanParents(view,scope.catalog(),scope.schema(),kind,deadline));}
        return new MetadataNames.Evidence(parents,NativeTypeReader.namespaceFingerprints(view,scope.schema(),deadline),requested);
    }
    private void verifyEvidence(SessionRegistry.Session view,MetadataScope scope,MetadataNames.Evidence expected,long deadline)throws Exception {
        // Compare one native aggregate at a time instead of retaining a second
        // namespace-sized evidence map during atomic replacement.
        for(ObjectKind kind:expected.requestedKinds()){check(deadline);if(!expected.children().get(kind).equals(adapter.scanParents(view,scope.catalog(),scope.schema(),kind,deadline)))throw new Explorer.ContinuationFailure();}
        if(!expected.typeDependencies().equals(NativeTypeReader.namespaceFingerprints(view,scope.schema(),deadline)))throw new Explorer.ContinuationFailure();
    }
    private static String nativeNamesFingerprint(List<SchemaObject> values){return MetadataIdentity.digest(values.stream().sorted(Comparator.comparing(SchemaObject::getName)).flatMap(value->java.util.stream.Stream.of(value.getName(),value.getPropertiesOrDefault("nativeTableId",""),value.getPropertiesOrDefault("nativeColumnEpoch",""))).toArray(String[]::new));}
    private static void check(long deadline)throws TimeoutException {
        if(io.grpc.Context.current().isCancelled()||Thread.currentThread().isInterrupted())throw new CancellationException("Metadata refresh cancelled");
        if(System.nanoTime()>deadline)throw new TimeoutException("Metadata refresh deadline exceeded");
    }
}
