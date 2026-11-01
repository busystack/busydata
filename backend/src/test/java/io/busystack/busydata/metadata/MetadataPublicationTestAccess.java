package io.busystack.busydata.metadata;

import java.nio.file.Path;
import java.util.*;

/** Test-only bridge to the instance-local, outside-Source candidate checkpoint. */
public final class MetadataPublicationTestAccess {
    private MetadataPublicationTestAccess(){}
    public static MetadataPlatform instrumented(Path privateRoot,Runnable beforeCommit)throws Exception{
        return new MetadataPlatform(privateRoot,beforeCommit);
    }
    public static boolean freshRoutinePoint(MetadataScope scope,MetadataCoverage coverage,MetadataPlatform.Branch branch,Map<String,MetadataObject> entries,Set<MetadataObject> admitted,IdentifierRules rules){
        return MetadataPlatform.freshRoutinePoint(scope,coverage,branch,entries,admitted,rules);
    }
}
