package io.busystack.busydata;

import io.busystack.busydata.adapters.JdbcAdapter;
import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.OwnedTemporarySource;
import java.lang.reflect.*;
import java.nio.file.Path;
import java.sql.*;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.*;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

/** Native preflight refuses oversized remarks before the pinned driver reads them. */
class PgJdbcMetadataBudgetIT {
    @TempDir Path root;
    private static final class Counter {
        final AtomicInteger columns=new AtomicInteger(),tables=new AtomicInteger();
        Connection connect(JdbcAdapter adapter,OpenRequest request,Integer port)throws Exception {
            var actual=adapter.connect(request,port);
            return (Connection)Proxy.newProxyInstance(Connection.class.getClassLoader(),new Class[]{Connection.class},(proxy,method,args)->{
                Object value=invoke(actual,method,args);
                if(method.getName().equals("getMetaData")&&value instanceof DatabaseMetaData metadata)
                    return Proxy.newProxyInstance(DatabaseMetaData.class.getClassLoader(),new Class[]{DatabaseMetaData.class},(selected,operation,parameters)->{
                        if(operation.getName().equals("getColumns"))columns.incrementAndGet();
                        if(operation.getName().equals("getTables"))tables.incrementAndGet();
                        return invoke(metadata,operation,parameters);
                    });
                return value;
            });
        }
    }
    private static Object invoke(Object target,Method method,Object[] args)throws Throwable {
        try{return method.invoke(target,args);}catch(InvocationTargetException error){throw error.getCause();}
    }
    @ParameterizedTest @ValueSource(strings={"column_max","column_aggregate","table_max","boundary"})
    void nativeScalarResourceEvidencePrecedesEagerDriverAllocation(String mode)throws Exception {
        var counter=new Counter();
        try(var fixture=new EngineFixture(root,"POSTGRESQL",counter::connect)) {
            var owner=fixture.open();owner.lock.lock();try {
                int count=mode.equals("column_aggregate")?128:1;
                var declarations=new java.util.ArrayList<String>();for(int n=0;n<count;n++)declarations.add(owner.adapter.quote("n"+n)+" INTEGER");
                try(var statement=owner.connection.createStatement()) {
                    statement.execute("CREATE TEMPORARY TABLE resource_rows("+String.join(",",declarations)+")");owner.refresh();
                    String target=owner.adapter.table("busydata",owner.context.temporarySchema(),"resource_rows");
                    if(mode.equals("table_max")||mode.equals("boundary"))
                        statement.execute("COMMENT ON TABLE "+target+" IS '"+"x".repeat(mode.equals("boundary")?65_536:65_537)+"'");
                    if(mode.equals("column_max"))statement.execute("COMMENT ON COLUMN "+target+".n0 IS '"+"λ".repeat(32_769)+"'");
                    if(mode.equals("column_aggregate"))for(int n=0;n<count;n++)statement.execute("COMMENT ON COLUMN "+target+"."+owner.adapter.quote("n"+n)+" IS '"+"x".repeat(40_000)+"'");
                }
                counter.columns.set(0);counter.tables.set(0);int socket=owner.connection.getNetworkTimeout();var allocated=new AtomicLong();
                if(mode.equals("boundary")) {
                    var structure=OwnedTemporarySource.operation(owner,System.nanoTime()+TimeUnit.SECONDS.toNanos(10),null,check->{
                        check.run();return NativeStructureReader.inspect(owner,"busydata",owner.context.temporarySchema(),"resource_rows",true,allocated::addAndGet);
                    });
                    assertEquals(1,structure.columns().size());assertEquals(1,counter.tables.get());assertEquals(1,counter.columns.get());assertTrue(allocated.get()>65_536);
                }else {
                    var limited=assertThrows(MetadataLimit.class,()->OwnedTemporarySource.operation(owner,System.nanoTime()+TimeUnit.SECONDS.toNanos(10),null,check->{
                        check.run();
                        if(mode.equals("table_max"))return NativeStructureReader.inspect(owner,"busydata",owner.context.temporarySchema(),"resource_rows",true,allocated::addAndGet);
                        JdbcMetadataPatterns.columns(owner,"busydata",owner.context.temporarySchema(),"resource_rows",allocated::addAndGet);return null;
                    }));
                    assertEquals(MetadataState.LIMITED,limited.state());assertEquals(0,counter.columns.get(),"The real driver's eager column tuple reader must never start");
                    assertEquals(0,counter.tables.get(),"A too-large table comment must be refused before eager getTables");
                }
                assertEquals(socket,owner.connection.getNetworkTimeout());assertFalse(owner.physicalEnded());
            }finally{owner.lock.unlock();}
        }
    }
}
