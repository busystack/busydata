package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.security.*;
import java.util.*;

/** Immutable native identifier comparison evidence shared by every metadata reader.
 * Provisional rules permit names-only inspection, but cannot certify resolution. */
public final class IdentifierRules {
    public static final int MAX_ENCODED_BYTES=400_000;
    private static final int MAGIC=0x42444943,FORMAT=3,MAP_LENGTH=65536;
    private final Engine engine;
    private final int lowerCaseTableNames;
    private final boolean lowerCaseFileSystem;
    private final String serverVersion,lower,comparison,dictionary,foreignByteMap,fingerprint;

    public IdentifierRules(Engine engine,int lowerCaseTableNames){this(engine,lowerCaseTableNames,"",null,null,null,null,false);}
    private IdentifierRules(Engine engine,int mode,String version,String lower,String comparison,String dictionary,String foreignByteMap,boolean lowerCaseFileSystem){
        if(engine!=Engine.POSTGRESQL&&engine!=Engine.MYSQL&&engine!=Engine.MARIADB||mode<0||mode>2)throw new IllegalArgumentException("Invalid identifier rules");
        Objects.requireNonNull(version);
        if(version.length()>256||version.indexOf('\0')>=0)throw new IllegalArgumentException("Invalid native identifier evidence version");
        if(engine==Engine.POSTGRESQL){if(mode!=0||lower!=null||comparison!=null||dictionary!=null||foreignByteMap!=null||lowerCaseFileSystem||!version.isEmpty())throw new IllegalArgumentException("Invalid PostgreSQL identifier evidence");}
        else if(lower!=null){
            if(version.isEmpty()||comparison==null||dictionary==null)throw new IllegalArgumentException("Incomplete native identifier evidence");
            validate(lower);if(comparison!=lower)validate(comparison);validate(dictionary);
            if(engine==Engine.MYSQL&&!lower.equals(comparison))throw new IllegalArgumentException("Invalid MySQL comparison domain");
            if(engine==Engine.MARIADB)validateBytes(foreignByteMap);
            else if(foreignByteMap!=null)throw new IllegalArgumentException("Unexpected foreign-key byte evidence");
            if(lower.equals(comparison))comparison=lower;
        }else if(comparison!=null||dictionary!=null||foreignByteMap!=null||lowerCaseFileSystem||!version.isEmpty())throw new IllegalArgumentException("Incomplete native identifier evidence");
        this.engine=engine;lowerCaseTableNames=mode;this.lowerCaseFileSystem=lowerCaseFileSystem;serverVersion=version;this.lower=lower;this.comparison=comparison;this.dictionary=dictionary;this.foreignByteMap=foreignByteMap;
        fingerprint=digest();
    }
    public static IdentifierRules nativeRules(Engine engine,int mode,String serverVersion,String lower,String comparison,String dictionary,String foreignByteMap,boolean lowerCaseFileSystem){
        return new IdentifierRules(engine,mode,serverVersion,Objects.requireNonNull(lower),Objects.requireNonNull(comparison),Objects.requireNonNull(dictionary),foreignByteMap,lowerCaseFileSystem);
    }
    private static boolean scalar(int c){return c>0&&c<MAP_LENGTH&&(c<0xd800||c>0xdfff);}
    private static void validate(String map){
        if(map.length()!=MAP_LENGTH)throw new IllegalArgumentException("Native identifier map cardinality is invalid");
        for(int c=0;c<MAP_LENGTH;c++){
            int mapped=map.charAt(c);
            if(!scalar(c)){if(mapped!=0)throw new IllegalArgumentException("Native identifier map includes a non-scalar");}
            else if(!scalar(mapped)||map.charAt(mapped)!=mapped)throw new IllegalArgumentException("Native identifier map is not a scalar equivalence map");
        }
    }
    /** Each stored character is the canonical native byte representative + 1.
     * This keeps lookup keys NUL-free without copying a server collation table. */
    private static void validateBytes(String map){
        if(map==null||map.length()!=256)throw new IllegalArgumentException("Native byte map cardinality is invalid");
        for(int value=0;value<256;value++){
            int mapped=map.charAt(value);
            if(mapped<1||mapped>256||map.charAt(mapped-1)!=mapped)throw new IllegalArgumentException("Native byte map is not canonical");
        }
    }
    /** Immutable facts observed on this physical connection before adoption. */
    public record ServerIdentity(Engine engine,int lowerCaseTableNames,String version,boolean lowerCaseFileSystem){
        public ServerIdentity{
            Objects.requireNonNull(engine);Objects.requireNonNull(version);
            if(engine!=Engine.POSTGRESQL&&engine!=Engine.MYSQL&&engine!=Engine.MARIADB||lowerCaseTableNames<0||lowerCaseTableNames>2||version.length()>256||version.indexOf(0)>=0||engine==Engine.POSTGRESQL&&(lowerCaseTableNames!=0||!version.isEmpty()||lowerCaseFileSystem)||engine!=Engine.POSTGRESQL&&version.isEmpty())throw new IllegalArgumentException("Invalid physical identifier context");
        }
    }
    public boolean matchesServer(ServerIdentity identity){return identity!=null&&matchesServer(identity.engine(),identity.lowerCaseTableNames(),identity.version(),identity.lowerCaseFileSystem());}
    /** Native DROP resolution differs from foreign-key creation uniqueness. */
    public String constraintDropKey(String actualType,String exactName){
        Objects.requireNonNull(actualType);Objects.requireNonNull(exactName);
        if(!complete())throw new IllegalStateException("Native constraint lookup evidence is unavailable");
        return engine==Engine.POSTGRESQL?exactName:mapped(exactName,comparison,false);
    }
    public Engine engine(){return engine;}
    public int lowerCaseTableNames(){return lowerCaseTableNames;}
    public boolean lowerCaseFileSystem(){return lowerCaseFileSystem;}
    public String serverVersion(){return serverVersion;}
    public boolean complete(){return engine==Engine.POSTGRESQL||lower!=null;}
    /** MariaDB trigger paths on a case-insensitive server filesystem need
     * additional native path evidence; other comparison domains remain valid. */
    public boolean kindAvailable(ObjectKind kind){Objects.requireNonNull(kind);return complete()&&!(engine==Engine.MARIADB&&kind==ObjectKind.TRIGGER&&lowerCaseFileSystem);}
    public String fingerprint(){return fingerprint;}
    public boolean matchesServer(Engine engine,int mode,String version,boolean lowerCaseFileSystem){return complete()&&this.engine==engine&&lowerCaseTableNames==mode&&serverVersion.equals(version)&&this.lowerCaseFileSystem==lowerCaseFileSystem;}
    public long estimatedBytes(){return 384L+2L*serverVersion.length()+(lower==null?0:2L*lower.length()+2L*dictionary.length()+(comparison==lower?0:2L*comparison.length()))+(foreignByteMap==null?0:48L+2L*foreignByteMap.length());}

    public String lookup(ObjectKind kind,String identifier,boolean quoted){
        Objects.requireNonNull(kind);Objects.requireNonNull(identifier);
        if(engine==Engine.POSTGRESQL)return quoted?identifier:postgresUnquoted(identifier);
        return switch(kind){
            case COLUMN,INDEX,CONSTRAINT->mapped(identifier,comparison,false);
            case ROUTINE->mapped(identifier,dictionary,true);
            case FOREIGN_KEY->engine==Engine.MARIADB?foreignUniquenessKey(identifier):mapped(identifier,dictionary,true);
            // Exact candidates remain inspectable when kindAvailable refuses
            // certainty for the server's case-insensitive .TRN path domain.
            case TRIGGER->engine==Engine.MYSQL?mapped(identifier,dictionary,true):identifier;
            default->lowerCaseTableNames==0?identifier:mapped(identifier,lower,false);
        };
    }
    public String lookup(ObjectKind kind,String identifier,boolean quoted,String structuralType){return lookup(kind==ObjectKind.CONSTRAINT&&"FOREIGN KEY".equals(structuralType)?ObjectKind.FOREIGN_KEY:kind,identifier,quoted);}
    public boolean matches(ObjectKind kind,String exact,String identifier,boolean quoted,String structuralType){return lookup(kind,exact,true,structuralType).equals(lookup(kind,identifier,quoted,structuralType));}
    /** Table aliases follow a different native comparator from physical table names. */
    public String alias(String identifier,boolean quoted){
        if(engine==Engine.POSTGRESQL)return quoted?identifier:postgresUnquoted(identifier);
        return lowerCaseTableNames==0?identifier:mapped(identifier,comparison,false);
    }
    public boolean matches(ObjectKind kind,String exact,String identifier,boolean quoted){return lookup(kind,exact,true).equals(lookup(kind,identifier,quoted));}
    private String mapped(String value,String map,boolean padSpace){
        StringBuilder out=null;
        for(int n=0;n<value.length();n++){
            char original=value.charAt(n),mapped;
            if(map!=null){if(!scalar(original))throw new IllegalArgumentException("Identifier is outside the native BMP domain");mapped=map.charAt(original);}
            else mapped=original>='A'&&original<='Z'?(char)(original+('a'-'A')):original;
            if(out==null&&original!=mapped){out=new StringBuilder(value.length());out.append(value,0,n);}
            if(out!=null)out.append(mapped);
        }
        String key=out==null?value:out.toString();
        if(padSpace&&map!=null){char space=map.charAt(' ');int end=key.length();while(end>0&&key.charAt(end-1)==space)end--;if(end!=key.length())key=key.substring(0,end);}
        return key;
    }
    private String foreignUniquenessKey(String value){
        if(foreignByteMap==null)return mapped(value,null,false); // Provisional inspection only.
        for(int index=0;index<value.length();index++)if(!scalar(value.charAt(index)))throw new IllegalArgumentException("Identifier is outside the native BMP domain");
        byte[] bytes=value.getBytes(StandardCharsets.UTF_8);int end=bytes.length;char space=foreignByteMap.charAt(' ');
        while(end>0&&foreignByteMap.charAt(Byte.toUnsignedInt(bytes[end-1]))==space)end--;
        var out=new StringBuilder(end);
        for(int index=0;index<end;index++)out.append(foreignByteMap.charAt(Byte.toUnsignedInt(bytes[index])));
        return out.toString();
    }
    /** PostgreSQL 17's UTF-8 scanner folds ASCII only. */
    public static String postgresUnquoted(String identifier){
        StringBuilder out=null;
        for(int i=0;i<identifier.length();i++){
            char c=identifier.charAt(i);if(out==null&&c>='A'&&c<='Z'){out=new StringBuilder(identifier.length());out.append(identifier,0,i);}
            if(out!=null)out.append(c>='A'&&c<='Z'?(char)(c+('a'-'A')):c);
        }
        return out==null?identifier:out.toString();
    }
    public String quote(String identifier){
        if(identifier.indexOf('\0')>=0)throw new IllegalArgumentException("Identifier contains NUL");
        String mark=engine==Engine.POSTGRESQL?"\"":"`";
        return mark+identifier.replace(mark,mark+mark)+mark;
    }
    public byte[] encode(){
        try{
            var bytes=new ByteArrayOutputStream();var out=new DataOutputStream(bytes);
            out.writeInt(MAGIC);out.writeInt(FORMAT);out.writeInt(engine.getNumber());out.writeInt(lowerCaseTableNames);out.writeBoolean(lowerCaseFileSystem);out.writeUTF(serverVersion);out.writeBoolean(lower!=null);
            if(lower!=null){writeMap(out,lower);if(engine==Engine.MARIADB)writeMap(out,comparison);writeMap(out,dictionary);if(engine==Engine.MARIADB)for(int value=0;value<256;value++)out.writeByte(foreignByteMap.charAt(value)-1);}
            out.writeUTF(fingerprint);out.flush();
            if(bytes.size()>MAX_ENCODED_BYTES)throw new IllegalArgumentException("Native identifier evidence exceeds its byte budget");return bytes.toByteArray();
        }catch(IOException impossible){throw new UncheckedIOException(impossible);}
    }
    public static IdentifierRules decode(Engine engine,int mode,byte[] encoded){
        Objects.requireNonNull(encoded);if(encoded.length>MAX_ENCODED_BYTES)throw new IllegalArgumentException("Native identifier evidence exceeds its byte budget");
        try(var in=new DataInputStream(new ByteArrayInputStream(encoded))){
            if(in.readInt()!=MAGIC||in.readInt()!=FORMAT||in.readInt()!=engine.getNumber()||in.readInt()!=mode)throw new IllegalArgumentException("Native identifier evidence owner or format mismatch");
            int filesystem=in.readUnsignedByte();if(filesystem>1)throw new IllegalArgumentException("Invalid native identifier filesystem context");boolean lowerCaseFileSystem=filesystem==1;
            String version=in.readUTF();boolean nativeMap=in.readBoolean();IdentifierRules rules;
            if(nativeMap){String lower=readMap(in),comparison=engine==Engine.MARIADB?readMap(in):lower,dictionary=readMap(in),foreignBytes=null;if(engine==Engine.MARIADB){var chars=new char[256];for(int value=0;value<256;value++)chars[value]=(char)(in.readUnsignedByte()+1);foreignBytes=new String(chars);}rules=nativeRules(engine,mode,version,lower,comparison,dictionary,foreignBytes,lowerCaseFileSystem);}
            else {if(!version.isEmpty()||lowerCaseFileSystem)throw new IllegalArgumentException("Unexpected native identifier version or filesystem context");rules=new IdentifierRules(engine,mode);}
            if(!rules.fingerprint.equals(in.readUTF())||in.read()!=-1)throw new IllegalArgumentException("Native identifier evidence checksum or framing mismatch");return rules;
        }catch(IOException malformed){throw new IllegalArgumentException("Malformed native identifier evidence",malformed);}
    }
    private static void writeMap(DataOutputStream out,String map)throws IOException{for(int c=0;c<MAP_LENGTH;c++)out.writeChar(map.charAt(c));}
    private static String readMap(DataInputStream in)throws IOException{var chars=new char[MAP_LENGTH];for(int c=0;c<MAP_LENGTH;c++)chars[c]=in.readChar();return new String(chars);}
    private String digest(){
        try{
            var digest=MessageDigest.getInstance("SHA-256");digest.update(("native-identifier-v"+FORMAT+":"+engine.getNumber()+":"+lowerCaseTableNames+":"+lowerCaseFileSystem+":"+serverVersion+":"+(lower!=null)).getBytes(StandardCharsets.UTF_8));
            if(lower!=null){update(digest,lower);if(engine==Engine.MARIADB)update(digest,comparison);update(digest,dictionary);if(foreignByteMap!=null)update(digest,foreignByteMap);}
            return HexFormat.of().formatHex(digest.digest());
        }catch(NoSuchAlgorithmException impossible){throw new IllegalStateException(impossible);}
    }
    private static void update(MessageDigest digest,String map){var buffer=new byte[8192];for(int base=0;base<map.length();base+=buffer.length/2){int count=Math.min(buffer.length/2,map.length()-base);for(int n=0;n<count;n++){char c=map.charAt(base+n);buffer[2*n]=(byte)(c>>>8);buffer[2*n+1]=(byte)c;}digest.update(buffer,0,count*2);}}
    @Override public boolean equals(Object value){return value instanceof IdentifierRules rules&&fingerprint.equals(rules.fingerprint);}
    @Override public int hashCode(){return fingerprint.hashCode();}
    @Override public String toString(){return "IdentifierRules[engine="+engine+",lowerCaseTableNames="+lowerCaseTableNames+",complete="+complete()+",fingerprint="+fingerprint+"]";}
}
