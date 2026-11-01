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

class MetadataPolicyIT {
    @TempDir Path root;
    private static void ddl(SessionRegistry.Session session,String... sql)throws Exception{session.lock.lock();try{try(var statement=session.connection.createStatement()){for(String text:sql)statement.execute(text);}session.refresh();session.advanceRevision();}finally{session.lock.unlock();}}
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void excludedKindsDoNotStaleUnchangedColumnsAndUnverifiedSourceIsExplicit(String engine)throws Exception {
        try(var f=new EngineFixture(root,engine)){
            var session=f.open();var external=f.open();var explorer=new Explorer(f.metadata);var platform=explorer.metadata();String schema=f.schema();
            ddl(external,"CREATE TABLE policy_base(id INTEGER PRIMARY KEY,n INTEGER DEFAULT 7)","INSERT INTO policy_base VALUES(1,7)");
            var config=platform.configuration(session);platform.configure(session,new MetadataConfiguration(config.revision()+1,Set.of("busydata"),Set.of(),Set.of(schema),Set.of(),false,Set.of(ObjectKind.TABLE,ObjectKind.COLUMN),List.of(),List.of(),IntrospectionLevel.STRUCTURE,Map.of()));
            var before=explorer.refreshContext(session,MetadataPlatform.RefreshMode.FULL);var columns=new MetadataScope("busydata",schema,"policy_base",ObjectKind.COLUMN);var base=before.resolve("busydata",schema,ObjectKind.TABLE,"","policy_base",true).getFirst();assertTrue(before.complete(columns,IntrospectionLevel.STRUCTURE));assertTrue(before.coverage().keySet().stream().noneMatch(scope->MetadataNames.CHILDREN.contains(scope.kind())&&scope.kind()!=ObjectKind.COLUMN));
            ddl(external,"CREATE TABLE policy_added(id INTEGER)");
            var after=explorer.refreshFragment(session,"busydata",schema,"policy_added",ObjectKind.TABLE);assertSame(base,after.resolve("busydata",schema,ObjectKind.TABLE,"","policy_base",true).getFirst());assertTrue(after.complete(columns,IntrospectionLevel.STRUCTURE));
            String target=session.adapter.table("busydata",schema,"policy_base");var retained=f.results.get(f.execute(session,"SELECT id,n FROM "+target).info().getResults(0).getResultId());assertTrue(retained.metadataProof().available(),retained.metadataProof().availability());
            explorer.explore(session,ExploreRequest.newBuilder().setCatalog("busydata").setSchema(schema).setKind(ObjectKind.TABLE).setSearch("policy_base").setExactName(true).setIntrospectionLevel(3).setIndependentMetadata(true).build());var source=platform.capture(session).resolve("busydata",schema,ObjectKind.TABLE,"","policy_base",true).getFirst();assertFalse(source.source().isEmpty());
            ddl(external,"CREATE TABLE policy_second(id INTEGER)");after=explorer.refreshFragment(session,"busydata",schema,"policy_second",ObjectKind.TABLE);var unchanged=after.resolve("busydata",schema,ObjectKind.TABLE,"","policy_base",true).getFirst();assertEquals(MetadataState.AVAILABLE,unchanged.state());assertEquals(IntrospectionLevel.STRUCTURE,unchanged.level());assertEquals("STALE",unchanged.properties().get("sourceAvailability"));assertEquals(source.source(),unchanged.source());assertTrue(after.complete(columns,IntrospectionLevel.STRUCTURE));
            var exactSource=new MetadataScope("busydata",schema,"",ObjectKind.TABLE,"policy_base",true,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED);assertEquals(MetadataState.STALE,after.coverage(exactSource).orElseThrow().state());retained=f.results.get(f.execute(session,"SELECT id,n FROM "+target).info().getResults(0).getResultId());assertTrue(retained.metadataProof().available(),retained.metadataProof().availability());
        }
    }
}
