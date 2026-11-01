package io.busystack.busydata;

import com.google.protobuf.ByteString;
import io.busystack.busydata.protocol.ArrayValue;
import io.busystack.busydata.protocol.Value;
import io.busystack.busydata.results.ArrayParameters;
import io.busystack.busydata.results.Values;
import java.lang.reflect.Proxy;
import java.nio.ByteBuffer;
import java.sql.*;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.Test;
import org.postgresql.core.BaseConnection;
import org.postgresql.core.TypeInfo;
import static org.junit.jupiter.api.Assertions.*;

class ArrayParametersTest {
    private static final io.busystack.busydata.adapters.JdbcAdapter.LiveContext CONTEXT=new io.busystack.busydata.adapters.JdbcAdapter.LiveContext("db","public",java.util.List.of("public"),"","",true,"","",true,"ISO, MDY");
    private static Value integer(long value){return Value.newBuilder().setSignedInteger(Long.toString(value)).build();}
    private static Value text(String raw){return Value.newBuilder().setArray(ArrayValue.newBuilder().setNativeLiteral(raw).setElementNativeType("int4").addValues(integer(1)).addValues(Values.nil()).addValues(integer(3))).build();}
    private static byte[] binary(int lower){return ByteBuffer.allocate(12+8+4+4+4+4+4).putInt(1).putInt(1).putInt(23).putInt(3).putInt(lower).putInt(4).putInt(1).putInt(-1).putInt(4).putInt(3).array();}
    private static PreparedStatement statement(AtomicReference<java.sql.Array> bound,boolean fail,int resolvedOid){
        var types=(TypeInfo)Proxy.newProxyInstance(ArrayParametersTest.class.getClassLoader(),new Class[]{TypeInfo.class},(p,m,args)->switch(m.getName()){case "getPGArrayElement"->23;case "getPGType"->"int4";case "getPGArrayType"->resolvedOid;default->throw new AssertionError("Unexpected type operation: "+m.getName());});
        var connection=(BaseConnection)Proxy.newProxyInstance(ArrayParametersTest.class.getClassLoader(),new Class[]{BaseConnection.class},(p,m,args)->{if(m.getName().equals("getTypeInfo"))return types;throw new AssertionError("No SQL connection operation is permitted: "+m.getName());});
        return (PreparedStatement)Proxy.newProxyInstance(ArrayParametersTest.class.getClassLoader(),new Class[]{PreparedStatement.class},(p,m,args)->{
            if(m.getName().equals("getConnection"))return connection;if(m.getName().equals("setArray")){assertEquals(4,args[0]);bound.set((java.sql.Array)args[1]);if(fail)throw new SQLException("binding fixture");return null;}throw new AssertionError("No SQL statement operation is permitted: "+m.getName());
        });
    }
    @Test void nativeTextAndBinaryPreserveBoundsNullsAndCallerOwnedResources()throws Exception {
        var captured=new AtomicReference<java.sql.Array>();var statement=statement(captured,false,1007);
        var text=ArrayParameters.bind(statement,4,text("[0:2]={1,NULL,3}"),1007,CONTEXT);assertSame(text,captured.get());assertEquals("[0:2]={1,NULL,3}",text.toString());text.free();assertNull(text.toString());
        byte[] bytes=binary(-7);var value=text("{1,NULL,3}").toBuilder().setArray(text("{1,NULL,3}").getArray().toBuilder().clearNativeLiteral().setNativeBinary(ByteString.copyFrom(bytes))).build();
        var binary=ArrayParameters.bind(statement,4,value,1007,CONTEXT);assertArrayEquals(bytes,((org.postgresql.jdbc.PgArray)binary).toBytes());binary.free();assertNull(((org.postgresql.jdbc.PgArray)binary).toBytes());
    }
    @Test void bindingFailureFreesTheAllocatedArrayAndWrongTypeDoesNotBind(){
        var captured=new AtomicReference<java.sql.Array>();assertThrows(SQLException.class,()->ArrayParameters.bind(statement(captured,true,1007),4,text("{1,NULL,3}"),1007,CONTEXT));assertNotNull(captured.get());assertNull(captured.get().toString());
        captured.set(null);assertThrows(SQLFeatureNotSupportedException.class,()->ArrayParameters.bind(statement(captured,false,1009),4,text("{1,NULL,3}"),1007,CONTEXT));assertNull(captured.get());
    }
    @Test void textContextGuardsRejectChangedNullAndDatetimeInterpretationWithoutSql()throws Exception {
        var off=new io.busystack.busydata.adapters.JdbcAdapter.LiveContext("db","public",java.util.List.of("public"),"","",true,"","",false,"ISO, MDY");var sql=new io.busystack.busydata.adapters.JdbcAdapter.LiveContext("db","public",java.util.List.of("public"),"","",true,"","",true,"SQL, DMY");
        assertThrows(SQLFeatureNotSupportedException.class,()->ArrayParameters.requireContext(text("{NULL}"),off,"text"));assertThrows(SQLFeatureNotSupportedException.class,()->ArrayParameters.requireContext(text("{2024-01-02}"),sql,"date"));assertThrows(SQLFeatureNotSupportedException.class,()->ArrayParameters.requireContext(text("{1day}"),CONTEXT,"interval"));ArrayParameters.requireContext(text("{1,NULL,3}"),sql,"int4");
        var captured=new AtomicReference<java.sql.Array>();assertThrows(SQLFeatureNotSupportedException.class,()->ArrayParameters.bind(statement(captured,false,1007),4,text("{1,NULL,3}"),1007,off));assertNull(captured.get());
        var nativeBinary=Value.newBuilder().setArray(ArrayValue.newBuilder().setNativeBinary(ByteString.copyFrom(binary(-7))).addValues(integer(1)).addValues(Values.nil()).addValues(integer(3))).build();ArrayParameters.requireContext(nativeBinary,off,"date");
    }
    @Test void missingAmbiguousTruncatedAndUnknownEvidenceCannotAuthorizeBinding(){
        var plain=Value.newBuilder().setArray(ArrayValue.newBuilder().addValues(integer(1))).build();assertThrows(SQLFeatureNotSupportedException.class,()->ArrayParameters.validate(plain));
        assertThrows(SQLFeatureNotSupportedException.class,()->ArrayParameters.validate(text("{1,NULL,3}").toBuilder().setTruncated(true).build()));
        assertThrows(SQLFeatureNotSupportedException.class,()->ArrayParameters.validate(text("{1,NULL,3}").toBuilder().setArray(text("{1,NULL,3}").getArray().toBuilder().setNativeBinary(ByteString.copyFrom(binary(1)))).build()));
        assertThrows(SQLFeatureNotSupportedException.class,()->ArrayParameters.validate(text("{1}").toBuilder().setArray(text("{1}").getArray().toBuilder().clearValues().addValues(Value.getDefaultInstance())).build()));
        assertThrows(SQLFeatureNotSupportedException.class,()->ArrayParameters.bind(statement(new AtomicReference<>(),false,1007),4,text("{1,NULL,3}"),0,CONTEXT));
    }
    @Test void depthElementAndByteLimitsPrecedeJdbcBinding(){
        Value deep=integer(1);for(int i=0;i<17;i++)deep=Value.newBuilder().setArray(ArrayValue.newBuilder().addValues(deep)).build();var excessive=deep.toBuilder().setArray(deep.getArray().toBuilder().setNativeLiteral("{1}"));assertThrows(SQLException.class,()->ArrayParameters.validate(excessive.build()));
        var many=ArrayValue.newBuilder().setNativeLiteral("{1}");for(int i=0;i<1025;i++)many.addValues(integer(i));assertThrows(SQLException.class,()->ArrayParameters.validate(Value.newBuilder().setArray(many).build()));
        assertThrows(SQLException.class,()->ArrayParameters.validate(text("{"+"x".repeat(ArrayParameters.MAX_BYTES)+"}")));
        assertThrows(SQLException.class,()->ArrayParameters.preflightBinary(ByteBuffer.wrap(new byte[ArrayParameters.MAX_BYTES+1])));
        byte[] malformed=binary(1);ByteBuffer.wrap(malformed).putInt(12,1025);assertThrows(SQLException.class,()->ArrayParameters.preflightBinary(ByteBuffer.wrap(malformed)));
        assertThrows(SQLException.class,()->ArrayParameters.preflightBinary(ByteBuffer.wrap(new byte[11])));
    }
}
