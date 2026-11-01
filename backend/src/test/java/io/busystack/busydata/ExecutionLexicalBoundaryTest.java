package io.busystack.busydata;

import io.busystack.busydata.analysis.*;
import io.busystack.busydata.protocol.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

/** Execution selection remains independently checked against native lexical facts. */
class ExecutionLexicalBoundaryTest {
    @Test void unicodeDollarBodiesCannotExposeTheirInternalTerminators(){
        var analysis=new SqlAnalysis();String sql="DO $漢😀$ BEGIN RAISE NOTICE 'one;two'; END $漢😀$; SELECT 2;";
        var fragments=analysis.split(sql,Engine.POSTGRESQL);assertEquals(2,fragments.size());
        assertEquals("DO $漢😀$ BEGIN RAISE NOTICE 'one;two'; END $漢😀$",fragments.getFirst().text());
        var selected=analysis.execution(ExecuteRequest.newBuilder().setSql(sql).setMode(ExecutionMode.CURRENT_STATEMENT).setCaretUtf16(sql.indexOf("one;two")+4).build(),Engine.POSTGRESQL,LexicalSettings.DEFAULT);
        assertEquals(fragments.getFirst(),selected.getFirst());assertEquals(1,selected.size());
        assertEquals(1,SqlLexer.scan("$漢😀$one;two$漢😀$",Engine.POSTGRESQL).size());
    }
    @Test void identifierDollarsDoNotStartAQuotedBodyOrAnEscapePrefix(){
        var analysis=new SqlAnalysis();String sql="SELECT foo$tag$; DELETE FROM t;";
        assertEquals(2,analysis.split(sql,Engine.POSTGRESQL).size());assertEquals("SELECT foo$tag$",analysis.split(sql,Engine.POSTGRESQL).getFirst().text());
        var token=SqlLexer.scan("foo$tag$",Engine.POSTGRESQL).getFirst();assertEquals(SqlLexer.Kind.WORD,token.kind());assertEquals("foo$tag$",token.text());
        assertEquals(2,analysis.split("SELECT token$E'a\\'; DELETE FROM t;",Engine.POSTGRESQL,LexicalSettings.DEFAULT).size());
    }
    @Test void unicodeIdentifierSpacesAreNeverTrimmedOrTurnedIntoComments(){
        var analysis=new SqlAnalysis();String sql="SELECT a\u2002;\r\nSELECT 2;";
        for(var engine:new Engine[]{Engine.POSTGRESQL,Engine.MYSQL,Engine.MARIADB}){
            assertEquals("SELECT a\u2002",analysis.split(sql,engine).getFirst().text());
            var token=SqlLexer.scan("a\u2002b",engine).getFirst();assertEquals(SqlLexer.Kind.WORD,token.kind());assertEquals("a\u2002b",token.text());
        }
        for(var engine:new Engine[]{Engine.MYSQL,Engine.MARIADB}){
            assertEquals(2,analysis.split("SELECT 2--\u2002x FROM t;DELETE FROM t;",engine).size());
            assertTrue(SqlLexer.scan("--\u2002x",engine).stream().noneMatch(t->t.kind()==SqlLexer.Kind.COMMENT));
            assertEquals(SqlLexer.Kind.COMMENT,SqlLexer.scan("--\u001fx",engine).getFirst().kind());
        }
    }
}
