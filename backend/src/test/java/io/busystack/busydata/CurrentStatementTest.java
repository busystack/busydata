package io.busystack.busydata;

import io.busystack.busydata.analysis.SqlAnalysis;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.safety.Safety;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class CurrentStatementTest {
    private final Safety safety = new Safety(new SqlAnalysis());
    private final Profile profile = Profile.newBuilder().setEngine(Engine.POSTGRESQL).build();

    private Approval review(String sql, int caret) {
        return safety.review(ExecuteRequest.newBuilder().setSql(sql).setCaretUtf16(caret)
            .setMode(ExecutionMode.CURRENT_STATEMENT).build(), profile, 1);
    }

    @Test void endOfTerminatorReviewsOnlyTheCurrentOriginalStatement() {
        String sql = "SELECT 'first😀' AS n; SELECT 'second漢' AS n;\r\n";
        assertEquals(java.util.List.of("SELECT 'second漢' AS n"), review(sql, sql.length()).getStatementsList());
        assertEquals(java.util.List.of("SELECT 'first😀' AS n"), review(sql, sql.indexOf(';') + 1).getStatementsList());
    }

    @Test void followingStatementWinsAtAnAdjacentBoundary() {
        String sql = "SELECT 1;SELECT 2;";
        assertEquals(java.util.List.of("SELECT 2"), review(sql, sql.indexOf(';') + 1).getStatementsList());
        assertEquals(java.util.List.of("SELECT 1"), review(sql, sql.indexOf(';')).getStatementsList());
    }

    @Test void readOnlyReviewIgnoresStatementsThatWillNotExecute() {
        String sql = "SELECT 'kept' AS n; DELETE FROM must_remain;";
        var request = ExecuteRequest.newBuilder().setSql(sql).setCaretUtf16(sql.indexOf(';') + 1)
            .setMode(ExecutionMode.CURRENT_STATEMENT).build();
        assertEquals(java.util.List.of("SELECT 'kept' AS n"),
            safety.review(request, profile.toBuilder().setReadOnly(true).build(), 1).getStatementsList());
    }

    @Test void emptyOrInvalidPositionsCannotAcquireAnApproval() {
        assertThrows(IllegalArgumentException.class, () -> review("", 0));
        assertThrows(IllegalArgumentException.class, () -> review("SELECT 1;", 100));
    }

    @Test void proceduralDelimitersAndPostgresDollarBodiesRetainTheirOriginalText() {
        String procedure = "CREATE PROCEDURE p() BEGIN SELECT '漢;😀'; SELECT 2; END";
        String mysql = "DELIMITER //\r\n" + procedure + "//\r\nDELIMITER ;\r\nSELECT 3;";
        for(var engine:java.util.List.of(Engine.MYSQL,Engine.MARIADB)) {
            var request=ExecuteRequest.newBuilder().setSql(mysql).setMode(ExecutionMode.CURRENT_STATEMENT)
                .setCaretUtf16(mysql.indexOf("//\r\nDELIMITER")+2).build();
            assertEquals(java.util.List.of(procedure),safety.review(request,profile.toBuilder().setEngine(engine).build(),1).getStatementsList());
        }
        String dollar="DO $body$ BEGIN RAISE NOTICE '漢;😀'; END $body$";
        assertEquals(java.util.List.of(dollar),review(dollar+";\r\n",dollar.length()+3).getStatementsList());
    }

    @Test void trailingCommentsOrDelimiterDirectivesAreNotWhitespaceApproval() {
        String sql="SELECT 1; -- only a comment\r\n";
        assertThrows(IllegalArgumentException.class,()->review(sql,sql.length()));
        var request=ExecuteRequest.newBuilder().setSql("SELECT 1;").setModeValue(99).build();
        assertThrows(IllegalArgumentException.class,()->safety.review(request,profile,1));
    }

    @Test void selectionAlreadyContainsOnlyTheOriginalSelectedText() {
        var request=ExecuteRequest.newBuilder().setSql("SELECT '漢😀';").setMode(ExecutionMode.SELECTION)
            .setCaretUtf16(1000).build();
        assertEquals(java.util.List.of("SELECT '漢😀'"),safety.review(request,profile,1).getStatementsList());
    }
}
