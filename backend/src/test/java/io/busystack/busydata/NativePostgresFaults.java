package io.busystack.busydata;

import java.lang.reflect.*;
import java.sql.*;
import org.postgresql.core.*;

/** Test-only observation of the pinned driver's real native transport and result factory.
 * Every execution delegates exactly once; explicit fault hooks retain real server and decoding ownership.
 */
final class NativePostgresFaults {
    interface Observer {
        default void beforeExecution(String sql)throws Exception {}
        default boolean statementCancellation()throws Exception {return false;}
        default void acknowledged(String sql)throws Exception {}
        default ResultSet result(String sql,ResultSet rows)throws Exception {return rows;}
    }
    static Connection wrap(Connection delegate,Observer observer)throws SQLException {
        var physical=delegate.unwrap(BaseConnection.class);
        var executor=proxy(QueryExecutor.class,(p,m,args)->{
            Query query=m.getName().equals("execute")&&args!=null&&args.length>0&&args[0] instanceof Query item?item:null;
            if(query!=null)observer.beforeExecution(query.getNativeSql());
            Object answer=invoke(physical.getQueryExecutor(),m,args);
            if(query!=null)observer.acknowledged(query.getNativeSql());
            return answer;
        });
        var nativeConnection=proxy(BaseConnection.class,(p,m,args)->{
            if(m.getName().equals("getQueryExecutor"))return executor;
            if(m.getName().equals("cancelQuery")&&observer.statementCancellation())return null;
            return invoke(physical,m,args);
        });
        return proxy(Connection.class,(p,m,args)->{
            if(m.getName().equals("unwrap")&&args[0]==BaseConnection.class)return nativeConnection;
            Object answer=invoke(delegate,m,args);
            if(!(answer instanceof Statement statement))return answer;
            var nativeStatement=proxy(BaseStatement.class,(sp,sm,sa)->{
                Object value=invoke(statement.unwrap(BaseStatement.class),sm,sa);
                return sm.getName().equals("createResultSet")&&value instanceof ResultSet rows&&sa[0] instanceof Query query?observer.result(query.getNativeSql(),rows):value;
            });
            Class<?> type=statement instanceof CallableStatement?CallableStatement.class:statement instanceof PreparedStatement?PreparedStatement.class:Statement.class;
            return Proxy.newProxyInstance(NativePostgresFaults.class.getClassLoader(),new Class[]{type},(sp,sm,sa)->{
                if(sm.getName().equals("unwrap")&&(sa[0]==BaseStatement.class||sa[0]==org.postgresql.PGStatement.class))return nativeStatement;
                return invoke(statement,sm,sa);
            });
        });
    }
    private static <T>T proxy(Class<T> type,InvocationHandler handler){return type.cast(Proxy.newProxyInstance(NativePostgresFaults.class.getClassLoader(),new Class[]{type},handler));}
    private static Object invoke(Object target,Method method,Object[] arguments)throws Throwable {
        try{return method.invoke(target,arguments);}catch(InvocationTargetException failure){throw failure.getCause();}
    }
}
