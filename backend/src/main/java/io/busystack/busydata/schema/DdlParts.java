package io.busystack.busydata.schema;

import java.util.*;

/** Preserve native SHOW CREATE fragments without an AST round trip. */
public record DdlParts(String prefix,List<String> parts,String suffix) {
    public DdlParts {parts=List.copyOf(parts);}
    public static DdlParts table(String sql) {
        if(sql.length()>1_048_576)throw new IllegalArgumentException("Native table definition exceeds 1Mi UTF-16 units");
        int open=-1,start=-1,depth=0;char quote=0;boolean comment=false;
        var parts=new ArrayList<String>();
        for(int i=0;i<sql.length();i++) {
            char c=sql.charAt(i),next=i+1<sql.length()?sql.charAt(i+1):0;
            if(comment){if(c=='*'&&next=='/'){comment=false;i++;}continue;}
            if(quote!=0){if(c==quote){if(next==quote)i++;else quote=0;}else if(c=='\\'&&quote=='\'')i++;continue;}
            if(c=='/'&&next=='*'){comment=true;i++;continue;}
            if(c=='\''||c=='"'||c=='`'){quote=c;continue;}
            if(c=='('){if(depth++==0){open=i;start=i+1;}if(depth>64)throw new IllegalArgumentException("Native definition nesting limit reached");}
            else if(c==')') {
                if(--depth==0){parts.add(sql.substring(start,i).trim());return new DdlParts(sql.substring(0,open),parts,sql.substring(i+1));}
                if(depth<0)throw new IllegalArgumentException("Malformed native definition");
            }else if(c==','&&depth==1){if(parts.size()>=4096)throw new IllegalArgumentException("Native definition item limit reached");parts.add(sql.substring(start,i).trim());start=i+1;}
        }
        throw new IllegalArgumentException("Native definition has no balanced table body");
    }
    public String render(List<String> selected){return prefix+"(\n  "+String.join(",\n  ",selected)+"\n)"+suffix;}
    /** Only the leading native constraint grammar is interpreted. Expressions,
     * quoted SQL and trailing native options remain byte-for-byte source. */
    public record Constraint(String name,String type,String definition){}
    public static String constraintBody(String definition,String exactName){
        if(definition.length()>1_048_576)throw new IllegalArgumentException("Native constraint definition exceeds its budget");
        String rest=definition.stripLeading();if(!word(rest,"CONSTRAINT"))throw new IllegalArgumentException("Expected an exact named native constraint header");
        rest=after(rest,"CONSTRAINT");var identifier=identifier(rest);if(!identifier.name.equals(exactName))throw new IllegalArgumentException("Constraint definition name disagrees with its exact identity");
        return rest.substring(identifier.end).stripLeading();
    }
    public static Constraint constraint(String text) {
        if(text.length()>1_048_576)throw new IllegalArgumentException("Native constraint definition exceeds its budget");
        String rest=text.stripLeading(),name="";boolean named=word(rest,"CONSTRAINT");
        if(named){rest=rest.substring(10).stripLeading();var identifier=identifier(rest);name=identifier.name;rest=rest.substring(identifier.end).stripLeading();}
        String type;
        if(words(rest,"PRIMARY","KEY")){type="PRIMARY KEY";rest=after(rest,"PRIMARY");rest=after(rest,"KEY");if(!named)name="PRIMARY";}
        else if(word(rest,"UNIQUE")){
            type="UNIQUE";rest=after(rest,"UNIQUE");if(word(rest,"KEY"))rest=after(rest,"KEY");else if(word(rest,"INDEX"))rest=after(rest,"INDEX");
            if(!rest.startsWith("(")){var identifier=identifier(rest);if(named&&!name.equals(identifier.name))throw new IllegalArgumentException("Conflicting native constraint/index identities");name=identifier.name;rest=rest.substring(identifier.end).stripLeading();}
        }else if(words(rest,"FOREIGN","KEY")){type="FOREIGN KEY";rest=after(after(rest,"FOREIGN"),"KEY");}
        else if(word(rest,"CHECK")){type="CHECK";rest=after(rest,"CHECK");}
        else {if(named)throw new IllegalArgumentException("Unsupported named native constraint grammar");return null;}
        if(name.isEmpty()||!rest.startsWith("("))throw new IllegalArgumentException("Exact native constraint name/body unavailable");
        return new Constraint(name,type,text);
    }
    private record Identifier(String name,int end){}
    private static Identifier identifier(String text){
        if(text.isEmpty()||text.charAt(0)!='`'&&text.charAt(0)!='"')throw new IllegalArgumentException("Expected an exact quoted native identifier");
        char quote=text.charAt(0);var name=new StringBuilder();
        for(int i=1;i<text.length();i++){char c=text.charAt(i);if(c==quote){if(i+1<text.length()&&text.charAt(i+1)==quote){name.append(c);i++;}else return new Identifier(name.toString(),i+1);}else name.append(c);}
        throw new IllegalArgumentException("Malformed quoted native identifier");
    }
    private static boolean word(String text,String word){return text.regionMatches(true,0,word,0,word.length())&&(text.length()==word.length()||!Character.isJavaIdentifierPart(text.charAt(word.length())));}
    private static boolean words(String text,String first,String second){return word(text,first)&&word(after(text,first),second);}
    private static String after(String text,String word){return text.substring(word.length()).stripLeading();}
    public static String leadingIdentifier(String text) {
        text=text.stripLeading();if(text.isEmpty())return "";
        char quote=text.charAt(0);if(quote!='`'&&quote!='"')return "";
        var value=new StringBuilder();for(int i=1;i<text.length();i++){char c=text.charAt(i);if(c==quote){if(i+1<text.length()&&text.charAt(i+1)==quote){value.append(c);i++;}else return value.toString();}else value.append(c);}
        throw new IllegalArgumentException("Malformed quoted native identifier");
    }
}
