package io.busystack.busydata;

import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import java.lang.reflect.*;
import java.nio.file.Path;
import java.sql.*;
import java.util.*;
import java.util.concurrent.atomic.AtomicBoolean;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

/** Checks actual pinned driver row storage for owned multirow native metadata. */
class OwnedTemporaryStreamingIT {
    @TempDir Path root;
    private static Object invoke(Object target,Method method,Object[] arguments)throws Throwable{try{return method.invoke(target,arguments);}catch(InvocationTargetException failure){throw failure.getCause();}}
    @ParameterizedTest @ValueSource(strings={"MYSQL","MARIADB"})
    void fullColumnMetadataIsStreamedBeforeIncrementalAdmission(String engine)throws Exception {
        var first=new AtomicBoolean();var streamed=new AtomicBoolean();var independentCorpus=new AtomicBoolean();
        try(var fixture=new EngineFixture(root,engine,(adapter,request,port)->{
            var physical=adapter.connect(request,port);boolean owner=!request.getProfile().getReadOnly()&&first.compareAndSet(false,true);
            return (Connection)Proxy.newProxyInstance(Connection.class.getClassLoader(),new Class[]{Connection.class},(proxy,method,args)->{
                if(method.getName().equals("prepareStatement")&&args[0] instanceof String sql&&sql.startsWith("SELECT j.ord,j.ch")){
                    assertFalse(owner,"The physical command connection must never acquire the full native character corpus");assertTrue(request.getProfile().getReadOnly(),"Full identifier evidence uses the independent metadata connection policy");independentCorpus.set(true);
                }
                Object result=invoke(physical,method,args);
                if(owner&&method.getName().equals("prepareStatement")&&args[0] instanceof String sql&&sql.startsWith("SHOW FULL COLUMNS FROM")){
                    var prepared=(PreparedStatement)result;
                    return Proxy.newProxyInstance(PreparedStatement.class.getClassLoader(),new Class[]{PreparedStatement.class},(statement,operation,parameters)->{
                        Object value=invoke(prepared,operation,parameters);
                        if(operation.getName().equals("executeQuery")&&value instanceof ResultSet rows){
                            assertEquals(ResultSet.TYPE_FORWARD_ONLY,rows.getType());
                            if(engine.equals("MYSQL")){
                                assertEquals(Integer.MIN_VALUE,prepared.getFetchSize());
                                assertInstanceOf(com.mysql.cj.protocol.a.result.ResultsetRowsStreaming.class,rows.unwrap(com.mysql.cj.jdbc.result.ResultSetInternalMethods.class).getRows());
                            }else{
                                assertEquals(1,prepared.getFetchSize());assertInstanceOf(org.mariadb.jdbc.client.result.StreamingResult.class,rows);
                            }
                            streamed.set(true);
                        }return value;
                    });
                }return result;
            });
        })){
            var owner=fixture.open();fixture.introspectionLevel(owner,IntrospectionLevel.STRUCTURE);var initial=fixture.metadata.metadataPlatform().publishedSnapshot(owner);assertTrue(initial.identities().isEmpty());assertFalse(initial.rules().complete(),"This regression begins before any durable introspection or native map acquisition");var declarations=new ArrayList<String>();
            for(int column=0;column<32;column++)declarations.add("c"+column+" TEXT COMMENT '"+"x".repeat(1024)+"'");
            fixture.execute(owner,"CREATE TEMPORARY TABLE streaming_columns("+String.join(",",declarations)+")");
            assertTrue(streamed.get(),()->"The owned native SHOW must use the pinned driver's bounded row storage; rules="+fixture.metadata.metadataPlatform().publishedSnapshot(owner).rules()+"; resolution="+fixture.metadata.metadataPlatform().capture(owner).sessionResolution().state());
            assertTrue(independentCorpus.get(),"A cold owned operation must obtain verified native comparison evidence independently");assertFalse(initial.rules().complete(),"Captured old metadata remains immutable after bootstrap");
            var snapshot=fixture.metadata.metadataPlatform().capture(owner);assertTrue(snapshot.complete(new MetadataScope("busydata","busydata","streaming_columns",ObjectKind.COLUMN),IntrospectionLevel.STRUCTURE));assertEquals(32,snapshot.namespace("busydata","busydata",ObjectKind.COLUMN,"streaming_columns").size());assertEquals(TransactionState.IDLE,owner.state);
        }
    }
}
