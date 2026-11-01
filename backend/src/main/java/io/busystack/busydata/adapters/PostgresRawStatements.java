package io.busystack.busydata.adapters;

import java.lang.reflect.InvocationHandler;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.lang.reflect.Proxy;
import java.sql.*;
import java.util.*;
import org.postgresql.core.*;

/** A single native PostgreSQL statement, without JDBC parsing or driver replay.
 * BusyData's independent execution splitter supplies the exact original SQL.
 * The pinned driver's transport, result decoder, portals and buffer limits stay
 * in use. Its char-based JDBC parser cannot recognize every native dollar tag.
 */
final class PostgresRawStatements implements InvocationHandler {
    private record Result(ResultSet rows,long count){}
    private final BaseConnection connection;
    private final BaseStatement statement;
    private final java.util.concurrent.Executor cancellationExecutor;
    private final ArrayList<Result> results=new ArrayList<>();
    private Query query;
    private SQLWarning warnings;
    private int warningCount;
    private int current;
    private long generation;
    private boolean cancellationActive;
    private volatile boolean closed;
    private TimerTask timeout;
    private PostgresRawStatements(Connection connection,Statement statement,java.util.concurrent.Executor cancellationExecutor)throws SQLException{
        this.connection=connection.unwrap(BaseConnection.class);this.statement=statement.unwrap(BaseStatement.class);this.cancellationExecutor=Objects.requireNonNull(cancellationExecutor);
    }
    static Statement wrap(Connection connection,Statement statement)throws SQLException{
        return wrap(connection,statement,task->Thread.ofVirtual().name("busydata-pg-timeout").start(task));
    }
    static Statement wrap(Connection connection,Statement statement,java.util.concurrent.Executor cancellationExecutor)throws SQLException{return (Statement)Proxy.newProxyInstance(Statement.class.getClassLoader(),new Class<?>[]{Statement.class},new PostgresRawStatements(connection,statement,cancellationExecutor));}
    private void open()throws SQLException{if(closed)throw new SQLException("Statement is closed","55000");}
    private Result result(){return current<results.size()?results.get(current):null;}
    private void cancel(long owner)throws SQLException{
        // Hold this small owner monitor across cancellation I/O. Closing the
        // statement cannot release its physical-session owner while an old
        // cancellation packet is still in flight toward that connection.
        synchronized(this){if(!closed&&cancellationActive&&generation==owner)connection.cancelQuery();}
    }
    private synchronized void stopTimeout(){cancellationActive=false;generation++;if(timeout!=null){timeout.cancel();timeout=null;connection.purgeTimerTasks();}}
    private void cancelCurrent()throws SQLException{final long owner;synchronized(this){owner=generation;}cancel(owner);}
    private void clear()throws SQLException{
        stopTimeout();SQLException failure=null;
        for(var result:results)if(result.rows()!=null)try{result.rows().close();}catch(SQLException error){if(failure==null)failure=error;else failure.addSuppressed(error);}
        results.clear();current=0;if(query!=null){query.close();query=null;}if(failure!=null)throw failure;
    }
    private boolean execute(String sql)throws SQLException{
        open();clear();warnings=null;warningCount=0;final long owner;
        synchronized(this){owner=++generation;cancellationActive=true;int seconds=statement.getQueryTimeout();if(seconds>0){
            timeout=new TimerTask(){@Override public void run(){cancellationExecutor.execute(()->{try{PostgresRawStatements.this.cancel(owner);}catch(SQLException ignored){/* The owning job still reconciles cancellation/session state. */}});}};
            connection.addTimerTask(timeout,seconds*1000L);
        }}
        var executor=connection.getQueryExecutor();
        query=executor.wrap(List.of(new NativeQuery(sql,new int[0],false,SqlCommand.BLANK)));
        var handler=new ResultHandlerBase(){
            @Override public void handleResultRows(Query source,Field[] fields,List<Tuple> tuples,ResultCursor cursor){
                try{if(results.size()>=32)throw new SQLException("Native statement result limit exceeded","54000");results.add(new Result(statement.createResultSet(source,fields,tuples,cursor),-1));}catch(SQLException failure){handleError(failure);}
            }
            @Override public void handleCommandStatus(String status,long count,long inserted){if(results.size()>=32)handleError(new SQLException("Native statement result limit exceeded","54000"));else results.add(new Result(null,count));}
            @Override public void handleWarning(SQLWarning warning){if(warningCount++>=100)return;String state=warning.getSQLState();var bounded=new SQLWarning("Database warning",state==null?null:state.substring(0,Math.min(5,state.length())),warning.getErrorCode());if(warnings==null)warnings=bounded;else warnings.setNextWarning(bounded);}
        };
        int flags=QueryExecutor.QUERY_ONESHOT|QueryExecutor.QUERY_NO_BINARY_TRANSFER;
        if(connection.getAutoCommit())flags|=QueryExecutor.QUERY_SUPPRESS_BEGIN;
        if(statement.getFetchSize()>0&&(!connection.getAutoCommit()||connection.getTransactionState()==org.postgresql.core.TransactionState.OPEN))flags|=QueryExecutor.QUERY_FORWARD_CURSOR;
        if(connection.hintReadOnly())flags|=QueryExecutor.QUERY_READ_ONLY_HINT;
        try{
            // Exactly one transport execution. PgStatement's SQLSTATE-based
            // automatic reparse/re-execute path is deliberately not entered.
            executor.execute(query,null,handler,statement.getMaxRows(),statement.getFetchSize(),flags,statement.getAdaptiveFetch());
            return result()!=null&&result().rows()!=null;
        }catch(SQLException|RuntimeException failure){try{clear();}catch(SQLException cleanup){failure.addSuppressed(cleanup);}throw failure;}
    }
    private synchronized void close()throws SQLException{
        if(closed)return;closed=true;generation++;
        try{clear();}finally{statement.close();}
    }
    @Override public Object invoke(Object proxy,Method method,Object[] arguments)throws Throwable{
        String name=method.getName();
        if(name.equals("close")){close();return null;}
        if(name.equals("isClosed"))return closed;
        if(name.equals("cancel")){cancelCurrent();return null;}
        if(name.equals("toString"))return "BusyData native PostgreSQL statement";
        if(name.equals("hashCode"))return System.identityHashCode(proxy);
        if(name.equals("equals"))return proxy==arguments[0];
        if(name.equals("unwrap")&&((Class<?>)arguments[0]).isInstance(proxy))return proxy;
        if(name.equals("isWrapperFor")&&((Class<?>)arguments[0]).isInstance(proxy))return true;
        open();
        if(Set.of("execute","executeQuery","executeUpdate","executeLargeUpdate").contains(name)){
            if(arguments==null||arguments.length!=1||!(arguments[0] instanceof String sql))throw new SQLFeatureNotSupportedException("Native SQL does not request generated keys","0A000");
            boolean rows=execute(sql);
            if(name.equals("execute"))return rows;
            if(name.equals("executeQuery")){if(!rows)throw new SQLException("Statement returned no rows","02000");return result().rows();}
            if(rows)throw new SQLException("Statement returned rows","0100E");long count=result()==null?0:result().count();
            if(name.equals("executeLargeUpdate"))return count;
            return count>Integer.MAX_VALUE?Statement.SUCCESS_NO_INFO:(int)count;
        }
        if(name.equals("getResultSet"))return result()==null?null:result().rows();
        if(name.equals("getLargeUpdateCount"))return result()==null?-1L:result().count();
        if(name.equals("getUpdateCount")){long count=result()==null?-1:result().count();return count>Integer.MAX_VALUE?Statement.SUCCESS_NO_INFO:(int)count;}
        if(name.equals("getMoreResults")){
            if(arguments!=null&&arguments.length==1&&(int)arguments[0]==Statement.KEEP_CURRENT_RESULT)throw new SQLFeatureNotSupportedException("Native results have one paging owner","0A000");
            var prior=result();if(prior!=null&&prior.rows()!=null)prior.rows().close();current++;
            if(result()==null)stopTimeout();return result()!=null&&result().rows()!=null;
        }
        if(name.equals("getWarnings"))return warnings;
        if(name.equals("clearWarnings")){warnings=null;return null;}
        if(Set.of("addBatch","executeBatch","executeLargeBatch","getGeneratedKeys","closeOnCompletion").contains(name))throw new SQLFeatureNotSupportedException("Unsupported native statement operation","0A000");
        try{return method.invoke(statement,arguments);}catch(InvocationTargetException failure){throw failure.getCause();}
    }
}
