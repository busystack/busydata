package io.busystack.busydata;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.rpc.WorkbenchFailure;
import io.busystack.busydata.schema.*;
import java.lang.reflect.*;
import java.nio.file.Path;
import java.sql.*;
import java.util.concurrent.atomic.*;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

class TemporarySourceFaultIT {
    @TempDir Path root;
    @ParameterizedTest @ValueSource(strings={"MYSQL","MARIADB"})
    void failedNetworkRestorationQuarantinesTheOwnerAndReturnsTypedUnknown(String engine)throws Exception {
        var first=new AtomicBoolean();var failRestore=new AtomicBoolean();var writes=new AtomicInteger();
        try(var f=new EngineFixture(root,engine,(adapter,request,port)->{
            var physical=adapter.connect(request,port);boolean owner=!request.getProfile().getReadOnly()&&first.compareAndSet(false,true);
            return (Connection)Proxy.newProxyInstance(Connection.class.getClassLoader(),new Class[]{Connection.class},(proxy,method,args)->{
                if(owner&&failRestore.get()&&method.getName().equals("setNetworkTimeout")&&writes.incrementAndGet()==2)throw new SQLException("fixture private restore detail","HY000");
                try{return method.invoke(physical,args);}catch(InvocationTargetException failure){throw failure.getCause();}
            });
        })){
            var owner=f.open();var other=f.open();var explorer=new Explorer(f.metadata);var platform=explorer.metadata();var tools=new SchemaTools(platform);
            try(var statement=owner.connection.createStatement()){statement.execute("CREATE TABLE fault_shadow(persistent_a INTEGER)");}owner.refresh();owner.advanceRevision();explorer.refreshContext(owner,io.busystack.busydata.metadata.MetadataPlatform.RefreshMode.FULL);
            var request=SchemaToolRequest.newBuilder().setAction(SchemaToolAction.OBJECT_DEFINITION).setCatalog("busydata").setSchema("busydata").setTable("fault_shadow").setKind(ObjectKind.TABLE).build();assertTrue(tools.run(other,request).getDefinition().contains("persistent_a"));
            owner.lock.lock();try{try(var statement=owner.connection.createStatement()){statement.execute("CREATE TEMPORARY TABLE fault_shadow(temporary_b INTEGER)");}owner.refresh();owner.advanceRevision();explorer.refreshTemporary(owner,"busydata","busydata","fault_shadow");}finally{owner.lock.unlock();}
            assertEquals(1,platform.sessionOverlayCount());var committed=platform.publishedSnapshot(owner);failRestore.set(true);
            var failure=assertThrows(WorkbenchFailure.class,()->tools.run(owner,request));assertEquals(WorkbenchFailure.Reason.TRANSACTION_UNKNOWN,failure.reason());assertNotNull(failure.getCause());assertTrue(failure.getCause().getMessage().contains("fixture private restore detail"));assertFalse(failure.asStatusRuntimeException().getStatus().getDescription().contains("private restore"));
            assertEquals(2,writes.get());assertEquals(TransactionState.UNKNOWN_TRANSACTION,owner.state);assertTrue(owner.physicalEnded());assertEquals(0,platform.sessionOverlayCount(),"Physical quarantine removes the owned overlay without a later capture");assertSame(committed,platform.snapshot(owner.profile.getId()));assertTrue(tools.run(other,request).getDefinition().contains("persistent_a"));assertEquals(TransactionState.IDLE,other.state);assertTrue(f.jobs.list("").isEmpty());
        }
    }
}
