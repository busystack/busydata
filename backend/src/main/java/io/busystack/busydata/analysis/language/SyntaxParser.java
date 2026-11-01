package io.busystack.busydata.analysis.language;

import java.util.*;
import io.busystack.busydata.analysis.language.LosslessLexer.*;
import io.busystack.busydata.analysis.language.SyntaxTree.*;
import static io.busystack.busydata.analysis.language.SyntaxTree.*;

/** Grammar-oriented recovery for query blocks, declarations, sources and projections.
 * Expressions retain their original token tree rather than being reserialized. */
public final class SyntaxParser {
    private static final Set<String> COMMANDS=Set.of("SELECT","WITH","VALUES","INSERT","UPDATE","DELETE","REPLACE","TABLE");
    private static final Set<String> CLAUSES=Set.of("SELECT","FROM","WHERE","GROUP","HAVING","WINDOW","ORDER","LIMIT","OFFSET","FETCH","RETURNING","SET","VALUES","ON","USING");
    private final Document document;private final AnalysisBudget budget;private final List<Token> tokens;private int cursor;
    private final List<Query> queries=new ArrayList<>();private final List<LanguageIssue> issues=new ArrayList<>();
    private final Map<Integer,Integer> groupQueries=new HashMap<>();
    private SyntaxParser(Document document,AnalysisBudget budget){this.document=document;this.budget=budget;tokens=document.significant();}
    public static SyntaxTree parse(Document document,AnalysisBudget budget){return new SyntaxParser(document,budget).parse();}
    private SyntaxTree parse(){
        if(document.dialect().postgres())for(int i=0;i+2<tokens.size();i++){var prefix=tokens.get(i);var ampersand=tokens.get(i+1);var quoted=tokens.get(i+2);if(prefix.is("U")&&ampersand.is("&")&&prefix.end()==ampersand.start()&&ampersand.end()==quoted.start()&&(quoted.kind()==Kind.IDENTIFIER||quoted.kind()==Kind.STRING))return new SyntaxTree(document,List.of(new Query(0,null,0,document.source().length(),"UNICODE_ESCAPE",List.of(),List.of(),List.of(),List.of(),List.of(),List.of(),List.of(),List.of(),true)),List.of(LanguageIssue.unavailable(prefix.start(),quoted.end(),"Unicode escape literals and identifiers require interpretation unavailable in this language service")));}
        for(var token:tokens)if(token.kind()==Kind.ERROR)return new SyntaxTree(document,List.of(new Query(0,null,0,document.source().length(),"LEXICAL_UNAVAILABLE",List.of(),List.of(),List.of(),List.of(),List.of(),List.of(),List.of(),List.of(),true)),List.of(LanguageIssue.unavailable(token.start(),token.end(),"This token is unavailable in the captured SQL dialect; semantic analysis is limited")));
        if(!document.dialect().postgres())for(var token:document.tokens())if(token.kind()==Kind.COMMENT&&(token.text().startsWith("/*!")||token.text().toUpperCase(Locale.ROOT).startsWith("/*M!"))){
            return new SyntaxTree(document,List.of(new Query(0,null,0,document.source().length(),"EXECUTABLE_COMMENT",List.of(),List.of(),List.of(),List.of(),List.of(),List.of(),List.of(),List.of(),true)),List.of(LanguageIssue.unavailable(token.start(),token.end(),"Versioned executable comments require server-specific interpretation; semantic analysis is unavailable for this statement")));
        }
        for(var token:document.tokens())if(!token.complete())issues.add(LanguageIssue.syntax("syntax.incomplete-token",token.start(),token.end(),"Unterminated SQL token"));
        var root=elements(0,null);int start=0;
        for(int i=0;i<=root.size();i++)if(i==root.size()||is(root.get(i),";")){
            if(i>start)query(root.subList(start,i),null,start==0?0:root.get(start).start(),i==root.size()?document.source().length():root.get(i).start());start=i+1;
        }
        if(queries.isEmpty())query(List.of(),null,0,document.source().length());
        return new SyntaxTree(document,queries,issues.stream().limit(64).toList());
    }
    private List<Element> elements(int depth,Token opener){
        if(depth>AnalysisBudget.MAX_DEPTH)throw new AnalysisBudget.Limit("SQL nesting exceeds 64 levels");
        var result=new ArrayList<Element>();
        while(cursor<tokens.size()){
            if((cursor&255)==0)budget.check();var token=tokens.get(cursor++);
            if(token.is(")")||token.is("]")){
                if(opener!=null){cursor--;return result;}
                issues.add(LanguageIssue.syntax("syntax.unexpected-close",token.start(),token.end(),"Unexpected closing delimiter"));result.add(new Leaf(token));
            }else if(token.is("(")||token.is("[")){
                var body=elements(depth+1,token);Token close=null;
                if(cursor<tokens.size()&&tokens.get(cursor).is(token.is("(")?")":"]"))close=tokens.get(cursor++);
                if(close==null)issues.add(LanguageIssue.syntax("syntax.missing-close",token.start(),token.end(),"Missing closing delimiter"));
                result.add(new Group(token,body,close,close==null?document.source().length():close.end()));
            }else result.add(new Leaf(token));
        }
        return result;
    }
    private int query(List<Element> elements,Integer parent,int start,int end){
        budget.check();if(queries.size()>=AnalysisBudget.MAX_SCOPES)throw new AnalysisBudget.Limit("SQL query-scope budget exceeded");
        int id=queries.size();queries.add(null);
        String first=firstWord(elements);boolean opaque=Set.of("DO","BEGIN","DECLARE").contains(first)||first.equals("CREATE")&&elements.stream().anyMatch(e->is(e,"FUNCTION")||is(e,"PROCEDURE")||is(e,"TRIGGER"));
        if(opaque){queries.set(id,new Query(id,parent,start,end,first,elements,List.of(),List.of(),List.of(),List.of(),List.of(),List.of(),List.of(),true));return id;}
        // Child query groups become semantic scopes; arithmetic and call groups do not.
        visitGroups(elements,id);
        if(elements.size()==1&&elements.getFirst() instanceof Group group&&groupQueries.containsKey(group.start())){
            queries.set(id,new Query(id,parent,start,end,"SET",elements,List.of(),List.of(),List.of(),List.of(),List.of(),List.of(groupQueries.get(group.start())),List.of(),false));return id;
        }
        var ctes=new ArrayList<Cte>();int main=0;
        if(!elements.isEmpty()&&is(elements.getFirst(),"WITH")){
            main=1;boolean recursive=main<elements.size()&&is(elements.get(main),"RECURSIVE");if(recursive)main++;
            while(main<elements.size()){
                Token name=name(elements.get(main));if(name==null)break;main++;
                var columns=new ArrayList<Token>();if(main<elements.size()&&elements.get(main) instanceof Group group&&groupQueries.get(group.start())==null){for(var e:group.body())if(name(e)!=null)columns.add(name(e));main++;}
                if(main>=elements.size()||!is(elements.get(main),"AS"))break;main++;
                if(main<elements.size()&&is(elements.get(main),"NOT"))main++;
                if(main<elements.size()&&is(elements.get(main),"MATERIALIZED"))main++;
                if(main>=elements.size()||!(elements.get(main) instanceof Group body)||!groupQueries.containsKey(body.start()))break;
                ctes.add(new Cte(name,columns,groupQueries.get(body.start()),recursive,ctes.size()));main++;
                if(main<elements.size()&&is(elements.get(main),",")){main++;continue;}break;
            }
        }
        var setPositions=new ArrayList<Integer>();for(int i=main;i<elements.size();i++)if(is(elements.get(i),"UNION")||is(elements.get(i),"INTERSECT")||is(elements.get(i),"EXCEPT"))setPositions.add(i);
        if(!setPositions.isEmpty()){
            var branches=new ArrayList<Integer>();int from=main;
            for(int position:setPositions){if(position>from)branches.add(query(elements.subList(from,position),id,elements.get(from).start(),elements.get(position).start()));from=position+1;if(from<elements.size()&&(is(elements.get(from),"ALL")||is(elements.get(from),"DISTINCT")))from++;}
            if(from<elements.size())branches.add(query(elements.subList(from,elements.size()),id,elements.get(from).start(),end));
            queries.set(id,new Query(id,parent,start,end,"SET",elements,List.of(),List.of(),ctes,List.of(),List.of(),branches,List.of(),false));return id;
        }
        String kind=main<elements.size()&&elements.get(main) instanceof Leaf leaf?leaf.token().text().toUpperCase(Locale.ROOT):first;
        var sourceSyntax=TableSourceParser.parse(elements,main,kind,document.dialect(),budget,groupQueries,issues);
        var relations=sourceSyntax.relations();var insertColumns=sourceSyntax.insertColumns();
        var clauses=new ArrayList<Clause>();int clauseStart=-1;String clauseName="";
        for(int i=main;i<=elements.size();i++){
            String next=i<elements.size()&&elements.get(i) instanceof Leaf leaf?leaf.token().text().toUpperCase(Locale.ROOT):"";
            if(i==elements.size()||CLAUSES.contains(next)){
                if(clauseStart>=0)clauses.add(new Clause(clauseName,elements.get(clauseStart).start(),i==elements.size()?end:elements.get(i).start(),elements.subList(clauseStart+1,i)));
                if(i<elements.size()){clauseStart=i;clauseName=next;}
            }
        }
        var projections=new ArrayList<Projection>();
        var select=clauses.stream().filter(c->c.name().equals("SELECT")||c.name().equals("RETURNING")).findFirst().orElse(null);
        if(select!=null){
            int from=0;var list=select.elements();while(from<list.size()&&(is(list.get(from),"DISTINCT")||is(list.get(from),"ALL")))from++;
            for(int i=from;i<=list.size();i++)if(i==list.size()||is(list.get(i),",")){if(i>from)projections.add(projection(list.subList(from,i)));from=i+1;}
            if(projections.isEmpty())issues.add(LanguageIssue.syntax("syntax.expected-projection",select.start(),Math.min(select.start()+6,end),"Expected a result expression"));
        }
        for(var clause:clauses){
            if(Set.of("WHERE","HAVING","ON","SET").contains(clause.name())&&clause.elements().isEmpty())issues.add(LanguageIssue.syntax("syntax.expected-expression",clause.end(),clause.end(),"Expected an expression"));
            if(!clause.elements().isEmpty()&&clause.elements().getLast() instanceof Leaf last&&(last.token().kind()==Kind.OPERATOR&&!last.token().is("*")||last.token().is(",")))issues.add(LanguageIssue.syntax("syntax.expected-expression",last.start(),last.end(),"Expected an expression after this token"));
        }
        if(kind.equals("UPDATE")&&clauses.stream().noneMatch(c->c.name().equals("SET")))issues.add(LanguageIssue.syntax("syntax.expected-set",end,end,"Expected SET assignments"));
        if(kind.equals("INSERT")&&clauses.stream().noneMatch(c->Set.of("VALUES","SELECT","SET").contains(c.name()))&&elements.stream().noneMatch(e->is(e,"DEFAULT")))issues.add(LanguageIssue.syntax("syntax.expected-insert-source",end,end,"Expected INSERT values or a query"));
        if(!COMMANDS.contains(kind)&&!Set.of("CREATE","ALTER","DROP","RENAME","TRUNCATE","COMMENT","USE","SET","RESET","DISCARD","COMMIT","ROLLBACK","CALL","EXPLAIN","SHOW","START").contains(kind)&&!elements.isEmpty())issues.add(LanguageIssue.unavailable(start,end,"Analysis is unavailable for this statement construct"));
        queries.set(id,new Query(id,parent,start,end,kind,elements,relations,sourceSyntax.sources(),ctes,projections,clauses,List.of(),insertColumns,false));return id;
    }
    private void visitGroups(List<Element> elements,int parent){for(var element:elements)if(element instanceof Group group){if(COMMANDS.contains(firstWord(group.body()))&&!groupQueries.containsKey(group.start())){int query=query(group.body(),parent,group.open().end(),group.close()==null?group.end():group.close().start());groupQueries.put(group.start(),query);}else visitGroups(group.body(),parent);}}
    private Projection projection(List<Element> expression){
        Token alias=null;int end=expression.size();
        if(end>=2&&name(expression.get(end-1))!=null){
            var candidate=name(expression.get(end-1));
            if(is(expression.get(end-2),"AS")){alias=candidate;end-=2;}
            else if(candidate.quoted()||!Dialect.KEYWORDS.contains(candidate.text().toUpperCase(Locale.ROOT))){
                var parsed=ExpressionParser.prefix(document.dialect(),budget,expression);
                if(parsed.complete()&&parsed.consumed()==end-1){alias=candidate;end--;}
            }
        }
        return new Projection(expression.subList(0,end),alias);
    }
    private static String firstWord(List<Element> elements){for(var element:elements)if(element instanceof Leaf leaf)return leaf.token().text().toUpperCase(Locale.ROOT);return "";}
}
