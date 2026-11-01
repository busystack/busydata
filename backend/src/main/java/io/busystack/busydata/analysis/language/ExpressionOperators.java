package io.busystack.busydata.analysis.language;

import java.util.*;
import java.util.function.Consumer;
import io.busystack.busydata.protocol.Engine;
import io.busystack.busydata.analysis.language.RoutineSignatures.*;
import io.busystack.busydata.analysis.language.ExpressionSyntax.Node;
import io.busystack.busydata.analysis.language.SqlTypes.*;
import static io.busystack.busydata.analysis.language.SqlTypes.*;

/** Finite native operator signatures. No JDBC access or runtime value evaluation. */
final class ExpressionOperators {
    private ExpressionOperators(){}
    // PostgreSQL 17 pg_operator.dat equality signatures. Integer widths and
    // float widths have cross-type operators; numeric uses numeric=numeric.
    // These immutable builtin facts contain no user/operator metadata cache.
    private static final List<Signature> POSTGRES_EQUALITY=postgresEquality();
    private static List<Signature> postgresEquality(){
        var signatures=new ArrayList<Signature>();
        for(var group:List.of(List.of("smallint","integer","bigint"),List.of("real","double precision"),List.of("date","timestamp","timestamptz")))for(String left:group)for(String right:group)addEquality(signatures,left,right);
        for(String type:List.of("numeric","boolean","text","character","name","bytea","bit","varbit","time","timetz","interval","jsonb","uuid"))addEquality(signatures,type,type);
        addEquality(signatures,"name","text");addEquality(signatures,"text","name");
        return List.copyOf(signatures);
    }
    private static void addEquality(List<Signature> signatures,String left,String right){
        Type a=nativeType(left,Engine.POSTGRESQL),b=nativeType(right,Engine.POSTGRESQL);
        signatures.add(new Signature("native-equality:"+left+":"+right,"=","","","",List.of(new Parameter("left","IN",a,false,false,""),new Parameter("right","IN",b,false,false,"")),a,true));
    }
    private static boolean postgresEqualityInput(Type type){
        if(!type.known()||type.family()==Family.NULL)return true;
        // Domains, enums, arrays and extension types can have their own visible
        // equality operators, whose declarations are not captured here.
        if(Set.of(Family.DOMAIN,Family.ENUM,Family.ARRAY,Family.USER).contains(type.family()))return false;
        if(sameBuiltinTypeName(type.nativeName(),"varchar",Engine.POSTGRESQL))return true;
        return POSTGRES_EQUALITY.stream().anyMatch(signature->sameNative(type,signature.returns(),Engine.POSTGRESQL));
    }
    static Type postgresEqualityLeft(Type left,Type right,AnalysisBudget budget){
        if(!postgresEqualityInput(left)||!postgresEqualityInput(right))return UNKNOWN;
        boolean unknownLeft=!left.known()||left.family()==Family.NULL,unknownRight=!right.known()||right.family()==Family.NULL;
        // Unlike a function call, binary operator lookup first assumes one
        // unknown input has the known input's type and checks an exact pair.
        Type exactLeft=unknownLeft&&!unknownRight?right:left,exactRight=unknownRight&&!unknownLeft?left:right;
        var exact=POSTGRES_EQUALITY.stream().filter(signature->sameNative(exactLeft,RoutineOverloads.parameter(signature,0),Engine.POSTGRESQL)&&sameNative(exactRight,RoutineOverloads.parameter(signature,1),Engine.POSTGRESQL)).toList();
        var selection=exact.isEmpty()?RoutineOverloads.select(POSTGRES_EQUALITY,List.of(left,right),true,Engine.POSTGRESQL,budget):new RoutineOverloads.Selection(exact,true);
        if(selection.unique().isEmpty())return UNKNOWN;
        Type target=selection.unique().orElseThrow().returns();
        // make_op retains the original operand and its typmod when its type
        // already matches. An inserted implicit cast has no result typmod.
        return sameNative(left,target,Engine.POSTGRESQL)?left:target;
    }
    static Type unary(String operator,Type original,Dialect dialect,Node span,Consumer<LanguageIssue> issues){
        Type value=base(original);if(operator.equals("NOT")||operator.equals("!")){
            if(!booleanCompatible(value,dialect)){issues.accept(error("type.invalid-boolean",span,"Boolean expression requires a Boolean operand"));return UNKNOWN;}
            return truth(dialect.engine(),value.nullable());
        }
        if(!value.known()||value.family()==Family.NULL)return value;
        if(operator.equals("~")){
            if(value.family()==Family.INTEGER)return dialect.postgres()?value:nullable(nativeType("bigint unsigned",dialect.engine()),value.nullable());
            if(!dialect.postgres()&&value.family()==Family.BINARY)return unavailable(span,issues);
            issues.accept(error("type.incompatible-operator",span,"Bitwise operation requires an integer operand"));return UNKNOWN;
        }
        if(!dialect.postgres()&&value.family()==Family.TEXT)return nullable(nativeType("double",dialect.engine()),value.nullable());
        if(!value.numeric()){if(value.family()==Family.USER||value.family()==Family.INTERVAL)return unavailable(span,issues);issues.accept(error("type.incompatible-operator",span,"Numeric operation requires a numeric operand"));return UNKNOWN;}
        if(dialect.postgres())return value;
        if(value.family()==Family.INTEGER)return operator.equals("-")?NativeNumericTypes.unaryMinus(value,dialect.engine()):value;
        if(operator.equals("-")&&value.family()==Family.DECIMAL){
            String name=value.nativeName().replaceAll("(?i)\\s+unsigned\\b","");
            return NativeNumericTypes.declared(new Type(Family.DECIMAL,name,value.jdbcType(),value.precision(),value.scale(),false,value.nullable(),null,false),dialect.engine());
        }
        return value;
    }
    static Type binary(String operator,Type originalLeft,Type originalRight,Dialect dialect,Node span,Consumer<LanguageIssue> issues){
        Type left=base(originalLeft),right=base(originalRight);boolean nullable=left.nullable()||right.nullable()||left.family()==Family.NULL||right.family()==Family.NULL;
        boolean concat=operator.equals("||")&&(dialect.postgres()||dialect.lexical().pipesAsConcat());
        if(Set.of("AND","OR","XOR").contains(operator)||operator.equals("&&")&&!dialect.postgres()||operator.equals("||")&&!concat){
            if(!booleanCompatible(left,dialect)||!booleanCompatible(right,dialect)){issues.accept(error("type.invalid-boolean",span,"Boolean expression requires Boolean operands"));return UNKNOWN;}
            return truth(dialect.engine(),nullable);
        }
        if(Set.of("=","<>","!=","<",">","<=",">=","<=>").contains(operator)){
            if(operator.equals("<=>")&&dialect.postgres())return unavailable(span,issues);
            if(!comparisonCompatible(left,right,dialect)){issues.accept(error("type.incompatible-comparison",span,"The operand types cannot be compared"));return UNKNOWN;}
            return truth(dialect.engine(),!operator.equals("<=>")&&nullable);
        }
        if(Set.of("LIKE","NOT LIKE","ILIKE","NOT ILIKE","REGEXP","NOT REGEXP","RLIKE","NOT RLIKE","~","~*","!~","!~*").contains(operator)){
            if((operator.contains("ILIKE")||operator.startsWith("~")||operator.startsWith("!~"))&&!dialect.postgres()||(operator.contains("REGEXP")||operator.contains("RLIKE"))&&dialect.postgres())return unavailable(span,issues);
            if(dialect.postgres()&&(!textCompatible(left)||!textCompatible(right))){issues.accept(error("type.incompatible-operator",span,"Pattern matching requires textual operands"));return UNKNOWN;}
            return truth(dialect.engine(),nullable);
        }
        if(concat){
            if(dialect.postgres()&&left.family()==Family.ARRAY&&right.family()==Family.ARRAY)return SqlTypes.common(left,right,dialect.engine());
            if(dialect.postgres()&&left.family()==Family.BINARY&&right.family()==Family.BINARY)return nullable(nativeType("bytea",dialect.engine()),nullable);
            if(dialect.postgres()&&!textCompatible(left)&&!textCompatible(right))return unavailable(span,issues);
            return nullable(nativeType(dialect.postgres()?"text":"varchar",dialect.engine()),nullable);
        }
        if(Set.of("->","->>","#>","#>>").contains(operator)){
            if(!dialect.postgres())return unavailable(span,issues);
            if(left.family()!=Family.JSON&&left.family()!=Family.JSONB)return unavailable(span,issues);
            if((operator.startsWith("#")&&right.family()!=Family.ARRAY&&right.known()&&right.family()!=Family.NULL)||(!operator.startsWith("#")&&right.known()&&!Set.of(Family.INTEGER,Family.TEXT,Family.NULL).contains(right.family())))return unavailable(span,issues);
            return nullable(operator.endsWith(">>")?nativeType("text",dialect.engine()):left,true);
        }
        if(Set.of("@>","<@","&&","?|","?&","@?","@@").contains(operator)){
            if(!dialect.postgres())return unavailable(span,issues);
            if(left.family()!=Family.ARRAY&&left.family()!=Family.JSONB)return unavailable(span,issues);
            return truth(dialect.engine(),nullable);
        }
        // Unknown literals/parameters acquire the other operand's known numeric
        // signature. Unavailable symbols are rejected by the analyzer beforehand.
        if(!left.known()||left.family()==Family.NULL)left=right;
        if(!right.known()||right.family()==Family.NULL)right=left;
        if(!left.known()||left.family()==Family.NULL||!right.known()||right.family()==Family.NULL)return unavailable(span,issues);
        if(dialect.postgres()){
            if(left.nativeName().equalsIgnoreCase("money")||right.nativeName().equalsIgnoreCase("money"))return unavailable(span,issues);
            Type temporal=temporal(operator,left,right,dialect);if(temporal!=null)return nullable(temporal,nullable);
            if(Set.of("&","|","#","<<",">>").contains(operator)){
                if(left.family()!=Family.INTEGER||right.family()!=Family.INTEGER){issues.accept(error("type.incompatible-operator",span,"Bitwise operation requires integer operands"));return UNKNOWN;}
                return nullable(Set.of("<<",">>").contains(operator)?left:SqlTypes.common(left,right,dialect.engine()),nullable);
            }
            if(!left.numeric()||!right.numeric()){
                if(left.family()==Family.USER||right.family()==Family.USER)return unavailable(span,issues);
                issues.accept(error("type.incompatible-operator",span,"Arithmetic operation requires numeric operands"));return UNKNOWN;
            }
            if(Set.of("DIV","MOD").contains(operator))return unavailable(span,issues);
            Type result=SqlTypes.common(left,right,dialect.engine());
            if(operator.equals("%")&&result.family()==Family.REAL){issues.accept(error("type.incompatible-operator",span,"Remainder has integer and numeric signatures, without a floating point signature"));return UNKNOWN;}
            if(operator.equals("^"))result=nativeType(result.family()==Family.DECIMAL?"numeric":"double precision",dialect.engine());
            return nullable(result,nullable);
        }
        if(Set.of("&","|","^","<<",">>").contains(operator)){
            if(left.family()==Family.BINARY||right.family()==Family.BINARY)return unavailable(span,issues);
            return nullable(nativeType("bigint unsigned",dialect.engine()),nullable);
        }
        if(Set.of(Family.DATE,Family.TIME,Family.TIMESTAMP).contains(left.family())||Set.of(Family.DATE,Family.TIME,Family.TIMESTAMP).contains(right.family()))return unavailable(span,issues);
        if(!(left.numeric()||left.family()==Family.TEXT||left.family()==Family.BOOLEAN)||!(right.numeric()||right.family()==Family.TEXT||right.family()==Family.BOOLEAN))return unavailable(span,issues);
        if(operator.equals("DIV"))return NativeNumericTypes.arithmetic(operator,left,right,dialect,true);
        nullable|=Set.of("/","%","MOD").contains(operator);
        if(left.family()==Family.REAL||right.family()==Family.REAL||left.family()==Family.TEXT||right.family()==Family.TEXT)return nullable(nativeType("double",dialect.engine()),nullable);
        // The family is exact even when runtime div_precision_increment or a
        // server-specific precision cap has not been captured. A zero precision
        // explicitly means the result typemod is unknown, never an exact scale.
        if(operator.equals("/")||left.family()==Family.DECIMAL||right.family()==Family.DECIMAL){
            boolean unsigned=(operator.equals("%")||operator.equals("MOD"))?left.unsigned():left.unsigned()&&right.unsigned();
            if(operator.equals("-")&&dialect.lexical().noUnsignedSubtraction())unsigned=false;
            return nullable(nativeType("decimal"+(unsigned?" unsigned":""),dialect.engine()),nullable);
        }
        return NativeNumericTypes.arithmetic(operator,left,right,dialect,nullable);
    }
    static boolean booleanCompatible(Type value,Dialect dialect){return !value.known()||value.family()==Family.NULL||value.family()==Family.BOOLEAN||!dialect.postgres()&&(value.numeric()||value.family()==Family.TEXT);}
    static boolean comparisonCompatible(Type left,Type right,Dialect dialect){
        if(!left.known()||!right.known()||left.family()==Family.NULL||right.family()==Family.NULL)return true;
        if(left.family()==Family.DOMAIN)left=base(left);if(right.family()==Family.DOMAIN)right=base(right);
        if(left.family()==Family.ARRAY||right.family()==Family.ARRAY)return left.family()==right.family()&&left.element()!=null&&right.element()!=null&&comparisonCompatible(left.element(),right.element(),dialect);
        if(left.family()==Family.ENUM||right.family()==Family.ENUM)return dialect.postgres()?sameNative(left,right,dialect.engine()):true;
        if(left.family()==right.family())return left.family()!=Family.JSON||!dialect.postgres();
        return compatible(left,right,dialect.engine())||compatible(right,left,dialect.engine());
    }
    private static boolean textCompatible(Type value){return !value.known()||value.family()==Family.NULL||value.family()==Family.TEXT;}
    private static Type temporal(String operator,Type left,Type right,Dialect dialect){
        Family a=left.family(),b=right.family();
        if(operator.equals("+")){
            if(a==Family.DATE&&b==Family.INTEGER||b==Family.DATE&&a==Family.INTEGER)return nativeType("date",dialect.engine());
            if(a==Family.DATE&&b==Family.TIME||b==Family.DATE&&a==Family.TIME)return nativeType(left.timezone()||right.timezone()?"timestamptz":"timestamp",dialect.engine());
            if(a==Family.INTERVAL&&Set.of(Family.DATE,Family.TIME,Family.TIMESTAMP,Family.INTERVAL).contains(b))return b==Family.DATE?nativeType("timestamp",dialect.engine()):right;
            if(b==Family.INTERVAL&&Set.of(Family.DATE,Family.TIME,Family.TIMESTAMP).contains(a))return a==Family.DATE?nativeType("timestamp",dialect.engine()):left;
        }
        if(operator.equals("-")){
            if(a==Family.DATE&&b==Family.DATE)return nativeType("integer",dialect.engine());
            if(a==Family.DATE&&b==Family.INTEGER)return nativeType("date",dialect.engine());
            if(a==Family.TIME&&b==Family.TIME||a==Family.TIMESTAMP&&b==Family.TIMESTAMP||a==Family.INTERVAL&&b==Family.INTERVAL)return nativeType("interval",dialect.engine());
            if(b==Family.INTERVAL&&Set.of(Family.DATE,Family.TIME,Family.TIMESTAMP).contains(a))return a==Family.DATE?nativeType("timestamp",dialect.engine()):left;
        }
        if((operator.equals("*")||operator.equals("/"))&&a==Family.INTERVAL&&right.numeric()||operator.equals("*")&&b==Family.INTERVAL&&left.numeric())return nativeType("interval",dialect.engine());
        return null;
    }
    private static Type unavailable(Node span,Consumer<LanguageIssue> issues){issues.accept(LanguageIssue.unavailable(span.start(),span.end(),"The native operator signature or result typemod is unavailable for these operand types"));return UNKNOWN;}
    private static LanguageIssue error(String code,Node span,String message){return LanguageIssue.semantic(code,span.start(),span.end(),message);}
}
