package io.busystack.busydata.rpc;

import io.grpc.Metadata;
import io.grpc.Status;
import io.grpc.StatusRuntimeException;
import java.util.*;

/** Allowlisted workbench failures. No SQL, values or arbitrary exception text crosses this boundary. */
public final class WorkbenchFailure extends RuntimeException {
    /** Internal closed evidence only; never transported as SQL, prose or a cause. */
    public enum Origin { UNCLASSIFIED,SOURCE_PARSE,CAPTURE_REBASE,INSPECTION,NATIVE_CLASSIFICATION,RETAINED_PROOF,OWNED_PUBLICATION,NATIVE_WITNESS,LOCKED_STRUCTURE }

    public enum Reason {
        UNSUPPORTED("unsupported",Status.UNIMPLEMENTED),
        UNAVAILABLE("unavailable",Status.UNAVAILABLE),
        DENIED("denied",Status.PERMISSION_DENIED),
        STALE("stale",Status.FAILED_PRECONDITION),
        CANCELLED("cancelled",Status.CANCELLED),
        TIMED_OUT("timed_out",Status.DEADLINE_EXCEEDED),
        INCOMPLETE_METADATA("incomplete_metadata",Status.FAILED_PRECONDITION),
        INVALID_OWNER("invalid_owner",Status.PERMISSION_DENIED),
        INVALID_REVISION("invalid_revision",Status.FAILED_PRECONDITION),
        MALFORMED_REQUEST("malformed_request",Status.INVALID_ARGUMENT),
        RESULT_DISPOSED("result_disposed",Status.NOT_FOUND),
        VALUE_TRUNCATED("value_truncated",Status.FAILED_PRECONDITION),
        ROW_NO_LONGER_CURRENT("row_no_longer_current",Status.ABORTED),
        TRANSACTION_UNKNOWN("transaction_unknown",Status.FAILED_PRECONDITION),
        BACKEND_RESTARTED("backend_restarted",Status.FAILED_PRECONDITION),
        READ_ONLY_POLICY("read_only_policy",Status.FAILED_PRECONDITION),
        SESSION_BUSY("session_busy",Status.FAILED_PRECONDITION),
        EDIT_IDENTITY_REQUIRED("edit_identity_required",Status.FAILED_PRECONDITION),
        EDIT_COLUMNS_READ_ONLY("edit_columns_read_only",Status.FAILED_PRECONDITION),
        EDIT_RESULT_NOT_READY("edit_result_not_ready",Status.FAILED_PRECONDITION),
        EDIT_PROJECTION_UNSUPPORTED("edit_projection_unsupported",Status.FAILED_PRECONDITION);
        private final String wire;private final Status status;
        Reason(String wire,Status status){this.wire=wire;this.status=status;}
        public String wire(){return wire;}public Status status(){return status;}
        public static Optional<Reason> parse(String wire){return Arrays.stream(values()).filter(reason->reason.wire.equals(wire)).findFirst();}
    }
    public static final String TRAILER="busydata-workbench-reason";
    private static final Metadata.Key<String> KEY=Metadata.Key.of(TRAILER,Metadata.ASCII_STRING_MARSHALLER);
    private final Reason reason;
    private final Origin origin;
    public WorkbenchFailure(Reason reason){this(reason,Origin.UNCLASSIFIED);}
    public WorkbenchFailure(Reason reason,Origin origin){super("Workbench request failed: "+Objects.requireNonNull(reason).wire());this.reason=reason;this.origin=Objects.requireNonNull(origin);}
    public Reason reason(){return reason;}
    public Origin origin(){return origin;}
    public StatusRuntimeException asStatusRuntimeException(){var metadata=new Metadata();metadata.put(KEY,reason.wire());return reason.status().withDescription(getMessage()).asRuntimeException(metadata);}
}
