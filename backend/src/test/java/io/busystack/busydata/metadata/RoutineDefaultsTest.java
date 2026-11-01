package io.busystack.busydata.metadata;

import io.busystack.busydata.analysis.LexicalSettings;
import io.busystack.busydata.protocol.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class RoutineDefaultsTest {
    private static SchemaObject routine(ObjectSubtype kind,String name){return SchemaObject.newBuilder().setKind(ObjectKind.ROUTINE).setSubtype(kind).setCatalog("db").setSchema("db").setName(name).setIdentifier((kind==ObjectSubtype.FUNCTION?"FUNCTION:":"PROCEDURE:")+name).build();}
    private static RoutineDefaults.Parameter parameter(int ordinal,String name,String mode){return new RoutineDefaults.Parameter(ordinal,name,mode);}
    private static NativeRoutineSource source(String ddl,String mode){return new NativeRoutineSource(ddl,mode,MetadataState.AVAILABLE);}
    @Test void mariaProcedureHeaderKeepsNestedCommasAndNullDistinctFromAbsence(){
        String ddl="CREATE DEFINER=`fixture`@`localhost` PROCEDURE `p`(IN `first` INT, `text` VARCHAR(30) DEFAULT CONCAT('a,b', ')'), `nothing` INT DEFAULT NULL) BEGIN SELECT 'body DEFAULT ignored'; END";
        var parsed=RoutineDefaults.maria(source(ddl,""),routine(ObjectSubtype.PROCEDURE,"p"),List.of(parameter(1,"first","IN"),parameter(2,"text","IN"),parameter(3,"nothing","IN")));
        assertTrue(parsed.available());assertFalse(parsed.values().get(0).declared());assertEquals("",parsed.values().get(0).expression());
        assertEquals("CONCAT('a,b', ')')",parsed.values().get(1).expression());assertTrue(parsed.values().get(2).declared());assertEquals("NULL",parsed.values().get(2).expression());
    }
    @Test void mariaFunctionUsesItsStoredQuotationAndEscapeMode(){
        String ddl="CREATE FUNCTION \"db\".\"f\"(\"arg\" VARCHAR(20) DEFAULT 'a\\b', \"n\" INT DEFAULT NULL) RETURNS INT RETURN 1";
        var parsed=RoutineDefaults.maria(source(ddl,"ANSI_QUOTES,NO_BACKSLASH_ESCAPES"),routine(ObjectSubtype.FUNCTION,"f"),List.of(parameter(1,"arg","IN"),parameter(2,"n","IN")));
        assertTrue(parsed.available());assertEquals("'a\\b'",parsed.values().get(0).expression());assertEquals("NULL",parsed.values().get(1).expression());
        assertFalse(RoutineDefaults.maria(source(ddl,""),routine(ObjectSubtype.FUNCTION,"f"),List.of(parameter(1,"arg","IN"),parameter(2,"n","IN"))).available());
    }
    @Test void nativeUnicodeIdentifierWhitespaceIsNotTrimmedFromDefaultExpressions(){
        String ascii=" \t\n\r\f"+(char)11;
        for(String expression:List.of("\u2002source","source\u2002","\u2002source\u2002","/* retained default comment */ \u2002source\u2002")){
            String ddl="CREATE PROCEDURE p(arg INT DEFAULT"+ascii+expression+ascii+") SELECT 1";
            var parsed=RoutineDefaults.maria(source(ddl,""),routine(ObjectSubtype.PROCEDURE,"p"),List.of(parameter(1,"arg","IN")));
            assertTrue(parsed.available());assertEquals(expression,parsed.values().getFirst().expression());
        }
    }
    @Test void supportedOracleHeaderModesAndAssignmentAreStillHeaderOnly(){
        var parsed=RoutineDefaults.maria(source("CREATE PROCEDURE p(arg IN INT := 5, txt IN VARCHAR(20) DEFAULT 'DEFAULT,') AS BEGIN NULL; END","ORACLE,ANSI_QUOTES"),routine(ObjectSubtype.PROCEDURE,"p"),List.of(parameter(1,"arg","IN"),parameter(2,"txt","IN")));
        assertTrue(parsed.available());assertEquals("5",parsed.values().get(0).expression());assertEquals("'DEFAULT,'",parsed.values().get(1).expression());
    }
    @Test void exactNativeOrdinalNameModeAndKindMustReconcile(){
        var source=source("CREATE PROCEDURE p(IN arg INT DEFAULT 1)","");var p=routine(ObjectSubtype.PROCEDURE,"p");
        assertEquals(MetadataState.STALE,RoutineDefaults.maria(source,p,List.of(parameter(2,"arg","IN"))).state());
        assertEquals(MetadataState.STALE,RoutineDefaults.maria(source,p,List.of(parameter(1,"other","IN"))).state());
        assertEquals(MetadataState.STALE,RoutineDefaults.maria(source,p,List.of(parameter(1,"arg","OUT"))).state());
        assertFalse(RoutineDefaults.maria(source,routine(ObjectSubtype.FUNCTION,"p"),List.of(parameter(1,"arg","IN"))).available());
        assertFalse(RoutineDefaults.maria(source,routine(ObjectSubtype.PROCEDURE,"other"),List.of(parameter(1,"arg","IN"))).available());
    }
    @Test void unavailableSourceDoesNotInventAbsentDefaultsOrCompleteArity(){
        for(var state:List.of(MetadataState.DENIED,MetadataState.UNAVAILABLE,MetadataState.LIMITED,MetadataState.STALE)){
            var parsed=RoutineDefaults.maria(new NativeRoutineSource("","",state),routine(ObjectSubtype.PROCEDURE,"p"),List.of(parameter(1,"arg","IN")));
            assertFalse(parsed.available());assertEquals(state,parsed.state());assertTrue(parsed.values().isEmpty());
        }
    }
    @Test void nativeInOnlyAndTrailingDefaultRulesAreNotGuessedAway(){
        for(String ddl:List.of("CREATE PROCEDURE p(OUT arg INT DEFAULT 1)","CREATE PROCEDURE p(arg INT DEFAULT 1, other INT)","CREATE PROCEDURE p(arg INT DEFAULT)","CREATE PROCEDURE p(arg INT DEFAULT (1,2)")){
            var params=ddl.contains("other")?List.of(parameter(1,"arg","IN"),parameter(2,"other","IN")):List.of(parameter(1,"arg",ddl.contains("OUT")?"OUT":"IN"));
            assertFalse(RoutineDefaults.maria(source(ddl,""),routine(ObjectSubtype.PROCEDURE,"p"),params).available(),ddl);
        }
    }
    @Test void bodySyntaxAndUnicodeIdentifierLettersNeverBecomeHeaderKeywords(){
        var parsed=RoutineDefaults.maria(source("CREATE FUNCTION f(İn INT DEFAULT 2) RETURNS INT body @ $$ 'unterminated",""),routine(ObjectSubtype.FUNCTION,"f"),List.of(parameter(1,"İn","IN")));
        assertTrue(parsed.available());assertEquals("2",parsed.values().getFirst().expression());
    }
    @Test void postgresExpressionsPreserveArraysCastsAndQuotedCommasByInputOrder(){
        var parameters=List.of(parameter(1,"required","IN"),parameter(2,"numbers","IN"),parameter(3,"text","IN"));
        var parsed=RoutineDefaults.postgres("ARRAY[1, 2]::integer[], NULL::text",3,2,parameters,LexicalSettings.DEFAULT);
        assertTrue(parsed.available());assertFalse(parsed.values().getFirst().declared());assertEquals("ARRAY[1, 2]::integer[]",parsed.values().get(1).expression());assertEquals("NULL::text",parsed.values().get(2).expression());
        var quote=RoutineDefaults.postgres("concat('a,b', $$x,y$$)",1,1,List.of(parameter(1,"arg","IN")),LexicalSettings.DEFAULT);
        assertTrue(quote.available());assertEquals("concat('a,b', $$x,y$$)",quote.values().getFirst().expression());
    }
    @Test void postgresOutputParametersDoNotShiftDefaultsOrHideMissingExpressions(){
        var parameters=List.of(parameter(1,"required","IN"),parameter(2,"output","OUT"),parameter(3,"optional","INOUT"));
        var parsed=RoutineDefaults.postgres("7",2,1,parameters,LexicalSettings.DEFAULT);
        assertTrue(parsed.available());assertFalse(parsed.values().get(1).declared());assertEquals("7",parsed.values().get(2).expression());
        assertFalse(RoutineDefaults.postgres(null,2,1,parameters,LexicalSettings.DEFAULT).available());
        assertFalse(RoutineDefaults.postgres("ARRAY[1,2]",2,2,parameters,LexicalSettings.DEFAULT).available());
        assertTrue(RoutineDefaults.postgres(null,0,0,List.of(),LexicalSettings.DEFAULT).available());
    }
    @Test void transientSourceIsBoundedAndItsStateAndStoredModeAffectTheFingerprint(){
        var a=source("CREATE PROCEDURE p() SELECT 1","");var b=source(a.definition(),"NO_BACKSLASH_ESCAPES");
        assertNotEquals(a.fingerprint(),b.fingerprint());assertNotEquals(new NativeRoutineSource("","",MetadataState.DENIED).fingerprint(),new NativeRoutineSource("","",MetadataState.UNAVAILABLE).fingerprint());
        assertThrows(IllegalArgumentException.class,()->source("x".repeat(65537),""));
        assertThrows(IllegalArgumentException.class,()->new NativeRoutineSource("source","",MetadataState.DENIED));
        assertEquals(65537,new NativeRoutineSource("","",MetadataState.LIMITED,65537).bytesRead());
    }
}
