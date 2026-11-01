package io.busystack.busydata.analysis.language;

import io.busystack.busydata.protocol.*;
import java.util.*;
import io.busystack.busydata.analysis.language.LosslessLexer.*;
import io.busystack.busydata.analysis.language.SyntaxTree.*;
import static io.busystack.busydata.analysis.language.SyntaxTree.*;

/** Deterministic syntax-context completion over bound symbols, never live catalogs. */
public final class CompletionService {
    public record Batch(List<Completion> items,boolean limited,boolean metadataIncomplete){public Batch(List<Completion> items,boolean limited){this(items,limited,false);}public Batch {items=List.copyOf(items);}}
    private record Candidate(String label,String insertion,String kind,String detail,String target,int rank,boolean qualified,boolean quoted,String normalizedLabel,SchemaObject qualifyObject,SemanticBinder.ColumnSymbol qualifyColumn){
        Candidate(String label,String insertion,String kind,String detail,String target,int rank,boolean qualified,boolean quoted){this(label,insertion,kind,detail,target,rank,qualified,quoted,io.busystack.busydata.metadata.IdentifierRules.postgresUnquoted(label),null,null);}
    }
    private static final Comparator<Candidate> ORDER=Comparator.comparingInt(Candidate::rank).thenComparing(Candidate::normalizedLabel).thenComparing(Candidate::label).thenComparing(Candidate::detail).thenComparing(Candidate::target);
    /** Best 201 unique matching items: one sentinel proves the 200-item limit. */
    private final class Candidates {
        private record Key(String kind,String insertion,String detail){}
        private final PriorityQueue<Candidate> worst=new PriorityQueue<>(201,ORDER.reversed());private final Map<Key,Candidate> unique=new HashMap<>();private final Replacement replacement;private boolean limited;
        Candidates(Replacement replacement){this.replacement=replacement;}
        boolean accepts(String label,String kind,String target){budget.check();return key(label,kind,target).startsWith(key(replacement.prefix(),kind,target));}
        private String key(String label,String kind,String target){
            if(dialect.postgres())return replacement.quoted()?label:io.busystack.busydata.metadata.IdentifierRules.postgresUnquoted(label);
            if(target.startsWith("builtin:")||target.startsWith("type:")||Set.of("keyword","snippet","join").contains(kind))return io.busystack.busydata.metadata.IdentifierRules.postgresUnquoted(label);
            var rules=binder.catalog().context().rules(dialect);
            return switch(kind){
                case "column"->rules.lookup(ObjectKind.COLUMN,label,true);
                case "table"->rules.lookup(ObjectKind.TABLE,label,true);
                case "view"->rules.lookup(ObjectKind.VIEW,label,true);
                case "sequence"->rules.lookup(ObjectKind.SEQUENCE,label,true);
                case "catalog"->rules.lookup(ObjectKind.CATALOG,label,true);
                case "schema"->rules.lookup(ObjectKind.SCHEMA,label,true);
                case "function","procedure"->rules.lookup(ObjectKind.ROUTINE,label,true);
                case "cte"->binder.cteKey(label,true);
                case "alias","field-list"->rules.alias(label,true);
                default->rules.lookup(ObjectKind.TYPE,label,true);
            };
        }
        void add(Candidate candidate){
            budget.check();if(!accepts(candidate.label(),candidate.kind(),candidate.target()))return;
            var key=new Key(candidate.kind(),candidate.insertion(),candidate.detail());var previous=unique.get(key);
            if(previous!=null){if(ORDER.compare(candidate,previous)>=0)return;worst.remove(previous);unique.remove(key);}
            if(worst.size()>=201){var last=worst.peek();if(ORDER.compare(candidate,last)>=0)return;worst.remove();unique.remove(new Key(last.kind(),last.insertion(),last.detail()));}
            unique.put(key,candidate);worst.add(candidate);
        }
        List<Candidate> sorted(){var result=new ArrayList<>(worst);result.sort(ORDER);return result;}
    }
    private record Replacement(int start,int end,String prefix,boolean quoted,Token previous,Token qualifier){}
    private final SemanticBinder binder;private final SyntaxTree tree;private final Dialect dialect;private final AnalysisBudget budget;
    public CompletionService(SemanticBinder binder,AnalysisBudget budget){this.binder=binder;this.tree=binder.tree();this.dialect=tree.document().dialect();this.budget=budget;}
    public List<Completion> complete(int caret){return completeBatch(caret,Map.of()).items();}
    public Batch completeBatch(int caret,Map<String,String> snippets){
        SnippetCatalog.validate(snippets);
        if(caret<0||caret>tree.document().source().length())throw new IllegalArgumentException("Invalid UTF-16 completion caret");
        if(tree.document().protectedAt(caret)!=null)return new Batch(List.of(),false);
        var replacement=replacement(caret);var query=tree.at(caret);if(query==null||query.opaque())return new Batch(List.of(),false);
        var candidates=new Candidates(replacement);var catalog=binder.catalog();var visible=binder.visible(query);var clause=query.clauseAt(caret);
        String context=clause==null?query.kind():clause.name();boolean procedure=procedureTarget(query,caret);
        if(replacement.previous()!=null&&replacement.previous().is(".")&&replacement.qualifier()!=null){
            String qualifier=binder.aliasKey(replacement.qualifier());
            var relations=visible.stream().filter(r->r.syntax().visibleName()!=null&&binder.aliasKey(r.syntax().visibleName()).equals(qualifier)).toList();
            if(!relations.isEmpty())for(var relation:relations)for(var column:relation.columns())column(candidates,column,false,0);
            else {
                String namespace=catalog.namespaceName(replacement.qualifier());var rules=catalog.context().rules(dialect);
                if(procedure){
                    for(var signature:catalog.routineCompletions(replacement.prefix(),replacement.quoted(),true)){budget.check();if(rules.lookup(ObjectKind.SCHEMA,signature.schema(),true).equals(namespace)||!dialect.postgres()&&rules.lookup(ObjectKind.CATALOG,signature.catalog(),true).equals(namespace))routine(candidates,signature,false,true,catalog);}
                }else{
                    for(var signature:catalog.routineCompletions(replacement.prefix(),replacement.quoted(),false)){budget.check();if(rules.lookup(ObjectKind.SCHEMA,signature.schema(),true).equals(namespace)||!dialect.postgres()&&rules.lookup(ObjectKind.CATALOG,signature.catalog(),true).equals(namespace))routine(candidates,signature,false,false,catalog);}
                    for(var object:catalog.relations()){budget.check();if(rules.lookup(ObjectKind.SCHEMA,object.getSchema(),true).equals(namespace)||!dialect.postgres()&&rules.lookup(ObjectKind.CATALOG,object.getCatalog(),true).equals(namespace))relation(candidates,object,false,20);}
                    for(var namespaceObject:catalog.namespaces())if(rules.matches(ObjectKind.CATALOG,namespaceObject.getCatalog(),replacement.qualifier().identifier(),replacement.qualifier().quoted()))object(candidates,namespaceObject,"schema",false,25);
                }
            }
        }else{
            boolean insertColumns=query.kind().equals("INSERT")&&insideInsertColumns(query,caret);
            boolean sources=!insertColumns&&(Set.of("FROM","JOIN","INTO","UPDATE").contains(context)||replacement.previous()!=null&&(replacement.previous().is("FROM")||replacement.previous().is("JOIN")||replacement.previous().is("INTO")));
            boolean typeContext=replacement.previous()!=null&&(replacement.previous().is("::")||replacement.previous().is("CAST")||replacement.previous().is("RETURNS")||replacement.previous().is("AS")&&insideCast(caret));
            if(typeContext){for(String type:dialect.types())candidates.add(new Candidate(type,type,"type",type,"type:"+dialect.engine()+":"+type,0,false,false));for(var type:catalog.types())object(candidates,type,"type",!type.getSchema().equals(catalog.context().schema()),5);}
            else if(sources){
                for(var cte:binder.visibleCtes(query)){String name=dialect.identifier(cte.name());candidates.add(new Candidate(name,dialect.insertion(name),"cte","WITH", "cte:"+query.id()+":"+cte.name().start(),0,false,!dialect.insertion(name).equals(name)));}
                for(var relation:catalog.relations()){budget.check();boolean qualified=!catalog.context().schema().isEmpty()&&!catalog.context().schema().equals(relation.getSchema());relation(candidates,relation,qualified,relation.getSchema().equals(catalog.context().schema())?10:20,true);}
                for(var namespace:catalog.namespaces())object(candidates,namespace,namespace.getKind()==ObjectKind.CATALOG?"catalog":"schema",false,30);
            }else{
                boolean targetOnly=insertColumns||query.kind().equals("UPDATE")&&context.equals("SET")&&assignmentTarget(clause,caret);
                var unqualified=targetOnly?List.<SemanticBinder.ColumnSymbol>of():binder.completionColumns(query);
                for(var column:unqualified)column(candidates,column,false,0,true);
                var unqualifiedIds=new HashSet<String>();for(var column:unqualified)unqualifiedIds.add(column.identity());
                for(var relation:visible){
                    if(targetOnly&&!relation.syntax().target())continue;
                    if(targetOnly)for(var column:relation.columns())column(candidates,column,false,0);
                    else for(var column:relation.columns())if(!unqualifiedIds.contains(column.identity()))column(candidates,column,true,20);
                    if(!targetOnly&&!relation.alias().isEmpty())candidates.add(new Candidate(relation.alias(),dialect.insertion(relation.alias()),"alias",relation.key()==null?"query":relation.key().schema()+"."+relation.key().name(),"alias:"+query.id()+":"+relation.syntax().start(),10,false,!dialect.insertion(relation.alias()).equals(relation.alias())));
                }
                if(!targetOnly){
                    if(Set.of("ORDER","GROUP","HAVING").contains(context)&&!(dialect.postgres()&&context.equals("HAVING")))for(var projection:query.projections())if(projection.alias()!=null){String name=dialect.identifier(projection.alias());candidates.add(new Candidate(name,dialect.insertion(name),"column","SELECT", "output:"+query.id()+":"+projection.alias().start(),5,false,!dialect.insertion(name).equals(name)));}
                    for(var signature:catalog.routineCompletions(replacement.prefix(),replacement.quoted(),procedure)){budget.check();routine(candidates,signature,!signature.schema().isEmpty(),procedure,catalog);}
                    if(context.equals("SELECT")||context.equals("RETURNING"))for(var relation:visible)if(!relation.columns().isEmpty()&&relation.complete()){
                        String label=relation.alias()+".*";if(!candidates.accepts(label,"field-list",""))continue;var text=new StringBuilder();String qualifier=dialect.insertion(relation.alias());boolean bounded=true;
                        for(var column:relation.columns()){budget.check();String name=dialect.insertion(column.name());if(text.length()+qualifier.length()+name.length()+1+(text.length()==0?0:2)>32768){bounded=false;break;}if(text.length()>0)text.append(", ");text.append(qualifier).append('.').append(name);}
                        if(bounded)candidates.add(new Candidate(label,text.toString(),"field-list",relation.alias(),"fields:"+query.id()+":"+relation.syntax().start(),15,false,false));else candidates.limited=true;
                    }
                    if(context.equals("ON"))joins(candidates,visible);
                    // Names are useful in an empty/incomplete SELECT before its FROM exists.
                    if(!procedure&&visible.isEmpty())for(var relation:catalog.relations())relation(candidates,relation,false,50);
                }
            }
            if(!procedure)for(String keyword:keywords(context,query.kind()))candidates.add(new Candidate(keyword,keyword,"keyword",dialect.engine().name(),"keyword:"+keyword,80,false,false));
        }
        if(snippetContext(caret,replacement))for(var snippet:snippets.entrySet())candidates.add(new Candidate(snippet.getKey(),snippet.getValue(),"snippet",dialect.engine().name(),"snippet:"+snippet.getKey(),60,false,false));
        budget.check();var out=new ArrayList<Completion>();
        int bytes=0;boolean limited=candidates.limited,incompleteNames=false;for(var selected:candidates.sorted()){
            budget.check();var candidate=selected;
            if(candidate.qualifyObject()!=null&&!candidate.qualified()&&catalog.relationNameAmbiguous(candidate.label())){var object=candidate.qualifyObject();candidate=new Candidate(candidate.label(),object.getSchema().isEmpty()?candidate.insertion():dialect.insertion(object.getSchema())+"."+dialect.insertion(object.getName()),candidate.kind(),candidate.detail(),candidate.target(),candidate.rank(),true,candidate.quoted());}
            if(candidate.qualifyColumn()!=null&&binder.ambiguousColumn(query,candidate.label())){var column=candidate.qualifyColumn();candidate=new Candidate(candidate.label(),dialect.insertion(column.qualifier())+"."+dialect.insertion(column.name()),candidate.kind(),candidate.detail(),candidate.target(),candidate.rank(),true,candidate.quoted());}
            var completion=Completion.newBuilder().setLabel(candidate.label()).setInsertText(candidate.insertion()).setKind(candidate.kind()).setStartUtf16(replacement.start()).setEndUtf16(replacement.end()).setDetail(candidate.detail()).setTargetIdentity(candidate.target()).setRank(candidate.rank()).setQualificationRequired(candidate.qualified()).setQuoted(candidate.quoted());
            if(Set.of("column","table","schema","catalog","alias","cte").contains(candidate.kind()))completion.addCommitCharacters(".");
            var built=completion.build();if(out.size()>=200||bytes+built.getSerializedSize()>262144){limited=true;break;}bytes+=built.getSerializedSize();out.add(built);if(Set.of("table","view","sequence").contains(candidate.kind())&&catalog.incompleteName(candidate.target()))incompleteNames=true;
        }
        return new Batch(out,limited,incompleteNames||!catalog.nativeRulesComplete()||visible.stream().anyMatch(relation->!relation.complete())||context.equals("ON")&&visible.stream().anyMatch(relation->relation.key()!=null&&!catalog.relationshipsComplete(relation.key())));
    }
    private boolean procedureTarget(Query query,int caret){
        if(!query.kind().equals("CALL"))return false;
        for(var element:query.elements())if(element instanceof Group group&&group.open().is("("))return caret<=group.open().start();
        return true;
    }
    private void routine(Candidates out,RoutineSignatures.Signature signature,boolean qualified,boolean procedure,SemanticCatalog catalog){
        String name=dialect.insertion(signature.name());String insertion=(qualified?dialect.insertion(signature.schema())+".":"")+name+"()";
        out.add(new Candidate(signature.name()+"()",insertion,procedure?"procedure":"function",(signature.schema().isEmpty()?"":signature.schema()+" · ")+signature.display(),signature.identity(),signature.schema().equals(catalog.context().schema())?25:30,qualified,!name.equals(signature.name())));
    }
    private boolean snippetContext(int caret,Replacement replacement){
        if(replacement.quoted()||replacement.previous()!=null&&replacement.previous().is("."))return false;
        var before=new ArrayList<Token>();int depth=0;
        for(var token:tree.document().significant()){
            if(token.start()>=replacement.start()||token.start()>=caret)break;
            if(token.is("(")||token.is("["))depth++;else if(token.is(")")||token.is("]"))depth=Math.max(0,depth-1);
            if(token.is(";")&&depth==0)before.clear();else before.add(token);
        }
        return before.isEmpty()&&depth==0;
    }
    private Replacement replacement(int caret){
        var tokens=tree.document().significant();Token word=null,previous=null,qualifier=null;
        for(int i=0;i<tokens.size();i++){
            var token=tokens.get(i);if(token.name()&&caret>=token.start()&&caret<=token.end()){word=token;previous=i>0?tokens.get(i-1):null;qualifier=i>1?tokens.get(i-2):null;break;}
            if(token.end()<=caret){qualifier=previous;previous=token;}
        }
        int start=word==null?caret:word.start(),end=word==null?caret:word.end();String prefix="";
        if(word!=null){
            prefix=word.text().substring(0,Math.max(0,caret-word.start()));
            if(word.quoted()&&!prefix.isEmpty()){char quote=word.text().charAt(0);prefix=prefix.substring(1);if(word.complete()&&caret==word.end()&&!prefix.isEmpty())prefix=prefix.substring(0,prefix.length()-1);prefix=prefix.replace(""+quote+quote,""+quote);}
        }
        return new Replacement(start,end,prefix,word!=null&&word.quoted(),previous,qualifier);
    }
    private void column(Candidates out,SemanticBinder.ColumnSymbol column,boolean qualified,int rank){column(out,column,qualified,rank,false);}
    private void column(Candidates out,SemanticBinder.ColumnSymbol column,boolean qualified,int rank,boolean qualifyDuplicates){if(!out.accepts(column.name(),"column",column.identity()))return;String name=dialect.insertion(column.name());String insert=qualified?dialect.insertion(column.qualifier())+"."+name:name;out.add(new Candidate(column.name(),insert,"column",(column.qualifier().isEmpty()?"":column.qualifier()+" · ")+column.type().nativeName(),column.identity(),rank,qualified,!name.equals(column.name()),io.busystack.busydata.metadata.IdentifierRules.postgresUnquoted(column.name()),null,qualifyDuplicates?column:null));}
    private void relation(Candidates out,SchemaObject object,boolean qualified,int rank){relation(out,object,qualified,rank,false);}
    private void relation(Candidates out,SchemaObject object,boolean qualified,int rank,boolean qualifyDuplicates){object(out,object,object.getKind()==ObjectKind.VIEW?"view":object.getKind()==ObjectKind.SEQUENCE?"sequence":"table",qualified,rank,qualifyDuplicates);}
    private void object(Candidates out,SchemaObject object,String kind,boolean qualified,int rank){object(out,object,kind,qualified,rank,false);}
    private void object(Candidates out,SchemaObject object,String kind,boolean qualified,int rank,boolean qualifyDuplicates){if(!out.accepts(object.getName(),kind,SemanticCatalog.identity(object)))return;String name=dialect.insertion(object.getName());String insert=qualified&&!object.getSchema().isEmpty()?dialect.insertion(object.getSchema())+"."+name:name;out.add(new Candidate(object.getName(),insert,kind,String.join(".",List.of(object.getCatalog(),object.getSchema()).stream().filter(s->!s.isEmpty()).toList()),SemanticCatalog.identity(object),rank,qualified,!name.equals(object.getName()),io.busystack.busydata.metadata.IdentifierRules.postgresUnquoted(object.getName()),qualifyDuplicates?object:null,null));}
    private boolean insideInsertColumns(Query query,int caret){
        var target=query.relations().stream().filter(Relation::target).findFirst().orElse(null);if(target==null)return false;
        for(var element:query.elements()){
            if(element.end()<=target.end())continue;
            if(element instanceof Leaf leaf&&Set.of("VALUES","SELECT","SET","DEFAULT").contains(leaf.token().text().toUpperCase(Locale.ROOT)))return false;
            if(element instanceof Group group)return caret>group.start()&&caret<group.end();
        }return false;
    }
    private static boolean assignmentTarget(Clause clause,int caret){if(clause==null)return true;boolean target=true;for(var e:clause.elements()){if(e.start()>=caret)break;if(is(e,"="))target=false;if(is(e,","))target=true;}return target;}
    private boolean insideCast(int caret){var stack=new ArrayDeque<String>();Token previous=null;for(var token:tree.document().significant()){if(token.start()>=caret)break;if(token.is("("))stack.push(previous==null?"":previous.text().toUpperCase(Locale.ROOT));else if(token.is(")")&&!stack.isEmpty())stack.pop();previous=token;}return !stack.isEmpty()&&stack.peek().equals("CAST");}
    private List<String> keywords(String context,String kind){
        var result=new ArrayList<>(switch(context){case "FROM","JOIN"->List.of("JOIN","LEFT JOIN","INNER JOIN","WHERE","GROUP BY","ORDER BY");case "WHERE","ON","HAVING"->List.of("AND","OR","NOT","IS NULL","IN","EXISTS","GROUP BY","ORDER BY","LIMIT");case "SELECT","RETURNING"->List.of("FROM","AS","DISTINCT","CASE","NULL","CAST");case "SET"->List.of("DEFAULT","NULL","WHERE");case "VALUES"->List.of("DEFAULT","NULL");case "GROUP","ORDER"->List.of("BY","ASC","DESC");default->List.of("SELECT","INSERT","UPDATE","DELETE","WITH","CREATE","ALTER","DROP");});
        if(kind.equals("INSERT"))result.add(dialect.postgres()?"ON CONFLICT":"ON DUPLICATE KEY UPDATE");
        if(dialect.returning(kind)&&Set.of("INSERT","UPDATE","DELETE").contains(kind))result.add("RETURNING");return result;
    }
    private void joins(Candidates out,List<SemanticBinder.RelationSymbol> visible){
        for(var fk:binder.catalog().relationships()){
            budget.check();
            var p=fk.getPropertiesMap();if(!p.getOrDefault("relationshipVerified","false").equals("true"))continue;int count=SqlTypes.integer(p.get("columnCount"),0);if(count<1||count>128)continue;
            for(var source:visible)for(var target:visible){
                budget.check();
                if(source==target||source.key()==null||target.key()==null||!source.key().sessionOwner().isEmpty()||!target.key().sessionOwner().isEmpty()||!source.complete()||!target.complete())continue;
                if(!source.key().name().equals(fk.getTable())||!source.key().schema().equals(fk.getSchema())||!source.key().catalog().equals(fk.getCatalog())||!target.key().name().equals(p.get("referencedTable"))||!target.key().schema().equals(p.get("referencedSchema"))||!p.getOrDefault("referencedCatalog",target.key().catalog()).equals(target.key().catalog()))continue;
                var predicates=new StringBuilder();boolean verified=true;
                for(int i=0;i<count;i++){budget.check();String column=p.get("column."+i),reference=p.get("referencedColumn."+i);if(column==null||reference==null||source.columns().stream().noneMatch(c->c.name().equals(column))||target.columns().stream().noneMatch(c->c.name().equals(reference))){verified=false;break;}String predicate=dialect.insertion(source.alias())+"."+dialect.insertion(column)+" = "+dialect.insertion(target.alias())+"."+dialect.insertion(reference);if(predicates.length()+predicate.length()+(predicates.length()==0?0:5)>131072){out.limited=true;verified=false;break;}if(predicates.length()>0)predicates.append(" AND ");predicates.append(predicate);}
                if(verified){String insertion=predicates.toString();out.add(new Candidate(insertion,insertion,"join",fk.getName(),SemanticCatalog.identity(fk),0,false,false));}
            }
        }
    }
}
