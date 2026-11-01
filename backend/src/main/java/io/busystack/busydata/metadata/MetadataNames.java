package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.*;
import java.util.*;

/** Names reconciliation never upgrades facts which a native fingerprint did not verify. */
public final class MetadataNames {
    private MetadataNames(){}
    public static final List<ObjectKind> CHILDREN=List.of(ObjectKind.COLUMN,ObjectKind.INDEX,ObjectKind.CONSTRAINT,ObjectKind.FOREIGN_KEY,ObjectKind.TRIGGER);
    private static final Set<ObjectKind> ALL_CHILDREN=Set.copyOf(CHILDREN);
    public record Evidence(Map<ObjectKind,Map<String,String>> children,Map<String,String> typeDependencies,Set<ObjectKind> requestedKinds) {
        public Evidence(Map<ObjectKind,Map<String,String>> children,Map<String,String> types){this(children,types,Set.copyOf(CHILDREN));}
        public Evidence {requestedKinds=Set.copyOf(requestedKinds);var copy=new EnumMap<ObjectKind,Map<String,String>>(ObjectKind.class);long bytes=0;for(var branch:children.entrySet()){copy.put(branch.getKey(),Map.copyOf(branch.getValue()));for(var value:branch.getValue().entrySet())bytes+=80+2L*(value.getKey().length()+value.getValue().length());}for(var value:typeDependencies.entrySet())bytes+=80+2L*(value.getKey().length()+value.getValue().length());if(bytes>12_582_912)throw new IllegalArgumentException("Metadata name reconciliation evidence exceeds its 12MiB budget");children=Map.copyOf(copy);typeDependencies=Map.copyOf(typeDependencies);}
        public boolean matches(MetadataSnapshot before,MetadataObject previous,SchemaObject acquired){return matches(before,previous,acquired,requestedKinds);}
        private boolean matches(MetadataSnapshot before,MetadataObject previous,SchemaObject acquired,Set<ObjectKind> required) {
            var identity=previous.identity();String marker=previous.properties().getOrDefault("catalogFingerprint","");
            if(!identity.catalog().equals(acquired.getCatalog())||!identity.schema().equals(acquired.getSchema())||!identity.name().equals(acquired.getName())||marker.isEmpty()||!marker.equals(acquired.getPropertiesOrDefault("catalogFingerprint",""))||identity.kind()!=acquired.getKind()||identity.subtype()!=acquired.getSubtype())return false;
            if(before.rules().engine()==Engine.POSTGRESQL) {
                if(identity.nativeKey().isEmpty()||!identity.nativeKey().equals(acquired.getPropertiesOrDefault("nativeId","")))return false;
                String types=previous.properties().getOrDefault("typeDependenciesFingerprint","");
                if(types.isEmpty()||!types.equals(typeDependencies.get(identity.name())))return false;
                if(!previous.properties().getOrDefault("nativeGeneration","").equals(acquired.getPropertiesOrDefault("nativeGeneration","")))return false;
            }else if(identity.kind()==ObjectKind.TABLE) {
                String id=previous.properties().getOrDefault("nativeTableId","");
                if(id.isEmpty()||!id.equals(acquired.getPropertiesOrDefault("nativeTableId","")))return false;
                if(before.rules().engine()==Engine.MYSQL&&!previous.properties().getOrDefault("nativeColumnEpoch","").equals(acquired.getPropertiesOrDefault("nativeColumnEpoch","")))return false;
            }
            for(ObjectKind kind:CHILDREN) {
                if(!required.contains(kind))continue;
                var old=before.coverage(new MetadataScope(identity.catalog(),identity.schema(),identity.name(),kind)).orElse(null);
                // Missing/filtered/failed coverage never proves structural equivalence.
                if(!children.containsKey(kind)||old==null||!old.complete()||!old.level().includes(IntrospectionLevel.STRUCTURE)||!old.fingerprint().equals(children.getOrDefault(kind,Map.of()).getOrDefault(identity.name(),"0:0")))return false;
            }
            return true;
        }
        public boolean sourceComplete(MetadataSnapshot before,MetadataObject previous,SchemaObject acquired){return matches(before,previous,acquired,ALL_CHILDREN);}
    }
    private record Relation(String catalog,String schema,String name){}
    private record Namespace(String catalog,String schema,ObjectKind kind){}
    public record Reconciled(List<MetadataObject> objects,Set<MetadataScope> staleScopes) {
        public Reconciled {objects=List.copyOf(objects);staleScopes=Set.copyOf(staleScopes);}
    }
    public static Reconciled reconcile(MetadataSnapshot before,MetadataScope scope,List<MetadataObject> acquired,Evidence evidence,long deadline)throws java.util.concurrent.TimeoutException {
        var children=new HashMap<Relation,List<MetadataScope>>();var exact=new HashMap<Relation,List<MetadataScope>>();var enumerations=new HashMap<Namespace,List<MetadataScope>>();
        for(var cached:before.coverage().keySet()) {
            check(deadline);
            if(!cached.parent().isEmpty())children.computeIfAbsent(new Relation(cached.catalog(),cached.schema(),cached.parent()),ignored->new ArrayList<>()).add(cached);
            else if((cached.kind()==ObjectKind.TABLE||cached.kind()==ObjectKind.VIEW)&&!cached.exactName())enumerations.computeIfAbsent(new Namespace(cached.catalog(),cached.schema(),cached.kind()),ignored->new ArrayList<>()).add(cached);
            else if(cached.exactName()&&(cached.kind()==ObjectKind.TABLE||cached.kind()==ObjectKind.VIEW))exact.computeIfAbsent(new Relation(cached.catalog(),cached.schema(),cached.search()),ignored->new ArrayList<>()).add(cached);
        }
        var result=new ArrayList<MetadataObject>(acquired.size());var stale=new HashSet<MetadataScope>();var retained=new HashSet<String>();
        for(var object:acquired) {
            check(deadline);var identity=object.identity();retained.add(identity.name());var previous=before.identities().get(identity.key());
            if(previous==null) {
                result.add(object);
                // The name can be reused after DROP/CREATE with a different native identity.
                for(var old:before.resolve(identity.catalog(),identity.schema(),identity.kind(),"",identity.name(),true))invalidate(before,old,stale,children,exact,enumerations);
            }else if(previous.level()==IntrospectionLevel.NAMES)result.add(object);
            else if(evidence.matches(before,previous,object.projection(0,0))) {
                if(previous.level()==IntrospectionLevel.SOURCE&&!evidence.sourceComplete(before,previous,object.projection(0,0))) {
                    var properties=new HashMap<>(previous.properties());properties.put("sourceAvailability","STALE");
                    result.add(new MetadataObject(previous.identity(),previous.displayName(),previous.quotedIdentifier(),previous.lookupKey(),properties,previous.source(),IntrospectionLevel.STRUCTURE,MetadataState.AVAILABLE,previous.sourceRevision(),previous.contextRevision()));
                }else result.add(previous);
            }
            else {
                // Retain inspected source and facts for inspection, but never bless them as current.
                result.add(new MetadataObject(object.identity(),object.displayName(),object.quotedIdentifier(),object.lookupKey(),previous.properties(),previous.source(),previous.level(),MetadataState.STALE,previous.sourceRevision(),previous.contextRevision()));
                invalidate(before,previous,stale,children,exact,enumerations);
            }
        }
        for(var old:before.select(scope))if(!retained.contains(old.identity().name()))invalidate(before,old,stale,children,exact,enumerations);
        return new Reconciled(result,stale);
    }
    private static void invalidate(MetadataSnapshot before,MetadataObject relation,Set<MetadataScope> stale,Map<Relation,List<MetadataScope>> children,Map<Relation,List<MetadataScope>> exact,Map<Namespace,List<MetadataScope>> enumerations) {
        var identity=relation.identity();var key=new Relation(identity.catalog(),identity.schema(),identity.name());
        for(var scope:enumerations.getOrDefault(new Namespace(identity.catalog(),identity.schema(),identity.kind()),List.of()))if(scope.contains(relation))stale.add(scope);
        stale.addAll(children.getOrDefault(key,List.of()));for(var scope:exact.getOrDefault(key,List.of()))if(scope.kind()==identity.kind())stale.add(scope);
        for(var incoming:before.incoming(identity.catalog(),identity.schema(),identity.name())) {
            var source=incoming.identity();for(var scope:children.getOrDefault(new Relation(source.catalog(),source.schema(),source.parent()),List.of()))if(scope.kind()==ObjectKind.FOREIGN_KEY||scope.kind()==ObjectKind.CONSTRAINT)stale.add(scope);
        }
    }
    private static void check(long deadline)throws java.util.concurrent.TimeoutException {
        if(io.grpc.Context.current().isCancelled()||Thread.currentThread().isInterrupted())throw new java.util.concurrent.CancellationException("Metadata name reconciliation cancelled");
        if(System.nanoTime()>deadline)throw new java.util.concurrent.TimeoutException("Metadata name reconciliation deadline exceeded");
    }
}
