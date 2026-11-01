package io.busystack.busydata;

import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.rpc.WorkbenchFailure;
import io.busystack.busydata.rpc.WorkbenchService;
import io.busystack.busydata.schema.Explorer;
import io.busystack.busydata.sessions.SessionRegistry;
import io.grpc.Metadata;
import io.grpc.Status;
import io.grpc.stub.StreamObserver;
import java.lang.reflect.*;
import java.nio.file.Path;
import java.sql.Connection;
import java.util.*;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

/** Real pinned sessions and the actual RPC mapper/transport boundary. The
 * counter covers public Connection entry only, not autonomous driver work. */
class MetadataRpcOwnershipIT {
    @TempDir Path root;
    private record Refusal(MetadataSettingsRequest request,WorkbenchFailure.Reason reason){}
    private static final class Reply implements StreamObserver<MetadataSettingsReply> {
        MetadataSettingsReply value;Throwable error;boolean complete;
        public void onNext(MetadataSettingsReply reply){assertNull(value);value=reply;}
        public void onError(Throwable failure){error=failure;}
        public void onCompleted(){complete=true;}
    }
    private static void unchanged(MetadataPlatform platform,SessionRegistry.Session owner,MetadataConfiguration policy,MetadataSnapshot snapshot,AtomicInteger calls,int before,long revision,long context){
        assertEquals(before,calls.get(),"Admission must not enter a public JDBC connection");
        assertEquals(policy,platform.configuration(owner),"Refusal must not change the source configuration");
        assertSame(snapshot,platform.publishedSnapshot(owner),"Refusal must not publish metadata");
        assertEquals(revision,owner.revision);assertEquals(context,owner.contextRevision);
    }
    private static void transportRefusal(WorkbenchService service,MetadataSettingsRequest request,WorkbenchFailure.Reason reason){
        var reply=new Reply();service.metadataSettings(request,reply);assertNull(reply.value);assertFalse(reply.complete);assertNotNull(reply.error);
        assertEquals(reason.status().getCode(),Status.fromThrowable(reply.error).getCode());
        var trailers=Status.trailersFromThrowable(reply.error);assertNotNull(trailers);
        assertEquals(reason.wire(),trailers.get(Metadata.Key.of(WorkbenchFailure.TRAILER,Metadata.ASCII_STRING_MARSHALLER)));
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void invalidRequestsKeepTypedReasonsBeforeJdbcOrConfigurationChanges(String engine)throws Exception {
        var calls=new AtomicInteger();
        try(var fixture=new EngineFixture(root,engine,(adapter,request,port)->{
            var physical=adapter.connect(request,port);
            return (Connection)Proxy.newProxyInstance(Connection.class.getClassLoader(),new Class[]{Connection.class},(proxy,method,args)->{
                calls.incrementAndGet();try{return method.invoke(physical,args);}catch(InvocationTargetException failure){throw failure.getCause();}
            });
        })){
            var owner=fixture.open();var platform=fixture.metadata.metadataPlatform();var initial=platform.configuration(owner);
            platform.configure(owner,new MetadataConfiguration(initial.revision()+1,initial.includedCatalogs(),initial.excludedCatalogs(),initial.includedSchemas(),initial.excludedSchemas(),initial.systemObjects(),initial.kinds(),initial.includePatterns(),initial.excludePatterns(),initial.defaultLevel(),initial.scopeLevels()));
            var explorer=new Explorer(platform);var service=new WorkbenchService(fixture.sessions,fixture.jobs,fixture.results,fixture.metadata,fixture.safety,fixture.analysis,()->{});
            var context=Context.newBuilder().setInstanceId(service.instance).setProtocolVersion(WorkbenchService.PROTOCOL).setRequestId("metadata-owned-admission").build();
            var current=MetadataSettingsRequest.newBuilder().setContext(context).setSessionId(owner.id).setSessionRevision(owner.revision).setContextRevision(owner.contextRevision).setAction(MetadataSettingsAction.READ_METADATA_SETTINGS).build();
            var policy=platform.configuration(owner);var published=platform.publishedSnapshot(owner);var captured=platform.capture(owner);
            int before=calls.get();long revision=owner.revision,contextRevision=owner.contextRevision;
            assertEquals(0,revision,"Zero is a legitimate initial physical revision, not missing ownership");assertTrue(contextRevision>0);assertTrue(policy.revision()>1);
            var happy=new Reply();service.metadataSettings(current,happy);assertNull(happy.error);assertTrue(happy.complete);assertNotNull(happy.value);
            assertEquals(service.instance,happy.value.getBackendInstance());assertEquals(owner.id,happy.value.getSessionId());assertEquals(owner.profile.getId(),happy.value.getProfileId());
            assertEquals(owner.metadataSourceIdentity,happy.value.getMetadataSourceIdentity());assertEquals(revision,happy.value.getSessionRevision());assertEquals(contextRevision,happy.value.getContextRevision());
            assertEquals(policy.revision(),happy.value.getConfigurationRevision());assertEquals(captured.revision(),happy.value.getSnapshotRevision());assertEquals(MetadataRpc.projection(policy),happy.value.getConfiguration());assertEquals(0,happy.value.getScopesCount());assertTrue(happy.value.getComplete());
            unchanged(platform,owner,policy,published,calls,before,revision,contextRevision);
            var malformedPolicy=MetadataRpc.projection(policy).toBuilder().addKinds(ObjectKind.TABLE).addKinds(ObjectKind.TABLE).build();
            var refusals=List.of(
                new Refusal(current.toBuilder().setSessionId("forged-owner").setSessionRevision(-1L).build(),WorkbenchFailure.Reason.INVALID_OWNER),
                new Refusal(current.toBuilder().clearSessionId().build(),WorkbenchFailure.Reason.INVALID_OWNER),
                new Refusal(current.toBuilder().setSessionRevision(revision+1).build(),WorkbenchFailure.Reason.INVALID_REVISION),
                new Refusal(current.toBuilder().setContextRevision(contextRevision+1).build(),WorkbenchFailure.Reason.INVALID_REVISION),
                new Refusal(current.toBuilder().clearContextRevision().build(),WorkbenchFailure.Reason.INVALID_REVISION),
                new Refusal(current.toBuilder().setSessionRevision(-1L).build(),WorkbenchFailure.Reason.MALFORMED_REQUEST),
                new Refusal(current.toBuilder().setContextRevision(-1L).build(),WorkbenchFailure.Reason.MALFORMED_REQUEST),
                new Refusal(current.toBuilder().setExpectedConfigurationRevision(-1L).build(),WorkbenchFailure.Reason.MALFORMED_REQUEST),
                new Refusal(current.toBuilder().setExpectedSnapshotRevision(-1L).build(),WorkbenchFailure.Reason.MALFORMED_REQUEST),
                new Refusal(current.toBuilder().setOffset(-1).build(),WorkbenchFailure.Reason.MALFORMED_REQUEST),
                new Refusal(current.toBuilder().setOffset(100001).build(),WorkbenchFailure.Reason.MALFORMED_REQUEST),
                new Refusal(current.toBuilder().setLimit(-1).build(),WorkbenchFailure.Reason.MALFORMED_REQUEST),
                new Refusal(current.toBuilder().setLimit(129).build(),WorkbenchFailure.Reason.MALFORMED_REQUEST),
                new Refusal(current.toBuilder().setActionValue(999).build(),WorkbenchFailure.Reason.MALFORMED_REQUEST),
                new Refusal(current.toBuilder().setConfiguration(MetadataIntrospectionConfiguration.newBuilder().addIncludePatterns("x".repeat(131072))).build(),WorkbenchFailure.Reason.MALFORMED_REQUEST),
                new Refusal(current.toBuilder().setAction(MetadataSettingsAction.SAVE_METADATA_SETTINGS).setExpectedConfigurationRevision(policy.revision()-1).setConfiguration(MetadataRpc.projection(policy)).build(),WorkbenchFailure.Reason.INVALID_REVISION),
                new Refusal(current.toBuilder().setAction(MetadataSettingsAction.SAVE_METADATA_SETTINGS).setExpectedConfigurationRevision(policy.revision()).setConfiguration(malformedPolicy).build(),WorkbenchFailure.Reason.MALFORMED_REQUEST),
                new Refusal(current.toBuilder().setOffset(1).setExpectedSnapshotRevision(captured.revision()+1).build(),WorkbenchFailure.Reason.STALE),
                new Refusal(current.toBuilder().setOffset(1).setExpectedSnapshotRevision(captured.revision()).build(),WorkbenchFailure.Reason.MALFORMED_REQUEST)
            );
            for(var refusal:refusals){
                assertEquals(refusal.reason(),assertThrows(WorkbenchFailure.class,()->MetadataRpc.run(explorer,owner,refusal.request())).reason());
                unchanged(platform,owner,policy,published,calls,before,revision,contextRevision);
                transportRefusal(service,refusal.request(),refusal.reason());
                unchanged(platform,owner,policy,published,calls,before,revision,contextRevision);
            }
            assertThrows(IllegalArgumentException.class,()->MetadataRpc.configuration(malformedPolicy,policy.revision()+1),"Pure configuration projection retains its non-RPC API");
            var pending=fixture.sessions.openPending(OpenRequest.newBuilder().setProfile(fixture.profile).setPassword("fixture").build());
            try{
                int pendingBefore=calls.get();var pendingRequest=current.toBuilder().setSessionId(pending.id).setSessionRevision(pending.revision).setContextRevision(pending.contextRevision).build();
                transportRefusal(service,pendingRequest,WorkbenchFailure.Reason.INVALID_OWNER);assertEquals(pendingBefore,calls.get());
                assertThrows(IllegalStateException.class,()->fixture.sessions.get(pending.id),"Metadata settings must not adopt a pending physical session");
                assertEquals(policy,platform.configuration(owner));assertSame(published,platform.publishedSnapshot(owner));assertTrue(fixture.jobs.list("").isEmpty());
            }finally{fixture.sessions.cancelPending(pending.id);}
            assertTrue(pending.physicalEnded());
        }
    }
}
