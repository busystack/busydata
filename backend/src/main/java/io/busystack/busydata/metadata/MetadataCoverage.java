package io.busystack.busydata.metadata;

public record MetadataCoverage(MetadataScope scope,IntrospectionLevel level,MetadataState state,boolean complete,
        String fingerprint,long sourceRevision,long contextRevision,long refreshedUnixMs,String limitation,String defaultNamespace) {
    public MetadataCoverage(MetadataScope scope,IntrospectionLevel level,MetadataState state,boolean complete,String fingerprint,long sourceRevision,long contextRevision,long refreshedUnixMs,String limitation){this(scope,level,state,complete,fingerprint,sourceRevision,contextRevision,refreshedUnixMs,limitation,"");}
    public MetadataCoverage {
        if(fingerprint.length()>512||limitation.length()>2048||defaultNamespace.length()>256||defaultNamespace.indexOf('\0')>=0)throw new IllegalArgumentException("Metadata coverage exceeds its budget");
        if(complete&&state!=MetadataState.AVAILABLE)throw new IllegalArgumentException("Only available metadata can be complete");
    }
    public MetadataCoverage stale(String reason){return new MetadataCoverage(scope,level,MetadataState.STALE,false,fingerprint,sourceRevision,contextRevision,refreshedUnixMs,reason,defaultNamespace);}
}
