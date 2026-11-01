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

class RoutineIncrementalFingerprintIT {
    @TempDir Path root;
    private static final String CHANGED="incremental_routine",STABLE="stable_routine",ADDED="added_routine";
    /** External fixture DDL deliberately bypasses Jobs/Smart invalidation, so
     * only the native incremental fingerprint can detect these replacements. */
    private static void external(SessionRegistry.Session session,String sql)throws Exception {
        session.lock.lock();try(var statement=session.connection.createStatement()){statement.setQueryTimeout(10);statement.execute(sql);session.refresh();}finally{session.lock.unlock();}
    }
    private static MetadataObject routine(MetadataSnapshot snapshot,String catalog,String schema,String name,ObjectSubtype subtype){
        var found=snapshot.resolve(catalog,schema,ObjectKind.ROUTINE,"",name,true).stream().filter(value->value.identity().subtype()==subtype).toList();assertEquals(1,found.size());return found.getFirst();
    }
    private static String function(SessionRegistry.Session session,String qualified,String parameter,String body){return session.profile.getEngine()==Engine.POSTGRESQL?"CREATE FUNCTION "+qualified+"("+parameter+") RETURNS INTEGER LANGUAGE sql AS 'SELECT "+body+"'":"CREATE FUNCTION "+qualified+"("+parameter+") RETURNS INTEGER DETERMINISTIC RETURN "+body;}
    private static String[] nativeStampAndBody(SessionRegistry.Session session,String schema,String name)throws Exception {
        session.lock.lock();try(var query=session.connection.prepareStatement("SELECT CAST(LAST_ALTERED AS CHAR),SHA2(ROUTINE_DEFINITION,256) FROM information_schema.ROUTINES WHERE BINARY ROUTINE_SCHEMA=BINARY ? AND BINARY ROUTINE_NAME=BINARY ? AND ROUTINE_TYPE='FUNCTION'")){
            query.setQueryTimeout(5);query.setString(1,schema);query.setString(2,name);try(var rows=query.executeQuery()){assertTrue(rows.next());var values=new String[]{rows.getString(1),rows.getString(2)};assertNotNull(values[0]);assertNotNull(values[1]);assertFalse(rows.next());return values;}
        }finally{session.lock.unlock();}
    }
    private static void result(SessionRegistry.Session session,String qualified,int expected)throws Exception {
        session.lock.lock();try(var query=session.connection.createStatement()){query.setQueryTimeout(5);try(var rows=query.executeQuery("SELECT "+qualified+"(0)")){assertTrue(rows.next());assertEquals(expected,rows.getInt(1));assertFalse(rows.next());}}finally{session.lock.unlock();}
    }
    private static void exactWork(Explorer explorer,SessionRegistry.Session owner,long objects){assertEquals(objects,explorer.metadata().diagnostics(owner).orElseThrow().fetchedObjects(),"Only changed/new exact routine details may be fetched");}
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void externalBodyParameterAddAndDeleteRefreshOnlyTheirExactRoutine(String engine)throws Exception {
        try(var fixture=new EngineFixture(root,engine)){
            var owner=fixture.open();var writer=fixture.open();boolean pg=fixture.engine==Engine.POSTGRESQL;String catalog=owner.context.catalog(),schema=fixture.schema();var explorer=new Explorer(fixture.metadata);
            String changed=owner.adapter.table(catalog,schema,CHANGED),stable=owner.adapter.table(catalog,schema,STABLE),added=owner.adapter.table(catalog,schema,ADDED);
            if(!pg)external(writer,"SET timestamp=1700000000");
            external(writer,function(writer,changed,"original_arg INTEGER","11"));external(writer,function(writer,stable,"","33"));
            external(writer,pg?"CREATE PROCEDURE "+changed+"(IN procedure_arg TEXT) LANGUAGE plpgsql AS 'BEGIN NULL; END'":"CREATE PROCEDURE "+changed+"(IN procedure_arg INTEGER) SELECT procedure_arg");
            fixture.introspectionLevel(owner,IntrospectionLevel.SOURCE);
            var before=explorer.refreshContext(owner,MetadataPlatform.RefreshMode.FULL);var original=routine(before,catalog,schema,CHANGED,ObjectSubtype.FUNCTION);var stableObject=routine(before,catalog,schema,STABLE,ObjectSubtype.FUNCTION);var procedure=routine(before,catalog,schema,CHANGED,ObjectSubtype.PROCEDURE);
            assertEquals("AVAILABLE",original.properties().get("sourceAvailability"));assertFalse(original.source().isBlank());assertEquals("original_arg",original.properties().get("parameter.0.name"));
            for(var acquired:List.of(original,stableObject,procedure)){
                var id=acquired.identity();var point=new MetadataScope(id.catalog(),id.schema(),"",ObjectKind.ROUTINE,id.name(),true,id.signature(),id.subtype());var coverage=before.coverage(point).orElseThrow();
                assertEquals(MetadataState.AVAILABLE,coverage.state(),"Actual publication must preserve newly acquired point proof across provisional-to-native rules");assertTrue(coverage.complete());assertEquals(IntrospectionLevel.SOURCE,coverage.level());assertSame(acquired,before.identities().get(id.key()));
            }
            var unchanged=explorer.refreshContext(owner,MetadataPlatform.RefreshMode.INCREMENTAL);exactWork(explorer,owner,0);assertSame(original,routine(unchanged,catalog,schema,CHANGED,ObjectSubtype.FUNCTION));assertSame(stableObject,routine(unchanged,catalog,schema,STABLE,ObjectSubtype.FUNCTION));
            String[] stamp=pg?null:nativeStampAndBody(writer,schema,CHANGED);
            external(writer,"DROP FUNCTION "+changed+(pg?"(INTEGER)":""));external(writer,function(writer,changed,"original_arg INTEGER","22"));
            if(!pg){var current=nativeStampAndBody(writer,schema,CHANGED);assertEquals(stamp[0],current[0],"Native LAST_ALTERED must actually remain the same second");assertNotEquals(stamp[1],current[1]);}
            var bodyChanged=explorer.refreshContext(owner,MetadataPlatform.RefreshMode.INCREMENTAL);exactWork(explorer,owner,1);var body=routine(bodyChanged,catalog,schema,CHANGED,ObjectSubtype.FUNCTION);assertNotEquals(original.source(),body.source());assertTrue(body.source().contains("22"));assertSame(stableObject,routine(bodyChanged,catalog,schema,STABLE,ObjectSubtype.FUNCTION));assertSame(procedure,routine(bodyChanged,catalog,schema,CHANGED,ObjectSubtype.PROCEDURE));result(writer,changed,22);
            String[] constantBody=pg?null:nativeStampAndBody(writer,schema,CHANGED);
            external(writer,"DROP FUNCTION "+changed+(pg?"(INTEGER)":""));external(writer,function(writer,changed,"changed_arg BIGINT","22"));
            if(!pg){var current=nativeStampAndBody(writer,schema,CHANGED);assertEquals(stamp[0],current[0]);assertEquals(constantBody[1],current[1],"Parameter-only replacement retains the exact native body hash");}
            var parametersChanged=explorer.refreshContext(owner,MetadataPlatform.RefreshMode.INCREMENTAL);exactWork(explorer,owner,1);var parameters=routine(parametersChanged,catalog,schema,CHANGED,ObjectSubtype.FUNCTION);assertEquals("changed_arg",parameters.properties().get("parameter.0.name"));assertTrue(parameters.properties().get("parameter.0.type").toLowerCase(Locale.ROOT).contains("bigint"));assertTrue(parameters.source().contains("changed_arg"));assertSame(stableObject,routine(parametersChanged,catalog,schema,STABLE,ObjectSubtype.FUNCTION));assertSame(procedure,routine(parametersChanged,catalog,schema,CHANGED,ObjectSubtype.PROCEDURE));
            var exact=explorer.explore(owner,ExploreRequest.newBuilder().setCatalog(catalog).setSchema(schema).setKind(ObjectKind.ROUTINE).setSearch(CHANGED).setExactName(true).setIdentifier(parameters.identity().signature()).setSubtype(ObjectSubtype.FUNCTION).setIntrospectionLevel(3).build());assertEquals(1,exact.getObjectsCount());assertEquals(parameters.source(),exact.getObjects(0).getDefinition());
            external(writer,function(writer,added,"","44"));var created=explorer.refreshContext(owner,MetadataPlatform.RefreshMode.INCREMENTAL);exactWork(explorer,owner,1);assertFalse(routine(created,catalog,schema,ADDED,ObjectSubtype.FUNCTION).source().isBlank());assertSame(parameters,routine(created,catalog,schema,CHANGED,ObjectSubtype.FUNCTION));assertSame(stableObject,routine(created,catalog,schema,STABLE,ObjectSubtype.FUNCTION));
            external(writer,"DROP FUNCTION "+added+(pg?"()":""));var deleted=explorer.refreshContext(owner,MetadataPlatform.RefreshMode.INCREMENTAL);exactWork(explorer,owner,0);assertTrue(deleted.resolve(catalog,schema,ObjectKind.ROUTINE,"",ADDED,true).isEmpty());assertSame(parameters,routine(deleted,catalog,schema,CHANGED,ObjectSubtype.FUNCTION));assertSame(stableObject,routine(deleted,catalog,schema,STABLE,ObjectSubtype.FUNCTION));
            if(fixture.engine==Engine.MARIADB){
                // MariaDB PARAMETERS omits defaults. Neither the timestamp nor
                // the body hash changes here; only bounded native header proof
                // can distinguish these otherwise identical routine versions.
                MetadataObject previous=parameters;MetadataSnapshot defaultsSnapshot=deleted;
                for(int value:List.of(7,9)){
                    external(writer,"DROP FUNCTION "+changed);external(writer,function(writer,changed,"changed_arg BIGINT DEFAULT "+value,"22"));
                    var nativeEvidence=nativeStampAndBody(writer,schema,CHANGED);assertEquals(stamp[0],nativeEvidence[0]);assertEquals(constantBody[1],nativeEvidence[1]);
                    defaultsSnapshot=explorer.refreshContext(owner,MetadataPlatform.RefreshMode.INCREMENTAL);exactWork(explorer,owner,1);
                    var current=routine(defaultsSnapshot,catalog,schema,CHANGED,ObjectSubtype.FUNCTION);
                    assertEquals(Integer.toString(value),current.properties().get("parameter.0.default"));assertEquals("true",current.properties().get("parameter.0.optional"));assertNotEquals(previous.source(),current.source());
                    assertSame(stableObject,routine(defaultsSnapshot,catalog,schema,STABLE,ObjectSubtype.FUNCTION));assertSame(procedure,routine(defaultsSnapshot,catalog,schema,CHANGED,ObjectSubtype.PROCEDURE));
                    if(value==9)assertEquals("7",previous.properties().get("parameter.0.default"),"The prior immutable snapshot must retain its original default");previous=current;
                }
                var noChange=explorer.refreshContext(owner,MetadataPlatform.RefreshMode.INCREMENTAL);exactWork(explorer,owner,0);assertSame(previous,routine(noChange,catalog,schema,CHANGED,ObjectSubtype.FUNCTION));
                String sql="SELECT "+changed+"(";var resolution=new io.busystack.busydata.analysis.language.ResolutionContext(catalog,schema,owner.context.searchPath(),true,noChange.revision(),noChange.configurationRevision(),noChange.rules(),noChange);
                var information=fixture.analysis.analyze(AnalysisRequest.newBuilder().setEngine(fixture.engine).setOperation(AnalysisOperation.PARAMETER_INFORMATION).setSql(sql).setCaretUtf16(sql.length()).build(),owner.context.lexical(),resolution).getParameterInformation();
                assertEquals("available",information.getAvailability());assertEquals(1,information.getOverloadsCount());assertEquals("9",information.getOverloads(0).getParameters(0).getDefaultExpression());
                writer.lock.lock();try(var query=writer.connection.createStatement()){query.setQueryTimeout(5);try(var rows=query.executeQuery("SELECT "+changed+"()")){assertTrue(rows.next());assertEquals(22,rows.getInt(1));assertFalse(rows.next());}}finally{writer.lock.unlock();}
            }
        }
    }
}
