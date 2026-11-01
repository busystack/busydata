package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.sessions.SessionRegistry;
import java.nio.file.Path;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;

/** One metadata authority per backend. Refresh writers never lock snapshot readers. */
public final class MetadataPlatform {
    private static final String RULES_CHANGED="Native identifier comparison evidence changed; reconcile this scope";
    public static final class SupersededRefresh extends IllegalStateException {public SupersededRefresh(){super("Metadata refresh ownership was superseded by a newer request or publication");}}
    public enum RefreshMode { FULL, FRAGMENT, INCREMENTAL, SMART }
    public record Branch(List<SchemaObject> objects,MetadataCoverage coverage,List<MetadataObject> normalized,boolean reuse){
        public Branch(List<SchemaObject> objects,MetadataCoverage coverage){this(objects,coverage,List.of(),false);}
        public Branch{objects=List.copyOf(objects);normalized=List.copyOf(normalized);if(reuse&&(!objects.isEmpty()||!normalized.isEmpty()))throw new IllegalArgumentException("Reused metadata branch cannot contain replacement data");}
        public static Branch reused(MetadataCoverage coverage){return new Branch(List.of(),coverage,List.of(),true);}
    }
    public record RefreshDiagnostics(RefreshMode mode,long scannedScopes,long fetchedScopes,long fetchedObjects,long removedObjects,long durationMs,String strategy){}
    /** A durable-publication token cannot be confused with a session overlay revision. */
    public static final class PublicationRevision {
        private final String source;private final long owner,revision;
        private PublicationRevision(String source,long owner,long revision){this.source=source;this.owner=owner;this.revision=revision;}
        public long owner(){return owner;}
        public long revision(){return revision;}
    }
    /** Immutable queue admission; contains no snapshot or catalog references. */
    public static final class QueuedRefreshOwner {
        private final PublicationRevision publication;
        private final String session;
        private final long reservation,requestEpoch,configuration,revision,context;
        private QueuedRefreshOwner(PublicationRevision publication,String session,long reservation,long requestEpoch,long configuration,long revision,long context){this.publication=publication;this.session=session;this.reservation=reservation;this.requestEpoch=requestEpoch;this.configuration=configuration;this.revision=revision;this.context=context;}
    }
    /** One logical acquisition, reserved before its first dependency query. */
    public static final class RefreshReservation {
        private final QueuedRefreshOwner owner;
        private final long ticket;
        private final boolean queued;
        private RefreshReservation(QueuedRefreshOwner owner,long ticket,boolean queued){this.owner=owner;this.ticket=ticket;this.queued=queued;}
        public long revision(){return owner.revision;}
        public long contextRevision(){return owner.context;}
    }
    private static final AtomicLong sourceOwners=new AtomicLong(),externalTokens=new AtomicLong();
    public record ProofFence(String source,long owner,long epoch){}
    /** Bounded coordination only: no metadata snapshot or native process is retained. */
    public static final class ExternalMutation {
        private final String source,session;private final long owner,token,wave;private boolean released;
        private ExternalMutation(String source,String session,long owner,long token,long wave){this.source=source;this.session=session;this.owner=owner;this.token=token;this.wave=wave;}
        public long wave(){return wave;}
    }
    public record ExternalCompletion(QueuedRefreshOwner acknowledgement,long wave,boolean ready){}
    static final class Source {
        final long owner=sourceOwners.incrementAndGet();
        final java.util.concurrent.locks.ReentrantLock writer=new java.util.concurrent.locks.ReentrantLock(true);
        final AtomicReference<MetadataSnapshot> snapshot;final AtomicLong tickets=new AtomicLong();
        long configurationTicket,requestEpoch,publicationFloor,proofEpoch,externalWave,rulesTicket;
        volatile CacheGap cacheGap;volatile String cacheState="";volatile MetadataRepository.WriteFailure cacheFailure;volatile long cacheWriteNanos,cacheSubmissionDeadline;volatile CacheMetrics cacheMetrics;volatile MetadataRepository.WriteReceipt cacheAttempt;final AtomicInteger pendingCacheWrites=new AtomicInteger();
        volatile int externalActive;boolean externalTainted,externalRequiresExplicit,configurationPending;BootstrapBridge bootstrapBridge;
        QueuedRefreshOwner externalAck;
        final Map<Long,ExternalMutation> externalMutations=new HashMap<>();
        Map<MetadataScope,Long> published=Map.of();
        final Map<String,Map<MetadataScope,Long>> overlayPublished=new ConcurrentHashMap<>();
        final ConcurrentMap<String,java.lang.ref.WeakReference<SessionRegistry.Session>> physicalOwners=new ConcurrentHashMap<>();
        Source(MetadataSnapshot snapshot){this.snapshot=new AtomicReference<>(snapshot);}
    }
    private static final AtomicLong ownedRecordOwners=new AtomicLong();
    static long nextOwnedRecordOwner(AtomicLong owners){return owners.updateAndGet(value->{if(value==Long.MAX_VALUE)throw new IllegalStateException("Metadata owned-record identity exhausted");return value+1;});}
    private record Overlay(String source,long sessionRevision,long contextRevision,long baseRevision,Set<MetadataScope> scopes,MetadataSnapshot snapshot,long owner){
        private Overlay(String source,long sessionRevision,long contextRevision,long baseRevision,Set<MetadataScope> scopes,MetadataSnapshot snapshot){this(source,sessionRevision,contextRevision,baseRevision,scopes,snapshot,nextOwnedRecordOwner(ownedRecordOwners));}
    }
    record BootstrapBridge(long from,long to,long configuration,long request,long proof,String session,long context){}
    private record CacheGap(long revision,long configuration,String rules){}
    private record CacheMetrics(long sourceOwner,MetadataRepository.WriteIdentity identity,MetadataRepository.WriteMetrics metrics){}
    private record OverlayContents(Collection<MetadataObject> entries,Map<MetadataScope,MetadataCoverage> coverage,Set<MetadataScope> removed,String inheritedStale){}
    private record ResolutionOwner(String source,MetadataSnapshot.SessionResolution state,String rulesFingerprint,long owner){
        private ResolutionOwner(String source,MetadataSnapshot.SessionResolution state,String rulesFingerprint){this(source,state,rulesFingerprint,nextOwnedRecordOwner(ownedRecordOwners));}
    }
    private record CapturedView(java.lang.ref.WeakReference<MetadataSnapshot> base,java.lang.ref.WeakReference<MetadataSnapshot.SessionResolution> state,long revision,java.lang.ref.WeakReference<MetadataSnapshot> view,MetadataSnapshot emptyBase){}
    private final AtomicLong resolutionEpochs=new AtomicLong(),viewRevisions=new AtomicLong();
    private final ConcurrentMap<String,ResolutionOwner> sessionResolutions=new ConcurrentHashMap<>();
    private final ConcurrentMap<String,CapturedView> sessionViews=new ConcurrentHashMap<>();
    public static final long MAX_TOTAL_BYTES=128L*1024*1024;
    private final Object admissionLock=new Object();
    private final Map<AcquisitionAdmission,Long> acquisitions=new IdentityHashMap<>();
    public final class AcquisitionAdmission implements AutoCloseable {
        private boolean closed,compositionSealed;
        private final Map<MetadataObject,Long> reservedObjects=new IdentityHashMap<>();
        private final Map<Object,Long> layouts=new IdentityHashMap<>();
        private final Set<IdentifierRules> ruleEvidence=Collections.newSetFromMap(new IdentityHashMap<>());
        private AcquisitionAdmission(){synchronized(admissionLock){if(acquisitions.size()>=32)throw new IllegalStateException("Metadata acquisition admission limit reached");acquisitions.put(this,0L);}}
        private void open(){if(closed||compositionSealed)throw new IllegalStateException("Metadata acquisition is closed or already prepared");}
        void reserve(MetadataObject object){synchronized(admissionLock){
            open();if(reservedObjects.containsKey(object))return;long objectBytes=object.estimatedBytes(),layoutBytes=0;Object layout=null;
            if(object.properties() instanceof CompactProperties compact&&!layouts.containsKey(compact.layoutIdentity())){layout=compact.layoutIdentity();layoutBytes=compact.layoutBytes();}
            long total=residentEstimate();for(long pending:acquisitions.values())total+=pending;
            if(total+objectBytes+layoutBytes>MAX_TOTAL_BYTES)throw new IllegalStateException("Metadata resident and in-flight semantic admission limit (128MiB) reached");
            reservedObjects.put(object,objectBytes);if(layout!=null)layouts.put(layout,layoutBytes);acquisitions.put(this,acquisitions.get(this)+objectBytes+layoutBytes);
        }}
        void reserveOwnedObject(MetadataObject object){reserve(object);}
        /** Transfer only final candidate facts/layouts, including ones reserved
         * by normalizedBranch before the owned planner saw their references. */
        void reserveComposition(long allocation,Collection<MetadataObject> facts){synchronized(admissionLock){
            open();if(allocation<0)throw new IllegalArgumentException("Invalid owned allocation");long transfer=0;var objectRefs=Collections.newSetFromMap(new IdentityHashMap<MetadataObject,Boolean>());var layoutRefs=Collections.newSetFromMap(new IdentityHashMap<Object,Boolean>());
            for(var fact:facts){if(objectRefs.add(fact))transfer+=reservedObjects.getOrDefault(fact,0L);if(fact.properties() instanceof CompactProperties compact&&layoutRefs.add(compact.layoutIdentity()))transfer+=layouts.getOrDefault(compact.layoutIdentity(),0L);}
            long retained=acquisitions.get(this)-transfer,total=residentEstimate();for(var entry:acquisitions.entrySet())if(entry.getKey()!=this)total+=entry.getValue();
            if(retained<0||total+retained+allocation>MAX_TOTAL_BYTES)throw new IllegalStateException("Metadata resident and prepared owned composition exceed128MiB");
            for(var fact:objectRefs)reservedObjects.remove(fact);for(var layout:layoutRefs)layouts.remove(layout);
            acquisitions.put(this,retained+allocation);compositionSealed=true;
        }}
        /** Replace temporary normalization references with the compact evidence
         * retained by one operation. This is not a metadata publication. */
        void sealInspection(long bytes){synchronized(admissionLock){
            open();if(bytes<0||bytes>MAX_TOTAL_BYTES)throw new IllegalStateException("Owned inspection evidence exceeds metadata admission");
            long total=residentEstimate();for(var entry:acquisitions.entrySet())if(entry.getKey()!=this)total+=entry.getValue();
            if(total+bytes>MAX_TOTAL_BYTES)throw new IllegalStateException("Owned inspection and resident metadata exceed128MiB");
            acquisitions.put(this,bytes);compositionSealed=true;reservedObjects.clear();layouts.clear();ruleEvidence.clear();
        }}
        void reserveAdditional(long allocation){synchronized(admissionLock){if(closed||allocation<0)throw new IllegalStateException("Metadata allocation admission is invalid");long total=residentEstimate();for(long pending:acquisitions.values())total+=pending;if(total+allocation>MAX_TOTAL_BYTES)throw new IllegalStateException("Metadata resident and in-flight index admission limit reached");acquisitions.put(this,acquisitions.get(this)+allocation);}}
        void committed(){synchronized(admissionLock){if(closed)throw new IllegalStateException("Metadata acquisition admission is closed");acquisitions.put(this,0L);compositionSealed=false;reservedObjects.clear();layouts.clear();ruleEvidence.clear();}}
        public void reserveRules(IdentifierRules rules){synchronized(admissionLock){open();if(ruleEvidence.contains(rules))return;long total=residentEstimate();for(long pending:acquisitions.values())total+=pending;if(total+rules.estimatedBytes()>MAX_TOTAL_BYTES)throw new IllegalStateException("Metadata identifier evidence exceeds resident and acquisition admission");ruleEvidence.add(rules);acquisitions.put(this,acquisitions.get(this)+rules.estimatedBytes());}}
        @Override public void close(){synchronized(admissionLock){closed=true;acquisitions.remove(this);reservedObjects.clear();layouts.clear();ruleEvidence.clear();}}
    }
    public AcquisitionAdmission admitAcquisition(){return new AcquisitionAdmission();}
    private long residentEstimate(){long bytes=0;for(var owner:sources.values())bytes+=owner.snapshot.get().estimatedBytes();for(var overlay:overlays.values())bytes+=overlay.snapshot().estimatedBytes();for(var resolution:sessionResolutions.values())bytes+=resolution.state().estimatedBytes();return bytes;}
    private final MetadataRepository repository;
    private final io.busystack.busydata.storage.MetadataStore preferences;
    private final Runnable beforeCommit;
    private final AtomicInteger pendingCacheWrites=new AtomicInteger();
    private final ConcurrentMap<String,Source> sources=new ConcurrentHashMap<>();
    private final ConcurrentMap<String,MetadataConfiguration> configurations=new ConcurrentHashMap<>();
    private final ConcurrentMap<String,Overlay> overlays=new ConcurrentHashMap<>();
    private final ConcurrentMap<String,RefreshDiagnostics> diagnostics=new ConcurrentHashMap<>();
    private final ThreadLocal<String> ownedMaintenance=new ThreadLocal<>();
    /** Only synchronous Smart session-overlay maintenance uses this scope.
     * Its tickets still supersede old attempts, but cannot masquerade as a
     * newer explicit request when the next real job settlement admits intent. */
    public final class OwnedMaintenance implements AutoCloseable {
        private final Thread thread=Thread.currentThread();private boolean closed;
        private OwnedMaintenance(SessionRegistry.Session session){requireResolutionOwner(session);if(ownedMaintenance.get()!=null)throw new IllegalStateException("Nested metadata maintenance is unavailable");ownedMaintenance.set(session.id);}
        @Override public void close(){if(Thread.currentThread()!=thread)throw new IllegalStateException("Metadata maintenance owner changed");if(!closed){closed=true;ownedMaintenance.remove();}}
    }
    public OwnedMaintenance ownedMaintenance(SessionRegistry.Session session){return new OwnedMaintenance(session);}
    private final ConcurrentMap<String,CompletableFuture<MetadataSnapshot>> refreshing=new ConcurrentHashMap<>();
    public MetadataPlatform(){repository=null;preferences=null;beforeCommit=()->{};}
    public MetadataPlatform(Path root)throws Exception {this(root,()->{});}
    MetadataPlatform(Path root,Runnable beforeCommit)throws Exception {
        preferences=null;this.beforeCommit=Objects.requireNonNull(beforeCommit);
        repository=new MetadataRepository(root);
        for(var snapshot:repository.loadNewest(Map.of()))sources.put(snapshot.source(),new Source(snapshot));
    }
    public MetadataPlatform(io.busystack.busydata.storage.MetadataStore storage)throws Exception {
        this(storage,new MetadataRepository(storage.root()));
    }
    MetadataPlatform(io.busystack.busydata.storage.MetadataStore storage,MetadataRepository repository)throws Exception {
        preferences=storage;beforeCommit=()->{};this.repository=Objects.requireNonNull(repository);
        configurations.putAll(storage.metadataConfigurations());
        for(var snapshot:repository.loadNewest(configurations))sources.put(snapshot.source(),new Source(snapshot));
    }
    // Eight console handles plus the existing two independent metadata slots.
    private static final int MAX_SOURCE_PHYSICAL_OWNERS=10;
    /** Called only under this exact Source guard. Weak records retain neither
     * the physical connection nor credentials; every real owner is registered. */
    private static boolean physicalOwners(Source source){
        source.physicalOwners.entrySet().removeIf(entry->{var owner=entry.getValue().get();return owner==null||owner.physicalEnded();});return !source.physicalOwners.isEmpty();
    }
    private Source attachPhysicalOwner(SessionRegistry.Session session,String key,Source source){
        synchronized(source){
            if(sources.get(key)!=source)return null;
            physicalOwners(source);
            if(!session.physicalEnded()){
                var registered=source.physicalOwners.get(session.id);var prior=registered==null?null:registered.get();
                if(prior!=null&&prior!=session)throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.INVALID_OWNER);
                if(prior==null){if(source.physicalOwners.size()>=MAX_SOURCE_PHYSICAL_OWNERS)throw new IllegalStateException("Metadata physical-owner admission limit reached");source.physicalOwners.put(session.id,new java.lang.ref.WeakReference<>(session));}
            }
            return source;
        }
    }
    private boolean evictable(String key,Source source){return !physicalOwners(source)&&source.externalActive==0&&!source.writer.isLocked()&&source.pendingCacheWrites.get()==0&&overlays.values().stream().noneMatch(overlay->overlay.source().equals(key));}
    private Source source(SessionRegistry.Session session) {
        String key=session.metadataSourceIdentity,sessionId=session.id;
        // Register before taking Source/sources locks. An immediate physical-end
        // callback carries scalar identities only and cannot resurrect a pin.
        session.onPhysicalEnd(this,()->endSession(sessionId,key));
        var known=sources.get(key);if(known!=null){var attached=attachPhysicalOwner(session,key,known);if(attached!=null)return attached;}
        synchronized(sources) {
            known=sources.get(key);if(known!=null)return attachPhysicalOwner(session,key,known);
            if(sources.size()>=8) {
                boolean removed=false;
                // Only eviction takes sources -> Source. Attaching to a known
                // Source takes that Source alone and rechecks exact membership.
                for(var candidate:sources.entrySet().stream().sorted(Comparator.comparingLong(entry->entry.getValue().snapshot.get().createdUnixMs())).toList()){
                    var retiring=candidate.getValue();synchronized(retiring){
                        if(sources.get(candidate.getKey())==retiring&&evictable(candidate.getKey(),retiring)){sources.remove(candidate.getKey(),retiring);removed=true;break;}
                    }
                }
                if(!removed)throw new IllegalStateException("Metadata source admission limit reached");
            }
            var state=new Source(MetadataSnapshot.empty(key,session.profile.getId(),new IdentifierRules(session.profile.getEngine(),0),configuration(session).revision()));sources.put(key,state);return attachPhysicalOwner(session,key,state);
        }
    }
    /** No live JDBC and no internal SQLite access. The same instance is reused until publication. */
    public MetadataSnapshot capture(SessionRegistry.Session session) {
        return resolutionView(session,captureBase(session));
    }
    private MetadataSnapshot captureBase(SessionRegistry.Session session) {
        if(session.physicalEnded()||session.state==TransactionState.DISCONNECTED){endSession(session.id,session.metadataSourceIdentity);return MetadataSnapshot.empty(session.metadataSourceIdentity,session.profile.getId(),new IdentifierRules(session.profile.getEngine(),0),configuration(session).revision());}
        if(session.state==TransactionState.UNKNOWN_TRANSACTION){var previous=sessionViews.get(session.id);if(previous!=null&&previous.emptyBase()!=null&&previous.emptyBase().configurationRevision()==configuration(session).revision())return previous.emptyBase();return MetadataSnapshot.empty(session.metadataSourceIdentity,session.profile.getId(),new IdentifierRules(session.profile.getEngine(),0),configuration(session).revision());}
        long deadline=System.nanoTime()+TimeUnit.MILLISECONDS.toNanos(100);String key=session.metadataSourceIdentity;
        for(int attempt=0;attempt<4;attempt++){
            var owner=source(session);MetadataSnapshot snapshot;Overlay overlay;
            synchronized(owner){
                snapshot=owner.snapshot.get();overlay=overlays.get(session.id);
                if(sources.get(key)!=owner)continue;
                if(overlay==null)return snapshot;
                if(!overlay.source().equals(snapshot.source())||overlay.sessionRevision()>session.revision){overlays.remove(session.id,overlay);return snapshot;}
                if(overlay.baseRevision()==snapshot.revision())return overlay.snapshot();
            }
            // Real-index rebases belong to durable preparation, never a warm
            // reader. Inline invalidation can change only captured coverage.
            if(!overlay.snapshot().canRebaseCoverageOnto(snapshot))throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.STALE);
            try(var admission=admitAcquisition()){
                admission.reserveAdditional(4096L+32L*overlay.scopes().size());
                var merged=overlay.snapshot().rebaseComposed(snapshot,Math.max(snapshot.revision(),overlay.snapshot().revision())+1,snapshot.configurationRevision(),System.currentTimeMillis(),deadline);
                synchronized(admissionLock){synchronized(owner){
                    if(sources.get(key)!=owner||owner.snapshot.get()!=snapshot||overlays.get(session.id)!=overlay)continue;
                    if(session.physicalEnded()||session.state==TransactionState.DISCONNECTED||session.state==TransactionState.UNKNOWN_TRANSACTION)throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.STALE);
                    enforceBudget(key,session.id,merged.estimatedBytes(),true,admission);
                    overlays.put(session.id,new Overlay(key,session.revision,session.contextRevision,snapshot.revision(),overlay.scopes(),merged));admission.committed();return merged;
                }}
            }catch(TimeoutException expired){throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.TIMED_OUT,io.busystack.busydata.rpc.WorkbenchFailure.Origin.CAPTURE_REBASE);}
        }
        throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.STALE);
    }
    static MetadataSnapshot rebaseOverlay(MetadataSnapshot base,MetadataSnapshot overlay,Set<MetadataScope> scopes,String session){
        if(!overlay.composed())throw new IllegalArgumentException("An owned metadata composition is required");
        long revision=Math.max(base.revision(),overlay.revision())+1;
        try{
            if(base.rules().fingerprint().equals(overlay.rules().fingerprint()))return overlay.rebaseComposed(base,revision,base.configurationRevision(),System.currentTimeMillis(),Long.MAX_VALUE);
            var content=overlayContents(base,overlay,scopes,session);
            var next=MetadataSnapshot.compose(base,content.entries(),scopes,content.coverage(),content.removed(),revision,base.configurationRevision(),System.currentTimeMillis(),Long.MAX_VALUE);
            return content.inheritedStale().isEmpty()?next:next.withInheritedCoverageStale(revision,content.inheritedStale());
        }catch(TimeoutException impossible){throw new AssertionError(impossible);}
    }
    private static OverlayContents overlayContents(MetadataSnapshot base,MetadataSnapshot overlay,Set<MetadataScope> scopes,String session){
        if(!overlay.composed())throw new IllegalArgumentException("An owned metadata composition is required");
        boolean changedRules=!base.rules().fingerprint().equals(overlay.rules().fingerprint());var entries=new ArrayList<MetadataObject>();
        for(var object:overlay.localIdentities().values())if((object.identity().sessionOwner().isEmpty()||object.identity().sessionOwner().equals(session))&&scopes.stream().anyMatch(scope->scope.contains(object)))entries.add(object.withRules(base.rules()));
        var coverage=new HashMap<>(overlay.localCoverage());if(changedRules)coverage.replaceAll((scope,state)->state.stale(RULES_CHANGED));
        return new OverlayContents(List.copyOf(entries),Map.copyOf(coverage),overlay.removedCoverageScopes(),overlay.allCoverageStaleReason());
    }
    private static MetadataSnapshot.SessionResolution unknownRules(String session,long epoch){return new MetadataSnapshot.SessionResolution(MetadataState.UNKNOWN,session,Math.max(1,epoch),RULES_CHANGED,Map.of());}
    static MetadataSnapshot.SessionResolution ruleResolution(String session,MetadataSnapshot.SessionResolution state,String fingerprint,IdentifierRules rules){return fingerprint.equals(rules.fingerprint())?state:unknownRules(session,state.epoch());}
    private void retireRuleResolutions(String source,IdentifierRules rules){
        sessionResolutions.replaceAll((id,current)->current.source().equals(source)&&!current.rulesFingerprint().equals(rules.fingerprint())?new ResolutionOwner(source,unknownRules(id,resolutionEpochs.incrementAndGet()),rules.fingerprint()):current);
        for(var entry:overlays.entrySet())if(entry.getValue().source().equals(source)){
            var resolution=sessionResolutions.computeIfAbsent(entry.getKey(),id->new ResolutionOwner(source,unknownRules(id,resolutionEpochs.incrementAndGet()),rules.fingerprint()));
            var live=overlays.get(entry.getKey());if(live==null||!live.source().equals(source))sessionResolutions.remove(entry.getKey(),resolution);
        }
    }
    static Map<MetadataScope,MetadataCoverage> ruleCoverage(MetadataSnapshot before,IdentifierRules rules){
        var coverage=new HashMap<>(before.catalogCoverage());
        if(!before.rules().fingerprint().equals(rules.fingerprint()))coverage.replaceAll((scope,state)->state.stale(RULES_CHANGED));
        return coverage;
    }
    /** Rules affect every name index, even when refresh scopes are disjoint. */
    static void checkRulesPublication(Source owner,long ticket,IdentifierRules rules,boolean sessionOwned){
        var current=owner.snapshot.get().rules();boolean changed=!current.fingerprint().equals(rules.fingerprint());
        if(changed&&(sessionOwned||ticket<owner.rulesTicket||current.complete()&&!rules.complete()))throw new SupersededRefresh();
    }
    /** Candidate preparation succeeded; callers hold the short source monitor. */
    static boolean commitSnapshot(Source owner,long ticket,MetadataSnapshot next){
        if(!Thread.holdsLock(owner))throw new IllegalStateException("Metadata publication owner is required");
        checkRulesPublication(owner,ticket,next.rules(),false);
        boolean changed=!owner.snapshot.get().rules().fingerprint().equals(next.rules().fingerprint());
        owner.snapshot.set(next);owner.bootstrapBridge=null;if(changed){owner.rulesTicket=ticket;owner.proofEpoch++;}return changed;
    }
    static boolean identifierAffinity(IdentifierRules rules,IdentifierRules.ServerIdentity identity){return identity!=null&&rules.matchesServer(identity);}
    static void checkIdentifierAffinity(IdentifierRules rules,IdentifierRules.ServerIdentity identity){if(!identifierAffinity(rules,identity))throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.UNAVAILABLE);}
    private static long semanticBytes(IdentifierRules rules,Collection<MetadataObject> objects){
        long bytes=rules.estimatedBytes();var layouts=new IdentityHashMap<Object,Boolean>();
        for(var object:objects){bytes+=object.estimatedBytes();if(object.properties() instanceof CompactProperties compact&&layouts.put(compact.layoutIdentity(),Boolean.TRUE)==null)bytes+=compact.layoutBytes();if(bytes>MetadataSnapshot.MAX_BYTES)throw new IllegalStateException("Metadata snapshot semantic admission limit reached");}
        return bytes;
    }
    private MetadataSnapshot resolutionView(SessionRegistry.Session session,MetadataSnapshot base){
        boolean identifiers=base.identifierRulesAvailable()&&identifierAffinity(base.rules(),session.identifierContext);
        var found=sessionResolutions.get(session.id);
        if(found!=null&&!found.source().equals(base.source())){sessionResolutions.remove(session.id,found);sessionViews.remove(session.id);found=null;}
        if(found==null&&identifiers)return base;
        if(found!=null&&!found.rulesFingerprint().equals(base.rules().fingerprint())){
            // A concurrent opaque statement can publish its old-rule UNKNOWN
            // state after the writer retired anchors. Only the current durable
            // rule generation may replace that state; an older captured reader
            // must never erase newer physical evidence.
            var current=sources.get(base.source());
            if(current!=null&&current.snapshot.get().rules().fingerprint().equals(base.rules().fingerprint())){
                var retired=new ResolutionOwner(found.source(),unknownRules(session.id,resolutionEpochs.incrementAndGet()),base.rules().fingerprint());
                if(sessionResolutions.replace(session.id,found,retired))found=retired;
                else found=sessionResolutions.get(session.id);
            }
        }
        var state=found==null?base.sessionResolution():ruleResolution(session.id,found.state(),found.rulesFingerprint(),base.rules());
        var captured=new MetadataSnapshot[1];
        sessionViews.compute(session.id,(id,old)->{
            boolean unchanged=old!=null&&old.base().get()==base&&old.state().get()==state;
            if(unchanged){var retained=old.view().get();if(retained!=null){captured[0]=retained;return old;}}
            long revision=unchanged?old.revision():viewRevisions.updateAndGet(previous->Math.max(previous+1,base.revision()+1));
            captured[0]=base.withSessionResolution(revision,state).withIdentifierAvailability(identifiers);
            return new CapturedView(new java.lang.ref.WeakReference<>(base),new java.lang.ref.WeakReference<>(state),revision,new java.lang.ref.WeakReference<>(captured[0]),base.revision()==0&&base.identities().isEmpty()?base:null);
        });
        return captured[0];
    }
    /** Opaque effects cannot be reconciled by a connection which cannot see
     * this physical session's temporary objects. Never persist this fact. */
    public long markSessionResolutionUnknown(SessionRegistry.Session session,String reason){
        if(session.physicalEnded()||session.state==TransactionState.DISCONNECTED){endSession(session.id,session.metadataSourceIdentity);return 0;}
        source(session);String message=reason.length()>2048?reason.substring(0,2048):reason;
        long epoch=resolutionEpochs.incrementAndGet();
        sessionResolutions.put(session.id,new ResolutionOwner(session.metadataSourceIdentity,new MetadataSnapshot.SessionResolution(MetadataState.UNKNOWN,session.id,epoch,message,Map.of()),captureBase(session).rules().fingerprint()));
        if(session.physicalEnded())endSession(session.id,session.metadataSourceIdentity);
        return epoch;
    }
    public long sessionResolutionEpoch(SessionRegistry.Session session){var owner=sessionResolutions.get(session.id);return owner==null?0:owner.state().epoch();}
    private record TemporaryOwner(String source,String session,long sourceOwner,long durable,long overlay,long resolution,long epoch,long configuration,long revision,long context,long proof,long request,String rules,IdentifierRules.ServerIdentity nativeIdentity,String sqlMode){}
    /** A bounded pre-SHOW token. No full snapshot, Source, native map, or
     * unaccounted catalog lease crosses the owning physical read. */
    public static final class TemporaryObservation {
        private final TemporaryOwner owner;private final String catalog,schema,requested,canonical;
        private final NativeDefinitionEvidence definition;private final boolean completeShape;
        private TemporaryObservation(TemporaryOwner owner,String catalog,String schema,String requested,String canonical,NativeDefinitionEvidence definition,boolean completeShape){this.owner=owner;this.catalog=catalog;this.schema=schema;this.requested=requested;this.canonical=canonical;this.definition=definition;this.completeShape=completeShape;}
    }
    /** Capture before SHOW, so an observation cannot certify a shape first
     * acquired after the real native read. Pure central-model lookups only. */
    public TemporaryObservation temporaryObservation(SessionRegistry.Session session,String catalog,String schema,String name){
        requireResolutionOwner(session);if(session.profile.getEngine()==Engine.POSTGRESQL)throw new IllegalArgumentException("Native SHOW observation requires MySQL/MariaDB");
        for(String part:List.of(catalog,schema,name))if(part.isEmpty()||part.length()>256||part.indexOf(0)>=0)throw new IllegalArgumentException("Exact physical relation identity required");
        capture(session); // Complete any pure stale-rule retirement before anchoring.
        var current=source(session);String key=session.metadataSourceIdentity;Overlay anchoredOverlay;ResolutionOwner anchoredResolution;MetadataSnapshot anchoredDurable;
        synchronized(current){if(sources.get(key)!=current)throw temporaryStale();anchoredOverlay=overlays.get(session.id);anchoredResolution=sessionResolutions.get(session.id);anchoredDurable=current.snapshot.get();}
        var view=capture(session);
        synchronized(current){
            if(sources.get(key)!=current||overlays.get(session.id)!=anchoredOverlay||sessionResolutions.get(session.id)!=anchoredResolution||current.snapshot.get()!=anchoredDurable)throw temporaryStale();var overlay=anchoredOverlay;var resolution=anchoredResolution;
            var owner=new TemporaryOwner(key,session.id,current.owner,current.snapshot.get().revision(),overlay==null?0:overlay.owner(),resolution==null?0:resolution.owner(),resolution==null?0:resolution.state().epoch(),configuration(session).revision(),session.revision,session.contextRevision,current.proofEpoch,current.requestEpoch,current.snapshot.get().rules().fingerprint(),session.identifierContext,session.context.sqlMode());
            NativeDefinitionEvidence definition=NativeDefinitionEvidence.unavailable();String canonical="";boolean complete=false;
            if(view.identifierRulesAvailable()&&view.configurationRevision()==owner.configuration()&&view.ownedRelationAvailable(catalog,schema,name,true)&&proofAdmissionState(current,new ProofFence(key,current.owner,current.proofEpoch),session.identifierContext)==MetadataState.AVAILABLE){
                var relationKey=new MetadataSnapshot.RelationName(view.rules().lookup(ObjectKind.CATALOG,catalog,true),view.rules().lookup(ObjectKind.SCHEMA,schema,true),view.rules().lookup(ObjectKind.TABLE,name,true));
                var evidence=view.sessionResolution().owned().get(relationKey);var names=evidence.names();var columns=evidence.columns();var identity=evidence.relation().identity();
                definition=NativeDefinitionEvidence.from(evidence.relation().properties());canonical=identity.name();
                complete=identity.source().equals(key)&&identity.sessionOwner().equals(session.id)&&names.state()==MetadataState.AVAILABLE&&columns!=null&&columns.state()==MetadataState.AVAILABLE
                    &&names.contextRevision()==session.contextRevision&&columns.contextRevision()==session.contextRevision&&definition.complete()&&NativeDefinitionEvidence.sourceAvailability(session.profile.getEngine(),definition.sqlMode(),definition.renderer())==MetadataState.AVAILABLE&&definition.sqlMode().equals(session.context.sqlMode());
            }
            return new TemporaryObservation(owner,catalog,schema,name,canonical,definition,complete);
        }
    }
    private static io.busystack.busydata.rpc.WorkbenchFailure temporaryStale(){return new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.STALE);}
    /** The private record token changes even when a verified map is replaced
     * inside one resolution epoch. No equality-by-epoch shortcut is allowed. */
    public boolean temporaryObservationCurrent(SessionRegistry.Session session,TemporaryObservation observation,String catalog,String schema,String name){
        if(!session.lock.isHeldByCurrentThread())throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.INVALID_OWNER);
        if(observation==null||session.physicalEnded()||session.state==TransactionState.DISCONNECTED||session.state==TransactionState.UNKNOWN_TRANSACTION)return false;
        var before=observation.owner;if(!before.session().equals(session.id)||!before.source().equals(session.metadataSourceIdentity)||!observation.catalog.equals(catalog)||!observation.schema.equals(schema)||!observation.requested.equals(name))return false;
        var current=sources.get(before.source());if(current==null)return false;
        synchronized(current){var overlay=overlays.get(session.id);var resolution=sessionResolutions.get(session.id);
            return sources.get(before.source())==current&&current.owner==before.sourceOwner()&&current.snapshot.get().revision()==before.durable()
                &&(overlay==null?0:overlay.owner())==before.overlay()&&(resolution==null?0:resolution.owner())==before.resolution()&&(resolution==null?0:resolution.state().epoch())==before.epoch()
                &&configuration(session).revision()==before.configuration()&&session.revision==before.revision()&&session.contextRevision==before.context()&&current.proofEpoch==before.proof()&&current.requestEpoch==before.request()
                &&current.snapshot.get().rules().fingerprint().equals(before.rules())&&Objects.equals(session.identifierContext,before.nativeIdentity())&&session.context.sqlMode().equals(before.sqlMode())
                &&proofAdmissionState(current,new ProofFence(before.source(),before.sourceOwner(),before.proof()),session.identifierContext)==MetadataState.AVAILABLE;
        }
    }
    public boolean priorCompleteTemporaryShape(TemporaryObservation observation){return observation!=null&&observation.completeShape;}
    /** Only the actual complete canonical native observation can preserve a
     * prior complete shape. Call again before skipping any later acquisition. */
    public boolean reuseTemporaryObservation(SessionRegistry.Session session,TemporaryObservation observation,String catalog,String schema,String requested,String nativeName,NativeDefinitionEvidence observed){
        if(observation==null||!observation.completeShape||!observed.complete()||!observation.definition.equals(observed)||!observation.canonical.equals(nativeName)||!temporaryObservationCurrent(session,observation,catalog,schema,requested))return false;
        // This brief pure lookup also rejects stale coverage/shape state; no
        // immutable catalog generation escapes beyond this call.
        boolean available=capture(session).ownedRelationAvailable(catalog,schema,nativeName,true);
        return available&&temporaryObservationCurrent(session,observation,catalog,schema,requested);
    }
    /** Known single-relation DDL cannot invalidate another temporary table. */
    public void invalidateSessionRelation(SessionRegistry.Session session,String catalog,String schema,String name){
        var current=sessionResolutions.get(session.id);if(current==null||current.state().state()!=MetadataState.UNKNOWN)return;
        var rules=captureBase(session).rules();if(!current.rulesFingerprint().equals(rules.fingerprint()))return;var key=new MetadataSnapshot.RelationName(rules.lookup(ObjectKind.CATALOG,catalog,true),rules.lookup(ObjectKind.SCHEMA,schema,true),rules.lookup(ObjectKind.TABLE,name,true));
        if(!current.state().verified().containsKey(key)&&!current.state().owned().containsKey(key))return;
        var known=new HashMap<>(current.state().verified());known.remove(key);var owned=new HashMap<>(current.state().owned());owned.remove(key);
        sessionResolutions.replace(session.id,current,new ResolutionOwner(current.source(),new MetadataSnapshot.SessionResolution(MetadataState.UNKNOWN,session.id,current.state().epoch(),current.state().limitation(),known,owned),current.rulesFingerprint()));
    }
    /** An exact native observation never upgrades an unknown whole inventory.
     * The physical lock prevents an intervening statement changing the target. */
    public boolean markSessionRelationVerified(SessionRegistry.Session session,long expectedEpoch,String catalog,String schema,String name,MetadataSnapshot.PhysicalRelationKind kind){
        requireResolutionOwner(session);Objects.requireNonNull(kind);
        if(catalog.isEmpty()||schema.isEmpty()||name.isEmpty()||catalog.length()>256||schema.length()>256||name.length()>256||catalog.indexOf('\0')>=0||schema.indexOf('\0')>=0||name.indexOf('\0')>=0)throw new IllegalArgumentException("Invalid physical relation identity");
        var current=sessionResolutions.get(session.id);if(current==null)return expectedEpoch==0;
        if(current.state().epoch()!=expectedEpoch||!current.source().equals(session.metadataSourceIdentity))return false;
        if(current.state().state()==MetadataState.AVAILABLE)return true;
        var rules=captureBase(session).rules();if(!identifierAffinity(rules,session.identifierContext)||!current.rulesFingerprint().equals(rules.fingerprint()))return false;var key=new MetadataSnapshot.RelationName(rules.lookup(ObjectKind.CATALOG,catalog,true),rules.lookup(ObjectKind.SCHEMA,schema,true),rules.lookup(ObjectKind.TABLE,name,true));
        var known=current.state().verified();if(known.get(key)==kind)return true;
        if(known.size()>=MetadataSnapshot.SessionResolution.MAX_VERIFIED&&!known.containsKey(key))return false;
        long additional=known.containsKey(key)?0:key.estimatedBytes();
        if(current.state().estimatedBytes()+additional>MetadataSnapshot.SessionResolution.MAX_VERIFIED_BYTES||residentEstimate()+additional>MAX_TOTAL_BYTES)return false;
        var verified=new HashMap<>(known);verified.put(key,kind);
        var owned=new HashMap<>(current.state().owned());if(kind!=MetadataSnapshot.PhysicalRelationKind.TEMPORARY)owned.remove(key);
        var next=new MetadataSnapshot.SessionResolution(MetadataState.UNKNOWN,session.id,expectedEpoch,current.state().limitation(),verified,owned);
        return sessionResolutions.replace(session.id,current,new ResolutionOwner(current.source(),next,current.rulesFingerprint()));
    }
    /** Called only after the PostgreSQL adapter completed an owned inventory,
     * including verified absence. Independent durable refresh must not call it. */
    public boolean reconcileSessionResolution(SessionRegistry.Session session,long expectedEpoch){
        requireResolutionOwner(session);if(session.profile.getEngine()!=Engine.POSTGRESQL)throw new IllegalArgumentException("Complete temporary inventory requires a supported owned-session adapter");
        var current=sessionResolutions.get(session.id);if(current==null)return expectedEpoch==0;
        if(current.state().epoch()!=expectedEpoch)return false;
        var next=new MetadataSnapshot.SessionResolution(MetadataState.AVAILABLE,session.id,expectedEpoch,"",Map.of());
        return sessionResolutions.replace(session.id,current,new ResolutionOwner(current.source(),next,current.rulesFingerprint()));
    }
    private static void requireResolutionOwner(SessionRegistry.Session session){if(!session.lock.isHeldByCurrentThread())throw new IllegalStateException("Physical session lock required for resolution verification");if(session.physicalEnded()||session.state==TransactionState.DISCONNECTED||session.state==TransactionState.UNKNOWN_TRANSACTION)throw new IllegalStateException("Physical session resolution is unavailable");}
    private record RulesBootstrapSeed(Source owner,MetadataSnapshot snapshot,long revision,long context,long configuration,long request,long proof,long tickets){}
    /** Only owned native maintenance or explicit reviewed inspection may bootstrap an initially empty source.
     * Native maps are still read exclusively through the independent metadata
     * connection policy; this path never persists or waits on the private cache. */
    public IdentifierRules ensureOwnedIdentifierRules(SessionRegistry.Session session,long deadline)throws Exception{
        requireResolutionOwner(session);checkPublicationDeadline(deadline);var owner=source(session);String key=session.metadataSourceIdentity;
        RulesBootstrapSeed seed;
        synchronized(owner){
            var current=owner.snapshot.get();if(identifierAffinity(current.rules(),session.identifierContext))return current.rules();
            if(!current.identities().isEmpty()||!current.catalogCoverage().isEmpty()||overlays.values().stream().anyMatch(value->value.source().equals(key)))throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.STALE);
            if(owner.configurationPending||owner.externalActive!=0||owner.externalRequiresExplicit)throw externalUnavailable();
            seed=new RulesBootstrapSeed(owner,current,session.revision,session.contextRevision,configuration(session).revision(),owner.requestEpoch,owner.proofEpoch,owner.tickets.get());
        }
        try(var admission=admitAcquisition()){
            var rules=session.metadata(session.context.catalog(),view->NativeStructureReader.rules(view,seed.snapshot().rules(),deadline));
            checkPublicationDeadline(deadline);checkIdentifierAffinity(rules,session.identifierContext);admission.reserveRules(rules);
            var next=MetadataSnapshot.prepare(key,session.profile.getId(),seed.snapshot().revision()+1,seed.configuration(),System.currentTimeMillis(),rules,List.of(),Map.of(),deadline);
            beforeCommit.run();checkPublicationDeadline(deadline);
            synchronized(admissionLock){synchronized(owner){
                if(sources.get(key)!=seed.owner()||session.physicalEnded()||session.state==TransactionState.DISCONNECTED||session.state==TransactionState.UNKNOWN_TRANSACTION||session.revision!=seed.revision()||session.contextRevision!=seed.context()||configuration(session).revision()!=seed.configuration()||owner.configurationPending||owner.externalActive!=0||owner.externalRequiresExplicit)throw new SupersededRefresh();
                var current=owner.snapshot.get();
                if(current!=seed.snapshot()){
                    // Join only identical already-published native evidence;
                    // this never overwrites or rekeys a nonempty model.
                    if(current.rules().fingerprint().equals(rules.fingerprint())&&identifierAffinity(current.rules(),session.identifierContext)&&owner.requestEpoch==seed.request())return current.rules();
                    throw new SupersededRefresh();
                }
                if(owner.requestEpoch!=seed.request()||owner.proofEpoch!=seed.proof()||owner.tickets.get()!=seed.tickets()||overlays.values().stream().anyMatch(value->value.source().equals(key)))throw new SupersededRefresh();
                enforceRuleBudget(key,next.estimatedBytes(),admission);long ticket=owner.tickets.incrementAndGet();commitSnapshot(owner,ticket,next);owner.bootstrapBridge=new BootstrapBridge(seed.snapshot().revision(),next.revision(),seed.configuration(),owner.requestEpoch,owner.proofEpoch,session.id,seed.context());retireRuleResolutions(key,rules);
                if(repository!=null)owner.cacheGap=new CacheGap(next.revision(),next.configurationRevision(),rules.fingerprint());
                admission.committed();return rules;
            }}
        }
    }
    /** Durable baseline for refresh writers; temporary overlays never replace server branches. */
    public MetadataSnapshot publishedSnapshot(SessionRegistry.Session session){return source(session).snapshot.get();}
    public MetadataSnapshot snapshot(String profileId) {
        var matches=sources.values().stream().map(s->s.snapshot.get()).filter(s->s.profileId().equals(profileId)).toList();
        if(matches.size()!=1)throw new IllegalArgumentException("Exact metadata source ownership is required");return matches.getFirst();
    }
    public MetadataConfiguration configuration(SessionRegistry.Session session){return configurations.getOrDefault(session.metadataSourceIdentity,MetadataConfiguration.defaults());}
    public String cacheState(){if(repository==null)return "MEMORY_ONLY";boolean pending=false;for(var owner:sources.values()){String state=cacheState(owner);if(state.equals("WRITE_UNAVAILABLE"))return state;if(state.equals("WRITE_PENDING"))pending=true;}return pending?"WRITE_PENDING":repository.cacheState();}
    public String cacheState(SessionRegistry.Session session){return repository==null?"MEMORY_ONLY":cacheState(source(session));}
    private String cacheState(Source owner){
        if(owner.cacheGap!=null)return "WRITE_UNAVAILABLE";var receipt=owner.cacheAttempt;
        if(receipt==null&&owner.cacheState.equals("WRITE_PENDING"))return System.nanoTime()>=owner.cacheSubmissionDeadline?"WRITE_UNAVAILABLE":"WRITE_PENDING";
        if(receipt!=null&&!receipt.identity().matches(owner.snapshot.get()))return "WRITE_UNAVAILABLE";
        if(receipt!=null&&receipt.completed().isEmpty())return !receipt.identity().matches(owner.snapshot.get())||receipt.cancellationRequested()||System.nanoTime()>=receipt.identity().deadlineNanos()?"WRITE_UNAVAILABLE":"WRITE_PENDING";
        return owner.cacheState.isEmpty()?repository.cacheState():owner.cacheState;
    }
    public Optional<MetadataRepository.WriteFailure> cacheFailure(SessionRegistry.Session session){var owner=source(session);var receipt=owner.cacheAttempt;if(receipt!=null&&receipt.completed().isEmpty()){if(receipt.cancellationRequested())return Optional.of(new MetadataRepository.WriteFailure(MetadataRepository.FailureReason.CANCELLED,"57014",0));if(System.nanoTime()>=receipt.identity().deadlineNanos())return Optional.of(new MetadataRepository.WriteFailure(MetadataRepository.FailureReason.TIMED_OUT,"57014",0));}else if(receipt==null&&owner.cacheState.equals("WRITE_PENDING")&&System.nanoTime()>=owner.cacheSubmissionDeadline)return Optional.of(new MetadataRepository.WriteFailure(MetadataRepository.FailureReason.TIMED_OUT,"57014",0));return Optional.ofNullable(owner.cacheFailure);}
    public Optional<MetadataRepository.WriteReceipt> cacheWriteReceipt(SessionRegistry.Session session){var owner=source(session);var receipt=owner.cacheAttempt;return receipt!=null&&receipt.identity().sourceOwner()==owner.owner&&receipt.identity().matches(owner.snapshot.get())?Optional.of(receipt):Optional.empty();}
    public long cacheWriteNanos(SessionRegistry.Session session){return source(session).cacheWriteNanos;}
    public Optional<MetadataRepository.WriteMetrics> cacheWriteMetrics(SessionRegistry.Session session){
        var owner=source(session);synchronized(owner){var measured=owner.cacheMetrics;
            return measured!=null&&measured.identity().matches(owner.snapshot.get())&&cacheMetricsCurrent(owner,sources.get(session.metadataSourceIdentity),measured.sourceOwner(),owner.snapshot.get(),measured.metrics())&&measured.metrics().profileId().equals(session.profile.getId())?Optional.of(measured.metrics()):Optional.empty();
        }
    }
    static boolean cacheMetricsCurrent(Source owner,Source current,long expectedOwner,MetadataSnapshot attempted,MetadataRepository.WriteMetrics metrics){
        return owner==current&&owner.owner==expectedOwner&&metrics!=null&&metrics.matches(attempted)&&metrics.matches(owner.snapshot.get());
    }
    private void cachePending(Source owner){pendingCacheWrites.incrementAndGet();owner.pendingCacheWrites.incrementAndGet();}
    /** Compare policy predicates once, rather than scanning known rows to
     * guess whether unseen names could have entered a complete enumeration. */
    private record Selector(boolean unrestricted,Set<String> names,boolean systemObjects){
        static Selector of(Set<String> included,Set<String> excluded,boolean schemas,boolean systemObjects){
            var names=new HashSet<>(included.isEmpty()?excluded:included);if(!included.isEmpty())names.removeAll(excluded);
            if(schemas&&!systemObjects)names.removeIf(MetadataConfiguration::system);
            return new Selector(included.isEmpty(),Set.copyOf(names),schemas&&included.isEmpty()&&systemObjects);
        }
        boolean empty(){return !unrestricted&&names.isEmpty();}
    }
    private record NamePolicy(Set<String> include,Set<String> exclude){
        static NamePolicy of(MetadataConfiguration policy){
            var include=patterns(policy.includePatterns());var exclude=patterns(policy.excludePatterns());
            if(exclude.contains("*"))return new NamePolicy(Set.of(),Set.of("*"));
            if(include.contains("*"))include=Set.of();return new NamePolicy(include,exclude);
        }
        private static Set<String> patterns(List<String> patterns){
            var result=new HashSet<String>();for(String pattern:patterns){var normalized=new StringBuilder();boolean star=false;for(int i=0;i<pattern.length();i++){char c=pattern.charAt(i);if(c!='*'||!star)normalized.append(c);star=c=='*';}result.add(normalized.toString());}return Set.copyOf(result);
        }
        boolean empty(){return exclude.contains("*");}
    }
    private static final class PolicyChange {
        private final MetadataConfiguration before,next;private final Selector catalogs,schemas,oldCatalogs,oldSchemas;private final NamePolicy names,oldNames;private final boolean namesChanged;
        PolicyChange(MetadataConfiguration before,MetadataConfiguration next){
            this.before=before;this.next=next;catalogs=Selector.of(next.includedCatalogs(),next.excludedCatalogs(),false,true);oldCatalogs=Selector.of(before.includedCatalogs(),before.excludedCatalogs(),false,true);schemas=Selector.of(next.includedSchemas(),next.excludedSchemas(),true,next.systemObjects());oldSchemas=Selector.of(before.includedSchemas(),before.excludedSchemas(),true,before.systemObjects());names=NamePolicy.of(next);oldNames=NamePolicy.of(before);namesChanged=!names.equals(oldNames);
        }
        private boolean permits(MetadataConfiguration policy,Selector catalogSelector,Selector schemaSelector,NamePolicy namePolicy,MetadataScope scope){
            if(!policy.kinds().contains(scope.kind())||catalogSelector.empty())return false;
            if(!scope.catalog().isEmpty()&&(policy.excludedCatalogs().contains(scope.catalog())||!policy.includedCatalogs().isEmpty()&&!policy.includedCatalogs().contains(scope.catalog())))return false;
            if(!scope.schema().isEmpty()){
                if(policy.excludedSchemas().contains(scope.schema())||!policy.includedSchemas().isEmpty()&&!policy.includedSchemas().contains(scope.schema())||!policy.systemObjects()&&MetadataConfiguration.system(scope.schema()))return false;
            }else if(scope.kind()!=ObjectKind.CATALOG&&schemaSelector.empty())return false;
            String name=scope.parent().isEmpty()?(scope.exactName()?scope.search():""):scope.parent();
            if(name.isEmpty())return !namePolicy.empty();
            return (policy.includePatterns().isEmpty()||policy.includePatterns().stream().anyMatch(pattern->MetadataConfiguration.matches(pattern,name)))&&policy.excludePatterns().stream().noneMatch(pattern->MetadataConfiguration.matches(pattern,name));
        }
        boolean permitted(MetadataScope scope){return permits(next,catalogs,schemas,names,scope);}
        boolean affected(MetadataScope scope){
            if(!permits(before,oldCatalogs,oldSchemas,oldNames,scope)||before.level(scope.catalog(),scope.schema())!=next.level(scope.catalog(),scope.schema()))return true;
            if(scope.catalog().isEmpty()&&!oldCatalogs.equals(catalogs)||scope.schema().isEmpty()&&scope.kind()!=ObjectKind.CATALOG&&!oldSchemas.equals(schemas))return true;
            if(scope.parent().isEmpty()&&!scope.exactName()&&namesChanged)return true;
            return false;
        }
    }
    /** Policy filtering is prepared before the essential preference CAS. No
     * catalog traversal or persistent write holds the Source monitor. */
    static MetadataSnapshot configuredSnapshot(MetadataSnapshot before,MetadataConfiguration current,MetadataConfiguration next)throws TimeoutException{return configuredSnapshot(before,current,next,defaultPublicationDeadline());}
    static MetadataSnapshot configuredSnapshot(MetadataSnapshot before,MetadataConfiguration current,MetadataConfiguration next,long deadline)throws TimeoutException{
        checkPublicationDeadline(deadline);var change=new PolicyChange(current,next);
        var retained=new ArrayList<MetadataObject>();
        for(var object:before.identities().values()){
            checkPublicationDeadline(deadline);var id=object.identity();if(next.permits(id.catalog(),id.schema(),id.kind(),id.parent().isEmpty()?id.name():id.parent()))retained.add(object);
        }
        var coverage=new HashMap<MetadataScope,MetadataCoverage>();
        for(var entry:before.catalogCoverage().entrySet()){
            checkPublicationDeadline(deadline);var scope=entry.getKey();
            if(change.permitted(scope))coverage.put(scope,change.affected(scope)?entry.getValue().stale("Metadata introspection policy changed for this scope"):entry.getValue());
        }
        // Materialize policy coverage off Source. Final inline-invalidation
        // composition can therefore add at most one immutable view layer.
        return MetadataSnapshot.prepare(before.source(),before.profileId(),before.revision()+1,next.revision(),System.currentTimeMillis(),before.rules(),retained,coverage,deadline);
    }
    public void configure(SessionRegistry.Session session,MetadataConfiguration next)throws Exception {
        var owner=source(session);String key=session.metadataSourceIdentity;long deadline=defaultPublicationDeadline();enterWriter(owner,session,deadline);
        boolean transitioning=false;MetadataRepository.WriteReceipt cacheReceipt=null;
        try{
            MetadataSnapshot before;MetadataConfiguration current;Map<MetadataScope,Long> priorTickets;Map<String,ResolutionOwner> resolutions=new HashMap<>();
            synchronized(owner){
                current=configuration(session);if(sources.get(key)!=owner||owner.configurationPending||next.revision()!=current.revision()+1)throw new IllegalStateException("Metadata configuration revision changed");
                if(session.physicalEnded()||session.state==TransactionState.DISCONNECTED)throw new IllegalStateException("Metadata physical session ended before configuration");
                before=owner.snapshot.get();priorTickets=owner.published;owner.configurationPending=true;transitioning=true;
                owner.configurationTicket=owner.tickets.incrementAndGet();owner.requestEpoch++;owner.proofEpoch++;
                for(var entry:sessionResolutions.entrySet())if(entry.getValue().source().equals(key))resolutions.put(entry.getKey(),entry.getValue());
            }
            var prepared=configuredSnapshot(before,current,next,deadline);var tickets=new HashMap<>(priorTickets);tickets.keySet().retainAll(prepared.catalogCoverage().keySet());var preparedTickets=Map.copyOf(tickets);
            var cleared=new HashMap<String,ResolutionOwner>();for(var entry:resolutions.entrySet()){
                var value=entry.getValue();var state=value.state();cleared.put(entry.getKey(),state.owned().isEmpty()?value:new ResolutionOwner(key,new MetadataSnapshot.SessionResolution(state.state(),entry.getKey(),state.epoch(),state.limitation(),state.verified()),value.rulesFingerprint()));
            }
            // The preference write is essential. A failure leaves the old
            // committed policy/model visible and propagates to the caller.
            checkPublicationDeadline(deadline);if(preferences!=null)preferences.metadataConfiguration(key,next);
            MetadataSnapshot committed,previous;
            synchronized(owner){
                previous=owner.snapshot.get();committed=prepared.withConfigurationPublication(previous.revision()+1,before,previous);
                configurations.put(key,next);owner.snapshot.set(committed);owner.bootstrapBridge=null;owner.published=preparedTickets;owner.overlayPublished.clear();
                overlays.entrySet().removeIf(entry->entry.getValue().source().equals(key));
                sessionResolutions.replaceAll((id,value)->!value.source().equals(key)?value:resolutions.get(id)==value?cleared.get(id):new ResolutionOwner(key,unknownRules(id,resolutionEpochs.incrementAndGet()),value.rulesFingerprint()));
                owner.configurationPending=false;transitioning=false;if(repository!=null)cachePending(owner);
            }
            if(repository!=null)cacheReceipt=persistCommitted(owner,committed,previous,deadline);
        }finally{
            if(transitioning)synchronized(owner){owner.configurationPending=false;}
            owner.writer.unlock();
            awaitCache(cacheReceipt,deadline);
        }
    }
    private static io.busystack.busydata.rpc.WorkbenchFailure externalUnavailable(){return new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.STALE);}
    public boolean externalMutationActive(SessionRegistry.Session session){return source(session).externalActive!=0;}
    /** Generated operations cannot turn unknown external effects into implicit fresh facts. */
    public void requirePersistentMetadata(SessionRegistry.Session session){var owner=source(session);synchronized(owner){if(owner.externalActive!=0||owner.externalRequiresExplicit||owner.configurationPending)throw externalUnavailable();checkIdentifierAffinity(owner.snapshot.get().rules(),session.identifierContext);}}
    public ProofFence proofFence(SessionRegistry.Session session){var owner=source(session);synchronized(owner){return new ProofFence(session.metadataSourceIdentity,owner.owner,owner.proofEpoch);}}
    /** Unacquired native evidence is unavailable; only changed authority or an
     * external mutation barrier makes this admission stale. No catalog work is
     * performed while checking the already captured physical header. */
    public MetadataState proofAdmissionState(SessionRegistry.Session session,ProofFence fence){var owner=source(session);synchronized(owner){return proofAdmissionState(owner,fence,session.identifierContext);}}
    public boolean proofFenceAvailable(SessionRegistry.Session session,ProofFence fence){return proofAdmissionState(session,fence)==MetadataState.AVAILABLE;}
    static MetadataState proofAdmissionState(Source owner,ProofFence fence){
        if(fence==null||!fence.source().equals(owner.snapshot.get().source())||fence.owner()!=owner.owner||fence.epoch()!=owner.proofEpoch||owner.externalActive!=0||owner.externalRequiresExplicit||owner.configurationPending)return MetadataState.STALE;
        return owner.snapshot.get().rules().complete()?MetadataState.AVAILABLE:MetadataState.UNAVAILABLE;
    }
    static MetadataState proofAdmissionState(Source owner,ProofFence fence,IdentifierRules.ServerIdentity identity){
        var state=proofAdmissionState(owner,fence);
        return state==MetadataState.AVAILABLE&&!identifierAffinity(owner.snapshot.get().rules(),identity)?MetadataState.UNAVAILABLE:state;
    }
    static boolean proofFenceAvailable(Source owner,ProofFence fence){return proofAdmissionState(owner,fence)==MetadataState.AVAILABLE;}
    /** Result creation shares the source monitor with the before-launch barrier.
     * Retained rows remain readable; only durable editability is withheld. */
    public io.busystack.busydata.results.ResultStore.Result publishRetainedProof(SessionRegistry.Session session,ProofFence fence,io.busystack.busydata.results.ResultStore.PreparedProof prepared){
        var proof=prepared.proof();String key=session.metadataSourceIdentity;var owner=sources.get(key);
        if(owner==null)return prepared.complete(retireProof(proof,"Metadata source ownership is unavailable; retained rows remain inspectable"));
        synchronized(owner){
            if(sources.get(key)!=owner||session.physicalEnded()||session.state==TransactionState.DISCONNECTED||session.state==TransactionState.UNKNOWN_TRANSACTION)return prepared.complete(retireProof(proof,"Physical metadata ownership is unavailable; retained rows remain inspectable"));
            return prepared.complete(admitProof(owner,fence,proof,session.identifierContext));
        }
    }
    static io.busystack.busydata.results.ResultStore.Result publishRetainedProof(Source owner,ProofFence fence,io.busystack.busydata.results.ResultStore.PreparedProof prepared){synchronized(owner){return prepared.complete(admitProof(owner,fence,prepared.proof()));}}
    private static RetainedMetadataProof retireProof(RetainedMetadataProof proof,String reason){return proof.available()||proof.capturedStructure()?proof.invalidateExternal(reason):proof;}
    static RetainedMetadataProof admitProof(Source owner,ProofFence fence,RetainedMetadataProof proof){if(!owner.snapshot.get().rules().complete()&&(proof.available()||proof.capturedStructure()))return RetainedMetadataProof.unavailable(MetadataState.UNAVAILABLE,"Native identifier comparison evidence is unavailable");return !proofFenceAvailable(owner,fence)?retireProof(proof,"Persistent source authority changed or is unavailable; reconcile metadata explicitly"):proof;}
    static RetainedMetadataProof admitProof(Source owner,ProofFence fence,RetainedMetadataProof proof,IdentifierRules.ServerIdentity identity){return !identifierAffinity(owner.snapshot.get().rules(),identity)&&(proof.available()||proof.capturedStructure())?RetainedMetadataProof.unavailable(MetadataState.UNAVAILABLE,"Native identifier evidence does not match the physical connection"):admitProof(owner,fence,proof);}
    static void explicitPublication(Source owner,boolean explicit,boolean fresh){if(explicit&&fresh)owner.externalRequiresExplicit=false;}
    public ExternalMutation beginExternalMutation(SessionRegistry.Session session){requireResolutionOwner(session);var owner=source(session);synchronized(owner){var mutation=beginExternalMutation(owner,session.metadataSourceIdentity,session.id);retirePersistentOverlays(session.metadataSourceIdentity);return mutation;}}
    static ExternalMutation beginExternalMutation(Source owner,String source,String session){
        if(owner.externalMutations.size()>=2)throw externalUnavailable();
        if(owner.externalMutations.isEmpty()){owner.externalWave++;owner.externalTainted=false;owner.externalAck=null;}
        owner.requestEpoch++; // A new reviewed source writer also supersedes earlier settled intents.
        var token=new ExternalMutation(source,session,owner.owner,externalTokens.incrementAndGet(),owner.externalWave);
        owner.externalMutations.put(token.token,token);owner.externalActive=owner.externalMutations.size();
        fenceExternal(owner,"Reviewed native restore may change persistent structure; metadata is stale until the native boundary is known");
        return token;
    }
    /** Keep physical temporary facts and pending object identities. Only
     * persistent overlay coverage loses authority over the new durable epoch. */
    static MetadataSnapshot retirePersistentOverlay(MetadataSnapshot snapshot,Set<MetadataScope> scopes,String session){
        var temporary=new HashSet<MetadataSnapshot.RelationName>();
        for(var object:snapshot.localIdentities().values()){var id=object.identity();if(id.kind()==ObjectKind.TABLE&&id.sessionOwner().equals(session)&&("true".equals(object.properties().get("temporary"))||id.schema().startsWith("pg_temp_")))temporary.add(new MetadataSnapshot.RelationName(id.catalog(),id.schema(),id.name()));}
        var coverage=new HashMap<MetadataScope,MetadataCoverage>();boolean changed=false;
        for(var scope:scopes){
            boolean local=scope.schema().startsWith("pg_temp_")||!scope.parent().isEmpty()&&temporary.contains(new MetadataSnapshot.RelationName(scope.catalog(),scope.schema(),scope.parent()))||scope.kind()==ObjectKind.TABLE&&scope.exactName()&&temporary.contains(new MetadataSnapshot.RelationName(scope.catalog(),scope.schema(),scope.search()));
            if(!local&&snapshot.catalogCoverage().containsKey(scope)){coverage.put(scope,snapshot.catalogCoverage().get(scope).stale("Native restore retired persistent session-overlay structure; reconcile on its owning physical session"));changed=true;}
        }
        return changed?snapshot.withCoverageOverrides(snapshot.revision()+1,coverage):snapshot;
    }
    private void retirePersistentOverlays(String source){overlays.replaceAll((session,overlay)->{
        if(!overlay.source().equals(source))return overlay;
        var retired=retirePersistentOverlay(overlay.snapshot(),overlay.scopes(),session);
        return retired==overlay.snapshot()?overlay:new Overlay(overlay.source(),overlay.sessionRevision(),overlay.contextRevision(),overlay.baseRevision(),overlay.scopes(),retired);
    });}
    private static void fenceExternal(Source owner,String reason){owner.proofEpoch++;owner.publicationFloor=owner.tickets.incrementAndGet();staleCoverage(owner,owner.snapshot.get().catalogCoverage().keySet(),reason);}
    /** A prepared spawn failure is nonmutating. An actually started unknown
     * outcome poisons the whole overlap wave, including an earlier success. */
    public ExternalCompletion finishExternalMutation(SessionRegistry.Session session,ExternalMutation token,boolean started,boolean acknowledged){
        if(!session.lock.isHeldByCurrentThread())throw new IllegalStateException("Physical session lock required for native mutation settlement");
        var owner=sources.get(token.source);if(owner==null||owner.owner!=token.owner)throw externalUnavailable();
        synchronized(owner){
            if(!token.session.equals(session.id))throw externalUnavailable();
            var completion=finishExternalMutation(owner,token,started,acknowledged,()->!session.physicalEnded()&&session.state!=TransactionState.UNKNOWN_TRANSACTION&&session.state!=TransactionState.DISCONNECTED?queuedOwner(session,owner):null);
            if(started)retirePersistentOverlays(token.source);return completion;
        }
    }
    static ExternalCompletion finishExternalMutation(Source owner,ExternalMutation token,boolean started,boolean acknowledged,java.util.function.Supplier<QueuedRefreshOwner> acknowledgement){
        if(token.released)return new ExternalCompletion(null,token.wave,false);
        if(owner.owner!=token.owner||owner.externalMutations.get(token.token)!=token)throw externalUnavailable();
        token.released=true;owner.externalMutations.remove(token.token);owner.externalActive=owner.externalMutations.size();
        if(started){
            fenceExternal(owner,acknowledged?"Native restore acknowledged persistent changes; independent metadata reconciliation is pending":"Native restore outcome is unknown; reconcile persistent metadata explicitly without replay");
            if(!acknowledged){owner.externalTainted=true;owner.externalRequiresExplicit=true;owner.externalAck=null;}
            else if(!owner.externalTainted&&!owner.externalRequiresExplicit)owner.externalAck=acknowledgement.get();
        }
        return new ExternalCompletion(owner.externalAck,owner.externalWave,externalWaveReady(owner,owner.externalWave,owner.externalAck));
    }
    static boolean externalWaveReady(Source owner,long wave,QueuedRefreshOwner acknowledgement){return acknowledgement!=null&&owner.externalWave==wave&&owner.externalActive==0&&!owner.externalTainted&&!owner.externalRequiresExplicit&&owner.externalAck==acknowledgement&&acknowledgement.publication.owner==owner.owner&&acknowledgement.publication.revision==owner.snapshot.get().revision()&&acknowledgement.requestEpoch==owner.requestEpoch;}
    public boolean externalWaveReady(SessionRegistry.Session session,long wave,QueuedRefreshOwner acknowledgement){var owner=source(session);synchronized(owner){return externalWaveReady(owner,wave,acknowledgement);}}
    static long beginExplicitAcquisition(Source owner,boolean maintenance){
        if(!maintenance){owner.requestEpoch++;owner.externalAck=null;}
        long ticket=owner.tickets.incrementAndGet();if(owner.externalActive!=0)throw externalUnavailable();return ticket;
    }
    static void checkQueuedAcquisition(Source owner){if(owner.externalActive!=0||owner.externalRequiresExplicit)throw externalUnavailable();}
    static void checkExternalPublication(Source owner,long ticket){if(owner.externalActive!=0||ticket<=owner.publicationFloor)throw externalUnavailable();}
    public long beginRefresh(SessionRegistry.Session session){var owner=source(session);synchronized(owner){return beginExplicitAcquisition(owner,session.id.equals(ownedMaintenance.get()));}}
    public QueuedRefreshOwner queuedRefreshOwner(SessionRegistry.Session session){var owner=source(session);synchronized(owner){return queuedOwner(session,owner);}}
    private QueuedRefreshOwner queuedOwner(SessionRegistry.Session session,Source owner){return new QueuedRefreshOwner(new PublicationRevision(session.metadataSourceIdentity,owner.owner,owner.snapshot.get().revision()),session.id,owner.tickets.get(),owner.requestEpoch,configuration(session).revision(),session.revision,session.contextRevision);}
    private boolean sameRefreshContext(SessionRegistry.Session session,Source source,QueuedRefreshOwner expected){
        return !session.physicalEnded()&&session.state!=TransactionState.DISCONNECTED&&session.state!=TransactionState.UNKNOWN_TRANSACTION&&expected.session.equals(session.id)&&expected.publication.source.equals(session.metadataSourceIdentity)&&sources.get(expected.publication.source)==source&&expected.publication.owner==source.owner&&expected.configuration==configuration(session).revision()&&expected.context==session.contextRevision;
    }
    private boolean sameRefreshOwner(SessionRegistry.Session session,Source source,QueuedRefreshOwner expected){return sameRefreshContext(session,source,expected)&&expected.revision==session.revision;}
    private boolean queuedOwnerCurrent(SessionRegistry.Session session,Source source,QueuedRefreshOwner expected){return sameRefreshOwner(session,source,expected)&&expected.publication.revision==source.snapshot.get().revision()&&expected.reservation==source.tickets.get();}
    public RefreshReservation reserveRefresh(SessionRegistry.Session session){var owner=source(session);synchronized(owner){var expected=queuedOwner(session,owner);long ticket=beginExplicitAcquisition(owner,false);if(!sameRefreshOwner(session,owner,expected))throw new SupersededRefresh();return new RefreshReservation(expected,ticket,false);}}
    public RefreshReservation reserveQueuedRefresh(SessionRegistry.Session session,QueuedRefreshOwner expected){var owner=source(session);synchronized(owner){checkQueuedAcquisition(owner);if(!queuedOwnerCurrent(session,owner,expected))throw new SupersededRefresh();return new RefreshReservation(expected,owner.tickets.incrementAndGet(),true);}}
    private void checkRefreshReservation(SessionRegistry.Session session,Source owner,RefreshReservation reservation){checkRefreshReservation(session,owner,reservation,false);}
    private void checkRefreshReservation(SessionRegistry.Session session,Source owner,RefreshReservation reservation,boolean structuredFailure){
        checkExternalPublication(owner,reservation.ticket);
        if(!sameRefreshOwner(session,owner,reservation.owner)||reservation.ticket<=owner.configurationTicket){if(reservation.queued)throw new SupersededRefresh();if(structuredFailure)throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.STALE);throw new IllegalStateException("Metadata source owner or configuration changed during refresh");}
        if(reservation.queued&&(reservation.ticket!=owner.tickets.get()||reservation.owner.publication.revision!=owner.snapshot.get().revision()))throw new SupersededRefresh();
    }
    public void checkRefreshReservation(SessionRegistry.Session session,RefreshReservation reservation){var owner=source(session);synchronized(owner){checkRefreshReservation(session,owner,reservation);}}
    /** Empty connection tasks may mark failure only while their original queue
     * owner is current, including the absence of a newer explicit reservation. */
    public void markStaleIfQueuedOwner(SessionRegistry.Session session,QueuedRefreshOwner expected,String reason){var owner=source(session);synchronized(owner){if(queuedOwnerCurrent(session,owner,expected))staleCoverage(owner,owner.snapshot.get().catalogCoverage().keySet(),reason);}}
    public void markStaleIfRefreshReservation(SessionRegistry.Session session,RefreshReservation reservation,String reason){var owner=source(session);synchronized(owner){if(reservation.queued&&sameRefreshOwner(session,owner,reservation.owner)&&reservation.ticket==owner.tickets.get()&&reservation.owner.publication.revision==owner.snapshot.get().revision())staleCoverage(owner,owner.snapshot.get().catalogCoverage().keySet(),reason);}}
    /** Invalidation and its catalog/request boundary are one atomic event. */
    public QueuedRefreshOwner invalidateForReconciliation(SessionRegistry.Session session,Collection<DdlEffect> effects,String reason){requireResolutionOwner(session);var owner=source(session);synchronized(owner){staleCoverage(owner,MetadataInvalidation.scopes(owner.snapshot.get(),effects,session.context.catalog(),session.context.schema()),reason);return queuedOwner(session,owner);}}
    /** Called only from a new physically owned settlement, never a worker's
     * retry/finally. Intervening Smart/owned-overlay tickets are known owners;
     * any explicit reservation, publication, policy or context change refuses
     * revival. The newly admitted attempt still has exact revision/ticket checks. */
    static boolean bootstrapRevision(Source owner,long revision,long configuration,long request,String session,long context){
        if(!Thread.holdsLock(owner))throw new IllegalStateException("Metadata bootstrap owner is required");var bridge=owner.bootstrapBridge;
        return bridge!=null&&bridge.from()==revision&&bridge.to()==owner.snapshot.get().revision()&&bridge.configuration()==configuration&&bridge.configuration()==owner.snapshot.get().configurationRevision()&&bridge.request()==request&&bridge.request()==owner.requestEpoch&&bridge.proof()==owner.proofEpoch&&bridge.session().equals(session)&&bridge.context()==context&&owner.externalActive==0&&!owner.externalRequiresExplicit&&!owner.configurationPending;
    }
    public QueuedRefreshOwner settledReconciliationOwner(SessionRegistry.Session session,QueuedRefreshOwner intent){requireResolutionOwner(session);var owner=source(session);synchronized(owner){if(!sameRefreshContext(session,owner,intent)||intent.publication.revision!=owner.snapshot.get().revision()&&!bootstrapRevision(owner,intent.publication.revision,intent.configuration,intent.requestEpoch,intent.session,intent.context)||intent.requestEpoch!=owner.requestEpoch)throw new SupersededRefresh();return queuedOwner(session,owner);}}
    /** Normalize one acquired branch, sharing unchanged semantic objects before the next branch is read. */
    public Branch normalizedBranch(SessionRegistry.Session session,IdentifierRules rules,List<SchemaObject> values,MetadataCoverage coverage,MetadataSnapshot before,AcquisitionAdmission admission){
        var normalized=new ArrayList<MetadataObject>(values.size());String source=session.metadataSourceIdentity;
        for(var value:values){var object=MetadataObject.from(source,session.profile.getId(),"",rules,value,coverage.level(),coverage.sourceRevision(),coverage.contextRevision());var previous=before.identities().get(object.identity().key());if(previous!=null&&previous.sameContent(object))normalized.add(previous);else{admission.reserve(object);normalized.add(object);}}
        return new Branch(List.of(),coverage,normalized,false);
    }
    public Branch reconciledNamesBranch(SessionRegistry.Session session,IdentifierRules rules,List<SchemaObject> values,MetadataCoverage coverage,MetadataSnapshot before,MetadataNames.Evidence evidence,Map<MetadataScope,Branch> branches,AcquisitionAdmission admission,long deadline)throws Exception {
        String source=session.metadataSourceIdentity;
        List<MetadataObject> acquired=new AbstractList<>() {
            @Override public int size(){return values.size();}
            @Override public MetadataObject get(int index){return MetadataObject.from(source,session.profile.getId(),"",rules,values.get(index),IntrospectionLevel.NAMES,coverage.sourceRevision(),coverage.contextRevision());}
        };
        var reconciled=MetadataNames.reconcile(before,coverage.scope(),acquired,evidence,deadline);
        for(var object:reconciled.objects())if(before.identities().get(object.identity().key())!=object)admission.reserve(object);
        for(var scope:reconciled.staleScopes()) {
            var previous=before.catalogCoverage().get(scope);if(previous==null||branches.containsKey(scope))continue;
            var state=new MetadataCoverage(scope,previous.level(),MetadataState.STALE,false,previous.fingerprint(),coverage.sourceRevision(),coverage.contextRevision(),previous.refreshedUnixMs(),"Native name/structure evidence changed or could not verify cached details",previous.defaultNamespace());
            branches.put(scope,Branch.reused(state));
        }
        return new Branch(List.of(),coverage,reconciled.objects(),false);
    }
    /** Reserve one acquisition before opening the independently owned view, and
     * retain that view through all native schema/designer validation. */
    public <T>T inspectSchema(SessionRegistry.Session owner,String catalog,SchemaMetadataProjection.InspectionAction<T> action)throws Exception{return SchemaMetadataProjection.inspect(this,owner,catalog,action);}
    public com.google.gson.JsonObject captureSchema(SessionRegistry.Session owner,String requested,String tableFilter)throws Exception{return SchemaMetadataProjection.capture(this,owner,requested,tableFilter);}
    void checkSchemaCaptureOwner(SessionRegistry.Session session,RefreshReservation reservation){var owner=source(session);synchronized(owner){checkRefreshReservation(session,owner,reservation,true);}}
    MetadataSnapshot publishSchemaCapture(SessionRegistry.Session session,RefreshReservation reservation,IdentifierRules rules,Map<MetadataScope,Branch> branches,boolean sessionOwned,long deadline)throws Exception {
        try{return publish(session,reservation.ticket,rules,branches,sessionOwned,null,false,true,reservation,null,deadline);}
        catch(IllegalStateException failure){
            // Writer admission may outlive the owner. Recheck only the original
            // scalar reservation; never reacquire catalog data or mint a retry.
            try{checkSchemaCaptureOwner(session,reservation);}
            catch(RuntimeException changed){if(changed!=failure)changed.addSuppressed(failure);throw changed;}
            throw failure;
        }
    }
    /** Equivalent acquisitions share work; each waiter owns its cancellation/deadline. */
    public MetadataSnapshot coalesce(SessionRegistry.Session session,String operation,Callable<MetadataSnapshot> acquisition)throws Exception {
        String key=MetadataIdentity.digest(session.metadataSourceIdentity,session.id,Long.toString(session.revision),Long.toString(session.contextRevision),Long.toString(configuration(session).revision()),operation);
        var future=new CompletableFuture<MetadataSnapshot>();CompletableFuture<MetadataSnapshot> existing;
        synchronized(refreshing) {
            existing=refreshing.get(key);
            if(existing==null){if(refreshing.size()>=32)throw new IllegalStateException("Metadata in-flight acquisition limit (32) reached");refreshing.put(key,future);}
        }
        if(existing==null) {
            try{var snapshot=acquisition.call();future.complete(snapshot);return snapshot;}
            catch(Exception failure){future.completeExceptionally(failure);throw failure;}
            finally{refreshing.remove(key,future);}
        }
        long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(30);
        while(true) {
            if(io.grpc.Context.current().isCancelled()||Thread.currentThread().isInterrupted())throw new CancellationException("Joined metadata request cancelled");
            if(System.nanoTime()>deadline)throw new TimeoutException("Joined metadata request deadline exceeded");
            try{return existing.get(50,TimeUnit.MILLISECONDS);}
            catch(TimeoutException waiting){}
            catch(ExecutionException failure){if(failure.getCause() instanceof Exception error)throw error;throw new IllegalStateException("Metadata acquisition failed",failure.getCause());}
        }
    }
    private record InspectionTarget(String catalog,String schema,String table){}
    /** Scalar authority only: no Source, snapshot, native index or rule map. */
    private record InspectionOwner(String source,long sourceOwner,long durableRevision,long overlayOwner,long resolutionOwner,
            long configuration,long revision,long context,long proof,long request,String rules,IdentifierRules.ServerIdentity identity){}
    public TableStructure readTableStructure(SessionRegistry.Session session,String catalog,String schema,String table)throws Exception {
        var target=inspectionTarget(session,catalog,schema,table);verifyInspectionTarget(session,target);
        try(var admission=admitAcquisition()){return NativeStructureReader.inspect(session,target.catalog(),target.schema(),target.table(),true,admission::reserveAdditional);}
    }
    private InspectionTarget inspectionTarget(SessionRegistry.Session session,String catalog,String schema,String table)throws Exception {
        requireResolutionOwner(session);
        String exactCatalog=catalog.isEmpty()?(session.profile.getEngine()!=Engine.POSTGRESQL&&!schema.isEmpty()?schema:session.context.catalog()):catalog;
        String exactSchema=schema.isEmpty()?(session.profile.getEngine()==Engine.POSTGRESQL?session.context.schema():exactCatalog):schema;
        if(session.profile.getEngine()==Engine.POSTGRESQL){
            if(exactSchema.equals("pg_temp")){if(session.context.temporarySchema().isEmpty())throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.UNAVAILABLE);exactSchema=session.context.temporarySchema();}
            if(exactSchema.startsWith("pg_temp_")&&(!exactCatalog.equals(session.context.catalog())||!exactSchema.equals(session.context.temporarySchema())))throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.INVALID_OWNER);
        }
        return canonicalInspectionTarget(session,new InspectionTarget(exactCatalog,exactSchema,table));
    }
    /** Pure, brief lookup: executable spelling comes from a unique cached native
     * identity, never a display label or a normalized comparison key. */
    private InspectionTarget canonicalInspectionTarget(SessionRegistry.Session session,InspectionTarget requested){
        var snapshot=capture(session);if(!snapshot.identifierRulesAvailable())return requested;
        var found=RetainedMetadataProof.sourceRelations(snapshot,requested.catalog(),requested.schema(),requested.table(),true);
        if(found.size()!=1)return requested;var identity=found.getFirst().identity();
        if(!identity.sessionOwner().isEmpty()&&!identity.sessionOwner().equals(session.id))throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.INVALID_OWNER);
        return new InspectionTarget(identity.catalog(),identity.schema(),identity.name());
    }
    /** Same owning-PG-temp policy as central owned publication; only exact
     * physical namespace evidence can qualify, never a display alias. */
    public static boolean permitsInspection(MetadataConfiguration configuration,Engine engine,io.busystack.busydata.adapters.JdbcAdapter.LiveContext context,String catalog,String schema,String table,ObjectKind kind){
        return configuration.permits(catalog,schema,kind,table)||engine==Engine.POSTGRESQL&&context!=null&&!context.temporarySchema().isEmpty()&&catalog.equals(context.catalog())&&schema.equals(context.temporarySchema())&&configuration.kinds().contains(kind);
    }
    private void verifyInspectionTarget(SessionRegistry.Session session,InspectionTarget target)throws Exception {
        requireResolutionOwner(session);ensureOwnedIdentifierRules(session,System.nanoTime()+TimeUnit.SECONDS.toNanos(10));requirePersistentMetadata(session);
        if(session.profile.getEngine()!=Engine.POSTGRESQL)io.busystack.busydata.schema.OwnedTemporarySource.verify(this,session,target.catalog(),target.schema(),target.table(),System.nanoTime()+TimeUnit.SECONDS.toNanos(10),null).requirePersistent();
    }
    private InspectionOwner inspectionOwner(SessionRegistry.Session session){
        requireResolutionOwner(session);capture(session);var source=source(session);String key=session.metadataSourceIdentity;
        synchronized(source){
            if(sources.get(key)!=source)throw inspectionStale();var overlay=overlays.get(session.id);var resolution=sessionResolutions.get(session.id);
            var result=new InspectionOwner(key,source.owner,source.snapshot.get().revision(),overlay==null?0:overlay.owner(),resolution==null?0:resolution.owner(),configuration(session).revision(),session.revision,session.contextRevision,source.proofEpoch,source.requestEpoch,source.snapshot.get().rules().fingerprint(),session.identifierContext);
            checkInspectionOwner(session,result);return result;
        }
    }
    private static void checkInspectionDeadline(long deadline){try{checkPublicationDeadline(deadline);}catch(TimeoutException expired){throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.TIMED_OUT,io.busystack.busydata.rpc.WorkbenchFailure.Origin.INSPECTION);}}
    private static io.busystack.busydata.rpc.WorkbenchFailure inspectionStale(){return new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.STALE,io.busystack.busydata.rpc.WorkbenchFailure.Origin.INSPECTION);}
    private void checkInspectionOwner(SessionRegistry.Session session,InspectionOwner captured){
        if(!session.lock.isHeldByCurrentThread())throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.INVALID_OWNER);
        if(session.physicalEnded()||session.state==TransactionState.DISCONNECTED||session.state==TransactionState.UNKNOWN_TRANSACTION)throw inspectionStale();
        if(!captured.source().equals(session.metadataSourceIdentity))throw inspectionStale();var source=sources.get(captured.source());if(source==null)throw inspectionStale();
        synchronized(source){
            var overlay=overlays.get(session.id);var resolution=sessionResolutions.get(session.id);
            if(sources.get(captured.source())!=source||source.owner!=captured.sourceOwner()||source.snapshot.get().revision()!=captured.durableRevision()
                ||(overlay==null?0:overlay.owner())!=captured.overlayOwner()||(resolution==null?0:resolution.owner())!=captured.resolutionOwner()
                ||configuration(session).revision()!=captured.configuration()||session.revision!=captured.revision()||session.contextRevision!=captured.context()
                ||source.proofEpoch!=captured.proof()||source.requestEpoch!=captured.request()||source.configurationPending
                ||!source.snapshot.get().rules().fingerprint().equals(captured.rules())||!Objects.equals(session.identifierContext,captured.identity()))throw inspectionStale();
            var state=proofAdmissionState(source,new ProofFence(captured.source(),captured.sourceOwner(),captured.proof()),session.identifierContext);
            if(state!=MetadataState.AVAILABLE)throw new io.busystack.busydata.rpc.WorkbenchFailure(state==MetadataState.STALE?io.busystack.busydata.rpc.WorkbenchFailure.Reason.STALE:io.busystack.busydata.rpc.WorkbenchFailure.Reason.UNAVAILABLE,io.busystack.busydata.rpc.WorkbenchFailure.Origin.INSPECTION);
        }
    }
    /** Scalar central owner for a bounded native observation. No source/catalog is leased. */
    public final class OwnedReadFence {
        private final SessionRegistry.Session physical;private final InspectionOwner owner;
        private OwnedReadFence(SessionRegistry.Session physical,InspectionOwner owner){this.physical=physical;this.owner=owner;}
        public void check(SessionRegistry.Session current){if(current!=physical)throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.INVALID_OWNER);checkInspectionOwner(current,owner);}
        /** Fail closed under the exact scalar owner before fallible coverage allocation. */
        public void retireUnknown(SessionRegistry.Session current,String reason){
            if(current!=physical)throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.INVALID_OWNER);
            var source=sources.get(owner.source());if(source==null)throw inspectionStale();
            synchronized(source){checkInspectionOwner(current,owner);markSessionResolutionUnknown(current,reason);}
        }
        /** Internal review digest only; private owner counters never become protocol fields. */
        public String fingerprint(){return MetadataIdentity.digest("owned-native-read-v1",physical.id,owner.source(),Long.toString(owner.sourceOwner()),Long.toString(owner.durableRevision()),Long.toString(owner.overlayOwner()),Long.toString(owner.resolutionOwner()),Long.toString(owner.configuration()),Long.toString(owner.revision()),Long.toString(owner.context()),Long.toString(owner.proof()),Long.toString(owner.request()),owner.rules(),Objects.toString(owner.identity(),""));}
    }
    public OwnedReadFence ownedReadFence(SessionRegistry.Session session){requireResolutionOwner(session);requirePersistentMetadata(session);return new OwnedReadFence(session,inspectionOwner(session));}
    /** Compact operation-owned evidence; no captured catalog generation escapes
     * the short pure extraction phase or enters a deferred change plan. */
    public final class TableInspection implements AutoCloseable {
        private SessionRegistry.Session session;private InspectionOwner owner;private TableStructure structure;
        private RetainedMetadataProof proof;private Map<SchemaObject,SchemaObject> types;private final AcquisitionAdmission admission;
        private final long deadline;private final Thread thread=Thread.currentThread();private boolean closed;
        private TableInspection(SessionRegistry.Session session,InspectionOwner owner,TableStructure structure,RetainedMetadataProof proof,Map<SchemaObject,SchemaObject> types,AcquisitionAdmission admission,long deadline){this.session=session;this.owner=owner;this.structure=structure;this.proof=proof;this.types=types;this.admission=admission;this.deadline=deadline;}
        public void checkCurrent(){
            if(closed)throw inspectionStale();if(Thread.currentThread()!=thread)throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.INVALID_OWNER);
            checkInspectionDeadline(deadline);
            checkInspectionOwner(session,owner);
        }
        public TableStructure structure(){checkCurrent();return structure;}
        public RetainedMetadataProof proof(){checkCurrent();return proof;}
        public long metadataRevision(){checkCurrent();return proof.snapshotRevision();}
        public long configurationRevision(){checkCurrent();return owner.configuration();}
        public SchemaObject typeEvidence(SchemaObject column){checkCurrent();var result=types.get(column);if(result==null)throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.INVALID_OWNER);return result;}
        public PreparedMetadataWitness captureWitness(io.busystack.busydata.jobs.Jobs.Job job)throws Exception {
            checkCurrent();var witness=PreparedMetadataWitness.captureInspection(session,proof,job);
            try{checkCurrent();return witness;}catch(RuntimeException failure){if(witness!=null)witness.close();throw failure;}
        }
        @Override public void close(){if(Thread.currentThread()!=thread)throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.INVALID_OWNER);if(!closed){closed=true;try{admission.close();}finally{session=null;owner=null;structure=null;proof=null;types=null;}}}
    }
    public TableInspection inspectTable(SessionRegistry.Session session,String catalog,String schema,String table,List<Column> projection)throws Exception {
        if(projection.isEmpty()||projection.size()>ExecutionMetadata.MAX_COLUMNS)throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.MALFORMED_REQUEST);
        long deadline=defaultPublicationDeadline();var target=inspectionTarget(session,catalog,schema,table);
        // This caller supplies exact retained-proof identities after result and
        // requested-target ownership checks, never a UI label or raw alias.
        var configured=configuration(session);if(!permitsInspection(configured,session.profile.getEngine(),session.context,target.catalog(),target.schema(),target.table(),ObjectKind.TABLE)||!permitsInspection(configured,session.profile.getEngine(),session.context,target.catalog(),target.schema(),target.table(),ObjectKind.COLUMN))throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.INCOMPLETE_METADATA);
        verifyInspectionTarget(session,target);var owner=inspectionOwner(session);
        var admission=admitAcquisition();boolean returned=false;
        try{
            var structure=NativeStructureReader.inspect(session,target.catalog(),target.schema(),target.table(),true,admission::reserveAdditional);checkInspectionOwner(session,owner);checkPublicationDeadline(deadline);
            admission.reserveAdditional(inspectionStructureBytes(structure));
            var relation=inspectionRelation(session,target,structure,deadline);checkInspectionOwner(session,owner);
            var evidence=inspectionEvidence(session,owner,relation,structure,projection,admission,deadline);checkInspectionOwner(session,owner);checkPublicationDeadline(deadline);
            admission.sealInspection(evidence.bytes());
            var result=new TableInspection(session,owner,structure,evidence.proof(),evidence.types(),admission,deadline);returned=true;return result;
        }finally{if(!returned)admission.close();}
    }
    private record InspectionEvidence(RetainedMetadataProof proof,Map<SchemaObject,SchemaObject> types,long bytes){}
    /** A snapshot is read only inside this pure, bounded extraction. Its native
     * indexes/rules/objects are not retained by the compact result or handle. */
    private InspectionEvidence inspectionEvidence(SessionRegistry.Session session,InspectionOwner owner,SchemaObject relation,TableStructure structure,List<Column> projection,AcquisitionAdmission admission,long deadline){
        checkInspectionOwner(session,owner);var snapshot=capture(session);checkInspectionOwner(session,owner);
        var proof=ExecutionMetadata.inspected(snapshot,relation,structure,projection,session.targetProfile(),session.id,session.context,configuration(session),session.revision,session.contextRevision,admission,()->{checkInspectionDeadline(deadline);checkInspectionOwner(session,owner);}).proof(projection);
        var selected=new HashSet<String>();for(var column:projection)selected.add(snapshot.rules().lookup(ObjectKind.COLUMN,column.getBaseColumn(),true));
        var types=new IdentityHashMap<SchemaObject,SchemaObject>();long bytes=1024L+proof.estimatedBytes()+inspectionStructureBytes(structure);
        for(var column:structure.columns())if(selected.contains(snapshot.rules().lookup(ObjectKind.COLUMN,column.getName(),true))){
            checkInspectionDeadline(deadline);checkInspectionOwner(session,owner);var type=EditTypeEvidence.forColumn(snapshot,column,admission::reserveAdditional);types.put(column,type);bytes+=256L+4L*column.getName().length();if(type!=column)bytes+=2048L+4L*type.getSerializedSize();
            if(bytes>MAX_TOTAL_BYTES)throw new IllegalStateException("Owned inspection evidence exceeds metadata admission");
        }
        checkInspectionOwner(session,owner);return new InspectionEvidence(proof,Collections.unmodifiableMap(types),bytes);
    }
    private static long inspectionStructureBytes(TableStructure structure){
        long bytes=1024L+4L*(structure.signature().length()+structure.recoverySignature().length());
        for(var group:List.of(structure.columns(),structure.constraints(),structure.relationships(),structure.indexes()))for(var object:group)bytes+=2048L+4L*object.getSerializedSize();
        bytes+=256L*structure.types().size();for(var identity:structure.identities())bytes+=256L+256L*identity.size();return bytes;
    }
    private SchemaObject inspectionRelation(SessionRegistry.Session session,InspectionTarget target,TableStructure structure,long deadline)throws Exception {
        var request=ExploreRequest.newBuilder().setCatalog(target.catalog()).setSchema(target.schema()).setKind(ObjectKind.TABLE).setSearch(target.table()).setExactName(true).setIntrospectionLevel(1).setLimit(1).build();
        var markers=new io.busystack.busydata.schema.Explorer(this).fetchBranch(session,request,deadline);if(markers.size()!=1)throw new IllegalStateException("Reviewed table identity changed during metadata inspection");
        var relation=SchemaObject.newBuilder().putAllProperties(markers.getFirst().getPropertiesMap()).putAllProperties(NativeRelationReader.identityProperties(structure.nativeGeneration())).setCatalog(target.catalog()).setSchema(target.schema()).setName(target.table()).setKind(ObjectKind.TABLE).setSubtype(ObjectSubtype.ORDINARY_TABLE).putProperties("editabilitySignature",structure.signature()).putProperties("baseTableVerified","true").putProperties("nativeGeneration",structure.nativeGeneration()).putProperties("nativeGenerationAvailability",structure.nativeGenerationAvailability()).putProperties("nativeId",structure.columns().isEmpty()?"":structure.columns().getFirst().getPropertiesOrDefault("parentNativeId","")).build();
        if(session.profile.getEngine()==Engine.POSTGRESQL)relation=relation.toBuilder().putProperties("typeDependenciesFingerprint",NativeTypeReader.namespaceFingerprints(session,target.schema(),target.table(),deadline).getOrDefault(target.table(),"")).build();
        return relation;
    }
    private static void putStructuralBranch(Map<MetadataScope,Branch> branches,MetadataScope scope,List<SchemaObject> values,SessionRegistry.Session session) {
        branches.put(scope,new Branch(values,new MetadataCoverage(scope,IntrospectionLevel.STRUCTURE,MetadataState.AVAILABLE,true,MetadataIdentity.digest(values.toString()),session.revision,session.contextRevision,System.currentTimeMillis(),"")));
    }
    /** The caller captured and verified the physical/session/context owner around all JDBC work. */
    public MetadataSnapshot publish(SessionRegistry.Session session,long ticket,IdentifierRules rules,Map<MetadataScope,Branch> branches,boolean sessionOwned)throws Exception{return publish(session,ticket,rules,branches,sessionOwned,null);}
    public MetadataSnapshot publish(SessionRegistry.Session session,long ticket,IdentifierRules rules,Map<MetadataScope,Branch> branches,boolean sessionOwned,AcquisitionAdmission admission)throws Exception {
        return publish(session,ticket,rules,branches,sessionOwned,admission,false,true);
    }
    /** The queued-owner fence and the existing publication checks share one
     * monitor with every explicit reservation; neither may race the final swap. */
    public MetadataSnapshot publish(SessionRegistry.Session session,RefreshReservation reservation,IdentifierRules rules,Map<MetadataScope,Branch> branches,AcquisitionAdmission admission)throws Exception {
        return publish(session,reservation,rules,branches,admission,null);
    }
    MetadataSnapshot publish(SessionRegistry.Session session,RefreshReservation reservation,IdentifierRules rules,Map<MetadataScope,Branch> branches,AcquisitionAdmission admission,java.util.function.Function<MetadataSnapshot,RefreshDiagnostics> report)throws Exception {
        return publish(session,reservation,rules,branches,admission,defaultPublicationDeadline(),report);
    }
    MetadataSnapshot publish(SessionRegistry.Session session,RefreshReservation reservation,IdentifierRules rules,Map<MetadataScope,Branch> branches,AcquisitionAdmission admission,long deadline,java.util.function.Function<MetadataSnapshot,RefreshDiagnostics> report)throws Exception {
        return publish(session,reservation.ticket,rules,branches,false,admission,false,true,reservation,report,deadline);
    }
    /** One atomic owned inventory publication restores durable fallback for
     * removed temporary identities; an empty temp branch must not hide it. */
    public MetadataSnapshot publishTemporaryInventory(SessionRegistry.Session session,long ticket,IdentifierRules rules,Map<MetadataScope,Branch> branches)throws Exception {
        requireResolutionOwner(session);return publish(session,ticket,rules,branches,true,null,true,true);
    }
    private MetadataSnapshot publish(SessionRegistry.Session session,long ticket,IdentifierRules rules,Map<MetadataScope,Branch> branches,boolean sessionOwned,AcquisitionAdmission admission,boolean replaceTemporary,boolean acquiredTemporary)throws Exception {
        return publish(session,ticket,rules,branches,sessionOwned,admission,replaceTemporary,acquiredTemporary,null,null);
    }
    private record PublicationSeed(MetadataSnapshot durable,MetadataConfiguration configuration,Map<MetadataScope,Long> published,Map<String,Overlay> overlays,Map<String,ResolutionOwner> resolutions,long revision,long context,long proofEpoch){}
    private record PreparedPublication(MetadataSnapshot next,Map<MetadataScope,Long> published,Map<String,Overlay> overlays,ResolutionOwner ownedResolution,boolean fresh){}
    private static long defaultPublicationDeadline(){return System.nanoTime()+TimeUnit.SECONDS.toNanos(30);}
    private static void checkPublicationDeadline(long deadline)throws TimeoutException {
        if(System.nanoTime()>deadline)throw new TimeoutException("Metadata publication preparation deadline exceeded");
        if(io.grpc.Context.current().isCancelled()||Thread.currentThread().isInterrupted())throw new CancellationException("Metadata publication cancelled");
    }
    private void enterWriter(Source owner,SessionRegistry.Session session,long deadline)throws Exception {
        checkPublicationDeadline(deadline);
        if(session.lock.isHeldByCurrentThread()){
            if(!owner.writer.tryLock())throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.UNAVAILABLE);
            return;
        }
        // Observe request cancellation while an earlier cache attempt owns the
        // writer gate. No wait here owns Source or a physical session.
        while(true){
            checkPublicationDeadline(deadline);long remaining=deadline-System.nanoTime();
            if(owner.writer.tryLock(Math.min(Math.max(0,remaining),TimeUnit.MILLISECONDS.toNanos(25)),TimeUnit.NANOSECONDS))return;
        }
    }
    private void validatePublication(SessionRegistry.Session session,Source owner,String key,long ticket,IdentifierRules rules,boolean sessionOwned,RefreshReservation reservation){
        if(sources.get(key)!=owner)throw new SupersededRefresh();checkExternalPublication(owner,ticket);checkRulesPublication(owner,ticket,rules,sessionOwned);
        if(rules.complete())checkIdentifierAffinity(rules,session.identifierContext);if(reservation!=null)checkRefreshReservation(session,owner,reservation);
        if(session.physicalEnded()||session.state==TransactionState.DISCONNECTED||session.state==TransactionState.UNKNOWN_TRANSACTION)throw new IllegalStateException("Metadata physical session ended before publication");
        if(owner.configurationPending||ticket<=owner.configurationTicket)throw new SupersededRefresh();
        if(io.grpc.Context.current().isCancelled()||Thread.currentThread().isInterrupted())throw new CancellationException("Metadata publication cancelled");
    }
    private PublicationSeed publicationSeed(SessionRegistry.Session session,Source owner,String key,long ticket,IdentifierRules rules,boolean sessionOwned,RefreshReservation reservation){
        validatePublication(session,owner,key,ticket,rules,sessionOwned,reservation);
        var scoped=new HashMap<String,Overlay>();for(var entry:overlays.entrySet())if(entry.getValue().source().equals(key))scoped.put(entry.getKey(),entry.getValue());
        var resolutions=new HashMap<String,ResolutionOwner>();for(var entry:sessionResolutions.entrySet())if(entry.getValue().source().equals(key))resolutions.put(entry.getKey(),entry.getValue());
        return new PublicationSeed(owner.snapshot.get(),configuration(session),sessionOwned?owner.overlayPublished.getOrDefault(session.id,Map.of()):owner.published,Map.copyOf(scoped),Map.copyOf(resolutions),session.revision,session.contextRevision,owner.proofEpoch);
    }
    private void validateSeed(SessionRegistry.Session session,Source owner,String key,PublicationSeed seed,boolean sessionOwned){
        if(owner.snapshot.get()!=seed.durable()||owner.proofEpoch!=seed.proofEpoch()||session.revision!=seed.revision()||session.contextRevision!=seed.context()||configuration(session).revision()!=seed.configuration().revision())throw new SupersededRefresh();
        if(sessionOwned){if(overlays.get(session.id)!=seed.overlays().get(session.id)||sessionResolutions.get(session.id)!=seed.resolutions().get(session.id))throw new SupersededRefresh();return;}
        int found=0;for(var entry:overlays.entrySet())if(entry.getValue().source().equals(key)){found++;if(seed.overlays().get(entry.getKey())!=entry.getValue())throw new SupersededRefresh();}if(found!=seed.overlays().size())throw new SupersededRefresh();
        found=0;for(var entry:sessionResolutions.entrySet())if(entry.getValue().source().equals(key)){found++;if(seed.resolutions().get(entry.getKey())!=entry.getValue())throw new SupersededRefresh();}if(found!=seed.resolutions().size())throw new SupersededRefresh();
    }
    static boolean freshRoutinePoint(MetadataScope scope,MetadataCoverage coverage,Branch branch,Map<String,MetadataObject> entries,Set<MetadataObject> admitted,IdentifierRules rules){
        if(!coverage.complete()||branch.reuse()||!coverage.scope().equals(scope)||scope.kind()!=ObjectKind.ROUTINE||!scope.exactName()||scope.catalog().isEmpty()||scope.schema().isEmpty()||!scope.parent().isEmpty()||scope.signature().isEmpty()||scope.subtype()==ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED||!branch.objects().isEmpty()||branch.normalized().size()!=1)return false;
        var object=branch.normalized().getFirst();var id=object.identity();
        return admitted.contains(object)&&entries.get(id.key())==object&&object.state()==MetadataState.AVAILABLE&&object.level().includes(coverage.level())&&id.kind()==ObjectKind.ROUTINE&&id.parent().isEmpty()&&id.sessionOwner().isEmpty()&&object.withRules(rules)==object&&scope.catalog().equals(id.catalog())&&scope.schema().equals(id.schema())&&scope.search().equals(id.name())&&scope.signature().equals(id.signature())&&scope.subtype()==id.subtype();
    }
    /** Concurrent physical retirement/opaque-state changes also write these
     * bounded maps. Equality is insufficient: only the captured owner may swap. */
    static <T> boolean replaceCaptured(ConcurrentMap<String,T> owners,String id,T captured,T replacement){
        boolean[] replaced={false};owners.compute(id,(key,current)->{if(current!=captured)return current;replaced[0]=true;return replacement;});return replaced[0];
    }
    private MetadataRepository.WriteReceipt persistCommitted(Source owner,MetadataSnapshot snapshot,MetadataSnapshot previous,long deadline){
        long began=System.nanoTime();synchronized(owner){owner.cacheAttempt=null;owner.cacheMetrics=null;owner.cacheWriteNanos=0;owner.cacheFailure=null;owner.cacheState="WRITE_PENDING";owner.cacheSubmissionDeadline=deadline;}try{
            var receipt=repository.publish(snapshot,previous,deadline,owner.owner);
            synchronized(owner){owner.cacheAttempt=receipt;owner.cacheMetrics=null;owner.cacheWriteNanos=0;owner.cacheFailure=null;owner.cacheState="WRITE_PENDING";}
            receipt.observe(cacheCompletionListener(this));return receipt;
        }catch(java.sql.SQLException|CancellationException unavailable){cacheSubmissionFailed(owner,unavailable,System.nanoTime()-began);owner.pendingCacheWrites.decrementAndGet();pendingCacheWrites.decrementAndGet();return null;}
        catch(RuntimeException|Error problem){
            var receipt=repository.activeReceipt().filter(value->value.identity().sourceOwner()==owner.owner&&value.identity().matches(snapshot)).orElse(null);
            if(receipt!=null){synchronized(owner){owner.cacheAttempt=receipt;owner.cacheMetrics=null;owner.cacheState="WRITE_PENDING";}receipt.observe(cacheCompletionListener(this));}
            else{cacheSubmissionFailed(owner,problem,System.nanoTime()-began);owner.pendingCacheWrites.decrementAndGet();pendingCacheWrites.decrementAndGet();}throw problem;
        }
    }
    static void cacheSubmissionFailed(Source owner,Throwable failure,long duration){synchronized(owner){owner.cacheAttempt=null;owner.cacheMetrics=null;owner.cacheFailure=MetadataRepository.writeFailure(failure);owner.cacheState="WRITE_UNAVAILABLE";owner.cacheWriteNanos=duration;owner.cacheSubmissionDeadline=0;}}
    private static MetadataRepository.CompletionListener cacheCompletionListener(MetadataPlatform platform){var weak=new java.lang.ref.WeakReference<>(platform);return completion->{var current=weak.get();if(current!=null)current.cacheCompleted(completion);};}
    private void cacheCompleted(MetadataRepository.WriteCompletion completion){
        var id=completion.identity();var owner=sources.get(id.source());try{
            if(owner==null||owner.owner!=id.sourceOwner())return;
            synchronized(owner){
                var current=owner.cacheAttempt;if(sources.get(id.source())!=owner||current==null||current.identity().attemptId()!=id.attemptId()||current.identity().sourceOwner()!=id.sourceOwner()||!id.matches(owner.snapshot.get()))return;
                var metrics=completion.metrics();owner.cacheMetrics=new CacheMetrics(owner.owner,id,metrics);owner.cacheWriteNanos=metrics.totalNanos();
                owner.cacheFailure=completion.failure()!=null?completion.failure().primary():null;
                owner.cacheState=owner.cacheFailure==null?"AVAILABLE":"WRITE_UNAVAILABLE";
                var gap=owner.cacheGap;if(owner.cacheFailure==null&&gap!=null&&id.snapshotRevision()>=gap.revision()&&id.configurationRevision()>=gap.configuration()&&id.rulesFingerprint().equals(gap.rules()))owner.cacheGap=null;
            }
        }finally{if(owner!=null&&owner.owner==id.sourceOwner())owner.pendingCacheWrites.decrementAndGet();pendingCacheWrites.decrementAndGet();}
    }
    private static void awaitCache(MetadataRepository.WriteReceipt receipt,long deadline){if(receipt!=null)try{receipt.awaitCompletion(deadline);}catch(java.sql.SQLException pending){/* Fresh memory remains authoritative; receipt and slot retain the actual native outcome. */}}
    private MetadataSnapshot publish(SessionRegistry.Session session,long ticket,IdentifierRules rules,Map<MetadataScope,Branch> branches,boolean sessionOwned,AcquisitionAdmission admission,boolean replaceTemporary,boolean acquiredTemporary,RefreshReservation reservation,java.util.function.Function<MetadataSnapshot,RefreshDiagnostics> report)throws Exception {
        return publish(session,ticket,rules,branches,sessionOwned,admission,replaceTemporary,acquiredTemporary,reservation,report,defaultPublicationDeadline());
    }
    private MetadataSnapshot publish(SessionRegistry.Session session,long ticket,IdentifierRules rules,Map<MetadataScope,Branch> branches,boolean sessionOwned,AcquisitionAdmission admission,boolean replaceTemporary,boolean acquiredTemporary,RefreshReservation reservation,java.util.function.Function<MetadataSnapshot,RefreshDiagnostics> report,long deadline)throws Exception {
        return publish(session,ticket,rules,branches,sessionOwned,admission,replaceTemporary,acquiredTemporary,reservation,report,deadline,false);
    }
    private MetadataSnapshot publish(SessionRegistry.Session session,long ticket,IdentifierRules rules,Map<MetadataScope,Branch> branches,boolean sessionOwned,AcquisitionAdmission admission,boolean replaceTemporary,boolean acquiredTemporary,RefreshReservation reservation,java.util.function.Function<MetadataSnapshot,RefreshDiagnostics> report,long deadline,boolean discardPersistent)throws Exception {
        if(discardPersistent&&!sessionOwned)throw new IllegalArgumentException("Only owned pending structure may be retired");
        if(sessionOwned)requireResolutionOwner(session);
        var owner=source(session);String key=session.metadataSourceIdentity;boolean writer=false;MetadataRepository.WriteReceipt cacheReceipt=null;
        AcquisitionAdmission created=admission==null?admitAcquisition():null;var active=created==null?admission:created;
        try{
            if(!sessionOwned){enterWriter(owner,session,deadline);writer=true;}
            PublicationSeed seed;synchronized(owner){seed=publicationSeed(session,owner,key,ticket,rules,sessionOwned,reservation);}
            var prepared=sessionOwned?prepareOwnedPublication(session,key,ticket,rules,branches,replaceTemporary,acquiredTemporary,discardPersistent,seed,active,deadline):prepareDurablePublication(session,key,ticket,rules,branches,seed,active,deadline);
            checkPublicationDeadline(deadline);beforeCommit.run();checkPublicationDeadline(deadline);MetadataSnapshot committed;
            synchronized(admissionLock){synchronized(owner){
                validatePublication(session,owner,key,ticket,rules,sessionOwned,reservation);validateSeed(session,owner,key,seed,sessionOwned);
                if(sessionOwned){
                    var replacement=prepared.overlays().get(session.id);enforceBudget(key,session.id,replacement==null?0:replacement.snapshot().estimatedBytes(),true,active);if(replacement!=null&&overlays.size()>=8&&!overlays.containsKey(session.id))throw new IllegalStateException("Session metadata overlay admission limit reached");
                    if(!replaceCaptured(overlays,session.id,seed.overlays().get(session.id),replacement))throw new SupersededRefresh();
                    if(prepared.ownedResolution()!=null)replaceCaptured(sessionResolutions,session.id,seed.resolutions().get(session.id),prepared.ownedResolution());if(replacement==null)owner.overlayPublished.remove(session.id);else owner.overlayPublished.put(session.id,prepared.published());
                }else{
                    long bytes=prepared.next().estimatedBytes();for(var overlay:prepared.overlays().values())bytes+=overlay.snapshot().estimatedBytes();enforceRuleBudget(key,bytes,active);
                    boolean changed=commitSnapshot(owner,ticket,prepared.next());for(var entry:prepared.overlays().entrySet())replaceCaptured(overlays,entry.getKey(),seed.overlays().get(entry.getKey()),entry.getValue());if(changed)retireRuleResolutions(key,rules);
                    owner.published=prepared.published();explicitPublication(owner,reservation==null||!reservation.queued,prepared.fresh());
                }
                if(active!=null)active.committed();
                var visible=overlays.get(session.id);committed=resolutionView(session,visible==null||!visible.source().equals(key)?prepared.next():visible.snapshot());
                if(!sessionOwned&&repository!=null)cachePending(owner);
            }}
            if(!sessionOwned&&repository!=null)cacheReceipt=persistCommitted(owner,prepared.next(),seed.durable(),deadline);if(report!=null)recordDiagnostics(session,report.apply(committed));return committed;
        }finally{if(writer)owner.writer.unlock();if(created!=null)created.close();awaitCache(cacheReceipt,deadline);}
    }
    private PreparedPublication prepareDurablePublication(SessionRegistry.Session session,String sourceKey,long ticket,IdentifierRules rules,Map<MetadataScope,Branch> branches,PublicationSeed seed,AcquisitionAdmission admission,long deadline)throws Exception {
        checkPublicationDeadline(deadline);long revision=seed.revision(),context=seed.context();var published=seed.published();long newest=0;for(long value:published.values())newest=Math.max(newest,value);
        if(newest>ticket)for(var scope:branches.keySet())for(var prior:published.entrySet())if(prior.getValue()>ticket&&scope.overlaps(prior.getKey()))throw new SupersededRefresh();
        var before=seed.durable();boolean changedRules=!before.rules().fingerprint().equals(rules.fingerprint());boolean fresh=false;var admittedRoutineFacts=Collections.newSetFromMap(new IdentityHashMap<MetadataObject,Boolean>());
        var entries=new LinkedHashMap<>(before.identities());var coverage=ruleCoverage(before,rules);
            var config=seed.configuration();
            for(var branch:branches.entrySet()) {
                checkPublicationDeadline(deadline);var scope=branch.getKey();var state=branch.getValue().coverage();
                if(changedRules&&branch.getValue().reuse())state=state.stale(RULES_CHANGED);
                boolean permitted=scope.kind()==ObjectKind.CATALOG&&scope.catalog().isEmpty()?config.kinds().contains(ObjectKind.CATALOG):config.permits(scope.catalog(),scope.schema(),scope.kind(),scope.parent().isEmpty()?(scope.exactName()?scope.search():""):scope.parent());
                if(!permitted)state=new MetadataCoverage(scope,state.level(),MetadataState.NOT_REQUESTED,false,state.fingerprint(),state.sourceRevision(),state.contextRevision(),state.refreshedUnixMs(),"This scope is excluded by the current introspection policy",state.defaultNamespace());
                if(!state.complete()){var prior=coverage.get(scope);state=new MetadataCoverage(scope,state.level(),state.state(),false,state.fingerprint(),state.sourceRevision(),state.contextRevision(),prior==null?0:prior.refreshedUnixMs(),state.limitation(),prior==null?state.defaultNamespace():prior.defaultNamespace());}
                if(state.sourceRevision()!=revision||state.contextRevision()!=context)throw new IllegalStateException("Metadata source revision changed before publication");
                // A failed refresh retains the old objects with an explicit stale/failed scope.
                boolean certified=state.complete()&&!branch.getValue().reuse()&&freshRoutinePoint(scope,state,branch.getValue(),entries,admittedRoutineFacts,rules);
                if(state.complete()&&!branch.getValue().reuse()&&!certified) {
                    var replaced=new ArrayList<MetadataObject>();var acquired=new ArrayList<MetadataObject>();
                    entries.entrySet().removeIf(entry->{if(!scope.contains(entry.getValue()))return false;replaced.add(entry.getValue());return true;});
                    var replacementLevel=state.level();
                    coverage.keySet().removeIf(existing->!existing.equals(scope)&&scope.encloses(existing)&&replacementLevel.includes(coverage.get(existing).level()));
                    if((scope.kind()==ObjectKind.TABLE||scope.kind()==ObjectKind.VIEW)&&scope.parent().isEmpty()) {
                        var present=new HashSet<String>();for(var object:branch.getValue().objects())present.add(object.getName());for(var object:branch.getValue().normalized())present.add(object.identity().name());
                        var deleted=new HashSet<String>();for(var old:before.select(scope))if(!present.contains(old.identity().name()))deleted.add(old.identity().name());
                        if(!deleted.isEmpty()) {
                            entries.entrySet().removeIf(entry->{var id=entry.getValue().identity();return id.catalog().equals(scope.catalog())&&id.schema().equals(scope.schema())&&deleted.contains(id.parent());});
                            coverage.replaceAll((key,value)->key.catalog().equals(scope.catalog())&&key.schema().equals(scope.schema())&&(deleted.contains(key.parent())||key.parent().isEmpty()&&key.kind()==scope.kind()&&key.exactName()&&deleted.contains(key.search()))?value.stale("The owning relation disappeared during names reconciliation"):value);
                        }
                    }
                    for(var object:branch.getValue().objects()) {
                        checkPublicationDeadline(deadline);if(object.getSchema().startsWith("pg_temp_"))throw new IllegalArgumentException("Temporary metadata has an invalid physical owner");
                        if(!config.permits(object.getCatalog(),object.getSchema(),object.getKind(),object.getTable().isEmpty()?object.getName():object.getTable()))continue;
                        if(state.level()==IntrospectionLevel.NAMES) {
                            // A plain Level 1 refresh has no structural proof. Only the
                            // refresh coordinator's normalized names branch can retain
                            // verified higher-level facts as current.
                            var prior=before.resolve(object.getCatalog(),object.getSchema(),object.getKind(),object.getTable(),object.getName(),true);
                            if(prior.stream().anyMatch(known->known.level().includes(IntrospectionLevel.STRUCTURE)))coverage.replaceAll((key,value)->key.catalog().equals(object.getCatalog())&&key.schema().equals(object.getSchema())&&(key.parent().equals(object.getName())||key.parent().isEmpty()&&key.kind()==object.getKind()&&key.exactName()&&key.search().equals(object.getName()))?value.stale("Names-only acquisition did not verify cached structural details"):value);
                        }
                        if("true".equals(object.getPropertiesOrDefault("temporary","")))throw new IllegalArgumentException("Owned temporary metadata cannot enter the durable source");
                        var normalized=MetadataObject.from(sourceKey,session.profile.getId(),"",rules,object,state.level(),revision,context);
                        var previous=before.identities().get(normalized.identity().key());if(previous!=null&&previous.sameContent(normalized))normalized=previous;
                        var displaced=entries.put(normalized.identity().key(),normalized);if(displaced!=null&&!scope.contains(displaced))replaced.add(displaced);acquired.add(normalized);
                    }
                    for(var normalized:branch.getValue().normalized()){
                        checkPublicationDeadline(deadline);var identity=normalized.identity();if(!config.permits(identity.catalog(),identity.schema(),identity.kind(),identity.parent().isEmpty()?identity.name():identity.parent()))continue;
                        if(!identity.source().equals(sourceKey)||!identity.profileId().equals(session.profile.getId())||!identity.sessionOwner().isEmpty())throw new IllegalArgumentException("Acquired metadata branch has an invalid owner");
                        var displaced=entries.put(identity.key(),normalized);if(displaced!=null&&!scope.contains(displaced))replaced.add(displaced);acquired.add(normalized);
                    }
                    if(scope.kind()==ObjectKind.ROUTINE&&(!scope.exactName()||scope.signature().isEmpty()||scope.subtype()==ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED))for(var object:acquired)if(object.identity().kind()==ObjectKind.ROUTINE&&scope.contains(object))admittedRoutineFacts.add(object);
                    for(var invalid:MetadataCoverageReconciliation.invalidated(coverage,scope,replaced,acquired))coverage.computeIfPresent(invalid,(key,value)->value.stale("An overlapping publication changed identities or replaced higher-level facts"));
                }
                coverage.put(scope,state);fresh|=state.complete()&&!branch.getValue().reuse();
            }
            checkPublicationDeadline(deadline);entries.replaceAll((key,object)->object.withRules(rules));
            long estimate=semanticBytes(rules,entries.values());
            {long total=estimate;for(var overlay:seed.overlays().values())total+=overlay.snapshot().estimatedBytes();enforceRuleBudget(sourceKey,total,admission);}
            // Admit before allocating the next snapshot's indexes. Rejected
            // sources must not exhaust the process while constructing a model
            // which could never be published.

            checkPublicationDeadline(deadline);var next=MetadataSnapshot.prepare(sourceKey,session.profile.getId(),Math.max(before.revision(),seed.durable().revision())+1,config.revision(),System.currentTimeMillis(),rules,entries.values(),coverage,deadline);
            var rekeyed=new LinkedHashMap<String,Overlay>();var planned=new LinkedHashMap<String,OverlayContents>();long stagedBytes=estimate,allocationBytes=0;
            for(var entry:seed.overlays().entrySet()){
                checkPublicationDeadline(deadline);var old=entry.getValue();var content=overlayContents(next,old.snapshot(),old.scopes(),entry.getKey());
                var charge=MetadataSnapshot.estimateComposition(next,old.snapshot(),content.entries(),old.scopes(),content.coverage(),content.removed());long reasonCharge=inheritedCoverageCharge(charge.residentBytes(),content.inheritedStale());stagedBytes+=charge.residentBytes()+reasonCharge;allocationBytes+=charge.allocationBytes()+reasonCharge;planned.put(entry.getKey(),content);
            }
            enforceRuleBudget(sourceKey,stagedBytes,admission);
            if(admission!=null)admission.reserveAdditional(allocationBytes);
            else if(allocationBytes!=0)throw new IllegalStateException("Rebasing owned metadata requires acquisition admission");
            for(var entry:planned.entrySet()){
                var old=seed.overlays().get(entry.getKey());var content=entry.getValue();long valueRevision=Math.max(next.revision(),old.snapshot().revision())+1;
                var snapshot=MetadataSnapshot.compose(next,content.entries(),old.scopes(),content.coverage(),content.removed(),valueRevision,next.configurationRevision(),next.createdUnixMs(),deadline);
                if(!content.inheritedStale().isEmpty())snapshot=snapshot.withInheritedCoverageStale(valueRevision,content.inheritedStale());
                rekeyed.put(entry.getKey(),new Overlay(sourceKey,old.sessionRevision(),old.contextRevision(),next.revision(),old.scopes(),snapshot));
            }
        var tickets=new HashMap<>(published);for(var scope:branches.keySet())tickets.put(scope,ticket);tickets.keySet().retainAll(next.catalogCoverage().keySet());
        return new PreparedPublication(next,Map.copyOf(tickets),Map.copyOf(rekeyed),null,fresh);
    }
    private static long inheritedCoverageCharge(long compositionCharge,String reason){return reason.isEmpty()?0:(compositionCharge==0?1024:0)+512L+2L*reason.length();}
    private PreparedPublication prepareOwnedPublication(SessionRegistry.Session session,String sourceKey,long ticket,IdentifierRules rules,Map<MetadataScope,Branch> branches,boolean replaceTemporary,boolean acquiredTemporary,boolean discardPersistent,PublicationSeed seed,AcquisitionAdmission admission,long deadline)throws Exception{
        var old=seed.overlays().get(session.id);var prior=old==null?null:old.snapshot();var scopes=old==null?Set.<MetadataScope>of():old.scopes();
        var owner=new MetadataOwnedPublication.Owner(sourceKey,session.profile.getId(),session.id,session.context.catalog(),session.context.temporarySchema(),seed.revision(),seed.context());
        var plan=MetadataOwnedPublication.prepare(owner,seed.durable(),prior,scopes,seed.published(),ticket,rules,seed.configuration(),branches,replaceTemporary,discardPersistent,admission,deadline);
        var charge=MetadataSnapshot.estimateComposition(seed.durable(),prior,plan.facts(),plan.replacements(),plan.coverage(),plan.removedCoverage());
        String inherited=prior==null||discardPersistent?"":prior.allCoverageStaleReason();long reasonCharge=inheritedCoverageCharge(charge.residentBytes(),inherited);
        enforceBudget(sourceKey,session.id,charge.residentBytes()+reasonCharge,true,admission);admission.reserveComposition(charge.allocationBytes()+reasonCharge,plan.facts());
        long revision=Math.max(seed.durable().revision(),prior==null?0:prior.revision())+1;
        var next=MetadataSnapshot.compose(seed.durable(),plan.facts(),plan.replacements(),plan.coverage(),plan.removedCoverage(),revision,seed.configuration().revision(),System.currentTimeMillis(),deadline);
        if(!inherited.isEmpty())next=next.withInheritedCoverageStale(revision,inherited);
        var before=prior==null?seed.durable():prior;var resolution=seed.resolutions().get(session.id);if(resolution!=null)before=before.withSessionResolution(Math.max(1,before.revision()),ruleResolution(session.id,resolution.state(),resolution.rulesFingerprint(),before.rules()));
        var owned=prepareOwnedShapes(session,before,next,branches,acquiredTemporary,resolution);
        var tickets=new HashMap<>(seed.published());tickets.keySet().removeAll(plan.removedTemporary());for(var scope:branches.keySet())tickets.put(scope,ticket);tickets.keySet().retainAll(next.catalogCoverage().keySet());
        Map<String,Overlay> overlays=next==seed.durable()?Map.of():Map.of(session.id,new Overlay(sourceKey,seed.revision(),seed.context(),seed.durable().revision(),plan.replacements(),next));
        return new PreparedPublication(next,Map.copyOf(tickets),overlays,owned,plan.fresh());
    }
    private ResolutionOwner prepareOwnedShapes(SessionRegistry.Session session,MetadataSnapshot before,MetadataSnapshot next,Map<MetadataScope,Branch> branches,boolean acquired,ResolutionOwner current){
        if(!session.lock.isHeldByCurrentThread())return current;
        if(current==null||!current.rulesFingerprint().equals(next.rules().fingerprint())||current.state().state()!=MetadataState.UNKNOWN||current.state().epoch()!=before.sessionResolution().epoch())return current;
        var evidence=new HashMap<>(current.state().owned());
        evidence.entrySet().removeIf(entry->{var value=entry.getValue();return next.identity(value.relation().identity().key()).orElse(null)!=value.relation()||next.catalogCoverage().get(value.namesScope())!=value.names();});
        for(var branch:branches.entrySet()){
            var scope=branch.getKey();if(scope.kind()!=ObjectKind.TABLE||branch.getValue().reuse()||!branch.getValue().coverage().complete())continue;
            for(var relation:next.select(scope)){
                var identity=relation.identity();if(!identity.sessionOwner().equals(session.id)||!"true".equals(relation.properties().get("temporary")))continue;
                var key=new MetadataSnapshot.RelationName(next.rules().lookup(ObjectKind.CATALOG,identity.catalog(),true),next.rules().lookup(ObjectKind.SCHEMA,identity.schema(),true),next.rules().lookup(ObjectKind.TABLE,identity.name(),true));
                if(current.state().verified().get(key)!=MetadataSnapshot.PhysicalRelationKind.TEMPORARY||!acquired&&!before.ownedRelationAvailable(identity.catalog(),identity.schema(),identity.name(),false))continue;
                var names=next.catalogCoverage().get(scope);if(names==null||!names.complete())continue;
                var columnScope=new MetadataScope(identity.catalog(),identity.schema(),identity.name(),ObjectKind.COLUMN);var columns=next.catalogCoverage().get(columnScope);var columnBranch=branches.get(columnScope);
                boolean previousStructure=before.ownedRelationAvailable(identity.catalog(),identity.schema(),identity.name(),true);
                boolean freshColumns=columnBranch!=null&&!columnBranch.reuse()&&columnBranch.coverage().complete()&&(acquired||previousStructure);
                boolean unchangedColumns=previousStructure&&(columnBranch==null&&before.catalogCoverage().get(columnScope)==columns||columnBranch!=null&&columnBranch.reuse());
                boolean structural=names.level().includes(IntrospectionLevel.STRUCTURE)&&columns!=null&&columns.complete()&&columns.level().includes(IntrospectionLevel.STRUCTURE)&&(freshColumns||unchangedColumns);
                var value=new MetadataSnapshot.OwnedRelationEvidence(relation,scope,names,columnScope,structural?columns:null);
                var proposed=new HashMap<>(evidence);proposed.put(key,value);
                try{var state=new MetadataSnapshot.SessionResolution(MetadataState.UNKNOWN,session.id,current.state().epoch(),current.state().limitation(),current.state().verified(),proposed);if(residentEstimate()-current.state().estimatedBytes()+state.estimatedBytes()>MAX_TOTAL_BYTES)continue;evidence=proposed;}catch(IllegalArgumentException limited){/* Admission failure retains UNKNOWN. */}
            }
        }
        return evidence.equals(current.state().owned())?current:new ResolutionOwner(current.source(),new MetadataSnapshot.SessionResolution(MetadataState.UNKNOWN,session.id,current.state().epoch(),current.state().limitation(),current.state().verified(),evidence),current.rulesFingerprint());
    }
    public void markStale(SessionRegistry.Session session,String reason){var owner=source(session);synchronized(owner){staleCoverage(owner,owner.snapshot.get().catalogCoverage().keySet(),reason);}}
    public PublicationRevision publicationRevision(SessionRegistry.Session session){var owner=source(session);return new PublicationRevision(session.metadataSourceIdentity,owner.owner,owner.snapshot.get().revision());}
    public void markStaleIfRevision(SessionRegistry.Session session,PublicationRevision expected,String reason){markStaleIfRevision(session,expected,List.of(),reason);}
    public void markStaleIfRevision(SessionRegistry.Session session,PublicationRevision expected,Collection<DdlEffect> effects,String reason){
        if(!expected.source.equals(session.metadataSourceIdentity))throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.INVALID_OWNER);
        if(session.physicalEnded())return;
        var owner=source(session);synchronized(owner){if(owner.owner==expected.owner&&owner.snapshot.get().revision()==expected.revision)staleCoverage(owner,MetadataInvalidation.scopes(owner.snapshot.get(),effects,session.context.catalog(),session.context.schema()),reason);}
    }
    /** A precise acknowledged relation effect cannot stale unrelated columns. */
    public void markStaleEffects(SessionRegistry.Session session,Collection<DdlEffect> effects,String reason){
        var owner=source(session);synchronized(owner){staleCoverage(owner,MetadataInvalidation.scopes(owner.snapshot.get(),effects,session.context.catalog(),session.context.schema()),reason);}
    }
    private static void staleCoverage(Source owner,Set<MetadataScope> affected,String reason){
        if(affected.isEmpty())return;
        String message=reason.length()>2048?reason.substring(0,2048):reason;
        var before=owner.snapshot.get();var coverage=new HashMap<>(before.catalogCoverage());
        coverage.replaceAll((scope,state)->affected.contains(scope)?state.stale(message):state);
        owner.snapshot.set(before.withCoverage(before.revision()+1,coverage));owner.bootstrapBridge=null;
    }
    public void endSession(String sessionId){
        var overlay=overlays.get(sessionId);var resolution=sessionResolutions.get(sessionId);String key=overlay!=null?overlay.source():resolution==null?null:resolution.source();
        if(key==null)for(var entry:sources.entrySet())if(entry.getValue().overlayPublished.containsKey(sessionId)||entry.getValue().physicalOwners.containsKey(sessionId)){key=entry.getKey();break;}
        endSession(sessionId,key);
    }
    private void endSession(String sessionId,String key){
        var owner=key==null?null:sources.get(key);
        if(owner==null){overlays.remove(sessionId);sessionResolutions.remove(sessionId);}
        else synchronized(owner){
            // No source iteration or nested Source lock: first-time owned
            // publication and exact physical retirement share one tiny guard.
            overlays.computeIfPresent(sessionId,(id,value)->value.source().equals(key)?null:value);sessionResolutions.computeIfPresent(sessionId,(id,value)->value.source().equals(key)?null:value);owner.overlayPublished.remove(sessionId);
            var registered=owner.physicalOwners.get(sessionId);var physical=registered==null?null:registered.get();if(registered!=null&&(physical==null||physical.physicalEnded()))owner.physicalOwners.remove(sessionId,registered);
        }
        sessionViews.remove(sessionId);PreparedMetadataWitness.endSession(sessionId);
    }
    public int sessionOverlayCount(){return overlays.size();}
    /** Verified absence of a temporary namespace is not physical session end.
     * Preserve pending ordinary structure, uncertainty and native witnesses. */
    public void clearTemporaryOverlay(SessionRegistry.Session session){
        requireResolutionOwner(session);try{var snapshot=captureBase(session);publishTemporaryInventory(session,beginRefresh(session),snapshot.rules(),Map.of());}
        catch(RuntimeException failure){throw failure;}catch(Exception failure){throw new IllegalStateException("Owned inventory retirement failed",failure);}
    }
    public void removeTemporary(SessionRegistry.Session session,String catalog,String schema,String table)throws Exception {
        var overlay=overlays.get(session.id);if(overlay==null)return;
        var remaining=overlay.snapshot().localIdentities().values().stream().filter(o->o.identity().sessionOwner().equals(session.id))
            .filter(o->!(o.identity().catalog().equals(catalog)&&(schema.isEmpty()||o.identity().schema().equals(schema))&&(o.identity().name().equals(table)&&o.identity().parent().isEmpty()||o.identity().parent().equals(table)))).toList();
        publish(session,beginRefresh(session),overlay.snapshot().rules(),temporaryBranches(session,overlay,remaining),true,null,true,false);
    }
    public void discardPendingStructure(SessionRegistry.Session session)throws Exception {
        var overlay=overlays.get(session.id);if(overlay==null)return;
        var temporary=overlay.snapshot().localIdentities().values().stream().filter(o->o.identity().sessionOwner().equals(session.id)&&("true".equals(o.properties().get("temporary"))||o.identity().schema().startsWith("pg_temp_"))).toList();
        rebuildOverlay(session,overlay,temporary);
    }
    private void rebuildOverlay(SessionRegistry.Session session,Overlay old,List<MetadataObject> remaining)throws Exception {
        requireResolutionOwner(session);
        publish(session,beginRefresh(session),old.snapshot().rules(),temporaryBranches(session,old,remaining),true,null,false,false,null,null,defaultPublicationDeadline(),true);
    }
    private static Map<MetadataScope,Branch> temporaryBranches(SessionRegistry.Session session,Overlay old,List<MetadataObject> remaining){
        var grouped=new LinkedHashMap<MetadataScope,List<SchemaObject>>();
        for(var object:remaining) {
            var i=object.identity();
            // Child enumerations belong to their exact physical relation, not
            // separate per-column fragments. Keep that structural coverage when
            // removing ordinary pending DDL or another temporary relation.
            var scope=i.parent().isEmpty()?new MetadataScope(i.catalog(),i.schema(),"",i.kind(),i.name(),true,i.signature(),i.subtype()):new MetadataScope(i.catalog(),i.schema(),i.parent(),i.kind());
            grouped.computeIfAbsent(scope,k->new ArrayList<>()).add(object.projection(old.snapshot().revision(),old.snapshot().configurationRevision()));
        }
        var branches=new LinkedHashMap<MetadataScope,Branch>();for(var entry:grouped.entrySet())putStructuralBranch(branches,entry.getKey(),entry.getValue(),session);
        return branches;
    }
    public void markSessionStale(SessionRegistry.Session session,String reason) {
        if(session.physicalEnded()||session.state==TransactionState.DISCONNECTED){endSession(session.id,session.metadataSourceIdentity);return;}
        if(session.state==TransactionState.UNKNOWN_TRANSACTION){markSessionResolutionUnknown(session,reason);return;}
        requireResolutionOwner(session);String key=session.metadataSourceIdentity;String message=reason.length()>2048?reason.substring(0,2048):reason;
        for(int attempt=0;attempt<4;attempt++){
            var owner=source(session);MetadataSnapshot base;Overlay old;long revision,context;
            synchronized(owner){if(sources.get(key)!=owner)continue;base=owner.snapshot.get();old=overlays.get(session.id);revision=session.revision;context=session.contextRevision;}
            var before=old==null?base:old.snapshot();
            try(var admission=admitAcquisition()){
                // Two immutable local coverage maps and mask arrays can be
                // prepared. The durable native indexes and values stay shared.
                long allocation=4096L+128L*(old==null?0:old.scopes().size());
                for(var state:before.localCoverage().values()){
                    var scope=state.scope();allocation+=1024L+2L*(scope.catalog().length()+scope.schema().length()+scope.parent().length()+scope.search().length()+scope.signature().length()+state.fingerprint().length()+state.defaultNamespace().length()+message.length());
                    if(allocation>MAX_TOTAL_BYTES)throw new IllegalStateException("Owned stale coverage preparation exceeds metadata admission");
                }
                admission.reserveAdditional(allocation);
                var effective=before;
                if(old!=null&&old.baseRevision()!=base.revision()){
                    if(!before.canRebaseCoverageOnto(base))throw new SupersededRefresh();
                    effective=rebaseOverlay(base,before,old.scopes(),session.id);
                }
                var next=effective.withAllCoverageStale(effective.revision()+1,message);
                synchronized(admissionLock){synchronized(owner){
                    if(sources.get(key)!=owner||owner.snapshot.get()!=base||overlays.get(session.id)!=old||session.revision!=revision||session.contextRevision!=context)continue;
                    if(session.physicalEnded()||session.state==TransactionState.DISCONNECTED){endSession(session.id,key);return;}
                    if(session.state==TransactionState.UNKNOWN_TRANSACTION)throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.TRANSACTION_UNKNOWN);
                    enforceBudget(key,session.id,next.estimatedBytes(),true,admission);
                    if(old==null&&overlays.size()>=8)throw new IllegalStateException("Session metadata overlay admission limit reached");
                    overlays.put(session.id,new Overlay(key,revision,context,base.revision(),old==null?Set.of():old.scopes(),next));admission.committed();return;
                }}
            }
        }
        throw new SupersededRefresh();
    }
    private void enforceBudget(String sourceKey,String sessionId,long estimate,boolean sessionOwned,AcquisitionAdmission admission) {
        long bytes=estimate;
        for(var entry:sources.entrySet())if(sessionOwned||!entry.getKey().equals(sourceKey))bytes+=entry.getValue().snapshot.get().estimatedBytes();
        for(var entry:overlays.entrySet())if(!sessionOwned||!entry.getKey().equals(sessionId))bytes+=entry.getValue().snapshot().estimatedBytes();
        for(var resolution:sessionResolutions.values())bytes+=resolution.state().estimatedBytes();
        synchronized(admissionLock){for(var pending:acquisitions.entrySet())if(pending.getKey()!=admission)bytes+=pending.getValue();if(bytes>MAX_TOTAL_BYTES)throw new IllegalStateException("Metadata global semantic admission limit (128MiB) reached; narrow configured scopes");}
    }
    private void enforceRuleBudget(String source,long stagedBytes,AcquisitionAdmission admission){
        long bytes=stagedBytes;
        for(var entry:sources.entrySet())if(!entry.getKey().equals(source))bytes+=entry.getValue().snapshot.get().estimatedBytes();
        for(var overlay:overlays.values())if(!overlay.source().equals(source))bytes+=overlay.snapshot().estimatedBytes();
        for(var resolution:sessionResolutions.values())bytes+=resolution.state().estimatedBytes();
        synchronized(admissionLock){for(var pending:acquisitions.entrySet())if(pending.getKey()!=admission)bytes+=pending.getValue();if(bytes>MAX_TOTAL_BYTES)throw new IllegalStateException("Metadata rule reindex exceeds the global semantic admission limit (128MiB)");}
    }
    public void recordDiagnostics(SessionRegistry.Session session,RefreshDiagnostics value){diagnostics.put(session.metadataSourceIdentity,value);}
    public void recordDiagnostics(SessionRegistry.Session session,RefreshReservation reservation,RefreshDiagnostics value){var owner=source(session);synchronized(owner){checkRefreshReservation(session,owner,reservation);recordDiagnostics(session,value);}}
    public Optional<RefreshDiagnostics> diagnostics(SessionRegistry.Session session){return Optional.ofNullable(diagnostics.get(session.metadataSourceIdentity));}
}
