package io.busystack.busydata;

import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.rpc.WorkbenchFailure;
import io.busystack.busydata.schema.*;
import io.busystack.busydata.sessions.SessionRegistry;
import java.lang.reflect.*;
import java.nio.file.Path;
import java.sql.*;
import java.util.*;
import java.util.concurrent.atomic.*;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

/** Real engine policy ordering: excluded retained targets do no JDBC work. */
class InspectionPolicyIT {
    private static final String TABLE="policy_rows";
    @TempDir Path root;
    private static final class Counter {
        final AtomicBoolean armed=new AtomicBoolean();final AtomicInteger jdbc=new AtomicInteger(),opens=new AtomicInteger();
        SessionRegistry.ConnectionOpener opener(){return(adapter,request,port)->{
            if(armed.get())opens.incrementAndGet();var physical=adapter.connect(request,port);
            return(Connection)Proxy.newProxyInstance(Connection.class.getClassLoader(),new Class[]{Connection.class},(proxy,method,args)->{
                if(armed.get()&&Set.of("prepareStatement","prepareCall","createStatement","getMetaData").contains(method.getName()))jdbc.incrementAndGet();
                try{return method.invoke(physical,args);}catch(InvocationTargetException failure){throw failure.getCause();}
            });
        };}
    }
    private static void seed(EngineFixture fixture,SessionRegistry.Session owner,String spelling)throws Exception{
        String table=owner.adapter.table("busydata",fixture.schema(),spelling);
        owner.lock.lock();try(var statement=owner.connection.createStatement()){
            statement.execute("CREATE TABLE "+table+"(id INTEGER PRIMARY KEY,n INTEGER NOT NULL DEFAULT 7)");statement.execute("INSERT INTO "+table+" VALUES(1,7)");
        }finally{owner.lock.unlock();}
    }
    private static ChangeRequest request(EngineFixture fixture,SessionRegistry.Session owner,String sql)throws Exception{
        var result=fixture.results.get(fixture.execute(owner,sql).info().getResults(0).getResultId());assertTrue(result.metadataProof().available(),result.metadataProof().toString());
        var first=result.columns.getFirst();return ChangeRequest.newBuilder().setSessionId(owner.id).setResultId(result.id).setCatalog(first.getCatalog()).setSchema(fixture.schema()).setTable(first.getTable())
            .addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE).putValues(2,Assignments.value(Value.newBuilder().setSignedInteger("8").build()))).build();
    }
    private static MetadataConfiguration policy(MetadataConfiguration before,List<String> include,List<String> exclude){
        return new MetadataConfiguration(before.revision()+1,before.includedCatalogs(),before.excludedCatalogs(),before.includedSchemas(),before.excludedSchemas(),before.systemObjects(),before.kinds(),include,exclude,before.defaultLevel(),before.scopeLevels());
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void excludedRetainedTargetIsRejectedBeforePhysicalOrIndependentJdbc(String engine)throws Exception{
        var counter=new Counter();try(var fixture=new EngineFixture(root,engine,counter.opener())){
            var owner=fixture.open();seed(fixture,owner,TABLE);fixture.warm(owner,TABLE);String table=owner.adapter.table("busydata",fixture.schema(),TABLE);
            var changes=request(fixture,owner,"SELECT id,n FROM "+table);var platform=fixture.metadata.metadataPlatform();var planner=new ChangePlanner(fixture.safety,fixture.results,platform);
            platform.configure(owner,policy(platform.configuration(owner),List.of(),List.of(TABLE)));int jobs=fixture.jobs.list(owner.id).size();
            counter.armed.set(true);
            try{var rejected=assertThrows(WorkbenchFailure.class,()->planner.preview(owner,changes));assertEquals(WorkbenchFailure.Reason.INCOMPLETE_METADATA,rejected.reason());}
            finally{counter.armed.set(false);}
            assertEquals(0,counter.jdbc.get(),"Excluded target must not reach native classification, table metadata or JDBC execution");assertEquals(0,counter.opens.get(),"Excluded target must not open independent metadata connections");
            assertEquals(jobs,fixture.jobs.list(owner.id).size());assertEquals("8",changes.getChanges(0).getValuesOrThrow(2).getValue().getSignedInteger());
            EditingIT.assertRows(owner,"SELECT id,n FROM "+table,new int[][]{{1,7}});
        }
    }
    @ParameterizedTest @ValueSource(strings={"MYSQL","MARIADB"})
    void nativeCaseVariantUsesRetainedCanonicalIdentityForExactPolicy(String engine)throws Exception{
        try(var fixture=new EngineFixture(root,engine,c->c.withCommand("--lower_case_table_names=1","--character-set-server=utf8mb4","--collation-server=utf8mb4_unicode_ci"))){
            var owner=fixture.open();seed(fixture,owner,"PoLiCy_RoWs");fixture.warm(owner,TABLE);var platform=fixture.metadata.metadataPlatform();
            platform.configure(owner,policy(platform.configuration(owner),List.of(TABLE),List.of()));fixture.warm(owner,TABLE);
            String variant=owner.adapter.table("busydata",fixture.schema(),"PoLiCy_RoWs");var changes=request(fixture,owner,"SELECT id,n FROM "+variant);
            var result=fixture.results.get(changes.getResultId());assertEquals(TABLE,result.metadataProof().table());assertEquals(1,platform.capture(owner).resolve("busydata",fixture.schema(),ObjectKind.TABLE,"",TABLE,true).size());
            var planner=new ChangePlanner(fixture.safety,fixture.results,platform);var plan=planner.preview(owner,changes);
            assertEquals(1,plan.getSqlCount());assertTrue(plan.getSql(0).contains(owner.adapter.table(changes.getCatalog(),changes.getSchema(),changes.getTable())));
            EditingIT.assertRows(owner,"SELECT id,n FROM "+variant,new int[][]{{1,7}});
        }
    }
}
