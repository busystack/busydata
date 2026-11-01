package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.Engine;
import java.nio.charset.StandardCharsets;
import java.util.*;

/** Decodes only pinned servers' canonical COLUMN_TYPE output, never editor SQL. */
public final class NativeEnumSet {
    public enum Kind { ENUM,SET }
    public enum Availability { AVAILABLE,UNSUPPORTED,MALFORMED,LIMITED }
    public record Declaration(Kind kind,List<String> members,Availability availability){public Declaration {members=List.copyOf(members);}public boolean available(){return availability==Availability.AVAILABLE;}}
    private NativeEnumSet(){}
    public static Declaration decode(String declaration,Engine engine){
        if(engine!=Engine.MYSQL&&engine!=Engine.MARIADB)return unavailable(null,Availability.UNSUPPORTED);
        if(declaration==null)return unavailable(null,Availability.MALFORMED);
        Kind kind=declaration.startsWith("enum(")?Kind.ENUM:declaration.startsWith("set(")?Kind.SET:null;
        if(kind==null)return unavailable(null,Availability.UNSUPPORTED);
        if(declaration.length()>32768||declaration.getBytes(StandardCharsets.UTF_8).length>32768)return unavailable(kind,Availability.LIMITED);
        for(int index=0;index<declaration.length();index++){char unit=declaration.charAt(index);if(Character.isHighSurrogate(unit)){if(++index==declaration.length()||!Character.isLowSurrogate(declaration.charAt(index)))return unavailable(kind,Availability.MALFORMED);}else if(Character.isLowSurrogate(unit))return unavailable(kind,Availability.MALFORMED);}
        int at=kind==Kind.ENUM?5:4;var members=new ArrayList<String>();
        while(at<declaration.length()){
            if(members.size()>=(kind==Kind.SET?64:1024))return unavailable(kind,Availability.LIMITED);
            if(declaration.charAt(at)!='\'')return unavailable(kind,declaration.charAt(at)=='x'||declaration.charAt(at)=='X'?Availability.UNSUPPORTED:Availability.MALFORMED);
            at++;var member=new StringBuilder();boolean closed=false;
            while(at<declaration.length()){
                char unit=declaration.charAt(at++);
                if(unit=='\''){if(at<declaration.length()&&declaration.charAt(at)=='\''){member.append('\'');at++;}else{closed=true;break;}}
                else if(unit=='\\'){
                    if(at==declaration.length())return unavailable(kind,Availability.MALFORMED);
                    char escaped=declaration.charAt(at++);switch(escaped){case '0'->member.append('\0');case 'n'->member.append('\n');case 'r'->member.append('\r');case '\\'->member.append('\\');default->{return unavailable(kind,Availability.UNSUPPORTED);}}
                }else if(unit==0||unit=='\n'||unit=='\r')return unavailable(kind,Availability.MALFORMED);
                else member.append(unit);
            }
            if(!closed||at>=declaration.length())return unavailable(kind,Availability.MALFORMED);members.add(member.toString());char separator=declaration.charAt(at++);
            if(separator==')')return at==declaration.length()?new Declaration(kind,members,Availability.AVAILABLE):unavailable(kind,Availability.MALFORMED);
            if(separator!=',')return unavailable(kind,Availability.MALFORMED);
        }
        return unavailable(kind,Availability.MALFORMED);
    }
    private static Declaration unavailable(Kind kind,Availability availability){return new Declaration(kind,List.of(),availability);}
}
