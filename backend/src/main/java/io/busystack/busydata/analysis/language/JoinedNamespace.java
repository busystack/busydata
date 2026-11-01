package io.busystack.busydata.analysis.language;

import java.util.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.analysis.language.LosslessLexer.Token;
import io.busystack.busydata.analysis.language.SemanticBinder.*;
import io.busystack.busydata.analysis.language.SyntaxTree.*;

/** Joined output, operand qualification, ordering and outer-join null extension. */
final class JoinedNamespace {
    record Output(List<ColumnSymbol> columns,List<RelationSymbol> relations,boolean complete) {
        Output {columns=List.copyOf(columns);relations=List.copyOf(relations);}
    }
    private static final Output EMPTY=new Output(List.of(),List.of(),true);
    private final Dialect dialect;private final io.busystack.busydata.metadata.IdentifierRules rules;private final AnalysisBudget budget;
    private final Map<Relation,RelationSymbol> bindings;private final List<LanguageIssue> issues;
    JoinedNamespace(Dialect dialect,io.busystack.busydata.metadata.IdentifierRules rules,AnalysisBudget budget,Map<Relation,RelationSymbol> bindings,List<LanguageIssue> issues){this.dialect=dialect;this.rules=rules;this.budget=budget;this.bindings=bindings;this.issues=issues;}
    Output bind(List<TableSource> sources,int before){
        var columns=new ArrayList<ColumnSymbol>();var relations=new ArrayList<RelationSymbol>();boolean complete=true;
        for(var source:sources){var output=bind(source,before);columns.addAll(output.columns());relations.addAll(output.relations());complete&=output.complete();}
        return new Output(columns,relations,complete);
    }
    private Output bind(TableSource source,int before){
        budget.check();if(source.start()>=before)return EMPTY;
        if(source instanceof RelationSource leaf){var relation=bindings.get(leaf.relation());return relation==null?new Output(List.of(),List.of(),false):new Output(relation.columns(),List.of(relation),relation.complete());}
        if(source instanceof GroupedSource group){
            var output=bind(group.source(),before);if(group.alias()==null||group.end()>=before)return output;
            String alias=dialect.identifier(group.alias());var columns=new ArrayList<ColumnSymbol>();
            for(int i=0;i<output.columns().size();i++){var column=output.columns().get(i);columns.add(new ColumnSymbol(i<group.outputAliases().size()?dialect.identifier(group.outputAliases().get(i)):column.name(),column.type(),column.identity(),alias,column.object()));}
            var syntax=new Relation(null,group.alias(),null,false,false,group.outputAliases(),group.start(),group.end());
            boolean complete=output.complete()&&dialect.postgres();var relation=new RelationSymbol(syntax,alias,columns,null,complete);
            return new Output(columns,List.of(relation),complete);
        }
        var join=(JoinedSource)source;var left=bind(join.left(),before);if(join.right().start()>=before)return left;var right=bind(join.right(),before);
        boolean complete=left.complete()&&right.complete()&&(join.kind()!=JoinKind.FULL||dialect.postgres());
        var nullableLeft=join.kind()==JoinKind.RIGHT||join.kind()==JoinKind.FULL?nullable(left):left;
        var nullableRight=join.kind()==JoinKind.LEFT||join.kind()==JoinKind.FULL?nullable(right):right;
        var relations=new ArrayList<RelationSymbol>(nullableLeft.relations());relations.addAll(nullableRight.relations());
        if(!join.natural()&&join.usingColumns().isEmpty())return concatenate(nullableLeft,nullableRight,relations,complete);
        // A partial source cannot prove the set or uniqueness of common output names.
        if(!complete)return concatenate(nullableLeft,nullableRight,relations,false);
        var leftNames=index(left.columns());var rightNames=index(right.columns());var keys=new LinkedHashSet<String>();var listed=new LinkedHashMap<String,Token>();
        for(var token:join.usingColumns()){
            String key=key(token);if(listed.putIfAbsent(key,token)!=null){issues.add(LanguageIssue.semantic("binding.duplicate-using-column",token.start(),token.end(),"Duplicate USING column"));complete=false;}
        }
        var preservedFirst=join.kind()==JoinKind.RIGHT&&!dialect.postgres()?right:left;
        if(join.natural())for(var column:preservedFirst.columns()){String key=key(column.name());if(leftNames.containsKey(key)&&rightNames.containsKey(key))keys.add(key);}
        else if(dialect.postgres())keys.addAll(listed.keySet());
        else for(var column:(join.kind()==JoinKind.RIGHT?right:left).columns()){String key=key(column.name());if(listed.containsKey(key))keys.add(key);}
        // Missing names must also be checked when MySQL/MariaDB order is operand based.
        for(var entry:listed.entrySet())if(!leftNames.containsKey(entry.getKey())||!rightNames.containsKey(entry.getKey())){
            var token=entry.getValue();issues.add(LanguageIssue.semantic("binding.unresolved-using-column",token.start(),token.end(),"USING column must exist in both joined operands"));complete=false;
        }
        for(String key:keys)if(leftNames.getOrDefault(key,List.of()).size()>1||rightNames.getOrDefault(key,List.of()).size()>1){
            var token=listed.get(key);issues.add(LanguageIssue.semantic("binding.ambiguous-using-column",token==null?join.start():token.start(),token==null?join.end():token.end(),"Common join column is ambiguous in an operand"));complete=false;
        }
        if(!complete)return concatenate(nullableLeft,nullableRight,relations,false);
        var output=new ArrayList<ColumnSymbol>();
        for(String key:keys){
            var a=leftNames.get(key).getFirst();var b=rightNames.get(key).getFirst();
            var type=dialect.postgres()?a.type().known()&&b.type().known()?SqlTypes.common(a.type(),b.type(),dialect.engine()):SqlTypes.UNKNOWN:join.kind()==JoinKind.RIGHT?b.type():a.type();
            boolean nullability=switch(join.kind()){case LEFT->a.type().nullable();case RIGHT->b.type().nullable();case FULL->a.type().nullable()||b.type().nullable();default->false;};
            type=withNullability(type,nullability);
            String name=join.kind()==JoinKind.RIGHT&&!dialect.postgres()?b.name():a.name();
            output.add(new ColumnSymbol(name,type,"join:"+join.start()+":"+a.identity()+":"+b.identity(),"",null));
        }
        var first=join.kind()==JoinKind.RIGHT&&!dialect.postgres()?nullableRight:nullableLeft;var second=first==nullableLeft?nullableRight:nullableLeft;
        for(var column:first.columns())if(!keys.contains(key(column.name())))output.add(column);
        for(var column:second.columns())if(!keys.contains(key(column.name())))output.add(column);
        return new Output(output,relations,true);
    }
    private Map<String,List<ColumnSymbol>> index(List<ColumnSymbol> columns){var result=new LinkedHashMap<String,List<ColumnSymbol>>();for(var column:columns){budget.check();result.computeIfAbsent(key(column.name()),ignored->new ArrayList<>()).add(column);}return result;}
    private String key(String exact){return rules.lookup(ObjectKind.COLUMN,exact,true);}
    private String key(Token token){return rules.lookup(ObjectKind.COLUMN,token.identifier(),token.quoted());}
    private static Output concatenate(Output left,Output right,List<RelationSymbol> relations,boolean complete){var columns=new ArrayList<ColumnSymbol>(left.columns());columns.addAll(right.columns());return new Output(columns,relations,complete);}
    private static SqlTypes.Type withNullability(SqlTypes.Type type,boolean nullable){return SqlTypes.nullable(type,nullable);}
    private static ColumnSymbol nullable(ColumnSymbol column){return new ColumnSymbol(column.name(),withNullability(column.type(),true),column.identity(),column.qualifier(),column.object());}
    private static Output nullable(Output output){
        var columns=output.columns().stream().map(JoinedNamespace::nullable).toList();
        var relations=output.relations().stream().map(relation->new RelationSymbol(relation.syntax(),relation.alias(),relation.columns().stream().map(JoinedNamespace::nullable).toList(),relation.key(),relation.complete())).toList();
        return new Output(columns,relations,output.complete());
    }
}
