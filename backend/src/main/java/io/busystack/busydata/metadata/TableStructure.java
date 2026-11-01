package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.SchemaObject;
import java.util.*;

/** One verified relation structure shared by editing, browsing and semantic clients. */
public record TableStructure(Map<String,Integer> types,Set<String> generated,List<Set<String>> identities,
        String signature,String recoverySignature,String nativeGeneration,String nativeGenerationAvailability,List<SchemaObject> columns,List<SchemaObject> constraints,List<SchemaObject> relationships,List<SchemaObject> indexes) {
    public TableStructure {
        types=Collections.unmodifiableMap(new TreeMap<>(types));generated=Set.copyOf(generated);
        identities=identities.stream().map(Set::copyOf).toList();columns=List.copyOf(columns);constraints=List.copyOf(constraints);relationships=List.copyOf(relationships);indexes=List.copyOf(indexes);
    }
}
