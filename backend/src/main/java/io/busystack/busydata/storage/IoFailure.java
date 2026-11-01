package io.busystack.busydata.storage;

import java.io.IOException;
import java.nio.file.*;
import java.util.Set;

/** Useful file failures without returning paths, credentials or source contents. */
public final class IoFailure {
    private IoFailure(){}
    private static final Set<String> CONTROLLED=Set.of("RESULT_DISK_QUOTA","IMPORT_SNAPSHOT_QUOTA","IMPORT_SNAPSHOT_DISK_RESERVE","ROW_TOO_WIDE","ROW_QUOTA");
    public static String code(IOException failure){
        if(failure instanceof io.busystack.busydata.transfers.OutputCommit.RecoveryRequired recovery)return recovery.published?"OUTPUT_PUBLISHED_RECOVERY_REQUIRED":"OUTPUT_RECOVERY_REQUIRED";
        if(failure instanceof AtomicMoveNotSupportedException)return "SAFE_OUTPUT_COMMIT_UNSUPPORTED";
        if(failure instanceof AccessDeniedException)return "FILE_ACCESS_DENIED";
        if(failure instanceof NoSuchFileException)return "FILE_NOT_FOUND";
        if(failure instanceof FileAlreadyExistsException)return "FILE_ALREADY_EXISTS";
        String message=failure instanceof FileSystemException file?file.getReason():failure.getMessage();
        if(CONTROLLED.contains(message==null?"":message))return message;
        if(message!=null&&message.contains("No space left on device"))return "DISK_FULL";
        return "FILE_OR_QUOTA_ERROR";
    }
}
