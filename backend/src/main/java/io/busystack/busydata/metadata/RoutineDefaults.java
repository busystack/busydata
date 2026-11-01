package io.busystack.busydata.metadata;

import io.busystack.busydata.analysis.LexicalSettings;
import io.busystack.busydata.analysis.SqlLexicalCharacters;
import io.busystack.busydata.analysis.language.*;
import io.busystack.busydata.analysis.language.LosslessLexer.*;
import io.busystack.busydata.protocol.*;
import java.nio.charset.StandardCharsets;
import java.util.*;

/** Bounded declaration/default boundaries only. Types, expressions and routine
 * bodies are never interpreted or executed by this helper. */
public final class RoutineDefaults {
    private RoutineDefaults(){}
    public record Parameter(int ordinal,String name,String mode){}
    public record Value(boolean declared,String expression){public Value{Objects.requireNonNull(expression);if(!declared&&!expression.isEmpty())throw new IllegalArgumentException("Invalid absent default");}}
    public record Parsed(List<Value> values,MetadataState state){public Parsed{values=List.copyOf(values);}public boolean available(){return state==MetadataState.AVAILABLE;}}
    private static Parsed unavailable(MetadataState state){return new Parsed(List.of(),state);}
    public static Parsed maria(NativeRoutineSource source,SchemaObject routine,List<Parameter> parameters){
        if(!source.available())return unavailable(source.state());
        try{
            var settings=LexicalSettings.mysql(source.sqlMode());var budget=AnalysisBudget.interactive();
            var tokens=LosslessLexer.scan(source.definition(),new Dialect(Engine.MARIADB,settings),budget).significant();int at=0;
            if(!word(tokens,at++,"CREATE"))return unavailable(MetadataState.UNSUPPORTED);
            if(word(tokens,at,"OR")){at++;if(!word(tokens,at++,"REPLACE"))return unavailable(MetadataState.UNSUPPORTED);}
            if(word(tokens,at,"DEFINER")){
                at++;if(!is(tokens,at++,"="))return unavailable(MetadataState.UNSUPPORTED);
                if(at>=tokens.size()||!account(tokens.get(at)))return unavailable(MetadataState.UNSUPPORTED);at++;
                if(is(tokens,at,"(")){at++;if(!is(tokens,at++,")"))return unavailable(MetadataState.UNSUPPORTED);}
                if(is(tokens,at,"@")){at++;if(at>=tokens.size()||!account(tokens.get(at)))return unavailable(MetadataState.UNSUPPORTED);at++;}
            }
            if(word(tokens,at,"AGGREGATE"))at++;
            String kind=switch(routine.getSubtype()){case FUNCTION->"FUNCTION";case PROCEDURE->"PROCEDURE";default->"";};
            if(kind.isEmpty()||!word(tokens,at++,kind)||at>=tokens.size()||!tokens.get(at).name())return unavailable(MetadataState.UNSUPPORTED);
            String name=tokens.get(at++).identifier();
            if(is(tokens,at,".")){if(!name.equals(routine.getSchema()))return unavailable(MetadataState.STALE);at++;if(at>=tokens.size()||!tokens.get(at).name())return unavailable(MetadataState.UNSUPPORTED);name=tokens.get(at++).identifier();}
            if(!name.equals(routine.getName()))return unavailable(MetadataState.STALE);
            if(!is(tokens,at++,"("))return unavailable(MetadataState.UNSUPPORTED);
            int begin=at,depth=1,end=-1;
            for(;at<tokens.size();at++){budget.check();var token=tokens.get(at);if(token.kind()==Kind.ERROR||!token.complete())return unavailable(MetadataState.UNSUPPORTED);if(token.is("("))depth++;else if(token.is(")")&&--depth==0){end=at;break;}}
            if(end<0)return unavailable(MetadataState.UNSUPPORTED);
            var declarations=split(tokens.subList(begin,end));
            if(declarations.size()!=parameters.size())return unavailable(MetadataState.STALE);
            var result=new ArrayList<Value>(parameters.size());boolean seenDefault=false;
            boolean oracle=Arrays.asList(source.sqlMode().split(",")).contains("ORACLE");
            for(int index=0;index<declarations.size();index++){
                var declaration=declarations.get(index);var expected=parameters.get(index);int cursor=0;String mode="IN";
                if(expected.ordinal()!=index+1||declaration.isEmpty())return unavailable(MetadataState.STALE);
                boolean prefixMode=isMode(declaration,cursor);if(prefixMode)mode=declaration.get(cursor++).text().toUpperCase(Locale.ROOT);
                if(cursor>=declaration.size()||!declaration.get(cursor).name()||!declaration.get(cursor++).identifier().equals(expected.name()))return unavailable(MetadataState.STALE);
                if(isMode(declaration,cursor)){if(!oracle||prefixMode)return unavailable(MetadataState.UNSUPPORTED);mode=declaration.get(cursor++).text().toUpperCase(Locale.ROOT);}
                if(!mode.equals(expected.mode())||cursor>=declaration.size())return unavailable(MetadataState.STALE);
                int defaultAt=-1,nesting=0;
                for(int i=cursor;i<declaration.size();i++){
                    var token=declaration.get(i);
                    if(token.is("(")||token.is("["))nesting++;
                    else if(token.is(")")||token.is("]")){if(--nesting<0)return unavailable(MetadataState.UNSUPPORTED);}
                    else if(nesting==0&&(word(declaration,i,"DEFAULT")||oracle&&token.is(":="))){if(defaultAt>=0)return unavailable(MetadataState.UNSUPPORTED);defaultAt=i;}
                }
                if(nesting!=0)return unavailable(MetadataState.UNSUPPORTED);
                if(defaultAt<0){if(seenDefault)return unavailable(MetadataState.UNSUPPORTED);result.add(new Value(false,""));continue;}
                if(defaultAt==cursor||defaultAt==declaration.size()-1||!mode.equals("IN"))return unavailable(MetadataState.UNSUPPORTED);
                seenDefault=true;String expression=trimSqlSpace(source.definition().substring(declaration.get(defaultAt).end(),declaration.getLast().end()));
                if(expression.isEmpty())return unavailable(MetadataState.UNSUPPORTED);result.add(new Value(true,expression));
            }
            return new Parsed(result,MetadataState.AVAILABLE);
        }catch(AnalysisBudget.Limit limit){return unavailable(MetadataState.LIMITED);}
        catch(IllegalArgumentException malformed){return unavailable(MetadataState.UNSUPPORTED);}
    }
    /** pg_get_expr(proargdefaults,0) supplies defaults in trailing input order;
     * only native counts/modes determine which parameter receives each span. */
    public static Parsed postgres(String expressions,int argumentCount,int defaultCount,List<Parameter> parameters,LexicalSettings settings){
        if(defaultCount<0||defaultCount>argumentCount||argumentCount>1024)return unavailable(MetadataState.UNAVAILABLE);
        if(expressions==null){if(defaultCount!=0)return unavailable(MetadataState.UNAVAILABLE);expressions="";}
        if(expressions.getBytes(StandardCharsets.UTF_8).length>NativeRoutineSource.MAX_BYTES)return unavailable(MetadataState.LIMITED);
        try{
            var tokens=LosslessLexer.scan(expressions,new Dialect(Engine.POSTGRESQL,settings),AnalysisBudget.interactive()).significant();
            for(var token:tokens)if(token.kind()==Kind.ERROR||!token.complete())return unavailable(MetadataState.UNSUPPORTED);
            var defaults=split(tokens);if(defaults.size()!=defaultCount)return unavailable(MetadataState.UNAVAILABLE);
            var result=new ArrayList<Value>(parameters.size());int input=0,next=0;
            for(int index=0;index<parameters.size();index++){
                var parameter=parameters.get(index);if(parameter.ordinal()!=index+1)return unavailable(MetadataState.UNAVAILABLE);
                boolean isInput=Set.of("IN","INOUT","VARIADIC").contains(parameter.mode());
                if(isInput&&++input>argumentCount-defaultCount){var expression=defaults.get(next++);result.add(new Value(true,expressions.substring(expression.getFirst().start(),expression.getLast().end())));}
                else result.add(new Value(false,""));
            }
            if(input!=argumentCount||next!=defaultCount)return unavailable(MetadataState.UNAVAILABLE);
            return new Parsed(result,MetadataState.AVAILABLE);
        }catch(AnalysisBudget.Limit limit){return unavailable(MetadataState.LIMITED);}
        catch(IllegalArgumentException malformed){return unavailable(MetadataState.UNSUPPORTED);}
    }
    private static boolean account(Token token){return token.name()||token.kind()==Kind.STRING;}
    private static String trimSqlSpace(String text){int start=0,end=text.length();while(start<end&&SqlLexicalCharacters.isSpace(text.charAt(start)))start++;while(end>start&&SqlLexicalCharacters.isSpace(text.charAt(end-1)))end--;return text.substring(start,end);}
    private static boolean isMode(List<Token> tokens,int at){return word(tokens,at,"IN")||word(tokens,at,"OUT")||word(tokens,at,"INOUT");}
    private static boolean word(List<Token> tokens,int at,String text){return at<tokens.size()&&tokens.get(at).kind()==Kind.WORD&&IdentifierRules.postgresUnquoted(tokens.get(at).text()).equals(IdentifierRules.postgresUnquoted(text));}
    private static boolean is(List<Token> tokens,int at,String text){return at<tokens.size()&&tokens.get(at).is(text);}
    private static List<List<Token>> split(List<Token> tokens){
        if(tokens.isEmpty())return List.of();var result=new ArrayList<List<Token>>();var stack=new ArrayDeque<String>();int start=0;
        for(int at=0;at<tokens.size();at++){
            var token=tokens.get(at);if(token.is("(")||token.is("["))stack.push(token.text());
            else if(token.is(")")||token.is("]")){if(stack.isEmpty()||!stack.pop().equals(token.is(")")?"(":"["))throw new IllegalArgumentException("Unbalanced default expression");}
            else if(token.is(",")&&stack.isEmpty()){if(start==at)throw new IllegalArgumentException("Empty routine declaration");result.add(List.copyOf(tokens.subList(start,at)));start=at+1;}
        }
        if(!stack.isEmpty()||start==tokens.size())throw new IllegalArgumentException("Unbalanced routine declaration");result.add(List.copyOf(tokens.subList(start,tokens.size())));return List.copyOf(result);
    }
}
