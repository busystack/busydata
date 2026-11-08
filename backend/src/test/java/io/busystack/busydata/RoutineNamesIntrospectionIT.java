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

/** Names acquisition must execute the native routine query, including its
 * identity projection, before any higher-level cache can mask a failure. */
class RoutineNamesIntrospectionIT {
    @TempDir Path root;

    private static void external(SessionRegistry.Session session,String sql)throws Exception {
        session.lock.lock();
        try(var statement=session.connection.createStatement()){
            statement.setQueryTimeout(10);statement.execute(sql);session.refresh();
        }finally{session.lock.unlock();}
    }

    private static List<MetadataObject> names(MetadataSnapshot snapshot,String catalog,String schema,int expected){
        var scope=new MetadataScope(catalog,schema,"",ObjectKind.ROUTINE);
        var coverage=snapshot.coverage(scope).orElseThrow();
        assertEquals(MetadataState.AVAILABLE,coverage.state(),coverage.limitation());
        assertTrue(coverage.complete());assertEquals(IntrospectionLevel.NAMES,coverage.level());
        assertTrue(snapshot.complete(scope,IntrospectionLevel.NAMES));
        var routines=snapshot.namespace(catalog,schema,ObjectKind.ROUTINE,"");
        assertEquals(expected,routines.size());
        assertEquals(expected,routines.stream().map(value->value.identity().key()).distinct().count());
        for(var routine:routines){
            assertEquals("names_routine",routine.identity().name());
            assertFalse(routine.identity().signature().isBlank());
            assertFalse(routine.properties().getOrDefault("specificName","").isBlank());
            assertTrue(routine.source().isEmpty());
            assertFalse(routine.properties().containsKey("parameterCount"));
            assertFalse(routine.properties().containsKey("returnType"));
        }
        assertEquals(1,routines.stream().filter(value->value.identity().subtype()==ObjectSubtype.PROCEDURE).count());
        return routines;
    }

    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void coldNamesRefreshAndExplorerPreserveNativeRoutineIdentitiesAcrossLevels(String engine)throws Exception {
        try(var fixture=new EngineFixture(root,engine)){
            var session=fixture.open();boolean pg=fixture.engine==Engine.POSTGRESQL;
            String catalog=session.context.catalog(),schema=fixture.schema();
            String qualified=session.adapter.table(catalog,schema,"names_routine");
            external(session,pg?"CREATE FUNCTION "+qualified+"(a INTEGER) RETURNS INTEGER LANGUAGE sql AS 'SELECT a'":
                "CREATE FUNCTION "+qualified+"(a INTEGER) RETURNS INTEGER DETERMINISTIC RETURN a");
            external(session,pg?"CREATE PROCEDURE "+qualified+"(IN a BIGINT) LANGUAGE plpgsql AS 'BEGIN NULL; END'":
                "CREATE PROCEDURE "+qualified+"(IN a INTEGER) SELECT a");
            if(pg)external(session,"CREATE FUNCTION "+qualified+"(a TEXT) RETURNS TEXT LANGUAGE sql AS 'SELECT a'");
            var explorer=new Explorer(fixture.metadata);int expected=pg?3:2;
            fixture.introspectionLevel(session,IntrospectionLevel.NAMES);
            var cold=explorer.refreshContext(session,MetadataPlatform.RefreshMode.FULL);
            var original=names(cold,catalog,schema,expected);
            var page=explorer.explore(session,ExploreRequest.newBuilder().setCatalog(catalog).setSchema(schema)
                .setKind(ObjectKind.ROUTINE).setIntrospectionLevel(1).setRefresh(true).build());
            assertTrue(page.getComplete());assertEquals(expected,page.getObjectsCount());
            assertEquals(MetadataCount.AUTHORITATIVE_TOTAL,page.getCountAvailability());
            assertEquals(expected,page.getTotalCount());
            for(var object:page.getObjectsList()){
                assertFalse(object.getPropertiesOrDefault("specificName","").isBlank());
                assertTrue(object.getDefinition().isEmpty());
            }
            fixture.introspectionLevel(session,IntrospectionLevel.SOURCE);
            var source=explorer.refreshContext(session,MetadataPlatform.RefreshMode.FULL);
            for(var routine:original){
                var detailed=source.identities().get(routine.identity().key());assertNotNull(detailed);
                assertEquals(routine.properties().get("specificName"),detailed.properties().get("specificName"));
                assertEquals("AVAILABLE",detailed.properties().get("sourceAvailability"));
                assertFalse(detailed.source().isBlank());
            }
            names(cold,catalog,schema,expected); // Published Names facts remain immutable.
            fixture.introspectionLevel(session,IntrospectionLevel.NAMES);
            var downgraded=names(explorer.refreshContext(session,MetadataPlatform.RefreshMode.FULL),catalog,schema,expected);
            assertEquals(original.stream().map(value->value.identity().key()).collect(java.util.stream.Collectors.toSet()),
                downgraded.stream().map(value->value.identity().key()).collect(java.util.stream.Collectors.toSet()));
        }
    }
}
