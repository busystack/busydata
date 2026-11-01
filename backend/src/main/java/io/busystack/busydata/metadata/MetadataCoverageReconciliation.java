package io.busystack.busydata.metadata;

import java.util.*;

/** Publication may not leave a broader proof complete after replacing its facts. */
public final class MetadataCoverageReconciliation {
    private MetadataCoverageReconciliation(){}
    public static Set<MetadataScope> invalidated(Map<MetadataScope,MetadataCoverage> coverage,MetadataScope replacement,List<MetadataObject> previous,List<MetadataObject> acquired) {
        var oldIds=new HashSet<MetadataIdentity>();for(var object:previous)oldIds.add(object.identity());
        var newIds=new HashSet<MetadataIdentity>();for(var object:acquired)newIds.add(object.identity());
        var changed=new ArrayList<MetadataObject>();for(var object:previous)if(!newIds.contains(object.identity()))changed.add(object);for(var object:acquired)if(!oldIds.contains(object.identity()))changed.add(object);
        var byName=new HashMap<String,List<MetadataObject>>();for(var object:acquired)byName.computeIfAbsent(object.identity().name(),ignored->new ArrayList<>()).add(object);
        var changedByName=new HashMap<String,List<MetadataObject>>();for(var object:changed)changedByName.computeIfAbsent(object.identity().name(),ignored->new ArrayList<>()).add(object);
        int minimum=acquired.stream().mapToInt(object->object.level().number()).min().orElse(4);long comparisons=0;
        var stale=new HashSet<MetadataScope>();
        for(var entry:coverage.entrySet()) {
            var scope=entry.getKey();var state=entry.getValue();if(scope.equals(replacement)||scope.kind()!=replacement.kind()||!state.complete())continue;
            if(io.grpc.Context.current().isCancelled()||Thread.currentThread().isInterrupted())throw new java.util.concurrent.CancellationException("Metadata publication cancelled");
            var identityChanges=scope.exactName()?changedByName.getOrDefault(scope.search(),List.of()):changed;
            for(var object:identityChanges){if(++comparisons>1_000_000){stale.add(scope);break;}if(scope.contains(object)){stale.add(scope);break;}}
            if(stale.contains(scope)||state.level().number()<=minimum||!scope.overlaps(replacement))continue;
            var facts=scope.exactName()?byName.getOrDefault(scope.search(),List.of()):acquired;
            for(var object:facts){if(++comparisons>1_000_000){stale.add(scope);break;}if(object.level().number()<state.level().number()&&scope.contains(object)){stale.add(scope);break;}}
        }
        return Set.copyOf(stale);
    }
}
