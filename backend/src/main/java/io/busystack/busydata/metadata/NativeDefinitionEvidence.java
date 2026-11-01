package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.Engine;
import java.util.*;

/** A complete native source comparison marker, never executable DDL or a
 * substitute for acquired structural metadata or physical incarnation proof. */
public record NativeDefinitionEvidence(MetadataState availability,String sha256,long bytes,String sqlMode,String renderer,String provenance) {
    public static final long MAX_BYTES=8_388_608;
    public static final String PROVENANCE="OWNED_NATIVE_SHOW_CREATE_UTF8_SHA256_V1";
    private static final Set<String> MARIA_OMISSIONS=Set.of("NO_FIELD_OPTIONS","NO_KEY_OPTIONS","NO_TABLE_OPTIONS","MYSQL323","MYSQL40","ORACLE","POSTGRESQL","MSSQL","DB2","MAXDB","ANSI");
    public NativeDefinitionEvidence {
        Objects.requireNonNull(availability);Objects.requireNonNull(sha256);Objects.requireNonNull(sqlMode);Objects.requireNonNull(renderer);Objects.requireNonNull(provenance);
        if(bytes<0||bytes>MAX_BYTES||sqlMode.length()>4096||sqlMode.indexOf(0)>=0||renderer.length()>64||renderer.indexOf(0)>=0||!provenance.isEmpty()&&!provenance.equals(PROVENANCE))throw new IllegalArgumentException("Invalid native definition evidence");
        if(availability==MetadataState.AVAILABLE){if(bytes==0||!sha256.matches("[0-9a-f]{64}")||!provenance.equals(PROVENANCE)||!Set.of("quote=0;gipk=1","quote=1;gipk=1","quote=0;gipk=N/A","quote=1;gipk=N/A").contains(renderer))throw new IllegalArgumentException("Complete native source provenance required");}
        else if(!sha256.isEmpty())throw new IllegalArgumentException("Incomplete native source cannot expose a digest");
    }
    public static NativeDefinitionEvidence unavailable(){return new NativeDefinitionEvidence(MetadataState.UNAVAILABLE,"",0,"","","");}
    public static MetadataState sourceAvailability(Engine engine,String sqlMode){
        if(engine!=Engine.MYSQL&&engine!=Engine.MARIADB)return MetadataState.UNSUPPORTED;
        if(sqlMode==null||sqlMode.length()>4096||sqlMode.indexOf(0)>=0)return MetadataState.UNAVAILABLE;
        // ANSI_QUOTES alone selects identifier quoting. ANSI still suppresses
        // native table/key options in both pinned renderers; NO_DIR_IN_CREATE
        // suppresses directory attributes. Full drains cannot repair omission.
        var modes=Arrays.stream(sqlMode.toUpperCase(Locale.ROOT).split(",")).map(String::trim).toList();
        if(modes.contains("ANSI")||modes.contains("NO_DIR_IN_CREATE"))return MetadataState.PARTIAL;
        if(engine==Engine.MARIADB&&modes.stream().anyMatch(MARIA_OMISSIONS::contains))return MetadataState.PARTIAL;
        if(engine==Engine.MYSQL&&modes.stream().anyMatch(mode->!mode.equals("ANSI")&&MARIA_OMISSIONS.contains(mode)))return MetadataState.UNSUPPORTED;
        return MetadataState.AVAILABLE;
    }
    public static MetadataState sourceAvailability(Engine engine,String mode,String renderer){
        var state=sourceAvailability(engine,mode);
        if(state==MetadataState.AVAILABLE&&!(engine==Engine.MYSQL?Set.of("quote=0;gipk=1","quote=1;gipk=1"):Set.of("quote=0;gipk=N/A","quote=1;gipk=N/A")).contains(renderer))return MetadataState.PARTIAL;
        return state;
    }
    public static NativeDefinitionEvidence drained(Engine engine,String mode,String renderer,String sha256,long bytes){
        var state=sourceAvailability(engine,mode,renderer);
        if(state==MetadataState.UNAVAILABLE)return unavailable();
        return new NativeDefinitionEvidence(state,state==MetadataState.AVAILABLE?sha256:"",bytes,mode,renderer,PROVENANCE);
    }
    public boolean complete(){return availability==MetadataState.AVAILABLE;}
    public Map<String,String> properties(){return Map.of("nativeDefinitionAvailability",availability.name(),"nativeDefinitionSha256",sha256,"nativeDefinitionBytes",Long.toString(bytes),"nativeDefinitionSqlMode",sqlMode,"nativeDefinitionRenderer",renderer,"nativeDefinitionProvenance",provenance);}
    public static NativeDefinitionEvidence from(Map<String,String> properties){
        try{return new NativeDefinitionEvidence(MetadataState.valueOf(properties.getOrDefault("nativeDefinitionAvailability","UNAVAILABLE")),properties.getOrDefault("nativeDefinitionSha256",""),Long.parseLong(properties.getOrDefault("nativeDefinitionBytes","0")),properties.getOrDefault("nativeDefinitionSqlMode",""),properties.getOrDefault("nativeDefinitionRenderer",""),properties.getOrDefault("nativeDefinitionProvenance",""));}
        catch(IllegalArgumentException malformed){return unavailable();}
    }
}
