package io.busystack.busydata;

import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.Explorer;
import io.busystack.busydata.schema.OwnedTemporarySource;
import java.nio.file.Path;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

/** Session-local counters must never authorize stale durable refresh publication. */
class MetadataPublicationIT {
    @TempDir Path root;
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void failedOlderRefreshCannotPoisonFreshPublicationWhenOverlayCountersCollide(String engine)throws Exception {
        try(var f=new EngineFixture(root,engine)){
            var session=f.open();var explorer=new Explorer(f.metadata);var platform=explorer.metadata();
            // External fixture DDL deliberately bypasses the smart scheduler so
            // this counter interleaving is deterministic rather than timed.
            session.lock.lock();try{try(var statement=session.connection.createStatement()){statement.execute("CREATE TABLE publication_rows(id INTEGER PRIMARY KEY,n INTEGER)");statement.execute("CREATE TEMPORARY TABLE publication_temporary(n INTEGER)");}session.refresh();session.advanceRevision();}finally{session.lock.unlock();}
            explorer.refreshFragment(session,"busydata",f.schema(),"publication_rows",ObjectKind.TABLE);
            var original=platform.publicationRevision(session);
            session.lock.lock();try{for(int index=0;index<3;index++)explorer.refreshTemporary(session,"busydata",f.schema(),"publication_temporary");}finally{session.lock.unlock();}
            var columns=new MetadataScope("busydata",f.schema(),"publication_rows",ObjectKind.COLUMN);
            if(f.engine!=Engine.POSTGRESQL){
                var unknown=platform.capture(session);
                assertTrue(platform.publishedSnapshot(session).complete(columns,IntrospectionLevel.STRUCTURE),"The independent acquisition proved durable columns, not physical-session name resolution");
                assertEquals(MetadataState.UNKNOWN,unknown.coverage(columns).orElseThrow().state());assertFalse(unknown.complete(columns,IntrospectionLevel.STRUCTURE));
                session.lock.lock();try{var physical=OwnedTemporarySource.verify(platform,session,"busydata",f.schema(),"publication_rows",System.nanoTime()+TimeUnit.SECONDS.toNanos(10),null);assertTrue(physical.available());assertEquals(MetadataSnapshot.PhysicalRelationKind.PERSISTENT,physical.kind());}finally{session.lock.unlock();}
                assertEquals(MetadataState.UNKNOWN,platform.capture(session).sessionResolution().state(),"An exact persistent fact cannot certify the whole session inventory");
                assertTrue(platform.capture(session).complete(columns,IntrospectionLevel.STRUCTURE));
                assertFalse(unknown.complete(columns,IntrospectionLevel.STRUCTURE),"The earlier immutable unknown view remains unknown");
            }
            long overlayRevision=platform.capture(session).revision();assertTrue(overlayRevision>original.revision());assertEquals(original.revision(),platform.publicationRevision(session).revision());
            while(platform.publicationRevision(session).revision()<overlayRevision)explorer.refreshFragment(session,"busydata",f.schema(),"publication_rows",ObjectKind.TABLE);
            assertEquals(overlayRevision,platform.publicationRevision(session).revision(),"The stale overlay number now matches a newer durable publication");
            assertTrue(platform.capture(session).complete(columns,IntrospectionLevel.STRUCTURE));
            platform.markStaleIfRevision(session,original,"An older independent acquisition failed");assertEquals(overlayRevision,platform.publicationRevision(session).revision());assertTrue(platform.capture(session).complete(columns,IntrospectionLevel.STRUCTURE),"An old token cannot stale the newly reconciled column branch");
            var current=platform.publicationRevision(session);platform.markStaleIfRevision(session,current,"The current acquisition failed");assertEquals(MetadataState.STALE,platform.capture(session).coverage(columns).orElseThrow().state(),"Current refresh failures remain explicit");
            assertTrue(platform.capture(session).identities().values().stream().anyMatch(object->object.identity().sessionOwner().equals(session.id)&&object.identity().name().equals("publication_temporary")));
        }
    }
}
