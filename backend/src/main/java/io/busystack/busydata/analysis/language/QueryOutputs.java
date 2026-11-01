package io.busystack.busydata.analysis.language;

import java.util.*;
import java.util.function.Consumer;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.analysis.language.SemanticBinder.ColumnSymbol;
import io.busystack.busydata.analysis.language.SqlTypes.*;
import io.busystack.busydata.analysis.language.SyntaxTree.*;

/** Positional query outputs are distinct from their known referenceable names.
 * An absent generated label never removes a position or invents an identifier. */
final class QueryOutputs {
    enum Origin {NONE,LITERAL,PARAMETER}
    record Column(String name,Type type,String identity,SchemaObject object,Origin origin) {
        Column {Objects.requireNonNull(type);Objects.requireNonNull(identity);}
        boolean contextual(){return origin!=Origin.NONE;}
        Column named(String name){return new Column(name,type,identity,object,origin);}
        Column typed(Type type){return new Column(name,type,identity,object,Origin.NONE);}
    }
    record Shape(List<Column> columns,boolean complete){
        Shape {columns=List.copyOf(columns);}
        boolean namesComplete(){return complete&&columns.stream().allMatch(c->c.name()!=null);}
        List<ColumnSymbol> symbols(String qualifier){return columns.stream().filter(c->c.name()!=null).map(c->new ColumnSymbol(c.name(),c.type(),c.identity(),qualifier,c.object())).toList();}
    }
    private QueryOutputs(){}
    static Column from(ColumnSymbol symbol){return new Column(symbol.name(),symbol.type(),symbol.identity(),symbol.object(),Origin.NONE);}
    static Shape aliases(Shape shape,List<LosslessLexer.Token> aliases,Dialect dialect,boolean exact,int start,int end,Consumer<LanguageIssue> issues){
        if(aliases.isEmpty())return shape;
        if(aliases.size()>shape.columns().size()||exact&&aliases.size()!=shape.columns().size()){
            if(shape.complete())issues.accept(LanguageIssue.semantic("binding.output-column-count",start,end,"Declared output column count does not match the query output"));
            return new Shape(shape.columns(),false);
        }
        var renamed=new ArrayList<Column>();for(int index=0;index<shape.columns().size();index++)renamed.add(index<aliases.size()?shape.columns().get(index).named(dialect.identifier(aliases.get(index))):shape.columns().get(index));
        return new Shape(renamed,shape.complete());
    }
    static Shape defaults(Shape shape,Dialect dialect){
        if(!dialect.postgres())return shape;var result=new ArrayList<Column>();for(var column:shape.columns())result.add(column.origin()==Origin.LITERAL&&(column.type().family()==Family.NULL||!column.type().known())?column.typed(SqlTypes.nullable(SqlTypes.nativeType("text",dialect.engine()),column.type().nullable())):column);
        return new Shape(result,shape.complete());
    }
    /** Only SQL constructs which prohibit derived merging prove materialization.
     * Smaller mergeable integer expressions retain their family but not a guessed
     * native width when the captured context omits optimizer settings. */
    static Shape referenced(Shape shape,Query query,Dialect dialect,boolean recursive){
        boolean holder=recursive||!query.branches().isEmpty();boolean materialized=!query.hasClause("FROM")||query.hasClause("GROUP")||query.hasClause("HAVING")||query.hasClause("LIMIT")||query.hasClause("WINDOW")||query.elements().stream().anyMatch(element->SyntaxTree.is(element,"DISTINCT"));
        return new Shape(shape.columns().stream().map(column->column.typed(NativeNumericTypes.materialized(column.type(),materialized,holder,dialect.engine()))).toList(),shape.complete());
    }
    static Shape nullable(Shape shape){return new Shape(shape.columns().stream().map(c->new Column(c.name(),SqlTypes.nullable(c.type(),true),c.identity(),c.object(),c.origin())).toList(),shape.complete());}
    static Shape values(List<Shape> rows,Dialect dialect,int start,int end,AnalysisBudget budget,Consumer<LanguageIssue> issues){
        if(rows.isEmpty())return new Shape(List.of(),false);int count=rows.getFirst().columns().size();boolean complete=rows.stream().allMatch(Shape::complete);
        if(rows.stream().anyMatch(row->row.columns().size()!=count)){issues.accept(LanguageIssue.semantic("type.set-column-count",start,end,"VALUES rows have different output column counts"));return new Shape(List.of(),false);}
        var result=new ArrayList<Column>();for(int index=0;index<count;index++){
            budget.check();var types=new ArrayList<Type>();boolean available=true;for(var row:rows){budget.check();var column=row.columns().get(index);types.add(column.type());available&=column.type().known()||column.contextual();}
            Type type=available?SqlTypes.common(types,dialect.engine()):SqlTypes.UNKNOWN;if(available&&!type.known())issues.accept(LanguageIssue.semantic("type.incompatible-set",start,end,"VALUES output expressions do not have a common type"));
            result.add(new Column("column"+(index+1),type,rows.getFirst().columns().get(index).identity(),null,Origin.NONE));
        }return new Shape(result,complete);
    }
    static Shape combine(Shape left,Shape right,Dialect dialect,int start,int end,AnalysisBudget budget,Consumer<LanguageIssue> issues){
        if(left.columns().size()!=right.columns().size()){
            if(left.complete()&&right.complete())issues.accept(LanguageIssue.semantic("type.set-column-count",start,end,"Set operation inputs have different output column counts"));
            return new Shape(left.columns().stream().map(c->c.typed(SqlTypes.UNKNOWN)).toList(),false);
        }
        var result=new ArrayList<Column>();for(int index=0;index<left.columns().size();index++){
            budget.check();var a=left.columns().get(index);var b=right.columns().get(index);Type type;
            if(!a.type().known()&&!a.contextual()||!b.type().known()&&!b.contextual())type=SqlTypes.UNKNOWN;
            else type=SqlTypes.common(a.type(),b.type(),dialect.engine());
            if(!type.known()&&a.type().known()&&b.type().known()&&left.complete()&&right.complete()){
                boolean unsupported=Set.of(Family.USER,Family.DOMAIN,Family.ENUM,Family.ARRAY,Family.UNKNOWN).contains(a.type().family())||Set.of(Family.USER,Family.DOMAIN,Family.ENUM,Family.ARRAY,Family.UNKNOWN).contains(b.type().family());
                issues.accept(unsupported?LanguageIssue.unavailable(start,end,"Set result type requires unavailable native coercion metadata"):LanguageIssue.semantic("type.incompatible-set",start,end,"Set operation output columns do not have a common type"));
            }
            result.add(new Column(a.name(),type,a.identity(),null,Origin.NONE));
        }return new Shape(result,left.complete()&&right.complete());
    }
}
