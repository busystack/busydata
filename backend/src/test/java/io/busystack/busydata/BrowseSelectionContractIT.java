package io.busystack.busydata;

import io.busystack.busydata.adapters.JdbcAdapter;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.rpc.WorkbenchFailure;
import io.busystack.busydata.schema.*;
import java.lang.reflect.*;
import java.nio.file.Path;
import java.sql.*;
import java.util.*;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

/** Existing wire selection fields are mandatory before JDBC. */
class BrowseSelectionContractIT {
    @TempDir Path root;
    private static final class Reads {
        final AtomicInteger jdbc=new AtomicInteger();
        Connection connect(JdbcAdapter adapter,OpenRequest request,Integer port)throws Exception {
            var actual=adapter.connect(request,port);
            return (Connection)Proxy.newProxyInstance(Connection.class.getClassLoader(),new Class[]{Connection.class},(proxy,method,args)->{
                if(Set.of("prepareStatement","createStatement","getMetaData").contains(method.getName()))jdbc.incrementAndGet();
                try{return method.invoke(actual,args);}catch(InvocationTargetException error){throw error.getCause();}
            });
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void missingOrHalfPopulatedSelectionIsMalformedBeforeNativeInspection(String engine)throws Exception {
        var reads=new Reads();
        try(var fixture=new EngineFixture(root,engine,reads::connect)){
            var owner=fixture.open();var explorer=new Explorer(fixture.metadata);
            var base=BrowseRequest.newBuilder().setSessionId(owner.id).setExecutionId(UUID.randomUUID().toString()).setDocumentId("missing-selection-proof").setCatalog("busydata").setSchema(fixture.schema()).setTable("untrusted_name_only").setRowLimit(10).build();
            var variants=List.of(base,base.toBuilder().setMetadataObjectIdentity("untrusted-identity-without-revision").build(),base.toBuilder().setMetadataSnapshotRevision(1).build());
            int jobs=fixture.jobs.list("").size();reads.jdbc.set(0);
            for(var request:variants){
                var review=assertThrows(WorkbenchFailure.class,()->TableBrowse.review(owner,request,explorer,fixture.safety));
                assertEquals(WorkbenchFailure.Reason.MALFORMED_REQUEST,review.reason());
                var submit=assertThrows(WorkbenchFailure.class,()->TableBrowse.submit(owner,request.toBuilder().setApprovalToken("forged").build(),explorer,fixture.safety,fixture.jobs));
                assertEquals(WorkbenchFailure.Reason.MALFORMED_REQUEST,submit.reason());
            }
            assertEquals(0,reads.jdbc.get(),"Missing authority must fail before metadata/native SQL, even when names look executable");
            assertEquals(jobs,fixture.jobs.list("").size());
        }
    }
}
