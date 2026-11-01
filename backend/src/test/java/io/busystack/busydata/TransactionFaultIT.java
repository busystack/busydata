package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.ChangePlanner;
import java.nio.file.Path;
import java.sql.*;
import java.lang.reflect.*;
import java.util.*;
import java.util.concurrent.atomic.*;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

class TransactionFaultIT {
    @TempDir Path root;
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void toolbarCommitResponseLossIsUnknownAndCannotBeRefreshedIntoReuse(String engine)throws Exception {
        var faults=new Faults();
        try(var f=new EngineFixture(root,engine,(adapter,request,port)->faults.wrap(adapter.connect(request,port)))){
            var s=f.open();var platform=f.metadata.metadataPlatform();var policy=platform.configuration(s);
            platform.configure(s,new io.busystack.busydata.metadata.MetadataConfiguration(policy.revision()+1,policy.includedCatalogs(),policy.excludedCatalogs(),policy.includedSchemas(),policy.excludedSchemas(),policy.systemObjects(),policy.kinds(),policy.includePatterns(),policy.excludePatterns(),policy.defaultLevel(),policy.scopeLevels()));
            long configuration=platform.configuration(s).revision();assertTrue(configuration>1);f.execute(s,"CREATE TABLE outcomes (id INTEGER PRIMARY KEY,n INTEGER)");
            f.sessions.command(SessionRequest.newBuilder().setSessionId(s.id).setAction(SessionAction.BEGIN).build());
            f.execute(s,"INSERT INTO outcomes VALUES(1,7)");faults.arm(s.connection,"commit-loss");
            assertThrows(SQLException.class,()->f.sessions.command(SessionRequest.newBuilder().setSessionId(s.id).setAction(SessionAction.COMMIT).build()));
            assertEquals(TransactionState.UNKNOWN_TRANSACTION,s.state,"A lost commit reply must not retain cached ACTIVE status");
            var unavailable=platform.capture(s);assertEquals(configuration,unavailable.configurationRevision(),"Unavailable metadata must retain its actual source configuration domain");
            assertEquals(s.metadataSourceIdentity,unavailable.source());assertTrue(unavailable.identities().isEmpty());assertTrue(unavailable.catalogCoverage().isEmpty());
            s.refresh();assertEquals(TransactionState.UNKNOWN_TRANSACTION,s.state,"Refresh cannot restore an uncertain connection");
            var rejected=f.submit(s,"INSERT INTO outcomes VALUES(2,8)");EditingIT.await(rejected);assertEquals(JobState.FAILED,rejected.state);
            var observer=f.open();EditingIT.assertRows(observer,"SELECT id,n FROM outcomes",new int[][]{{1,7}});
            f.sessions.close(s.id,true);f.sessions.close(s.id,true);assertEquals(1,faults.closed.get());
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void failedRollbackNeverRestoresAutoCommitOrCommitsEarlierEdits(String engine)throws Exception {
        var faults=new Faults();
        try(var f=new EngineFixture(root,engine,(adapter,request,port)->faults.wrap(adapter.connect(request,port)))){
            var s=f.open();f.execute(s,"CREATE TABLE outcomes (id INTEGER PRIMARY KEY,n INTEGER); INSERT INTO outcomes VALUES(1,1),(2,2)");
            f.warm(s,"outcomes");
            String table=s.adapter.table(s.context.catalog(),f.schema(),"outcomes");
            var source=f.results.get(f.execute(s,"SELECT id,n FROM "+table+" ORDER BY id").info().getResults(0).getResultId());
            var planner=new ChangePlanner(f.safety,f.results,f.metadata.metadataPlatform());var request=ChangeRequest.newBuilder().setSessionId(s.id).setSchema(f.schema()).setTable("outcomes").setResultId(source.id)
                .addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE).setSourceRow(0).putValues(2,io.busystack.busydata.schema.Assignments.value(EditingIT.integer(3))))
                .addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE).setSourceRow(1).putValues(2,io.busystack.busydata.schema.Assignments.value(EditingIT.integer(4)))).build();
            var plan=planner.preview(s,request);var observer=f.open();f.execute(observer,"UPDATE outcomes SET n=99 WHERE id=2");
            faults.arm(s.connection,"rollback-failure");
            var job=planner.apply(s,ApplyRequest.newBuilder().setSessionId(s.id).setPlanId(plan.getPlanId()).setExecutionId(UUID.randomUUID().toString()).build(),f.jobs);EditingIT.await(job);
            assertEquals(TransactionState.UNKNOWN_TRANSACTION,s.state);assertEquals(0,faults.autoCommitOn.get(),"setAutoCommit(true) after failed rollback could commit row 1");
            assertEquals(JobState.UNKNOWN_OUTCOME,job.state,job.info().toString());
            EditingIT.assertRows(observer,"SELECT id,n FROM outcomes ORDER BY id",new int[][]{{1,1},{2,99}});
            assertEquals(1,faults.closed.get());
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void importRollbackFailureCannotCommitAnEarlierExecutedBatch(String engine)throws Exception {
        var faults=new Faults();
        try(var f=new EngineFixture(root,engine,(adapter,request,port)->faults.wrap(adapter.connect(request,port)))){
            var s=f.open();f.execute(s,"CREATE TABLE outcomes (id INTEGER PRIMARY KEY,n INTEGER)");
            Path input=root.resolve("batch.csv");try(var writer=java.nio.file.Files.newBufferedWriter(input)){
                writer.write("id,n\n");for(int i=1;i<=256;i++)writer.write(i+",7\n");writer.write("257,invalid_integer\n");
            }
            faults.arm(s.connection,"rollback-failure");
            var request=ToolRequest.newBuilder().setKind(ToolKind.IMPORT_CSV).setPath(input.toString()).setSchema(f.schema()).setTable("outcomes").addColumns("id").addColumns("n").build();
            var transfers=new io.busystack.busydata.transfers.Transfers(f.results);
            var job=f.jobs.submit(s,UUID.randomUUID().toString(),"",j->transfers.run(j,request));EditingIT.await(job);
            assertEquals(256,job.progress);assertEquals(JobState.UNKNOWN_OUTCOME,job.state,job.info().toString());
            assertEquals(TransactionState.UNKNOWN_TRANSACTION,s.state);assertEquals(0,faults.autoCommitOn.get());
            var observer=f.open();try(var statement=observer.connection.createStatement();var rows=statement.executeQuery("SELECT COUNT(*) FROM outcomes")){assertTrue(rows.next());assertEquals(0,rows.getLong(1));}
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void acknowledgedCommitSurvivesRestoreFailureAndLateCancellation(String engine)throws Exception {
        var faults=new Faults();
        try(var f=new EngineFixture(root,engine,(adapter,request,port)->faults.wrap(adapter.connect(request,port)))){
            var s=f.open();f.execute(s,"CREATE TABLE outcomes (id INTEGER PRIMARY KEY,n INTEGER); INSERT INTO outcomes VALUES(1,1)");
            f.warm(s,"outcomes");
            String table=s.adapter.table(s.context.catalog(),f.schema(),"outcomes");
            var source=f.results.get(f.execute(s,"SELECT id,n FROM "+table).info().getResults(0).getResultId());
            var planner=new ChangePlanner(f.safety,f.results,f.metadata.metadataPlatform());var request=ChangeRequest.newBuilder().setSessionId(s.id).setSchema(f.schema()).setTable("outcomes").setResultId(source.id)
                .addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE).putValues(2,io.busystack.busydata.schema.Assignments.value(EditingIT.integer(7)))).build();
            var plan=planner.preview(s,request);faults.arm(s.connection,"restore-failure");
            var job=planner.apply(s,ApplyRequest.newBuilder().setSessionId(s.id).setPlanId(plan.getPlanId()).setExecutionId(UUID.randomUUID().toString()).build(),f.jobs);EditingIT.await(job);
            assertEquals(JobState.COMPLETED,job.state,"The database acknowledged commit even though session restoration failed");
            assertEquals(TransactionState.UNKNOWN_TRANSACTION,s.state);f.jobs.cancel(job.id);assertEquals(JobState.COMPLETED,job.state);
            var observer=f.open();EditingIT.assertRows(observer,"SELECT id,n FROM outcomes",new int[][]{{1,7}});
            // Cancel while COMMIT's server response is deliberately held. The
            // operation remains acknowledged, and no next statement is cancelled.
            f.sessions.command(SessionRequest.newBuilder().setSessionId(observer.id).setAction(SessionAction.BEGIN).build());
            f.execute(observer,"UPDATE outcomes SET n=8 WHERE id=1");faults.arm(observer.connection,"commit-block");
            var committing=f.submit(observer,"COMMIT");assertTrue(faults.committed.await(5,java.util.concurrent.TimeUnit.SECONDS));
            f.jobs.cancel(committing.id);assertFalse(committing.cancel.get());faults.reply.countDown();EditingIT.await(committing);
            assertEquals(JobState.COMPLETED,committing.state,committing.info().toString());
            EditingIT.assertRows(observer,"SELECT id,n FROM outcomes",new int[][]{{1,8}});f.execute(observer,"SELECT 1");
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void toolbarAcknowledgementIsRetainedWhenContextRefreshFails(String engine)throws Exception {
        var faults=new Faults();
        try(var f=new EngineFixture(root,engine,(adapter,request,port)->faults.wrap(adapter.connect(request,port)))){
            var s=f.open();f.execute(s,"CREATE TABLE outcomes(id INTEGER PRIMARY KEY,n INTEGER)");
            f.sessions.command(SessionRequest.newBuilder().setSessionId(s.id).setAction(SessionAction.BEGIN).build());
            f.execute(s,"INSERT INTO outcomes VALUES(1,9)");faults.arm(s.connection,"commit-refresh-loss");
            var acknowledged=f.sessions.command(SessionRequest.newBuilder().setSessionId(s.id).setAction(SessionAction.COMMIT).build());
            assertTrue(acknowledged.getCommandAcknowledged());assertEquals(SessionAction.COMMIT,acknowledged.getAcknowledgedAction());
            assertEquals(TransactionState.UNKNOWN_TRANSACTION,acknowledged.getTransaction());assertTrue(acknowledged.getCommandWarning().contains("acknowledged COMMIT"));
            var observer=f.open();EditingIT.assertRows(observer,"SELECT id,n FROM outcomes",new int[][]{{1,9}});
            assertThrows(IllegalStateException.class,()->f.sessions.command(SessionRequest.newBuilder().setSessionId(s.id).setAction(SessionAction.COMMIT).build()));
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL"})
    void returningWriteCanStopFetchingWithoutRelabellingAcknowledgedMutation(String engine)throws Exception {
        var fetching=new java.util.concurrent.CountDownLatch(1);var release=new java.util.concurrent.CountDownLatch(1);
        var armed=new AtomicBoolean();var target=new AtomicReference<Connection>();
        try(var f=new EngineFixture(root,engine,(adapter,request,port)->{
            var owner=new AtomicReference<Connection>();
            var delegate=NativePostgresFaults.wrap(adapter.connect(request,port),new NativePostgresFaults.Observer(){
                @Override public ResultSet result(String sql,ResultSet rows){
                    if(!armed.get()||owner.get()!=target.get()||!sql.startsWith("WITH changed AS"))return rows;
                    return (ResultSet)Proxy.newProxyInstance(getClass().getClassLoader(),new Class[]{ResultSet.class},(rs,read,parameters)->{
                        if(read.getName().equals("next")){fetching.countDown();if(!release.await(5,java.util.concurrent.TimeUnit.SECONDS))throw new SQLException("Injected fetch deadline","08006");}
                        return Faults.invoke(rows,read,parameters);
                    });
                }
            });
            var connection=(Connection)Proxy.newProxyInstance(getClass().getClassLoader(),new Class[]{Connection.class},(proxy,m,args)->Faults.invoke(delegate,m,args));
            owner.set(connection);return connection;
        })){
            var s=f.open();f.execute(s,"CREATE TABLE outcomes(id INTEGER PRIMARY KEY,n INTEGER); INSERT INTO outcomes VALUES(1,1)");
            target.set(s.connection);armed.set(true);var job=f.submit(s,"WITH changed AS (UPDATE outcomes SET n=9 WHERE id=1 RETURNING id,n) SELECT * FROM changed");
            assertTrue(fetching.await(5,java.util.concurrent.TimeUnit.SECONDS));var observer=f.open();
            EditingIT.assertRows(observer,"SELECT id,n FROM outcomes",new int[][]{{1,9}});
            f.jobs.cancel(job.id);assertTrue(job.cancel.get(),"Only delivery is cancelled after acknowledgement");release.countDown();EditingIT.await(job);
            assertEquals(JobState.COMPLETED,job.state,job.info().toString());assertFalse(job.info().getResults(0).getComplete());
            assertTrue(job.info().getMessagesList().stream().anyMatch(message->message.contains("committed changes remain committed")));
            armed.set(false);f.execute(s,"SELECT 7");
        }finally{release.countDown();}
    }
    static final class Faults {
        volatile Connection target;volatile String mode="";volatile boolean acknowledged;final AtomicInteger closed=new AtomicInteger(),autoCommitOn=new AtomicInteger();
        final java.util.concurrent.CountDownLatch committed=new java.util.concurrent.CountDownLatch(1),reply=new java.util.concurrent.CountDownLatch(1);
        void arm(Connection connection,String failure){target=connection;mode=failure;acknowledged=false;closed.set(0);autoCommitOn.set(0);}
        Connection wrap(Connection delegate)throws SQLException {
            var owner=new AtomicReference<Connection>();
            var observed=delegate.isWrapperFor(org.postgresql.core.BaseConnection.class)?NativePostgresFaults.wrap(delegate,new NativePostgresFaults.Observer(){
                @Override public void acknowledged(String sql)throws Exception {
                    if(owner.get()!=target||!sql.equalsIgnoreCase("COMMIT"))return;
                    if(mode.equals("commit-refresh-loss"))acknowledged=true;
                    if(mode.equals("commit-loss"))throw new SQLException("Injected lost commit acknowledgement","08006");
                    if(mode.equals("commit-block"))awaitCommitReply();
                }
            }):delegate;
            var connection=(Connection)Proxy.newProxyInstance(getClass().getClassLoader(),new Class[]{Connection.class},(proxy,method,args)->{
                boolean armed=proxy==target;
                if(armed&&acknowledged&&mode.equals("commit-refresh-loss")&&method.getName().equals("getAutoCommit"))throw new SQLException("Injected refresh response loss","08006");
                if(armed&&method.getName().equals("close"))closed.incrementAndGet();
                if(armed&&method.getName().equals("setAutoCommit")&&Boolean.TRUE.equals(args[0]))autoCommitOn.incrementAndGet();
                if(armed&&mode.equals("rollback-failure")&&method.getName().equals("rollback"))throw new SQLException("Injected rollback failure","08006");
                if(armed&&mode.equals("restore-failure")&&method.getName().equals("setAutoCommit")&&Boolean.TRUE.equals(args[0]))throw new SQLException("Injected auto-commit restoration failure","08006");
                Object value=invoke(observed,method,args);
                if(value instanceof Statement statement)return Proxy.newProxyInstance(getClass().getClassLoader(),new Class[]{value instanceof PreparedStatement?PreparedStatement.class:Statement.class},(st,m,a)->{
                    Object result=invoke(statement,m,a);
                    if(proxy==target&&mode.equals("commit-refresh-loss")&&m.getName().equals("execute")&&a!=null&&a.length>0&&a[0].toString().equalsIgnoreCase("COMMIT"))acknowledged=true;
                    if(proxy==target&&mode.equals("commit-loss")&&m.getName().equals("execute")&&a!=null&&a.length>0&&a[0].toString().equalsIgnoreCase("COMMIT"))throw new SQLException("Injected lost commit acknowledgement","08006");
                    if(proxy==target&&mode.equals("commit-block")&&m.getName().equals("execute")&&a!=null&&a.length>0&&a[0].toString().equalsIgnoreCase("COMMIT"))awaitCommitReply();
                    return result;
                });
                if(armed&&mode.equals("commit-loss")&&method.getName().equals("commit"))throw new SQLException("Injected lost commit acknowledgement","08006");
                if(armed&&mode.equals("commit-block")&&method.getName().equals("commit"))awaitCommitReply();
                return value;
            });
            owner.set(connection);return connection;
        }
        void awaitCommitReply()throws Exception {committed.countDown();if(!reply.await(5,java.util.concurrent.TimeUnit.SECONDS))throw new SQLException("Injected commit reply deadline","08006");}
        static Object invoke(Object target,Method method,Object[] arguments)throws Throwable {
            try{return method.invoke(target,arguments);}catch(InvocationTargetException e){throw e.getCause();}
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void lateCancellationAfterAutoCommitResponseCannotCancelContextRefresh(String engine)throws Exception {
        var entered=new java.util.concurrent.CountDownLatch(1);var release=new java.util.concurrent.CountDownLatch(1);
        var armed=new AtomicBoolean();var executed=new AtomicBoolean();
        try(var f=new EngineFixture(root,engine,(adapter,request,port)->{
            var physical=adapter.connect(request,port);
            var delegate=adapter.engine()==Engine.POSTGRESQL?NativePostgresFaults.wrap(physical,new NativePostgresFaults.Observer(){
                @Override public void acknowledged(String sql){if(armed.get()&&sql.startsWith("UPDATE outcomes"))executed.set(true);}
            }):physical;
            return (Connection)Proxy.newProxyInstance(getClass().getClassLoader(),new Class[]{Connection.class},(proxy,m,args)->{
                if(armed.get()&&executed.get()&&m.getName().equals("getAutoCommit")){
                    entered.countDown();if(!release.await(5,java.util.concurrent.TimeUnit.SECONDS))throw new SQLException("Injected context deadline","08006");
                }
                Object value=Faults.invoke(delegate,m,args);
                if(value instanceof Statement statement)return Proxy.newProxyInstance(getClass().getClassLoader(),new Class[]{value instanceof PreparedStatement?PreparedStatement.class:Statement.class},(st,method,arguments)->{
                    Object result=Faults.invoke(statement,method,arguments);
                    if(armed.get()&&method.getName().equals("execute")&&arguments!=null&&arguments.length>0&&arguments[0].toString().startsWith("UPDATE outcomes"))executed.set(true);
                    return result;
                });
                return value;
            });
        })){
            var s=f.open();f.execute(s,"CREATE TABLE outcomes(id INTEGER PRIMARY KEY,n INTEGER); INSERT INTO outcomes VALUES(1,1)");
            armed.set(true);var update=f.submit(s,"UPDATE outcomes SET n=8 WHERE id=1");
            assertTrue(entered.await(5,java.util.concurrent.TimeUnit.SECONDS));f.jobs.cancel(update.id);
            assertFalse(update.cancel.get(),"The write acknowledgement precedes context refresh");release.countDown();EditingIT.await(update);armed.set(false);
            assertEquals(JobState.COMPLETED,update.state,update.info().toString());EditingIT.assertRows(s,"SELECT id,n FROM outcomes",new int[][]{{1,8}});
        }finally{release.countDown();}
    }
}
