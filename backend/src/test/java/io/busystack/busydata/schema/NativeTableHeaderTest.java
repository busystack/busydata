package io.busystack.busydata.schema;

import io.busystack.busydata.NativeCaseFixtures;
import io.busystack.busydata.analysis.LexicalSettings;
import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import java.io.StringReader;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class NativeTableHeaderTest {
    private static NativeTableHeader.Header header(String text,Engine engine,LexicalSettings lexical)throws Exception{return NativeTableHeader.parse(text,false,engine,lexical);}
    private static NativeTableHeader.Header header(String text,Engine engine)throws Exception{return header(text,engine,LexicalSettings.DEFAULT);}
    @Test void escapedNativeIdentifiersAndNamespacesAreLossless()throws Exception{
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB)){
            var parsed=header("CREATE TEMPORARY TABLE `db``name`.`Ta``ble\\name` (`id` int)",engine);assertEquals("db`name",parsed.catalog());assertEquals("Ta`ble\\name",parsed.name());assertEquals(MetadataState.AVAILABLE,parsed.nameAvailability());
        }
    }
    @Test void doubleQuotesUseTheCapturedActualAnsiMode()throws Exception{
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB)){
            String text="CREATE TEMPORARY TABLE \"a\"\"b\\c\" (id int)";var available=header(text,engine,LexicalSettings.mysql("ANSI_QUOTES,NO_BACKSLASH_ESCAPES"));assertEquals("a\"b\\c",available.name());assertEquals(MetadataState.AVAILABLE,available.nameAvailability());assertEquals(MetadataState.UNAVAILABLE,header(text,engine).nameAvailability());assertEquals(MetadataState.UNAVAILABLE,header("CREATE TEMPORARY TABLE 't' (id int)",engine).nameAvailability());
        }
    }
    @Test void safeUnquotedAndQuotedNumericNamesRemainExact()throws Exception{
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB)){
            assertEquals("123_native$",header("CREATE TEMPORARY TABLE 123_native$ (id int)",engine).name());assertEquals("Ångström",header("CREATE TEMPORARY TABLE Ångström (id int)",engine).name());assertEquals("123",header("CREATE TEMPORARY TABLE `123` (id int)",engine).name());assertEquals(MetadataState.UNAVAILABLE,header("CREATE TEMPORARY TABLE 123 (id int)",engine).nameAvailability());
        }
    }
    @Test void theBodyMayBeCutInsideStringsOrCommentsAfterACompleteHeader()throws Exception{
        for(var suffix:List.of("v text DEFAULT '","v text /*", "v text DEFAULT 'invalid\\")){
            String complete="CREATE TEMPORARY TABLE `native_name` ("+suffix+"x".repeat(5000);String prefix=complete.substring(0,NativeTableHeader.MAX_HEADER_UNITS);
            var parsed=NativeTableHeader.parse(prefix,true,Engine.MYSQL,LexicalSettings.DEFAULT);assertEquals("native_name",parsed.name());assertEquals(MetadataState.AVAILABLE,parsed.nameAvailability());
        }
    }
    @Test void aCutOrMalformedNameNeverBecomesAnAliasFallback()throws Exception{
        var cut=NativeTableHeader.parse("CREATE TEMPORARY TABLE `"+"x".repeat(2000),true,Engine.MYSQL,LexicalSettings.DEFAULT);assertEquals(MetadataSnapshot.PhysicalRelationKind.TEMPORARY,cut.kind());assertEquals(MetadataState.LIMITED,cut.nameAvailability());assertTrue(cut.name().isEmpty());
        var malformed=header("CREATE TEMPORARY TABLE `unterminated",Engine.MYSQL);assertEquals(MetadataSnapshot.PhysicalRelationKind.TEMPORARY,malformed.kind());assertEquals(MetadataState.UNAVAILABLE,malformed.nameAvailability());assertTrue(malformed.name().isEmpty());
        assertEquals(MetadataState.UNAVAILABLE,header("CREATE TEMPORARY TABLE t.not_a_name.extra (id int)",Engine.MYSQL).nameAvailability());
    }
    @Test void commentsAndOtherObjectsCannotManufactureANativeTableMarker()throws Exception{
        assertNull(header("/* CREATE TEMPORARY TABLE */ CREATE TABLE t(id int)",Engine.MYSQL).kind());assertEquals(ObjectKind.VIEW,header("CREATE ALGORITHM=UNDEFINED VIEW t AS SELECT 1",Engine.MYSQL).objectKind());var comment=header("CREATE TEMPORARY TABLE /* alias */ t(id int)",Engine.MYSQL);assertEquals(MetadataSnapshot.PhysicalRelationKind.TEMPORARY,comment.kind());assertEquals(MetadataState.UNAVAILABLE,comment.nameAvailability());
    }
    @Test void nativeMariaReplacementAndOptionalExistenceSyntaxRemainBounded()throws Exception{
        assertEquals("t",header("CREATE OR REPLACE TEMPORARY TABLE t(id int)",Engine.MARIADB).name());assertNull(header("CREATE OR REPLACE TEMPORARY TABLE t(id int)",Engine.MYSQL).kind());assertEquals("t",header("CREATE TEMPORARY TABLE IF NOT EXISTS t(id int)",Engine.MYSQL).name());
    }
    @Test void aMaximumEscapedProtocolNameFitsTheIndependentHeaderBound()throws Exception{
        String name="`".repeat(256),quoted="`"+name.replace("`","``")+"`";var parsed=header("CREATE TEMPORARY TABLE "+quoted+"."+quoted+" (id int)",Engine.MYSQL);assertEquals(name,parsed.catalog());assertEquals(name,parsed.name());assertEquals(MetadataState.AVAILABLE,parsed.nameAvailability());assertEquals(MetadataState.UNAVAILABLE,header("CREATE TEMPORARY TABLE `"+"x".repeat(257)+"` (id int)",Engine.MYSQL).nameAvailability());
    }
    @Test void invalidIdentifierScalarsRemainUnavailable()throws Exception{
        for(String name:List.of("x\0y","🙂","\ud800"))assertEquals(MetadataState.UNAVAILABLE,header("CREATE TEMPORARY TABLE `"+name+"` (id int)",Engine.MYSQL).nameAvailability());
    }
    @Test void canonicalNameUsesNativeHeaderAndVerifiedComparisonWithoutClientFolding()throws Exception{
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB)){
            var rules=NativeCaseFixtures.rules(engine,1);var parsed=header("CREATE TEMPORARY TABLE `mixed` (id int)",engine);var exact=NativeTableHeader.authority(parsed,rules,"db","MIXED");assertTrue(exact.available());assertEquals("mixed",exact.exact());assertEquals(NativeTableHeader.PROVENANCE,exact.provenance());
            var preserve=NativeTableHeader.authority(header("CREATE TEMPORARY TABLE `MiXeD` (id int)",engine),rules,"db","MIXED");assertEquals("MiXeD",preserve.exact(),"Only the native header supplies spelling; lookup does not rewrite it");
        }
    }
    @Test void wrongNativeTargetOrNamespaceIsStale()throws Exception{
        var rules=NativeCaseFixtures.rules(Engine.MYSQL,0);assertEquals(MetadataState.STALE,NativeTableHeader.authority(header("CREATE TEMPORARY TABLE `other`.`t` (id int)",Engine.MYSQL),rules,"db","t").availability());assertEquals(MetadataState.STALE,NativeTableHeader.authority(header("CREATE TEMPORARY TABLE `mixed` (id int)",Engine.MYSQL),rules,"db","MIXED").availability());
    }
    @Test void modeTwoNeverPromotesTheHeaderAliasToAStoredName()throws Exception{
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB)){var exact=NativeTableHeader.authority(header("CREATE TEMPORARY TABLE `MiXeD` (id int)",engine),NativeCaseFixtures.rules(engine,2),"db","MIXED");assertEquals(MetadataState.UNSUPPORTED,exact.availability());assertTrue(exact.exact().isEmpty());assertFalse(exact.available());}
    }
    @Test void missingNativeComparisonAndUnavailableHeaderCarryExplicitStates()throws Exception{
        var parsed=header("CREATE TEMPORARY TABLE t(id int)",Engine.MYSQL);assertEquals(MetadataState.UNAVAILABLE,NativeTableHeader.authority(parsed,new IdentifierRules(Engine.MYSQL,0),"db","t").availability());var unknown=NativeTableHeader.authority(header("CREATE TEMPORARY TABLE `",Engine.MYSQL),NativeCaseFixtures.rules(Engine.MYSQL,0),"db","t");assertEquals(MetadataState.UNAVAILABLE,unknown.availability());assertTrue(unknown.exact().isEmpty());
    }
    @Test void classificationCannotCertifyAnAliasWithoutCanonicalProvenance(){
        assertThrows(IllegalArgumentException.class,()->new OwnedTemporarySource.Classification(MetadataState.AVAILABLE,MetadataSnapshot.PhysicalRelationKind.TEMPORARY,"alias",MetadataState.AVAILABLE,"SHOW_COLUMN_1"));var unavailable=new OwnedTemporarySource.Classification(MetadataState.UNSUPPORTED,MetadataSnapshot.PhysicalRelationKind.TEMPORARY,"",MetadataState.UNSUPPORTED,"NATIVE_CREATE_HEADER_ALIAS_ONLY_MODE_2");assertFalse(unavailable.available());assertThrows(io.busystack.busydata.rpc.WorkbenchFailure.class,unavailable::requireNativeName);
    }
}
