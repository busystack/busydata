package io.busystack.busydata.metadata;

import java.util.Map;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class ExternalProofInvalidationTest {
    private static RetainedMetadataProof proof(){return new RetainedMetadataProof("source",7,2,"db","schema","table","identity","generation",Map.of(1,new RetainedMetadataProof.ColumnProof("column","23","integer","shape")),MetadataState.AVAILABLE,"","zone");}
    @Test void externalInvalidationCannotUseOrdinaryRollbackRecovery(){var original=proof();assertTrue(original.invalidate("Ordinary uncommitted DDL").samePhysicalStructure(original));var external=original.invalidateExternal("External native outcome");assertEquals(MetadataState.STALE,external.state());assertFalse(external.capturedStructure());assertFalse(external.samePhysicalStructure(original));assertTrue(original.available());}
    @Test void irreversibleRetirementPreservesInspectionProvenance(){var original=proof();var external=original.invalidateExternal("External native outcome");assertEquals(original.sourceKey(),external.sourceKey());assertEquals(original.snapshotRevision(),external.snapshotRevision());assertEquals(original.catalog(),external.catalog());assertEquals(original.schema(),external.schema());assertEquals(original.table(),external.table());assertEquals(original.temporalContext(),external.temporalContext());assertTrue(external.columns().isEmpty());}
    @Test void laterRecoverableInvalidationCannotRestoreRetiredEvidence(){var original=proof();var external=original.invalidateExternal("External native outcome").invalidate("Console rollback");assertFalse(external.capturedStructure());assertFalse(external.samePhysicalStructure(original));assertEquals(MetadataState.STALE,external.state());}
}
