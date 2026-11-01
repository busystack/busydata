package io.busystack.busydata;

import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.Explorer;
import io.busystack.busydata.sessions.SessionRegistry;
import java.nio.file.Path;
import java.util.*;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

class FragmentNamesIT {
    @TempDir Path root;
    private static void ddl(SessionRegistry.Session session,String... statements)throws Exception {
        session.lock.lock();try{try(var command=session.connection.createStatement()){for(String statement:statements)command.execute(statement);}session.refresh();session.advanceRevision();}finally{session.lock.unlock();}
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void fragmentReconcilesCachedNamesWithoutReloadingUnchangedStructureOrBlessingExternalChanges(String engine)throws Exception {
        try(var f=new EngineFixture(root,engine)){
            var session=f.open();var external=f.open();var other=f.open();var explorer=new Explorer(f.metadata);var platform=explorer.metadata();String schema=f.schema();
            var fields=new ArrayList<String>();fields.add("id INTEGER PRIMARY KEY");for(int index=0;index<64;index++)fields.add("n"+index+" DECIMAL(30,9) DEFAULT 123.456");
            ddl(external,"CREATE TABLE names_kept("+String.join(",",fields)+")","CREATE TABLE names_vanished(id INTEGER PRIMARY KEY)");
            explorer.refreshContext(session,MetadataPlatform.RefreshMode.FULL);
            explorer.explore(session,ExploreRequest.newBuilder().setCatalog("busydata").setSchema(schema).setKind(ObjectKind.TABLE).setSearch("names_kept").setExactName(true).setIntrospectionLevel(3).setIndependentMetadata(true).build());
            var original=platform.publishedSnapshot(session);var relation=original.resolve("busydata",schema,ObjectKind.TABLE,"","names_kept",true).getFirst();var columns=new MetadataScope("busydata",schema,"names_kept",ObjectKind.COLUMN);var enumeration=new MetadataScope("busydata",schema,"",ObjectKind.TABLE);
            assertEquals(65,original.select(columns).size());assertFalse(relation.source().isEmpty());assertEquals(IntrospectionLevel.SOURCE,relation.level());
            ddl(external,"CREATE TABLE names_created(id INTEGER PRIMARY KEY,n INTEGER)");
            platform.markStaleEffects(session,List.of(DdlEffect.newBuilder().setOperation("CREATE").setCatalog("busydata").setSchema(schema).setKind(ObjectKind.TABLE).setName("names_created").build()),"An acknowledged precise table DDL changed names");
            var refreshed=explorer.refreshFragment(session,"busydata",schema,"names_created",ObjectKind.TABLE);
            var names=refreshed.coverage(enumeration).orElseThrow();assertTrue(names.complete());assertEquals(IntrospectionLevel.NAMES,names.level(),"A names-only scan cannot claim every relation's structural completeness");assertEquals(3,refreshed.select(enumeration).size());assertSame(relation,refreshed.resolve("busydata",schema,ObjectKind.TABLE,"","names_kept",true).getFirst(),"Verified unchanged facts and Level 3 source are shared");assertTrue(refreshed.complete(columns,IntrospectionLevel.STRUCTURE));assertEquals(2,refreshed.namespace("busydata",schema,ObjectKind.COLUMN,"names_created").size());assertEquals(2,original.select(enumeration).size(),"Existing readers retain one immutable snapshot");
            assertTrue(platform.diagnostics(session).orElseThrow().fetchedObjects()<25,"Namespace fingerprints must not fetch the 65 unchanged column structures");
            // A temporary object shadows the permanent name only in its owning
            // physical session. The refresh writer must use the durable baseline.
            ddl(session,"CREATE TEMPORARY TABLE names_kept(temporary_only INTEGER)");
            session.lock.lock();try{explorer.refreshTemporary(session,"busydata",schema,"names_kept");}finally{session.lock.unlock();}
            ddl(external,"ALTER TABLE names_kept ADD COLUMN externally_changed INTEGER DEFAULT 9","DROP TABLE names_vanished","CREATE TABLE names_second(id INTEGER PRIMARY KEY)");
            explorer.refreshFragment(session,"busydata",schema,"names_second",ObjectKind.TABLE);
            var durable=platform.publishedSnapshot(session);var changed=durable.resolve("busydata",schema,ObjectKind.TABLE,"","names_kept",true).getFirst();assertEquals(MetadataState.STALE,changed.state());assertFalse(changed.source().isEmpty(),"Unverified higher facts remain inspectable with explicit stale availability");assertEquals(MetadataState.STALE,durable.coverage(columns).orElseThrow().state());assertTrue(durable.resolve("busydata",schema,ObjectKind.TABLE,"","names_vanished",true).isEmpty());assertTrue(durable.namespace("busydata",schema,ObjectKind.COLUMN,"names_vanished").isEmpty());assertTrue(durable.coverage(new MetadataScope("busydata",schema,"names_vanished",ObjectKind.COLUMN)).stream().noneMatch(MetadataCoverage::complete));
            assertTrue(durable.complete(new MetadataScope("busydata",schema,"names_second",ObjectKind.COLUMN),IntrospectionLevel.STRUCTURE));assertTrue(durable.resolve("busydata",schema,ObjectKind.COLUMN,"names_kept","temporary_only",true).isEmpty());assertTrue(platform.capture(other).identities().values().stream().noneMatch(object->object.identity().sessionOwner().equals(session.id)));assertTrue(platform.capture(session).identities().values().stream().anyMatch(object->object.identity().sessionOwner().equals(session.id)&&object.identity().name().equals("temporary_only")));
            assertTrue(f.jobs.list("").isEmpty(),"Metadata reconciliation never executes or retries user SQL");
        }
    }
}
