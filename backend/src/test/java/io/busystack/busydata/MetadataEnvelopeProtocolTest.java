package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.analysis.*;
import io.busystack.busydata.analysis.language.ResolutionContext;
import io.busystack.busydata.metadata.*;
import java.util.List;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class MetadataEnvelopeProtocolTest {
    @Test void optionalZeroOwnershipRemainsPresentAndHighBitRevisionsRemainDetectable()throws Exception{
        var omitted=RelatedRowsRequest.getDefaultInstance();assertFalse(omitted.hasExpectedSessionRevision());assertFalse(omitted.hasExpectedContextRevision());
        var zero=RelatedRowsRequest.newBuilder().setExpectedSessionRevision(0).setExpectedContextRevision(0).build();
        var roundtrip=RelatedRowsRequest.parseFrom(zero.toByteArray());assertTrue(roundtrip.hasExpectedSessionRevision());assertTrue(roundtrip.hasExpectedContextRevision());assertEquals(0,roundtrip.getExpectedSessionRevision());assertEquals(0,roundtrip.getExpectedContextRevision());
        var high=RelatedRowsRequest.parseFrom(zero.toBuilder().setExpectedSessionRevision(-1L).build().toByteArray());assertEquals(-1L,high.getExpectedSessionRevision());
    }
    @Test void semanticRepliesRetainCapturedSourceAndConfigurationWhenObjectsAreUnavailable(){
        String source=MetadataIdentity.digest("captured-envelope-source");var snapshot=MetadataSnapshot.empty(source,"captured-profile",new IdentifierRules(Engine.POSTGRESQL,0),3);
        var context=new ResolutionContext("db","public",List.of("public"),false,snapshot.revision(),snapshot.configurationRevision(),snapshot.rules(),snapshot);
        var request=AnalysisRequest.newBuilder().setDocumentId("owned-document").setDocumentVersion(1).setSessionId("owned-session").setEngine(Engine.POSTGRESQL).setSql("SELECT ").setCaretUtf16(7).setOperation(AnalysisOperation.COMPLETION).build();
        var reply=new SqlAnalysis().analyze(request,LexicalSettings.DEFAULT,context);
        assertEquals(source,reply.getMetadataSourceIdentity());assertEquals(3,reply.getMetadataConfigurationRevision());assertEquals(snapshot.revision(),reply.getMetadataSnapshotRevision());assertEquals("incomplete-metadata",reply.getAvailability());
    }
    @Test void disconnectedFormattingDoesNotInventMetadataAuthority(){
        var request=AnalysisRequest.newBuilder().setDocumentId("offline-document").setEngine(Engine.POSTGRESQL).setSql("select 1").setOperation(AnalysisOperation.FORMAT).build();
        var reply=new SqlAnalysis().analyze(request);assertTrue(reply.getMetadataSourceIdentity().isEmpty());assertEquals(0,reply.getMetadataSnapshotRevision());assertEquals(0,reply.getMetadataConfigurationRevision());assertFalse(reply.getFormattedSql().isEmpty());
    }
    @Test void completeOwnerEnvelopesFitTheUnchangedControlAndMetadataBudgets()throws Exception{
        String identity=MetadataIdentity.digest("opaque-source"),owner="x".repeat(128);long revision=Long.MAX_VALUE;
        var request=RelatedRowsRequest.newBuilder().setContext(Context.newBuilder().setInstanceId(owner).setRequestId(owner).setProtocolVersion(ProtocolVersion.BUSYDATA_PROTOCOL_VERSION.getNumber())).setSessionId(owner).setDocumentId(owner).setResultId(owner).setSourceRow(revision).setSnapshotRevision(revision).setExpectedSessionRevision(revision).setExpectedContextRevision(revision).build();assertTrue(request.getSerializedSize()<65536);
        var related=RelatedRowsReply.newBuilder().setBackendInstance(owner).setProfileId(owner).setMetadataSourceIdentity(identity).setSessionId(owner).setSessionRevision(revision).setContextRevision(revision).setMetadataConfigurationRevision(revision).setSnapshotRevision(revision).setResultId(owner).setSourceRow(revision).setAvailability("available").build();assertEquals(related,RelatedRowsReply.parseFrom(related.toByteArray()));
        var objects=SchemaObjects.newBuilder().setMetadataSourceIdentity(identity).setInstanceId(owner).setProfileId(owner).setSessionId(owner).setMetadataSnapshotRevision(revision).setMetadataConfigurationRevision(revision).build();
        var analysis=Analysis.newBuilder().setMetadataSourceIdentity(identity).setBackendInstance(owner).setSessionId(owner).setMetadataSnapshotRevision(revision).setMetadataConfigurationRevision(revision).build();
        var settings=MetadataSettingsReply.newBuilder().setMetadataSourceIdentity(identity).setBackendInstance(owner).setProfileId(owner).setSessionId(owner).setSnapshotRevision(revision).setConfigurationRevision(revision).build();
        for(var envelope:List.of(related,objects,analysis,settings))assertTrue(envelope.getSerializedSize()<65536,"Ownership adds bounded headers without raising any request/response limit");
    }
}
