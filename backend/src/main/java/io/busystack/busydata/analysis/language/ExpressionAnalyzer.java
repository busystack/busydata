package io.busystack.busydata.analysis.language;

import java.math.BigInteger;
import java.util.*;
import io.busystack.busydata.protocol.Engine;
import io.busystack.busydata.analysis.language.LosslessLexer.*;
import io.busystack.busydata.analysis.language.SyntaxTree.*;
import io.busystack.busydata.analysis.language.ExpressionSyntax.*;
import io.busystack.busydata.analysis.language.SqlTypes.*;
import static io.busystack.busydata.analysis.language.SqlTypes.*;

/** Request-local expression binding and native type propagation. The resolver is
 * bound to one captured immutable metadata snapshot and query scope. */
public final class ExpressionAnalyzer {
    public interface Resolver {
        Type reference(Name name);
        default boolean referenceComplete(Name name){return reference(name).known();}
        CallCandidates routines(Name name,Group arguments,int count);
        default Type subquery(Group query){return UNKNOWN;}
        /** Custom types require authoritative metadata, not a guessed type name. */
        default Type castType(String nativeName,Dialect dialect){Type value=nativeType(nativeName,dialect.engine());return value.family()==Family.USER?UNKNOWN:value;}
    }
    public record CallCandidates(List<RoutineSignatures.Signature> signatures,boolean complete){public CallCandidates{signatures=List.copyOf(signatures);}}
    public record Result(Node syntax,Type type,List<LanguageIssue> issues,boolean complete){public Result{issues=List.copyOf(issues);}}
    private record Value(Type type,boolean available,boolean incomplete){Value(Type type,boolean available){this(type,available,!available);}}
    private record Frame(Node node,boolean expanded){}
    private final Dialect dialect;private final AnalysisBudget budget;private final Resolver resolver;
    public ExpressionAnalyzer(Dialect dialect,AnalysisBudget budget,Resolver resolver){this.dialect=Objects.requireNonNull(dialect);this.budget=Objects.requireNonNull(budget);this.resolver=Objects.requireNonNull(resolver);}
    public Result analyze(List<Element> elements){
        Node root=ExpressionParser.parse(dialect,budget,elements);var values=new IdentityHashMap<Node,Value>();var issues=new ArrayList<LanguageIssue>();var pending=new ArrayDeque<Frame>();pending.push(new Frame(root,false));
        // A flat binary chain may contain thousands of operators. Traversal is
        // iterative so its depth cannot exhaust the Java stack.
        while(!pending.isEmpty()){
            budget.check();Frame frame=pending.pop();Node node=frame.node();
            if(!frame.expanded()){pending.push(new Frame(node,true));var children=node.children();for(int i=children.size()-1;i>=0;i--)pending.push(new Frame(children.get(i),false));continue;}
            values.put(node,infer(node,values,issues));
        }
        Value result=values.get(root);Type type=result.type();
        if(result.incomplete()&&issues.isEmpty())unavailable(root,"Expression metadata or a native signature is incomplete or unavailable",issues);
        if(type.known()&&!type.nativeKnown())unavailable(root,"Native integer width requires unavailable display or materialization context",issues);
        return new Result(root,type,issues.stream().distinct().limit(16).toList(),result.available()&&type.nativeKnown());
    }
    private Value infer(Node node,IdentityHashMap<Node,Value> values,List<LanguageIssue> issues){
        if(node instanceof Literal literal)return new Value(literal(literal.token()),true);
        if(node instanceof Reference reference){Type type=resolver.reference(reference.name());return new Value(type,type.known(),!resolver.referenceComplete(reference.name()));}
        if(node instanceof Opaque opaque){unavailable(opaque,opaque.reason(),issues);return new Value(UNKNOWN,false);}
        if(node instanceof Subquery subquery){Type type=resolver.subquery(subquery.group());return new Value(type,type.known());}
        if(node instanceof Cast cast)return cast(cast,values.get(cast.value()),issues);
        if(node instanceof Predicate predicate&&predicate.operator().equals("EXISTS"))return new Value(truth(dialect.engine(),false),true);
        boolean available=node.children().stream().allMatch(child->values.get(child).available());
        if(!available)return new Value(UNKNOWN,false,node.children().stream().anyMatch(child->values.get(child).incomplete()));
        if(node instanceof Decoration decoration){
            if(decoration.clause().equals("FILTER")&&!dialect.postgres()){unavailable(node,"Aggregate FILTER is unavailable in the selected dialect",issues);return new Value(UNKNOWN,false);}
            if(decoration.clause().equals("FILTER"))for(var condition:decoration.expressions())if(!ExpressionOperators.booleanCompatible(values.get(condition).type(),dialect))add(issues,LanguageIssue.semantic("type.invalid-boolean",condition.start(),condition.end(),"Aggregate FILTER requires a Boolean condition"));
            return values.get(decoration.value());
        }
        if(node instanceof Unary unary){
            if(unary.operator().equals("-")&&unary.operand() instanceof Literal literal&&literal.token().kind()==Kind.NUMBER&&(dialect.postgres()||values.get(unary.operand()).type().family()==Family.INTEGER))return new Value(dialect.postgres()?number(literal.token(),true):NativeNumericTypes.negativeLiteral(values.get(unary.operand()).type(),dialect.engine()),true);
            return new Value(ExpressionOperators.unary(unary.operator(),values.get(unary.operand()).type(),dialect,node,issue->add(issues,issue)),true);
        }
        if(node instanceof Binary binary)return new Value(ExpressionOperators.binary(binary.operator(),values.get(binary.left()).type(),values.get(binary.right()).type(),dialect,node,issue->add(issues,issue)),true);
        if(node instanceof Conditional conditional)return conditional(conditional,values,issues);
        if(node instanceof Call call)return call(call,values,issues);
        if(node instanceof Predicate predicate)return predicate(predicate,values,issues);
        if(node instanceof ExpressionSyntax.Array array){
            if(!dialect.postgres()){unavailable(node,"Array constructors are unavailable in this dialect",issues);return new Value(UNKNOWN,false);}
            if(array.values().isEmpty()){unavailable(node,"An empty array requires an explicit element type",issues);return new Value(UNKNOWN,false);}
            Type element=common(array.values().stream().map(value->values.get(value).type()).toList(),dialect.engine());
            if(!element.known()){add(issues,LanguageIssue.semantic("type.incompatible-array",node.start(),node.end(),"Array elements do not have a common type"));return new Value(UNKNOWN,true);}
            return new Value(new Type(Family.ARRAY,element.nativeName()+"[]",java.sql.Types.ARRAY,0,0,false,false,element,false),true);
        }
        if(node instanceof Subscript subscript){Type array=values.get(subscript.value()).type(),index=values.get(subscript.index()).type();
            if(dialect.postgres()&&array.family()==Family.ARRAY&&array.element()!=null&&(!index.known()||index.family()==Family.NULL||index.family()==Family.INTEGER))return new Value(nullable(array.element(),true),true);
            unavailable(node,"Subscript result type is unavailable for these operand types",issues);return new Value(UNKNOWN,false);
        }
        return new Value(UNKNOWN,false);
    }
    private Type literal(Token token){
        if(token.is("NULL"))return NULL;if(token.is("TRUE")||token.is("FALSE")){
            Type type=truth(dialect.engine(),false);if(dialect.postgres())return type;int width=dialect.engine()==Engine.MARIADB?5:1;
            return shaped(type,new NumericShape(width,width,true,true,token.is("TRUE")?BigInteger.ONE:BigInteger.ZERO,NumericShape.Origin.LITERAL));
        }
        if(token.kind()==Kind.STRING)return dialect.postgres()?UNKNOWN:NativeNumericTypes.stringLiteral(nullable(nativeType("varchar",dialect.engine()),false),token.text(),dialect.engine());
        if(token.kind()!=Kind.NUMBER)return UNKNOWN;
        return number(token,false);
    }
    private Type number(Token token,boolean negative){
        String number=token.text().replace("_","");int radix=10;String digits=number;
        if(number.length()>2&&number.charAt(0)=='0'){radix=switch(Character.toLowerCase(number.charAt(1))){case 'x'->16;case 'o'->8;case 'b'->2;default->10;};if(radix!=10)digits=number.substring(2);}
        boolean exponent=radix==10&&number.toLowerCase(Locale.ROOT).contains("e"),decimal=radix==10&&number.contains(".");
        if(decimal||exponent)return nullable(nativeType(exponent&&!dialect.postgres()?"double":dialect.postgres()?"numeric":"decimal",dialect.engine()),false);
        int significant=0;while(significant+1<digits.length()&&digits.charAt(significant)=='0'){if((significant&4095)==0)budget.check();significant++;}digits=digits.substring(significant);
        // Width classification never parses an unbounded arbitrary precision
        // value. Beyond 64 bits the exact numeric family is already determined.
        if(digits.length()>64)return nullable(nativeType(dialect.postgres()?"numeric":"decimal",dialect.engine()),false);
        try{BigInteger integer=new BigInteger(digits,radix);if(negative)integer=integer.negate();String name=dialect.postgres()?(integer.bitLength()<32?"integer":integer.bitLength()<64?"bigint":"numeric"):(integer.bitLength()<64?"bigint":integer.bitLength()<=64?"bigint unsigned":"decimal");return NativeNumericTypes.integerLiteral(nullable(nativeType(name,dialect.engine()),false),token.text(),integer,dialect.engine());}catch(NumberFormatException ignored){return UNKNOWN;}
    }
    private Value cast(Cast cast,Value value,List<LanguageIssue> issues){
        String name=cast.nativeName().toLowerCase(Locale.ROOT).trim().replaceAll("\\s+"," ");
        boolean integerCast=!dialect.postgres()&&(Set.of("signed","signed integer","unsigned","unsigned integer").contains(name)||dialect.engine()==Engine.MARIADB&&name.equals("integer"));
        boolean unsignedCast=integerCast&&name.startsWith("unsigned");
        if(!dialect.postgres()){
            if(name.equals("signed")||name.equals("signed integer")||dialect.engine()==Engine.MARIADB&&name.equals("integer"))name="bigint";
            else if(name.equals("unsigned")||name.equals("unsigned integer"))name="bigint unsigned";
            else if(name.equals("real"))name=dialect.lexical().realAsFloat()?"float":"double";
            // Native casts accept a narrower target set than column declarations.
            String base=name.replaceFirst("\\s*\\(.*","");
            boolean allowed=integerCast||Set.of("binary","char","date","datetime","decimal","double","float","time").contains(base)||dialect.engine()==Engine.MYSQL&&Set.of("json","year").contains(base)||dialect.engine()==Engine.MARIADB&&base.equals("varchar");
            if(!allowed){unavailable(cast,"Cast target is unavailable for the selected dialect",issues);return new Value(UNKNOWN,false);}
        }
        Type type=integerCast?NativeNumericTypes.castInteger(value.type(),unsignedCast,dialect):resolver.castType(name,dialect);
        if(!type.known()){unavailable(cast,"Cast target metadata is incomplete or unavailable",issues);return new Value(UNKNOWN,false);}
        if(type.family()==Family.DECIMAL&&name.contains("(")){
            int maximum=dialect.postgres()?1000:65,scale=dialect.postgres()?1000:dialect.engine()==Engine.MARIADB?38:30;
            boolean valid=type.precision()>=1&&type.precision()<=maximum&&type.scale()>= (dialect.postgres()?-1000:0)&&type.scale()<=scale&&(dialect.postgres()||type.scale()<=type.precision());
            if(!valid){unavailable(cast,"Cast precision or scale is outside the supported native bounds",issues);return new Value(type,false);}
        }
        // A cast establishes the result type even if the input symbol is absent;
        // availability still prevents that guessed input from selecting overloads.
        return new Value(nullable(type,value.type().nullable()||value.type().family()==Family.NULL),value.available(),value.incomplete());
    }
    private Value conditional(Conditional conditional,IdentityHashMap<Node,Value> values,List<LanguageIssue> issues){
        for(var arm:conditional.arms()){
            Type condition=values.get(arm.condition()).type();boolean valid=conditional.operand()==null?ExpressionOperators.booleanCompatible(condition,dialect):ExpressionOperators.comparisonCompatible(values.get(conditional.operand()).type(),condition,dialect);
            if(!valid)add(issues,LanguageIssue.semantic("type.invalid-case-condition",arm.condition().start(),arm.condition().end(),"CASE condition has an incompatible type"));
        }
        // PostgreSQL considers ELSE before THEN results during common-type
        // selection; preserving this ordering also makes results deterministic.
        var alternatives=new ArrayList<Type>();if(conditional.otherwise()!=null)alternatives.add(values.get(conditional.otherwise()).type());else if(dialect.engine()!=Engine.MARIADB)alternatives.add(NULL);for(var arm:conditional.arms())alternatives.add(values.get(arm.result()).type());
        Type result=common(alternatives,dialect.engine());if(conditional.otherwise()==null)result=nullable(result,true);if(!result.known())add(issues,LanguageIssue.semantic("type.incompatible-case",conditional.start(),conditional.end(),"CASE result branches do not have a common type"));
        return new Value(result,true);
    }
    private Value predicate(Predicate predicate,IdentityHashMap<Node,Value> values,List<LanguageIssue> issues){
        String operator=predicate.operator();var operands=predicate.values().stream().map(value->values.get(value).type()).toList();
        if(operator.equals("EXISTS"))return new Value(truth(dialect.engine(),false),true);
        if(operator.endsWith("TRUE")||operator.endsWith("FALSE")||operator.endsWith("UNKNOWN"))if(!ExpressionOperators.booleanCompatible(operands.getFirst(),dialect))add(issues,LanguageIssue.semantic("type.invalid-boolean",predicate.start(),predicate.end(),"Truth predicate requires a Boolean operand"));
        if(operands.size()>1)for(int i=1;i<operands.size();i++)if(!ExpressionOperators.comparisonCompatible(operands.getFirst(),operands.get(i),dialect))add(issues,LanguageIssue.semantic("type.incompatible-comparison",predicate.values().get(i).start(),predicate.values().get(i).end(),"Predicate operands have incompatible types"));
        boolean nullable=!operator.startsWith("IS")&&operands.stream().anyMatch(t->t.nullable()||t.family()==Family.NULL);
        return new Value(truth(dialect.engine(),nullable),true);
    }
    private Value call(Call call,IdentityHashMap<Node,Value> values,List<LanguageIssue> issues){
        var arguments=call.values().stream().map(value->values.get(value).type()).toList();CallCandidates available=resolver.routines(call.name(),call.arguments(),arguments.size());
        var selection=RoutineOverloads.select(available.signatures(),arguments,available.complete(),dialect.engine(),budget);
        if(!selection.complete()){unavailable(call,"Routine signatures are incomplete, unavailable or stale",issues);return new Value(UNKNOWN,false);}
        if(selection.candidates().isEmpty()){
            String code=available.signatures().isEmpty()?"routine.unknown":available.signatures().stream().noneMatch(s->s.accepts(arguments.size()))?"routine.argument-count":"routine.no-matching-overload";
            add(issues,LanguageIssue.semantic(code,call.name().start(),code.equals("routine.unknown")?call.name().end():call.end(),code.equals("routine.unknown")?"Unknown routine in the inspected namespace":code.equals("routine.argument-count")?"No visible routine overload accepts this argument count":"No visible routine overload accepts these argument types"));return new Value(UNKNOWN,true);
        }
        if(selection.unique().isEmpty()){add(issues,LanguageIssue.semantic("routine.ambiguous-overload",call.start(),call.end(),"More than one visible routine overload matches these argument types"));return new Value(UNKNOWN,true);}
        var signature=selection.unique().orElseThrow();Type result=signature.identity().startsWith("builtin:")?builtin(signature,arguments,call,issues):signature.returns();
        if(!result.known())unavailable(call,"Routine result type cannot be determined from the captured signature and argument types",issues);
        return new Value(result,result.known());
    }
    private Type builtin(RoutineSignatures.Signature signature,List<Type> arguments,Call call,List<LanguageIssue> issues){
        String name=signature.name().toLowerCase(Locale.ROOT);Type first=arguments.isEmpty()?UNKNOWN:base(arguments.getFirst());
        if(name.equals("coalesce")){Type result=common(arguments,dialect.engine());if(!result.known())add(issues,LanguageIssue.semantic("type.incompatible-coalesce",call.start(),call.end(),"COALESCE arguments do not have a common type"));return nullable(result,arguments.stream().allMatch(type->type.nullable()||type.family()==Family.NULL));}
        if(name.equals("nullif")){
            if(arguments.size()!=2)return UNKNOWN;if(!ExpressionOperators.comparisonCompatible(arguments.getFirst(),arguments.get(1),dialect)){add(issues,LanguageIssue.semantic("type.incompatible-comparison",call.start(),call.end(),"NULLIF arguments cannot be compared"));return UNKNOWN;}
            return nullable(dialect.postgres()?ExpressionOperators.postgresEqualityLeft(arguments.getFirst(),arguments.get(1),budget):first.known()?first:common(arguments,dialect.engine()),true);
        }
        if(Set.of("min","max").contains(name)){
            if(dialect.engine()==Engine.MARIADB&&first.family()==Family.INTEGER)return nullable(nativeType("bigint"+(first.unsigned()?" unsigned":""),dialect.engine()),true);
            if(dialect.engine()==Engine.MARIADB&&first.family()==Family.REAL)return nullable(nativeType("double",dialect.engine()),true);return nullable(first,true);
        }
        if(Set.of("sum","avg","abs").contains(name)){
            if(!first.known()||first.family()==Family.NULL)return UNKNOWN;
            if(dialect.postgres()&&first.nativeName().equalsIgnoreCase("money"))return UNKNOWN;
            if(!first.numeric()&&!(dialect.postgres()&&first.family()==Family.INTERVAL&&!name.equals("abs"))){if(!dialect.postgres()&&first.family()==Family.TEXT)return nullable(nativeType("double",dialect.engine()),true);add(issues,LanguageIssue.semantic("routine.no-matching-overload",call.start(),call.end(),"The native routine requires a numeric argument"));return UNKNOWN;}
            if(dialect.postgres()){
                if(name.equals("abs"))return first.family()==Family.DECIMAL?nullable(nativeType("numeric",dialect.engine()),first.nullable()):first;if(first.family()==Family.INTERVAL)return nullable(first,true);
                if(name.equals("sum"))return nullable(first.family()==Family.INTEGER?nativeType(first.integerBits()==64?"numeric":"bigint",dialect.engine()):first.family()==Family.DECIMAL?nativeType("numeric",dialect.engine()):first,true);
                return nullable(nativeType(first.family()==Family.REAL?"double precision":"numeric",dialect.engine()),true);
            }
            if(name.equals("abs"))return first.family()==Family.INTEGER?NativeNumericTypes.absolute(first,dialect.engine()):first;
            return nullable(nativeType(first.family()==Family.REAL?"double":"decimal",dialect.engine()),true);
        }
        // Overloaded fixed-result calls use the selected captured signature.
        return nullable(signature.returns(),!Set.of("count","row_number","rank","dense_rank").contains(name));
    }
    private static void unavailable(Node node,String message,List<LanguageIssue> issues){add(issues,LanguageIssue.unavailable(node.start(),node.end(),message));}
    private static void add(List<LanguageIssue> issues,LanguageIssue issue){if(issues.size()<16&&!issues.contains(issue))issues.add(issue);}
}
