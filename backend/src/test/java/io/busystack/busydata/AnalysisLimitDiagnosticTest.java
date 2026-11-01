package io.busystack.busydata;

import io.busystack.busydata.analysis.*;
import io.busystack.busydata.analysis.language.*;
import io.busystack.busydata.protocol.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class AnalysisLimitDiagnosticTest {
    private static AnalysisRequest request(String sql){return AnalysisRequest.newBuilder().setEngine(Engine.POSTGRESQL).setDocumentId("limit-fixture").setOperation(AnalysisOperation.DIAGNOSTICS).setSql(sql).build();}
    private static Diagnostic onlyLimit(Analysis reply){assertEquals("limited",reply.getAvailability());assertEquals(1,reply.getDiagnosticsCount());var issue=reply.getDiagnostics(0);assertEquals("analysis.limit",issue.getCode());assertEquals("availability",issue.getSource());assertEquals("hint",issue.getSeverity());assertTrue(issue.getIncomplete());return issue;}
    @Test void exactControlledReasonKeepsTheStableStructuredDiagnostic(){
        var reply=new SqlAnalysis().analyze(request("SELECT 1"),LexicalSettings.DEFAULT,ResolutionContext.UNAVAILABLE,()->{throw new AnalysisBudget.Limit("SQL analysis deadline exceeded");});
        assertEquals("SQL analysis deadline exceeded",onlyLimit(reply).getMessage());assertTrue(reply.getFormattedSql().isEmpty());assertEquals(0,reply.getCompletionsCount());
    }
    @Test void dynamicMessagesAndRequestValuesNeverReachTheAvailabilityDiagnostic(){
        String sensitive="private_sql_and_value_fixture";String sql="SELECT '"+sensitive+"'";
        var reply=new SqlAnalysis().analyze(request(sql),LexicalSettings.DEFAULT,ResolutionContext.UNAVAILABLE,()->{throw new AnalysisBudget.Limit(sql);});
        assertEquals("SQL analysis resource limit reached; analyze a smaller statement or selection",onlyLimit(reply).getMessage());assertFalse(reply.toString().contains(sensitive));
    }
    @Test void realDocumentLimitReportsItsBoundWithoutEchoingSource(){
        String sensitive="private_sql_and_value_fixture";String sql="SELECT '"+sensitive+"x".repeat(AnalysisBudget.MAX_DOCUMENT_UNITS)+"'";
        var reply=new SqlAnalysis().analyze(request(sql));assertEquals("SQL document exceeds 256Ki UTF-16 units",onlyLimit(reply).getMessage());assertFalse(reply.toString().contains(sensitive));
    }
}
