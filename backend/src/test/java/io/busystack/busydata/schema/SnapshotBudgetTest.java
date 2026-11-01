package io.busystack.busydata.schema;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
class SnapshotBudgetTest {
    @Test void cumulativeValuesAreRejectedBeforeRetentionAndFailedAdmissionDoesNotConsumeQuota(){
        var budget=new SnapshotBudget(256);
        assertEquals("漢😀",budget.retain("漢😀"));
        assertEquals(70,budget.bytes());
        assertThrows(IllegalArgumentException.class,()->budget.retain("x".repeat(100)));
        assertEquals(70,budget.bytes());
        budget.retain("ok");assertEquals(138,budget.bytes());
        assertThrows(IllegalArgumentException.class,()->budget.reserve(-1));
        assertEquals(138,budget.bytes());
    }
}
