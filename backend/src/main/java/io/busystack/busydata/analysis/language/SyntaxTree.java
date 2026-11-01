package io.busystack.busydata.analysis.language;

import java.util.*;
import io.busystack.busydata.analysis.language.LosslessLexer.Token;

/** Recoverable editor syntax. Missing closing tokens are represented explicitly. */
public record SyntaxTree(LosslessLexer.Document document,List<Query> queries,List<LanguageIssue> issues) {
    public SyntaxTree {queries=List.copyOf(queries);issues=List.copyOf(issues);}
    public sealed interface Element permits Leaf,Group {int start();int end();}
    public record Leaf(Token token) implements Element {public int start(){return token.start();}public int end(){return token.end();}}
    public record Group(Token open,List<Element> body,Token close,int end) implements Element {
        public Group {body=List.copyOf(body);}public int start(){return open.start();}public boolean complete(){return close!=null;}
    }
    public record Name(List<Token> parts) {
        public Name {parts=List.copyOf(parts);}public Token last(){return parts.getLast();}public int start(){return parts.getFirst().start();}public int end(){return last().end();}
    }
    public record Relation(Name name,Token alias,Integer derivedQuery,boolean lateral,boolean target,List<Token> outputAliases,int start,int end) {
        public Relation {outputAliases=List.copyOf(outputAliases);}
        public Token visibleName(){return alias!=null?alias:name==null?null:name.last();}
    }
    /** A joined table has an output namespace distinct from its qualified operands. */
    public sealed interface TableSource permits RelationSource,JoinedSource,GroupedSource {int start();int end();}
    public record RelationSource(Relation relation) implements TableSource {public int start(){return relation.start();}public int end(){return relation.end();}}
    public enum JoinKind {COMMA,INNER,CROSS,LEFT,RIGHT,FULL}
    public record JoinedSource(TableSource left,TableSource right,JoinKind kind,boolean natural,List<Token> usingColumns,List<Element> condition,int start,int end) implements TableSource {
        public JoinedSource {usingColumns=List.copyOf(usingColumns);condition=List.copyOf(condition);}
    }
    public record GroupedSource(TableSource source,Token alias,List<Token> outputAliases,int start,int end) implements TableSource {
        public GroupedSource {outputAliases=List.copyOf(outputAliases);}
    }
    public record Cte(Token name,List<Token> columns,int query,boolean recursive,int ordinal) {public Cte {columns=List.copyOf(columns);}}
    public record Projection(List<Element> expression,Token alias) {public Projection {expression=List.copyOf(expression);}}
    public record Clause(String name,int start,int end,List<Element> elements) {public Clause {elements=List.copyOf(elements);}}
    public record Query(int id,Integer parent,int start,int end,String kind,List<Element> elements,List<Relation> relations,List<TableSource> sources,List<Cte> ctes,List<Projection> projections,List<Clause> clauses,List<Integer> branches,List<Token> insertColumns,boolean opaque) {
        public Query {elements=List.copyOf(elements);relations=List.copyOf(relations);sources=List.copyOf(sources);ctes=List.copyOf(ctes);projections=List.copyOf(projections);clauses=List.copyOf(clauses);branches=List.copyOf(branches);insertColumns=List.copyOf(insertColumns);}
        public Clause clauseAt(int caret){return clauses.stream().filter(c->caret>=c.start()&&caret<=c.end()).reduce((a,b)->b).orElse(null);}
        public boolean hasClause(String name){return clauses.stream().anyMatch(c->c.name().equals(name));}
    }
    public Query at(int caret){return queries.stream().filter(q->caret>=q.start()&&caret<=q.end()&&!q.opaque()).min(Comparator.comparingInt(q->q.end()-q.start())).orElse(queries.isEmpty()?null:queries.getFirst());}
    public Query query(int id){return queries.get(id);}
    public static boolean is(Element element,String word){return element instanceof Leaf leaf&&leaf.token().is(word);}
    public static Token name(Element element){return element instanceof Leaf leaf&&leaf.token().name()?leaf.token():null;}
}
