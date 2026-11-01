package io.busystack.busydata.analysis.language;

import java.util.*;
import io.busystack.busydata.analysis.language.LosslessLexer.*;
import io.busystack.busydata.analysis.language.SyntaxTree.*;
import io.busystack.busydata.analysis.language.ExpressionSyntax.*;
import static io.busystack.busydata.analysis.language.SyntaxTree.*;

/** Bounded Pratt grammar for scalar expressions; execution never uses this parser. */
public final class ExpressionParser {
    private final Dialect dialect;private final AnalysisBudget budget;private final List<Element> elements;private final int depth;private int cursor;
    private ExpressionParser(Dialect dialect,AnalysisBudget budget,List<Element> elements,int depth){this.dialect=dialect;this.budget=budget;this.elements=elements;this.depth=depth;}
    public static Node parse(Dialect dialect,AnalysisBudget budget,List<Element> elements){return new ExpressionParser(dialect,budget,elements,0).whole();}
    /** Grammar consumption, used to distinguish an implicit result alias from
     * the final operand of an otherwise complete expression. */
    public record Prefix(Node syntax,int consumed,boolean complete){}
    public static Prefix prefix(Dialect dialect,AnalysisBudget budget,List<Element> elements){
        var parser=new ExpressionParser(dialect,budget,elements,0);budget.check();Node node=parser.expression(0,0);
        var pending=new ArrayDeque<Node>();pending.push(node);boolean complete=true;
        while(!pending.isEmpty()){budget.check();var next=pending.pop();if(next instanceof Opaque){complete=false;break;}for(var child:next.children())pending.push(child);}
        return new Prefix(node,parser.cursor,complete);
    }
    private Node whole(){
        budget.check();if(elements.isEmpty())return new Opaque(0,0,"Expression is incomplete");
        Node value=expression(0,depth);
        if(cursor<elements.size())return new Opaque(elements.getFirst().start(),elements.getLast().end(),"Expression syntax is not available for this construct");
        return value;
    }
    private Node expression(int minimum,int nesting){
        budget.check();if(nesting>=AnalysisBudget.MAX_DEPTH)throw new AnalysisBudget.Limit("SQL nesting exceeds 64 levels");
        Node left=prefix(nesting+1);
        while(cursor<elements.size()){
            budget.check();Element current=elements.get(cursor);String operator=word(current);
            if(operator.equals("::")&&120>=minimum){
                int start=left.start();cursor++;int from=cursor;consumeType();
                left=from==cursor?new Opaque(start,current.end(),"Cast type is incomplete"):new Cast(left,typeName(elements.subList(from,cursor)),start,elements.get(cursor-1).end());continue;
            }
            if(current instanceof Group group&&group.open().is("[")&&115>=minimum){cursor++;left=new Subscript(left,nested(group.body()),left.start(),group.end());continue;}
            if(operator.equals("COLLATE")&&105>=minimum){cursor++;if(cursor<elements.size()&&name(elements.get(cursor))!=null){cursor++;while(cursor+1<elements.size()&&is(elements.get(cursor),".")&&name(elements.get(cursor+1))!=null)cursor+=2;continue;}return new Opaque(left.start(),current.end(),"Collation name is incomplete");}
            // These postfix clauses preserve the function's result type. Their
            // independent clause grammar/binding remains in the query tree.
            if((operator.equals("OVER")||operator.equals("FILTER"))&&110>=minimum){
                cursor++;if(cursor<elements.size()&&elements.get(cursor) instanceof Group group){cursor++;var expressions=new ArrayList<Node>();
                    if(operator.equals("FILTER")){var body=group.body();if(!body.isEmpty()&&is(body.getFirst(),"WHERE"))expressions.add(nested(body.subList(1,body.size())));else expressions.add(new Opaque(group.start(),group.end(),"Aggregate FILTER condition is incomplete"));}
                    else for(var part:windowParts(group))expressions.add(nested(part));
                    left=new Decoration(operator,left,expressions,left.start(),group.end());continue;
                }
                if(operator.equals("OVER")&&cursor<elements.size()&&name(elements.get(cursor))!=null){Element window=elements.get(cursor++);left=new Decoration(operator,left,List.of(),left.start(),window.end());continue;}
                return new Opaque(left.start(),current.end(),"Window or filter clause is incomplete");
            }
            boolean negated=operator.equals("NOT")&&cursor+1<elements.size()&&Set.of("IN","BETWEEN","LIKE","ILIKE","REGEXP","RLIKE").contains(word(elements.get(cursor+1)));
            String actual=negated?word(elements.get(cursor+1)):operator;int precedence=precedence(actual);
            if(precedence<minimum||precedence<0)break;cursor+=negated?2:1;
            if(actual.equals("IS")){
                boolean not=take("NOT");if(take("DISTINCT")){if(!take("FROM"))return opaque(left,"IS DISTINCT FROM is incomplete");Node right=expression(precedence+1,nesting+1);left=new Predicate(not?"IS NOT DISTINCT FROM":"IS DISTINCT FROM",List.of(left,right),left.start(),right.end());}
                else if(cursor<elements.size()&&Set.of("NULL","TRUE","FALSE","UNKNOWN").contains(word(elements.get(cursor)))){Element last=elements.get(cursor++);left=new Predicate("IS "+(not?"NOT ":"")+word(last),List.of(left),left.start(),last.end());}
                else return opaque(left,"IS predicate is incomplete");
                continue;
            }
            if(actual.equals("BETWEEN")){
                take("SYMMETRIC");take("ASYMMETRIC");Node low=expression(precedence+1,nesting+1);if(!take("AND"))return opaque(left,"BETWEEN bounds are incomplete");Node high=expression(precedence+1,nesting+1);left=new Predicate(negated?"NOT BETWEEN":"BETWEEN",List.of(left,low,high),left.start(),high.end());continue;
            }
            if(actual.equals("IN")){
                if(cursor>=elements.size()||!(elements.get(cursor) instanceof Group group))return opaque(left,"IN list is incomplete");cursor++;
                var values=new ArrayList<Node>();values.add(left);if(query(group))values.add(new Subquery(group));else values.addAll(list(group.body(),nesting+1));
                left=new Predicate(negated?"NOT IN":"IN",values,left.start(),group.end());continue;
            }
            Node right=expression(precedence+1,nesting+1);left=new Binary((negated?"NOT ":"")+actual,left,right,left.start(),right.end());
        }
        return left;
    }
    private Node prefix(int nesting){
        if(cursor>=elements.size())return new Opaque(elements.isEmpty()?0:elements.getLast().end(),elements.isEmpty()?0:elements.getLast().end(),"Expression is incomplete");
        Element current=elements.get(cursor++);String value=word(current);
        if(Set.of("+","-","~","!","NOT").contains(value)){
            int precedence=value.equals("NOT")&&!dialect.lexical().highNotPrecedence()?30:value.equals("!")&&!dialect.postgres()?110:100;
            Node operand=expression(precedence,nesting);return new Unary(value,operand,current.start(),operand.end());
        }
        if(value.equals("EXISTS")&&cursor<elements.size()&&elements.get(cursor) instanceof Group group){cursor++;return new Predicate("EXISTS",List.of(new Subquery(group)),current.start(),group.end());}
        if(value.equals("CASE"))return conditional(current,nesting);
        if(value.equals("CAST")&&cursor<elements.size()&&elements.get(cursor) instanceof Group group){
            cursor++;int separator=-1,caseDepth=0;
            for(int i=0;i<group.body().size();i++){if(is(group.body().get(i),"CASE"))caseDepth++;if(is(group.body().get(i),"END"))caseDepth--;if(caseDepth==0&&is(group.body().get(i),"AS")){separator=i;break;}}
            if(separator<1||separator+1>=group.body().size()||!group.complete())return new Opaque(current.start(),group.end(),"CAST expression is incomplete");
            return new Cast(nested(group.body().subList(0,separator)),typeName(group.body().subList(separator+1,group.body().size())),current.start(),group.end());
        }
        if(value.equals("ARRAY")&&cursor<elements.size()&&elements.get(cursor) instanceof Group group&&group.open().is("[")){cursor++;return new ExpressionSyntax.Array(list(group.body(),nesting),current.start(),group.end());}
        if(current instanceof Group group){if(!group.complete())return new Opaque(group.start(),group.end(),"Parenthesized expression is incomplete");return query(group)?new Subquery(group):nested(group.body());}
        if(current instanceof Leaf leaf){
            Token token=leaf.token();if(Set.of(Kind.STRING,Kind.NUMBER,Kind.PARAMETER).contains(token.kind())||Set.of("NULL","TRUE","FALSE","*").contains(value))return new Literal(token);
            if(token.name()){
                if(cursor<elements.size()&&elements.get(cursor) instanceof Leaf literal&&literal.token().kind()==Kind.STRING){
                    if(Set.of("DATE","TIME","TIMESTAMP","INTERVAL","JSON","JSONB","UUID").contains(value)){cursor++;if(!dialect.postgres()&&value.equals("INTERVAL")&&cursor<elements.size()&&name(elements.get(cursor))!=null)cursor++;return new Cast(new Literal(literal.token()),value.toLowerCase(Locale.ROOT),token.start(),elements.get(cursor-1).end());}
                    if(Set.of("E","N","B","X").contains(value)&&token.end()==literal.start()){cursor++;return Set.of("B","X").contains(value)?new Cast(new Literal(literal.token()),dialect.postgres()?"bit":"binary",token.start(),literal.end()):new Literal(literal.token());}
                }
                var parts=new ArrayList<Token>();parts.add(token);
                while(cursor+1<elements.size()&&is(elements.get(cursor),".")&&name(elements.get(cursor+1))!=null){parts.add(name(elements.get(cursor+1)));cursor+=2;}
                var name=new Name(parts);
                if(cursor<elements.size()&&elements.get(cursor) instanceof Group group&&group.open().is("(")){
                    cursor++;if(!group.complete())return new Opaque(name.start(),group.end(),"Routine arguments are incomplete");
                    var body=group.body();if(!body.isEmpty()&&(is(body.getFirst(),"DISTINCT")||is(body.getFirst(),"ALL")))body=body.subList(1,body.size());
                    return new Call(name,group,list(body,nesting),name.start(),group.end());
                }
                return new Reference(name);
            }
        }
        return new Opaque(current.start(),current.end(),"Expression syntax is not available for this construct");
    }
    private Node conditional(Element beginning,int nesting){
        Node operand=peek("WHEN")?null:expression(0,nesting);var arms=new ArrayList<Arm>();
        while(take("WHEN")){Node condition=expression(0,nesting);if(!take("THEN"))return opaqueFrom(beginning,"CASE branch is incomplete");Node result=expression(0,nesting);arms.add(new Arm(condition,result));}
        Node otherwise=take("ELSE")?expression(0,nesting):null;
        if(arms.isEmpty()||!take("END"))return opaqueFrom(beginning,"CASE expression is incomplete");
        return new Conditional(operand,arms,otherwise,beginning.start(),elements.get(cursor-1).end());
    }
    private Node nested(List<Element> body){return new ExpressionParser(dialect,budget,body,depth+1).whole();}
    private List<Node> list(List<Element> body,int nesting){
        if(body.isEmpty())return List.of();var result=new ArrayList<Node>();int from=0,caseDepth=0;
        for(int i=0;i<=body.size();i++){
            budget.check();if(i<body.size()){if(is(body.get(i),"CASE"))caseDepth++;else if(is(body.get(i),"END"))caseDepth--;}
            if(i==body.size()||caseDepth==0&&is(body.get(i),",")){result.add(new ExpressionParser(dialect,budget,body.subList(from,i),Math.max(depth+1,nesting)).whole());from=i+1;}
        }return List.copyOf(result);
    }
    private void consumeType(){
        if(cursor>=elements.size()||name(elements.get(cursor))==null)return;cursor++;
        while(cursor<elements.size()){
            Element next=elements.get(cursor);String word=word(next);
            if(next instanceof Group group&&(group.open().is("(")||group.open().is("["))){cursor++;continue;}
            if(word.equals(".")&&cursor+1<elements.size()&&name(elements.get(cursor+1))!=null){cursor+=2;continue;}
            if(Set.of("PRECISION","VARYING","WITH","WITHOUT","TIME","ZONE","UNSIGNED","SIGNED","INTEGER").contains(word)){cursor++;continue;}break;
        }
    }
    private int precedence(String operator){
        if(operator.equals("OR")||operator.equals("||")&&!dialect.postgres()&&!dialect.lexical().pipesAsConcat())return 10;
        if(operator.equals("XOR"))return dialect.postgres()?-1:15;
        if(operator.equals("AND")||operator.equals("&&")&&!dialect.postgres())return 20;
        if(operator.equals("IS"))return 40;
        if(Set.of("=","<>","!=","<",">","<=",">=","<=>").contains(operator))return dialect.postgres()?45:40;
        if(Set.of("BETWEEN","IN","LIKE","ILIKE","REGEXP","RLIKE").contains(operator))return dialect.postgres()?50:35;
        if(Set.of("|","&","#","<<",">>").contains(operator))return dialect.postgres()?60:operator.equals("|")?50:operator.equals("&")?55:60;
        if(operator.equals("||"))return dialect.postgres()?60:95;
        if(Set.of("+","-").contains(operator))return 70;
        if(Set.of("*","/","%","DIV","MOD").contains(operator))return 80;
        if(operator.equals("^"))return 90;
        if(Set.of("->","->>","#>","#>>","@>","<@","?|","?&","@?","@@","~","~*","!~","!~*").contains(operator))return 60;
        return -1;
    }
    private static boolean query(Group group){return !group.body().isEmpty()&&(is(group.body().getFirst(),"SELECT")||is(group.body().getFirst(),"WITH")||is(group.body().getFirst(),"VALUES"));}
    /** Query-scope expressions inside a window declaration. Frame grammar is
     * independent of result typing; its keywords are never column references. */
    public static List<List<Element>> windowParts(Group group){
        var result=new ArrayList<List<Element>>();var body=group.body();int from=-1;
        for(int i=0;i<=body.size();i++){
            boolean clause=i<body.size()&&(is(body.get(i),"PARTITION")||is(body.get(i),"ORDER"));
            boolean frame=i<body.size()&&(is(body.get(i),"ROWS")||is(body.get(i),"RANGE")||is(body.get(i),"GROUPS"));
            if(i==body.size()||clause||frame||i<body.size()&&is(body.get(i),",")){
                if(from>=0&&i>from){int end=i;if(end-from>=2&&is(body.get(end-2),"NULLS")&&(is(body.get(end-1),"FIRST")||is(body.get(end-1),"LAST")))end-=2;if(end>from&&(is(body.get(end-1),"ASC")||is(body.get(end-1),"DESC")))end--;if(end>from)result.add(body.subList(from,end));}
                from=clause?i+1:from>=0&&!frame?i+1:-1;if(from>=0&&from<body.size()&&is(body.get(from),"BY"))from++;
                if(frame)break;
            }
        }return List.copyOf(result);
    }
    private boolean peek(String text){return cursor<elements.size()&&is(elements.get(cursor),text);}
    private boolean take(String text){if(!peek(text))return false;cursor++;return true;}
    private Node opaque(Node from,String reason){return new Opaque(from.start(),cursor==0?from.end():elements.get(cursor-1).end(),reason);}
    private Node opaqueFrom(Element from,String reason){return new Opaque(from.start(),cursor==0?from.end():elements.get(cursor-1).end(),reason);}
    private static String word(Element element){return element instanceof Leaf leaf?leaf.token().text().toUpperCase(Locale.ROOT):"";}
    private static String typeName(List<Element> elements){
        StringBuilder out=new StringBuilder();for(var element:elements){String text=element instanceof Leaf leaf?leaf.token().text():element instanceof Group group?group.open().text()+typeName(group.body())+(group.close()==null?"":group.close().text()):"";
            if(!out.isEmpty()&&!text.equals(".")&&!text.equals(",")&&!text.startsWith("(")&&!text.startsWith("[")&&out.charAt(out.length()-1)!='.')out.append(' ');out.append(text);}
        return out.toString();
    }
}
