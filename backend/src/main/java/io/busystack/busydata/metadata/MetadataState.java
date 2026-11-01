package io.busystack.busydata.metadata;

/** Availability is independent of an empty collection and of introspection depth. */
public enum MetadataState {
    AVAILABLE, NOT_REQUESTED, UNAVAILABLE, DENIED, INVISIBLE, UNSUPPORTED,
    PARTIAL, LIMITED, STALE, CANCELLED, TIMED_OUT, FAILED, UNKNOWN
}
