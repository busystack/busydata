package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.*;
import java.util.*;

/** Cached coverage affected by acknowledged DDL; never acquires database data. */
public final class MetadataInvalidation {
    private MetadataInvalidation(){}
    private record Relation(String catalog,String schema,String table){}
    public static Set<MetadataScope> scopes(MetadataSnapshot snapshot,Collection<DdlEffect> effects,String currentCatalog,String currentSchema){
        if(effects.isEmpty())return Set.copyOf(snapshot.coverage().keySet());
        var selected=new HashSet<MetadataScope>();var rules=snapshot.rules();
        for(var effect:effects){
            if(effect.getTemporary())continue;
            String catalog=effect.getCatalog().isEmpty()?currentCatalog:effect.getCatalog();
            String schema=effect.getSchema().isEmpty()?currentSchema:effect.getSchema();
            if(!effect.getConservative()&&effect.getKind()==ObjectKind.TABLE&&!effect.getName().isEmpty()){
                String table=effect.getName();boolean structural=!effect.getOperation().equalsIgnoreCase("COMMENT");
                for(var scope:snapshot.coverage().keySet())if(namespace(rules,scope,catalog,schema)){
                    if(scope.parent().isEmpty()&&(scope.kind()==ObjectKind.TABLE||scope.kind()==ObjectKind.VIEW)&&includesName(rules,scope,table))selected.add(scope);
                    else if(structural&&!scope.parent().isEmpty()&&same(rules,ObjectKind.TABLE,scope.parent(),table))selected.add(scope);
                }
                if(structural){
                    var dependents=new HashSet<Relation>();
                    for(var foreign:snapshot.kind(ObjectKind.FOREIGN_KEY)){
                        var properties=foreign.properties();
                        if(same(rules,ObjectKind.CATALOG,properties.getOrDefault("referencedCatalog",""),catalog)
                            &&same(rules,ObjectKind.SCHEMA,properties.getOrDefault("referencedSchema",""),schema)
                            &&same(rules,ObjectKind.TABLE,properties.getOrDefault("referencedTable",""),table)){
                            var identity=foreign.identity();dependents.add(key(rules,identity.catalog(),identity.schema(),identity.parent()));
                        }
                    }
                    for(var scope:snapshot.coverage().keySet())if((scope.kind()==ObjectKind.FOREIGN_KEY||scope.kind()==ObjectKind.CONSTRAINT)
                        &&dependents.contains(key(rules,scope.catalog(),scope.schema(),scope.parent())))selected.add(scope);
                }
            }else{
                // The effect does not prove a complete cross-object dependency
                // fragment. PostgreSQL dependencies stay within one database;
                // MySQL/MariaDB DDL can rename/reference across databases. A
                // context change only invalidates its captured namespace.
                boolean context=effect.getOperation().equalsIgnoreCase("CONTEXT");
                for(var scope:snapshot.coverage().keySet())if(context?namespace(rules,scope,catalog,schema)
                    :rules.engine()!=Engine.POSTGRESQL||scope.catalog().isEmpty()||same(rules,ObjectKind.CATALOG,scope.catalog(),catalog))selected.add(scope);
            }
        }
        return Set.copyOf(selected);
    }
    private static Relation key(IdentifierRules rules,String catalog,String schema,String table){return new Relation(rules.lookup(ObjectKind.CATALOG,catalog,true),rules.lookup(ObjectKind.SCHEMA,schema,true),rules.lookup(ObjectKind.TABLE,table,true));}
    private static boolean namespace(IdentifierRules rules,MetadataScope scope,String catalog,String schema){return same(rules,ObjectKind.CATALOG,scope.catalog(),catalog)&&(schema.isEmpty()||same(rules,ObjectKind.SCHEMA,scope.schema(),schema));}
    private static boolean same(IdentifierRules rules,ObjectKind kind,String first,String second){return rules.lookup(kind,first,true).equals(rules.lookup(kind,second,true));}
    private static boolean includesName(IdentifierRules rules,MetadataScope scope,String name){return scope.exactName()?same(rules,scope.kind(),scope.search(),name):name.toLowerCase(Locale.ROOT).contains(scope.search().toLowerCase(Locale.ROOT));}
}
