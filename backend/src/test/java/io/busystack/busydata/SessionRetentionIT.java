package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import java.nio.file.Path;
import java.sql.SQLException;
import java.util.ArrayList;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

/** Uncertain handles stay reachable without permitting unbounded driver retention. */
class SessionRetentionIT {
    @TempDir Path root;

    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void quarantinedHandlesRemainBoundedUntilExplicitDisconnect(String engine)throws Exception {
        try(var f=new EngineFixture(root,engine)) {
            var retained=new ArrayList<String>();
            for(int count=0;count<8;count++) {
                var session=f.open();
                f.execute(session,"SELECT repeat('r',65536) AS retained_driver_value");
                session.quarantine(new SQLException("Injected unconfirmed connection outcome","08006"));
                assertTrue(session.connection.isClosed());
                assertEquals(TransactionState.UNKNOWN_TRANSACTION,session.info().getTransaction());
                retained.add(session.id);
            }
            assertEquals(8,f.sessions.size());
            assertEquals(0,f.sessions.physicalSessionCount());
            var failure=assertThrows(IllegalStateException.class,f::open,
                "Closed driver objects behind uncertain handles must not accumulate without admission");
            assertTrue(failure.getMessage().contains("disconnect"),"Admission must explain how to resolve retained uncertainty");
            for(String id:retained) {
                var status=f.sessions.command(SessionRequest.newBuilder().setSessionId(id).build());
                assertEquals(TransactionState.UNKNOWN_TRANSACTION,status.getTransaction());
                assertThrows(IllegalStateException.class,()->f.sessions.command(SessionRequest.newBuilder().setSessionId(id).setAction(SessionAction.COMMIT).build()));
            }
            f.sessions.close(retained.removeFirst(),true);
            var replacement=f.open();
            assertEquals(1,f.sessions.physicalSessionCount());
            assertEquals("43",f.results.get(f.execute(replacement,"SELECT 43").info().getResults(0).getResultId()).read(0).getValues(0).getSignedInteger());
            assertEquals(8,f.sessions.size());
            f.sessions.close(replacement.id,true);
            for(String id:retained)f.sessions.close(id,true);
            assertEquals(0,f.sessions.size());
            assertEquals(0,f.sessions.physicalSessionCount());
            var restored=new ArrayList<String>();
            for(int count=0;count<8;count++)restored.add(f.open().id);
            assertThrows(IllegalStateException.class,f::open);
            for(String id:restored)f.sessions.close(id,true);
            assertEquals(0,f.sessions.size());
        }
    }
}
