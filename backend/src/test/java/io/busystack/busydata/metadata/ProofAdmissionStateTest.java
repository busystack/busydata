package io.busystack.busydata.metadata;

import io.busystack.busydata.NativeCaseFixtures;
import io.busystack.busydata.protocol.Engine;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

/** Source coordination and physical-header fixtures, without native queries. */
class ProofAdmissionStateTest {
    private static MetadataPlatform.Source source(IdentifierRules rules){return new MetadataPlatform.Source(MetadataSnapshot.empty("source","profile",rules));}
    private static MetadataPlatform.ProofFence fence(MetadataPlatform.Source source){return new MetadataPlatform.ProofFence("source",source.owner,source.proofEpoch);}
    private static IdentifierRules.ServerIdentity identity(Engine engine,int mode,String version,boolean filesystem){return new IdentifierRules.ServerIdentity(engine,mode,version,filesystem);}
    private static RetainedMetadataProof proof(){return new RetainedMetadataProof("source",1,1,"db","db","t","table","generation",Map.of(1,new RetainedMetadataProof.ColumnProof("column","","INT","shape")),MetadataState.AVAILABLE,"");}

    @Test void provisionalEvidenceIsUnavailableWithoutInventingAChangedAuthority(){
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB)){
            var source=source(new IdentifierRules(engine,1));var captured=fence(source);var before=source.snapshot.get();
            assertEquals(MetadataState.UNAVAILABLE,MetadataPlatform.proofAdmissionState(source,captured));
            assertEquals(MetadataState.UNAVAILABLE,MetadataPlatform.proofAdmissionState(source,captured,identity(engine,1,"version",false)));
            assertFalse(MetadataPlatform.proofFenceAvailable(source,captured));assertSame(before,source.snapshot.get());assertEquals(captured.epoch(),source.proofEpoch);
            var denied=MetadataPlatform.admitProof(source,captured,proof());assertEquals(MetadataState.UNAVAILABLE,denied.state());assertFalse(denied.capturedStructure());
        }
    }
    @Test void completeMapsNeedTheExactPhysicalModeVersionEngineAndFilesystem(){
        var source=source(NativeCaseFixtures.rules(Engine.MARIADB,1,"version"));var captured=fence(source);
        for(var physical:List.of(identity(Engine.MARIADB,0,"version",false),identity(Engine.MARIADB,1,"new-version",false),identity(Engine.MYSQL,1,"version",false),identity(Engine.MARIADB,1,"version",true))){
            assertEquals(MetadataState.UNAVAILABLE,MetadataPlatform.proofAdmissionState(source,captured,physical));
            for(var original:List.of(proof(),proof().invalidate("Ordinary rollback"))){var denied=MetadataPlatform.admitProof(source,captured,original,physical);assertEquals(MetadataState.UNAVAILABLE,denied.state());assertFalse(denied.capturedStructure());}
        }
        assertEquals(MetadataState.UNAVAILABLE,MetadataPlatform.proofAdmissionState(source,captured,null));
        assertEquals(MetadataState.AVAILABLE,MetadataPlatform.proofAdmissionState(source,captured,identity(Engine.MARIADB,1,"version",false)));assertTrue(MetadataPlatform.proofFenceAvailable(source,captured));
    }
    @Test void wrongSourceOwnerOrEpochIsStaleEvenWithoutNativeEvidence(){
        for(var rules:List.of(new IdentifierRules(Engine.MYSQL,1),NativeCaseFixtures.rules(Engine.MYSQL,1,"version"))){
            var source=source(rules);var physical=identity(Engine.MYSQL,1,"version",false);
            var invalid=Arrays.asList(null,new MetadataPlatform.ProofFence("other-source",source.owner,source.proofEpoch),new MetadataPlatform.ProofFence("source",source.owner+1,source.proofEpoch),new MetadataPlatform.ProofFence("source",source.owner,source.proofEpoch+1));
            for(var captured:invalid){assertEquals(MetadataState.STALE,MetadataPlatform.proofAdmissionState(source,captured));assertEquals(MetadataState.STALE,MetadataPlatform.proofAdmissionState(source,captured,physical));assertFalse(MetadataPlatform.proofFenceAvailable(source,captured));}
        }
    }
    @Test void activeAndUnknownExternalMutationsStayStaleWithACurrentFence(){
        var source=source(NativeCaseFixtures.rules(Engine.MYSQL,1,"version"));var physical=identity(Engine.MYSQL,1,"version",false);
        synchronized(source){
            var mutation=MetadataPlatform.beginExternalMutation(source,"source","owner");var during=fence(source);
            assertEquals(MetadataState.STALE,MetadataPlatform.proofAdmissionState(source,during,physical));assertFalse(MetadataPlatform.proofFenceAvailable(source,during));
            MetadataPlatform.finishExternalMutation(source,mutation,true,false,()->{throw new AssertionError("An unknown native outcome cannot acquire acknowledgement ownership");});
            var after=fence(source);assertEquals(0,source.externalActive);assertTrue(source.externalRequiresExplicit);
            assertEquals(MetadataState.STALE,MetadataPlatform.proofAdmissionState(source,after,physical));assertFalse(MetadataPlatform.proofFenceAvailable(source,after));
            for(var original:List.of(proof(),proof().invalidate("Ordinary rollback"))){var denied=MetadataPlatform.admitProof(source,after,original,physical);assertEquals(MetadataState.STALE,denied.state());assertFalse(denied.capturedStructure());}
        }
    }
    @Test void matchingNativeAndPostgresqlEvidenceKeepTheExistingPositiveAdmission(){
        for(var rules:List.of(NativeCaseFixtures.rules(Engine.MYSQL,1,"version"),NativeCaseFixtures.rules(Engine.MARIADB,1,"version"),new IdentifierRules(Engine.POSTGRESQL,0))){
            var source=source(rules);var captured=fence(source);var physical=identity(rules.engine(),rules.lowerCaseTableNames(),rules.serverVersion(),rules.lowerCaseFileSystem());var original=proof();
            assertEquals(MetadataState.AVAILABLE,MetadataPlatform.proofAdmissionState(source,captured,physical));assertTrue(MetadataPlatform.proofFenceAvailable(source,captured));assertSame(original,MetadataPlatform.admitProof(source,captured,original,physical));
        }
    }
}
