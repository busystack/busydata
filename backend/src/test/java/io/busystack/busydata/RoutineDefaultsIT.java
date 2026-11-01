package io.busystack.busydata;

import io.busystack.busydata.analysis.language.*;
import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.*;
import io.busystack.busydata.sessions.SessionRegistry;
import java.lang.reflect.*;
import java.nio.file.Path;
import java.sql.*;
import java.util.*;
import java.util.concurrent.atomic.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

/** Native invocation and the captured parameter popup must agree. Routine
 * bodies are fixtures, never parsed as the source of parameter facts. */
class RoutineDefaultsIT {
    @TempDir Path root;
    private static final String NAME="routine_default_fixture";
    private static void execute(SessionRegistry.Session session,String sql)throws Exception {
        session.lock.lock();try(var query=session.connection.createStatement()){query.setQueryTimeout(10);query.execute(sql);session.refresh();}finally{session.lock.unlock();}
    }
    private static Connection observed(Connection connection,AtomicBoolean observing,AtomicInteger sourceReads){
        return (Connection)Proxy.newProxyInstance(Connection.class.getClassLoader(),new Class[]{Connection.class},(p,m,a)->{
            if(observing.get()&&m.getName().equals("prepareStatement")&&a!=null&&a.length>0&&a[0] instanceof String sql&&(sql.startsWith("SHOW CREATE FUNCTION ")||sql.startsWith("SHOW CREATE PROCEDURE ")))sourceReads.incrementAndGet();
            try{return m.invoke(connection,a);}catch(InvocationTargetException failure){throw failure.getCause();}
        });
    }
    private static MetadataObject exact(MetadataSnapshot snapshot,SessionRegistry.Session session,ObjectSubtype kind){
        var matches=snapshot.resolve(session.context.catalog(),session.context.schema(),ObjectKind.ROUTINE,"",NAME,true).stream().filter(value->value.identity().subtype()==kind).toList();assertEquals(1,matches.size());return matches.getFirst();
    }
    private static ParameterInformation popup(EngineFixture fixture,SessionRegistry.Session session,MetadataSnapshot snapshot,String sql){
        var context=new ResolutionContext(session.context.catalog(),session.context.schema(),session.context.searchPath(),true,snapshot.revision(),snapshot.configurationRevision(),snapshot.rules(),snapshot);
        return fixture.analysis.analyze(AnalysisRequest.newBuilder().setEngine(fixture.engine).setOperation(AnalysisOperation.PARAMETER_INFORMATION).setSql(sql).setCaretUtf16(sql.length()).build(),session.context.lexical(),context).getParameterInformation();
    }
    private static void assertParameter(RoutineParameter parameter,String name,boolean optional,String expression){assertEquals(name,parameter.getName());assertEquals("IN",parameter.getMode());assertEquals(optional,parameter.getOptional());assertEquals(expression,parameter.getDefaultExpression());}
    private static void ambiguous(SessionRegistry.Session session,String sql)throws Exception {
        session.lock.lock();try(var query=session.connection.createStatement()){query.setQueryTimeout(5);assertEquals("42725",assertThrows(SQLException.class,()->query.execute(sql)).getSQLState(),"The native mixed-kind default call must actually be ambiguous");}finally{session.lock.unlock();}
    }

    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void nativeFunctionAndProcedureDefaultsReachTheActualCapturedPopup(String engine)throws Exception {
        var observing=new AtomicBoolean();var sourceReads=new AtomicInteger();
        try(var fixture=new EngineFixture(root,engine,(adapter,request,port)->observed(adapter.connect(request,port),observing,sourceReads))){
            var session=fixture.open();boolean pg=fixture.engine==Engine.POSTGRESQL,defaults=fixture.engine!=Engine.MYSQL;
            String qualified=session.adapter.table(session.context.catalog(),fixture.schema(),NAME);
            String parameters="required_arg INTEGER, optional_arg INTEGER"+(defaults?" DEFAULT 7":"")+", nullable_arg "+(pg?"TEXT":"VARCHAR(30)")+(defaults?" DEFAULT NULL":"");
            execute(session,"CREATE FUNCTION "+qualified+"("+parameters+") RETURNS INTEGER "+(pg?"LANGUAGE sql AS 'SELECT required_arg + optional_arg'":"DETERMINISTIC RETURN required_arg + optional_arg"));
            if(pg){session.lock.lock();try(var query=session.connection.createStatement();var rows=query.executeQuery("SELECT "+qualified+"(3)")){assertTrue(rows.next());assertEquals(10,rows.getInt(1));assertFalse(rows.next());}finally{session.lock.unlock();}}
            String procedureParameters="IN required_arg INTEGER, IN optional_text "+(pg?"TEXT":"VARCHAR(30)")+(defaults?" DEFAULT 'a,b'":"");
            execute(session,"CREATE PROCEDURE "+qualified+"("+procedureParameters+") "+(pg?"LANGUAGE plpgsql AS 'BEGIN NULL; END'":"SELECT required_arg, optional_text"));
            if(pg){ambiguous(session,"SELECT "+qualified+"(3)");ambiguous(session,"CALL "+qualified+"(3)");}
            session.lock.lock();try(var query=session.connection.createStatement()){
                query.setQueryTimeout(5);try(var rows=query.executeQuery("SELECT "+qualified+(pg?"(3,7,NULL::text)":defaults?"(3)":"(3,7,NULL)"))){assertTrue(rows.next());assertEquals(10,rows.getInt(1));assertFalse(rows.next());}
                boolean result=query.execute("CALL "+qualified+(pg?"(3,'a,b'::text)":defaults?"(3)":"(3,'a,b')"));
                if(!pg){assertTrue(result);try(var rows=query.getResultSet()){assertTrue(rows.next());assertEquals(3,rows.getInt(1));assertEquals("a,b",rows.getString(2));assertFalse(rows.next());}}
            }finally{session.lock.unlock();}
            fixture.introspectionLevel(session,IntrospectionLevel.STRUCTURE);observing.set(true);
            var snapshot=new Explorer(fixture.metadata).refreshContext(session,MetadataPlatform.RefreshMode.FULL);
            observing.set(false);assertEquals(fixture.engine==Engine.MARIADB?6:0,sourceReads.get(),"MariaDB uses one initial scan, exact detail read and verification scan per routine; the other engines need no Level 2 source reads");
            var function=exact(snapshot,session,ObjectSubtype.FUNCTION);var procedure=exact(snapshot,session,ObjectSubtype.PROCEDURE);
            for(var routine:List.of(function,procedure)){assertEquals(MetadataState.AVAILABLE,routine.state());assertEquals("AVAILABLE",routine.properties().get("signatureAvailability"));assertEquals("AVAILABLE",routine.properties().get("parameterDefaultsAvailability"));assertTrue(routine.source().isEmpty(),"Level 2 cannot retain a fetched routine body");}
            if(pg)for(String sql:List.of("SELECT "+qualified+"(3","CALL "+qualified+"(3")){var collision=popup(fixture,session,snapshot,sql);assertEquals("partial-signatures",collision.getAvailability());assertEquals(1,collision.getOverloadsCount());assertTrue(collision.getOverloads(0).getParameters(1).getOptional(),"Captured default facts stay available even when call resolution is uncertain");}
            var functionInformation=popup(fixture,session,snapshot,"SELECT "+qualified+(pg?"(3,7,NULL::text":"(3, "));assertEquals("available",functionInformation.getAvailability());assertEquals(1,functionInformation.getOverloadsCount());var functionSignature=functionInformation.getOverloads(0);assertEquals(3,functionSignature.getParametersCount());
            assertParameter(functionSignature.getParameters(0),"required_arg",false,"");assertParameter(functionSignature.getParameters(1),"optional_arg",defaults,defaults?"7":"");assertParameter(functionSignature.getParameters(2),"nullable_arg",defaults,defaults?(pg?"NULL::text":"NULL"):"");
            assertEquals(function.identity().key(),functionSignature.getIdentity());
            var procedureInformation=popup(fixture,session,snapshot,"CALL "+qualified+"(3, ");assertEquals(pg?"partial-signatures":"available",procedureInformation.getAvailability());assertEquals(1,procedureInformation.getOverloadsCount());var procedureSignature=procedureInformation.getOverloads(0);assertEquals(2,procedureSignature.getParametersCount());
            assertParameter(procedureSignature.getParameters(0),"required_arg",false,"");assertParameter(procedureSignature.getParameters(1),"optional_text",defaults,defaults?(pg?"'a,b'::text":"'a,b'"):"");assertEquals(procedure.identity().key(),procedureSignature.getIdentity());
            var nativeSignature=RoutineSignatures.from(function.projection(snapshot.revision(),snapshot.configurationRevision()),fixture.engine);assertTrue(nativeSignature.complete());assertEquals(defaults?1:3,nativeSignature.minimumArguments());assertEquals(3,nativeSignature.maximumArguments());
            assertEquals(defaults,function.properties().containsKey("parameter.1.default"));assertEquals(defaults?"AVAILABLE":"ABSENT",function.properties().get("parameter.1.defaultAvailability"));
        }
    }

    @Test void postgresArrayDefaultKeepsTheEntireNativeExpressionInParameterInformation()throws Exception {
        try(var fixture=new EngineFixture(root,"POSTGRESQL")){
            var session=fixture.open();String qualified=session.adapter.table(session.context.catalog(),fixture.schema(),NAME);
            execute(session,"CREATE FUNCTION "+qualified+"(required_arg INTEGER, numbers INTEGER[] DEFAULT ARRAY[1,2], caption TEXT DEFAULT 'a,b') RETURNS INTEGER LANGUAGE sql AS 'SELECT required_arg + cardinality(numbers)'");
            fixture.introspectionLevel(session,IntrospectionLevel.STRUCTURE);var snapshot=new Explorer(fixture.metadata).refreshContext(session,MetadataPlatform.RefreshMode.FULL);
            var information=popup(fixture,session,snapshot,"SELECT "+qualified+"(1, ");assertEquals("available",information.getAvailability());assertEquals(1,information.getOverloadsCount());var parameters=information.getOverloads(0).getParametersList();assertParameter(parameters.get(1),"numbers",true,"ARRAY[1, 2]");assertParameter(parameters.get(2),"caption",true,"'a,b'::text");
            session.lock.lock();try(var query=session.connection.createStatement();var rows=query.executeQuery("SELECT "+qualified+"(1)")){assertTrue(rows.next());assertEquals(3,rows.getInt(1));assertFalse(rows.next());}finally{session.lock.unlock();}
        }
    }

    @Test void mariaOwnedArtifactDefaultsAndExpiredReadPreserveTheExactTransaction()throws Exception {
        try(var fixture=new EngineFixture(root,"MARIADB")){
            var session=fixture.open();var observer=fixture.open();String qualified=session.adapter.table(session.context.catalog(),fixture.schema(),NAME);
            execute(session,"CREATE FUNCTION "+qualified+"(required_arg INTEGER, optional_arg INTEGER DEFAULT 7) RETURNS INTEGER DETERMINISTIC RETURN required_arg + optional_arg");
            execute(session,"CREATE TABLE owned_default_marker(id INTEGER PRIMARY KEY)");
            fixture.introspectionLevel(session,IntrospectionLevel.STRUCTURE);var snapshot=new Explorer(fixture.metadata).refreshContext(session,MetadataPlatform.RefreshMode.FULL);var routine=exact(snapshot,session,ObjectSubtype.FUNCTION).projection(snapshot.revision(),snapshot.configurationRevision());
            assertThrows(IllegalStateException.class,()->NativeRoutineSource.read(session,routine,System.nanoTime()+1_000_000_000L));
            fixture.sessions.command(SessionRequest.newBuilder().setSessionId(session.id).setAction(SessionAction.BEGIN).build());
            try{
                execute(session,"INSERT INTO owned_default_marker VALUES(1)");session.lock.lock();try{
                    assertThrows(SQLTimeoutException.class,()->NativeRoutineSource.read(session,routine,0));assertFalse(session.connection.isClosed());assertFalse(session.connection.getAutoCommit());
                    var artifact=new SchemaTools(fixture.metadata.metadataPlatform()).capture(session,fixture.schema());assertTrue(artifact.getAsJsonObject("routines").has("FUNCTION:"+NAME));
                    var current=fixture.metadata.metadataPlatform().capture(session);var captured=exact(current,session,ObjectSubtype.FUNCTION);assertEquals("7",captured.properties().get("parameter.1.default"));assertEquals("AVAILABLE",captured.properties().get("signatureAvailability"));
                    try(var query=session.connection.createStatement();var rows=query.executeQuery("SELECT COUNT(*) FROM owned_default_marker")){assertTrue(rows.next());assertEquals(1,rows.getInt(1));}
                }finally{session.lock.unlock();}
                observer.lock.lock();try(var query=observer.connection.createStatement();var rows=query.executeQuery("SELECT COUNT(*) FROM owned_default_marker")){assertTrue(rows.next());assertEquals(0,rows.getInt(1));}finally{observer.lock.unlock();}
            }finally{fixture.sessions.command(SessionRequest.newBuilder().setSessionId(session.id).setAction(SessionAction.ROLLBACK).build());}
            session.lock.lock();try(var query=session.connection.createStatement();var rows=query.executeQuery("SELECT COUNT(*) FROM owned_default_marker")){assertTrue(rows.next());assertEquals(0,rows.getInt(1));}finally{session.lock.unlock();}
        }
    }
}
