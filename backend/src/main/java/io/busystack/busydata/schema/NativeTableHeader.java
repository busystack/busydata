package io.busystack.busydata.schema;

import io.busystack.busydata.analysis.LexicalSettings;
import io.busystack.busydata.analysis.language.*;
import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import java.io.Reader;
import java.sql.*;
import java.security.*;
import java.util.*;

/** A native SHOW row is drained; only a bounded header and complete digest are retained.
 * The SHOW display field is an alias and supplies no executable identity. */
final class NativeTableHeader {
    static final int MAX_HEADER_UNITS=2048;
    static final long MAX_CELL_BYTES=NativeDefinitionEvidence.MAX_BYTES;
    static final String PROVENANCE="OWNED_NATIVE_CREATE_HEADER";
    record Header(MetadataSnapshot.PhysicalRelationKind kind,String catalog,String name,MetadataState nameAvailability,ObjectKind objectKind){}
    record Name(String exact,MetadataState availability,String provenance){boolean available(){return availability==MetadataState.AVAILABLE&&!exact.isEmpty();}}
    private NativeTableHeader(){}
    record Observation(Header header,NativeDefinitionEvidence definition){}
    /** The hash covers every validated UTF-8 scalar only after EOF. A cut
     * header can still classify a kind; it never supplies a partial digest. */
    static Observation observe(Reader reader,Engine engine,LexicalSettings lexical,String sqlMode,String renderer,OwnedTemporarySource.Check check)throws Exception{
        if(reader==null)throw new SQLException("Native relation classification is unavailable");
        var prefix=new StringBuilder(MAX_HEADER_UNITS);var chunk=new char[4096];long bytes=0,units=0;char high=0;
        final MessageDigest hash;try{hash=MessageDigest.getInstance("SHA-256");}catch(NoSuchAlgorithmException unavailable){throw new AssertionError(unavailable);}
        for(int count;(count=reader.read(chunk))!=-1;){
            check.run();
            for(int index=0;index<count;index++){
                char value=chunk[index];units++;int scalar;
                if(prefix.length()<MAX_HEADER_UNITS)prefix.append(value);
                if(high!=0){if(!Character.isLowSurrogate(value))throw new SQLException("Invalid native source encoding","22021");scalar=Character.toCodePoint(high,value);high=0;}
                else if(Character.isHighSurrogate(value)){high=value;continue;}
                else if(Character.isLowSurrogate(value))throw new SQLException("Invalid native source encoding","22021");
                else scalar=value;
                int length=scalar<128?1:scalar<2048?2:scalar<65536?3:4;
                if(bytes>MAX_CELL_BYTES-length)throw new SQLException("Native relation classification exceeds its receive budget","54000");bytes+=length;
                if(length==1)hash.update((byte)scalar);
                else{if(length==4){hash.update((byte)(0xf0|(scalar>>>18)));hash.update((byte)(0x80|((scalar>>>12)&63)));}else if(length==3)hash.update((byte)(0xe0|(scalar>>>12)));else hash.update((byte)(0xc0|(scalar>>>6)));
                    if(length>=3)hash.update((byte)(0x80|((scalar>>>6)&63)));hash.update((byte)(0x80|(scalar&63)));}
            }
        }
        check.run();if(high!=0)throw new SQLException("Invalid native source encoding","22021");
        var header=parse(prefix.toString(),units>MAX_HEADER_UNITS,engine,lexical);check.run();
        var definition=header.nameAvailability()==MetadataState.AVAILABLE?NativeDefinitionEvidence.drained(engine,sqlMode,renderer,HexFormat.of().formatHex(hash.digest()),bytes):NativeDefinitionEvidence.unavailable();
        check.run();return new Observation(header,definition);
    }
    static Header parse(String prefix,boolean capped,Engine engine,LexicalSettings lexical)throws SQLException{
        if(engine!=Engine.MYSQL&&engine!=Engine.MARIADB)throw new IllegalArgumentException("Native MySQL/MariaDB header required");
        if(prefix.length()>MAX_HEADER_UNITS)throw new IllegalArgumentException("Native header prefix exceeds its budget");
        List<LosslessLexer.Token> tokens;
        try{tokens=LosslessLexer.scan(prefix,new Dialect(engine,lexical),new AnalysisBudget(250,()->io.grpc.Context.current().isCancelled())).tokens();}
        catch(AnalysisBudget.Limit limited){throw new SQLTimeoutException("Native table header analysis deadline exceeded");}
        // Comments are not native CREATE-prefix whitespace. Retain them in the
        // lossless token stream so a commented marker cannot become authority.
        var significant=new ArrayList<LosslessLexer.Token>();for(var token:tokens)if(token.kind()!=LosslessLexer.Kind.WHITESPACE)significant.add(token);
        int at=0;if(!word(significant,at++,"CREATE"))return missing(null,capped);
        if(word(significant,at,"OR")){if(engine!=Engine.MARIADB||!word(significant,at+1,"REPLACE"))return missing(null,capped);at+=2;}
        if(word(significant,at,"VIEW")||word(significant,at,"ALGORITHM")||word(significant,at,"DEFINER")||word(significant,at,"SQL"))return view(significant,at,capped);
        boolean temporary=word(significant,at,"TEMPORARY");if(temporary)at++;
        if(!word(significant,at++,"TABLE"))return missing(null,capped);
        var kind=temporary?MetadataSnapshot.PhysicalRelationKind.TEMPORARY:MetadataSnapshot.PhysicalRelationKind.PERSISTENT;
        if(word(significant,at,"IF")){if(!word(significant,at+1,"NOT")||!word(significant,at+2,"EXISTS"))return missing(kind,capped);at+=3;}
        if(at>=significant.size()||!identifier(significant.get(at)))return missing(kind,capped);
        String first=significant.get(at++).identifier(),catalog="",name=first;
        if(at<significant.size()&&significant.get(at).text().equals(".")){
            catalog=first;at++;if(at>=significant.size()||!identifier(significant.get(at)))return missing(kind,capped);name=significant.get(at++).identifier();
        }
        if(at>=significant.size()||!significant.get(at).text().equals("("))return missing(kind,capped);
        // Everything after '(' belongs to the body. It may be cut inside a
        // string/comment by the prefix budget without invalidating this name.
        return new Header(kind,catalog,name,MetadataState.AVAILABLE,ObjectKind.TABLE);
    }
    private static Header missing(MetadataSnapshot.PhysicalRelationKind kind,boolean capped){return new Header(kind,"","",capped?MetadataState.LIMITED:MetadataState.UNAVAILABLE,kind==null?null:ObjectKind.TABLE);}
    /** Parse only the bounded native SHOW VIEW identity prefix. The selected
     * central object remains the authority; no display alias or definer is an
     * executable identifier. Native view bodies are not parsed or executed. */
    private static Header view(List<LosslessLexer.Token> tokens,int at,boolean capped){
        if(word(tokens,at,"ALGORITHM")){
            at++;if(!punctuation(tokens,at++,"="))return missing(null,capped);
            if(!word(tokens,at,"UNDEFINED")&&!word(tokens,at,"MERGE")&&!word(tokens,at,"TEMPTABLE"))return missing(null,capped);at++;
        }
        if(word(tokens,at,"DEFINER")){
            at++;if(!punctuation(tokens,at++,"=")||!account(tokens,at++))return missing(null,capped);
            // MariaDB role definers can omit an empty host; both engines use
            // identifier quoting for account parts in their native renderer.
            if(punctuation(tokens,at,"@")){at++;if(!account(tokens,at++))return missing(null,capped);}
        }
        if(word(tokens,at,"SQL")){
            at++;if(!word(tokens,at++,"SECURITY")||!word(tokens,at,"DEFINER")&&!word(tokens,at,"INVOKER"))return missing(null,capped);at++;
        }
        if(!word(tokens,at++,"VIEW"))return missing(null,capped);
        var kind=MetadataSnapshot.PhysicalRelationKind.PERSISTENT;
        if(at>=tokens.size()||!identifier(tokens.get(at)))return missingView(capped);
        String first=tokens.get(at++).identifier(),catalog="",name=first;
        if(punctuation(tokens,at,".")){
            catalog=first;at++;if(at>=tokens.size()||!identifier(tokens.get(at)))return missingView(capped);name=tokens.get(at++).identifier();
        }
        if(punctuation(tokens,at,"(")){
            at++;if(at>=tokens.size()||!identifier(tokens.get(at++)))return missingView(capped);
            while(punctuation(tokens,at,",")){at++;if(at>=tokens.size()||!identifier(tokens.get(at++)))return missingView(capped);}
            if(!punctuation(tokens,at++,")"))return missingView(capped);
        }
        if(!word(tokens,at,"AS"))return missingView(capped);
        return new Header(kind,catalog,name,MetadataState.AVAILABLE,ObjectKind.VIEW);
    }
    private static Header missingView(boolean capped){return new Header(MetadataSnapshot.PhysicalRelationKind.PERSISTENT,"","",capped?MetadataState.LIMITED:MetadataState.UNAVAILABLE,ObjectKind.VIEW);}
    private static boolean punctuation(List<LosslessLexer.Token> values,int at,String value){return at<values.size()&&values.get(at).complete()&&values.get(at).text().equals(value);}
    private static boolean account(List<LosslessLexer.Token> values,int at){return at<values.size()&&values.get(at).complete()&&values.get(at).name();}
    private static boolean word(List<LosslessLexer.Token> values,int at,String text){return at<values.size()&&values.get(at).complete()&&values.get(at).kind()==LosslessLexer.Kind.WORD&&values.get(at).is(text);}
    private static boolean identifier(LosslessLexer.Token token){
        if(!token.name()||!token.complete())return false;String name=token.identifier();if(name.isEmpty()||name.length()>256||name.indexOf(0)>=0)return false;
        for(int at=0;at<name.length();at++)if(Character.isSurrogate(name.charAt(at)))return false;return true;
    }
    /** Only modes whose native renderer emits TABLE_SHARE's name certify it.
     * Mode2 renders the current alias in both pinned engines, so it cannot be
     * promoted to an exact temporary identity or repaired by client folding. */
    static Name authority(Header header,IdentifierRules rules,String catalog,String requested){
        if(header.kind()!=MetadataSnapshot.PhysicalRelationKind.TEMPORARY)return new Name("",MetadataState.NOT_REQUESTED,"");
        if(header.nameAvailability()!=MetadataState.AVAILABLE)return new Name("",header.nameAvailability(),PROVENANCE);
        if(!rules.complete())return new Name("",MetadataState.UNAVAILABLE,PROVENANCE);
        if(rules.lowerCaseTableNames()==2)return new Name("",MetadataState.UNSUPPORTED,"NATIVE_CREATE_HEADER_ALIAS_ONLY_MODE_2");
        try{
            if(!header.catalog().isEmpty()&&!rules.matches(ObjectKind.CATALOG,header.catalog(),catalog,true)||!rules.matches(ObjectKind.TABLE,header.name(),requested,true))return new Name("",MetadataState.STALE,PROVENANCE);
        }catch(IllegalArgumentException invalid){return new Name("",MetadataState.UNAVAILABLE,PROVENANCE);}
        return new Name(header.name(),MetadataState.AVAILABLE,PROVENANCE);
    }
}
