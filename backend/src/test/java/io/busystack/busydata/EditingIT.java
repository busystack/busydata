package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.analysis.SqlAnalysis;
import io.busystack.busydata.sessions.SessionRegistry;
import io.busystack.busydata.results.*;
import io.busystack.busydata.storage.MetadataStore;
import io.busystack.busydata.safety.Safety;
import io.busystack.busydata.jobs.Jobs;
import io.busystack.busydata.schema.ChangePlanner;
import java.nio.file.Path;
import java.time.Duration;
import java.util.*;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.junit.jupiter.api.io.TempDir;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.wait.strategy.Wait;
import org.testcontainers.utility.DockerImageName;
import static org.junit.jupiter.api.Assertions.*;

class EditingIT {
    @TempDir Path root;
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void aliasSwapChangesOnlyTheActualBaseRow(String name)throws Exception {
        Engine engine=Engine.valueOf(name);int port=engine==Engine.POSTGRESQL?5432:3306;
        String image=switch(engine){case POSTGRESQL->"postgres:17.11";case MYSQL->"mysql:8.4.10";case MARIADB->"mariadb:11.8.9";default->throw new AssertionError();};
        try(var database=new GenericContainer<>(DockerImageName.parse(image)).withExposedPorts(port)) {
            if(engine==Engine.POSTGRESQL)database.withEnv("POSTGRES_PASSWORD","fixture").withEnv("POSTGRES_USER","busydata").withEnv("POSTGRES_DB","busydata").waitingFor(Wait.forLogMessage(".*database system is ready to accept connections.*\\n",2));
            else database.withEnv(engine==Engine.MYSQL?"MYSQL_ROOT_PASSWORD":"MARIADB_ROOT_PASSWORD","fixture").withEnv(engine==Engine.MYSQL?"MYSQL_DATABASE":"MARIADB_DATABASE","busydata").withCommand("--character-set-server=utf8mb4","--collation-server=utf8mb4_unicode_ci").waitingFor(Wait.forListeningPort());
            database.withStartupTimeout(Duration.ofMinutes(3));
            database.start();
            var profile=Profile.newBuilder().setId("editing").setName("Editing fixture").setEngine(engine).setHost(database.getHost()).setPort(database.getMappedPort(port)).setDatabase("busydata").setUser(engine==Engine.POSTGRESQL?"busydata":"root").setTls(Tls.newBuilder().setMode(engine==Engine.MYSQL?TlsMode.INSECURE:TlsMode.DISABLED)).setConnectTimeoutSeconds(10).setQueryTimeoutSeconds(30).build();
            try(var sessions=new SessionRegistry();var metadata=new MetadataStore(root);var results=new ResultStore(root,64L*1024*1024)) {
                var analysis=new SqlAnalysis();var safety=new Safety(analysis);
                try(var jobs=new Jobs(results,metadata,analysis,safety)) {
                    var session=sessions.open(OpenRequest.newBuilder().setProfile(profile).setPassword("fixture").build());
                    execute(jobs,safety,session,"CREATE TABLE alias_swap (id INTEGER PRIMARY KEY,n INTEGER); INSERT INTO alias_swap VALUES(1,2),(2,1)");
                    EngineFixture.warm(metadata,session,"alias_swap");
                    String aliasSwap=session.adapter.table(session.context.catalog(),engine==Engine.POSTGRESQL?"public":session.context.catalog(),"alias_swap");
                    var source=execute(jobs,safety,session,"SELECT n AS id,id AS n FROM "+aliasSwap+" ORDER BY alias_swap.id");
                    var retained=results.get(source.info().getResults(0).getResultId());var row=retained.read(0);
                    var change=StagedChange.newBuilder().setKind(ChangeKind.UPDATE).setSourceRow(0).putValues(1,io.busystack.busydata.schema.Assignments.value(Value.newBuilder().setSignedInteger("9").build()));
                    var request=ChangeRequest.newBuilder().setSessionId(session.id).setResultId(retained.id).setSchema(engine==Engine.POSTGRESQL?"public":"busydata").setTable("alias_swap").addChanges(change).build();
                    var planner=new ChangePlanner(safety,results,metadata.metadataPlatform());var plan=planner.preview(session,request);
                    var applied=planner.apply(session,ApplyRequest.newBuilder().setSessionId(session.id).setPlanId(plan.getPlanId()).setExecutionId(UUID.randomUUID().toString()).build(),jobs);await(applied);
                    assertEquals(JobState.COMPLETED,applied.state,applied.info().toString());
                    try(var statement=session.connection.createStatement();var rows=statement.executeQuery("SELECT id,n FROM alias_swap ORDER BY id")) {
                        assertTrue(rows.next());assertEquals(1,rows.getInt(1),"The selected row's base id must remain 1");assertEquals(9,rows.getInt(2));
                        assertTrue(rows.next());assertEquals(2,rows.getInt(1));assertEquals(1,rows.getInt(2));assertFalse(rows.next());
                    }
                    assertEquals("id",retained.columns.get(0).getName());assertEquals("n",retained.columns.get(0).getBaseColumn());
                    assertEquals("id",retained.columns.get(1).getBaseColumn());assertEquals(1,retained.columns.get(0).getOrdinal());
                    // Deletion must also follow server-retained identity after an alias swap.
                    var deletion=results.get(execute(jobs,safety,session,"SELECT n AS id,id AS n FROM "+aliasSwap+" ORDER BY alias_swap.id").info().getResults(0).getResultId());
                    apply(planner,jobs,session,request.toBuilder().setResultId(deletion.id).clearChanges().addChanges(StagedChange.newBuilder().setKind(ChangeKind.DELETE).setSourceRow(0)).build());
                    assertRows(session,"SELECT id,n FROM alias_swap",new int[][]{{2,1}});
                    // Duplicate display labels are harmless when each base ordinal is unique.
                    var duplicate=results.get(execute(jobs,safety,session,"SELECT id AS same,n AS same FROM "+aliasSwap).info().getResults(0).getResultId());
                    apply(planner,jobs,session,request.toBuilder().setResultId(duplicate.id).clearChanges().addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE).putValues(2,io.busystack.busydata.schema.Assignments.value(integer(7)))).build());
                    assertRows(session,"SELECT id,n FROM alias_swap",new int[][]{{2,7}});
                    for(String invalid:List.of("SELECT id,id AS other,n FROM "+aliasSwap,"SELECT id,n+1 AS computed FROM "+aliasSwap,"SELECT n FROM "+aliasSwap)) {
                        var bad=results.get(execute(jobs,safety,session,invalid).info().getResults(0).getResultId());
                        var badRequest=request.toBuilder().setResultId(bad.id).clearChanges().addChanges(StagedChange.newBuilder().setKind(ChangeKind.DELETE)).build();
                        assertEquals(invalid.startsWith("SELECT n FROM ")?io.busystack.busydata.rpc.WorkbenchFailure.Reason.EDIT_IDENTITY_REQUIRED:io.busystack.busydata.rpc.WorkbenchFailure.Reason.EDIT_PROJECTION_UNSUPPORTED,assertThrows(io.busystack.busydata.rpc.WorkbenchFailure.class,()->planner.preview(session,badRequest),invalid).reason());
                    }
                    String quoted=session.adapter.quote("Quoted 漢 Table"),key=session.adapter.quote("Key"),value=session.adapter.quote("Value"),computed=session.adapter.quote("Computed");
                    String scope=engine==Engine.POSTGRESQL?"public":"busydata";
                    execute(jobs,safety,session,"CREATE TABLE "+quoted+" ("+key+" INTEGER NOT NULL UNIQUE,"+value+" INTEGER DEFAULT 3,"+computed+" INTEGER GENERATED ALWAYS AS ("+value+"*2) STORED); INSERT INTO "+quoted+" ("+key+") VALUES(10)");
                    EngineFixture.warm(metadata,session,"Quoted 漢 Table");
                    String projection="SELECT q."+value+" AS "+session.adapter.quote("label value")+",q."+key+" AS "+session.adapter.quote("label key")+",q."+computed+" FROM "+session.adapter.quote(scope)+"."+quoted+" q";
                    var uniqueSource=results.get(execute(jobs,safety,session,projection).info().getResults(0).getResultId());
                    var uniqueRequest=request.toBuilder().setTable("Quoted 漢 Table").setResultId(uniqueSource.id).clearChanges().addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE).putValues(1,io.busystack.busydata.schema.Assignments.value(integer(4)))).build();
                    apply(planner,jobs,session,uniqueRequest);assertRows(session,"SELECT "+key+","+value+","+computed+" FROM "+quoted,new int[][]{{10,4,8}});
                    var generated=uniqueRequest.toBuilder().setChanges(0,StagedChange.newBuilder().setKind(ChangeKind.UPDATE).putValues(3,io.busystack.busydata.schema.Assignments.value(integer(1)))).build();
                    assertThrows(IllegalArgumentException.class,()->planner.preview(session,generated));
                    // Retained values detect concurrent changes, without trusting client originals.
                    var conflict=planner.preview(session,uniqueRequest);
                    var rejected=planner.apply(session,ApplyRequest.newBuilder().setSessionId(session.id).setPlanId(conflict.getPlanId()).setExecutionId(UUID.randomUUID().toString()).build(),jobs);await(rejected);assertEquals(JobState.FAILED,rejected.state);
                    assertRows(session,"SELECT "+key+","+value+","+computed+" FROM "+quoted,new int[][]{{10,4,8}});
                    var fresh=results.get(execute(jobs,safety,session,projection).info().getResults(0).getResultId());
                    var stale=planner.preview(session,uniqueRequest.toBuilder().setResultId(fresh.id).build());
                    execute(jobs,safety,session,"SELECT 1");
                    var staleJob=planner.apply(session,ApplyRequest.newBuilder().setSessionId(session.id).setPlanId(stale.getPlanId()).setExecutionId(UUID.randomUUID().toString()).build(),jobs);await(staleJob);assertEquals(JobState.FAILED,staleJob.state);
                    assertRows(session,"SELECT "+key+","+value+","+computed+" FROM "+quoted,new int[][]{{10,4,8}});
                    if(engine==Engine.POSTGRESQL){
                        var operators=execute(jobs,safety,session,"SELECT '{\"a\":1}'::jsonb ? 'a','{\"a\":1}'::jsonb ?| ARRAY['a','b'],'{\"a\":1}'::jsonb ?& ARRAY['a'],'literal ? {fn now()}'");
                        var operatorRow=results.get(operators.info().getResults(0).getResultId()).read(0);
                        assertTrue(operatorRow.getValues(0).getBoolean());assertTrue(operatorRow.getValues(1).getBoolean());assertTrue(operatorRow.getValues(2).getBoolean());assertEquals("literal ? {fn now()}",operatorRow.getValues(3).getText());
                    }
                }
            }
        }
    }
    static Jobs.Job execute(Jobs jobs,Safety safety,SessionRegistry.Session session,String sql)throws Exception {
        var request=ExecuteRequest.newBuilder().setSessionId(session.id).setExecutionId(UUID.randomUUID().toString()).setSql(sql).setRowLimit(1000).build();
        var job=jobs.execute(session,request.toBuilder().setApprovalToken(safety.review(request,session).getToken()).build());await(job);assertEquals(JobState.COMPLETED,job.state,job.info().toString());return job;
    }
    static Value integer(int value){return Value.newBuilder().setSignedInteger(Integer.toString(value)).build();}
    static void apply(ChangePlanner planner,Jobs jobs,SessionRegistry.Session session,ChangeRequest request)throws Exception {
        var plan=planner.preview(session,request);var job=planner.apply(session,ApplyRequest.newBuilder().setSessionId(session.id).setPlanId(plan.getPlanId()).setExecutionId(UUID.randomUUID().toString()).build(),jobs);await(job);assertEquals(JobState.COMPLETED,job.state,()->"failureOrigin="+job.failureOrigin()+"\n"+job.info());
    }
    static void assertRows(SessionRegistry.Session session,String sql,int[][] expected)throws Exception {
        try(var statement=session.connection.createStatement();var rows=statement.executeQuery(sql)){
            for(var values:expected){assertTrue(rows.next());for(int i=0;i<values.length;i++)assertEquals(values[i],rows.getInt(i+1));}assertFalse(rows.next());
        }
    }
    static void await(Jobs.Job job)throws Exception {long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(45);while(!Jobs.terminal(job.state)&&System.nanoTime()<deadline)Thread.sleep(10);assertTrue(Jobs.terminal(job.state),job.info().toString());}
}
