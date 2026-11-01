package io.busystack.busydata.analysis.language;

import java.math.BigInteger;
import java.util.*;
import io.busystack.busydata.protocol.Engine;
import io.busystack.busydata.analysis.language.NumericShape.Origin;
import io.busystack.busydata.analysis.language.SqlTypes.*;
import static io.busystack.busydata.analysis.language.SqlTypes.*;

/** Pinned native integer metadata rules. Display-width facts are not inferred
 * from a value's minimum storage width. All folding is bounded to 65 bits. */
final class NativeNumericTypes {
    private NativeNumericTypes(){}
    static Type declared(Type type,Engine engine){
        if(engine==Engine.POSTGRESQL)return type;
        if(type.family()==Family.INTEGER){int bits=type.integerBits();if(bits==0)return type;
            int digits=bits==8?3:bits==16?5:bits==24?8:bits==32?10:type.unsigned()?20:19;
            return shaped(type,new NumericShape(digits+(type.unsigned()?0:1),digits,false,type.unsigned(),null,Origin.DECLARED));
        }
        if(type.family()==Family.DECIMAL&&type.precision()>0){
            long digits=(long)type.precision()-type.scale(),width=(long)type.precision()+(type.scale()>0?1:0)+(type.unsigned()?0:1);
            if(type.precision()>65||type.scale()<0||type.scale()>type.precision()||digits<0||width>Integer.MAX_VALUE)return shaped(type,NumericShape.UNKNOWN);
            return shaped(type,new NumericShape((int)width,(int)digits,false,type.unsigned(),null,Origin.DECLARED));
        }
        if(type.family()==Family.TEXT&&type.precision()>0)return shaped(type,new NumericShape(type.precision(),Math.min(65,type.precision()),false,false,null,Origin.DECLARED));
        return type;
    }
    static Type integerLiteral(Type classified,String source,BigInteger value,Engine engine){
        if(engine==Engine.POSTGRESQL||classified.family()!=Family.INTEGER)return classified;
        int width=source.length()+(engine==Engine.MYSQL&&!classified.unsigned()?1:0);int digits=source.length();
        var shape=new NumericShape(width,digits,true,value.signum()>=0,value,Origin.LITERAL);
        return integer(engine,width,classified.unsigned(),false,shape,false);
    }
    static Type stringLiteral(Type type,String source,Engine engine){
        if(engine==Engine.POSTGRESQL||source.length()<2)return type;
        String content=source.substring(1,source.length()-1);
        // Escaped/introduced strings need captured character-set interpretation.
        // Never guess their native width from source bytes.
        if(content.indexOf('\\')>=0||content.indexOf(source.charAt(0))>=0)return type;
        int width=content.codePointCount(0,content.length());return shaped(type,new NumericShape(width,Math.min(65,width),true,false,null,Origin.LITERAL));
    }
    static Type negativeLiteral(Type value,Engine engine){
        var shape=value.numericShape();if(!shape.known()||shape.exact()==null)return unaryMinus(value,engine);
        BigInteger negative=shape.exact().negate();int width=shape.characters()+(engine==Engine.MARIADB?1:0);
        if(negative.bitLength()>63&&negative.signum()<0)return nullable(nativeType("decimal",engine),value.nullable());
        return integer(engine,width,false,value.nullable(),new NumericShape(width,shape.integerDigits(),true,negative.signum()>=0,negative,Origin.LITERAL),false);
    }
    static Type unaryMinus(Type value,Engine engine){
        var input=value.numericShape();if(!input.known())return engine==Engine.MYSQL?nullable(nativeType("bigint",engine),value.nullable()):unknownInteger(false,value.nullable(),input);
        int width=input.characters()+(engine==Engine.MARIADB||value.unsigned()?1:0);if(engine==Engine.MYSQL&&width==1)width++;BigInteger exact=fold("negate",input.exact(),null);
        if(input.exact()!=null&&(input.exact().compareTo(BigInteger.ONE.shiftLeft(63))>0||input.exact().equals(BigInteger.ONE.shiftLeft(63).negate())))return nullable(nativeType("decimal",engine),value.nullable());
        var shape=new NumericShape(width,Math.max(1,width-1),input.constant(),exact!=null&&exact.signum()>=0,exact,Origin.EXPRESSION);
        return integer(engine,width,false,value.nullable(),shape,false);
    }
    static Type arithmetic(String operator,Type left,Type right,Dialect dialect,boolean nullable){
        Engine engine=dialect.engine();var a=left.numericShape();var b=right.numericShape();boolean initialUnsigned=operator.equals("%")||operator.equals("MOD")?left.unsigned():left.unsigned()||right.unsigned();
        boolean unsigned=initialUnsigned&&!(operator.equals("-")&&dialect.lexical().noUnsignedSubtraction());
        nullable|=Set.of("DIV","%","MOD").contains(operator);
        if(!a.known()||!b.known())return engine==Engine.MYSQL?nullable(nativeType("bigint"+(unsigned?" unsigned":""),engine),nullable):unknownInteger(unsigned,nullable,NumericShape.UNKNOWN);
        int digits=switch(operator){case "+","-"->Math.max(a.integerDigits(),b.integerDigits())+1;case "*"->Math.min(65,a.integerDigits()+b.integerDigits());case "DIV"->Math.min(21,a.integerDigits()+(engine==Engine.MYSQL?Math.max(0,right.scale()):0));case "%","MOD"->Math.max(a.integerDigits(),b.integerDigits());default->-1;};
        if(digits<0)return unknownInteger(unsigned,nullable,NumericShape.UNKNOWN);
        // Maria selects the native handler before NO_UNSIGNED_SUBTRACTION
        // switches signedness. The observed display width is retained.
        int width=digits+(operator.equals("DIV")&&engine==Engine.MARIADB?0:initialUnsigned?0:1);BigInteger exact=fold(operator,a.exact(),b.exact());
        boolean nonNegative=unsigned||exact!=null&&exact.signum()>=0||Set.of("+","*","DIV").contains(operator)&&a.nonNegative()&&b.nonNegative()||Set.of("%","MOD").contains(operator)&&a.nonNegative();
        var shape=new NumericShape(width,operator.equals("DIV")&&engine==Engine.MARIADB&&!unsigned||operator.equals("-")&&initialUnsigned&&!unsigned?Math.max(0,width-1):digits,a.constant()&&b.constant(),nonNegative,exact,Origin.EXPRESSION);
        return integer(engine,width,unsigned,nullable,shape,false);
    }
    static Type castInteger(Type source,boolean unsigned,Dialect dialect){
        Engine engine=dialect.engine();var input=source.numericShape();BigInteger exact=input.exact();
        if(unsigned&&exact!=null&&exact.signum()<0)exact=exact.mod(BigInteger.ONE.shiftLeft(64));
        if(!unsigned&&exact!=null&&source.unsigned()&&exact.compareTo(BigInteger.ONE.shiftLeft(63))>=0)exact=exact.subtract(BigInteger.ONE.shiftLeft(64));
        boolean nonNegative=unsigned||exact!=null&&exact.signum()>=0||!source.unsigned()&&input.nonNegative();
        if(engine==Engine.MYSQL)return integer(engine,21,unsigned,source.nullable(),new NumericShape(21,unsigned?21:20,input.constant(),nonNegative,exact,Origin.CAST),false);
        if(source.family()==Family.NULL)return integer(engine,unsigned?1:2,unsigned,true,new NumericShape(unsigned?1:2,1,true,unsigned,null,Origin.CAST),unsigned);
        if(source.family()==Family.REAL)return integer(engine,20,unsigned,source.nullable(),new NumericShape(20,unsigned?20:19,input.constant(),unsigned,null,Origin.CAST),unsigned);
        if(!input.known())return unknownInteger(unsigned,source.nullable(),input);
        int width;
        if(unsigned&&!source.unsigned()&&(source.family()==Family.TEXT?input.characters()>1:!input.nonNegative()))width=20;
        else width=Math.max(unsigned?1:2,Math.min(21,input.characters()));
        int digits=unsigned?width:input.integerDigits();var shape=new NumericShape(width,digits,input.constant(),nonNegative,exact,Origin.CAST);
        return integer(engine,width,unsigned,source.nullable(),shape,unsigned);
    }
    static Type absolute(Type source,Engine engine){
        var shape=source.numericShape();if(!shape.known())return engine==Engine.MYSQL?nullable(nativeType("bigint"+(source.unsigned()?" unsigned":""),engine),source.nullable()):unknownInteger(source.unsigned(),source.nullable(),shape);
        BigInteger exact=shape.exact()==null?null:shape.exact().abs();if(exact!=null&&exact.bitLength()>65)exact=null;return integer(engine,shape.characters(),source.unsigned(),source.nullable(),new NumericShape(shape.characters(),shape.integerDigits(),shape.constant(),true,exact,Origin.FUNCTION),false);
    }
    static Type commonShape(Type result,List<Type> inputs,Engine engine){
        if(engine==Engine.POSTGRESQL||result.family()!=Family.INTEGER)return result;
        var known=inputs.stream().filter(t->t.family()!=Family.NULL&&t.family()!=Family.UNKNOWN).toList();if(known.isEmpty()||known.stream().anyMatch(t->!t.numericShape().known()))return shaped(result,NumericShape.UNKNOWN);
        int width=known.stream().mapToInt(t->engine==Engine.MARIADB?t.numericShape().integerDigits()+(t.unsigned()?0:1):t.numericShape().characters()).max().orElse(0),digits=known.stream().mapToInt(t->t.numericShape().integerDigits()).max().orElse(0);
        return shaped(result,new NumericShape(width,digits,false,known.stream().allMatch(t->t.unsigned()||t.numericShape().nonNegative()),null,Origin.FUNCTION));
    }
    static Type materialized(Type source,boolean guaranteed,boolean typeHolder,Engine engine){
        var shape=source.numericShape();if(source.family()!=Family.INTEGER||engine!=Engine.MYSQL||typeHolder||shape.origin()==Origin.FIELD||shape.origin()==Origin.DECLARED)return queryField(source,engine);
        if(!shape.known())return unknownInteger(source.unsigned(),source.nullable(),shape.field(source.unsigned()));
        if(shape.characters()>=10)return field(source);
        if(!guaranteed)return unknownInteger(source.unsigned(),source.nullable(),shape.field(source.unsigned()));
        Type narrowed=nativeType("integer"+(source.unsigned()?" unsigned":""),engine);return shaped(nullable(narrowed,source.nullable()),shape.field(source.unsigned()));
    }
    static Type field(Type type){return shaped(type,type.numericShape().field(type.unsigned()));}
    static Type queryField(Type type,Engine engine){
        var shape=type.numericShape();if(engine==Engine.MARIADB&&type.family()==Family.INTEGER&&shape.known()){
            // Field_int::type_numeric_attributes reserves the complete native
            // range, even for a temporary INT(1). A scalar subquery is an Item,
            // not an Item_field, and deliberately keeps its narrower evidence.
            var capacity=declared(type,engine).numericShape();
            int width=Math.max(shape.characters(),capacity.known()?capacity.characters():0);
            shape=new NumericShape(width,Math.max(0,width-(type.unsigned()?0:1)),false,type.unsigned(),null,Origin.FIELD);
        }
        return shaped(type,shape.field(type.unsigned()));
    }
    static Type scalar(Type type,Engine engine){
        var shape=type.numericShape();if(!shape.known())return type;int width=engine==Engine.MARIADB&&type.family()==Family.INTEGER?shape.integerDigits()+(type.unsigned()?0:1):shape.characters();
        return shaped(type,new NumericShape(width,shape.integerDigits(),false,shape.nonNegative(),null,Origin.SUBQUERY));
    }

    static Type unknownInteger(boolean unsigned,boolean nullable,NumericShape shape){return new Type(Family.INTEGER,"",java.sql.Types.BIGINT,0,0,unsigned,nullable,null,false,shape);}
    private static Type integer(Engine engine,int width,boolean unsigned,boolean nullable,NumericShape shape,boolean unsignedCast){
        boolean narrow=engine==Engine.MARIADB&&width<=(unsignedCast?10:9);return shaped(nullable(nativeType((narrow?"integer":"bigint")+(unsigned?" unsigned":""),engine),nullable),shape);
    }
    private static BigInteger fold(String operator,BigInteger left,BigInteger right){
        if(left==null||!operator.equals("negate")&&right==null)return null;BigInteger value=switch(operator){case "+"->left.add(right);case "-"->left.subtract(right);case "*"->left.multiply(right);case "DIV"->right.signum()==0?null:left.divide(right);case "%","MOD"->right.signum()==0?null:left.remainder(right);case "negate"->left.negate();default->null;};return value!=null&&value.bitLength()<=65?value:null;
    }
}
