package io.busystack.busydata.schema;

import io.busystack.busydata.analysis.language.*;
import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.sessions.SessionRegistry;
import java.util.*;
import java.util.concurrent.*;

/** Acknowledged execution effects schedule independent metadata work, never SQL replay. */
public final class SmartMetadataRefresh implements AutoCloseable {
    private final Explorer explorer;
    private final io.busystack.busydata.results.ResultStore results;
    private final Map<String,List<DdlEffect>> pending=new ConcurrentHashMap<>();
    private final Set<String> scheduled=ConcurrentHashMap.newKeySet();
    private static final class EffectIntent {
        final long generation;final List<DdlEffect> effects;final MetadataPlatform.QueuedRefreshOwner fence;
        final java.lang.ref.WeakReference<SessionRegistry.Session> session;final String source;final boolean external;final long wave;
        MetadataPlatform.QueuedRefreshOwner admittedOwner;long admittedRevision=-1;
        EffectIntent(SessionRegistry.Session session,long generation,List<DdlEffect> effects,MetadataPlatform.QueuedRefreshOwner fence,boolean external,long wave){this.session=new java.lang.ref.WeakReference<>(session);this.source=session.metadataSourceIdentity;this.generation=generation;this.effects=List.copyOf(effects);this.fence=fence;this.external=external;this.wave=wave;}
    }
    private final Map<String,EffectIntent> ready=new HashMap<>();
    private long intentGeneration;
    private record QueuedBatch(MetadataPlatform.QueuedRefreshOwner owner,List<DdlEffect> effects,long intent,boolean context){QueuedBatch(MetadataPlatform.QueuedRefreshOwner owner,List<DdlEffect> effects,long intent){this(owner,effects,intent,false);}QueuedBatch{effects=List.copyOf(effects);}}
    private final Map<String,QueuedBatch> queued=new HashMap<>();
    // The second metadata-connection slot remains available to interactive
    // Explorer/designer requests while background reconciliation is running.
    private final ExecutorService workers=Executors.newFixedThreadPool(1,Thread.ofVirtual().name("metadata-refresh-",0).factory());
    private volatile boolean closed;
    public SmartMetadataRefresh(Explorer explorer,io.busystack.busydata.results.ResultStore results){this.explorer=explorer;this.results=Objects.requireNonNull(results);}
    public void connected(SessionRegistry.Session session){schedule(session,List.of());}
    /** Before opaque user execution: a failed routine may leave nontransactional
     * temporary DDL behind. This records uncertainty, never executes SQL. */
    public void beforeExecution(SessionRegistry.Session session,String sql){
        if(closed)return;
        var first=io.busystack.busydata.analysis.SqlLexer.scan(sql,session.profile.getEngine(),session.context.lexical()).stream().filter(t->t.kind()!=io.busystack.busydata.analysis.SqlLexer.Kind.COMMENT).findFirst().orElse(null);
        if(first==null||!DdlImpact.opaqueOperation(first.text()))return;
        explorer.metadata().markSessionResolutionUnknown(session,"Opaque SQL may change temporary-object resolution; verify the owning physical session");
        explorer.metadata().markStale(session,"Opaque SQL may change persistent structure; reconcile committed metadata");
        results.invalidateMetadataProof(session.metadataSourceIdentity,"","","","STALE: opaque SQL may change retained-source structure or session-local resolution; inspect and reload explicitly");
    }
    public void acknowledged(SessionRegistry.Session session,String sql){
        if(closed)return;
        var first=io.busystack.busydata.analysis.SqlLexer.scan(sql,session.profile.getEngine(),session.context.lexical()).stream()
            .filter(t->t.kind()!=io.busystack.busydata.analysis.SqlLexer.Kind.COMMENT).findFirst().orElse(null);
        if(first==null)return;
        if(first.is("ROLLBACK")){pending.remove(session.id);rollbackOverlay(session);return;}
        if(first.is("COMMIT")||first.is("END")){rollbackOverlay(session);if(session.state==TransactionState.IDLE)committed(session,List.of());return;}
        boolean opaque=DdlImpact.opaqueOperation(first.text());
        if(!opaque&&!Set.of("CREATE","ALTER","DROP","RENAME","TRUNCATE","COMMENT","USE","SET","RESET","DISCARD").stream().anyMatch(first::is))return;
        if(opaque)explorer.metadata().markSessionResolutionUnknown(session,"Acknowledged opaque SQL changed an unknown session-local scope; verify the owning physical session");
        List<DdlEffect> effects;
        try{effects=DdlImpact.analyze(sql,session.profile.getEngine(),session.context.lexical(),new ResolutionContext(session.context.catalog(),session.context.schema(),session.context.searchPath(),false,0,0));}
        catch(IllegalArgumentException limited){effects=List.of(DdlEffect.newBuilder().setCatalog(session.context.catalog()).setSchema(session.context.schema()).setKind(ObjectKind.SCHEMA).setConservative(true).build());}
        if(session.profile.getEngine()==Engine.POSTGRESQL)effects=effects.stream().map(effect->effect.getSchema().equals("pg_temp")||effect.getSchema().startsWith("pg_temp_")?effect.toBuilder().setTemporary(true).setSchema(session.context.temporarySchema().isEmpty()?effect.getSchema():session.context.temporarySchema()).build():effect).toList();
        if(effects.isEmpty())return;
        if(!opaque&&!Set.of("USE","SET","RESET","DISCARD").stream().anyMatch(first::is)){
            if(session.profile.getEngine()==Engine.POSTGRESQL||effects.stream().anyMatch(DdlEffect::getConservative))invalidateResolutionFacts(session);
            else for(var effect:effects)if(Set.of(ObjectKind.TABLE,ObjectKind.VIEW).contains(effect.getKind())&&!effect.getName().isEmpty()){
                String catalog=effect.getCatalog().isEmpty()?session.context.catalog():effect.getCatalog(),schema=effect.getSchema().isEmpty()?session.context.schema():effect.getSchema();
                explorer.metadata().invalidateSessionRelation(session,catalog,schema,effect.getName());
            }
        }
        for(var effect:effects)if(Set.of("CREATE","ALTER","DROP","RENAME","TRUNCATE").contains(effect.getOperation().toUpperCase(Locale.ROOT))) {
            String catalog=effect.getCatalog().isEmpty()?session.context.catalog():effect.getCatalog(),schema=effect.getSchema().isEmpty()?session.context.schema():effect.getSchema();
            String table=!effect.getConservative()&&Set.of(ObjectKind.TABLE,ObjectKind.VIEW).contains(effect.getKind())?effect.getName():"";
            results.invalidateMetadataProof(session.metadataSourceIdentity,catalog,schema,table,"STALE: acknowledged structural SQL changed retained-source metadata; inspect and reload explicitly");
        }
        refreshTemporaryEffects(session,effects);
        effects=effects.stream().filter(effect->!effect.getTemporary()).toList();
        if(effects.isEmpty())return;
        if(session.state==TransactionState.IDLE)committed(session,effects);
        else {
            final var capturedEffects=effects;
            pending.compute(session.id,(id,old)->combine(session,old,capturedEffects));
            if(session.state==TransactionState.ACTIVE&&!opaque)explorer.metadata().markSessionStale(session,"Uncommitted DDL is pending in this physical session; committed metadata will reconcile after explicit transaction resolution");
        }
    }
    private static List<DdlEffect> combine(SessionRegistry.Session session,List<DdlEffect> first,List<DdlEffect> second){var effects=new ArrayList<DdlEffect>();if(first!=null)effects.addAll(first);effects.addAll(second);return effects.size()>32?List.of(DdlEffect.newBuilder().setCatalog(session.context.catalog()).setSchema(session.context.schema()).setKind(ObjectKind.SCHEMA).setConservative(true).build()):List.copyOf(effects);}
    /** Known committed effects outlive attempts; transaction-pending effects do
     * not. Invalidate now, then admit at an acknowledged statement or final
     * cleanup boundary using that boundary's exact physical revisions. */
    private void committed(SessionRegistry.Session session,List<DdlEffect> effects){synchronized(scheduled){
        if(closed)return;
        var transaction=pending.remove(session.id);
        var incoming=combine(session,transaction,effects);if(incoming.isEmpty())return;
        var previous=ready.get(session.id);var all=combine(session,previous==null?null:previous.effects,incoming);
        var fence=explorer.metadata().invalidateForReconciliation(session,all,"Acknowledged SQL changed structure or resolution context");
        if(ready.size()>=8&&!ready.containsKey(session.id))throw new IllegalStateException("Metadata reconciliation intent admission limit reached; refresh explicitly");
        ready.put(session.id,new EffectIntent(session,++intentGeneration,all,fence,previous!=null&&previous.external,0));
    }}
    /** No SQL is invented or executed to describe a native client's effects. */
    public MetadataPlatform.ExternalMutation externalMutationStarting(SessionRegistry.Session session){
        synchronized(scheduled){if(closed)throw new IllegalStateException("Metadata coordinator is closed; native restore was not started");}
        var mutation=explorer.metadata().beginExternalMutation(session);
        try{results.invalidateExternalMetadataProof(session.metadataSourceIdentity,"STALE: native restore owns the persistent source; reconcile metadata without replay");return mutation;}
        catch(RuntimeException failure){explorer.metadata().finishExternalMutation(session,mutation,false,false);throw failure;}
    }
    public void externalMutationFinished(SessionRegistry.Session session,MetadataPlatform.ExternalMutation mutation,boolean started,boolean acknowledged){
        // Keep the source barrier through memory-only retirement of every
        // registered proof, including rollback-recoverable stale evidence.
        var retired=started?results.retireExternalMetadataProofs(session.metadataSourceIdentity,"STALE: native restore changed persistent metadata; reload retained edit sources explicitly"):List.<PreparedMetadataWitness>of();
        final MetadataPlatform.ExternalCompletion completion;
        try{completion=explorer.metadata().finishExternalMutation(session,mutation,started,acknowledged);}
        finally{io.busystack.busydata.results.ResultStore.closeRetiredMetadataWitnesses(retired);}
        synchronized(scheduled){
            String source=session.metadataSourceIdentity;
            // An overlapping unknown retires an earlier successful wave; a
            // later real ACK replaces only the older external wave evidence.
            ready.entrySet().removeIf(entry->{var intent=entry.getValue();boolean retire=intent.external&&intent.wave==completion.wave()&&intent.source.equals(source)&&intent.fence!=completion.acknowledgement();if(retire)queued.remove(entry.getKey());return retire;});
            if(acknowledged&&completion.acknowledgement()!=null&&!closed){
                if(ready.size()>=8&&!ready.containsKey(session.id))throw new IllegalStateException("Metadata reconciliation intent admission limit reached; refresh explicitly");
                var previous=ready.get(session.id);var effects=previous==null?List.<DdlEffect>of():previous.effects;
                ready.put(session.id,new EffectIntent(session,++intentGeneration,effects,completion.acknowledgement(),true,completion.wave()));
            }
            if(completion.ready()&&!closed)for(var intent:List.copyOf(ready.values())){
                var original=intent.session.get();
                if(original!=null&&!original.physicalEnded()&&intent.external&&intent.wave==completion.wave()&&intent.fence==completion.acknowledgement()&&intent.admittedOwner!=null)
                    schedule(original,new QueuedBatch(intent.admittedOwner,intent.effects,intent.generation,true));
            }
        }
    }
    /** Called after context refresh/revision advance at a real statement ACK
     * or physical cleanup boundary. A following script statement may remain
     * active; only independent metadata connections perform acquisition. */
    public void settled(SessionRegistry.Session session){
        if(closed)return;
        boolean acquired=false;
        if(!session.lock.isHeldByCurrentThread()){if(!session.lock.tryLock())return;acquired=true;}
        try{
            if(session.state==TransactionState.DISCONNECTED||session.state==TransactionState.UNKNOWN_TRANSACTION){
                pending.remove(session.id);synchronized(scheduled){ready.remove(session.id);queued.remove(session.id);}
                if(session.state==TransactionState.DISCONNECTED)explorer.metadata().endSession(session.id);else explorer.metadata().markStale(session,"Transaction outcome unknown; reconcile metadata explicitly");return;
            }
            if(session.state==TransactionState.IDLE&&pending.containsKey(session.id))committed(session,List.of());
            synchronized(scheduled){
                var intent=ready.get(session.id);if(intent==null||closed)return;
                if(session.state!=TransactionState.IDLE&&!intent.external)return;
                MetadataPlatform.QueuedRefreshOwner owner;
                try{owner=explorer.metadata().settledReconciliationOwner(session,intent.fence);}
                catch(MetadataPlatform.SupersededRefresh superseded){ready.remove(session.id);queued.remove(session.id);return;}
                if(intent.admittedRevision==session.revision)return;
                intent.admittedRevision=session.revision;intent.admittedOwner=owner;
                if(intent.external&&intent.wave!=0&&!explorer.metadata().externalWaveReady(session,intent.wave,intent.fence))return;
                schedule(session,new QueuedBatch(owner,intent.effects,intent.generation,intent.external));
            }
        }finally{if(acquired)session.lock.unlock();}
    }
    public void transaction(SessionRegistry.Session session,SessionAction action){
        if(action==SessionAction.ROLLBACK){pending.remove(session.id);rollbackOverlay(session);settled(session);}
        else if(action==SessionAction.DISCONNECT){pending.remove(session.id);synchronized(scheduled){ready.remove(session.id);queued.remove(session.id);}explorer.metadata().endSession(session.id);}
        else {if(action==SessionAction.COMMIT)rollbackOverlay(session);settled(session);}
    }
    private void refreshTemporaryEffects(SessionRegistry.Session session,List<DdlEffect> effects) {
        if(!session.lock.isHeldByCurrentThread())return;
        try(var maintenance=explorer.metadata().ownedMaintenance(session)) {
            if(session.profile.getEngine()==Engine.POSTGRESQL) {
                if(!session.context.temporarySchema().isEmpty()||effects.stream().anyMatch(DdlEffect::getTemporary))explorer.refreshSessionOverlay(session);
                return;
            }
            if(effects.stream().anyMatch(effect->DdlImpact.opaqueOperation(effect.getOperation())))explorer.refreshSessionOverlay(session);
            var snapshot=explorer.metadata().capture(session);
            for(var effect:effects)if(effect.getKind()==ObjectKind.TABLE&&!effect.getName().isEmpty()) {
                String catalog=effect.getCatalog().isEmpty()?session.context.catalog():effect.getCatalog();
                boolean known=snapshot.identities().values().stream().anyMatch(o->o.identity().sessionOwner().equals(session.id)&&o.identity().kind()==ObjectKind.TABLE&&o.identity().catalog().equals(catalog)&&o.identity().name().equals(effect.getName())&&"true".equals(o.properties().get("temporary")));
                if(effect.getTemporary()||known) {
                    if(effect.getOperation().equalsIgnoreCase("DROP"))explorer.metadata().removeTemporary(session,catalog,catalog,effect.getName());
                    else explorer.refreshTemporary(session,catalog,catalog,effect.getName());
                }
            }
        }catch(Exception unavailable){explorer.metadata().markSessionResolutionUnknown(session,"Session-local metadata refresh failed; reconcile the owning session explicitly");}
    }
    private void rollbackOverlay(SessionRegistry.Session session) {
        boolean acquired=false;
        try {
            if(!session.lock.isHeldByCurrentThread()){if(!session.lock.tryLock())return;acquired=true;}
            try(var maintenance=explorer.metadata().ownedMaintenance(session)){if(session.profile.getEngine()==Engine.POSTGRESQL){invalidateResolutionFacts(session);explorer.metadata().discardPendingStructure(session);explorer.refreshSessionOverlay(session);}}
        }catch(Exception unavailable){explorer.metadata().markSessionStale(session,"Transaction resolution acknowledged; session-local metadata requires reconciliation");}
        finally{if(acquired)session.lock.unlock();}
    }
    private void invalidateResolutionFacts(SessionRegistry.Session session){if(explorer.metadata().sessionResolutionEpoch(session)!=0)explorer.metadata().markSessionResolutionUnknown(session,"Transaction or structural execution may change session-local resolution; verify the physical owner again");}
    private void schedule(SessionRegistry.Session session,List<DdlEffect> effects){
        if(closed||session.state==TransactionState.DISCONNECTED||session.state==TransactionState.UNKNOWN_TRANSACTION)return;
        // Capture before queueing. A late worker cannot adopt a publication
        // which an explicit metadata request completed while it was waiting.
        schedule(session,new QueuedBatch(explorer.metadata().queuedRefreshOwner(session),effects,0));
    }
    private void schedule(SessionRegistry.Session session,QueuedBatch batch){synchronized(scheduled){
        if(closed)return;
        if(!scheduled.add(session.id)){
            queued.merge(session.id,batch,(old,next)->next.intent()!=0||old.intent()==0?next:old);return;
        }
        var owner=batch.owner();var effects=batch.effects();
        if(scheduled.size()>8){scheduled.remove(session.id);if(effects.isEmpty())explorer.metadata().markStaleIfQueuedOwner(session,owner,"Metadata refresh admission limit reached; refresh explicitly");return;}
        workers.submit(()->{
            MetadataPlatform.RefreshReservation reservation=null;
            try {
                synchronized(scheduled){
                    if(closed||batch.intent()!=0&&(ready.get(session.id)==null||ready.get(session.id).generation!=batch.intent()))return;
                    reservation=explorer.metadata().reserveQueuedRefresh(session,owner);
                }
                // An obsolete background task must not enter Explorer's
                // explicit retry/coalescing path and acquire a newer owner.
                var refresh=new MetadataRefresh(explorer,System.nanoTime()+TimeUnit.SECONDS.toNanos(30),reservation);
                // Fragment refresh includes relationship dependencies. Uncertain impact uses the configured context.
                if(!batch.context()&&effects.size()==1&&!effects.getFirst().getConservative()&&!effects.getFirst().getTemporary()&&
                    Set.of(ObjectKind.TABLE,ObjectKind.VIEW).contains(effects.getFirst().getKind())){
                    var effect=effects.getFirst();refresh.fragment(session,effect.getCatalog(),effect.getSchema(),effect.getName(),effect.getKind());
                }else refresh.context(session,MetadataPlatform.RefreshMode.INCREMENTAL);
                synchronized(scheduled){var intent=ready.get(session.id);if(intent!=null&&intent.generation==batch.intent())ready.remove(session.id);}
            }catch(Exception failure){
                // Committed effects were invalidated synchronously when
                // acknowledged. Their failure cannot poison a later explicit
                // acquisition. This batch never retries with a newer owner;
                // existing unreconciled scopes remain stale.
                // Empty connection refreshes have no synchronous invalidation:
                // retain their fenced failure marking, using the admission token.
                if(effects.isEmpty()&&!(failure instanceof MetadataPlatform.SupersededRefresh)){
                    if(reservation==null)explorer.metadata().markStaleIfQueuedOwner(session,owner,"Metadata refresh failed; refresh the affected scope explicitly");
                    else explorer.metadata().markStaleIfRefreshReservation(session,reservation,"Metadata refresh failed; refresh the affected scope explicitly");
                }
                // Only a real statement ACK or physical cleanup boundary may
                // admit another attempt from retained committed intent. A worker
                // never recaptures an owner or retries a database execution.
            }
            finally{
                synchronized(scheduled){scheduled.remove(session.id);var next=queued.remove(session.id);if(next!=null)schedule(session,next);}
            }
        });
    }}
    @Override public void close(){synchronized(scheduled){closed=true;pending.clear();ready.clear();queued.clear();workers.shutdownNow();}}
}
