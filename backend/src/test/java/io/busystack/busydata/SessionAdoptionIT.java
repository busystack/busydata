package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import java.nio.file.Path;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

class SessionAdoptionIT {
    @TempDir Path root;
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void lostOpeningResponsesCannotOrphanPhysicalConnections(String engine)throws Exception {
        try(var f=new EngineFixture(root,engine)) {
            var request=OpenRequest.newBuilder().setProfile(f.profile).setPassword("fixture").build();
            var previous=f.open();
            var pending=f.sessions.openPending(request);
            assertThrows(IllegalStateException.class,()->f.sessions.get(pending.id));
            f.sessions.cancelPending(pending.id);
            assertTrue(pending.connection.isClosed());assertEquals(1,f.sessions.size());
            assertSame(previous,f.sessions.get(previous.id));
            var adopted=f.sessions.openPending(request);
            var accepted=f.sessions.command(SessionRequest.newBuilder().setSessionId(adopted.id).setAction(SessionAction.ADOPT_SESSION).build());
            assertEquals(adopted.id,accepted.getSessionId());assertEquals(adopted.profile,accepted.getProfile());
            assertEquals(previous.info().getMetadataSourceIdentity(),accepted.getMetadataSourceIdentity());
            assertEquals(io.busystack.busydata.metadata.SourceIdentity.fingerprint(f.profile),accepted.getMetadataSourceIdentity());
            f.sessions.cancelPending(adopted.id);
            assertSame(adopted,f.sessions.get(adopted.id));assertFalse(adopted.connection.isClosed());
            assertEquals(JobState.COMPLETED,f.execute(adopted,"SELECT 7").state);
            f.sessions.close(adopted.id,true);
            for(int i=0;i<12;i++) {var unused=f.sessions.openPending(request);f.sessions.cancelPending(unused.id);}
            assertEquals(1,f.sessions.size());assertEquals(JobState.COMPLETED,f.execute(previous,"SELECT 8").state);
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void cancellationAfterAuthenticationDisposesTestSessionsAndReleasesAdmission(String engine)throws Exception {
        var cancelled=new java.util.concurrent.atomic.AtomicBoolean();
        try(var f=new EngineFixture(root,engine,(adapter,request,port)->{
            var connection=adapter.connect(request,port);cancelled.set(true);return connection;
        })) {
            var request=OpenRequest.newBuilder().setProfile(f.profile).setPassword("fixture").build();
            for(int i=0;i<12;i++) {
                cancelled.set(false);
                assertThrows(java.util.concurrent.CancellationException.class,()->f.sessions.test(request,cancelled::get));
                assertEquals(0,f.sessions.size(),"A cancelled profile test must not retain physical sessions or consume connection admission");
            }
        }
    }

}
