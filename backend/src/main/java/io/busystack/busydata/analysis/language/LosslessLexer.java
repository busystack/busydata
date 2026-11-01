package io.busystack.busydata.analysis.language;

import java.util.*;
import io.busystack.busydata.analysis.SqlLexicalCharacters;

/** Every UTF-16 unit belongs to exactly one token, including whitespace and errors. */
public final class LosslessLexer {
    public enum Kind { WORD,IDENTIFIER,STRING,NUMBER,PARAMETER,OPERATOR,PUNCTUATION,WHITESPACE,COMMENT,ERROR }
    public record Token(Kind kind,String text,int start,int end,boolean complete) {
        public boolean is(String value){return kind==Kind.WORD&&text.equalsIgnoreCase(value)||kind!=Kind.WORD&&text.equals(value);}
        public boolean name(){return kind==Kind.WORD||kind==Kind.IDENTIFIER;}
        public boolean quoted(){return kind==Kind.IDENTIFIER;}
        public boolean trivia(){return kind==Kind.WHITESPACE||kind==Kind.COMMENT;}
        public String identifier(){
            if(!quoted())return text;
            char quote=text.charAt(0);String inner=text.substring(1,complete?text.length()-1:text.length());return inner.replace(""+quote+quote,""+quote);
        }
    }
    public record Document(String source,Dialect dialect,List<Token> tokens,List<Token> significant) {
        public Document {tokens=List.copyOf(tokens);significant=List.copyOf(significant);}
        public Token protectedAt(int caret){for(var token:tokens)if(caret>=token.start()&&(caret<token.end()||caret==token.end()&&(!token.complete()||token.kind()==Kind.COMMENT&&(token.text().startsWith("--")||token.text().startsWith("#"))))&&(token.kind()==Kind.STRING||token.kind()==Kind.COMMENT))return token;return null;}
    }
    private static final List<String> OPERATORS=List.of("#>>","->>","<=>","!~~*","~~*","!~~","!~*","::",":=","->","#>","@>","<@","?|","?&","||","&&","<=",">=","<>","!=","<<",">>","!~","~*","~~","@?","@@","**","..");
    private LosslessLexer(){}
    public static Document scan(String sql,Dialect dialect,AnalysisBudget budget){
        if(sql.length()>AnalysisBudget.MAX_DOCUMENT_UNITS)throw new AnalysisBudget.Limit("SQL document exceeds 256Ki UTF-16 units");
        var all=new ArrayList<Token>();var significant=new ArrayList<Token>();
        for(int at=0;at<sql.length();) {
            if((all.size()&255)==0)budget.check();
            int start=at;char c=sql.charAt(at);Kind kind;boolean complete=true;
            if(SqlLexicalCharacters.isSpace(c)){kind=Kind.WHITESPACE;do{at++;}while(at<sql.length()&&SqlLexicalCharacters.isSpace(sql.charAt(at)));}
            else if(sql.startsWith("--",at)&&(dialect.postgres()||at+2==sql.length()||SqlLexicalCharacters.mysqlCommentFollower(sql.codePointAt(at+2)))||!dialect.postgres()&&c=='#'){
                kind=Kind.COMMENT;while(at<sql.length()&&sql.charAt(at)!='\r'&&sql.charAt(at)!='\n')at++;
            }else if(sql.startsWith("/*",at)){
                kind=Kind.COMMENT;int depth=1;at+=2;
                while(at<sql.length()&&depth>0){if((at&4095)==0)budget.check();if(dialect.postgres()&&sql.startsWith("/*",at)){depth++;at+=2;}else if(sql.startsWith("*/",at)){depth--;at+=2;}else at++;}
                complete=depth==0;
            }else if(c=='\''||c=='"'||!dialect.postgres()&&c=='`'){
                kind=c=='\''||c=='"'&&!dialect.postgres()&&!dialect.lexical().ansiQuotes()?Kind.STRING:Kind.IDENTIFIER;
                boolean escape=kind==Kind.STRING&&(dialect.postgres()?!dialect.lexical().standardConformingStrings()||start>0&&(sql.charAt(start-1)=='E'||sql.charAt(start-1)=='e')&&(start<2||!SqlLexicalCharacters.identifierPart(sql.codePointBefore(start-1),dialect.engine())):!dialect.lexical().noBackslashEscapes());
                at++;complete=false;
                while(at<sql.length()){if((at&4095)==0)budget.check();char current=sql.charAt(at++);if(current==c){if(at<sql.length()&&sql.charAt(at)==c)at++;else{complete=true;break;}}else if(current=='\\'&&escape&&at<sql.length())at++;}
                if(kind==Kind.IDENTIFIER&&!dialect.postgres())for(int offset=start;offset<at;offset++)if(Character.isSurrogate(sql.charAt(offset))){kind=Kind.ERROR;break;}
            }else if(c=='$'&&dialect.postgres()&&(at==0||!SqlLexicalCharacters.identifierPart(sql.codePointBefore(at),dialect.engine()))){
                int tag=at+1;while(tag<sql.length()&&SqlLexicalCharacters.dollarTagPart(sql.codePointAt(tag)))tag+=Character.charCount(sql.codePointAt(tag));
                if(tag<sql.length()&&sql.charAt(tag)=='$'&&(tag==at+1||SqlLexicalCharacters.identifierStart(sql.codePointAt(at+1),dialect.engine()))){
                    kind=Kind.STRING;String delimiter=sql.substring(at,tag+1);int end=sql.indexOf(delimiter,tag+1);complete=end>=0;at=complete?end+delimiter.length():sql.length();
                }else if(at+1<sql.length()&&SqlLexicalCharacters.isDigit(sql.charAt(at+1))){kind=Kind.PARAMETER;at+=2;while(at<sql.length()&&SqlLexicalCharacters.isDigit(sql.charAt(at)))at++;}
                else{kind=Kind.OPERATOR;at++;}
            }else if(c==':'&&at+1<sql.length()&&sql.charAt(at+1)!=':'&&SqlLexicalCharacters.identifierStart(sql.codePointAt(at+1),dialect.engine())&&!SqlLexicalCharacters.isDigit(sql.codePointAt(at+1))){
                kind=Kind.PARAMETER;at++;while(at<sql.length()&&SqlLexicalCharacters.identifierPart(sql.codePointAt(at),dialect.engine()))at+=Character.charCount(sql.codePointAt(at));
            }else if(SqlLexicalCharacters.isDigit(c)||c=='.'&&at+1<sql.length()&&SqlLexicalCharacters.isDigit(sql.charAt(at+1))){
                if(dialect.postgres()){
                    var number=postgresNumber(sql,at,budget);at=number.end();kind=number.valid()?Kind.NUMBER:Kind.ERROR;
                }else{
                kind=Kind.NUMBER;at++;
                while(at<sql.length()&&(SqlLexicalCharacters.isDigit(sql.charAt(at))||sql.charAt(at)=='_'))at++;
                if(at<sql.length()&&sql.charAt(at)=='.'&&c!='.'){at++;while(at<sql.length()&&(SqlLexicalCharacters.isDigit(sql.charAt(at))||sql.charAt(at)=='_'))at++;}
                if(at<sql.length()&&(sql.charAt(at)=='e'||sql.charAt(at)=='E')){int exponent=at++;if(at<sql.length()&&(sql.charAt(at)=='+'||sql.charAt(at)=='-'))at++;int digits=at;while(at<sql.length()&&(SqlLexicalCharacters.isDigit(sql.charAt(at))||sql.charAt(at)=='_'))at++;if(at==digits)at=exponent;}
                if(!dialect.postgres()&&sql.substring(start,at).chars().allMatch(value->value>='0'&&value<='9'||value=='_')&&at<sql.length()&&SqlLexicalCharacters.identifierPart(sql.codePointAt(at),dialect.engine())){kind=Kind.WORD;while(at<sql.length()&&SqlLexicalCharacters.identifierPart(sql.codePointAt(at),dialect.engine()))at+=Character.charCount(sql.codePointAt(at));}
                }
            }else if(SqlLexicalCharacters.identifierStart(sql.codePointAt(at),dialect.engine())){
                kind=Kind.WORD;at+=Character.charCount(sql.codePointAt(at));while(at<sql.length()&&SqlLexicalCharacters.identifierPart(sql.codePointAt(at),dialect.engine()))at+=Character.charCount(sql.codePointAt(at));
            }else{
                String operator=null;for(String value:OPERATORS)if(sql.startsWith(value,at)){operator=value;break;}
                if(operator!=null){kind=Kind.OPERATOR;at+=operator.length();}
                else{kind="(),.;[]".indexOf(c)>=0?Kind.PUNCTUATION:c=='?'?Kind.PARAMETER:"+-*/%=<>!~^|&@#\\:".indexOf(c)>=0?Kind.OPERATOR:Kind.ERROR;at+=Character.charCount(sql.codePointAt(at));}
            }
            if(all.size()>=AnalysisBudget.MAX_TOKENS)throw new AnalysisBudget.Limit("SQL token budget exceeded");
            var token=new Token(kind,sql.substring(start,at),start,at,complete);all.add(token);if(!token.trivia())significant.add(token);
        }
        budget.check();return new Document(sql,dialect,all,significant);
    }
    private record Numeric(int end,boolean valid,boolean digits){}
    private static Numeric digitRun(String sql,int at,int radix,boolean prefixSeparator,AnalysisBudget budget){
        boolean valid=true,separator=false,digits=false;if(prefixSeparator&&at<sql.length()&&sql.charAt(at)=='_'){at++;separator=true;}
        for(;at<sql.length();at++){
            if((at&4095)==0)budget.check();char value=sql.charAt(at);int digit=value>='0'&&value<='9'?value-'0':value>='a'&&value<='f'?value-'a'+10:value>='A'&&value<='F'?value-'A'+10:-1;
            if(digit>=0&&digit<radix){digits=true;separator=false;continue;}
            if(value=='_'){if(separator||!digits)valid=false;separator=true;continue;}break;
        }return new Numeric(at,valid&&!separator,digits);
    }
    /** PostgreSQL17 scan.l numeric/radix separators and trailing-junk rules.
     * A malformed numeric region is one lossless error token, not guessed names. */
    private static Numeric postgresNumber(String sql,int start,AnalysisBudget budget){
        int at=start;boolean valid=true;
        if(sql.charAt(at)=='0'&&at+1<sql.length()){
            int radix=switch(Character.toLowerCase(sql.charAt(at+1))){case 'x'->16;case 'o'->8;case 'b'->2;default->0;};
            if(radix!=0){var run=digitRun(sql,at+2,radix,true,budget);at=run.end();valid=run.valid()&&run.digits();
                if(at<sql.length()&&SqlLexicalCharacters.identifierPart(sql.codePointAt(at),io.busystack.busydata.protocol.Engine.POSTGRESQL)){valid=false;while(at<sql.length()&&SqlLexicalCharacters.identifierPart(sql.codePointAt(at),io.busystack.busydata.protocol.Engine.POSTGRESQL)){if((at&4095)==0)budget.check();at+=Character.charCount(sql.codePointAt(at));}}
                return new Numeric(at,valid,true);
            }
        }
        if(sql.charAt(at)=='.'){at++;var run=digitRun(sql,at,10,false,budget);at=run.end();valid=run.valid()&&run.digits();}
        else {var run=digitRun(sql,at,10,false,budget);at=run.end();valid=run.valid();
            if(at<sql.length()&&sql.charAt(at)=='.'&&(at+1==sql.length()||sql.charAt(at+1)!='.')){at++;var fraction=digitRun(sql,at,10,false,budget);at=fraction.end();valid&=fraction.valid();}
        }
        if(at<sql.length()&&(sql.charAt(at)=='e'||sql.charAt(at)=='E')){at++;if(at<sql.length()&&(sql.charAt(at)=='+'||sql.charAt(at)=='-'))at++;var run=digitRun(sql,at,10,false,budget);at=run.end();valid&=run.valid()&&run.digits();}
        if(at<sql.length()&&SqlLexicalCharacters.identifierPart(sql.codePointAt(at),io.busystack.busydata.protocol.Engine.POSTGRESQL)){valid=false;while(at<sql.length()&&SqlLexicalCharacters.identifierPart(sql.codePointAt(at),io.busystack.busydata.protocol.Engine.POSTGRESQL)){if((at&4095)==0)budget.check();at+=Character.charCount(sql.codePointAt(at));}}
        return new Numeric(at,valid,true);
    }
}
