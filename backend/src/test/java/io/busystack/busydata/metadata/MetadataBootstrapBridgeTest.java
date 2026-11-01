package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.Engine;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

/** A rules header is not a structural refresh and cannot retire committed DDL intent. */
class MetadataBootstrapBridgeTest {
    private static final IdentifierRules RULES=new IdentifierRules(Engine.POSTGRESQL,0);
    private static MetadataSnapshot snapshot(long revision,long configuration){return new MetadataSnapshot("source","profile",revision,configuration,1,RULES,List.of(),Map.of());}
    private static MetadataPlatform.Source source(){
        var owner=new MetadataPlatform.Source(snapshot(2,3));owner.requestEpoch=4;owner.proofEpoch=5;owner.bootstrapBridge=new MetadataPlatform.BootstrapBridge(1,2,3,4,5,"session",9);return owner;
    }
    @Test void onlyTheExactHeaderTransitionCanBridgeARealSettlement(){
        var owner=source();synchronized(owner){assertTrue(MetadataPlatform.bootstrapRevision(owner,1,3,4,"session",9));assertFalse(MetadataPlatform.bootstrapRevision(owner,0,3,4,"session",9));assertFalse(MetadataPlatform.bootstrapRevision(owner,1,2,4,"session",9));assertFalse(MetadataPlatform.bootstrapRevision(owner,1,3,3,"session",9));}
    }
    @Test void structuralInvalidationOrNativeProofRetirementCannotBeBridged(){
        var owner=source();synchronized(owner){owner.proofEpoch++;assertFalse(MetadataPlatform.bootstrapRevision(owner,1,3,4,"session",9));owner.proofEpoch--;owner.snapshot.set(snapshot(3,3));assertFalse(MetadataPlatform.bootstrapRevision(owner,1,3,4,"session",9));}
    }
    @Test void aNewExplicitRequestOrConfigurationCannotReviveOldIntent(){
        var owner=source();synchronized(owner){owner.requestEpoch++;assertFalse(MetadataPlatform.bootstrapRevision(owner,1,3,4,"session",9));owner.requestEpoch--;owner.snapshot.set(snapshot(2,4));assertFalse(MetadataPlatform.bootstrapRevision(owner,1,3,4,"session",9));}
    }
    @Test void aNormalDurablePublicationClearsTheHeaderOnlyBridge(){
        var owner=source();synchronized(owner){MetadataPlatform.commitSnapshot(owner,1,snapshot(3,3));assertNull(owner.bootstrapBridge);assertFalse(MetadataPlatform.bootstrapRevision(owner,1,3,4,"session",9));}
    }
    @Test void anotherPhysicalContextOrExternalBarrierCannotAdoptTheHeaderBridge(){var owner=source();synchronized(owner){assertFalse(MetadataPlatform.bootstrapRevision(owner,1,3,4,"other",9));assertFalse(MetadataPlatform.bootstrapRevision(owner,1,3,4,"session",10));owner.externalActive=1;assertFalse(MetadataPlatform.bootstrapRevision(owner,1,3,4,"session",9));}}
    @Test void bridgeValidationRequiresTheExactSourceGuard(){assertThrows(IllegalStateException.class,()->MetadataPlatform.bootstrapRevision(source(),1,3,4,"session",9));}
}
