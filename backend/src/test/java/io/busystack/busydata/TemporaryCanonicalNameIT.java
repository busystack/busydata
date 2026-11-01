package io.busystack.busydata;

import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import java.io.StringReader;
import java.lang.reflect.*;
import java.nio.file.Path;
import java.sql.*;
import java.util.*;
import java.util.concurrent.atomic.*;
import java.util.stream.Stream;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.*;
import static org.junit.jupiter.api.Assertions.*;

/** Exact names follow native CREATE headers rather than the first SHOW alias. */
class TemporaryCanonicalNameIT {
    @TempDir Path root;
    static Stream<Arguments> cases(){return Stream.of("MYSQL","MARIADB").flatMap(engine->Stream.of(Arguments.of(engine,false),Arguments.of(engine,true)));}
    private static Object invoke(Object target,Method method,Object[] arguments)throws Throwable{try{return method.invoke(target,arguments);}catch(InvocationTargetException failure){throw failure.getCause();}}
    @ParameterizedTest @MethodSource("cases")
    void firstReferenceAndPresentationLevelDoNotChooseTheNativeName(String engine,boolean ansi)throws Exception{
        try(var fixture=new EngineFixture(root,engine,container->container.withCommand("--lower-case-table-names=1","--character-set-server=utf8mb4","--collation-server=utf8mb4_unicode_ci"))){
            var owner=fixture.open();owner.lock.lock();try{
                if(ansi)try(var mode=owner.connection.prepareStatement("SET SESSION sql_mode=?")){mode.setString(1,"ANSI_QUOTES");mode.execute();}
                try(var setup=owner.connection.createStatement()){setup.execute("CREATE PROCEDURE make_canonical_temp() BEGIN CREATE TEMPORARY TABLE `MiXeD`(id INTEGER PRIMARY KEY,n INTEGER); INSERT INTO `MiXeD` VALUES(1,7); END");setup.execute("CALL make_canonical_temp()");}owner.refresh();owner.advanceRevision();
            }finally{owner.lock.unlock();}
            String identity=null;int jobs=0;var platform=fixture.metadata.metadataPlatform();
            for(var level:List.of(IntrospectionLevel.NAMES,IntrospectionLevel.STRUCTURE)){
                fixture.introspectionLevel(owner,level);String first=level==IntrospectionLevel.NAMES?"MIXED":"MiXeD";
                var selected=fixture.execute(owner,"SELECT id,n FROM "+owner.adapter.table("busydata","busydata",first));jobs++;var result=fixture.results.get(selected.info().getResults(0).getResultId());assertEquals("7",result.read(0).getValues(1).getSignedInteger());assertFalse(result.metadataProof().capturedStructure());
                var captured=platform.capture(owner);var found=captured.resolve("busydata","busydata",ObjectKind.TABLE,"",first,true);assertEquals(1,found.size());var table=found.getFirst();assertEquals("mixed",table.identity().name());assertEquals("mixed",table.displayName());assertEquals("AVAILABLE",table.properties().get("nativeNameAvailability"));assertEquals("OWNED_NATIVE_CREATE_HEADER",table.properties().get("nativeNameProvenance"));assertTrue(table.source().isEmpty(),"Names/structure retains no full source document");
                if(identity==null)identity=table.identity().key();else assertEquals(identity,table.identity().key(),"Configuration/first spelling cannot change one physical temp identity");
                var columns=new MetadataScope("busydata","busydata","mixed",ObjectKind.COLUMN);assertEquals(level==IntrospectionLevel.STRUCTURE,captured.complete(columns,IntrospectionLevel.STRUCTURE));
                var later=fixture.execute(owner,"SELECT id,n FROM `mixed`");jobs++;assertEquals(JobState.COMPLETED,later.state);var current=platform.capture(owner);assertEquals(identity,current.resolve("busydata","busydata",ObjectKind.TABLE,"","MIXED",true).getFirst().identity().key());assertEquals("mixed",table.identity().name(),"Captured names remain immutable");assertEquals(1,current.identities().values().stream().filter(value->value.identity().kind()==ObjectKind.TABLE&&value.identity().sessionOwner().equals(owner.id)).count());
            }
            assertEquals(jobs,fixture.jobs.list(owner.id).size());assertEquals(4,jobs);assertTrue(platform.publishedSnapshot(owner).identities().values().stream().noneMatch(value->!value.identity().sessionOwner().isEmpty()));
        }
    }
    @ParameterizedTest @ValueSource(strings={"MYSQL","MARIADB"})
    void unavailableCanonicalHeaderRetiresACachedPermanentClaim(String engine)throws Exception{
        var first=new AtomicBoolean();var malformed=new AtomicBoolean();var altered=new AtomicInteger();
        try(var fixture=new EngineFixture(root,engine,(adapter,request,port)->{
            var nativeConnection=adapter.connect(request,port);boolean owner=!request.getProfile().getReadOnly()&&first.compareAndSet(false,true);
            return (Connection)Proxy.newProxyInstance(Connection.class.getClassLoader(),new Class[]{Connection.class},(proxy,method,args)->{
                var value=invoke(nativeConnection,method,args);
                if(owner&&method.getName().equals("prepareStatement")&&args[0] instanceof String sql&&sql.startsWith("SHOW CREATE TABLE ")){
                    var statement=(PreparedStatement)value;return Proxy.newProxyInstance(PreparedStatement.class.getClassLoader(),new Class[]{PreparedStatement.class},(prepared,operation,parameters)->{
                        var result=invoke(statement,operation,parameters);if(malformed.get()&&operation.getName().equals("executeQuery")&&result instanceof ResultSet rows)return Proxy.newProxyInstance(ResultSet.class.getClassLoader(),new Class[]{ResultSet.class},(wrapped,read,arguments)->{
                            if(read.getName().equals("getCharacterStream")&&Integer.valueOf(2).equals(arguments[0])){altered.incrementAndGet();return new StringReader("CREATE TEMPORARY TABLE `"+"x".repeat(3000));}return invoke(rows,read,arguments);
                        });return result;
                    });
                }return value;
            });
        },container->container.withCommand("--lower-case-table-names=1","--character-set-server=utf8mb4","--collation-server=utf8mb4_unicode_ci"))){
            var owner=fixture.open();var other=fixture.open();fixture.introspectionLevel(owner,IntrospectionLevel.STRUCTURE);
            owner.lock.lock();try(var setup=owner.connection.createStatement()){setup.execute("CREATE TABLE `MiXeD`(id INTEGER PRIMARY KEY,n INTEGER)");setup.execute("INSERT INTO `MiXeD` VALUES(1,2)");}finally{owner.lock.unlock();}
            fixture.warm(owner,"mixed");var platform=fixture.metadata.metadataPlatform();var old=platform.capture(owner);var scope=new MetadataScope("busydata","busydata","mixed",ObjectKind.COLUMN);assertTrue(old.complete(scope,IntrospectionLevel.STRUCTURE));
            owner.lock.lock();try(var setup=owner.connection.createStatement()){setup.execute("CREATE TEMPORARY TABLE `MiXeD`(id INTEGER PRIMARY KEY,n INTEGER)");setup.execute("INSERT INTO `MiXeD` VALUES(1,7)");owner.refresh();owner.advanceRevision();}finally{owner.lock.unlock();}
            malformed.set(true);var selected=fixture.execute(owner,"SELECT id,n FROM `MIXED`");var result=fixture.results.get(selected.info().getResults(0).getResultId());assertEquals("7",result.read(0).getValues(1).getSignedInteger());assertFalse(result.metadataProof().capturedStructure());assertTrue(altered.get()>0);
            var current=platform.capture(owner);assertEquals(MetadataState.UNKNOWN,current.sessionResolution().state());assertFalse(current.complete(scope,IntrospectionLevel.STRUCTURE));assertFalse(current.relationResolutionAvailable("busydata","busydata","mixed",owner.id));assertTrue(old.complete(scope,IntrospectionLevel.STRUCTURE));assertTrue(platform.capture(other).complete(scope,IntrospectionLevel.STRUCTURE),"Unknown header evidence is physical-session scoped");assertEquals(1,fixture.jobs.list(owner.id).size());
        }
    }
}
