package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.rpc.WorkbenchFailure;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class MetadataSettingsEnvelopeTest {
    private static MetadataConfiguration configuration(long revision){var value=MetadataConfiguration.defaults();return new MetadataConfiguration(revision,value.includedCatalogs(),value.excludedCatalogs(),value.includedSchemas(),value.excludedSchemas(),value.systemObjects(),value.kinds(),value.includePatterns(),value.excludePatterns(),value.defaultLevel(),value.scopeLevels());}
    private static MetadataSettingsRequest request(){return MetadataSettingsRequest.newBuilder().setContext(Context.newBuilder().setInstanceId("owned-backend")).setSessionId("physical-session").setSessionRevision(7).setContextRevision(4).build();}
    @Test void aNewPolicyCannotRelabelScopesCapturedUnderAnOlderConfiguration(){
        var old=MetadataSnapshot.empty(MetadataIdentity.digest("source"),"profile",new IdentifierRules(Engine.POSTGRESQL,0),2);
        var failure=assertThrows(WorkbenchFailure.class,()->MetadataRpc.settingsHeader(request(),old,configuration(3),"AVAILABLE"));assertEquals(WorkbenchFailure.Reason.INVALID_REVISION,failure.reason());assertEquals(2,old.configurationRevision());
    }
    @Test void unavailableContentsStillReportTheirActualSourceConfigurationAndPhysicalOwner(){
        String source=MetadataIdentity.digest("source");var snapshot=MetadataSnapshot.empty(source,"",new IdentifierRules(Engine.POSTGRESQL,0),3);
        var reply=MetadataRpc.settingsHeader(request(),snapshot,configuration(3),"AVAILABLE").build();
        assertEquals("owned-backend",reply.getBackendInstance());assertEquals("physical-session",reply.getSessionId());assertEquals(7,reply.getSessionRevision());assertEquals(4,reply.getContextRevision());assertEquals(source,reply.getMetadataSourceIdentity());assertEquals(3,reply.getConfigurationRevision());assertEquals(0,reply.getSnapshotRevision());assertTrue(reply.getScopesList().isEmpty());assertEquals("UNAVAILABLE",reply.getCacheState());assertTrue(reply.getProfileId().isEmpty(),"Preserve an unsaved profile's empty identifier without inventing one");
    }
}
