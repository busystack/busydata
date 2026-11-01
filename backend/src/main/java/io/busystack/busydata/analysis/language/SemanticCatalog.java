package io.busystack.busydata.analysis.language;

import io.busystack.busydata.protocol.*;
import java.util.*;
import io.busystack.busydata.analysis.language.SyntaxTree.Name;
import io.busystack.busydata.metadata.MetadataObject;
import io.busystack.busydata.metadata.MetadataSnapshot;

/** Request-local semantic access to the central immutable indexes.
 * Only referenced branches are projected; no request copies the full catalog. */
public final class SemanticCatalog {
    public record RelationKey(String catalog,String schema,String name,String sessionOwner){public RelationKey(String catalog,String schema,String name){this(catalog,schema,name,"");}}
    private final Dialect dialect;private final ResolutionContext context;private final MetadataSnapshot snapshot;private final AnalysisBudget budget;
    private final Map<RelationKey,SchemaObject> relations=new LinkedHashMap<>();
    private final Map<RelationKey,List<SchemaObject>> columns=new HashMap<>();
    private final Map<String,List<RoutineSignatures.Signature>> builtins=new TreeMap<>();
    public SemanticCatalog(Dialect dialect,ResolutionContext context,AnalysisBudget budget){
        this.dialect=dialect;this.context=context;this.snapshot=context.snapshot()==null?MetadataSnapshot.empty("unavailable","unavailable",context.rules(dialect)):context.snapshot();this.budget=budget;
        for(var signature:RoutineSignatures.builtins(dialect.engine()))builtins.computeIfAbsent(signature.name(),ignored->new ArrayList<>()).add(signature);
        builtins.replaceAll((name,signatures)->List.copyOf(signatures));
    }
    public ResolutionContext context(){return context;}
    private boolean supportsObjectName(Name name){
        if(!dialect.supportsObjectName(name))return false;
        if(!dialect.postgres()||name.parts().size()<3)return true;
        var catalog=name.parts().getFirst();
        return !context.catalog().isEmpty()&&context.rules(dialect).matches(ObjectKind.CATALOG,context.catalog(),catalog.identifier(),catalog.quoted());
    }
    public boolean nativeRulesComplete(){return context.rules(dialect).complete()&&(context.snapshot()==null||context.snapshot().identifierRulesAvailable());}
    public String namespaceName(io.busystack.busydata.analysis.language.LosslessLexer.Token token){String name=context.rules(dialect).lookup(ObjectKind.SCHEMA,token.identifier(),token.quoted());return dialect.postgres()&&name.equals("pg_temp")&&!context.temporarySchema().isEmpty()?context.temporarySchema():name;}
    public List<String> searchPath(boolean includeTemporary){var explicit=context.searchPath().isEmpty()?(context.schema().isEmpty()?List.<String>of():List.of(context.schema())):context.searchPath();return dialect.postgres()?io.busystack.busydata.metadata.MetadataSearchPath.postgres(explicit,context.temporarySchema(),includeTemporary):explicit;}
    public Collection<SchemaObject> relations(){return projected(ObjectKind.TABLE,ObjectKind.VIEW,ObjectKind.SEQUENCE);}
    public Collection<SchemaObject> namespaces(){return projected(ObjectKind.SCHEMA,ObjectKind.CATALOG);}
    public Collection<SchemaObject> types(){return projected(ObjectKind.TYPE);}
    public Collection<SchemaObject> relationships(){return projected(ObjectKind.FOREIGN_KEY);}
    public boolean relationshipsComplete(RelationKey key){if(!snapshot.outgoingComplete(key.catalog(),key.schema(),key.name()))return false;for(var relationship:snapshot.outgoing(key.catalog(),key.schema(),key.name()))if(!snapshot.relationshipComplete(relationship))return false;return true;}
    public List<RoutineSignatures.Signature> routines(String name){return routines(new Name(List.of(new io.busystack.busydata.analysis.language.LosslessLexer.Token(io.busystack.busydata.analysis.language.LosslessLexer.Kind.WORD,name,0,name.length(),true))));}
    public List<RoutineSignatures.Signature> routines(Name name){return routines(name,true);}
    public List<RoutineSignatures.Signature> routines(Name name,boolean nativeEligible){return nativeRoutines(name,false,nativeEligible);}
    public List<RoutineSignatures.Signature> procedures(Name name){return nativeRoutines(name,true,false);}
    /** PostgreSQL expands defaults and resolves all routine kinds before it
     * rejects the wrong kind. Keep captured facts, but do not claim call/type
     * certainty while an opposite-kind candidate can accept this arity. This
     * deliberately does not choose among native coercions or declare ambiguity. */
    public List<RoutineSignatures.Signature> callSignatures(Name name,boolean procedure,boolean nativeEligible,int arity){
        var requested=procedure?procedures(name):routines(name,nativeEligible);
        if(!dialect.postgres()||requested.isEmpty())return requested;
        var opposite=procedure?routines(name):procedures(name);
        for(var candidate:opposite){budget.check();if(oppositeArityPossible(candidate,arity))return requested.stream().map(SemanticCatalog::incomplete).toList();}
        return requested;
    }
    private boolean oppositeArityPossible(RoutineSignatures.Signature candidate,int arity){
        // Namespace/search-path uncertainty can wrap otherwise complete
        // parameter facts. It must not make a known two-input signature accept
        // three inputs. Re-read only its exact immutable capture, never JDBC.
        if(candidate.identity().startsWith("builtin:"))return arity>=candidate.minimumArguments()&&arity<=candidate.maximumArguments();
        var object=snapshot.identity(candidate.identity()).orElse(null);
        if(object==null||!object.level().includes(io.busystack.busydata.metadata.IntrospectionLevel.STRUCTURE))return true;
        var captured=RoutineSignatures.from(snapshot.projection(object),dialect.engine());
        return !captured.complete()||arity>=captured.minimumArguments()&&arity<=captured.maximumArguments();
    }
    private List<RoutineSignatures.Signature> nativeRoutines(Name name,boolean procedure,boolean nativeEligible){
        if(!supportsObjectName(name))return List.of();
        if(dialect.postgres()&&name.parts().size()==1)return postgresRoutines(name,procedure);
        var parts=name.parts();var token=name.last();String exact=dialect.identifier(token);List<MetadataObject> objects=List.of();boolean earlierComplete=nativeRulesComplete();
        // MySQL8.4 and MariaDB11.8 require qualification to call a stored
        // function whose name collides with a native function. CALL has no
        // native-function fallback and resolves only verified procedures.
        if(nativeEligible&&!procedure&&!dialect.postgres()&&parts.size()==1&&builtins.containsKey(builtinKey(exact)))return builtins.get(builtinKey(exact));
        if(parts.size()>1){String schema=namespaceName(parts.get(parts.size()-2)),catalog=parts.size()>2?dialect.identifier(parts.getFirst()):dialect.postgres()?context.catalog():schema;objects=snapshot.resolve(catalog,schema,ObjectKind.ROUTINE,"",token.identifier(),token.quoted());}
        else {
            for(String schema:searchPath(false)){budget.check();var visible=snapshot.resolve(context.catalog(),schema,ObjectKind.ROUTINE,"",token.identifier(),token.quoted());if(hasRoutineKind(visible,procedure)){objects=visible;break;}if(!procedure&&dialect.postgres()&&schema.equals("pg_catalog")&&builtins.containsKey(builtinKey(exact))){var builtin=builtins.get(builtinKey(exact));return earlierComplete?builtin:builtin.stream().map(SemanticCatalog::incomplete).toList();}earlierComplete&=context.complete()&&snapshot.complete(new io.busystack.busydata.metadata.MetadataScope(context.catalog(),schema,"",ObjectKind.ROUTINE),io.busystack.busydata.metadata.IntrospectionLevel.NAMES);}
        }
        var ordering=Comparator.comparing(RoutineSignatures.Signature::display).thenComparing(RoutineSignatures.Signature::identity);var best=new PriorityQueue<RoutineSignatures.Signature>(65,ordering.reversed());
        for(var object:objects){budget.check();if(!routineKind(object,procedure))continue;if(object.state()!=io.busystack.busydata.metadata.MetadataState.AVAILABLE&&object.state()!=io.busystack.busydata.metadata.MetadataState.PARTIAL)continue;var signature=RoutineSignatures.from(snapshot.projection(object),dialect.engine());if(!earlierComplete||!routineStructureComplete(object)||object.state()==io.busystack.busydata.metadata.MetadataState.PARTIAL)signature=incomplete(signature);if(!context.rules(dialect).matches(ObjectKind.ROUTINE,signature.name(),token.identifier(),token.quoted()))continue;if(best.size()<65)best.add(signature);else if(ordering.compare(signature,best.peek())<0){best.remove();best.add(signature);}}
        if(best.isEmpty())return !nativeEligible||procedure||parts.size()>1?List.of():builtins.getOrDefault(builtinKey(exact),List.of());
        var result=new ArrayList<>(best);result.sort(ordering);
        if(result.size()==65){var extra=result.getLast();result.set(64,new RoutineSignatures.Signature(extra.identity(),extra.name(),extra.catalog(),extra.schema(),extra.display(),extra.parameters(),extra.returns(),false));}
        return result;
    }
    private List<RoutineSignatures.Signature> postgresRoutines(Name name,boolean procedure){
        var token=name.last();var path=searchPath(false);boolean earlierComplete=nativeRulesComplete();
        var ordering=Comparator.comparing(RoutineSignatures.Signature::display).thenComparing(RoutineSignatures.Signature::identity);var best=new PriorityQueue<RoutineSignatures.Signature>(65,ordering.reversed());
        for(int scope=0;scope<path.size();scope++){
            budget.check();String schema=path.get(scope);var objects=snapshot.resolve(context.catalog(),schema,ObjectKind.ROUTINE,"",token.identifier(),token.quoted());
            for(var object:objects){
                budget.check();if(!routineKind(object,procedure))continue;if(object.state()!=io.busystack.busydata.metadata.MetadataState.AVAILABLE&&object.state()!=io.busystack.busydata.metadata.MetadataState.PARTIAL)continue;
                var inputTypes=nativeInputTypes(object);boolean shadowed=false,uncertain=false;
                for(int prior=0;prior<scope&&!shadowed;prior++){
                    budget.check();var preceding=snapshot.resolve(context.catalog(),path.get(prior),ObjectKind.ROUTINE,"",token.identifier(),token.quoted());
                    for(var previous:preceding){budget.check();var precedingTypes=nativeInputTypes(previous);if(inputTypes==null||precedingTypes==null)uncertain=true;else if(inputTypes.equals(precedingTypes)){shadowed=true;break;}}
                    if(!procedure&&preceding.isEmpty()&&path.get(prior).equals("pg_catalog")&&builtins.containsKey(builtinKey(dialect.identifier(token))))uncertain=true;
                }
                if(shadowed)continue;
                var signature=RoutineSignatures.from(snapshot.projection(object),dialect.engine());if(!earlierComplete||uncertain||!routineStructureComplete(object)||object.state()==io.busystack.busydata.metadata.MetadataState.PARTIAL)signature=incomplete(signature);admitSignature(best,signature,ordering);
            }
            if(!procedure&&objects.isEmpty()&&schema.equals("pg_catalog"))for(var signature:builtins.getOrDefault(builtinKey(dialect.identifier(token)),List.of())){
                boolean potentiallyShadowed=false;for(int prior=0;prior<scope;prior++){budget.check();if(!snapshot.resolve(context.catalog(),path.get(prior),ObjectKind.ROUTINE,"",token.identifier(),token.quoted()).isEmpty()){potentiallyShadowed=true;break;}}
                admitSignature(best,earlierComplete&&!potentiallyShadowed?signature:incomplete(signature),ordering);
            }
            earlierComplete&=context.complete()&&snapshot.complete(new io.busystack.busydata.metadata.MetadataScope(context.catalog(),schema,"",ObjectKind.ROUTINE),io.busystack.busydata.metadata.IntrospectionLevel.NAMES);
        }
        var result=new ArrayList<>(best);result.sort(ordering);if(result.size()==65)result.set(64,incomplete(result.getLast()));return result;
    }
    /** PostgreSQL overload identity consists only of ordered native input type OIDs. */
    private List<String> nativeInputTypes(MetadataObject object){
        var properties=object.properties();int count=SqlTypes.integer(properties.get("parameterCount"),-1);if(count<0||count>1024)return null;var types=new ArrayList<String>();
        for(int index=0;index<count;index++){budget.check();String prefix="parameter."+index+".",mode=properties.getOrDefault(prefix+"mode","IN");if(Set.of("OUT","TABLE","RETURN").contains(mode))continue;String identity=properties.getOrDefault(prefix+"nativeTypeId","");if(identity.isEmpty())return null;types.add(identity);}return types;
    }
    private static void admitSignature(PriorityQueue<RoutineSignatures.Signature> best,RoutineSignatures.Signature signature,Comparator<RoutineSignatures.Signature> ordering){if(best.size()<65)best.add(signature);else if(ordering.compare(signature,best.peek())<0){best.remove();best.add(signature);}}
    private static RoutineSignatures.Signature incomplete(RoutineSignatures.Signature signature){return new RoutineSignatures.Signature(signature.identity(),signature.name(),signature.catalog(),signature.schema(),signature.display(),signature.parameters(),signature.returns(),false);}
    private boolean hasRoutineKind(List<MetadataObject> objects,boolean procedure){for(var object:objects){budget.check();if(routineKind(object,procedure))return true;}return false;}
    private static boolean routineKind(MetadataObject object,boolean procedure){return procedure?object.identity().subtype()==ObjectSubtype.PROCEDURE:object.identity().subtype()!=ObjectSubtype.PROCEDURE;}
    private boolean routineStructureComplete(MetadataObject object){
        var identity=object.identity();
        return snapshot.complete(new io.busystack.busydata.metadata.MetadataScope(identity.catalog(),identity.schema(),"",ObjectKind.ROUTINE),io.busystack.busydata.metadata.IntrospectionLevel.STRUCTURE)
            ||snapshot.complete(new io.busystack.busydata.metadata.MetadataScope(identity.catalog(),identity.schema(),"",ObjectKind.ROUTINE,identity.name(),true,identity.signature(),identity.subtype()),io.busystack.busydata.metadata.IntrospectionLevel.STRUCTURE);
    }
    public boolean routineNamespaceComplete(Name name){
        if(!supportsObjectName(name)||!nativeRulesComplete()||context.snapshot()==null||name.parts().size()<2)return false;
        String schema=namespaceName(name.parts().get(name.parts().size()-2)),catalog=dialect.postgres()?context.catalog():schema;if(name.parts().size()>2)catalog=dialect.identifier(name.parts().getFirst());
        return !catalog.isEmpty()&&!schema.isEmpty()&&snapshot.complete(new io.busystack.busydata.metadata.MetadataScope(catalog,schema,"",ObjectKind.ROUTINE),io.busystack.busydata.metadata.IntrospectionLevel.STRUCTURE);
    }
    public Iterable<RoutineSignatures.Signature> routineCompletions(String prefix,boolean quoted,boolean procedure){
        return ()->new Iterator<>(){
            final Iterator<MetadataObject> custom=nativeObjects(ObjectKind.ROUTINE).iterator();final Set<String> shadowedBuiltins=new HashSet<>();Iterator<RoutineSignatures.Signature> builtinIterator;RoutineSignatures.Signature next;
            public boolean hasNext(){while(next==null&&custom.hasNext()){var object=custom.next();if(dialect.postgres()&&!context.rules(dialect).lookup(ObjectKind.CATALOG,object.identity().catalog(),true).equals(context.rules(dialect).lookup(ObjectKind.CATALOG,context.catalog(),true)))continue;if(!routineKind(object,procedure))continue;String name=object.identity().name();if(!startsWith(name,prefix,quoted,false))continue;String normalized=builtinKey(name);if(!procedure&&dialect.postgres()&&builtins.containsKey(normalized))shadowedBuiltins.add(normalized);next=RoutineSignatures.from(snapshot.projection(object),dialect.engine());if(!routineStructureComplete(object))next=incomplete(next);}if(next!=null)return true;if(procedure)return false;if(builtinIterator==null)builtinIterator=builtins.entrySet().stream().filter(e->!shadowedBuiltins.contains(e.getKey())).flatMap(e->e.getValue().stream()).filter(s->startsWith(s.name(),prefix,quoted,true)).iterator();if(builtinIterator.hasNext())next=builtinIterator.next();return next!=null;}
            public RoutineSignatures.Signature next(){if(!hasNext())throw new NoSuchElementException();var value=next;next=null;return value;}
        };
    }
    /** PostgreSQL exact native names and quoted tokens never undergo another fold. */
    private String builtinKey(String exactName){return dialect.postgres()?exactName:io.busystack.busydata.metadata.IdentifierRules.postgresUnquoted(exactName);}
    private boolean startsWith(String name,String prefix,boolean quoted,boolean builtin){
        if(dialect.postgres()&&quoted)return name.startsWith(prefix);
        if(dialect.postgres()||builtin)return io.busystack.busydata.metadata.IdentifierRules.postgresUnquoted(name).startsWith(io.busystack.busydata.metadata.IdentifierRules.postgresUnquoted(prefix));
        var rules=context.rules(dialect);return rules.lookup(ObjectKind.ROUTINE,name,true).startsWith(rules.lookup(ObjectKind.ROUTINE,prefix,quoted));
    }
    public boolean relationNameAmbiguous(String exactName){
        int found=0;for(var kind:List.of(ObjectKind.TABLE,ObjectKind.VIEW))for(var relation:snapshot.resolveName(kind,exactName,true)){budget.check();if(++found>1)return true;}
        return false;
    }
    /** Freshly observed names can survive retired structural evidence, but
     * must not acquire any of that retained evidence's authority. */
    public boolean incompleteName(String identity){var object=snapshot.identity(identity).orElse(null);return object!=null&&object.state()==io.busystack.busydata.metadata.MetadataState.STALE&&snapshot.nameAvailable(object);}
    private boolean staleRelation(RelationKey key){for(var kind:List.of(ObjectKind.TABLE,ObjectKind.VIEW,ObjectKind.SEQUENCE))for(var object:snapshot.resolve(key.catalog(),key.schema(),kind,"",key.name(),true))if(object.identity().name().equals(key.name())&&object.identity().sessionOwner().equals(key.sessionOwner()))return object.state()==io.busystack.busydata.metadata.MetadataState.STALE;return false;}
    public List<SchemaObject> columns(RelationKey key){
        if(staleRelation(key))return List.of();
        if(!snapshot.relationMatchesResolution(key.catalog(),key.schema(),key.name(),key.sessionOwner()))return List.of();
        if(!snapshot.scopeResolutionAvailable(new io.busystack.busydata.metadata.MetadataScope(key.catalog(),key.schema(),key.name(),ObjectKind.COLUMN)))return List.of();
        return columns.computeIfAbsent(key,k->snapshot.namespace(k.catalog(),k.schema(),ObjectKind.COLUMN,k.name()).stream().filter(o->o.identity().sessionOwner().equals(k.sessionOwner())).sorted(Comparator.comparingInt((MetadataObject o)->SqlTypes.integer(o.properties().get("ordinal"),Integer.MAX_VALUE)).thenComparing(o->o.identity().name())).map(o->{budget.check();return snapshot.projection(o);}).toList());
    }
    public boolean columnsComplete(RelationKey key){
        return !staleRelation(key)&&snapshot.relationMatchesResolution(key.catalog(),key.schema(),key.name(),key.sessionOwner())&&snapshot.complete(new io.busystack.busydata.metadata.MetadataScope(key.catalog(),key.schema(),key.name(),ObjectKind.COLUMN),io.busystack.busydata.metadata.IntrospectionLevel.STRUCTURE);
    }
    /** A later namespace is authoritative only after earlier names are known absent. */
    public boolean sessionLookupAvailable(Name name,RelationKey key){return supportsObjectName(name)&&!staleRelation(key)&&snapshot.relationLookupAvailable(key.catalog(),key.schema(),key.name(),name.parts().size()>1)&&snapshot.relationMatchesResolution(key.catalog(),key.schema(),key.name(),key.sessionOwner())&&snapshot.scopeResolutionAvailable(new io.busystack.busydata.metadata.MetadataScope(key.catalog(),key.schema(),"",ObjectKind.TABLE,key.name(),true,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED));}
    public boolean lookupComplete(Name name,RelationKey key){
        if(!sessionLookupAvailable(name,key))return false;
        if(name.parts().size()>1)return true;
        for(String schema:searchPath(true)){budget.check();if(schema.equals(key.schema()))return true;if(!context.complete())return false;for(var kind:List.of(ObjectKind.TABLE,ObjectKind.VIEW,ObjectKind.SEQUENCE))if(!snapshot.complete(new io.busystack.busydata.metadata.MetadataScope(key.catalog(),schema,"",kind),io.busystack.busydata.metadata.IntrospectionLevel.NAMES))return false;}
        return false;
    }
    public boolean namespaceComplete(Name name){
        if(!supportsObjectName(name)||!context.complete()||context.snapshot()==null)return false;
        var parts=name.parts();var rules=context.rules(dialect);String catalog=context.catalog();List<String> schemas;
        if(parts.size()>1){var token=parts.get(parts.size()-2);String schema=namespaceName(token);schemas=List.of(schema);if(!dialect.postgres())catalog=schema;}
        else schemas=searchPath(true);
        if(parts.size()>2){var token=parts.getFirst();catalog=rules.lookup(ObjectKind.CATALOG,token.identifier(),token.quoted());}
        if(catalog.isEmpty()||schemas.isEmpty()||schemas.stream().anyMatch(String::isEmpty))return false;
        for(String schema:schemas)for(var kind:List.of(ObjectKind.TABLE,ObjectKind.VIEW,ObjectKind.SEQUENCE))if(!snapshot.complete(new io.busystack.busydata.metadata.MetadataScope(catalog,schema,"",kind),io.busystack.busydata.metadata.IntrospectionLevel.NAMES))return false;
        return true;
    }
    public SchemaObject relation(RelationKey key){
        return relations.computeIfAbsent(key,k->{for(var kind:List.of(ObjectKind.TABLE,ObjectKind.VIEW,ObjectKind.SEQUENCE))for(var object:snapshot.resolve(k.catalog(),k.schema(),kind,"",k.name(),true))if(object.identity().sessionOwner().equals(k.sessionOwner()))return snapshot.projection(object);return null;});
    }
    public List<RelationKey> resolve(Name name){
        if(!supportsObjectName(name))return List.of();
        var last=name.parts().getLast();var found=new ArrayList<RelationKey>();
        // Binding an exact name uses the same immutable namespace/name indexes
        // as other metadata readers, including physical-owner compositions.
        for(var kind:List.of(ObjectKind.TABLE,ObjectKind.VIEW,ObjectKind.SEQUENCE))for(var object:snapshot.resolveName(kind,last.identifier(),last.quoted())){
            budget.check();if(!visibleObject(object))continue;var i=object.identity();found.add(new RelationKey(i.catalog(),i.schema(),i.name(),i.sessionOwner()));
        }
        return visible(name,found,k->"true".equalsIgnoreCase(relation(k).getPropertiesOrDefault("temporary","false")));
    }
    private List<RelationKey> visible(Name name,List<RelationKey> candidates,java.util.function.Predicate<RelationKey> temporary){
        if(!supportsObjectName(name))return List.of();
        var rules=context.rules(dialect);var parts=name.parts();
        if(parts.size()>1){var part=parts.get(parts.size()-2);String schema=namespaceName(part);candidates=candidates.stream().filter(k->rules.lookup(ObjectKind.SCHEMA,k.schema(),true).equals(schema)||!dialect.postgres()&&rules.lookup(ObjectKind.CATALOG,k.catalog(),true).equals(schema)).toList();}
        if(parts.size()>2){var part=parts.getFirst();String catalog=rules.lookup(ObjectKind.CATALOG,part.identifier(),part.quoted());candidates=candidates.stream().filter(k->rules.lookup(ObjectKind.CATALOG,k.catalog(),true).equals(catalog)).toList();}
        if(parts.size()==1&&!context.catalog().isEmpty())candidates=candidates.stream().filter(k->k.catalog().isEmpty()||rules.lookup(ObjectKind.CATALOG,k.catalog(),true).equals(rules.lookup(ObjectKind.CATALOG,context.catalog(),true))).toList();
        if(parts.size()==1&&!dialect.postgres()){var temporaryMatches=candidates.stream().filter(k->!k.sessionOwner().isEmpty()&&temporary.test(k)).toList();if(!temporaryMatches.isEmpty())return temporaryMatches;}
        if(parts.size()==1&&!searchPath(true).isEmpty()){
            for(String schema:searchPath(true)){var scoped=candidates.stream().filter(k->rules.lookup(ObjectKind.SCHEMA,k.schema(),true).equals(rules.lookup(ObjectKind.SCHEMA,schema,true))).toList();if(!scoped.isEmpty())return scoped;}
            return List.of();
        }
        if(parts.size()==1&&!context.schema().isEmpty())return candidates.stream().filter(k->rules.lookup(ObjectKind.SCHEMA,k.schema(),true).equals(rules.lookup(ObjectKind.SCHEMA,context.schema(),true))).toList();
        return candidates;
    }
    public record SymbolMatches(List<SchemaObject> objects,boolean caseChoice,boolean complete,boolean limited){public SymbolMatches{objects=List.copyOf(objects);}}
    /** Navigation consumes the identical namespace/temp precedence as binding.
     * Case-only alternatives are explicit choices, never successful bindings. */
    private record RankedSymbol(MetadataObject object,RelationKey key,int priority){}
    public SymbolMatches resolveSymbols(Name name){
        if(!supportsObjectName(name)||context.snapshot()==null)return new SymbolMatches(List.of(),false,false,false);
        var parts=name.parts();var rules=context.rules(dialect);var token=name.last();
        if(parts.size()==1&&searchPath(true).size()>32)return new SymbolMatches(List.of(),false,false,true);
        if(parts.size()==1&&(context.catalog().isEmpty()||context.searchPath().isEmpty()&&context.schema().isEmpty()))return new SymbolMatches(List.of(),false,false,false);
        var ordering=Comparator.comparingInt(RankedSymbol::priority).thenComparing(v->v.key().catalog()).thenComparing(v->v.key().schema()).thenComparing(v->v.key().name()).thenComparing(v->v.key().sessionOwner()).thenComparing(v->v.object().identity().kind().name()).thenComparing(v->v.object().identity().nativeKey());
        var exact=new PriorityQueue<RankedSymbol>(33,ordering.reversed());var alternatives=new PriorityQueue<RankedSymbol>(33,ordering.reversed());
        String lookup=rules.lookup(ObjectKind.TABLE,token.identifier(),token.quoted());
        for(var object:nativeObjects(ObjectKind.TABLE,ObjectKind.VIEW,ObjectKind.SEQUENCE)){
            boolean match=object.lookupKey().equals(lookup),suggestion=!dialect.postgres()&&rules.complete()&&rules.matches(ObjectKind.COLUMN,object.identity().name(),token.identifier(),token.quoted());
            if(!match&&!suggestion)continue;
            var i=object.identity();var key=new RelationKey(i.catalog(),i.schema(),i.name(),i.sessionOwner());
            boolean temporary="true".equalsIgnoreCase(object.properties().getOrDefault("temporary","false"));
            // Reuse binding's authoritative visibility check before admitting
            // even an object reference; unrelated namespaces are not projected.
            if(visible(name,List.of(key),ignored->temporary).isEmpty())continue;
            int priority=1;
            if(parts.size()==1){
                if(!dialect.postgres()&&!key.sessionOwner().isEmpty()&&temporary)priority=0;
                else for(int index=0;index<searchPath(true).size();index++)if(rules.lookup(ObjectKind.SCHEMA,key.schema(),true).equals(rules.lookup(ObjectKind.SCHEMA,searchPath(true).get(index),true))){priority=index+1;break;}
            }
            var ranked=new RankedSymbol(object,key,priority);var best=match?exact:alternatives;
            if(best.size()<33)best.add(ranked);else if(ordering.compare(ranked,best.peek())<0){best.remove();best.add(ranked);}
        }
        boolean caseChoice=exact.isEmpty()&&!alternatives.isEmpty();var best=new ArrayList<>(caseChoice?alternatives:exact);best.sort(ordering);
        var temporaryByKey=new HashMap<RelationKey,Boolean>();for(var ranked:best)temporaryByKey.merge(ranked.key(),"true".equalsIgnoreCase(ranked.object().properties().getOrDefault("temporary","false")),(left,right)->left||right);
        var selected=visible(name,best.stream().map(RankedSymbol::key).toList(),k->temporaryByKey.getOrDefault(k,false));
        if(selected.size()>32)return new SymbolMatches(List.of(),false,false,true);
        var selectedKeys=new HashSet<>(selected);
        boolean complete=nativeRulesComplete()&&(caseChoice||selected.isEmpty()?symbolNamesComplete(name):selected.stream().allMatch(key->lookupComplete(name,key)));
        return new SymbolMatches(best.stream().filter(v->selectedKeys.contains(v.key())).map(v->snapshot.projection(v.object())).toList(),caseChoice,complete,false);
    }

    private boolean symbolNamesComplete(Name name){
        if(!supportsObjectName(name)||!nativeRulesComplete())return false;
        var parts=name.parts();var rules=context.rules(dialect);String catalog=context.catalog();List<String> schemas;
        if(parts.size()>1){var token=parts.get(parts.size()-2);String schema=namespaceName(token);schemas=List.of(schema);if(!dialect.postgres())catalog=schema;}
        else schemas=searchPath(true);
        if(parts.size()>2){var token=parts.getFirst();catalog=rules.lookup(ObjectKind.CATALOG,token.identifier(),token.quoted());}
        if(catalog.isEmpty()||schemas.isEmpty()||schemas.stream().anyMatch(String::isEmpty))return false;
        for(String schema:schemas){if(!snapshot.relationLookupAvailable(catalog,schema,name.last().identifier(),parts.size()>1))return false;for(var kind:List.of(ObjectKind.TABLE,ObjectKind.VIEW,ObjectKind.SEQUENCE))if(!snapshot.complete(new io.busystack.busydata.metadata.MetadataScope(catalog,schema,"",kind),io.busystack.busydata.metadata.IntrospectionLevel.NAMES))return false;}
        return true;
    }

    private boolean visibleObject(MetadataObject object){
        if(object.identity().kind()==ObjectKind.FOREIGN_KEY&&!snapshot.relationshipComplete(object))return false;
        return object.state()==io.busystack.busydata.metadata.MetadataState.AVAILABLE||object.state()==io.busystack.busydata.metadata.MetadataState.PARTIAL||object.state()==io.busystack.busydata.metadata.MetadataState.STALE&&snapshot.nameAvailable(object);
    }
    private Iterable<MetadataObject> nativeObjects(ObjectKind... kinds){
        var accepted=Set.of(kinds);return ()->new Iterator<>(){
            final Iterator<ObjectKind> kinds=accepted.iterator();Iterator<MetadataObject> source=Collections.emptyIterator();MetadataObject next;int inspected;
            public boolean hasNext(){while(next==null){while(!source.hasNext()){if(!kinds.hasNext())return false;source=snapshot.kind(kinds.next()).iterator();}if((inspected++&1023)==0)budget.check();var object=source.next();if(visibleObject(object))next=object;}return true;}
            public MetadataObject next(){if(!hasNext())throw new NoSuchElementException();var object=next;next=null;return object;}
        };
    }
    private Collection<SchemaObject> projected(ObjectKind... kinds){return new AbstractCollection<>(){
        public Iterator<SchemaObject> iterator(){var source=nativeObjects(kinds).iterator();return new Iterator<>(){public boolean hasNext(){return source.hasNext();}public SchemaObject next(){return snapshot.projection(source.next());}};}
        public int size(){int count=0;for(var ignored:nativeObjects(kinds))count++;return count;}
    };}
    public static String identity(SchemaObject object){if(object.getStableIdentity().isEmpty())throw new IllegalArgumentException("Central metadata identity is required");return object.getStableIdentity();}
}
