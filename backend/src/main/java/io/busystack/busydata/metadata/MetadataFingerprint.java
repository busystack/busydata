package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.SchemaObject;
import java.util.*;

/** Durable fingerprints never depend on collection iteration or protobuf debug text. */
public final class MetadataFingerprint {
    private MetadataFingerprint(){}
    public static String objects(Collection<SchemaObject> objects) {
        var components=new ArrayList<String>();components.add("metadata-objects-v1");components.add(Integer.toString(objects.size()));
        var ordered=objects.stream().sorted(Comparator.comparingInt(SchemaObject::getKindValue).thenComparing(SchemaObject::getCatalog).thenComparing(SchemaObject::getSchema).thenComparing(SchemaObject::getTable).thenComparing(SchemaObject::getName).thenComparing(SchemaObject::getIdentifier)).toList();
        for(var object:ordered) {
            components.addAll(List.of(Integer.toString(object.getKindValue()),Integer.toString(object.getSubtypeValue()),object.getCatalog(),object.getSchema(),object.getTable(),object.getName(),object.getIdentifier(),object.getDefinition()));
            var properties=new TreeMap<>(object.getPropertiesMap());
            for(String presentation:List.of("stableIdentity","quotedIdentifier","normalizedIdentifier","metadataSnapshotRevision","metadataConfigurationRevision","introspectionLevel","metadataState","sourceRevision","sessionOwner"))properties.remove(presentation);
            components.add(Integer.toString(properties.size()));for(var property:properties.entrySet()){components.add(property.getKey());components.add(property.getValue());}
        }
        return MetadataIdentity.digest(components.toArray(String[]::new));
    }
    public static String table(Map<String,Integer> types,Map<String,List<String>> details,Set<String> generated,Set<String> primary,Map<String,Set<String>> unique,Set<String> invalid,List<SchemaObject> columns,List<SchemaObject> relationships,String nativeTypes,String constraints) {
        var parts=new ArrayList<String>();parts.add("table-metadata-v1");parts.add(Integer.toString(types.size()));
        for(var entry:new TreeMap<>(types).entrySet()){parts.add(entry.getKey());parts.add(Integer.toString(entry.getValue()));}
        parts.add(Integer.toString(details.size()));for(var entry:new TreeMap<>(details).entrySet()){parts.add(entry.getKey());parts.add(Integer.toString(entry.getValue().size()));parts.addAll(entry.getValue());}
        for(var values:List.of(generated,primary,invalid)){parts.add(Integer.toString(values.size()));parts.addAll(new TreeSet<>(values));}
        parts.add(Integer.toString(unique.size()));for(var entry:new TreeMap<>(unique).entrySet()){parts.add(entry.getKey());parts.add(Integer.toString(entry.getValue().size()));parts.addAll(new TreeSet<>(entry.getValue()));}
        parts.add(objects(columns));parts.add(objects(relationships));parts.add(nativeTypes);parts.add(constraints);return MetadataIdentity.digest(parts.toArray(String[]::new));
    }
}
