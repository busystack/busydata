package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.*;
import java.util.*;

/** Introspection policy is separate from connection settings and UI visibility. */
public record MetadataConfiguration(long revision,Set<String> includedCatalogs,Set<String> excludedCatalogs,
        Set<String> includedSchemas,Set<String> excludedSchemas,boolean systemObjects,Set<ObjectKind> kinds,
        List<String> includePatterns,List<String> excludePatterns,IntrospectionLevel defaultLevel,Map<String,IntrospectionLevel> scopeLevels) {
    public MetadataConfiguration {
        if(revision<1)throw new IllegalArgumentException("Configuration revision required");
        includedCatalogs=Set.copyOf(includedCatalogs);excludedCatalogs=Set.copyOf(excludedCatalogs);includedSchemas=Set.copyOf(includedSchemas);excludedSchemas=Set.copyOf(excludedSchemas);
        kinds=Set.copyOf(kinds);includePatterns=List.copyOf(includePatterns);excludePatterns=List.copyOf(excludePatterns);scopeLevels=Map.copyOf(scopeLevels);
        if(includedCatalogs.size()+excludedCatalogs.size()+includedSchemas.size()+excludedSchemas.size()+scopeLevels.size()>2048||includePatterns.size()+excludePatterns.size()>64)throw new IllegalArgumentException("Metadata configuration scope budget exceeded");
        for(String value:java.util.stream.Stream.of(includedCatalogs,excludedCatalogs,includedSchemas,excludedSchemas,includePatterns,excludePatterns).flatMap(Collection::stream).toList())if(value.length()>512||value.indexOf('\0')>=0)throw new IllegalArgumentException("Invalid metadata configuration pattern");
        for(String key:scopeLevels.keySet()){if(key.length()>2048)throw new IllegalArgumentException("Invalid metadata introspection scope");for(String name:scopeParts(key))if(name.length()>256||name.indexOf('\0')>=0)throw new IllegalArgumentException("Invalid metadata introspection scope");}
        Objects.requireNonNull(defaultLevel);
    }
    public static MetadataConfiguration defaults(){return new MetadataConfiguration(1,Set.of(),Set.of(),Set.of(),Set.of(),false,Set.of(ObjectKind.values()).stream().filter(k->k!=ObjectKind.UNRECOGNIZED).collect(java.util.stream.Collectors.toSet()),List.of(),List.of(),IntrospectionLevel.STRUCTURE,Map.of());}
    public static String scopeKey(String catalog,String schema){var encoder=Base64.getUrlEncoder().withoutPadding();return encoder.encodeToString(catalog.getBytes(java.nio.charset.StandardCharsets.UTF_8))+"."+encoder.encodeToString(schema.getBytes(java.nio.charset.StandardCharsets.UTF_8));}
    public static List<String> scopeParts(String key){int separator=key.indexOf('.');if(separator<0||separator!=key.lastIndexOf('.'))throw new IllegalArgumentException("Invalid introspection scope key");var decoder=Base64.getUrlDecoder();return List.of(new String(decoder.decode(key.substring(0,separator)),java.nio.charset.StandardCharsets.UTF_8),new String(decoder.decode(key.substring(separator+1)),java.nio.charset.StandardCharsets.UTF_8));}
    public IntrospectionLevel level(String catalog,String schema){return scopeLevels.getOrDefault(scopeKey(catalog,schema),defaultLevel);}
    public boolean permits(String catalog,String schema,ObjectKind kind,String name) {
        return (includedCatalogs.isEmpty()||includedCatalogs.contains(catalog))&&!excludedCatalogs.contains(catalog)
            &&(schema.isEmpty()||includedSchemas.isEmpty()||includedSchemas.contains(schema))&&!excludedSchemas.contains(schema)
            &&(systemObjects||!system(schema))&&kinds.contains(kind)
            &&(name.isEmpty()||includePatterns.isEmpty()||includePatterns.stream().anyMatch(p->matches(p,name)))
            &&(name.isEmpty()||excludePatterns.stream().noneMatch(p->matches(p,name)));
    }
    public static boolean system(String schema){return schema.equals("information_schema")||schema.equals("pg_catalog")||schema.equals("mysql")||schema.equals("performance_schema")||schema.equals("sys")||schema.startsWith("pg_toast")||schema.startsWith("pg_temp_");}
    /** Bounded wildcard matching, without user-supplied regular expressions. */
    public static boolean matches(String pattern,String text) {
        int p=0,t=0,star=-1,retry=0;
        while(t<text.length()) {
            if(p<pattern.length()&&(pattern.charAt(p)=='?'||pattern.charAt(p)==text.charAt(t))){p++;t++;}
            else if(p<pattern.length()&&pattern.charAt(p)=='*'){star=p++;retry=t;}
            else if(star>=0){p=star+1;t=++retry;}else return false;
        }
        while(p<pattern.length()&&pattern.charAt(p)=='*')p++;
        return p==pattern.length();
    }
}
