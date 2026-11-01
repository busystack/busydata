package io.busystack.busydata.analysis.language;

import java.util.*;
import io.busystack.busydata.analysis.language.LosslessLexer.*;
import io.busystack.busydata.analysis.language.SyntaxTree.*;
import static io.busystack.busydata.analysis.language.SyntaxTree.*;

/** Recoverable table-reference grammar. Explicit joins bind more tightly than commas. */
final class TableSourceParser {
    record Result(List<Relation> relations,List<TableSource> sources,List<Token> insertColumns) {}
    private static final Set<String> END=Set.of("WHERE","GROUP","HAVING","WINDOW","ORDER","LIMIT","OFFSET","FETCH","RETURNING","SET","VALUES","UNION","INTERSECT","EXCEPT","FOR","LOCK");
    private static final Set<String> JOIN=Set.of("JOIN","LEFT","RIGHT","FULL","INNER","OUTER","CROSS","NATURAL","STRAIGHT_JOIN");
    private final Dialect dialect;private final AnalysisBudget budget;private final Map<Integer,Integer> groupQueries;private final List<LanguageIssue> issues;
    private final List<Token> insertColumns=new ArrayList<>();
    private final Map<TableSource,Integer> depths=new IdentityHashMap<>();
    private List<Element> elements;private int at;
    private TableSourceParser(Dialect dialect,AnalysisBudget budget,Map<Integer,Integer> groupQueries,List<LanguageIssue> issues){this.dialect=dialect;this.budget=budget;this.groupQueries=groupQueries;this.issues=issues;}
    static Result parse(List<Element> elements,int main,String kind,Dialect dialect,AnalysisBudget budget,Map<Integer,Integer> groupQueries,List<LanguageIssue> issues){
        var parser=new TableSourceParser(dialect,budget,groupQueries,issues);return parser.query(elements,main,kind);
    }
    private Result query(List<Element> input,int main,String kind){
        elements=input;var sources=new ArrayList<TableSource>();
        for(int i=main;i<input.size();i++){
            budget.check();boolean update=i==main&&kind.equals("UPDATE");
            boolean insert=is(input.get(i),"INTO")&&Set.of("INSERT","REPLACE").contains(kind);
            boolean from=is(input.get(i),"FROM")||kind.equals("DELETE")&&is(input.get(i),"USING");
            if(!update&&!insert&&!from)continue;
            at=i+1;TableSource source=insert?factor(true):list(update||kind.equals("DELETE")&&sources.isEmpty());
            if(source!=null)sources.add(source);else issues.add(LanguageIssue.syntax("syntax.expected-relation",input.get(i).end(),input.get(i).end(),"Expected a relation"));
            i=Math.max(i,at-1);
        }
        var relations=new ArrayList<Relation>();for(var source:sources)collect(source,relations);
        return new Result(List.copyOf(relations),List.copyOf(sources),List.copyOf(insertColumns));
    }
    private TableSource list(boolean target){
        TableSource source=joined(target);while(source!=null&&peek(",")){at++;var right=joined(false);if(right==null)break;source=bounded(new JoinedSource(source,right,JoinKind.COMMA,false,List.of(),List.of(),source.start(),right.end()));}return source;
    }
    private TableSource joined(boolean target){
        TableSource source=factor(target);
        while(source!=null&&at<elements.size()&&joinStart(at)){
            budget.check();int begin=at;boolean natural=take("NATURAL");JoinKind kind=JoinKind.INNER;
            if(take("LEFT"))kind=JoinKind.LEFT;else if(take("RIGHT"))kind=JoinKind.RIGHT;else if(take("FULL"))kind=JoinKind.FULL;else if(take("CROSS"))kind=JoinKind.CROSS;else take("INNER");
            take("OUTER");if(!take("JOIN")&&!take("STRAIGHT_JOIN")){at=begin;break;}
            if(kind==JoinKind.FULL&&!dialect.postgres())issues.add(LanguageIssue.syntax("dialect.full-join",elements.get(begin).start(),elements.get(at-1).end(),"FULL JOIN is unavailable in this engine release"));
            TableSource right=factor(false);if(right==null){issues.add(LanguageIssue.syntax("syntax.expected-relation",elements.get(at-1).end(),elements.get(at-1).end(),"Expected a joined relation"));break;}
            var using=new ArrayList<Token>();List<Element> condition=List.of();
            if(take("USING")){
                if(at<elements.size()&&elements.get(at) instanceof Group group){
                    boolean expected=true;for(var element:group.body()){
                        if(expected&&name(element)!=null){using.add(name(element));expected=false;}
                        else if(!expected&&is(element,","))expected=true;
                        else issues.add(LanguageIssue.syntax("syntax.using-column",element.start(),element.end(),"Expected a column name in USING"));
                    }
                    if(using.isEmpty()||expected)issues.add(LanguageIssue.syntax("syntax.using-column",group.start(),group.end(),"Expected a column name in USING"));at++;
                }else issues.add(LanguageIssue.syntax("syntax.expected-using-columns",elements.get(at-1).end(),elements.get(at-1).end(),"Expected USING column list"));
            }else if(take("ON")){
                int start=at;while(at<elements.size()&&!peek(",")&&!joinStart(at)&&!end(at))at++;condition=elements.subList(start,at);
            }
            source=bounded(new JoinedSource(source,right,kind,natural,using,condition,source.start(),at==0?right.end():Math.max(right.end(),elements.get(at-1).end())));
        }
        return source;
    }
    private TableSource factor(boolean target){
        while(peek("ONLY")||peek("LOW_PRIORITY")||peek("IGNORE"))at++;
        boolean lateral=take("LATERAL");if(at>=elements.size()||end(at)||joinStart(at)||peek("USING"))return null;
        int start=at;Name relationName=null;Integer derived=null;TableSource nested=null;
        if(elements.get(at) instanceof Group group){
            derived=groupQueries.get(group.start());at++;
            if(derived==null){
                var outer=elements;int after=at;elements=group.body();at=0;nested=list(target);
                if(at<elements.size())issues.add(LanguageIssue.unavailable(elements.get(at).start(),group.end(),"This grouped table source is not supported"));
                elements=outer;at=after;if(nested==null)return null;
            }
        }else{
            Token first=name(elements.get(at));if(first==null||first.kind()==Kind.WORD&&(END.contains(first.text().toUpperCase(Locale.ROOT))||first.is("SELECT")))return null;
            var parts=new ArrayList<Token>();parts.add(first);at++;
            while(at+1<elements.size()&&peek(".")&&name(elements.get(at+1))!=null){parts.add(name(elements.get(at+1)));at+=2;}
            relationName=new Name(parts);
            if(at<elements.size()&&elements.get(at) instanceof Group&&!target){
                var group=(Group)elements.get(at++);issues.add(LanguageIssue.unavailable(first.start(),group.end(),"Table-valued function output requires a verified return structure"));return null;
            }
        }
        boolean as=take("AS");Token alias=at<elements.size()?name(elements.get(at)):null;
        if(alias!=null&&alias.kind()==Kind.WORD&&(Dialect.KEYWORDS.contains(alias.text().toUpperCase(Locale.ROOT))||JOIN.contains(alias.text().toUpperCase(Locale.ROOT))||alias.is("USING")))alias=null;
        if(alias!=null)at++;else if(as)issues.add(LanguageIssue.syntax("syntax.expected-alias",elements.get(at-1).end(),elements.get(at-1).end(),"Expected an alias"));
        int declarationEnd=elements.get(Math.max(start,at-1)).end();var aliases=new ArrayList<Token>();
        if(at<elements.size()&&elements.get(at) instanceof Group group&&groupQueries.get(group.start())==null){for(var element:group.body())if(name(element)!=null)aliases.add(name(element));if(target)insertColumns.addAll(aliases);at++;}
        int end=elements.get(Math.max(start,at-1)).end();
        if(nested!=null){if(alias!=null&&!dialect.postgres())issues.add(LanguageIssue.unavailable(alias.start(),end,"An alias on a grouped joined table is unavailable in this engine release"));return bounded(new GroupedSource(nested,alias,aliases,elements.get(start).start(),end));}
        return bounded(new RelationSource(new Relation(relationName,alias,derived,lateral,target,aliases,elements.get(start).start(),target?declarationEnd:end)));
    }
    private TableSource bounded(TableSource source){
        int depth=source instanceof JoinedSource join?1+Math.max(depths.get(join.left()),depths.get(join.right())):source instanceof GroupedSource group?1+depths.get(group.source()):1;
        if(depth>AnalysisBudget.MAX_DEPTH)throw new AnalysisBudget.Limit("SQL nesting exceeds 64 levels");depths.put(source,depth);return source;
    }
    private boolean end(int index){return elements.get(index) instanceof Leaf leaf&&leaf.token().kind()==Kind.WORD&&END.contains(leaf.token().text().toUpperCase(Locale.ROOT));}
    private boolean joinStart(int index){
        if(is(elements.get(index),"JOIN")||is(elements.get(index),"STRAIGHT_JOIN"))return true;
        int next=index;if(is(elements.get(next),"NATURAL"))next++;
        if(next<elements.size()&&(is(elements.get(next),"LEFT")||is(elements.get(next),"RIGHT")||is(elements.get(next),"FULL"))){next++;if(next<elements.size()&&is(elements.get(next),"OUTER"))next++;}
        else if(next<elements.size()&&(is(elements.get(next),"INNER")||is(elements.get(next),"CROSS")))next++;
        return next>index&&next<elements.size()&&is(elements.get(next),"JOIN");
    }
    private boolean peek(String word){return at<elements.size()&&is(elements.get(at),word);}
    private boolean take(String word){if(!peek(word))return false;at++;return true;}
    private static void collect(TableSource source,List<Relation> result){if(source instanceof RelationSource relation)result.add(relation.relation());else if(source instanceof JoinedSource join){collect(join.left(),result);collect(join.right(),result);}else if(source instanceof GroupedSource group)collect(group.source(),result);}
}
