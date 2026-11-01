package io.busystack.busydata;

import java.nio.file.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

/** Provider-level reproduction of the old export finalization defect. */
class OutputMoveRegressionTest {
    @TempDir Path directory;
    @Test void destinationCreatedAfterReviewMustNotBeReplaced() throws Exception {
        Path target=directory.resolve("output.csv"), partial=directory.resolve("partial");
        Files.writeString(partial,"export");
        assertFalse(Files.exists(target)); // old preflight/review
        Files.writeString(target,"unrelated user file"); // deterministic race
        assertThrows(FileAlreadyExistsException.class,()->
            io.busystack.busydata.transfers.OutputCommit.open(target,false));
        assertEquals("unrelated user file",Files.readString(target));
    }
}
