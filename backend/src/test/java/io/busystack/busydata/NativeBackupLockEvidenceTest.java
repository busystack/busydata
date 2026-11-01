package io.busystack.busydata;

import com.google.gson.Gson;
import java.util.Map;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class NativeBackupLockEvidenceTest {
    @Test void retainedHistoryContainsOnlyNumericOwnershipAndVictimFacts(){
        String status="LATEST DETECTED DEADLOCK\n*** (1) TRANSACTION:\nTRANSACTION 12345, ACTIVE 1 sec\nMariaDB thread id 73, OS thread handle secret-user\nSQL secret credential table_private\n*** (2) TRANSACTION:\nTRANSACTION 12346, ACTIVE 2 sec\nMariaDB thread id 74, query id 1 private-user\nSQL generated_operation_private\n*** WE ROLL BACK TRANSACTION (1)\nTRANSACTIONS\nprivate-record-values";
        var evidence=NativeBackupLockEvidence.parseLatestDeadlock(status);assertEquals("AVAILABLE",evidence.get("availability"));assertEquals("1",evidence.get("victimSlot"));
        String json=new Gson().toJson(evidence);assertTrue(json.contains("12345")&&json.contains("12346")&&json.contains("73")&&json.contains("74"));
        for(String secret:new String[]{"credential","table_private","generated_operation","private-user","private-record","SQL"})assertFalse(json.contains(secret));
    }
    @Test void missingOrOversizeHistoryDoesNotPretendToProveADeadlockCycle(){
        assertEquals(Map.of("availability","HISTORY_NOT_PRESENT"),NativeBackupLockEvidence.parseLatestDeadlock("TRANSACTIONS\nprivate current query"));
        assertEquals(Map.of("availability","CHAR_LIMIT"),NativeBackupLockEvidence.parseLatestDeadlock("x".repeat(65537)));
        assertEquals("UNRECOGNIZED_HISTORY",NativeBackupLockEvidence.parseLatestDeadlock("LATEST DETECTED DEADLOCK\nprivate unsupported format").get("availability"));
    }
    @Test void numericHistoryAdmissionRejectsExcessTransactionsWithoutPartialGraph(){
        var status=new StringBuilder("LATEST DETECTED DEADLOCK\n");
        for(int i=1;i<=65;i++)status.append("*** (").append(i).append(") TRANSACTION:\nTRANSACTION ").append(i).append(", ACTIVE\n");
        assertEquals(Map.of("availability","ROW_LIMIT"),NativeBackupLockEvidence.parseLatestDeadlock(status.toString()));
    }
}
