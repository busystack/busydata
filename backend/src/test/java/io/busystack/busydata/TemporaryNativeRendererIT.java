package io.busystack.busydata;

import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.OwnedTemporarySource;
import java.nio.file.Path;
import java.sql.*;
import java.util.*;
import java.util.concurrent.TimeUnit;
import java.util.stream.Stream;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.*;
import static org.junit.jupiter.api.Assertions.*;

/** Native quote=0 remains exact; no client casing repair or alias authority. */
class TemporaryNativeRendererIT {
    @TempDir Path root;
    static Stream<Arguments> cases(){return Stream.of("MYSQL","MARIADB").flatMap(engine->Stream.of(0,1).flatMap(mode->Stream.of(false,true).map(ansi->Arguments.of(engine,mode,ansi))));}
    @ParameterizedTest @MethodSource("cases")
    void quoteOffAndAnsiUseActualStoredNameForSimpleAndSpecialIdentifiers(String engine,int lowerCaseMode,boolean ansi)throws Exception{
        try(var fixture=new EngineFixture(root,engine,container->container.withCommand("--lower-case-table-names="+lowerCaseMode,"--character-set-server=utf8mb4","--collation-server=utf8mb4_unicode_ci"))){
            var session=fixture.open();fixture.introspectionLevel(session,IntrospectionLevel.STRUCTURE);
            session.lock.lock();try{
                try(var mode=session.connection.prepareStatement("SET SESSION sql_mode=?")){mode.setString(1,ansi?"ANSI_QUOTES":"");mode.execute();}
                try(var setup=session.connection.createStatement()){setup.execute("SET SESSION sql_quote_show_create=OFF");for(String name:List.of("MiXeD","odd`quote\" table"))setup.execute("CREATE TEMPORARY TABLE "+session.adapter.quote(name)+"(id INTEGER PRIMARY KEY)");}
                session.refresh();
            }finally{session.lock.unlock();}
            for(String requested:List.of("MiXeD","odd`quote\" table")){
                var job=fixture.execute(session,"SELECT id FROM "+session.adapter.quote(requested));assertEquals(JobState.COMPLETED,job.state);
                session.lock.lock();try{
                    var platform=fixture.metadata.metadataPlatform();var observed=OwnedTemporarySource.verify(platform,session,"busydata","busydata",requested,System.nanoTime()+TimeUnit.SECONDS.toNanos(10),null);
                    assertTrue(observed.available());assertEquals(MetadataSnapshot.PhysicalRelationKind.TEMPORARY,observed.kind());assertEquals(MetadataState.AVAILABLE,observed.nativeNameAvailability());assertEquals(requested.equals("MiXeD")&&lowerCaseMode==1?"mixed":requested,observed.nativeName());assertEquals("OWNED_NATIVE_CREATE_HEADER",observed.nativeNameProvenance());assertTrue(observed.definition().complete());assertEquals("quote=0;gipk="+(fixture.engine==Engine.MYSQL?"1":"N/A"),observed.definition().renderer());assertEquals(session.context.sqlMode(),observed.definition().sqlMode());assertTrue(observed.reusesOwnedShape(platform,session));assertTrue(platform.capture(session).ownedRelationAvailable("busydata","busydata",observed.nativeName(),true));
                    assertTrue(platform.publishedSnapshot(session).identities().values().stream().allMatch(value->value.identity().sessionOwner().isEmpty()));
                }finally{session.lock.unlock();}
            }
            assertEquals(2,fixture.jobs.list(session.id).size());
        }
    }
}
