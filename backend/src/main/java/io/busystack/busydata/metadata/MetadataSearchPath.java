package io.busystack.busydata.metadata;

import java.util.*;

/** PostgreSQL namespace ordering facts; consumers supply captured server context. */
public final class MetadataSearchPath {
    private MetadataSearchPath(){}
    public static List<String> postgres(List<String> explicit,String temporarySchema,boolean includeTemporary){
        Objects.requireNonNull(temporarySchema);boolean listedTemporary=false;var ordered=new LinkedHashSet<String>();
        for(String namespace:explicit){
            boolean ownTemporary=namespace.equals("pg_temp")||!temporarySchema.isEmpty()&&namespace.equals(temporarySchema);listedTemporary|=ownTemporary;
            if(namespace.equals("pg_temp")){if(temporarySchema.isEmpty())continue;namespace=temporarySchema;}
            if(!includeTemporary&&(ownTemporary||namespace.startsWith("pg_temp_")))continue;
            ordered.add(namespace);
        }
        var result=new ArrayList<String>();if(includeTemporary&&!temporarySchema.isEmpty()&&!listedTemporary)result.add(temporarySchema);
        if(!ordered.contains("pg_catalog"))result.add("pg_catalog");result.addAll(ordered);return List.copyOf(result);
    }
}
