package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.*;
import java.util.*;

/** Published once, then shared without catalog work or reader locks. */
public final class MetadataSnapshot {
    public enum PhysicalRelationKind { PERSISTENT, TEMPORARY, ABSENT }
    public record RelationName(String catalog,String schema,String name){
        public RelationName{for(String identifier:List.of(catalog,schema,name))if(identifier.isEmpty()||identifier.length()>256||identifier.indexOf('\0')>=0)throw new IllegalArgumentException("Invalid physical relation identity");}
        long estimatedBytes(){return 256L+2L*(catalog.length()+schema.length()+name.length());}
    }
    /** Existing immutable acquisition facts, rather than a second catalog.
     * Coverage identity prevents a kind observation certifying an old shape. */
    public record OwnedRelationEvidence(MetadataObject relation,MetadataScope namesScope,MetadataCoverage names,MetadataScope columnsScope,MetadataCoverage columns){
        public OwnedRelationEvidence{Objects.requireNonNull(relation);Objects.requireNonNull(namesScope);Objects.requireNonNull(names);if(columns!=null)Objects.requireNonNull(columnsScope);}
        long estimatedBytes(){return 256+relation.estimatedBytes()+coverageBytes(names)+(columns==null?0:coverageBytes(columns));}
        private static long coverageBytes(MetadataCoverage value){return 256L+2L*(value.fingerprint().length()+value.limitation().length()+value.defaultNamespace().length());}
    }
    /** Physical-session visibility is independent of durable catalog coverage.
     * An opaque execution can create a shadow table invisible to every other
     * connection. Exact owned-session observations do not prove a full inventory. */
    public record SessionResolution(MetadataState state,String sessionId,long epoch,String limitation,Map<RelationName,PhysicalRelationKind> verified,Map<RelationName,OwnedRelationEvidence> owned){
        public static final int MAX_VERIFIED=2048;
        public static final long MAX_VERIFIED_BYTES=512L*1024;
        public SessionResolution(MetadataState state,String sessionId,long epoch,String limitation,Map<RelationName,PhysicalRelationKind> verified){this(state,sessionId,epoch,limitation,verified,Map.of());}
        public SessionResolution {
            sessionId=Objects.requireNonNull(sessionId);limitation=Objects.requireNonNull(limitation);verified=Map.copyOf(verified);owned=Map.copyOf(owned);
            if(state!=MetadataState.AVAILABLE&&state!=MetadataState.UNKNOWN||epoch<0||verified.size()>MAX_VERIFIED||limitation.length()>2048||sessionId.length()>128||sessionId.indexOf('\0')>=0)throw new IllegalArgumentException("Invalid session resolution state");
            if(state==MetadataState.UNKNOWN&&(sessionId.isEmpty()||epoch==0))throw new IllegalArgumentException("Unknown resolution needs an exact physical owner and epoch");
            long bytes=256;for(var key:verified.keySet())if((bytes+=key.estimatedBytes())>MAX_VERIFIED_BYTES)throw new IllegalArgumentException("Session relation evidence exceeds its byte budget");
            for(var entry:owned.entrySet()){if(verified.get(entry.getKey())!=PhysicalRelationKind.TEMPORARY||!entry.getValue().relation().identity().sessionOwner().equals(sessionId))throw new IllegalArgumentException("Owned shape needs the same physical TEMP observation");if((bytes+=entry.getValue().estimatedBytes()+entry.getKey().estimatedBytes())>MAX_VERIFIED_BYTES)throw new IllegalArgumentException("Session owned-shape evidence exceeds its byte budget");}
        }
        public static SessionResolution available(){return new SessionResolution(MetadataState.AVAILABLE,"",0,"",Map.of());}
        public long estimatedBytes(){long bytes=256;for(var key:verified.keySet())bytes+=key.estimatedBytes();for(var entry:owned.entrySet())bytes+=entry.getValue().estimatedBytes()+entry.getKey().estimatedBytes();return bytes;}
    }
    public static final int MAX_OBJECTS=250_000;
    public static final long MAX_BYTES=192L*1024*1024;
    record Namespace(String catalog,String schema,ObjectKind kind,String parent){}
    record Relation(String catalog,String schema,String name){}
    private final String source,profileId;
    private final long revision,configurationRevision,createdUnixMs,estimatedBytes;
    private final IdentifierRules rules;
    private final boolean identifierAvailable;
    private final Map<String,MetadataObject> identities;
    private final Map<MetadataScope,MetadataCoverage> coverage;
    private final Map<Namespace,List<MetadataObject>> namespaces;
    private final Map<Namespace,Map<String,Object>> names;
    private final Map<ObjectKind,List<List<MetadataObject>>> kinds;
    private final List<SchemaObject> objects;
    private final Map<Relation,List<MetadataObject>> incoming;
    private final Map<Relation,String> parents;
    private final List<MetadataObject> ordered,persistenceObjects;
    private final SessionResolution sessionResolution;
    private final MetadataObject[] lookup;
    private final Set<Object> layoutIdentities;
    private final OwnedLayer ownedLayer;
    record Indexes(Map<String,MetadataObject> identities,List<MetadataObject> ordered,MetadataObject[] lookup,
            Map<Namespace,List<MetadataObject>> namespaces,Map<Namespace,Map<String,Object>> names,
            Map<ObjectKind,List<List<MetadataObject>>> kinds,Map<Relation,List<MetadataObject>> incoming,
            Map<Relation,String> parents,Map<MetadataScope,MetadataCoverage> coverage,List<MetadataObject> persistence){}
    private record OwnedLayer(MetadataSnapshot base,MetadataSnapshot delta,Set<MetadataScope> scopes,
            Map<MetadataScope,MetadataCoverage> coverage,Set<MetadataScope> removed,
            Map<MetadataScope,MetadataCoverage> composedCoverage,String inheritedStaleReason,MetadataOverlayIndex.ScopeMask mask){}
    record CompositionCharge(long residentBytes,long allocationBytes){}
    Indexes indexes(){return new Indexes(identities,ordered,lookup,namespaces,names,kinds,incoming,parents,coverage,persistenceObjects);}
    boolean composed(){return ownedLayer!=null;}
    String allCoverageStaleReason(){return ownedLayer==null?"":ownedLayer.inheritedStaleReason();}
    Map<String,MetadataObject> localIdentities(){return ownedLayer==null?Map.of():ownedLayer.delta().identities();}
    Set<MetadataScope> replacementScopes(){return ownedLayer==null?Set.of():ownedLayer.scopes();}
    Map<MetadataScope,MetadataCoverage> localCoverage(){
        if(ownedLayer==null)return Map.of();
        if(coverage==ownedLayer.composedCoverage())return ownedLayer.coverage();
        var layer=ownedLayer;return Collections.unmodifiableMap(new AbstractMap<>(){
            @Override public MetadataCoverage get(Object key){var value=coverage.get(key);return value!=null&&(layer.coverage().containsKey(key)||value!=layer.base().catalogCoverage().get(key))?value:null;}
            @Override public int size(){int count=0;for(var ignored:entrySet())count++;return count;}
            @Override public Set<Entry<MetadataScope,MetadataCoverage>> entrySet(){return new AbstractSet<>(){
                @Override public int size(){int count=0;for(var ignored:this)count++;return count;}
                @Override public Iterator<Entry<MetadataScope,MetadataCoverage>> iterator(){var values=coverage.entrySet().iterator();return new Iterator<>(){Entry<MetadataScope,MetadataCoverage> next;public boolean hasNext(){while(next==null&&values.hasNext()){var entry=values.next();if(layer.coverage().containsKey(entry.getKey())||entry.getValue()!=layer.base().catalogCoverage().get(entry.getKey()))next=entry;}return next!=null;}public Entry<MetadataScope,MetadataCoverage> next(){if(!hasNext())throw new NoSuchElementException();var result=next;next=null;return result;}};}
            };}
        });
    }
    Set<MetadataScope> removedCoverageScopes(){
        if(ownedLayer==null)return Set.of();if(coverage==ownedLayer.composedCoverage())return ownedLayer.removed();var layer=ownedLayer;
        return Collections.unmodifiableSet(new AbstractSet<>(){
            @Override public boolean contains(Object scope){return layer.removed().contains(scope)||layer.base().catalogCoverage().containsKey(scope)&&!coverage.containsKey(scope);}
            @Override public int size(){int n=0;for(var ignored:this)n++;return n;}
            @Override public Iterator<MetadataScope> iterator(){var existing=layer.removed().iterator();var baseline=layer.base().catalogCoverage().keySet().iterator();return new Iterator<>(){MetadataScope next;public boolean hasNext(){if(existing.hasNext())return true;while(next==null&&baseline.hasNext()){var scope=baseline.next();if(!layer.removed().contains(scope)&&!coverage.containsKey(scope))next=scope;}return next!=null;}public MetadataScope next(){if(existing.hasNext())return existing.next();if(!hasNext())throw new NoSuchElementException();var result=next;next=null;return result;}};}
        });
    }
    List<MetadataObject> selectLocal(MetadataScope scope){return ownedLayer==null?List.of():ownedLayer.delta().select(scope);}
    boolean replacesBase(MetadataObject object){return replacesBase(object,Long.MAX_VALUE);}
    boolean replacesBase(MetadataObject object,long deadline){try{return ownedLayer!=null&&(ownedLayer.delta().identities().containsKey(object.identity().key())||ownedLayer.mask().contains(object,deadline));}catch(BuildDeadline expired){throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.TIMED_OUT);}}
    /** Only acquired local facts retain ownership; publication callers validate
     * physical session/context, masks and scope completeness before this model. */
    static MetadataSnapshot compose(MetadataSnapshot base,Collection<MetadataObject> facts,Set<MetadataScope> scopes,
            Map<MetadataScope,MetadataCoverage> localCoverage,Set<MetadataScope> removed,long revision,long configurationRevision,long createdUnixMs,long deadline)throws java.util.concurrent.TimeoutException {
        if(base.composed())throw new IllegalArgumentException("A durable overlay base is required");checkCompositionDeadline(deadline);
        if(scopes.isEmpty()&&facts.isEmpty()&&localCoverage.isEmpty()&&removed.isEmpty())return base;
        var charge=estimateComposition(base,null,facts,scopes,localCoverage,removed);
        long scopesCount=base.catalogCoverage().size();for(var key:removed)if(base.catalogCoverage().containsKey(key)&&!localCoverage.containsKey(key))scopesCount--;for(var key:localCoverage.keySet())if(!base.catalogCoverage().containsKey(key))scopesCount++;
        if(scopesCount>100_000)throw new IllegalArgumentException("Composed metadata scope budget exceeded");
        try{
            checkBuild(deadline);var mask=new MetadataOverlayIndex.ScopeMask(scopes,deadline);for(var fact:facts){checkBuild(deadline);if(!mask.contains(fact))throw new IllegalArgumentException("Owned fact is outside its replacement scopes");}
            var delta=MetadataSnapshot.prepare(base.source(),base.profileId(),Math.max(1,revision),configurationRevision,createdUnixMs,base.rules(),facts,localCoverage,deadline);
            var indexes=MetadataOverlayIndex.prepare(base,delta,scopes,localCoverage,removed,deadline).indexes();
            return new MetadataSnapshot(base,delta,indexes,scopes,localCoverage,removed,revision,configurationRevision,createdUnixMs,charge.residentBytes());
        }catch(BuildDeadline expired){throw new java.util.concurrent.TimeoutException("Metadata composition deadline exceeded");}
    }
    /** The semantic estimate charges shared object/layout references once. Index
     * charges are conservative documented bounds, not JVM object-size claims. */
    static CompositionCharge estimateComposition(MetadataSnapshot base,MetadataSnapshot prior,Collection<MetadataObject> facts,
            Set<MetadataScope> scopes,Map<MetadataScope,MetadataCoverage> localCoverage,Set<MetadataScope> removed){
        if(base.composed()||facts.size()>MAX_OBJECTS||scopes.size()>100_000||localCoverage.size()>100_000||removed.size()>100_000)throw new IllegalArgumentException("Invalid owned composition budget");
        if(prior!=null&&(!prior.source().equals(base.source())||!prior.profileId().equals(base.profileId())))throw new IllegalArgumentException("Owned composition belongs to another source");
        if(facts.isEmpty()&&scopes.isEmpty()&&localCoverage.isEmpty()&&removed.isEmpty())return new CompositionCharge(0,0);
        long resident=0,allocation=0;var residentLayouts=Collections.newSetFromMap(new IdentityHashMap<Object,Boolean>());var allocatedLayouts=Collections.newSetFromMap(new IdentityHashMap<Object,Boolean>());
        for(var fact:facts){var key=fact.identity().key();String nativeKind=base.rules().engine()!=Engine.POSTGRESQL&&fact.identity().kind()==ObjectKind.CONSTRAINT?fact.properties().getOrDefault("type",""):"";boolean renormalized=!base.rules().lookup(fact.identity().kind(),fact.identity().name(),true,nativeKind).equals(fact.lookupKey())||base.rules().engine()!=Engine.POSTGRESQL&&fact.identity().kind()==ObjectKind.CONSTRAINT&&(!nativeKind.equals(fact.identity().signature())||!fact.identity().nativeKey().isEmpty());boolean shared=!renormalized&&base.identities().get(key)==fact;boolean old=!renormalized&&prior!=null&&prior.localIdentities().get(key)==fact;if(!shared)resident+=fact.estimatedBytes();if(!shared&&!old)allocation+=fact.estimatedBytes();if(fact.properties() instanceof CompactProperties compact){Object layout=compact.layoutIdentity();if(!base.layoutIdentities.contains(layout)&&residentLayouts.add(layout))resident+=compact.layoutBytes();if(!base.layoutIdentities.contains(layout)&&(prior==null||!prior.layoutIdentities.contains(layout))&&allocatedLayouts.add(layout))allocation+=compact.layoutBytes();}if(resident>MAX_BYTES||allocation>MAX_BYTES)throw new IllegalArgumentException("Owned semantic byte budget exceeded");}
        for(var entry:localCoverage.entrySet()){var value=entry.getValue();if(base.catalogCoverage().get(entry.getKey())!=value)resident+=coverageCharge(value);if(base.catalogCoverage().get(entry.getKey())!=value&&(prior==null||prior.catalogCoverage().get(entry.getKey())!=value))allocation+=coverageCharge(value);}
        long indexes=MetadataOverlayIndex.indexCharge(base,facts.size(),scopes,localCoverage.size(),removed.size());resident+=indexes;allocation+=indexes;
        if(base.estimatedBytes()+resident>MAX_BYTES)throw new IllegalArgumentException("Composed semantic and index byte budget exceeded");return new CompositionCharge(resident,allocation);
    }
    private static void checkCompositionDeadline(long deadline)throws java.util.concurrent.TimeoutException {try{checkBuild(deadline);}catch(BuildDeadline expired){throw new java.util.concurrent.TimeoutException("Metadata composition deadline exceeded");}}
    private static long coverageCharge(MetadataCoverage value){var scope=value.scope();return 512L+2L*(scope.catalog().length()+scope.schema().length()+scope.parent().length()+scope.search().length()+scope.signature().length()+value.fingerprint().length()+value.limitation().length()+value.defaultNamespace().length());}
    private MetadataSnapshot(MetadataSnapshot base,MetadataSnapshot delta,Indexes indexes,Set<MetadataScope> scopes,
            Map<MetadataScope,MetadataCoverage> localCoverage,Set<MetadataScope> removed,long revision,long configurationRevision,long createdUnixMs,long residentBytes){
        this(base,delta,indexes,scopes,localCoverage,removed,revision,configurationRevision,createdUnixMs,residentBytes,"");
    }
    private MetadataSnapshot(MetadataSnapshot base,MetadataSnapshot delta,Indexes indexes,Set<MetadataScope> scopes,
            Map<MetadataScope,MetadataCoverage> localCoverage,Set<MetadataScope> removed,long revision,long configurationRevision,long createdUnixMs,long residentBytes,String inheritedStaleReason){
        source=base.source;profileId=base.profileId;this.revision=revision;this.configurationRevision=configurationRevision;this.createdUnixMs=createdUnixMs;rules=base.rules;identifierAvailable=base.identifierAvailable;sessionResolution=base.sessionResolution;estimatedBytes=residentBytes;
        identities=indexes.identities();ordered=indexes.ordered();lookup=null;namespaces=indexes.namespaces();names=indexes.names();kinds=indexes.kinds();incoming=indexes.incoming();parents=indexes.parents();coverage=inheritedStaleReason.isEmpty()?indexes.coverage():Collections.unmodifiableMap(new MetadataOverlayIndex.Overrides<>(new StaleCoverage(base.catalogCoverage(),inheritedStaleReason),localCoverage,removed));persistenceObjects=List.of();
        layoutIdentities=unionLayouts(base.layoutIdentities,delta.layoutIdentities);
        ownedLayer=new OwnedLayer(base,delta,Set.copyOf(scopes),Map.copyOf(localCoverage),Set.copyOf(removed),coverage,inheritedStaleReason,new MetadataOverlayIndex.ScopeMask(scopes));objects=objectProjection();
    }
    /** Inline invalidation changes coverage/revision only. Rebase such a view in
     * bounded delta work; no full-catalog scan occurs on a capture/keystroke. */
    boolean canRebaseCoverageOnto(MetadataSnapshot base){
        return ownedLayer!=null&&base!=null&&!base.composed()&&base.rules.fingerprint().equals(rules.fingerprint())&&ownedLayer.base().lookup==base.lookup;
    }
    MetadataSnapshot rebaseComposed(MetadataSnapshot base,long revision,long configurationRevision,long createdUnixMs,long deadline)throws java.util.concurrent.TimeoutException {
        if(ownedLayer==null)throw new IllegalArgumentException("Expected an owned composition");if(base.composed())throw new IllegalArgumentException("Expected a durable base");
        if(!base.rules.fingerprint().equals(rules.fingerprint()))throw new IllegalArgumentException("Changed identifier evidence requires explicit owned scope reconciliation");
        var states=localCoverage();var removed=removedCoverageScopes();
        if(base.lookup!=ownedLayer.base().lookup){var result=compose(base,localIdentities().values(),replacementScopes(),states,removed,revision,configurationRevision,createdUnixMs,deadline);if(!allCoverageStaleReason().isEmpty())result=result.withInheritedCoverageStale(revision,allCoverageStaleReason());return result.withSessionResolution(revision,sessionResolution).withIdentifierAvailability(base.identifierAvailable&&identifierAvailable);}
        checkCompositionDeadline(deadline);var coverage=Collections.unmodifiableMap(new MetadataOverlayIndex.Overrides<>(base.catalogCoverage(),states,removed));var indexes=new Indexes(identities,ordered,null,namespaces,names,kinds,incoming,parents,coverage,List.of());
        long charge=estimatedBytes;for(var entry:ownedLayer.coverage().entrySet())if(ownedLayer.base().catalogCoverage().get(entry.getKey())!=entry.getValue())charge-=coverageCharge(entry.getValue());
        for(var entry:states.entrySet())if(base.catalogCoverage().get(entry.getKey())!=entry.getValue())charge+=coverageCharge(entry.getValue());
        return new MetadataSnapshot(base,ownedLayer.delta(),indexes,replacementScopes(),states,removed,revision,configurationRevision,createdUnixMs,charge,allCoverageStaleReason()).withSessionResolution(revision,sessionResolution).withIdentifierAvailability(base.identifierAvailable&&identifierAvailable);
    }
    /** Owned scope invalidation is a sparse immutable coverage replacement.
     * Repeated updates flatten the local map and retain no earlier view. */
    MetadataSnapshot withCoverageOverrides(long revision,Map<MetadataScope,MetadataCoverage> overrides){
        if(ownedLayer==null)throw new IllegalArgumentException("Coverage overrides require an owned composition");
        var local=new HashMap<>(localCoverage());local.putAll(overrides);if(local.size()>100_000)throw new IllegalArgumentException("Owned coverage budget exceeded");var removed=removedCoverageScopes();var states=Collections.unmodifiableMap(new MetadataOverlayIndex.Overrides<>(ownedLayer.base().catalogCoverage(),local,removed));
        var indexes=new Indexes(identities,ordered,null,namespaces,names,kinds,incoming,parents,states,List.of());long charge=estimatedBytes+384L*(local.size()-ownedLayer.coverage().size());
        for(var entry:ownedLayer.coverage().entrySet())if(ownedLayer.base().catalogCoverage().get(entry.getKey())!=entry.getValue())charge-=coverageCharge(entry.getValue());
        for(var entry:local.entrySet())if(ownedLayer.base().catalogCoverage().get(entry.getKey())!=entry.getValue())charge+=coverageCharge(entry.getValue());
        return new MetadataSnapshot(ownedLayer.base(),ownedLayer.delta(),indexes,replacementScopes(),local,removed,revision,configurationRevision,createdUnixMs,charge,allCoverageStaleReason()).withSessionResolution(revision,sessionResolution).withIdentifierAvailability(identifierAvailable);
    }
    /** Invalidation affects all currently acquired facts. Future fresh owned
     * overrides can regain authority while inherited durable scopes stay stale. */
    MetadataSnapshot withAllCoverageStale(long revision,String reason){
        checkStaleReason(reason);if(ownedLayer==null)return withInheritedCoverageStale(revision,reason);
        var local=new HashMap<MetadataScope,MetadataCoverage>();for(var entry:localCoverage().entrySet())local.put(entry.getKey(),entry.getValue().stale(reason));
        return withCoverageOverrides(revision,local).withInheritedCoverageStale(revision,reason);
    }
    /** A zero-delta owned availability view shares the captured durable indexes.
     * Repeated transforms replace a reason, never wrap a preceding stale view. */
    MetadataSnapshot withInheritedCoverageStale(long revision,String reason){
        checkStaleReason(reason);MetadataSnapshot base=ownedLayer==null?this:ownedLayer.base();
        var delta=ownedLayer==null?new MetadataSnapshot(source,profileId,revision,configurationRevision,createdUnixMs,rules,List.of(),Map.of()):ownedLayer.delta();
        var local=localCoverage();var removed=removedCoverageScopes();var scopes=replacementScopes();
        var coverage=Collections.unmodifiableMap(new MetadataOverlayIndex.Overrides<>(base.catalogCoverage(),local,removed));
        var indexes=new Indexes(identities,ordered,null,namespaces,names,kinds,incoming,parents,coverage,List.of());
        long bytes=(ownedLayer==null?1024:estimatedBytes-staleReasonCharge(allCoverageStaleReason()))+staleReasonCharge(reason);
        return new MetadataSnapshot(base,delta,indexes,scopes,local,removed,revision,configurationRevision,createdUnixMs,bytes,reason).withSessionResolution(revision,sessionResolution).withIdentifierAvailability(identifierAvailable);
    }
    private static long staleReasonCharge(String reason){return reason.isEmpty()?0:512L+2L*reason.length();}
    private static void checkStaleReason(String reason){if(reason==null||reason.isEmpty()||reason.length()>2048||reason.indexOf('\0')>=0)throw new IllegalArgumentException("Invalid owned stale-coverage reason");}
    private static final class StaleCoverage extends AbstractMap<MetadataScope,MetadataCoverage>{
        private final Map<MetadataScope,MetadataCoverage> captured;private final String reason;
        StaleCoverage(Map<MetadataScope,MetadataCoverage> captured,String reason){this.captured=captured;this.reason=reason;}
        @Override public int size(){return captured.size();}
        @Override public MetadataCoverage get(Object key){var value=captured.get(key);return value==null?null:value.stale(reason);}
        @Override public boolean containsKey(Object key){return captured.containsKey(key);}
        @Override public Set<Entry<MetadataScope,MetadataCoverage>> entrySet(){return Collections.unmodifiableSet(new AbstractSet<>(){
            @Override public int size(){return captured.size();}
            @Override public Iterator<Entry<MetadataScope,MetadataCoverage>> iterator(){var iterator=captured.entrySet().iterator();return new Iterator<>(){public boolean hasNext(){return iterator.hasNext();}public Entry<MetadataScope,MetadataCoverage> next(){var value=iterator.next();return Map.entry(value.getKey(),value.getValue().stale(reason));}};}
        });}
    }
    private static Set<Object> unionLayouts(Set<Object> base,Set<Object> delta){
        if(delta.isEmpty())return base;return Collections.unmodifiableSet(new AbstractSet<>(){
            @Override public boolean contains(Object value){return base.contains(value)||delta.contains(value);}
            @Override public int size(){int size=base.size();for(var value:delta)if(!base.contains(value))size++;return size;}
            @Override public Iterator<Object> iterator(){var first=base.iterator();var second=delta.iterator();return new Iterator<>(){Object next;public boolean hasNext(){if(first.hasNext())return true;while(next==null&&second.hasNext()){var value=second.next();if(!base.contains(value))next=value;}return next!=null;}public Object next(){if(first.hasNext())return first.next();if(!hasNext())throw new NoSuchElementException();var result=next;next=null;return result;}};}
        });
    }

    public MetadataSnapshot(String source,String profileId,long revision,long configurationRevision,long createdUnixMs,
            IdentifierRules rules,Collection<MetadataObject> entries,Map<MetadataScope,MetadataCoverage> coverage) {
        this(source,profileId,revision,configurationRevision,createdUnixMs,rules,entries,coverage,Long.MAX_VALUE);
    }
    private static final class BuildDeadline extends RuntimeException {}
    static void checkBuild(long deadline){
        if(deadline==Long.MAX_VALUE)return;
        if(io.grpc.Context.current().isCancelled()||Thread.currentThread().isInterrupted())throw new java.util.concurrent.CancellationException("Metadata snapshot preparation cancelled");
        if(System.nanoTime()>deadline)throw new BuildDeadline();
    }
    static MetadataSnapshot prepare(String source,String profileId,long revision,long configurationRevision,long createdUnixMs,IdentifierRules rules,Collection<MetadataObject> entries,Map<MetadataScope,MetadataCoverage> coverage,long deadline)throws java.util.concurrent.TimeoutException {
        try{return new MetadataSnapshot(source,profileId,revision,configurationRevision,createdUnixMs,rules,entries,coverage,deadline);}
        catch(BuildDeadline expired){throw new java.util.concurrent.TimeoutException("Metadata snapshot preparation deadline exceeded");}
    }
    private MetadataSnapshot(String source,String profileId,long revision,long configurationRevision,long createdUnixMs,
            IdentifierRules rules,Collection<MetadataObject> entries,Map<MetadataScope,MetadataCoverage> coverage,long deadline) {
        checkBuild(deadline);
        this.source=source;this.profileId=profileId;this.revision=revision;this.configurationRevision=configurationRevision;this.createdUnixMs=createdUnixMs;this.rules=rules;identifierAvailable=rules.complete();sessionResolution=SessionResolution.available();ownedLayer=null;
        if(entries.size()>MAX_OBJECTS||coverage.size()>100_000)throw new IllegalArgumentException("Metadata snapshot object/scope budget exceeded");
        var encountered=new MetadataObject[entries.size()];int encounteredCount=0;for(var entry:entries){if((encounteredCount&255)==0)checkBuild(deadline);encountered[encounteredCount++]=entry.withRules(rules);}
        long bytes=rules.estimatedBytes();var layouts=new IdentityHashMap<Object,Boolean>();
        int visited=0;for(var entry:encountered) {
            if((visited++&255)==0)checkBuild(deadline);
            if(!entry.identity().source().equals(source)||!entry.identity().profileId().equals(profileId))throw new IllegalArgumentException("Metadata object belongs to another source");
            if((bytes+=entry.estimatedBytes())>MAX_BYTES)throw new IllegalArgumentException("Metadata snapshot byte budget exceeded");
            if(entry.properties() instanceof CompactProperties compact&&layouts.put(compact.layoutIdentity(),Boolean.TRUE)==null){bytes+=compact.layoutBytes();if(bytes>MAX_BYTES)throw new IllegalArgumentException("Metadata key-layout byte budget exceeded");}
        }
        layoutIdentities=Collections.unmodifiableSet(layouts.keySet());
        var index=new OrderedIdentityMap(encountered,deadline);lookup=index.lookup;identities=Collections.unmodifiableMap(index);ordered=index.values;persistenceObjects=Collections.unmodifiableList(Arrays.asList(index.lookup));
        var byNamespace=new HashMap<Namespace,List<MetadataObject>>();var byName=new HashMap<Namespace,Map<String,Object>>();
        visited=0;for(var entry:ordered) {
            if((visited++&255)==0)checkBuild(deadline);
            var i=entry.identity();var namespace=new Namespace(i.catalog(),i.schema(),i.kind(),i.parent());
            byNamespace.computeIfAbsent(namespace,k->new ArrayList<>()).add(entry);
            indexName(byName,namespace,entry);
            if(!i.parent().isEmpty()) {
                var branch=new Namespace(i.catalog(),i.schema(),i.kind(),"");
                byNamespace.computeIfAbsent(branch,k->new ArrayList<>()).add(entry);
                indexName(byName,branch,entry);
            }
        }
        Comparator<MetadataObject> ordering=Comparator.comparing((MetadataObject o)->o.identity().name()).thenComparing(o->o.identity().parent()).thenComparing(o->o.identity().signature());
        byNamespace.replaceAll((k,v)->{checkBuild(deadline);return v.stream().sorted(ordering).toList();});byName.replaceAll((k,v)->{checkBuild(deadline);v.replaceAll((name,value)->value instanceof List<?> list?List.copyOf(list):value);return Map.copyOf(v);});
        namespaces=Map.copyOf(byNamespace);names=Map.copyOf(byName);this.coverage=Map.copyOf(coverage);estimatedBytes=bytes;
        var byKind=new EnumMap<ObjectKind,List<List<MetadataObject>>>(ObjectKind.class);
        for(var branch:namespaces.entrySet())if(branch.getKey().parent().isEmpty())byKind.computeIfAbsent(branch.getKey().kind(),ignored->new ArrayList<>()).add(branch.getValue());
        byKind.replaceAll((kind,branches)->List.copyOf(branches));kinds=Map.copyOf(byKind);
        var parentKeys=new HashMap<Relation,String>();var incomingKeys=new HashMap<Relation,List<MetadataObject>>();
        visited=0;for(var entry:ordered) {
            if((visited++&255)==0)checkBuild(deadline);
            var identity=entry.identity();
            if(identity.kind()==ObjectKind.TABLE||identity.kind()==ObjectKind.VIEW)parentKeys.put(new Relation(identity.catalog(),identity.schema(),identity.name()),identity.key());
            if(identity.kind()==ObjectKind.FOREIGN_KEY&&"true".equals(entry.properties().get("relationshipVerified"))) {
                var relation=new Relation(entry.properties().getOrDefault("referencedCatalog",""),entry.properties().getOrDefault("referencedSchema",""),entry.properties().getOrDefault("referencedTable",""));
                incomingKeys.computeIfAbsent(relation,k->new ArrayList<>()).add(entry);
            }
        }
        incomingKeys.replaceAll((k,v)->List.copyOf(v));incoming=Map.copyOf(incomingKeys);parents=Map.copyOf(parentKeys);
        // The native model is authoritative. A wire projection is created only
        // for the selected object; retaining a second protobuf catalog doubles
        // the resident column/property data in a large source.
        objects=objectProjection();checkBuild(deadline);
    }
    /** A sorted immutable identity index shares encounter-order values with projections.
     * Entry/key views preserve map iteration order without permanent linked nodes. */
    private static final class OrderedIdentityMap extends AbstractMap<String,MetadataObject> {
        private final MetadataObject[] lookup;
        private final List<MetadataObject> values;
        private OrderedIdentityMap(MetadataObject[] encountered,long deadline){
            var sorted=encountered.clone();Arrays.sort(sorted,Comparator.comparing(value->value.identity().key()));
            int unique=0;Map<String,MetadataObject> duplicates=null;
            int visited=0;for(var value:sorted){
                if((visited++&255)==0)checkBuild(deadline);
                if(unique>0&&sorted[unique-1].identity().key().equals(value.identity().key())){
                    if(!sorted[unique-1].equals(value))throw new IllegalArgumentException("Conflicting metadata identity");
                    if(duplicates==null)duplicates=new HashMap<>();duplicates.put(value.identity().key(),value);sorted[unique-1]=value;
                }else sorted[unique++]=value;
            }
            lookup=unique==sorted.length?sorted:Arrays.copyOf(sorted,unique);
            if(duplicates==null)values=Collections.unmodifiableList(Arrays.asList(encountered));
            else{
                var distinct=new ArrayList<MetadataObject>(unique);
                visited=0;for(var value:encountered){if((visited++&255)==0)checkBuild(deadline);String key=value.identity().key();if(!duplicates.containsKey(key))distinct.add(value);else{var last=duplicates.put(key,null);if(last!=null)distinct.add(last);}}
                values=List.copyOf(distinct);
            }
        }
        @Override public int size(){return values.size();}
        @Override public MetadataObject get(Object key){
            if(!(key instanceof String identity))return null;
            int low=0,high=lookup.length-1;
            while(low<=high){int middle=(low+high)>>>1;var value=lookup[middle];int order=value.identity().key().compareTo(identity);if(order<0)low=middle+1;else if(order>0)high=middle-1;else return value;}
            return null;
        }
        @Override public boolean containsKey(Object key){return get(key)!=null;}
        @Override public boolean containsValue(Object value){return value!=null&&values.contains(value);}
        @Override public Collection<MetadataObject> values(){return values;}
        @Override public void forEach(java.util.function.BiConsumer<? super String,? super MetadataObject> action){Objects.requireNonNull(action);for(var value:values)action.accept(value.identity().key(),value);}
        @Override public Set<String> keySet(){return new AbstractSet<>(){
            @Override public int size(){return values.size();}
            @Override public boolean contains(Object key){return containsKey(key);}
            @Override public Iterator<String> iterator(){var iterator=values.iterator();return new Iterator<>(){public boolean hasNext(){return iterator.hasNext();}public String next(){return iterator.next().identity().key();}};}
            @Override public Spliterator<String> spliterator(){return Spliterators.spliterator(iterator(),size(),Spliterator.ORDERED|Spliterator.IMMUTABLE|Spliterator.DISTINCT|Spliterator.NONNULL);}
        };}
        @Override public Set<Entry<String,MetadataObject>> entrySet(){return new AbstractSet<>(){
            @Override public int size(){return values.size();}
            @Override public boolean contains(Object value){return value instanceof Entry<?,?> entry&&entry.getValue()!=null&&Objects.equals(get(entry.getKey()),entry.getValue());}
            @Override public Iterator<Entry<String,MetadataObject>> iterator(){var iterator=values.iterator();return new Iterator<>(){public boolean hasNext(){return iterator.hasNext();}public Entry<String,MetadataObject> next(){var value=iterator.next();return Map.entry(value.identity().key(),value);}};}
            @Override public Spliterator<Entry<String,MetadataObject>> spliterator(){return Spliterators.spliterator(iterator(),size(),Spliterator.ORDERED|Spliterator.IMMUTABLE|Spliterator.DISTINCT|Spliterator.NONNULL);}
        };}
    }
    /** Shares every native catalog index. A session-state change allocates no
     * catalog-sized map, list, coverage replacement or protobuf projection. */
    private MetadataSnapshot(MetadataSnapshot base,long revision,SessionResolution resolution){this(base,revision,resolution,base.coverage);}
    private MetadataSnapshot(MetadataSnapshot base,long revision,SessionResolution resolution,Map<MetadataScope,MetadataCoverage> coverage){
        this(base,revision,resolution,coverage,base.identifierAvailable);
    }
    private MetadataSnapshot(MetadataSnapshot base,long revision,SessionResolution resolution,Map<MetadataScope,MetadataCoverage> coverage,boolean identifierAvailable){
        source=base.source;profileId=base.profileId;this.revision=revision;configurationRevision=base.configurationRevision;createdUnixMs=base.createdUnixMs;estimatedBytes=base.estimatedBytes;rules=base.rules;
        this.identifierAvailable=identifierAvailable&&rules.complete();
        lookup=base.lookup;layoutIdentities=base.layoutIdentities;ownedLayer=base.ownedLayer;identities=base.identities;this.coverage=coverage;namespaces=base.namespaces;names=base.names;kinds=base.kinds;incoming=base.incoming;parents=base.parents;ordered=base.ordered;persistenceObjects=base.persistenceObjects;sessionResolution=resolution;objects=objectProjection();
    }
    /** Rebuildable-cache writes follow the already-built SHA identity index.
     * This read-only view owns no new array/sort and never changes live order. */
    List<MetadataObject> persistenceObjects(){if(composed())throw new IllegalStateException("Session metadata cannot be persisted as a durable catalog");return persistenceObjects;}
    private List<SchemaObject> objectProjection(){
        return Collections.unmodifiableList(new AbstractList<>() {
            @Override public SchemaObject get(int index){return projection(ordered.get(index));}
            @Override public int size(){return ordered.size();}
        });
    }
    public MetadataSnapshot withSessionResolution(long revision,SessionResolution resolution){if(revision<1)throw new IllegalArgumentException("Invalid captured metadata revision");return new MetadataSnapshot(this,revision,Objects.requireNonNull(resolution));}
    /** Advance a prepared candidate without rebuilding any catalog index. */
    MetadataSnapshot withPublicationRevision(long revision){return revision==this.revision?this:new MetadataSnapshot(this,revision,sessionResolution);}
    /** The essential preference CAS may overlap an inline invalidation. This
     * immutable key-filtered view preserves that loss of authority in O(1)
     * commit work; the next policy/normal publication materializes its entries. */
    MetadataSnapshot withConfigurationPublication(long revision,MetadataSnapshot captured,MetadataSnapshot latest){
        if(captured.coverage==latest.coverage)return withPublicationRevision(revision);
        return new MetadataSnapshot(this,revision,sessionResolution,new PolicyCoverage(coverage,captured.coverage,latest.coverage));
    }
    private static final class PolicyCoverage extends AbstractMap<MetadataScope,MetadataCoverage> {
        private final Map<MetadataScope,MetadataCoverage> prepared,before,latest;
        PolicyCoverage(Map<MetadataScope,MetadataCoverage> prepared,Map<MetadataScope,MetadataCoverage> before,Map<MetadataScope,MetadataCoverage> latest){this.prepared=prepared;this.before=before;this.latest=latest;}
        @Override public int size(){return prepared.size();}
        @Override public MetadataCoverage get(Object key){var value=prepared.get(key);if(value==null)return null;var current=latest.get(key);return current!=null&&current!=before.get(key)&&!current.complete()?current:value;}
        @Override public Set<Entry<MetadataScope,MetadataCoverage>> entrySet(){return Collections.unmodifiableSet(new AbstractSet<>(){
            @Override public int size(){return prepared.size();}
            @Override public Iterator<Entry<MetadataScope,MetadataCoverage>> iterator(){var keys=prepared.keySet().iterator();return new Iterator<>(){public boolean hasNext(){return keys.hasNext();}public Entry<MetadataScope,MetadataCoverage> next(){var key=keys.next();return Map.entry(key,get(key));}};}
        });}
    }
    public MetadataSnapshot withCoverage(long revision,Map<MetadataScope,MetadataCoverage> coverage){return new MetadataSnapshot(this,revision,sessionResolution,Map.copyOf(coverage));}
    /** Physical header mismatch withholds authority without copying or rekeying
     * the captured catalog. Only the platform validates the physical owner. */
    public MetadataSnapshot withIdentifierAvailability(boolean available){return identifierAvailable==(available&&rules.complete())?this:new MetadataSnapshot(this,revision,sessionResolution,coverage,available);}
    public boolean identifierRulesAvailable(){return identifierAvailable;}
    /** Fresh catalog name evidence may coexist with retained stale structure.
     * This does not certify physical TEMP resolution, columns or editability.
     * Direct namespace/point keys keep the check independent of catalog size. */
    public boolean nameAvailable(MetadataObject object){
        if(object==null||!identifierRulesAvailable())return false;var i=object.identity();
        if(!rules.kindAvailable(i.kind())||identities.get(i.key())!=object||!i.parent().isEmpty()||!i.sessionOwner().isEmpty()||temporaryNamespace(i.schema())||"true".equals(object.properties().get("temporary")))return false;
        if(i.kind()!=ObjectKind.TABLE&&i.kind()!=ObjectKind.VIEW&&i.kind()!=ObjectKind.SEQUENCE||object.state()!=MetadataState.AVAILABLE&&object.state()!=MetadataState.STALE)return false;
        if(nameCoverage(i,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED))return true;
        if(i.subtype()!=ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED&&nameCoverage(i,"",i.subtype()))return true;
        return !i.signature().isEmpty()&&(nameCoverage(i,i.signature(),ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED)||i.subtype()!=ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED&&nameCoverage(i,i.signature(),i.subtype()));
    }
    private boolean nameCoverage(MetadataIdentity identity,String signature,ObjectSubtype subtype){
        return freshNames(coverage.get(new MetadataScope(identity.catalog(),identity.schema(),"",identity.kind(),"",false,signature,subtype)))
            ||freshNames(coverage.get(new MetadataScope(identity.catalog(),identity.schema(),"",identity.kind(),identity.name(),true,signature,subtype)));
    }
    private static boolean freshNames(MetadataCoverage state){return state!=null&&state.state()==MetadataState.AVAILABLE&&state.complete()&&state.level().includes(IntrospectionLevel.NAMES);}
    public SessionResolution sessionResolution(){return sessionResolution;}
    private RelationName relationName(String catalog,String schema,String name){return new RelationName(rules.lookup(ObjectKind.CATALOG,catalog,true),rules.lookup(ObjectKind.SCHEMA,schema,true),rules.lookup(ObjectKind.TABLE,name,true));}
    private boolean temporaryNamespace(String schema){return schema.equals("pg_temp")||schema.startsWith("pg_temp_");}
    /** Evidence for a persistent generated target or retained base relation. */
    public boolean relationResolutionAvailable(String catalog,String schema,String name,String sessionId){
        if(!identifierRulesAvailable())return false;
        if(!sessionResolution.sessionId().isEmpty()&&!sessionResolution.sessionId().equals(sessionId))return false;
        if(sessionResolution.state()==MetadataState.AVAILABLE)return true;
        if(rules.engine()==Engine.POSTGRESQL&&!temporaryNamespace(schema))return true;
        return sessionResolution.verified().get(relationName(catalog,schema,name))==PhysicalRelationKind.PERSISTENT;
    }
    /** Whether a cached candidate is the physically observed relation, rather
     * than an identically named persistent object hidden by a temporary table. */
    public boolean relationMatchesResolution(String catalog,String schema,String name,String candidateSessionOwner){
        if(!identifierRulesAvailable())return false;
        if(sessionResolution.state()==MetadataState.AVAILABLE)return true;
        if(rules.engine()==Engine.POSTGRESQL&&!temporaryNamespace(schema))return candidateSessionOwner.isEmpty();
        var kind=sessionResolution.verified().get(relationName(catalog,schema,name));
        return kind==PhysicalRelationKind.PERSISTENT?candidateSessionOwner.isEmpty():kind==PhysicalRelationKind.TEMPORARY&&!candidateSessionOwner.isEmpty()&&candidateSessionOwner.equals(sessionResolution.sessionId());
    }
    public boolean relationLookupAvailable(String catalog,String schema,String name,boolean qualified){
        if(!identifierRulesAvailable())return false;
        if(sessionResolution.state()==MetadataState.AVAILABLE)return true;
        if(rules.engine()==Engine.POSTGRESQL)return qualified&&!temporaryNamespace(schema);
        return sessionResolution.verified().containsKey(relationName(catalog,schema,name));
    }
    /** Catalog coverage and physical-session name visibility are distinct.
     * A broad durable enumeration cannot prove absence of unknown temp names. */
    public boolean scopeResolutionAvailable(MetadataScope scope){
        if(!identifierRulesAvailable()||!rules.kindAvailable(scope.kind()))return false;
        if(sessionResolution.state()==MetadataState.AVAILABLE)return true;
        if(rules.engine()==Engine.POSTGRESQL)return !scope.schema().isEmpty()&&!temporaryNamespace(scope.schema());
        if(!Set.of(ObjectKind.TABLE,ObjectKind.VIEW,ObjectKind.COLUMN,ObjectKind.INDEX,ObjectKind.CONSTRAINT,ObjectKind.FOREIGN_KEY,ObjectKind.TRIGGER).contains(scope.kind()))return true;
        String table=!scope.parent().isEmpty()?scope.parent():scope.exactName()?scope.search():"";
        if(scope.catalog().isEmpty()||scope.schema().isEmpty()||table.isEmpty())return false;
        if(relationResolutionAvailable(scope.catalog(),scope.schema(),table,sessionResolution.sessionId()))return true;
        return ownedRelationAvailable(scope.catalog(),scope.schema(),table,scope.kind()!=ObjectKind.TABLE&&scope.kind()!=ObjectKind.VIEW);
    }
    public boolean ownedRelationAvailable(String catalog,String schema,String table,boolean structure){
        if(!identifierRulesAvailable())return false;
        var key=relationName(catalog,schema,table);var evidence=sessionResolution.owned().get(key);if(evidence==null||sessionResolution.verified().get(key)!=PhysicalRelationKind.TEMPORARY)return false;
        if(identities.get(evidence.relation().identity().key())!=evidence.relation()||coverage.get(evidence.namesScope())!=evidence.names()||!evidence.names().complete())return false;
        return !structure||evidence.columns()!=null&&coverage.get(evidence.columnsScope())==evidence.columns()&&evidence.columns().complete()&&evidence.columns().level().includes(IntrospectionLevel.STRUCTURE);
    }
    public static MetadataSnapshot empty(String source,String profile,IdentifierRules rules){return empty(source,profile,rules,1);}
    public static MetadataSnapshot empty(String source,String profile,IdentifierRules rules,long configuration){if(configuration<1)throw new IllegalArgumentException("Metadata configuration revision must be positive");return new MetadataSnapshot(source,profile,0,configuration,System.currentTimeMillis(),rules,List.of(),Map.of());}
    public String source(){return source;}public String profileId(){return profileId;}public long revision(){return revision;}
    public long configurationRevision(){return configurationRevision;}public long createdUnixMs(){return createdUnixMs;}public long estimatedBytes(){return estimatedBytes;}
    public IdentifierRules rules(){return rules;}public Map<String,MetadataObject> identities(){return identities;}
    /** Raw immutable acquisition evidence for publication/storage writers. */
    public Map<MetadataScope,MetadataCoverage> catalogCoverage(){return coverage;}
    /** Session-visible coverage is projected lazily, without copying all scopes. */
    public Map<MetadataScope,MetadataCoverage> coverage(){
        if(sessionResolution.state()==MetadataState.AVAILABLE&&identifierRulesAvailable()&&rules.kindAvailable(ObjectKind.TRIGGER))return coverage;
        return Collections.unmodifiableMap(new AbstractMap<>(){
            @Override public MetadataCoverage get(Object key){return key instanceof MetadataScope scope?resolutionCoverage(scope,coverage.get(scope)):null;}
            @Override public int size(){return coverage.size();}
            @Override public Set<Entry<MetadataScope,MetadataCoverage>> entrySet(){return new AbstractSet<>(){
                @Override public int size(){return coverage.size();}
                @Override public Iterator<Entry<MetadataScope,MetadataCoverage>> iterator(){var values=coverage.entrySet().iterator();return new Iterator<>(){public boolean hasNext(){return values.hasNext();}public Entry<MetadataScope,MetadataCoverage> next(){var entry=values.next();return Map.entry(entry.getKey(),resolutionCoverage(entry.getKey(),entry.getValue()));}};}
            };}
        });
    }
    private MetadataCoverage resolutionCoverage(MetadataScope scope,MetadataCoverage state){
        if(state==null)return null;
        if(!identifierRulesAvailable())return new MetadataCoverage(scope,state.level(),state.state()==MetadataState.AVAILABLE?MetadataState.UNAVAILABLE:state.state(),false,state.fingerprint(),state.sourceRevision(),state.contextRevision(),state.refreshedUnixMs(),"Native identifier comparison evidence is unavailable",state.defaultNamespace());
        if(!rules.kindAvailable(scope.kind()))return new MetadataCoverage(scope,state.level(),MetadataState.UNSUPPORTED,false,state.fingerprint(),state.sourceRevision(),state.contextRevision(),state.refreshedUnixMs(),"Native identifier resolution is unsupported for this object kind and observed server filesystem",state.defaultNamespace());
        return scopeResolutionAvailable(scope)?state:new MetadataCoverage(scope,state.level(),MetadataState.UNKNOWN,false,state.fingerprint(),state.sourceRevision(),state.contextRevision(),state.refreshedUnixMs(),sessionResolution.limitation(),state.defaultNamespace());
    }
    public List<SchemaObject> objects(){return objects;}
    public SchemaObject projection(MetadataObject object){
        var i=object.identity();var projected=object.projection(revision,configurationRevision,parents.getOrDefault(new Relation(i.catalog(),i.schema(),i.parent()),""));
        if(!identifierRulesAvailable())return projected.toBuilder().setMetadataState(object.state()==MetadataState.AVAILABLE?MetadataState.UNAVAILABLE.name():object.state().name()).build();
        if(!rules.kindAvailable(i.kind()))return projected.toBuilder().setMetadataState(MetadataState.UNSUPPORTED.name()).build();
        if(sessionResolution.state()==MetadataState.AVAILABLE)return projected;
        var scope=i.parent().isEmpty()?new MetadataScope(i.catalog(),i.schema(),"",i.kind(),i.name(),true,i.signature(),i.subtype()):new MetadataScope(i.catalog(),i.schema(),i.parent(),i.kind());
        return scopeResolutionAvailable(scope)?projected:projected.toBuilder().setMetadataState(MetadataState.UNKNOWN.name()).build();
    }
    public Optional<MetadataObject> identity(String identity){return Optional.ofNullable(identities.get(identity));}
    public List<MetadataObject> namespace(String catalog,String schema,ObjectKind kind,String parent){return namespaces.getOrDefault(new Namespace(catalog,schema,kind,parent),List.of());}
    /** Reuses namespace lists; there is no second catalog-sized kind index. */
    public Iterable<MetadataObject> kind(ObjectKind kind){return ()->new Iterator<>(){private final Iterator<List<MetadataObject>> branches=kinds.getOrDefault(kind,List.of()).iterator();private Iterator<MetadataObject> current=Collections.emptyIterator();@Override public boolean hasNext(){while(!current.hasNext()&&branches.hasNext())current=branches.next().iterator();return current.hasNext();}@Override public MetadataObject next(){if(!hasNext())throw new NoSuchElementException();return current.next();}};}
    @SuppressWarnings("unchecked")
    public List<MetadataObject> resolve(String catalog,String schema,ObjectKind kind,String parent,String name,boolean quoted){var namespace=names.get(new Namespace(catalog,schema,kind,parent));return namespace==null?List.of():resolve(namespace,kind,name,quoted);}
    @SuppressWarnings("unchecked")
    private List<MetadataObject> resolve(Map<String,Object> namespace,ObjectKind kind,String name,boolean quoted){
        if(kind!=ObjectKind.CONSTRAINT){var value=namespace.get(rules.lookup(kind,name,quoted));return value==null?List.of():value instanceof MetadataObject object?List.of(object):(List<MetadataObject>)value;}
        var result=new ArrayList<MetadataObject>();var seen=new HashSet<String>();
        for(String key:List.of(rules.lookup(kind,name,quoted),rules.lookup(kind,name,quoted,"FOREIGN KEY"))){
            var value=namespace.get(key);var found=value==null?List.<MetadataObject>of():value instanceof MetadataObject object?List.of(object):(List<MetadataObject>)value;
            for(var object:found)if(seen.add(object.identity().key())&&rules.matches(kind,object.identity().name(),name,quoted,object.properties().getOrDefault("type","")))result.add(object);
        }
        return List.copyOf(result);
    }
    /** Exact-name lookup across existing namespace indexes, without a global duplicate index. */
    public Iterable<MetadataObject> resolveName(ObjectKind kind,String name,boolean quoted){
        String lookup=rules.lookup(kind,name,quoted);return ()->new Iterator<>(){
            final Iterator<List<MetadataObject>> branches=kinds.getOrDefault(kind,List.of()).iterator();Iterator<MetadataObject> current=Collections.emptyIterator();
            @SuppressWarnings("unchecked") public boolean hasNext(){while(!current.hasNext()&&branches.hasNext()){var branch=branches.next();if(branch.isEmpty())continue;var i=branch.getFirst().identity();var namespace=names.get(new Namespace(i.catalog(),i.schema(),kind,""));if(namespace==null)continue;if(kind==ObjectKind.CONSTRAINT){current=resolve(namespace,kind,name,quoted).iterator();continue;}var found=namespace.get(lookup);current=found instanceof MetadataObject object?List.of(object).iterator():found instanceof List<?> values?((List<MetadataObject>)values).iterator():Collections.emptyIterator();}return current.hasNext();}
            public MetadataObject next(){if(!hasNext())throw new NoSuchElementException();return current.next();}
        };
    }
    @SuppressWarnings("unchecked")
    private static void indexName(Map<Namespace,Map<String,Object>> index,Namespace namespace,MetadataObject entry){
        var names=index.computeIfAbsent(namespace,k->new HashMap<>());var previous=names.putIfAbsent(entry.lookupKey(),entry);
        if(previous instanceof MetadataObject object){var duplicates=new ArrayList<MetadataObject>();duplicates.add(object);duplicates.add(entry);names.put(entry.lookupKey(),duplicates);}
        else if(previous instanceof List<?> duplicates)((List<MetadataObject>)duplicates).add(entry);
    }
    public Optional<MetadataCoverage> coverage(MetadataScope scope){return Optional.ofNullable(resolutionCoverage(scope,coverage.get(scope)));}
    public boolean complete(MetadataScope scope,IntrospectionLevel level){var c=coverage.get(scope);return scopeResolutionAvailable(scope)&&c!=null&&c.complete()&&c.level().includes(level);}
    public List<MetadataObject> select(MetadataScope scope) {
        if(!scope.catalog().isEmpty()&&!scope.schema().isEmpty())return namespace(scope.catalog(),scope.schema(),scope.kind(),scope.parent()).stream().filter(scope::contains).toList();
        return identities.values().stream().filter(scope::contains).sorted(Comparator.comparing((MetadataObject o)->o.identity().name()).thenComparing(o->o.identity().parent()).thenComparing(o->o.identity().signature())).toList();
    }
    public List<MetadataObject> outgoing(String catalog,String schema,String table){return namespace(catalog,schema,ObjectKind.FOREIGN_KEY,table);}
    public List<MetadataObject> incoming(String catalog,String schema,String table){
        return incoming.getOrDefault(new Relation(catalog,schema,table),List.of());
    }
    public boolean outgoingComplete(String catalog,String schema,String table){return relationResolutionAvailable(catalog,schema,table,sessionResolution.sessionId())&&complete(new MetadataScope(catalog,schema,table,ObjectKind.FOREIGN_KEY),IntrospectionLevel.STRUCTURE);}
    /** A cached FK object alone is not fresh evidence after its scope is stale. */
    public boolean relationshipComplete(MetadataObject relationship){
        var identity=relationship.identity();var properties=relationship.properties();
        if(identity.kind()!=ObjectKind.FOREIGN_KEY||identities.get(identity.key())!=relationship||relationship.state()!=MetadataState.AVAILABLE||!relationship.level().includes(IntrospectionLevel.STRUCTURE)||!"true".equals(properties.get("relationshipVerified")))return false;
        if(!outgoingComplete(identity.catalog(),identity.schema(),identity.parent()))return false;
        String catalog=properties.getOrDefault("referencedCatalog",""),schema=properties.getOrDefault("referencedSchema",""),table=properties.getOrDefault("referencedTable","");
        if(catalog.isEmpty()||schema.isEmpty()||table.isEmpty())return false;
        var source=resolve(identity.catalog(),identity.schema(),ObjectKind.TABLE,"",identity.parent(),true);var target=resolve(catalog,schema,ObjectKind.TABLE,"",table,true);
        if(source.size()!=1||target.size()!=1||!structural(source.getFirst())||!structural(target.getFirst()))return false;
        if(!relationMatchesResolution(identity.catalog(),identity.schema(),identity.parent(),source.getFirst().identity().sessionOwner())||!relationMatchesResolution(catalog,schema,table,target.getFirst().identity().sessionOwner()))return false;
        if(!source.getFirst().identity().sessionOwner().equals(identity.sessionOwner())||!target.getFirst().identity().sessionOwner().isEmpty()&&!target.getFirst().identity().sessionOwner().equals(identity.sessionOwner()))return false;
        if(!complete(new MetadataScope(identity.catalog(),identity.schema(),identity.parent(),ObjectKind.COLUMN),IntrospectionLevel.STRUCTURE)||!complete(new MetadataScope(catalog,schema,table,ObjectKind.COLUMN),IntrospectionLevel.STRUCTURE))return false;
        final int count;try{count=Integer.parseInt(properties.getOrDefault("columnCount","0"));}catch(NumberFormatException invalid){return false;}
        if(count<1||count>128)return false;
        for(int index=0;index<count;index++){
            String own=properties.getOrDefault("column."+index,""),referenced=properties.getOrDefault("referencedColumn."+index,"");if(own.isEmpty()||referenced.isEmpty())return false;
            var ownColumns=resolve(identity.catalog(),identity.schema(),ObjectKind.COLUMN,identity.parent(),own,true);var targetColumns=resolve(catalog,schema,ObjectKind.COLUMN,table,referenced,true);
            if(ownColumns.size()!=1||targetColumns.size()!=1||!structural(ownColumns.getFirst())||!structural(targetColumns.getFirst()))return false;
            if(!ownColumns.getFirst().identity().sessionOwner().equals(source.getFirst().identity().sessionOwner())||!targetColumns.getFirst().identity().sessionOwner().equals(target.getFirst().identity().sessionOwner()))return false;
        }
        return true;
    }
    private static boolean structural(MetadataObject object){return object.state()==MetadataState.AVAILABLE&&object.level().includes(IntrospectionLevel.STRUCTURE);}
    public boolean incomingComplete() {
        if(!identifierRulesAvailable())return false;
        if(sessionResolution.state()!=MetadataState.AVAILABLE)return false;
        boolean found=false;
        for(var state:coverage.values())if(state.scope().kind()==ObjectKind.TABLE&&state.scope().parent().isEmpty()&&state.scope().broad()) {
            found=true;if(!state.complete())return false;
            for(var relation:select(state.scope())){if(!outgoingComplete(relation.identity().catalog(),relation.identity().schema(),relation.identity().name()))return false;for(var relationship:outgoing(relation.identity().catalog(),relation.identity().schema(),relation.identity().name()))if(!relationshipComplete(relationship))return false;}
        }
        return found;
    }
}
