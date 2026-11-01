package io.busystack.busydata;

import io.busystack.busydata.storage.IoFailure;
import java.io.IOException;
import java.nio.file.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class IoFailureTest {
    @Test void diagnosesControlledResourceFailuresWithoutDisclosingSourceOrPaths(){
        assertEquals("RESULT_DISK_QUOTA",IoFailure.code(new IOException("RESULT_DISK_QUOTA")));
        assertEquals("DISK_FULL",IoFailure.code(new FileSystemException("private-password-file",null,"No space left on device")));
        assertEquals("FILE_ACCESS_DENIED",IoFailure.code(new AccessDeniedException("secret-source")));
        assertEquals("FILE_NOT_FOUND",IoFailure.code(new NoSuchFileException("secret-source")));
        assertEquals("FILE_OR_QUOTA_ERROR",IoFailure.code(new IOException("arbitrary server password and SQL")));
        assertEquals("FILE_OR_QUOTA_ERROR",IoFailure.code(new IOException()));
    }
}
