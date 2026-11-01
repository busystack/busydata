package io.busystack.busydata.analysis.language;

import java.util.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.analysis.language.LosslessLexer.*;
import io.busystack.busydata.analysis.language.SyntaxTree.*;
import static io.busystack.busydata.analysis.language.SyntaxTree.*;

/** Binds query declarations and references to exact, revision-captured metadata. */
public final class SemanticBinder {
    public record ColumnSymbol(String name,SqlTypes.Type type,String identity,String qualifier,SchemaObject object){}
    public record RelationSymbol(Relation syntax,String alias,List<ColumnSymbol> columns,SemanticCatalog.RelationKey key,boolean complete) {public RelationSymbol {columns=List.copyOf(columns);}}
    private final SyntaxTree tree;private final SemanticCatalog catalog;private final Dialect dialect;private final AnalysisBudget budget;
    private final Map<Integer,List<RelationSymbol>> bound=new HashMap<>();private final Map<Integer,QueryOutputs.Shape> outputs=new HashMap<>();private final Set<Integer> resolving=new HashSet<>(),projecting=new HashSet<>();
    private final Map<Integer,Cte> cteDeclarations=new HashMap<>();private final Map<Integer,QueryOutputs.Shape> cteOutputs=new HashMap<>();private final Map<Integer,Boolean> recursionFacts=new HashMap<>();private final Set<Integer> buildingCtes=new HashSet<>(),recursiveCtes=new HashSet<>();
    private final Map<String,LanguageIssue> outputIssues=new LinkedHashMap<>();
    private final Map<Integer,JoinedNamespace.Output> namespaces=new HashMap<>();
    private final Map<Integer,JoinedNamespace.Output> conditionScopes=new HashMap<>();
    private final Map<String,LanguageIssue> joinIssues=new LinkedHashMap<>();
    private int expressionDepth;
    public record ColumnLookup(List<ColumnSymbol> candidates,boolean complete) {public ColumnLookup {candidates=List.copyOf(candidates);}}
    private record ScopeFrame(Query query,int before) {}
    public SemanticBinder(SyntaxTree tree,SemanticCatalog catalog,AnalysisBudget budget){this.tree=tree;this.catalog=catalog;this.dialect=tree.document().dialect();this.budget=budget;for(var query:tree.queries())for(var cte:query.ctes())cteDeclarations.put(cte.query(),cte);}
    public SyntaxTree tree(){return tree;}public SemanticCatalog catalog(){return catalog;}
    public String aliasKey(Token token){return catalog.context().rules(dialect).alias(token.identifier(),token.quoted());}
    private boolean rulesComplete(){return catalog.nativeRulesComplete();}
    private String columnKey(Token token){return catalog.context().rules(dialect).lookup(ObjectKind.COLUMN,token.identifier(),token.quoted());}
    private boolean columnMatches(String exact,Token token){return dialect.columnMatches(exact,token,catalog.context().rules(dialect));}
    // MySQL's CTE constructor applies conditional filename LOWER then memcmp;
    // MariaDB Lex_ident_with_element uses unconditional identifier comparison.
    private String cteKey(Token token){return cteKey(token.identifier(),token.quoted());}
    private String cteKey(String exact){return cteKey(exact,true);}
    public String cteKey(String name,boolean quoted){var rules=catalog.context().rules(dialect);return dialect.engine()==Engine.MARIADB?rules.lookup(ObjectKind.COLUMN,name,quoted):rules.alias(name,quoted);}
    private String aliasKey(RelationSymbol relation){return relation.syntax().visibleName()==null?relation.alias():aliasKey(relation.syntax().visibleName());}
    private List<RelationSymbol> physical(Query query){
        var cached=bound.get(query.id());if(cached!=null)return cached;
        if(!resolving.add(query.id()))return List.of();
        if(resolving.size()>32)throw new AnalysisBudget.Limit("Semantic projection nesting exceeds 32 levels");
        try{
            budget.check();var result=new ArrayList<RelationSymbol>();
            for(var relation:query.relations()){
                Token visible=relation.visibleName();String alias=visible==null?"":dialect.identifier(visible);var columns=new ArrayList<ColumnSymbol>();SemanticCatalog.RelationKey key=null;boolean complete=false;
                if(relation.derivedQuery()!=null){var derived=tree.query(relation.derivedQuery());var shape=QueryOutputs.referenced(QueryOutputs.defaults(projection(derived),dialect),derived,dialect,false);shape=QueryOutputs.aliases(shape,relation.outputAliases(),dialect,!dialect.postgres(),relation.start(),relation.end(),this::outputIssue);columns.addAll(shape.symbols(alias));complete=shape.namesComplete();if(shape.complete()&&!complete)outputIssue(LanguageIssue.unavailable(relation.start(),relation.end(),"Generated output column names are unavailable; use explicit output column aliases"));}
                else if(relation.name()!=null){
                    var cte=relation.name().parts().size()==1?findCte(query,dialect.identifier(relation.name().last())):null;
                    if(cte!=null){
                        var shape=cteProjection(cte);columns.addAll(shape.symbols(alias));complete=shape.namesComplete();
                    }else{
                        var candidates=catalog.resolve(relation.name());if(candidates.size()==1){key=candidates.getFirst();if(catalog.sessionLookupAvailable(relation.name(),key))for(var column:catalog.columns(key))columns.add(new ColumnSymbol(column.getName(),SqlTypes.column(column,dialect.engine()),SemanticCatalog.identity(column),alias,column));complete=catalog.columnsComplete(key)&&catalog.lookupComplete(relation.name(),key);}
                    }
                }
                var renamed=new ArrayList<ColumnSymbol>();for(int i=0;i<columns.size();i++){var column=columns.get(i);String name=relation.derivedQuery()==null&&i<relation.outputAliases().size()&&!relation.target()?dialect.identifier(relation.outputAliases().get(i)):column.name();renamed.add(new ColumnSymbol(name,column.type(),column.identity(),alias,column.object()));}
                result.add(new RelationSymbol(relation,alias,renamed,key,complete&&rulesComplete()));
                // LATERAL children can read already bound preceding sources while this block is being bound.
                bound.put(query.id(),List.copyOf(result));
            }
            var frozen=List.copyOf(result);bound.put(query.id(),frozen);return frozen;
        }finally{resolving.remove(query.id());}
    }
    public List<RelationSymbol> own(Query query){return namespace(query,Integer.MAX_VALUE).relations();}
    private JoinedNamespace.Output namespace(Query query,int before){
        if(before==Integer.MAX_VALUE&&conditionScopes.containsKey(query.id()))return conditionScopes.get(query.id());
        var cached=namespaces.get(query.id());if(before==Integer.MAX_VALUE&&cached!=null)return cached;
        boolean pending=resolving.contains(query.id());var bindings=new LinkedHashMap<Relation,RelationSymbol>();
        for(var relation:physical(query))bindings.put(relation.syntax(),relation);
        var issues=new ArrayList<LanguageIssue>();var output=new JoinedNamespace(dialect,catalog.context().rules(dialect),budget,bindings,issues).bind(query.sources(),before);
        for(var issue:issues)joinIssues.putIfAbsent(issue.code()+":"+issue.start()+":"+issue.end(),issue);
        if(before==Integer.MAX_VALUE&&!pending)namespaces.put(query.id(),output);return output;
    }
    private List<ScopeFrame> frames(Query query){
        var frames=new ArrayList<ScopeFrame>();Query current=query;Query child=null;
        while(current!=null){
            boolean skip=false;int before=Integer.MAX_VALUE;
            if(child!=null){
                Query inspected=child;var derived=current.relations().stream().filter(r->Objects.equals(r.derivedQuery(),inspected.id())).findFirst().orElse(null);
                if(derived!=null){skip=!derived.lateral();before=derived.start();}
                if(current.ctes().stream().anyMatch(c->c.query()==inspected.id()))skip=true;
            }
            if(!skip)frames.add(new ScopeFrame(current,before));child=current;current=current.parent()==null?null:tree.query(current.parent());
        }
        return List.copyOf(frames);
    }
    public List<RelationSymbol> visible(Query query){
        var result=new LinkedHashMap<String,List<RelationSymbol>>();
        for(var frame:frames(query)){
            var local=new LinkedHashMap<String,List<RelationSymbol>>();
            for(var relation:namespace(frame.query(),frame.before()).relations())local.computeIfAbsent(aliasKey(relation),ignored->new ArrayList<>()).add(relation);
            for(var entry:local.entrySet())result.putIfAbsent(entry.getKey(),entry.getValue());
        }
        return result.values().stream().flatMap(Collection::stream).toList();
    }
    public Cte findCte(Query query,String name){
        Query child=null;for(Query scope=query;scope!=null;scope=scope.parent()==null?null:tree.query(scope.parent())){
            int maximum=Integer.MAX_VALUE;if(child!=null)for(var cte:scope.ctes())if(cte.query()==child.id())maximum=cte.recursive()?cte.ordinal():cte.ordinal()-1;
            for(var cte:scope.ctes())if(cte.ordinal()<=maximum&&cteKey(cte.name()).equals(cteKey(name)))return cte;child=scope;
        }
        return null;
    }
    public List<Cte> visibleCtes(Query query){
        var result=new LinkedHashMap<String,Cte>();Query child=null;
        for(Query scope=query;scope!=null;scope=scope.parent()==null?null:tree.query(scope.parent())){
            int maximum=Integer.MAX_VALUE;if(child!=null)for(var cte:scope.ctes())if(cte.query()==child.id())maximum=cte.recursive()?cte.ordinal():cte.ordinal()-1;
            for(var cte:scope.ctes())if(cte.ordinal()<=maximum)result.putIfAbsent(cteKey(cte.name()),cte);child=scope;
        }return List.copyOf(result.values());
    }
    public ColumnLookup lookupColumns(Query query,Token qualifier,Token column){
        for(var frame:frames(query)){
            var namespace=namespace(frame.query(),frame.before());var matches=new ArrayList<ColumnSymbol>();
            boolean complete=namespace.complete();boolean aliasPresent=false;
            if(qualifier==null){for(var candidate:namespace.columns())if(column==null||columnMatches(candidate.name(),column))matches.add(candidate);}
            else{
                String alias=aliasKey(qualifier);complete=true;
                for(var relation:namespace.relations())if(aliasKey(relation).equals(alias)){
                    aliasPresent=true;complete&=relation.complete();for(var candidate:relation.columns())if(column==null||columnMatches(candidate.name(),column))matches.add(candidate);
                }
            }
            // A known local match shadows every outer scope. Missing structural metadata
            // also stops lookup: an unknown local column could shadow an outer name.
            if(!matches.isEmpty()||!complete||aliasPresent)return new ColumnLookup(matches,complete);
        }
        return new ColumnLookup(List.of(),rulesComplete());
    }
    public List<ColumnSymbol> columns(Query query,Token qualifier,Token column){return lookupColumns(query,qualifier,column).candidates();}
    /** Unqualified completion retains nearest-scope names while preserving true local ambiguity. */
    public List<ColumnSymbol> completionColumns(Query query){
        var result=new ArrayList<ColumnSymbol>();var seen=new HashSet<String>();
        for(var frame:frames(query)){
            var namespace=namespace(frame.query(),frame.before());var local=new LinkedHashMap<String,List<ColumnSymbol>>();
            for(var column:namespace.columns())local.computeIfAbsent(catalog.context().rules(dialect).lookup(ObjectKind.COLUMN,column.name(),true),ignored->new ArrayList<>()).add(column);
            for(var entry:local.entrySet())if(seen.add(entry.getKey()))result.addAll(entry.getValue());
            if(!namespace.complete())break;
        }
        return List.copyOf(result);
    }
    public boolean ambiguousColumn(Query query,String exact){
        for(var frame:frames(query)){
            var namespace=namespace(frame.query(),frame.before());int matches=0;
            for(var column:namespace.columns())if(catalog.context().rules(dialect).matches(ObjectKind.COLUMN,column.name(),exact,true))matches++;
            if(matches>0||!namespace.complete())return namespace.complete()&&matches>1;
        }return false;
    }
    public ColumnLookup lookupReference(Query query,Name reference){
        if(reference.parts().size()<=2)return lookupColumns(query,reference.parts().size()==2?reference.parts().getFirst():null,reference.last());
        if(reference.parts().size()>(dialect.postgres()?4:3))return new ColumnLookup(List.of(),rulesComplete());
        var relationName=new Name(reference.parts().subList(0,reference.parts().size()-1));var resolved=catalog.resolve(relationName);
        for(var frame:frames(query)){
            var matches=new ArrayList<ColumnSymbol>();boolean present=false,complete=true;
            for(var relation:namespace(frame.query(),frame.before()).relations()){
                if(relation.syntax().alias()!=null||relation.key()==null||!resolved.contains(relation.key()))continue;
                present=true;complete&=relation.complete();for(var column:relation.columns())if(columnMatches(column.name(),reference.last()))matches.add(column);
            }
            if(present)return new ColumnLookup(matches,complete);
        }
        return new ColumnLookup(List.of(),rulesComplete());
    }
    public SqlTypes.Type referenceType(Query query,Name reference){
        var lookup=lookupReference(query,reference);return lookup.complete()&&lookup.candidates().size()==1?lookup.candidates().getFirst().type():SqlTypes.UNKNOWN;
    }
    public List<ColumnSymbol> project(Query query){
        return QueryOutputs.defaults(projection(query),dialect).symbols("");
    }
    private void outputIssue(LanguageIssue issue){outputIssues.putIfAbsent(issue.code()+":"+issue.start()+":"+issue.end(),issue);}
    private QueryOutputs.Shape projection(Query query){
        budget.check();var cte=cteDeclarations.get(query.id());if(cte!=null&&recursive(cte))return cteProjection(cte);
        var cached=outputs.get(query.id());if(cached!=null)return cached;
        if(!projecting.add(query.id()))return new QueryOutputs.Shape(List.of(),false);
        if(projecting.size()>32){projecting.remove(query.id());throw new AnalysisBudget.Limit("Semantic projection nesting exceeds 32 levels");}
        try{
            QueryOutputs.Shape result;
            if(!query.branches().isEmpty())result=setProjection(query,query.branches());
            else if(query.kind().equals("VALUES"))result=valuesProjection(query);
            else {
                var columns=new ArrayList<QueryOutputs.Column>();boolean complete=rulesComplete()&&!query.opaque()&&!query.projections().isEmpty();
                for(var item:query.projections()){
                    budget.check();var expression=item.expression();if(expression.isEmpty()){complete=false;continue;}
                    if(expression.size()==1&&is(expression.getFirst(),"*")){var source=namespace(query,Integer.MAX_VALUE);for(var column:source.columns())columns.add(QueryOutputs.from(column));complete&=source.complete();continue;}
                    if(expression.size()==3&&name(expression.getFirst())!=null&&is(expression.get(1),".")&&is(expression.getLast(),"*")){
                        String alias=aliasKey(name(expression.getFirst()));var matches=own(query).stream().filter(r->aliasKey(r).equals(alias)).toList();complete&=!matches.isEmpty()&&matches.stream().allMatch(RelationSymbol::complete);for(var relation:matches)for(var column:relation.columns())columns.add(QueryOutputs.from(column));continue;
                    }
                    var analysis=expressionAnalysis(query,expression,"");var node=analysis.syntax();while(node instanceof ExpressionSyntax.Decoration decoration)node=decoration.value();
                    String label=item.alias()!=null?dialect.identifier(item.alias()):node instanceof ExpressionSyntax.Reference reference?dialect.identifier(reference.name().last()):dialect.postgres()&&node instanceof ExpressionSyntax.Call call?dialect.identifier(call.name().last()):null;
                    QueryOutputs.Origin origin=node instanceof ExpressionSyntax.Literal literal?literal.token().kind()==Kind.PARAMETER?QueryOutputs.Origin.PARAMETER:literal.token().kind()==Kind.STRING||literal.token().is("NULL")?QueryOutputs.Origin.LITERAL:QueryOutputs.Origin.NONE:QueryOutputs.Origin.NONE;
                    columns.add(new QueryOutputs.Column(label,analysis.type(),"output:"+query.id()+":"+expression.getFirst().start(),null,origin));
                    complete&=!(analysis.syntax() instanceof ExpressionSyntax.Opaque)&&!(analysis.type().family()==SqlTypes.Family.UNKNOWN&&analysis.issues().stream().anyMatch(LanguageIssue::incomplete));
                }
                result=new QueryOutputs.Shape(columns,complete);
            }
            outputs.put(query.id(),result);return result;
        }finally{projecting.remove(query.id());}
    }
    private List<Group> valueRows(Query query){return query.clauses().stream().filter(clause->clause.name().equals("VALUES")).findFirst().stream().flatMap(clause->clause.elements().stream()).filter(Group.class::isInstance).map(Group.class::cast).toList();}
    private QueryOutputs.Shape valuesProjection(Query query){
        if(!dialect.postgres()){outputIssue(LanguageIssue.unavailable(query.start(),query.end(),"Table-value constructor output metadata is unavailable for this dialect"));return new QueryOutputs.Shape(List.of(),false);}
        var rows=new ArrayList<QueryOutputs.Shape>();for(var group:valueRows(query)){
            var columns=new ArrayList<QueryOutputs.Column>();boolean complete=group.complete();int from=0;
            for(int index=0;index<=group.body().size();index++)if(index==group.body().size()||is(group.body().get(index),",")){
                budget.check();var expression=group.body().subList(from,index);from=index+1;if(expression.isEmpty()){complete=false;continue;}
                var analysis=expressionAnalysis(query,expression,"");for(var issue:analysis.issues())outputIssue(issue);complete&=analysis.issues().stream().noneMatch(LanguageIssue::incomplete);
                var origin=analysis.syntax() instanceof ExpressionSyntax.Literal literal?literal.token().kind()==Kind.PARAMETER?QueryOutputs.Origin.PARAMETER:literal.token().kind()==Kind.STRING||literal.token().is("NULL")?QueryOutputs.Origin.LITERAL:QueryOutputs.Origin.NONE:QueryOutputs.Origin.NONE;
                columns.add(new QueryOutputs.Column(null,analysis.type(),"output:"+query.id()+":"+expression.getFirst().start(),null,origin));
            }rows.add(new QueryOutputs.Shape(columns,complete));
        }return QueryOutputs.values(rows,dialect,query.start(),query.end(),budget,this::outputIssue);
    }
    private List<String> setOperators(Query query){var result=new ArrayList<String>();for(var element:query.elements())if(element instanceof Leaf leaf&&Set.of("UNION","INTERSECT","EXCEPT").contains(leaf.token().text().toUpperCase(Locale.ROOT)))result.add(leaf.token().text().toUpperCase(Locale.ROOT));return result;}
    private int setPrecedence(String operator){return operator.equals("INTERSECT")&&!(dialect.engine()==Engine.MARIADB&&Arrays.asList(dialect.lexical().sqlMode().split(",")).contains("ORACLE"))?2:1;}
    private QueryOutputs.Shape setProjection(Query owner,List<Integer> branches){
        if(branches.isEmpty())return new QueryOutputs.Shape(List.of(),false);var operators=setOperators(owner);var operands=new ArrayDeque<QueryOutputs.Shape>();var pending=new ArrayDeque<String>();operands.push(projection(tree.query(branches.getFirst())));
        if(operators.size()<branches.size()-1){outputIssue(LanguageIssue.unavailable(owner.start(),owner.end(),"Set operation grammar is incomplete"));return new QueryOutputs.Shape(operands.peek().columns(),false);}
        for(int index=1;index<branches.size();index++){
            budget.check();String operator=operators.get(index-1);
            while(!pending.isEmpty()&&setPrecedence(pending.peek())>=setPrecedence(operator)){pending.pop();var right=operands.pop();var left=operands.pop();operands.push(QueryOutputs.combine(left,right,dialect,owner.start(),owner.end(),budget,this::outputIssue));}
            pending.push(operator);operands.push(projection(tree.query(branches.get(index))));
        }
        while(!pending.isEmpty()){pending.pop();var right=operands.pop();var left=operands.pop();operands.push(QueryOutputs.combine(left,right,dialect,owner.start(),owner.end(),budget,this::outputIssue));}return operands.pop();
    }
    private boolean within(Query query,int ancestor){for(Query scope=query;scope!=null;scope=scope.parent()==null?null:tree.query(scope.parent()))if(scope.id()==ancestor)return true;return false;}
    private boolean references(Query query,Cte cte){
        for(var inspected:tree.queries()){budget.check();if(within(inspected,query.id()))for(var relation:inspected.relations()){budget.check();if(relation.name()!=null&&relation.name().parts().size()==1&&findCte(inspected,dialect.identifier(relation.name().last()))==cte)return true;}}return false;
    }
    private boolean recursive(Cte cte){budget.check();return recursionFacts.computeIfAbsent(cte.query(),ignored->cte.recursive()&&references(tree.query(cte.query()),cte));}
    private QueryOutputs.Shape cteProjection(Cte cte){
        var cached=cteOutputs.get(cte.query());if(cached!=null)return cached;
        if(!buildingCtes.add(cte.query()))return new QueryOutputs.Shape(List.of(),false);
        try{
            Query query=tree.query(cte.query());QueryOutputs.Shape shape;
            if(recursive(cte)){
                int boundary=0;while(boundary<query.branches().size()&&!references(tree.query(query.branches().get(boundary)),cte))boundary++;
                if(boundary==0||boundary==query.branches().size()){outputIssue(LanguageIssue.unavailable(cte.name().start(),query.end(),"Recursive CTE requires an identifiable nonrecursive anchor and recursive term"));return new QueryOutputs.Shape(List.of(),false);}
                shape=QueryOutputs.defaults(setProjection(query,query.branches().subList(0,boundary)),dialect);
                shape=QueryOutputs.nullable(QueryOutputs.aliases(QueryOutputs.referenced(shape,query,dialect,true),cte.columns(),dialect,!dialect.postgres(),cte.name().start(),query.end(),this::outputIssue));
                recursiveCtes.add(cte.query());
            }else shape=QueryOutputs.aliases(QueryOutputs.referenced(QueryOutputs.defaults(projection(query),dialect),query,dialect,false),cte.columns(),dialect,!dialect.postgres(),cte.name().start(),query.end(),this::outputIssue);
            cteOutputs.put(cte.query(),shape);return shape;
        }finally{buildingCtes.remove(cte.query());}
    }
    private void inspectRecursiveTypes(){
        for(int id:new ArrayList<>(recursiveCtes)){
            budget.check();var cte=cteDeclarations.get(id);var query=tree.query(id);var anchor=cteOutputs.get(id);
            for(int branch:query.branches())if(references(tree.query(branch),cte)){
                var term=projection(tree.query(branch));if(anchor.columns().size()!=term.columns().size()){if(anchor.complete()&&term.complete())outputIssue(LanguageIssue.semantic("type.set-column-count",query.start(),query.end(),"Recursive term and anchor have different output column counts"));continue;}
                if(!dialect.postgres())continue;
                for(int index=0;index<anchor.columns().size();index++){
                    var expected=anchor.columns().get(index).type();var column=term.columns().get(index);var actual=column.type();
                    if(!expected.known()||!actual.known()&&!column.contextual()){outputIssue(LanguageIssue.unavailable(query.start(),query.end(),"Recursive CTE type validation requires complete anchor and recursive term types"));continue;}
                    var overall=SqlTypes.common(expected,actual,dialect.engine());
                    if(!overall.known()||!SqlTypes.sameNative(expected,overall,dialect.engine())||expected.precision()>0&&actual.precision()>0&&(expected.precision()!=actual.precision()||expected.scale()!=actual.scale()))outputIssue(LanguageIssue.semantic("type.recursive-cte-mismatch",query.start(),query.end(),"Recursive query type differs from the nonrecursive anchor; use an explicit cast"));
                    else if(expected.precision()!=overall.precision()||expected.scale()!=overall.scale())outputIssue(LanguageIssue.unavailable(query.start(),query.end(),"Recursive CTE typemod validation requires exact result typemods"));
                }
            }
        }
    }
    public SqlTypes.Type type(Query query,List<Element> expression){
        return expression.isEmpty()?SqlTypes.UNKNOWN:expressionAnalysis(query,expression,"").type();
    }
    private Projection outputAlias(Query query,Name name,List<Element> expression,String clause){
        if(name.parts().size()!=1||!Set.of("ORDER","GROUP","HAVING").contains(clause)||dialect.postgres()&&clause.equals("HAVING"))return null;
        if(dialect.postgres()&&!(expression.size()==1&&expression.getFirst() instanceof Leaf))return null;
        if((clause.equals("GROUP")||clause.equals("HAVING"))&&!lookupReference(query,name).candidates().isEmpty())return null;
        var matches=query.projections().stream().filter(p->p.alias()!=null&&columnMatches(dialect.identifier(p.alias()),name.last())).toList();return matches.size()==1?matches.getFirst():null;
    }
    private ExpressionAnalyzer.Result expressionAnalysis(Query query,List<Element> expression,String clause){
        if(++expressionDepth>32){expressionDepth--;throw new AnalysisBudget.Limit("Semantic projection nesting exceeds 32 levels");}
        try{return new ExpressionAnalyzer(dialect,budget,new ExpressionAnalyzer.Resolver(){
            public SqlTypes.Type reference(Name name){var output=outputAlias(query,name,expression,clause);return output==null?referenceType(query,name):type(query,output.expression());}
            public boolean referenceComplete(Name name){return outputAlias(query,name,expression,clause)!=null||lookupReference(query,name).complete();}
            public ExpressionAnalyzer.CallCandidates routines(Name name,Group arguments,int count){
                var signatures=catalog.callSignatures(name,false,NativeCallSyntax.nativeEligible(dialect,name,tree.document().source(),arguments.open().start()),count);
                // Empty lookup results establish absence only in the exact
                // captured namespace. Data-source configuration completeness is
                // not evidence about an uninspected routine namespace.
                boolean provenSignatures=!signatures.isEmpty()&&signatures.stream().allMatch(RoutineSignatures.Signature::complete);
                return new ExpressionAnalyzer.CallCandidates(signatures,provenSignatures||catalog.routineNamespaceComplete(name));
            }
            public SqlTypes.Type subquery(Group group){
                var nested=tree.queries().stream().filter(q->q.start()==group.open().end()).findFirst().orElse(null);
                if(nested==null)return SqlTypes.UNKNOWN;var shape=QueryOutputs.defaults(projection(nested),dialect);return shape.complete()&&shape.columns().size()==1?SqlTypes.nullable(NativeNumericTypes.scalar(shape.columns().getFirst().type(),dialect.engine()),true):SqlTypes.UNKNOWN;
            }
        }).analyze(expression);}finally{expressionDepth--;}
    }
    public List<LanguageIssue> diagnostics(){
        var issues=new ArrayList<>(tree.issues());
        for(var query:tree.queries()){
            budget.check();if(query.opaque()){if(!Set.of("EXECUTABLE_COMMENT","UNICODE_ESCAPE","LEXICAL_UNAVAILABLE").contains(query.kind()))issues.add(LanguageIssue.unavailable(query.start(),query.end(),"Procedural body is an opaque analysis region"));continue;}
            if(query.kind().equals("SET")){if(!query.branches().isEmpty())projection(query);continue;}
            if(query.kind().equals("VALUES")){projection(query);for(var group:valueRows(query))inspectExpressions(query,group.body(),"VALUES_EXPRESSION",issues);}
            var aliases=new HashMap<String,Relation>();for(var symbol:own(query)){var relation=symbol.syntax();if(relation.visibleName()!=null){String alias=aliasKey(relation.visibleName());if(aliases.putIfAbsent(alias,relation)!=null&&rulesComplete())issues.add(LanguageIssue.semantic("binding.duplicate-alias",relation.visibleName().start(),relation.visibleName().end(),"Duplicate relation alias: "+dialect.identifier(relation.visibleName())));if(relation.lateral()&&!dialect.lateral())issues.add(LanguageIssue.syntax("dialect.lateral",relation.start(),relation.end(),"LATERAL derived tables are unavailable in this MariaDB release"));}}
            var cteNames=new HashSet<String>();for(var cte:query.ctes())if(!cteNames.add(cteKey(cte.name()))&&rulesComplete())issues.add(LanguageIssue.semantic("binding.duplicate-cte",cte.name().start(),cte.name().end(),"Duplicate common table expression"));
            if(!query.ctes().isEmpty()&&dialect.engine()==Engine.MARIADB&&Set.of("UPDATE","DELETE").contains(query.kind()))issues.add(LanguageIssue.syntax("dialect.cte-dml",query.start(),query.end(),"WITH before UPDATE or DELETE is unavailable in MariaDB 11.8"));
            if(query.hasClause("RETURNING")&&!dialect.returning(query.kind())){var clause=query.clauses().stream().filter(c->c.name().equals("RETURNING")).findFirst().orElseThrow();issues.add(LanguageIssue.syntax("dialect.returning",clause.start(),Math.min(clause.start()+9,clause.end()),"RETURNING is unavailable for this statement in the selected engine"));}
            if(Set.of("UPDATE","DELETE").contains(query.kind())&&!SafetyInspections.restrictingWhere(query))issues.add(new LanguageIssue("inspection.unrestricted-"+query.kind().toLowerCase(Locale.ROOT),"inspection","warning",query.start(),Math.min(query.start()+query.kind().length(),query.end()),query.kind()+" has no restricting WHERE clause",false));
            var own=own(query);
            for(var relation:physical(query)){
                if(relation.syntax().name()!=null&&relation.syntax().name().parts().size()==1&&findCte(query,dialect.identifier(relation.syntax().name().last()))!=null)continue;
                if(relation.key()==null&&relation.syntax().name()!=null&&catalog.namespaceComplete(relation.syntax().name()))issues.add(LanguageIssue.semantic("binding.unresolved-relation",relation.syntax().name().start(),relation.syntax().name().end(),"Unresolved relation: "+dialect.identifier(relation.syntax().name().last())));
                else if(!relation.complete())issues.add(new LanguageIssue("metadata.incomplete","metadata","hint",relation.syntax().start(),relation.syntax().end(),"Metadata for this source is incomplete, unavailable or stale; refresh its structural scope",true));
            }
            var insertNames=new HashSet<String>();for(var token:query.insertColumns()){
                String key=columnKey(token);if(!insertNames.add(key)&&rulesComplete())issues.add(LanguageIssue.semantic("binding.duplicate-insert-column",token.start(),token.end(),"Duplicate INSERT target column"));
                if(!own.isEmpty()&&own.getFirst().complete()&&own.getFirst().columns().stream().noneMatch(c->columnMatches(c.name(),token)))issues.add(LanguageIssue.semantic("binding.unknown-target-column",token.start(),token.end(),"Unknown INSERT target column"));
            }
            for(var clause:query.clauses())if(Set.of("SELECT","WHERE","GROUP","HAVING","ORDER","SET","RETURNING","WINDOW").contains(clause.name()))inspectExpressions(query,clause.elements(),clause.name(),issues);
            for(var source:query.sources())inspectJoinConditions(query,source,issues);
            for(var clause:query.clauses())if(clause.name().equals("SET"))inspectAssignments(query,clause.elements(),issues);
        }
        inspectRecursiveTypes();issues.addAll(joinIssues.values());issues.addAll(outputIssues.values());
        if(!catalog.context().complete()&&tree.queries().stream().anyMatch(q->!q.relations().isEmpty()))issues.add(LanguageIssue.unavailable(0,Math.min(tree.document().source().length(),1),"Metadata is incomplete or unavailable; unresolved-object inspections are limited"));
        return issues.stream().limit(64).toList();
    }
    private void inspectJoinConditions(Query query,TableSource source,List<LanguageIssue> issues){
        if(source instanceof GroupedSource group){inspectJoinConditions(query,group.source(),issues);return;}
        if(!(source instanceof JoinedSource join))return;
        inspectJoinConditions(query,join.left(),issues);inspectJoinConditions(query,join.right(),issues);
        if(join.condition().isEmpty())return;
        var bindings=new LinkedHashMap<Relation,RelationSymbol>();for(var relation:physical(query))bindings.put(relation.syntax(),relation);
        var operands=new JoinedNamespace(dialect,catalog.context().rules(dialect),budget,bindings,new ArrayList<>()).bind(List.of(join.left(),join.right()),Integer.MAX_VALUE);
        var previous=conditionScopes.put(query.id(),operands);
        try{inspectExpressions(query,join.condition(),"ON",issues);}finally{if(previous==null)conditionScopes.remove(query.id());else conditionScopes.put(query.id(),previous);}
    }
    private void inspectExpressions(Query query,List<Element> elements,String clause,List<LanguageIssue> issues){
        if(clause.equals("WINDOW")){for(var element:elements)if(element instanceof Group group)for(var part:ExpressionParser.windowParts(group))inspectExpressions(query,part,"WINDOW_EXPRESSION",issues);return;}
        var expressions=new ArrayList<List<Element>>();
        if(Set.of("SELECT","RETURNING").contains(clause))for(var projection:query.projections())expressions.add(projection.expression());
        else {
            int from=0,caseDepth=0;for(int index=0;index<=elements.size();index++){
                if(index<elements.size()){if(is(elements.get(index),"CASE"))caseDepth++;else if(is(elements.get(index),"END"))caseDepth--;}
                if(index==elements.size()||caseDepth==0&&is(elements.get(index),",")){var part=elements.subList(from,index);from=index+1;
                    if(!part.isEmpty()&&is(part.getFirst(),"BY"))part=part.subList(1,part.size());
                    if(clause.equals("SET")){int equal=0;while(equal<part.size()&&!is(part.get(equal),"="))equal++;part=equal<part.size()?part.subList(equal+1,part.size()):List.of();}
                    if(clause.equals("ORDER")){int end=part.size();if(end>=2&&is(part.get(end-2),"NULLS")&&(is(part.get(end-1),"FIRST")||is(part.get(end-1),"LAST")))end-=2;if(end>0&&(is(part.get(end-1),"ASC")||is(part.get(end-1),"DESC")))end--;part=part.subList(0,end);}
                    expressions.add(part);
                }
            }
        }
        for(var expression:expressions){
            if(expression.isEmpty()||expression.size()==1&&(is(expression.getFirst(),"*")||is(expression.getFirst(),"DEFAULT"))||expression.size()>=3&&is(expression.getLast(),"*")&&is(expression.get(expression.size()-2),"."))continue;
            var analysis=expressionAnalysis(query,expression,clause);issues.addAll(analysis.issues());
            if(Set.of("WHERE","HAVING","ON").contains(clause)&&analysis.complete()&&!ExpressionOperators.booleanCompatible(analysis.type(),dialect))issues.add(LanguageIssue.semantic("type.invalid-boolean",expression.getFirst().start(),expression.getLast().end(),"Clause requires a Boolean expression"));
            var pending=new ArrayDeque<ExpressionSyntax.Node>();pending.push(analysis.syntax());while(!pending.isEmpty()){
                budget.check();var node=pending.pop();for(var child:node.children())pending.push(child);
                if(node instanceof ExpressionSyntax.Reference reference){
                    var name=reference.name();var column=name.last();if(outputAlias(query,name,expression,clause)!=null)continue;
                    var lookup=lookupReference(query,name);if(lookup.complete()&&lookup.candidates().size()>1)issues.add(LanguageIssue.semantic("binding.ambiguous-column",column.start(),column.end(),"Ambiguous column: "+dialect.identifier(column)));
                    else if(lookup.complete()&&lookup.candidates().isEmpty()&&!visible(query).isEmpty())issues.add(LanguageIssue.semantic(name.parts().size()==1?"binding.unresolved-column":"binding.invalid-derived-reference",column.start(),column.end(),"Unresolved column: "+dialect.identifier(column)));
                }else if(node instanceof ExpressionSyntax.Call call&&Set.of("WHERE","ON").contains(clause)){
                    var signatures=catalog.callSignatures(call.name(),false,NativeCallSyntax.nativeEligible(dialect,call.name(),tree.document().source(),call.arguments().open().start()),call.values().size());
                    if(!signatures.isEmpty()&&signatures.stream().allMatch(s->s.identity().startsWith("builtin:"))&&Set.of("count","sum","avg","min","max","row_number","rank","dense_rank").contains(dialect.identifier(call.name().last()).toLowerCase(Locale.ROOT)))issues.add(LanguageIssue.semantic("expression.invalid-aggregate",call.start(),call.end(),"Aggregate or window expression is unavailable in this clause"));
                }
            }
        }
    }
    private void inspectAssignments(Query query,List<Element> elements,List<LanguageIssue> issues){
        var target=own(query).stream().filter(r->r.syntax().target()).findFirst().orElse(null);if(target==null||!target.complete())return;int from=0;
        for(int at=0;at<=elements.size();at++)if(at==elements.size()||is(elements.get(at),",")){
            var assignment=elements.subList(from,at);from=at+1;int equal=-1;for(int i=0;i<assignment.size();i++)if(is(assignment.get(i),"=")){equal=i;break;}
            if(equal<1)continue;Token column=name(assignment.get(equal-1));if(column==null)continue;
            var matches=target.columns().stream().filter(c->columnMatches(c.name(),column)).toList();
            if(matches.isEmpty()){issues.add(LanguageIssue.semantic("binding.unknown-update-column",column.start(),column.end(),"Unknown UPDATE target column"));continue;}
            if(equal+1>=assignment.size()||is(assignment.get(equal+1),"DEFAULT"))continue;var type=type(query,assignment.subList(equal+1,assignment.size()));
            if(!SqlTypes.compatible(type,matches.getFirst().type(),dialect.engine()))issues.add(LanguageIssue.semantic("type.incompatible-assignment",assignment.get(equal+1).start(),assignment.getLast().end(),"Incompatible assignment type: "+type.nativeName()+" to "+matches.getFirst().type().nativeName()));
        }
    }
}
