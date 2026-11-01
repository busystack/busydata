package io.busystack.busydata;

import io.busystack.busydata.analysis.language.ResolutionContext;
import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import java.util.*;

/** Test-only normalization into the production metadata model.
 * A complete declaration means the explicitly supplied objects are the whole
 * known fixture model in selected/effective and explicitly supplied namespaces.
 * It can therefore declare empty scopes, never invent objects or type facts.
 * Partial declarations and explicit object availability remain incomplete.
 */
final class SemanticFixtures {
    private SemanticFixtures(){}
    private record Namespace(String catalog,String schema){}
    private record Parent(String catalog,String schema,String table){}
    private static final List<ObjectKind> NAMES=List.of(ObjectKind.TABLE,ObjectKind.VIEW,ObjectKind.SEQUENCE,ObjectKind.ROUTINE,ObjectKind.TYPE);

    static Analysis analyze(io.busystack.busydata.analysis.SqlAnalysis service,AnalysisRequest request,List<SchemaObject> objects,io.busystack.busydata.analysis.LexicalSettings lexical,ResolutionContext declared){
        return analyze(service,request,objects,lexical,declared,()->io.grpc.Context.current().isCancelled());
    }
    static Analysis analyze(io.busystack.busydata.analysis.SqlAnalysis service,AnalysisRequest request,List<SchemaObject> objects,io.busystack.busydata.analysis.LexicalSettings lexical,ResolutionContext declared,java.util.function.BooleanSupplier cancelled){
        return service.analyze(request,lexical,context(request.getEngine(),objects,declared),cancelled);
    }

    static ResolutionContext context(Engine engine,List<SchemaObject> objects,ResolutionContext declared){
        Objects.requireNonNull(engine);Objects.requireNonNull(objects);Objects.requireNonNull(declared);
        if(declared.snapshot()!=null)return declared;
        if(declared.metadataRevision()<0||declared.configurationRevision()<0)throw new IllegalArgumentException("Fixture revisions must be nonnegative");
        var rules=declared.identifierRules()==null?NativeCaseFixtures.rules(engine,0):declared.identifierRules();
        String source=MetadataIdentity.digest("semantic-fixture",engine.name()),profile="semantic-fixture";
        var entries=new ArrayList<MetadataObject>(objects.size());var namespaces=new LinkedHashSet<Namespace>();
        if(!declared.catalog().isEmpty()){
            if(!declared.schema().isEmpty())namespaces.add(new Namespace(declared.catalog(),declared.schema()));
            var path=declared.searchPath().isEmpty()?(declared.schema().isEmpty()?List.<String>of():List.of(declared.schema())):declared.searchPath();
            if(engine==Engine.POSTGRESQL)path=MetadataSearchPath.postgres(path,declared.temporarySchema(),true);
            for(String schema:path)if(!schema.isEmpty())namespaces.add(new Namespace(declared.catalog(),schema));
        }
        for(var original:objects){
            var object=original.toBuilder();
            if(original.getCatalog().isEmpty())object.setCatalog(declared.catalog());
            if(original.getSchema().isEmpty())object.setSchema(declared.schema());
            var value=object.build();
            if(value.getCatalog().isEmpty())throw new IllegalArgumentException("A fixture object requires an explicit or declared catalog");
            var level=value.getIntrospectionLevel()==0?IntrospectionLevel.STRUCTURE:IntrospectionLevel.of(value.getIntrospectionLevel());
            MetadataState state=value.getMetadataState().isEmpty()?MetadataState.AVAILABLE:MetadataState.valueOf(value.getMetadataState().toUpperCase(Locale.ROOT));
            long sourceRevision=value.getSourceRevision().isEmpty()?declared.metadataRevision():Long.parseLong(value.getSourceRevision());
            var normalized=MetadataObject.from(source,profile,value.getPropertiesOrDefault("sessionOwner",""),rules,value,level,sourceRevision,0);
            if(state!=MetadataState.AVAILABLE)normalized=new MetadataObject(normalized.identity(),normalized.displayName(),normalized.quotedIdentifier(),normalized.lookupKey(),normalized.properties(),normalized.source(),level,state,sourceRevision,0);
            entries.add(normalized);
            if(!value.getSchema().isEmpty())namespaces.add(new Namespace(value.getCatalog(),value.getSchema()));
        }
        var grouped=new HashMap<MetadataScope,List<MetadataObject>>();
        for(var object:entries){var identity=object.identity();var scope=new MetadataScope(identity.catalog(),identity.schema(),identity.parent(),identity.kind());grouped.computeIfAbsent(scope,ignored->new ArrayList<>()).add(object);}
        var coverage=new LinkedHashMap<MetadataScope,MetadataCoverage>();
        for(var namespace:namespaces)for(var kind:NAMES){
            var scope=new MetadataScope(namespace.catalog(),namespace.schema(),"",kind);
            var members=grouped.getOrDefault(scope,List.of());
            put(coverage,scope,members,IntrospectionLevel.STRUCTURE,declared);
        }
        var parents=new LinkedHashMap<Parent,MetadataObject>();
        for(var object:entries)if(object.identity().kind()==ObjectKind.TABLE||object.identity().kind()==ObjectKind.VIEW){var identity=object.identity();parents.put(new Parent(identity.catalog(),identity.schema(),identity.name()),object);}
        for(var entry:parents.entrySet())for(var kind:List.of(ObjectKind.COLUMN,ObjectKind.FOREIGN_KEY)){
            var parent=entry.getKey();var scope=new MetadataScope(parent.catalog(),parent.schema(),parent.table(),kind);
            var members=grouped.getOrDefault(scope,List.of());
            var fallback=entry.getValue().level().includes(IntrospectionLevel.STRUCTURE)?IntrospectionLevel.STRUCTURE:IntrospectionLevel.NAMES;
            put(coverage,scope,members,fallback,declared);
            if(members.isEmpty()&&!fallback.includes(IntrospectionLevel.STRUCTURE))coverage.put(scope,new MetadataCoverage(scope,IntrospectionLevel.NAMES,MetadataState.NOT_REQUESTED,false,"",declared.metadataRevision(),0,0,"Fixture names level did not request structure"));
        }
        var snapshot=new MetadataSnapshot(source,profile,declared.metadataRevision(),declared.configurationRevision(),0,rules,entries,coverage);
        return new ResolutionContext(declared.catalog(),declared.schema(),declared.searchPath(),declared.complete(),declared.metadataRevision(),declared.configurationRevision(),rules,snapshot,declared.temporarySchema());
    }
    private static void put(Map<MetadataScope,MetadataCoverage> output,MetadataScope scope,List<MetadataObject> members,IntrospectionLevel fallback,ResolutionContext declared){
        var level=members.stream().map(MetadataObject::level).min(Comparator.comparingInt(IntrospectionLevel::number)).orElse(fallback);
        MetadataState state=declared.complete()?MetadataState.AVAILABLE:MetadataState.PARTIAL;
        for(var member:members)if(member.state()!=MetadataState.AVAILABLE){state=member.state();break;}
        boolean complete=declared.complete()&&state==MetadataState.AVAILABLE;
        output.put(scope,new MetadataCoverage(scope,level,state,complete,"",declared.metadataRevision(),0,0,complete?"":"Fixture availability is explicitly incomplete"));
    }
}
