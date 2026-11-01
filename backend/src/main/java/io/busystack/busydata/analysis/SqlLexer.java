package io.busystack.busydata.analysis;

import io.busystack.busydata.protocol.Engine;
import java.util.*;

/** Lossless editor lexer. Positions are UTF-16; incomplete tokens remain tokens. */
public final class SqlLexer {
    public enum Kind { WORD, IDENTIFIER, STRING, COMMENT, SYMBOL }
    public record Token(Kind kind, String text, int start, int end, boolean complete) {
        public boolean is(String word) { return kind==Kind.WORD && text.equalsIgnoreCase(word); }
    }
    public static List<Token> scan(String sql, Engine engine) {
        return scan(sql,engine,false,false);
    }
    public static List<Token> scan(String sql, Engine engine, boolean noBackslashEscapes, boolean ansiQuotes) {
        return scan(sql,engine,new LexicalSettings(noBackslashEscapes,ansiQuotes,true));
    }
    public static List<Token> scan(String sql,Engine engine,LexicalSettings settings) {
        if(sql.length()>8_000_000)throw new IllegalArgumentException("Document exceeds 8M UTF-16 units");
        var tokens=new ArrayList<Token>(); boolean postgres=engine==Engine.POSTGRESQL;
        for(int i=0;i<sql.length();) {
            char c=sql.charAt(i);if(SqlLexicalCharacters.isSpace(c)){i++;continue;}
            int start=i; Kind kind; boolean complete=true;
            if(sql.startsWith("--",i)&&(postgres||i+2==sql.length()||SqlLexicalCharacters.mysqlCommentFollower(sql.codePointAt(i+2)))||c=='#'&&!postgres) {
                kind=Kind.COMMENT;while(i<sql.length()&&sql.charAt(i)!='\r'&&sql.charAt(i)!='\n')i++;
            } else if(sql.startsWith("/*",i)) {
                kind=Kind.COMMENT;i+=2;int depth=1;
                while(i<sql.length()&&depth>0){if(postgres&&sql.startsWith("/*",i)){depth++;i+=2;}else if(sql.startsWith("*/",i)){depth--;i+=2;}else i++;}
                complete=depth==0;
            } else if(c=='\''||c=='"'||c=='`'&&!postgres) {
                kind=c=='\''||c=='"'&&!postgres&&!settings.ansiQuotes()?Kind.STRING:Kind.IDENTIFIER;
                boolean backslash=kind==Kind.STRING&&(!postgres&&!settings.noBackslashEscapes()||postgres&&c=='\''&&(!settings.standardConformingStrings()||start>0&&(sql.charAt(start-1)=='e'||sql.charAt(start-1)=='E')&&(start<2||!SqlLexicalCharacters.identifierPart(sql.codePointBefore(start-1),engine))));
                complete=false;i++;
                while(i<sql.length()){char value=sql.charAt(i++);if(value==c){if(i<sql.length()&&sql.charAt(i)==c)i++;else{complete=true;break;}}else if(value=='\\'&&backslash&&i<sql.length())i++;}
            } else if(c=='$'&&postgres&&(i==0||!SqlLexicalCharacters.identifierPart(sql.codePointBefore(i),engine))) {
                int tag=i+1;while(tag<sql.length()&&SqlLexicalCharacters.dollarTagPart(sql.codePointAt(tag)))tag+=Character.charCount(sql.codePointAt(tag));
                if(tag<sql.length()&&sql.charAt(tag)=='$'&&(tag==i+1||SqlLexicalCharacters.identifierStart(sql.codePointAt(i+1),engine))) {
                    kind=Kind.STRING;String delimiter=sql.substring(i,tag+1);int end=sql.indexOf(delimiter,tag+1);complete=end>=0;i=complete?end+delimiter.length():sql.length();
                }else{kind=Kind.SYMBOL;i++;}
            } else if(SqlLexicalCharacters.identifierStart(sql.codePointAt(i),engine)) {
                kind=Kind.WORD;i+=Character.charCount(sql.codePointAt(i));while(i<sql.length()&&SqlLexicalCharacters.identifierPart(sql.codePointAt(i),engine))i+=Character.charCount(sql.codePointAt(i));
            } else {kind=Kind.SYMBOL;i++;}
            if(tokens.size()>=100_000)throw new IllegalArgumentException("SQL lexical token budget exceeded");
            tokens.add(new Token(kind,sql.substring(start,i),start,i,complete));
        }
        return List.copyOf(tokens);
    }
    /** Changes whitespace only, never parser serialization or token contents. */
    public static String format(String sql, Engine engine) {
        return format(sql,engine,LexicalSettings.DEFAULT);
    }
    public static String format(String sql,Engine engine,LexicalSettings settings) {
        try {
            var result=io.busystack.busydata.analysis.language.SqlFormatter.format(sql,
                new io.busystack.busydata.analysis.language.Dialect(engine,settings),
                io.busystack.busydata.analysis.language.SqlFormatter.Options.DEFAULT,0,sql.length(),
                io.busystack.busydata.analysis.language.AnalysisBudget.interactive());
            return result.available()?result.sql():"";
        } catch(io.busystack.busydata.analysis.language.AnalysisBudget.Limit limit){return "";}
    }
}
