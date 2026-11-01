package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.*;
import java.util.*;
import java.util.concurrent.*;

/** Pure, bounded owned-delta planning. The durable catalog is never copied or reinterpreted. */
final class MetadataOwnedPublication {
    private MetadataOwnedPublication(){}
    private static final List<ObjectKind> CHILDREN=List.of(ObjectKind.COLUMN,ObjectKind.INDEX,ObjectKind.CONSTRAINT,ObjectKind.FOREIGN_KEY,ObjectKind.TRIGGER);
    record Owner(String source,String profile,String session,String catalog,String temporarySchema,long revision,long context){}
    record Result(Collection<MetadataObject> facts,Set<MetadataScope> replacements,Map<MetadataScope,MetadataCoverage> coverage,Set<MetadataScope> removedCoverage,Set<MetadataScope> removedTemporary,boolean fresh){}
    private record Relation(String catalog,String schema,String name){}
    private static boolean temporary(MetadataObject object,String owner){return object.identity().sessionOwner().equals(owner)&&("true".equals(object.properties().get("temporary"))||object.identity().schema().startsWith("pg_temp_"));}
    private static boolean relationScope(MetadataScope scope,Set<Relation> relations){
        return !scope.parent().isEmpty()&&relations.contains(new Relation(scope.catalog(),scope.schema(),scope.parent()))
            ||scope.kind()==ObjectKind.TABLE&&scope.exactName()&&relations.contains(new Relation(scope.catalog(),scope.schema(),scope.search()));
    }
    private static void check(long deadline)throws TimeoutException{
        if(io.grpc.Context.current().isCancelled()||Thread.currentThread().isInterrupted())throw new CancellationException("Owned metadata publication cancelled");
        if(System.nanoTime()>deadline)throw new TimeoutException("Owned metadata publication preparation deadline exceeded");
    }
    static Result prepare(Owner owner,MetadataSnapshot durable,MetadataSnapshot prior,Set<MetadataScope> priorScopes,
            Map<MetadataScope,Long> published,long ticket,IdentifierRules rules,MetadataConfiguration config,
            Map<MetadataScope,MetadataPlatform.Branch> branches,boolean replaceTemporary,boolean discardPersistent,
            MetadataPlatform.AcquisitionAdmission admission,long deadline)throws Exception{
        check(deadline);
        var facts=new LinkedHashMap<String,MetadataObject>();var coverage=new HashMap<MetadataScope,MetadataCoverage>();var removedCoverage=new HashSet<MetadataScope>();
        var replacements=new HashSet<>(priorScopes);var removedTemporary=new HashSet<MetadataScope>();
        if(prior!=null){facts.putAll(prior.localIdentities());coverage.putAll(prior.localCoverage());removedCoverage.addAll(prior.removedCoverageScopes());}
        if(discardPersistent){facts.clear();coverage.clear();removedCoverage.clear();replacements.clear();}
        if(replaceTemporary&&!discardPersistent&&prior!=null){
            var temporary=facts.values().stream().filter(value->temporary(value,owner.session())).toList();var relations=new HashSet<Relation>();
            for(var value:temporary)if(value.identity().kind()==ObjectKind.TABLE)relations.add(new Relation(value.identity().catalog(),value.identity().schema(),value.identity().name()));
            admission.reserveAdditional(1024L+1024L*temporary.size());var candidates=new TemporaryCandidates(temporary,deadline);
            for(var scope:priorScopes){
                check(deadline);boolean local=scope.schema().startsWith("pg_temp_")||relationScope(scope,relations);
                if(!local)local=candidates.contains(scope,deadline);
                if(local)removedTemporary.add(scope);
            }
            for(var scope:removedTemporary)if(published.getOrDefault(scope,0L)>ticket)throw new MetadataPlatform.SupersededRefresh();
            replacements.removeAll(removedTemporary);
            facts.entrySet().removeIf(entry->temporary(entry.getValue(),owner.session()));
            // Collateral ordinary coverage/tombstones need not themselves be
            // replacement scopes (e.g. a names refresh staled its old columns).
            // Retiring temp facts must never resurrect that inherited authority.
            coverage.keySet().removeIf(scope->removedTemporary.contains(scope)||scope.schema().startsWith("pg_temp_")||relationScope(scope,relations));
            removedCoverage.removeIf(scope->removedTemporary.contains(scope)||scope.schema().startsWith("pg_temp_")||relationScope(scope,relations));
            var ordinaryMask=new MetadataOverlayIndex.ScopeMask(replacements,deadline);
            for(var value:facts.values()){check(deadline);if(!ordinaryMask.contains(value,deadline))throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.INCOMPLETE_METADATA);}

        }
        var visible=new Visible(durable,facts,replacements,coverage,removedCoverage,deadline);boolean fresh=false;
        long newest=0;for(long value:published.values())newest=Math.max(newest,value);
        if(newest>ticket)for(var scope:branches.keySet())for(var entry:published.entrySet())if(entry.getValue()>ticket&&scope.overlaps(entry.getKey()))throw new MetadataPlatform.SupersededRefresh();
        for(var entry:branches.entrySet()){
            check(deadline);var scope=entry.getKey();var branch=entry.getValue();var state=branch.coverage();
            boolean permitted=scope.kind()==ObjectKind.CATALOG&&scope.catalog().isEmpty()?config.kinds().contains(ObjectKind.CATALOG)
                :config.permits(scope.catalog(),scope.schema(),scope.kind(),scope.parent().isEmpty()?(scope.exactName()?scope.search():""):scope.parent())
                    ||scope.schema().startsWith("pg_temp_")&&config.kinds().contains(scope.kind());
            if(!permitted)state=new MetadataCoverage(scope,state.level(),MetadataState.NOT_REQUESTED,false,state.fingerprint(),state.sourceRevision(),state.contextRevision(),state.refreshedUnixMs(),"This scope is excluded by the current introspection policy",state.defaultNamespace());
            if(state.sourceRevision()!=owner.revision()||state.contextRevision()!=owner.context())throw new IllegalStateException("Metadata source revision changed before owned publication");
            if(!state.complete()){
                var previous=visible.coverage.get(scope);state=new MetadataCoverage(scope,state.level(),state.state(),false,state.fingerprint(),state.sourceRevision(),state.contextRevision(),previous==null?0:previous.refreshedUnixMs(),state.limitation(),previous==null?state.defaultNamespace():previous.defaultNamespace());
            }
            var replaced=visible.select(scope);
            if(state.complete()&&!branch.reuse()){
                facts.entrySet().removeIf(value->scope.contains(value.getValue()));replacements.add(scope);
                var erase=new ArrayList<MetadataScope>();
                for(var existing:visible.coverage.entrySet())if(!existing.getKey().equals(scope)&&scope.encloses(existing.getKey())&&state.level().includes(existing.getValue().level()))erase.add(existing.getKey());
                for(var erased:erase){coverage.remove(erased);removedCoverage.add(erased);}
                var acquired=new ArrayList<MetadataObject>();
                for(var object:branch.objects()){
                    check(deadline);
                    if(object.getSchema().startsWith("pg_temp_")&&(!object.getSchema().equals(owner.temporarySchema())||!object.getCatalog().equals(owner.catalog())))throw new IllegalArgumentException("Temporary metadata has an invalid physical owner");
                    if(!config.permits(object.getCatalog(),object.getSchema(),object.getKind(),object.getTable().isEmpty()?object.getName():object.getTable())
                        &&!((object.getSchema().startsWith("pg_temp_")||"true".equals(object.getPropertiesOrDefault("temporary","")))&&config.kinds().contains(object.getKind())))continue;
                    if(state.level()==IntrospectionLevel.NAMES&&replaced.stream().anyMatch(value->value.identity().catalog().equals(object.getCatalog())&&value.identity().schema().equals(object.getSchema())&&value.identity().kind()==object.getKind()&&value.identity().parent().equals(object.getTable())&&value.identity().name().equals(object.getName())&&value.level().includes(IntrospectionLevel.STRUCTURE))){
                        var stale=new ArrayList<MetadataScope>();for(var previous:visible.coverage.keySet())if(previous.catalog().equals(object.getCatalog())&&previous.schema().equals(object.getSchema())&&(previous.parent().equals(object.getName())||previous.parent().isEmpty()&&previous.kind()==object.getKind()&&previous.exactName()&&previous.search().equals(object.getName())))stale.add(previous);
                        for(var previous:stale)coverage.put(previous,visible.coverage.get(previous).stale("Names-only acquisition did not verify cached structural details"));
                    }
                    var next=MetadataObject.from(owner.source(),owner.profile(),object.getSchema().startsWith("pg_temp_")||"true".equals(object.getPropertiesOrDefault("temporary",""))?owner.session():"",rules,object,state.level(),owner.revision(),owner.context());
                    var previous=facts.get(next.identity().key());if(previous==null&&prior!=null)previous=prior.localIdentities().get(next.identity().key());if(previous==null)previous=durable.identities().get(next.identity().key());
                    if(previous!=null&&previous.sameContent(next))next=previous;else admission.reserveOwnedObject(next);
                    facts.put(next.identity().key(),next);acquired.add(next);
                }
                for(var next:branch.normalized()){
                    check(deadline);var identity=next.identity();
                    if(!identity.source().equals(owner.source())||!identity.profileId().equals(owner.profile())||!identity.sessionOwner().isEmpty()&&!identity.sessionOwner().equals(owner.session()))throw new IllegalArgumentException("Acquired owned metadata branch has an invalid owner");
                    if(!config.permits(identity.catalog(),identity.schema(),identity.kind(),identity.parent().isEmpty()?identity.name():identity.parent()))continue;
                    var previous=prior==null?null:prior.localIdentities().get(identity.key());if(previous!=next&&durable.identities().get(identity.key())!=next)admission.reserveOwnedObject(next);
                    facts.put(identity.key(),next);acquired.add(next);
                }
                if((scope.kind()==ObjectKind.TABLE||scope.kind()==ObjectKind.VIEW)&&scope.parent().isEmpty()){
                    var present=new HashSet<String>();for(var value:acquired)if(scope.contains(value))present.add(value.identity().name());
                    var deleted=new HashSet<String>();for(var value:replaced)if(!present.contains(value.identity().name()))deleted.add(value.identity().name());
                    if(!deleted.isEmpty()){
                        facts.entrySet().removeIf(value->{var identity=value.getValue().identity();return identity.catalog().equals(scope.catalog())&&identity.schema().equals(scope.schema())&&deleted.contains(identity.parent());});
                        for(String name:deleted)for(var child:CHILDREN)replacements.add(new MetadataScope(scope.catalog(),scope.schema(),name,child));
                        var stale=new ArrayList<MetadataScope>();for(var existing:visible.coverage.keySet())if(existing.catalog().equals(scope.catalog())&&existing.schema().equals(scope.schema())&&(deleted.contains(existing.parent())||existing.parent().isEmpty()&&existing.kind()==scope.kind()&&existing.exactName()&&deleted.contains(existing.search())))stale.add(existing);
                        for(var changed:stale)coverage.put(changed,visible.coverage.get(changed).stale("The owning relation disappeared during names reconciliation"));
                    }
                }
                // A temporary relation cannot borrow a same-name persistent
                // relation's unacquired children or certify their absence.
                for(var value:acquired)if(value.identity().kind()==ObjectKind.TABLE&&temporary(value,owner.session()))for(var child:CHILDREN){
                    var childScope=new MetadataScope(value.identity().catalog(),value.identity().schema(),value.identity().name(),child);
                    if(replacements.add(childScope)){
                        facts.entrySet().removeIf(existing->childScope.contains(existing.getValue()));
                        coverage.put(childScope,new MetadataCoverage(childScope,IntrospectionLevel.NAMES,MetadataState.NOT_REQUESTED,false,"",owner.revision(),owner.context(),0,"Temporary child metadata was not acquired by this physical owner"));
                    }
                }
                for(var invalid:MetadataCoverageReconciliation.invalidated(visible.coverage,scope,replaced,acquired)){
                    var old=visible.coverage.get(invalid);if(old!=null)coverage.put(invalid,old.stale("An overlapping owned publication changed identities or replaced higher-level facts"));
                }
            }else{
                // A failed/reused branch retains the captured facts, rather
                // than adopting later durable changes through its owned mask.
                for(var value:replaced)facts.put(value.identity().key(),value);
                replacements.add(scope);
            }
            removedCoverage.remove(scope);coverage.put(scope,state);fresh|=state.complete()&&!branch.reuse();
            if(facts.size()>MetadataSnapshot.MAX_OBJECTS||replacements.size()>100_000||coverage.size()>100_000||removedCoverage.size()>100_000)throw new IllegalArgumentException("Owned metadata object/scope budget exceeded");
        }
        check(deadline);facts.replaceAll((key,value)->value.withRules(rules));
        return new Result(List.copyOf(facts.values()),Set.copyOf(replacements),Map.copyOf(coverage),Set.copyOf(removedCoverage),Set.copyOf(removedTemporary),fresh);
    }
    /** Private operation index only: selectLocal materializes whole namespaces
     * before returning, so it cannot enforce this operation's inner deadline. */
    private static final class TemporaryCandidates {
        private record Name(MetadataSnapshot.Namespace namespace,String name){}
        private record AnyName(ObjectKind kind,String name){}
        private final Map<MetadataSnapshot.Namespace,List<MetadataObject>> namespaces=new HashMap<>();
        private final Map<Name,List<MetadataObject>> names=new HashMap<>();
        private final Map<ObjectKind,List<MetadataObject>> kinds=new EnumMap<>(ObjectKind.class);
        private final Map<AnyName,List<MetadataObject>> anyNames=new HashMap<>();
        TemporaryCandidates(List<MetadataObject> facts,long deadline)throws TimeoutException{
            for(var fact:facts){check(deadline);var id=fact.identity();var exact=new MetadataSnapshot.Namespace(id.catalog(),id.schema(),id.kind(),id.parent());add(exact,fact);
                if(!id.parent().isEmpty())add(new MetadataSnapshot.Namespace(id.catalog(),id.schema(),id.kind(),""),fact);
                kinds.computeIfAbsent(id.kind(),key->new ArrayList<>()).add(fact);anyNames.computeIfAbsent(new AnyName(id.kind(),id.name()),key->new ArrayList<>()).add(fact);
            }
        }
        private void add(MetadataSnapshot.Namespace namespace,MetadataObject fact){namespaces.computeIfAbsent(namespace,key->new ArrayList<>()).add(fact);names.computeIfAbsent(new Name(namespace,fact.identity().name()),key->new ArrayList<>()).add(fact);}
        boolean contains(MetadataScope scope,long deadline)throws TimeoutException{
            List<MetadataObject> candidates;
            if(!scope.catalog().isEmpty()&&!scope.schema().isEmpty()){
                var namespace=new MetadataSnapshot.Namespace(scope.catalog(),scope.schema(),scope.kind(),scope.parent());
                candidates=scope.exactName()?names.getOrDefault(new Name(namespace,scope.search()),List.of()):namespaces.getOrDefault(namespace,List.of());
            }else candidates=scope.exactName()?anyNames.getOrDefault(new AnyName(scope.kind(),scope.search()),List.of()):kinds.getOrDefault(scope.kind(),List.of());
            for(var fact:candidates){check(deadline);if(scope.contains(fact))return true;}return false;
        }
    }
    /** Mutable only inside the private plan; it never becomes a published map. */
    private static final class Visible {
        private final MetadataSnapshot base;private final Map<String,MetadataObject> facts;private final Set<MetadataScope> replacements;
        private final Map<MetadataScope,MetadataCoverage> coverage;private final long deadline;
        private void poll(){if(io.grpc.Context.current().isCancelled()||Thread.currentThread().isInterrupted())throw new CancellationException("Owned metadata selection cancelled");if(System.nanoTime()>deadline)throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.TIMED_OUT,io.busystack.busydata.rpc.WorkbenchFailure.Origin.OWNED_PUBLICATION);}
        Visible(MetadataSnapshot base,Map<String,MetadataObject> facts,Set<MetadataScope> replacements,Map<MetadataScope,MetadataCoverage> overrides,Set<MetadataScope> removed,long deadline){
            this.deadline=deadline;this.base=base;this.facts=facts;this.replacements=replacements;
            coverage=new AbstractMap<>(){
                @Override public MetadataCoverage get(Object key){return overrides.containsKey(key)?overrides.get(key):removed.contains(key)?null:base.catalogCoverage().get(key);}
                @Override public Set<Entry<MetadataScope,MetadataCoverage>> entrySet(){return new AbstractSet<>(){
                    @Override public int size(){int count=overrides.size();for(var key:base.catalogCoverage().keySet()){poll();if(!overrides.containsKey(key)&&!removed.contains(key))count++;}return count;}
                    @Override public Iterator<Entry<MetadataScope,MetadataCoverage>> iterator(){
                        var source=base.catalogCoverage().entrySet().iterator();var local=overrides.entrySet().iterator();
                        return new Iterator<>(){Entry<MetadataScope,MetadataCoverage> next;
                            @Override public boolean hasNext(){while(next==null&&source.hasNext()){poll();var value=source.next();if(!overrides.containsKey(value.getKey())&&!removed.contains(value.getKey()))next=value;}if(next==null&&local.hasNext()){poll();next=local.next();}return next!=null;}
                            @Override public Entry<MetadataScope,MetadataCoverage> next(){if(!hasNext())throw new NoSuchElementException();var value=next;next=null;return value;}
                        };
                    }
                };}
            };
        }
        List<MetadataObject> select(MetadataScope scope){
            var values=new LinkedHashMap<String,MetadataObject>();
            poll();var mask=new MetadataOverlayIndex.ScopeMask(replacements,deadline);
            for(var value:base.select(scope)){poll();if(!facts.containsKey(value.identity().key())&&!mask.contains(value,deadline))values.put(value.identity().key(),value);}
            for(var value:facts.values()){poll();if(scope.contains(value))values.put(value.identity().key(),value);}
            return List.copyOf(values.values());
        }
    }
}
