package io.busystack.busydata.metadata;

import io.busystack.busydata.adapters.JdbcAdapter;
import io.busystack.busydata.protocol.Engine;
import io.grpc.Context;
import java.lang.reflect.*;
import java.sql.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class NativeIdentifierContextTest {
    private record Row(Integer mode,String version,Integer insensitiveFilesystem){}
    private static final class Header {
        List<Row> rows=List.of(new Row(1,"native-version",0));int cursor=-1,prepared,timeout,maxRows;boolean wasNull,statementClosed,resultClosed;String sql,warning="";
        Connection connection(){return proxy(Connection.class,(object,method,args)->switch(method.getName()){
            case "prepareStatement"->{prepared++;sql=(String)args[0];yield statement();}
            case "clearWarnings"->null;
            case "getWarnings"->warning.equals("connection")?new SQLWarning("sensitive native detail","01004"):null;
            case "close","abort"->throw new AssertionError("The header reader does not own connection cleanup");
            default->throw new UnsupportedOperationException(method.getName());
        });}
        PreparedStatement statement(){return proxy(PreparedStatement.class,(object,method,args)->switch(method.getName()){
            case "setQueryTimeout"->{timeout=(int)args[0];yield null;}
            case "setMaxRows"->{maxRows=(int)args[0];yield null;}
            case "setFetchSize"->null;
            case "executeQuery"->result();
            case "getWarnings"->warning.equals("statement")?new SQLWarning("sensitive native detail","01004"):null;
            case "close"->{statementClosed=true;yield null;}
            default->throw new UnsupportedOperationException(method.getName());
        });}
        ResultSet result(){return proxy(ResultSet.class,(object,method,args)->switch(method.getName()){
            case "next"->++cursor<rows.size();
            case "getInt"->{int column=(Integer)args[0];if(column!=1&&column!=3)throw new UnsupportedOperationException("Unexpected integer header column");var value=column==1?rows.get(cursor).mode():rows.get(cursor).insensitiveFilesystem();wasNull=value==null;yield value==null?0:value;}
            case "wasNull"->wasNull;
            case "getString"->{if(!Integer.valueOf(2).equals(args[0]))throw new UnsupportedOperationException("Unexpected version header column");yield rows.get(cursor).version();}
            case "getWarnings"->warning.equals("result")?new SQLWarning("sensitive native detail","01004"):null;
            case "close"->{resultClosed=true;yield null;}
            default->throw new UnsupportedOperationException(method.getName());
        });}
    }
    @SuppressWarnings("unchecked") private static <T>T proxy(Class<T> type,InvocationHandler handler){return (T)Proxy.newProxyInstance(type.getClassLoader(),new Class<?>[]{type},handler);}
    @Test void postgresNeedsNoHeaderQuery()throws Exception{
        var header=new Header();var context=NativeIdentifierCaseReader.identity(new JdbcAdapter(Engine.POSTGRESQL),header.connection());
        assertEquals(new IdentifierRules.ServerIdentity(Engine.POSTGRESQL,0,"",false),context);assertEquals(0,header.prepared);
    }
    @Test void initialPhysicalHeaderIsExactBoundedAndOwnsOnlyItsStatement()throws Exception{
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB)){
            var header=new Header();var context=NativeIdentifierCaseReader.identity(new JdbcAdapter(engine),header.connection());
            assertEquals(new IdentifierRules.ServerIdentity(engine,1,"native-version",false),context);
            assertEquals("SELECT @@lower_case_table_names,VERSION(),@@lower_case_file_system",header.sql);assertEquals(1,header.prepared);
            assertEquals(5,header.timeout);assertEquals(2,header.maxRows);assertTrue(header.statementClosed);assertTrue(header.resultClosed);
        }
    }
    @Test void missingNullInvalidAndExtraRowsNeverCertifyAPhysicalContext(){
        for(var rows:List.of(List.<Row>of(),List.of(new Row(null,"v",0)),List.of(new Row(-1,"v",0)),List.of(new Row(3,"v",0)),List.of(new Row(0,null,0)),List.of(new Row(0,"",0)),List.of(new Row(0,"v\0x",0)),List.of(new Row(0,"x".repeat(257),0)),List.of(new Row(0,"v",0),new Row(0,"v",0)),List.of(new Row(0,"v",null)),List.of(new Row(0,"v",-1)),List.of(new Row(0,"v",2)))){
            var header=new Header();header.rows=rows;
            assertThrows(SQLException.class,()->NativeIdentifierCaseReader.identity(new JdbcAdapter(Engine.MYSQL),header.connection()));
            assertTrue(header.statementClosed);assertTrue(header.resultClosed);
        }
    }
    @Test void warningsAtEveryJdbcOwnerRefuseEvidenceWithoutExposingServerText(){
        for(String owner:List.of("result","statement","connection")){
            var header=new Header();header.warning=owner;
            var failure=assertThrows(SQLException.class,()->NativeIdentifierCaseReader.identity(new JdbcAdapter(Engine.MARIADB),header.connection()));
            assertEquals("01000",failure.getSQLState());assertFalse(failure.getMessage().contains("sensitive"));assertTrue(header.statementClosed);assertTrue(header.resultClosed);
        }
    }
    @Test void cancelledConstructionDoesNotStartAJdbcHeaderQuery(){
        var header=new Header();var cancelled=Context.current().withCancellation();cancelled.cancel(null);var previous=cancelled.attach();
        try{assertThrows(java.util.concurrent.CancellationException.class,()->NativeIdentifierCaseReader.identity(new JdbcAdapter(Engine.MYSQL),header.connection()));}
        finally{cancelled.detach(previous);cancelled.close();}
        assertEquals(0,header.prepared);
    }
    @Test void nativeContextCannotBeForgedAcrossEngineModeOrServerVersion(){
        assertThrows(IllegalArgumentException.class,()->new IdentifierRules.ServerIdentity(Engine.ENGINE_UNSPECIFIED,0,"v",false));
        assertThrows(IllegalArgumentException.class,()->new IdentifierRules.ServerIdentity(Engine.POSTGRESQL,1,"",false));
        assertThrows(IllegalArgumentException.class,()->new IdentifierRules.ServerIdentity(Engine.POSTGRESQL,0,"v",false));
        assertThrows(IllegalArgumentException.class,()->new IdentifierRules.ServerIdentity(Engine.POSTGRESQL,0,"",true));
        assertThrows(IllegalArgumentException.class,()->new IdentifierRules.ServerIdentity(Engine.MYSQL,0,"",false));
        var rules=io.busystack.busydata.NativeCaseFixtures.rules(Engine.MYSQL,1,"v1");
        assertTrue(rules.matchesServer(new IdentifierRules.ServerIdentity(Engine.MYSQL,1,"v1",false)));
        assertFalse(rules.matchesServer(new IdentifierRules.ServerIdentity(Engine.MYSQL,0,"v1",false)));
        assertFalse(rules.matchesServer(new IdentifierRules.ServerIdentity(Engine.MYSQL,1,"v2",false)));
        assertFalse(rules.matchesServer(new IdentifierRules.ServerIdentity(Engine.MARIADB,1,"v1",false)));
        assertFalse(rules.matchesServer(new IdentifierRules.ServerIdentity(Engine.MYSQL,1,"v1",true)));
    }
}
