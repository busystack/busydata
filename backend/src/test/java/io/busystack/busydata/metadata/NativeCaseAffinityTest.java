package io.busystack.busydata.metadata;

import io.busystack.busydata.NativeCaseFixtures;
import io.busystack.busydata.protocol.Engine;
import io.busystack.busydata.rpc.WorkbenchFailure;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

/** Explicit physical-header facts, not a substitute for a live connection. */
class NativeCaseAffinityTest {
    @Test void sameServerVersionWithDifferentNativeModeCannotFreshenCachedEvidence(){
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB)){
            var rules=NativeCaseFixtures.rules(engine,1,"same-version");
            var physical=new IdentifierRules.ServerIdentity(engine,0,"same-version",false);
            assertFalse(MetadataPlatform.identifierAffinity(rules,physical));
            assertFalse(MetadataPlatform.identifierAffinity(rules,new IdentifierRules.ServerIdentity(engine,1,"same-version",true)));
            var failure=assertThrows(WorkbenchFailure.class,()->MetadataPlatform.checkIdentifierAffinity(rules,physical));assertEquals(WorkbenchFailure.Reason.UNAVAILABLE,failure.reason());
            assertDoesNotThrow(()->MetadataPlatform.checkIdentifierAffinity(rules,new IdentifierRules.ServerIdentity(engine,1,"same-version",false)));
        }
    }
    @Test void mismatchedVersionEngineOrUnacquiredMapsNeverPassPhysicalAffinity(){
        var rules=NativeCaseFixtures.rules(Engine.MYSQL,1,"version-one");
        assertFalse(MetadataPlatform.identifierAffinity(rules,new IdentifierRules.ServerIdentity(Engine.MYSQL,1,"version-two",false)));
        assertFalse(MetadataPlatform.identifierAffinity(rules,new IdentifierRules.ServerIdentity(Engine.MARIADB,1,"version-one",false)));
        assertFalse(MetadataPlatform.identifierAffinity(new IdentifierRules(Engine.MYSQL,1),new IdentifierRules.ServerIdentity(Engine.MYSQL,1,"version-one",false)));
        assertTrue(MetadataPlatform.identifierAffinity(new IdentifierRules(Engine.POSTGRESQL,0),new IdentifierRules.ServerIdentity(Engine.POSTGRESQL,0,"",false)));
    }
    @Test void physicalHeaderMismatchDeniesAvailableAndRecoverableProofWithoutChangingCapturedEvidence(){
        var rules=NativeCaseFixtures.rules(Engine.MARIADB,1,"same-version");var snapshot=MetadataSnapshot.empty("source","profile",rules);var source=new MetadataPlatform.Source(snapshot);
        var fence=new MetadataPlatform.ProofFence("source",source.owner,source.proofEpoch);var wrong=new IdentifierRules.ServerIdentity(Engine.MARIADB,0,"same-version",false);var matching=new IdentifierRules.ServerIdentity(Engine.MARIADB,1,"same-version",false);
        var proof=new RetainedMetadataProof("source",1,1,"db","db","t","identity","generation",Map.of(1,new RetainedMetadataProof.ColumnProof("column","","INT","shape")),MetadataState.AVAILABLE,"");
        for(var candidate:List.of(proof,proof.invalidate("Recoverable rollback"))){
            var denied=MetadataPlatform.admitProof(source,fence,candidate,wrong);assertEquals(MetadataState.UNAVAILABLE,denied.state());assertFalse(denied.capturedStructure());
        }
        assertSame(proof,MetadataPlatform.admitProof(source,fence,proof,matching));assertSame(snapshot,source.snapshot.get());assertTrue(proof.available());
    }
}
