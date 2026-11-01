package io.busystack.busydata;

import io.busystack.busydata.adapters.JdbcAdapter;
import io.busystack.busydata.metadata.NativeStructureReader;
import io.busystack.busydata.protocol.OpenRequest;
import io.busystack.busydata.rpc.WorkbenchFailure;
import java.lang.reflect.*;
import java.nio.file.Path;
import java.sql.*;
import java.util.concurrent.atomic.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

/** Real pinned-driver category and native-owner parity. */
class PgTemporaryCategoryIT {
    @TempDir Path root;
    private static final class Counter {
        final AtomicInteger statements=new AtomicInteger(),tableReads=new AtomicInteger();
        final AtomicReference<String[]> categories=new AtomicReference<>();
        Connection connect(JdbcAdapter adapter,OpenRequest request,Integer port)throws Exception {
            var actual=adapter.connect(request,port);
            return (Connection)Proxy.newProxyInstance(Connection.class.getClassLoader(),new Class[]{Connection.class},(proxy,method,args)->{
                if(method.getName().equals("prepareStatement")||method.getName().equals("createStatement"))statements.incrementAndGet();
                Object value=invoke(actual,method,args);
                if(method.getName().equals("getMetaData")&&value instanceof DatabaseMetaData metadata)
                    return Proxy.newProxyInstance(DatabaseMetaData.class.getClassLoader(),new Class[]{DatabaseMetaData.class},(selected,operation,parameters)->{
                        if(operation.getName().equals("getTables")){
                            tableReads.incrementAndGet();var requested=(String[])parameters[3];categories.set(requested==null?null:requested.clone());
                        }
                        return invoke(metadata,operation,parameters);
                    });
                return value;
            });
        }
        void reset(){statements.set(0);tableReads.set(0);categories.set(null);}
    }
    private static Object invoke(Object target,Method method,Object[] args)throws Throwable {
        try{return method.invoke(target,args);}catch(InvocationTargetException error){throw error.getCause();}
    }
    @Test void ownQuotedTemporaryBaseUsesThePinnedDriversTemporaryCategory()throws Exception {
        var counter=new Counter();
        try(var fixture=new EngineFixture(root,"POSTGRESQL",counter::connect)) {
            var owner=fixture.open();String name="MiX_ed%Temp";
            fixture.execute(owner,"CREATE TEMPORARY TABLE "+owner.adapter.quote(name)+"(id INTEGER PRIMARY KEY,n INTEGER NOT NULL DEFAULT 7)");
            String schema=owner.context.temporarySchema();assertFalse(schema.isEmpty());counter.reset();
            owner.lock.lock();try {
                var structure=NativeStructureReader.inspect(owner,"busydata",schema,name);
                assertEquals(2,structure.columns().size());assertEquals("AVAILABLE",structure.nativeGenerationAvailability());
                assertEquals(1,counter.tableReads.get());assertArrayEquals(new String[]{"TEMPORARY TABLE"},counter.categories.get());
                assertTrue(structure.columns().stream().allMatch(column->column.getSchema().equals(schema)&&column.getTable().equals(name)));
            }finally{owner.lock.unlock();}
        }
    }
    @Test void ownedTemporaryViewNeverPassesTheBaseTableCheck()throws Exception {
        var counter=new Counter();
        try(var fixture=new EngineFixture(root,"POSTGRESQL",counter::connect)) {
            var owner=fixture.open();
            fixture.execute(owner,"CREATE TEMPORARY TABLE category_rows(id INTEGER PRIMARY KEY); CREATE TEMPORARY VIEW category_view AS SELECT id FROM category_rows");
            counter.reset();owner.lock.lock();try {
                assertThrows(IllegalArgumentException.class,()->NativeStructureReader.inspect(owner,"busydata",owner.context.temporarySchema(),"category_view"));
                assertEquals(1,counter.tableReads.get());assertArrayEquals(new String[]{"TEMPORARY TABLE"},counter.categories.get());
            }finally{owner.lock.unlock();}
        }
    }
    @Test void foreignTemporaryNamespaceIsRejectedBeforeAnyJdbcRead()throws Exception {
        var counter=new Counter();
        try(var fixture=new EngineFixture(root,"POSTGRESQL",counter::connect)) {
            var owner=fixture.open();var other=fixture.open();
            fixture.execute(owner,"CREATE TEMPORARY TABLE category_rows(id INTEGER PRIMARY KEY)");
            fixture.execute(other,"CREATE TEMPORARY TABLE category_rows(id INTEGER PRIMARY KEY)");
            String foreign=other.context.temporarySchema();assertNotEquals(owner.context.temporarySchema(),foreign);counter.reset();
            owner.lock.lock();try {
                var rejected=assertThrows(WorkbenchFailure.class,()->NativeStructureReader.inspect(owner,"busydata",foreign,"category_rows"));
                assertEquals(WorkbenchFailure.Reason.INVALID_OWNER,rejected.reason());
                assertEquals(0,counter.statements.get());assertEquals(0,counter.tableReads.get());
            }finally{owner.lock.unlock();}
        }
    }
    @Test void temporaryPartitionedShapeRemainsReadOnlyAndDoesNotInventAFilenode()throws Exception {
        var counter=new Counter();
        try(var fixture=new EngineFixture(root,"POSTGRESQL",counter::connect)) {
            var owner=fixture.open();
            fixture.execute(owner,"CREATE TEMPORARY TABLE category_partition(id INTEGER,n INTEGER) PARTITION BY RANGE(id)");
            counter.reset();owner.lock.lock();try {
                String schema=owner.context.temporarySchema();
                assertThrows(IllegalArgumentException.class,()->NativeStructureReader.inspect(owner,"busydata",schema,"category_partition",true));
                var structure=NativeStructureReader.inspect(owner,"busydata",schema,"category_partition",false);
                assertEquals(2,structure.columns().size());assertEquals("UNAVAILABLE",structure.nativeGenerationAvailability());assertTrue(structure.nativeGeneration().isEmpty());
                assertEquals(2,counter.tableReads.get());assertNull(counter.categories.get(),"Read-only structural lookup requests native categories without changing editability");
            }finally{owner.lock.unlock();}
        }
    }
}
