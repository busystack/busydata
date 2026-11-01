package io.busystack.busydata.analysis.language;

import java.util.*;
import io.busystack.busydata.analysis.language.LosslessLexer.Token;
import io.busystack.busydata.analysis.language.SyntaxTree.*;

/** Source-bound expression nodes. Tokens and groups are retained, never rewritten. */
public final class ExpressionSyntax {
    private ExpressionSyntax(){}
    public sealed interface Node permits Literal,Reference,Unary,Binary,Cast,Conditional,Call,Predicate,Array,Subscript,Subquery,Decoration,Opaque {
        int start();int end();
        default List<Node> children(){return List.of();}
    }
    public record Literal(Token token) implements Node {public int start(){return token.start();}public int end(){return token.end();}}
    public record Reference(Name name) implements Node {public int start(){return name.start();}public int end(){return name.end();}}
    public record Unary(String operator,Node operand,int start,int end) implements Node {public List<Node> children(){return List.of(operand);}}
    public record Binary(String operator,Node left,Node right,int start,int end) implements Node {public List<Node> children(){return List.of(left,right);}}
    public record Cast(Node value,String nativeName,int start,int end) implements Node {public List<Node> children(){return List.of(value);}}
    public record Arm(Node condition,Node result){}
    public record Conditional(Node operand,List<Arm> arms,Node otherwise,int start,int end) implements Node {
        public Conditional {arms=List.copyOf(arms);}
        public List<Node> children(){var result=new ArrayList<Node>();if(operand!=null)result.add(operand);for(var arm:arms){result.add(arm.condition());result.add(arm.result());}if(otherwise!=null)result.add(otherwise);return result;}
    }
    public record Call(Name name,Group arguments,List<Node> values,int start,int end) implements Node {
        public Call {values=List.copyOf(values);}public List<Node> children(){return values;}
    }
    public record Predicate(String operator,List<Node> values,int start,int end) implements Node {
        public Predicate {values=List.copyOf(values);}public List<Node> children(){return values;}
    }
    public record Array(List<Node> values,int start,int end) implements Node {public Array{values=List.copyOf(values);}public List<Node> children(){return values;}}
    public record Subscript(Node value,Node index,int start,int end) implements Node {public List<Node> children(){return List.of(value,index);}}
    public record Subquery(Group group) implements Node {public int start(){return group.start();}public int end(){return group.end();}}
    public record Decoration(String clause,Node value,List<Node> expressions,int start,int end) implements Node {
        public Decoration{expressions=List.copyOf(expressions);}public List<Node> children(){var result=new ArrayList<Node>();result.add(value);result.addAll(expressions);return result;}
    }
    public record Opaque(int start,int end,String reason) implements Node {}
}
