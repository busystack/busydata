package io.busystack.busydata.metadata;

import io.busystack.busydata.NativeCaseFixtures;
import io.busystack.busydata.protocol.*;
import java.util.Arrays;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class IdentifierRulesTest {
    @Test void provisionalRulesNeverClaimNativeUnicodeEvidence(){
        for(var engine:new Engine[]{Engine.MYSQL,Engine.MARIADB}){
            var rules=new IdentifierRules(engine,1);
            assertFalse(rules.complete());assertEquals("ΟΣ",rules.lookup(ObjectKind.COLUMN,"ΟΣ",true));
            assertEquals("İ",rules.lookup(ObjectKind.COLUMN,"İ",true));assertEquals("ẞ",rules.lookup(ObjectKind.COLUMN,"ẞ",true));
            assertFalse(rules.matchesServer(engine,1,"8.4.10",false));assertTrue(rules.estimatedBytes()<1024);
        }
        var pg=new IdentifierRules(Engine.POSTGRESQL,0);assertTrue(pg.complete());
        assertEquals("i_ΟΣ_İ_ẞ",pg.lookup(ObjectKind.COLUMN,"I_ΟΣ_İ_ẞ",false));
        assertEquals("I_ΟΣ",pg.lookup(ObjectKind.COLUMN,"I_ΟΣ",true));
    }
    @Test void explicitDomainsSeparatePhysicalNamesAliasesAndDictionaryNames(){
        var mysql=NativeCaseFixtures.rules(Engine.MYSQL,1);
        var maria=NativeCaseFixtures.rules(Engine.MARIADB,1);
        assertEquals("mixed",mysql.lookup(ObjectKind.TABLE,"MiXeD",true));
        assertEquals("mixed",maria.lookup(ObjectKind.TABLE,"MiXeD",true));
        assertEquals("mixed",mysql.alias("MiXeD",true));assertEquals("MIXED",maria.alias("MiXeD",true));
        assertEquals("mixed",mysql.lookup(ObjectKind.COLUMN,"MiXeD",true));assertEquals("MIXED",maria.lookup(ObjectKind.COLUMN,"MiXeD",true));
        assertEquals("MiXeD",NativeCaseFixtures.rules(Engine.MYSQL,0).alias("MiXeD",true));
        assertEquals("MiXeD",NativeCaseFixtures.rules(Engine.MARIADB,0).lookup(ObjectKind.TABLE,"MiXeD",true));
        assertTrue(mysql.matches(ObjectKind.COLUMN,"MiXeD","mixed",false));
        assertTrue(maria.matches(ObjectKind.INDEX,"MiXeD","mixed",true));
        assertEquals(mysql.lookup(ObjectKind.FOREIGN_KEY,"MiXeD",true),mysql.lookup(ObjectKind.CONSTRAINT,"MiXeD",true,"FOREIGN KEY"));
        assertEquals(mysql.lookup(ObjectKind.INDEX,"MiXeD",true),mysql.lookup(ObjectKind.CONSTRAINT,"MiXeD",true,"CHECK"));
    }
    @Test void cacheRoundTripsAllSupportedEvidenceOwners(){
        for(var engine:new Engine[]{Engine.POSTGRESQL,Engine.MYSQL,Engine.MARIADB})for(int mode:new int[]{0,1}){
            if(engine==Engine.POSTGRESQL&&mode!=0)continue;
            var rules=NativeCaseFixtures.rules(engine,mode);byte[] bytes=rules.encode();
            assertTrue(bytes.length<=IdentifierRules.MAX_ENCODED_BYTES);
            var restored=IdentifierRules.decode(engine,mode,bytes);
            assertEquals(rules,restored);assertEquals(rules.fingerprint(),restored.fingerprint());
            assertEquals(rules.serverVersion(),restored.serverVersion());assertEquals(rules.estimatedBytes(),restored.estimatedBytes());
            assertEquals(rules.lookup(ObjectKind.COLUMN,"AbC",true),restored.lookup(ObjectKind.COLUMN,"AbC",true));
            Arrays.fill(bytes,(byte)0);assertTrue(restored.complete());
            assertEquals(rules,IdentifierRules.decode(engine,mode,restored.encode()));
        }
    }
    @Test void cacheRejectsMalformedCorruptOversizedAndCrossOwnerEvidence(){
        var rules=NativeCaseFixtures.rules(Engine.MYSQL,1);byte[] encoded=rules.encode();
        assertThrows(IllegalArgumentException.class,()->IdentifierRules.decode(Engine.MARIADB,1,encoded));
        assertThrows(IllegalArgumentException.class,()->IdentifierRules.decode(Engine.MYSQL,0,encoded));
        for(int length:new int[]{0,1,8,17,encoded.length-1})assertThrows(IllegalArgumentException.class,()->IdentifierRules.decode(Engine.MYSQL,1,Arrays.copyOf(encoded,length)));
        var extra=Arrays.copyOf(encoded,encoded.length+1);assertThrows(IllegalArgumentException.class,()->IdentifierRules.decode(Engine.MYSQL,1,extra));
        var corrupt=encoded.clone();corrupt[corrupt.length-1]^=1;assertThrows(IllegalArgumentException.class,()->IdentifierRules.decode(Engine.MYSQL,1,corrupt));
        assertThrows(IllegalArgumentException.class,()->IdentifierRules.decode(Engine.MYSQL,1,new byte[IdentifierRules.MAX_ENCODED_BYTES+1]));
    }
    @Test void nativeEvidenceRequiresCompleteScalarAndIdempotentMaps(){
        String valid=identity();
        assertThrows(IllegalArgumentException.class,()->IdentifierRules.nativeRules(Engine.MYSQL,0,"test",valid.substring(1),valid,valid,null,false));
        var nullOutput=valid.toCharArray();nullOutput['a']=0;
        assertThrows(IllegalArgumentException.class,()->IdentifierRules.nativeRules(Engine.MYSQL,0,"test",new String(nullOutput),new String(nullOutput),valid,null,false));
        var surrogate=valid.toCharArray();surrogate[0xd800]='a';
        assertThrows(IllegalArgumentException.class,()->IdentifierRules.nativeRules(Engine.MYSQL,0,"test",new String(surrogate),new String(surrogate),valid,null,false));
        var chain=valid.toCharArray();chain['a']='b';chain['b']='c';
        assertThrows(IllegalArgumentException.class,()->IdentifierRules.nativeRules(Engine.MYSQL,0,"test",new String(chain),new String(chain),valid,null,false));
        assertThrows(IllegalArgumentException.class,()->IdentifierRules.nativeRules(Engine.MYSQL,0,"",valid,valid,valid,null,false));
        assertThrows(IllegalArgumentException.class,()->IdentifierRules.nativeRules(Engine.POSTGRESQL,0,"test",valid,valid,valid,null,false));
    }
    @Test void evidenceVersionAndDomainChangesCannotReuseOldKeys(){
        var first=NativeCaseFixtures.rules(Engine.MARIADB,1,"fixture-v1");
        var changed=NativeCaseFixtures.rules(Engine.MARIADB,1,"fixture-v2");
        assertNotEquals(first.fingerprint(),changed.fingerprint());
        assertTrue(first.matchesServer(Engine.MARIADB,1,"fixture-v1",false));
        assertFalse(first.matchesServer(Engine.MARIADB,0,"fixture-v1",false));assertFalse(first.matchesServer(Engine.MYSQL,1,"fixture-v1",false));
        assertFalse(first.matchesServer(Engine.MARIADB,1,"fixture-v2",false));
        assertTrue(first.estimatedBytes()<ExecutionMetadata.MAX_BYTES);
        assertTrue(NativeCaseFixtures.rules(Engine.MYSQL,1).estimatedBytes()<first.estimatedBytes());
    }
    @Test void foreignKeyUniquenessAndPublicDropUseSeparateCapturedDomains(){
        var lower=identity().toCharArray();lower['Σ']='σ';
        var comparison=identity().toCharArray();comparison['σ']='Σ';comparison['ς']='Σ';
        var dictionary=identity().toCharArray();dictionary['Σ']='σ';dictionary['ς']='σ';
        var maria=IdentifierRules.nativeRules(Engine.MARIADB,1,"synthetic-domains",new String(lower),new String(comparison),new String(dictionary),byteMap(),false);
        assertEquals(maria.lookup(ObjectKind.FOREIGN_KEY,"Aa",true),maria.lookup(ObjectKind.FOREIGN_KEY,"aA ",true));
        assertNotEquals(maria.lookup(ObjectKind.FOREIGN_KEY,"Σ",true),maria.lookup(ObjectKind.FOREIGN_KEY,"σ",true));
        assertEquals(maria.constraintDropKey("FOREIGN KEY","Σ"),maria.constraintDropKey("FOREIGN KEY","ς"));
        assertEquals(maria.lookup(ObjectKind.FOREIGN_KEY,"Aa",true),maria.lookup(ObjectKind.CONSTRAINT,"Aa",true,"FOREIGN KEY"));
        assertEquals(maria.lookup(ObjectKind.CONSTRAINT,"Σ",true,"CHECK"),maria.constraintDropKey("CHECK","σ"));
        assertFalse(maria.lookup(ObjectKind.FOREIGN_KEY,"Aa",true).contains("\0"));
        for(String invalid:new String[]{"a\0b","\ud800","\udc00","\ud83d\ude00"})
            assertThrows(IllegalArgumentException.class,()->maria.lookup(ObjectKind.FOREIGN_KEY,invalid,true));
        // MariaDB's supported Linux .TRN lookup is exact in either lctn mode.
        assertNotEquals(maria.lookup(ObjectKind.TRIGGER,"Aa",true),maria.lookup(ObjectKind.TRIGGER,"aa",true));
    }
    @Test void byteEvidenceIsRequiredCanonicalBoundedAndPartOfTheCacheIdentity(){
        String valid=identity(),bytes=byteMap();
        assertThrows(IllegalArgumentException.class,()->IdentifierRules.nativeRules(Engine.MARIADB,0,"test",valid,valid,valid,null,false));
        assertThrows(IllegalArgumentException.class,()->IdentifierRules.nativeRules(Engine.MARIADB,0,"test",valid,valid,valid,bytes.substring(1),false));
        assertThrows(IllegalArgumentException.class,()->IdentifierRules.nativeRules(Engine.MYSQL,0,"test",valid,valid,valid,bytes,false));
        var invalid=bytes.toCharArray();invalid['x']=0;
        assertThrows(IllegalArgumentException.class,()->IdentifierRules.nativeRules(Engine.MARIADB,0,"test",valid,valid,valid,new String(invalid),false));
        var tooLarge=bytes.toCharArray();tooLarge['x']=257;
        assertThrows(IllegalArgumentException.class,()->IdentifierRules.nativeRules(Engine.MARIADB,0,"test",valid,valid,valid,new String(tooLarge),false));
        var chained=bytes.toCharArray();chained['x']='y'+1;chained['y']='z'+1;
        assertThrows(IllegalArgumentException.class,()->IdentifierRules.nativeRules(Engine.MARIADB,0,"test",valid,valid,valid,new String(chained),false));
        var first=IdentifierRules.nativeRules(Engine.MARIADB,0,"test",valid,valid,valid,bytes,false);
        var changed=bytes.toCharArray();changed['!']='#'+1;
        var second=IdentifierRules.nativeRules(Engine.MARIADB,0,"test",valid,valid,valid,new String(changed),false);
        assertNotEquals(first.fingerprint(),second.fingerprint());assertEquals(first.estimatedBytes(),second.estimatedBytes());
        byte[] encoded=first.encode();assertTrue(encoded.length<400000);
        var restored=IdentifierRules.decode(Engine.MARIADB,0,encoded);assertEquals(first,restored);
        assertEquals(first.lookup(ObjectKind.FOREIGN_KEY,"AaΣ",true),restored.lookup(ObjectKind.FOREIGN_KEY,"AaΣ",true));
        int byteMapOffset=16+1+2+"test".length()+1+3*65536*Character.BYTES;
        byte[] corrupt=encoded.clone();corrupt[byteMapOffset+'A']='B';
        assertThrows(IllegalArgumentException.class,()->IdentifierRules.decode(Engine.MARIADB,0,corrupt));
        byte[] oldFormat=encoded.clone();oldFormat[7]=1;
        assertThrows(IllegalArgumentException.class,()->IdentifierRules.decode(Engine.MARIADB,0,oldFormat));
    }
    @Test void serverFilesystemIdentityGatesOnlyTheUnsupportedTriggerDomain(){
        var exact=NativeCaseFixtures.rules(Engine.MARIADB,1,"same-version",false);
        var insensitive=NativeCaseFixtures.rules(Engine.MARIADB,1,"same-version",true);
        assertTrue(insensitive.complete());assertTrue(insensitive.lowerCaseFileSystem());
        assertTrue(exact.kindAvailable(ObjectKind.TRIGGER));assertFalse(insensitive.kindAvailable(ObjectKind.TRIGGER));
        for(var kind:new ObjectKind[]{ObjectKind.TABLE,ObjectKind.COLUMN,ObjectKind.INDEX,ObjectKind.ROUTINE,ObjectKind.FOREIGN_KEY})assertTrue(insensitive.kindAvailable(kind));
        assertEquals("Aa",insensitive.lookup(ObjectKind.TRIGGER,"Aa",true));
        assertNotEquals(exact.fingerprint(),insensitive.fingerprint());
        assertTrue(insensitive.matchesServer(new IdentifierRules.ServerIdentity(Engine.MARIADB,1,"same-version",true)));
        assertFalse(insensitive.matchesServer(new IdentifierRules.ServerIdentity(Engine.MARIADB,1,"same-version",false)));
        var restored=IdentifierRules.decode(Engine.MARIADB,1,insensitive.encode());
        assertEquals(insensitive,restored);assertTrue(restored.lowerCaseFileSystem());assertFalse(restored.kindAvailable(ObjectKind.TRIGGER));
        byte[] invalid=insensitive.encode();invalid[16]=2;
        assertThrows(IllegalArgumentException.class,()->IdentifierRules.decode(Engine.MARIADB,1,invalid));
        assertTrue(NativeCaseFixtures.rules(Engine.MYSQL,1,"same-version",true).kindAvailable(ObjectKind.TRIGGER));
    }
    private static String byteMap(){var map=new char[256];for(int value=0;value<256;value++)map[value]=(char)(value+1);for(char upper='A';upper<='Z';upper++)map[upper]=(char)(upper+33);return new String(map);}
    private static String identity(){var chars=new char[65536];for(int c=1;c<chars.length;c++)if(c<0xd800||c>0xdfff)chars[c]=(char)c;return new String(chars);}
}
