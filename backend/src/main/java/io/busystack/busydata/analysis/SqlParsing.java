package io.busystack.busydata.analysis;

import io.busystack.busydata.protocol.Engine;
import java.util.concurrent.*;
import net.sf.jsqlparser.parser.CCJSqlParserUtil;
import net.sf.jsqlparser.statement.Statement;

/** Bounded tolerant-analysis parsing; this is never an execution authorization. */
public final class SqlParsing {
    private static final ExecutorService CPU=new ThreadPoolExecutor(2,2,0,TimeUnit.MILLISECONDS,
        new ArrayBlockingQueue<>(8),Thread.ofPlatform().daemon().name("busydata-parser-",0).factory(),new ThreadPoolExecutor.AbortPolicy());
    private SqlParsing(){}
    public static void validate(String sql,Engine engine){validate(sql,engine,LexicalSettings.DEFAULT);}
    public static void validate(String sql,Engine engine,LexicalSettings settings){
        if(sql.length()>262144)throw new IllegalArgumentException("Parser snapshot exceeds 256Ki UTF-16 units");
        int depth=0;
        for(var token:SqlLexer.scan(sql,engine,settings)){
            if(!token.complete())throw new IllegalArgumentException("Incomplete SQL token");
            if(token.kind()==SqlLexer.Kind.SYMBOL&&token.text().equals("(")){if(++depth>64)throw new IllegalArgumentException("SQL nesting exceeds the analysis budget (64)");}
            if(token.kind()==SqlLexer.Kind.SYMBOL&&token.text().equals(")")&&--depth<0)throw new IllegalArgumentException("Unbalanced SQL parentheses");
        }
        if(depth!=0)throw new IllegalArgumentException("Incomplete SQL parentheses");
    }
    public static Statement parse(String sql,Engine engine)throws net.sf.jsqlparser.JSQLParserException {
        return parse(sql,engine,LexicalSettings.DEFAULT);
    }
    public static Statement parse(String sql,Engine engine,LexicalSettings settings)throws net.sf.jsqlparser.JSQLParserException {
        return parse(sql,engine,settings,CPU);
    }
    /** Same parser boundary with an owned executor; package scope permits deterministic scheduling tests. */
    static Statement parse(String sql,Engine engine,LexicalSettings settings,ExecutorService executor)throws net.sf.jsqlparser.JSQLParserException {
        checkCancellation();
        validate(sql,engine,settings);
        boolean pg=engine==Engine.POSTGRESQL;
        var statements=CCJSqlParserUtil.parseStatements(sql,executor,parser->parser.withAllowedNestingDepth(64).withTimeOut(250).withBackslashEscapeCharacter(pg?!settings.standardConformingStrings():!settings.noBackslashEscapes()).withDoubleQuotedStrings(!pg&&!settings.ansiQuotes()).withHashLineComments(!pg));
        // A completed Future may return without observing the caller's interrupt.
        checkCancellation();
        if(statements.size()!=1)throw new IllegalArgumentException("Provide one complete SQL statement");
        return statements.getFirst();
    }
    private static void checkCancellation(){
        if(Thread.currentThread().isInterrupted())throw new CancellationException("SQL parsing cancelled");
    }
    public static void expression(String expression,Engine engine)throws net.sf.jsqlparser.JSQLParserException {expression(expression,engine,LexicalSettings.DEFAULT);}
    public static void expression(String expression,Engine engine,LexicalSettings settings)throws net.sf.jsqlparser.JSQLParserException {
        // Parse a complete SELECT on the same bounded executor. A trailing
        // statement or alias is not a column default/generated expression.
        int depth=0;for(var token:SqlLexer.scan(expression,engine,settings))if(token.kind()==SqlLexer.Kind.SYMBOL){if(token.text().equals(";"))throw new IllegalArgumentException("Expressions cannot contain statement delimiters");if(token.text().equals("("))depth++;if(token.text().equals(")")&&--depth<0)throw new IllegalArgumentException("Expression parentheses are unbalanced");}
        if(depth!=0)throw new IllegalArgumentException("Expression parentheses are unbalanced");
        var statement=parse("SELECT ("+expression+")",engine,settings);
        if(!(statement instanceof net.sf.jsqlparser.statement.select.PlainSelect select)||select.getSelectItems().size()!=1||select.getSelectItems().getFirst().getAlias()!=null)throw new IllegalArgumentException("Provide one SQL expression");
    }
    public static java.util.Set<String> tables(String sql,Engine engine)throws net.sf.jsqlparser.JSQLParserException {
        try{var tables=new net.sf.jsqlparser.util.TablesNamesFinder<>().getTables(parse(sql,engine));if(tables.size()>1024)throw new IllegalArgumentException("Definition dependency limit exceeded");return java.util.Set.copyOf(tables);}
        catch(StackOverflowError tooDeep){throw new IllegalArgumentException("Definition dependency nesting exceeds its analysis budget");}
    }
}
