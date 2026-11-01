package io.busystack.busydata.adapters;

import java.lang.reflect.InvocationHandler;
import java.lang.reflect.Method;
import java.lang.reflect.Proxy;
import java.sql.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;
import org.postgresql.core.*;
import static org.junit.jupiter.api.Assertions.*;

class PostgresRawStatementsTest {
    @Test void explicitCancelIsNoOpBeforeExecutionAndAfterFinalResult()throws Exception {
        var f=new Fixture();
        try(var statement=f.wrap()) {
            statement.cancel();assertEquals(0,f.cancels.get());
            statement.execute("UPDATE target SET value=1");
            statement.cancel();assertEquals(1,f.cancels.get());
            assertFalse(statement.getMoreResults());
            statement.cancel();assertEquals(1,f.cancels.get());
        }
    }
    @Test void queuedTimeoutCannotCancelContextProbeAfterFinalResult()throws Exception {
        var f=new Fixture();
        try(var statement=f.wrap()) {
            assertFalse(statement.execute("UPDATE target SET value=1"));
            assertEquals(1,statement.getLargeUpdateCount());
            f.timer.run();assertEquals(1,f.queued.size());
            assertFalse(statement.getMoreResults(Statement.CLOSE_CURRENT_RESULT));
            assertEquals(-1,statement.getLargeUpdateCount());
            // The wrapper remains open while Jobs refreshes the session context.
            // This worker was already admitted before its TimerTask was stopped.
            f.queued.removeFirst().run();
            assertEquals(0,f.cancels.get());assertFalse(statement.isClosed());
            assertEquals(1,f.executions.get());
        }
    }
    @Test void oldTimeoutCannotCancelAnotherExecutionButCurrentTimeoutStillWorks()throws Exception {
        var f=new Fixture();
        try(var statement=f.wrap()) {
            statement.execute("UPDATE first_target SET value=1");f.timer.run();
            statement.execute("UPDATE second_target SET value=2");
            f.queued.removeFirst().run();assertEquals(0,f.cancels.get());
            f.timer.run();f.queued.removeFirst().run();assertEquals(1,f.cancels.get());
            assertEquals(2,f.executions.get());
        }
    }
    @Test void explicitCancellationKeepsPhysicalOwnerUntilCancellationIoFinishes()throws Exception {
        var f=new Fixture();var statement=f.wrap();
        var entered=new CountDownLatch(1);var release=new CountDownLatch(1);
        f.cancelIo=()->{entered.countDown();assertTrue(release.await(2,TimeUnit.SECONDS));};
        statement.execute("UPDATE target SET value=1");
        try(var threads=Executors.newFixedThreadPool(2)) {
            var cancelled=threads.submit(()->{statement.cancel();return null;});
            assertTrue(entered.await(2,TimeUnit.SECONDS));
            var closeStarted=new CountDownLatch(1);
            var closed=threads.submit(()->{closeStarted.countDown();statement.close();return null;});
            assertTrue(closeStarted.await(2,TimeUnit.SECONDS));
            try {
                assertThrows(TimeoutException.class,()->closed.get(50,TimeUnit.MILLISECONDS));
                assertFalse(f.delegateClosed);
            }finally {release.countDown();}
            cancelled.get(2,TimeUnit.SECONDS);closed.get(2,TimeUnit.SECONDS);
            assertTrue(statement.isClosed());assertTrue(f.delegateClosed);assertEquals(1,f.cancels.get());
        }finally {release.countDown();statement.close();}
    }
    @Test void resultFactoryReceivesExactCursorAndCloseReleasesResultsBeforeQuery()throws Exception {
        var f=new Fixture();f.returnRows=true;
        try(var statement=f.wrap()) {
            assertTrue(statement.execute("SELECT value FROM target"));
            assertSame(f.rows,statement.getResultSet());assertEquals(-1,statement.getUpdateCount());
            statement.cancel();assertEquals(1,f.cancels.get(),"Cursor fetching retains its cancellation owner");
            assertSame(f.query,f.resultArguments[0]);assertSame(f.fields,f.resultArguments[1]);
            assertSame(f.tuples,f.resultArguments[2]);assertSame(f.cursor,f.resultArguments[3]);
        }
        assertEquals(List.of("rows","query","statement"),f.closedResources);
    }

    @FunctionalInterface private interface CheckedAction {void run()throws Exception;}
    private static final class Fixture {
        final AtomicInteger executions=new AtomicInteger(),cancels=new AtomicInteger();
        final ArrayList<Runnable> queued=new ArrayList<>();
        final ArrayList<String> closedResources=new ArrayList<>();
        final Field[] fields=new Field[0];final List<Tuple> tuples=List.of();
        final ResultCursor cursor=()->{};
        TimerTask timer;boolean returnRows,delegateClosed,rowsClosed;Object[] resultArguments;
        CheckedAction cancelIo=()->{};
        final Query query=proxy(Query.class,(proxy,method,args)->{
            if(method.getName().equals("close")){closedResources.add("query");return null;}
            throw unexpected(method);
        });
        final ResultSet rows=proxy(ResultSet.class,(proxy,method,args)->{
            if(method.getName().equals("close")){if(!rowsClosed){rowsClosed=true;closedResources.add("rows");}return null;}
            throw unexpected(method);
        });
        final QueryExecutor executor=proxy(QueryExecutor.class,(proxy,method,args)->{
            if(method.getName().equals("wrap"))return query;
            if(method.getName().equals("execute")){
                executions.incrementAndGet();var handler=(ResultHandler)args[2];
                if(returnRows)handler.handleResultRows(query,fields,tuples,cursor);else handler.handleCommandStatus("UPDATE 1",1,0);
                handler.handleCompletion();return null;
            }
            throw unexpected(method);
        });
        final BaseConnection connection=proxy(BaseConnection.class,(proxy,method,args)->switch(method.getName()) {
            case "unwrap"->proxy;
            case "getQueryExecutor"->executor;
            case "getAutoCommit"->true;
            case "hintReadOnly"->false;
            case "addTimerTask"->{timer=(TimerTask)args[0];assertEquals(1000L,args[1]);yield null;}
            case "purgeTimerTasks"->null;
            case "cancelQuery"->{cancels.incrementAndGet();cancelIo.run();yield null;}
            default->throw unexpected(method);
        });
        final BaseStatement delegate=proxy(BaseStatement.class,(proxy,method,args)->switch(method.getName()) {
            case "unwrap"->proxy;
            case "getQueryTimeout","getMaxRows"->1;
            case "getFetchSize"->0;
            case "getAdaptiveFetch"->false;
            case "createResultSet"->{resultArguments=args;yield rows;}
            case "close"->{delegateClosed=true;closedResources.add("statement");yield null;}
            default->throw unexpected(method);
        });
        Statement wrap()throws SQLException{return PostgresRawStatements.wrap(connection,delegate,queued::add);}
    }
    @SuppressWarnings("unchecked") private static <T> T proxy(Class<T> type,InvocationHandler handler){return (T)Proxy.newProxyInstance(type.getClassLoader(),new Class<?>[]{type},handler);}
    private static AssertionError unexpected(Method method){return new AssertionError("Unexpected driver operation: "+method.getName());}
}
