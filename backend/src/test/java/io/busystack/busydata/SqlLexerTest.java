package io.busystack.busydata;
import io.busystack.busydata.analysis.*;
import io.busystack.busydata.analysis.language.SemanticDocument;
import io.busystack.busydata.protocol.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
class SqlLexerTest {
 @Test void liveModesControlScriptBoundariesIdentifiersAndLosslessFormatting(){
  var analysis=new SqlAnalysis();var mysql=LexicalSettings.mysql("ANSI_QUOTES,NO_BACKSLASH_ESCAPES");
  String sql="SELECT 'a\\' AS x; SELECT \"Odd\\漢\" FROM t;";
  assertEquals(2,analysis.split(sql,Engine.MYSQL,mysql).size());
  assertTrue(SqlLexer.scan(sql,Engine.MYSQL,mysql).stream().anyMatch(t->t.kind()==SqlLexer.Kind.IDENTIFIER&&t.text().equals("\"Odd\\漢\"")));
  assertEquals(SqlLexer.scan(sql,Engine.MYSQL,mysql).stream().map(SqlLexer.Token::text).toList(),SqlLexer.scan(SqlLexer.format(sql,Engine.MYSQL,mysql),Engine.MYSQL,mysql).stream().map(SqlLexer.Token::text).toList());
  var pg=new LexicalSettings(false,false,false);assertEquals(2,analysis.split("SELECT 'a\\'b;c'; SELECT 2",Engine.POSTGRESQL,pg).size());
  assertThrows(IllegalArgumentException.class,()->SqlParsing.expression("(".repeat(65)+"1"+")".repeat(65),Engine.POSTGRESQL));
  assertThrows(Exception.class,()->SqlParsing.expression("1); DROP TABLE t; SELECT (2",Engine.POSTGRESQL));
 }
    @Test void deepOrOversizedAnalysisNeverClassifiesSqlAsHarmlessOrRoundTripsIt(){
        var analysis=new SqlAnalysis();String deep="SELECT "+"(".repeat(10000)+"1"+")".repeat(10000);
        assertFalse(analysis.readOnly(deep));var result=analysis.analyze(AnalysisRequest.newBuilder().setOperation(AnalysisOperation.DIAGNOSTICS).setEngine(Engine.POSTGRESQL).setSql(deep).build());
        assertFalse(result.getDiagnosticsList().isEmpty());assertEquals("",result.getFormattedSql());
        String huge="SELECT '"+"x".repeat(262144)+"'";assertFalse(analysis.readOnly(huge));result=analysis.analyze(AnalysisRequest.newBuilder().setOperation(AnalysisOperation.DIAGNOSTICS).setEngine(Engine.POSTGRESQL).setSql(huge).build());assertFalse(result.getStatements(0).getSupported());assertEquals("",result.getFormattedSql());assertTrue(result.getSerializedSize()<8192);
    }
    @Test void proceduralAlphabeticDelimitersRemainAuthoritative(){
        var analysis=new SqlAnalysis();
        for(var engine:java.util.List.of(Engine.MYSQL,Engine.MARIADB)){
            var fragments=analysis.split("DELIMITER _bd_end_\nCREATE PROCEDURE p() BEGIN SELECT 1; END_bd_end_\nDELIMITER ;\nSELECT 2;",engine);
            assertEquals(2,fragments.size());assertEquals("CREATE PROCEDURE p() BEGIN SELECT 1; END",fragments.getFirst().text());assertEquals("SELECT 2",fragments.getLast().text());
        }
    }
 @Test void formattingPreservesEveryTokenAndLineEnding(){
  String sql="-- 🌍 a comment\r\nSELECT  E'a\\\'b', x ? 'key' /* keep */ FROM \"Odd Table\" WHERE n = 12.34;\r\n";
  String formatted=SqlLexer.format(sql,Engine.POSTGRESQL);
  assertFalse(formatted.isEmpty());assertTrue(formatted.contains("-- 🌍 a comment\r\n"));assertTrue(formatted.endsWith("\r\n"));
  assertEquals(SqlLexer.scan(sql,Engine.POSTGRESQL).stream().map(SqlLexer.Token::text).toList(),SqlLexer.scan(formatted,Engine.POSTGRESQL).stream().map(SqlLexer.Token::text).toList());
  String mapped="-- 😀 comment\r\nSELECT  'a b\n漢' FROM t;";
  var result=new SqlAnalysis().analyze(AnalysisRequest.newBuilder().setOperation(AnalysisOperation.FORMAT).setEngine(Engine.POSTGRESQL).setSql(mapped).build());assertTrue(result.getFormattedSql().contains("-- 😀 comment\r\n"));
  assertFalse(result.getFormatTokensList().isEmpty());
  for(var token:result.getFormatTokensList())assertEquals(mapped.substring(token.getSourceStartUtf16(),token.getSourceEndUtf16()),result.getFormattedSql().substring(token.getFormattedStartUtf16(),token.getFormattedStartUtf16()+token.getSourceEndUtf16()-token.getSourceStartUtf16()));
 }
 @Test void incompleteTokensDoNotBecomeNewRelationsOrFormat(){
  assertEquals("",SqlLexer.format("SELECT 'unfinished",Engine.POSTGRESQL));
  assertEquals(1,new SemanticDocument("SELECT E'escaped\\\' FROM false f' FROM actual a",Engine.POSTGRESQL).references().size());
  assertEquals(2,SqlLexer.scan("--not_comment",Engine.MYSQL).stream().filter(t->t.kind()==SqlLexer.Kind.SYMBOL).count());
  assertTrue(SqlLexer.scan("SELECT \"literal\"",Engine.MYSQL).stream().anyMatch(t->t.kind()==SqlLexer.Kind.STRING));
 }
 @Test void modeAndDollarQuoteBoundariesAreExact(){
  assertTrue(SqlLexer.scan("SELECT 'a\\' ; SELECT 2",Engine.MYSQL,true,false).stream().filter(t->t.kind()==SqlLexer.Kind.STRING).allMatch(SqlLexer.Token::complete));
  assertTrue(SqlLexer.scan("SELECT \"identifier\"",Engine.MYSQL,false,true).stream().anyMatch(t->t.kind()==SqlLexer.Kind.IDENTIFIER));
  assertEquals("$$body;$$",SqlLexer.scan("SELECT $$body;$$",Engine.POSTGRESQL).get(1).text());
 }
}
