package io.busystack.busydata.metadata;

import java.util.*;

/** One authority reduction for native routine fields in every acquisition path. */
public final class RoutineAvailability {
    private RoutineAvailability(){}
    public record Assessment(IntrospectionLevel level,MetadataState objectState,MetadataState failure){
        public String limitation(){return failure==MetadataState.AVAILABLE?"":"Requested routine metadata is "+failure.name().toLowerCase(Locale.ROOT);}
    }
    public static Assessment assess(IntrospectionLevel requested,Map<String,String> properties){return assess(requested,properties,MetadataState.AVAILABLE);}
    public static Assessment assess(IntrospectionLevel requested,Map<String,String> properties,MetadataState fingerprint){
        Objects.requireNonNull(requested);Objects.requireNonNull(properties);Objects.requireNonNull(fingerprint);
        if(fingerprint!=MetadataState.AVAILABLE)return new Assessment(IntrospectionLevel.NAMES,MetadataState.PARTIAL,fingerprint);
        if(requested==IntrospectionLevel.NAMES)return new Assessment(requested,MetadataState.AVAILABLE,MetadataState.AVAILABLE);
        var state=field(properties.get("signatureAvailability"));if(state==MetadataState.AVAILABLE)state=field(properties.get("parameterDefaultsAvailability"));
        if(state!=MetadataState.AVAILABLE)return new Assessment(IntrospectionLevel.NAMES,MetadataState.PARTIAL,state);
        if(requested==IntrospectionLevel.SOURCE){state=field(properties.get("sourceAvailability"));if(state!=MetadataState.AVAILABLE)return new Assessment(IntrospectionLevel.STRUCTURE,MetadataState.AVAILABLE,state);}
        return new Assessment(requested,MetadataState.AVAILABLE,MetadataState.AVAILABLE);
    }
    private static MetadataState field(String value){if(value==null)return MetadataState.UNAVAILABLE;try{return MetadataState.valueOf(value);}catch(IllegalArgumentException unavailable){return MetadataState.UNAVAILABLE;}}
    public static MetadataObject apply(MetadataObject object,Assessment assessment){
        if(object.level()==assessment.level()&&object.state()==assessment.objectState())return object;
        return new MetadataObject(object.identity(),object.displayName(),object.quotedIdentifier(),object.lookupKey(),object.properties(),object.source(),assessment.level(),assessment.objectState(),object.sourceRevision(),object.contextRevision());
    }
}
