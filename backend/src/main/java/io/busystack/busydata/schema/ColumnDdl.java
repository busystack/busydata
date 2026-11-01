package io.busystack.busydata.schema;

import java.util.*;

/** Native MySQL column fragments, with quoted strings and nested expressions retained. */
final class ColumnDdl {
    private record Token(String word,int start,int end){}
    private static final Set<String> CLAUSES=Set.of("NOT","NULL","DEFAULT","GENERATED","AUTO_INCREMENT","COMMENT","COLLATE","CHARACTER","ON","VISIBLE","INVISIBLE","COLUMN_FORMAT","STORAGE","REFERENCES","CHECK","PRIMARY","UNIQUE");
    static String canonicalProperties(String original,String charset,String collation){
        if(!collation.isEmpty()&&!collation.matches("[A-Za-z0-9_]{1,128}"))throw new IllegalArgumentException("Invalid catalog collation");
        if(!charset.isEmpty()&&!charset.matches("[A-Za-z0-9_]{1,128}"))throw new IllegalArgumentException("Invalid catalog character set");
        String without=original;
        for(String clause:List.of("CHARACTER","COLLATE")) {
            var parsed=tokens(without);
            for(int i=1;i<parsed.size();i++)if(parsed.get(i).word().equals(clause)) {
                int end=without.length();for(int j=i+1;j<parsed.size();j++)if(CLAUSES.contains(parsed.get(j).word())){end=parsed.get(j).start();break;}
                without=(without.substring(0,parsed.get(i).start()).stripTrailing()+" "+without.substring(end).stripLeading()).stripTrailing();break;
            }
        }
        var parsed=tokens(without);int offset=without.length();
        for(int i=1;i<parsed.size();i++)if(CLAUSES.contains(parsed.get(i).word())){offset=parsed.get(i).start();break;}
        return without.substring(0,offset).stripTrailing()+(charset.isEmpty()?"":" CHARACTER SET "+charset)+(collation.isEmpty()?"":" COLLATE "+collation)+(offset<without.length()?" "+without.substring(offset).stripLeading():"");
    }
    static String canonicalCharacterSet(String original,String charset){
        if(charset.isEmpty())return original;
        if(!charset.matches("[A-Za-z0-9_]{1,128}"))throw new IllegalArgumentException("Invalid catalog character set");
        String without=original;var tokens=tokens(original);
        for(int i=1;i<tokens.size();i++)if(tokens.get(i).word().equals("CHARACTER")){
            int end=original.length();for(int j=i+1;j<tokens.size();j++)if(CLAUSES.contains(tokens.get(j).word())){end=tokens.get(j).start();break;}
            without=(original.substring(0,tokens.get(i).start()).stripTrailing()+" "+original.substring(end).stripLeading()).stripTrailing();break;
        }
        tokens=tokens(without);int offset=without.length();
        for(int i=1;i<tokens.size();i++)if(CLAUSES.contains(tokens.get(i).word())){offset=tokens.get(i).start();break;}
        return without.substring(0,offset).stripTrailing()+" CHARACTER SET "+charset+(offset<without.length()?" "+without.substring(offset).stripLeading():"");
    }
    static String change(String original,String property,String value){return change(original,property,value,false);}
    static String change(String original,String property,String value,boolean noBackslashEscapes){
        var tokens=tokens(original,noBackslashEscapes);if(tokens.isEmpty())throw new IllegalArgumentException("Native column definition unavailable");
        if(property.equals("type")){
            int start=tokens.getFirst().end(),end=original.length();
            for(int i=1;i<tokens.size();i++)if(CLAUSES.contains(tokens.get(i).word())){end=tokens.get(i).start();break;}
            return original.substring(0,start)+" "+value+" "+original.substring(end).stripLeading();
        }
        String clause=switch(property){case "nullable"->"NOT";case "default"->"DEFAULT";case "identity"->"AUTO_INCREMENT";case "generated"->"GENERATED";case "comment"->"COMMENT";case "collation"->"COLLATE";default->throw new IllegalArgumentException("Unsupported column property");};
        int start=-1,end=original.length();
        for(int i=1;i<tokens.size();i++){
            var token=tokens.get(i);boolean matched=token.word().equals(clause)||property.equals("nullable")&&token.word().equals("NULL");
            if(!matched)continue;start=token.start();
            for(int j=i+1;j<tokens.size();j++){
                String word=tokens.get(j).word();
                if(property.equals("nullable")&&word.equals("NULL"))continue;
                if(property.equals("default")&&j==i+1&&word.equals("NULL"))continue;
                if(property.equals("generated")&&Set.of("ALWAYS","AS","STORED","VIRTUAL").contains(word))continue;
                if(CLAUSES.contains(word)){end=tokens.get(j).start();break;}
            }break;
        }
        String replacement=switch(property){
            case "nullable"->Boolean.parseBoolean(value)?"":"NOT NULL";
            case "default"->value.isEmpty()?"":"DEFAULT "+value;
            case "identity"->value.equals("none")?"":"AUTO_INCREMENT";
            case "generated"->value.isEmpty()?"":"GENERATED ALWAYS AS ("+value+") STORED";
            case "comment"->"COMMENT '"+(noBackslashEscapes?value:value.replace("\\","\\\\")).replace("'","''")+"'";
            case "collation"->value.isEmpty()?"":"COLLATE "+value;
            default->throw new IllegalArgumentException();
        };
        if(start<0)return original+(replacement.isEmpty()?"":" "+replacement);
        return (original.substring(0,start)+replacement+" "+original.substring(end)).stripTrailing();
    }
    private static List<Token> tokens(String sql){return tokens(sql,false);}
    private static List<Token> tokens(String sql,boolean noBackslashEscapes){
        var out=new ArrayList<Token>();int depth=0;char quote=0;
        for(int i=0;i<sql.length();){char c=sql.charAt(i);
            if(quote!=0){if(c=='\\'&&quote!='`'&&!noBackslashEscapes){i+=Math.min(2,sql.length()-i);continue;}if(c==quote){if(i+1<sql.length()&&sql.charAt(i+1)==quote){i+=2;continue;}quote=0;}i++;continue;}
            if(c=='\''||c=='"'||c=='`'){int start=i;quote=c;i++;if(out.isEmpty()){
                while(i<sql.length()){if(sql.charAt(i)==c){if(i+1<sql.length()&&sql.charAt(i+1)==c){i+=2;continue;}i++;quote=0;break;}i++;}out.add(new Token("IDENTIFIER",start,i));}continue;}
            if(c=='('){depth++;i++;continue;}if(c==')'){depth--;i++;continue;}
            if(depth==0&&(Character.isLetter(c)||c=='_')){int start=i++;while(i<sql.length()&&(Character.isLetterOrDigit(sql.charAt(i))||sql.charAt(i)=='_'))i++;out.add(new Token(sql.substring(start,i).toUpperCase(Locale.ROOT),start,i));}else i++;
        }return out;
    }
}
