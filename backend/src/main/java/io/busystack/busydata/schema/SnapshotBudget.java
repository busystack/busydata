package io.busystack.busydata.schema;

/** Working strings are charged before insertion/concatenation, independently of
 * the final 6MiB encoded-snapshot limit. A heap cap is not this admission policy. */
final class SnapshotBudget {
    private final long limit;
    private long bytes;
    SnapshotBudget(){this(33_554_432);}
    SnapshotBudget(long limit){this.limit=limit;}
    String retain(String value) {
        if(value!=null)reserve(Math.addExact(64L,Math.multiplyExact(value.length(),2L)));
        return value;
    }
    void reserve(long cost) {
        if(cost<0||cost>limit-bytes)throw new IllegalArgumentException("Schema snapshot working byte budget exceeded; choose a narrower schema");
        bytes+=cost;
    }
    long bytes(){return bytes;}
}
