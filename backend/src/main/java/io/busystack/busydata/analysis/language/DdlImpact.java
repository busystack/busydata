package io.busystack.busydata.analysis.language;

import io.busystack.busydata.protocol.*;
import java.util.*;
import io.busystack.busydata.analysis.language.LosslessLexer.*;

/** Conservative structural effects, consumed only after acknowledged SQL execution. */
public final class DdlImpact {
    private static final Set<String> DDL=Set.of("CREATE","ALTER","DROP","RENAME","TRUNCATE","COMMENT");
    private static final Map<String,ObjectKind> KINDS=Map.ofEntries(Map.entry("TABLE",ObjectKind.TABLE),Map.entry("VIEW",ObjectKind.VIEW),Map.entry("INDEX",ObjectKind.INDEX),Map.entry("SCHEMA",ObjectKind.SCHEMA),Map.entry("DATABASE",ObjectKind.CATALOG),Map.entry("SEQUENCE",ObjectKind.SEQUENCE),Map.entry("FUNCTION",ObjectKind.ROUTINE),Map.entry("PROCEDURE",ObjectKind.ROUTINE),Map.entry("TRIGGER",ObjectKind.TRIGGER),Map.entry("CONSTRAINT",ObjectKind.CONSTRAINT),Map.entry("COLUMN",ObjectKind.COLUMN),Map.entry("TYPE",ObjectKind.TYPE),Map.entry("DOMAIN",ObjectKind.TYPE));
    private DdlImpact(){}
    /** A call or dynamic execution can hide arbitrary persistent and temporary
     * DDL. Its body is never executed or guessed by editor analysis. */
    public static boolean opaqueOperation(String operation){return Set.of("CALL","DO","EXECUTE").contains(operation.toUpperCase(Locale.ROOT));}
    public static List<DdlEffect> analyze(String sql,Engine engine,io.busystack.busydata.analysis.LexicalSettings lexical,ResolutionContext context){return analyze(LosslessLexer.scan(sql,new Dialect(engine,lexical),AnalysisBudget.interactive()),context);}
    public static List<DdlEffect> analyze(LosslessLexer.Document document,ResolutionContext context){
        var effects=new ArrayList<DdlEffect>();var tokens=document.significant();int start=0,depth=0;
        for(int i=0;i<=tokens.size();i++){
            if(i<tokens.size()){if(tokens.get(i).is("("))depth++;if(tokens.get(i).is(")"))depth=Math.max(0,depth-1);}
            if(i==tokens.size()||depth==0&&tokens.get(i).is(";")){if(i>start)effect(tokens.subList(start,i),document.dialect(),context,effects);start=i+1;}
        }return List.copyOf(effects);
    }
    private static void effect(List<Token> tokens,Dialect dialect,ResolutionContext context,List<DdlEffect> effects){
        String operation=tokens.getFirst().text().toUpperCase(Locale.ROOT);
        if(opaqueOperation(operation)){effects.add(conservative(operation,context,false));return;}
        if(operation.equals("SET")&&valueContextOnly(tokens,dialect))return;
        if(Set.of("USE","SET","RESET","DISCARD").contains(operation)){effects.add(DdlEffect.newBuilder().setOperation("CONTEXT").setCatalog(context.catalog()).setSchema(context.schema()).setKind(ObjectKind.SCHEMA).setConservative(true).build());return;}
        if(!DDL.contains(operation))return;int at=1;boolean temporary=false;ObjectKind kind=null;
        while(at<tokens.size()){
            var token=tokens.get(at);String word=token.text().toUpperCase(Locale.ROOT);if(word.equals("TEMP")||word.equals("TEMPORARY"))temporary=true;
            if(KINDS.containsKey(word)){kind=KINDS.get(word);at++;break;}at++;
        }
        if(kind==null&&operation.equals("TRUNCATE")){kind=ObjectKind.TABLE;at=1;}
        if(kind==null){effects.add(conservative(operation,context,temporary));return;}
        while(at<tokens.size()&&(tokens.get(at).is("IF")||tokens.get(at).is("NOT")||tokens.get(at).is("EXISTS")||tokens.get(at).is("ONLY")))at++;
        if(at>=tokens.size()||!tokens.get(at).name()){effects.add(conservative(operation,context,temporary));return;}
        var names=new ArrayList<Token>();names.add(tokens.get(at++));while(at+1<tokens.size()&&tokens.get(at).is(".")&&tokens.get(at+1).name()){names.add(tokens.get(at+1));at+=2;}
        if(names.size()>(dialect.postgres()?3:2)){effects.add(conservative(operation,context,temporary));return;}
        String catalog=names.size()>2?dialect.identifier(names.getFirst()):context.catalog(),schema=names.size()>1?dialect.identifier(names.get(names.size()-2)):context.schema(),name=dialect.identifier(names.getLast());
        if(!dialect.postgres()&&names.size()>1)catalog=schema;
        if(dialect.postgres()&&(schema.equals("pg_temp")||schema.startsWith("pg_temp_")))temporary=true;
        boolean conservative=kind==ObjectKind.INDEX||kind==ObjectKind.COLUMN||kind==ObjectKind.CONSTRAINT||kind==ObjectKind.TRIGGER||kind==ObjectKind.SCHEMA||kind==ObjectKind.CATALOG||uncertainTail(tokens,operation,at)||operation.equals("RENAME");
        effects.add(DdlEffect.newBuilder().setOperation(operation).setCatalog(catalog).setSchema(schema).setName(name).setKind(kind).setTemporary(temporary).setConservative(conservative).build());
    }
    /** Definition/key commas do not introduce additional DDL owners. The
     * supported native grammars place those lists inside delimiters. CREATE
     * query/table-option commas also follow one already established owner;
     * DROP object lists and uncertain multi-action ALTER remain conservative. */
    private static boolean uncertainTail(List<Token> tokens,String operation,int afterName){
        int parentheses=0,brackets=0;
        boolean singleCreate=operation.equals("CREATE")&&afterName<tokens.size()&&(tokens.get(afterName).is("(")||tokens.get(afterName).is("LIKE")||tokens.get(afterName).is("AS")||tokens.get(afterName).is("SELECT")||tokens.get(afterName).is("OF"));
        for(int index=afterName;index<tokens.size();index++){
            var token=tokens.get(index);if(!token.complete())return true;
            if(token.is("(")){parentheses++;continue;}
            if(token.is(")")){if(parentheses==0)return true;parentheses--;continue;}
            if(token.is("[")){brackets++;continue;}
            if(token.is("]")){if(brackets==0)return true;brackets--;continue;}
            if(parentheses==0&&brackets==0){
                if(token.is(",")&&!singleCreate)return true;
                if(token.is("CASCADE")||token.is("RENAME")||token.is("INHERITS")||token.is("PARTITION")||token.is("ATTACH")||token.is("DETACH"))return true;
            }
        }
        return parentheses!=0||brackets!=0;
    }
    /** Literal value-I/O settings change captured interpretation, not catalog structure. */
    private static boolean valueContextOnly(List<Token> tokens,Dialect dialect){
        int at=1;if(at<tokens.size()&&(tokens.get(at).is("SESSION")||tokens.get(at).is("LOCAL")||tokens.get(at).is("GLOBAL")))at++;
        if(at>=tokens.size()||!tokens.get(at++).is(dialect.postgres()?"array_nulls":"time_zone")||at>=tokens.size())return false;
        var assignment=tokens.get(at++);if(!assignment.is("=")&&!(dialect.postgres()&&assignment.is("TO")))return false;
        return at+1==tokens.size()&&(tokens.get(at).kind()==Kind.STRING||tokens.get(at).is("DEFAULT")||dialect.postgres()&&(tokens.get(at).is("ON")||tokens.get(at).is("OFF")||tokens.get(at).is("TRUE")||tokens.get(at).is("FALSE")));
    }
    private static DdlEffect conservative(String operation,ResolutionContext context,boolean temporary){return DdlEffect.newBuilder().setOperation(operation).setCatalog(context.catalog()).setSchema(context.schema()).setKind(ObjectKind.SCHEMA).setTemporary(temporary).setConservative(true).build();}
}
