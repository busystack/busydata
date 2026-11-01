package io.busystack.busydata.metadata;

/** Explicit incomplete native resource evidence; never an empty complete branch. */
public final class MetadataLimit extends IllegalArgumentException {
    public MetadataLimit(){super("Native metadata exceeds its bounded introspection resources");}
    public MetadataState state(){return MetadataState.LIMITED;}
}
