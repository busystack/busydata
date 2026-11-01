package io.busystack.busydata.analysis.language;

import java.math.BigDecimal;
import java.util.List;
import static io.busystack.busydata.analysis.language.SyntaxTree.*;

/** Only proven constant predicates influence the restricting-WHERE inspection. */
public final class SafetyInspections {
    private SafetyInspections(){}
    public static boolean restrictingWhere(Query query){
        var where=query.clauses().stream().filter(c->c.name().equals("WHERE")).findFirst().orElse(null);
        return where!=null&&!where.elements().isEmpty()&&!Boolean.TRUE.equals(constant(where.elements()));
    }
    private static Boolean constant(List<Element> expression){
        if(expression.size()==1&&expression.getFirst() instanceof Group group)return constant(group.body());
        if(expression.size()==1&&expression.getFirst() instanceof Leaf leaf&&!leaf.token().quoted()){
            if(leaf.token().is("TRUE"))return true;if(leaf.token().is("FALSE"))return false;
        }
        if(expression.size()==2&&is(expression.getFirst(),"NOT")){var value=constant(expression.subList(1,2));return value==null?null:!value;}
        if(expression.size()==3){
            if(is(expression.get(1),"AND")||is(expression.get(1),"OR")){
                var left=constant(expression.subList(0,1));var right=constant(expression.subList(2,3));
                if(is(expression.get(1),"OR")&&(Boolean.TRUE.equals(left)||Boolean.TRUE.equals(right)))return true;
                if(left!=null&&right!=null)return is(expression.get(1),"AND")?left&&right:left||right;
            }
            if(is(expression.get(1),"=")&&expression.getFirst() instanceof Leaf left&&expression.getLast() instanceof Leaf right&&
                left.token().kind()==LosslessLexer.Kind.NUMBER&&right.token().kind()==LosslessLexer.Kind.NUMBER){
                try{
                    if(left.token().text().length()>1024||right.token().text().length()>1024)return null;
                    var a=new BigDecimal(left.token().text());var b=new BigDecimal(right.token().text());
                    if(Math.abs((long)a.scale())>1024||Math.abs((long)b.scale())>1024)return null;
                    return a.compareTo(b)==0;
                }catch(NumberFormatException unavailable){return null;}
            }
        }
        return null;
    }
}
