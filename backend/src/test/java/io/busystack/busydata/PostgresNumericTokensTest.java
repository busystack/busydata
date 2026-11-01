package io.busystack.busydata;

import io.busystack.busydata.analysis.*;
import io.busystack.busydata.analysis.language.*;
import io.busystack.busydata.protocol.Engine;
import java.util.*;
import java.util.concurrent.CancellationException;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class PostgresNumericTokensTest {
    private static LosslessLexer.Document scan(String sql){return LosslessLexer.scan(sql,new Dialect(Engine.POSTGRESQL,LexicalSettings.DEFAULT),new AnalysisBudget(1500,()->false));}
    private static SqlTypes.Type type(String number){var document=new SemanticDocument("SELECT "+number+" AS value",Engine.POSTGRESQL,LexicalSettings.DEFAULT,new AnalysisBudget(1500,()->false));var context=SemanticFixtures.context(Engine.POSTGRESQL,List.of(),new ResolutionContext("db","public",List.of("public"),true,1,1));return document.bind(context).project(document.syntax().queries().getFirst()).getFirst().type();}
    @Test void pinnedPostgresRadixFormsAndDigitSeparatorsAreLosslessNumbers(){
        for(String value:List.of("0xFF","0X_7FFF_FFFF","0o_1_755","0O755","0b_1001_0000","0B11","1_500_000_000","1.618_034","9.1e-1_0")){
            var tokens=scan(value);assertEquals(1,tokens.significant().size(),value);assertEquals(LosslessLexer.Kind.NUMBER,tokens.significant().getFirst().kind(),value);assertEquals(value,tokens.significant().getFirst().text());assertEquals(value.length(),tokens.significant().getFirst().end());
        }
        assertEquals("integer",type("0xDEAD").nativeName());assertEquals("bigint",type("0xdead_beef").nativeName());assertEquals("integer",type("0x7FFF_FFFF").nativeName());assertEquals("bigint",type("0x8000_0000").nativeName());assertEquals("numeric",type("0x8000_0000_0000_0000").nativeName());
        assertEquals("integer",type("-0xFE").nativeName());assertEquals("bigint",type("-0xdead_beef").nativeName());assertEquals("integer",type("-0x8000_0000").nativeName());assertEquals("bigint",type("-0x8000_0000_0000_0000").nativeName());
        assertEquals("integer",type("0b101").nativeName());assertEquals("integer",type("0".repeat(80)+"1").nativeName());
        assertEquals("numeric",type("1e2").nativeName());
    }
    @Test void malformedNumbersAreOneBoundedErrorRegionInsteadOfIdentifiers(){
        for(String number:List.of("0x","0x_","0x__F","0xFG","0o8","0b102","1__2","1_","1e+","1e_2","1.2foo","1😀")){
            var tokens=scan(number);assertEquals(1,tokens.significant().size(),number);assertEquals(LosslessLexer.Kind.ERROR,tokens.significant().getFirst().kind(),number);assertEquals(number,tokens.significant().getFirst().text());
            var syntax=new SemanticDocument("SELECT "+number,Engine.POSTGRESQL).syntax();assertEquals(1,syntax.issues().size(),number);assertTrue(syntax.issues().getFirst().incomplete(),number);
        }
    }
    @Test void radixScanningPreservesUnicodeTriviaCrLfAndNumericBoundaries(){
        String sql="/*😀*/\r\nSELECT 0x_FF, 0b10_01, 0o755, 1..10;\r\n";var document=scan(sql);assertEquals(sql,String.join("",document.tokens().stream().map(LosslessLexer.Token::text).toList()));
        var numbers=document.significant().stream().filter(t->t.kind()==LosslessLexer.Kind.NUMBER).map(LosslessLexer.Token::text).toList();assertEquals(List.of("0x_FF","0b10_01","0o755","1","10"),numbers);assertTrue(document.significant().stream().anyMatch(t->t.text().equals("..")));
        assertEquals(sql.indexOf("0x"),document.significant().stream().filter(t->t.text().equals("0x_FF")).findFirst().orElseThrow().start());
    }
    @Test void hugeIntegerClassificationDoesNotParseAnUnboundedBigInteger(){
        assertEquals("numeric",type("0x"+"F".repeat(100_000)).nativeName());
        assertThrows(CancellationException.class,()->LosslessLexer.scan("0x"+"F".repeat(100_000),new Dialect(Engine.POSTGRESQL,LexicalSettings.DEFAULT),new AnalysisBudget(1500,()->true)));
    }
}
