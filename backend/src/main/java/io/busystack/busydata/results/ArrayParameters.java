package io.busystack.busydata.results;

import io.busystack.busydata.protocol.Value;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import java.sql.*;
import java.util.Set;
import org.postgresql.core.BaseConnection;
import org.postgresql.jdbc.PgArray;

/** PostgreSQL arrays are bound from validated or retained native evidence, never reconstructed SQL.
 * The caller verifies exact column/session/result ownership and frees the returned
 * Array after execution. A structured preview alone cannot authorize a write. */
public final class ArrayParameters {
    public static final int MAX_DEPTH=16,MAX_ELEMENTS=1024,MAX_BYTES=1_048_576;
    private ArrayParameters(){}

    public static java.sql.Array bind(PreparedStatement statement,int index,Value value,int verifiedArrayOid,io.busystack.busydata.adapters.JdbcAdapter.LiveContext context)throws SQLException {
        validate(value);
        if(verifiedArrayOid==0)throw unsupported("Verified PostgreSQL array type identity is required");
        Connection connection=statement.getConnection();
        BaseConnection base=connection instanceof BaseConnection pg?pg:connection.isWrapperFor(BaseConnection.class)?connection.unwrap(BaseConnection.class):null;
        if(base==null)throw unsupported("SQL array parameters require the PostgreSQL adapter");
        int elementOid=base.getTypeInfo().getPGArrayElement(verifiedArrayOid);
        if(elementOid==0)throw unsupported("The verified type has no available array element identity");
        String elementName=base.getTypeInfo().getPGType(elementOid);
        requireContext(value,context,elementName);
        // Pinned PgPreparedStatement.setArray resolves a base name before sending
        // a PgArray. Refuse a driver name that resolves to another identity.
        if(elementName==null||base.getTypeInfo().getPGArrayType(elementName)!=verifiedArrayOid)throw unsupported("The pinned driver cannot resolve this exact array type identity");
        var array=value.getArray();PgArray bound;
        if(!array.getNativeBinary().isEmpty()){
            byte[] bytes=array.getNativeBinary().toByteArray();
            if(ByteBuffer.wrap(bytes).order(ByteOrder.BIG_ENDIAN).getInt(8)!=elementOid)throw new SQLException("Retained array element identity changed","42804");
            bound=new PgArray(base,verifiedArrayOid,bytes);
        }else bound=new PgArray(base,verifiedArrayOid,array.getNativeLiteral());
        try{statement.setArray(index,bound);return bound;}
        catch(SQLException|RuntimeException failure){try{bound.free();}catch(SQLException cleanup){failure.addSuppressed(cleanup);}throw failure;}
    }

    /** Text I/O settings are part of parameter interpretation, never guessed
     * from an editor display. Binary arrays carry their own typed NULL bitmap. */
    public static void requireContext(Value value,io.busystack.busydata.adapters.JdbcAdapter.LiveContext context,String verifiedElementName)throws SQLFeatureNotSupportedException {
        if(!value.hasArray())throw unsupported("A native PostgreSQL array is required");
        if(!value.getArray().getNativeBinary().isEmpty())return;
        if(context==null||!context.arrayNulls()||verifiedElementName==null||verifiedElementName.isEmpty())throw unsupported("Native text array interpretation context is unavailable");
        if(verifiedElementName.equals("interval"))throw unsupported("Native interval array interpretation is unavailable");
        if(Set.of("date","timestamp","timestamptz").contains(verifiedElementName)&&!context.dateStyle().equals("ISO")&&!context.dateStyle().startsWith("ISO,"))throw unsupported("Native datetime array text requires captured ISO DateStyle");
    }

    public static void validate(Value value)throws SQLException {
        if(!value.hasArray()||value.getTruncated())throw unsupported("A complete native SQL array is required");
        var array=value.getArray();boolean text=!array.getNativeLiteral().isEmpty(),binary=!array.getNativeBinary().isEmpty();
        if(text==binary)throw unsupported("Retained native array evidence is unavailable or ambiguous");
        int bytes;
        if(binary){bytes=array.getNativeBinary().size();preflightBinary(array.getNativeBinary().asReadOnlyByteBuffer());}
        else{
            String nativeText=array.getNativeLiteral();if(nativeText.length()>MAX_BYTES)throw new SQLException("Array parameter exceeds 1MiB","54000");bytes=nativeText.getBytes(StandardCharsets.UTF_8).length;
            int start=0,end=nativeText.length();while(start<end&&io.busystack.busydata.analysis.SqlLexicalCharacters.isSpace(nativeText.charAt(start)))start++;while(end>start&&io.busystack.busydata.analysis.SqlLexicalCharacters.isSpace(nativeText.charAt(end-1)))end--;
            if(nativeText.indexOf('\0')>=0||start==end||(nativeText.charAt(start)!='{'&&nativeText.charAt(start)!='[')||nativeText.charAt(end-1)!='}')throw unsupported("Native array representation is invalid");
        }
        if(bytes>MAX_BYTES)throw new SQLException("Array parameter exceeds 1MiB","54000");
        int[] work={0,bytes,0};validateTree(value,0,work);
        if(value.getSerializedSize()>MAX_BYTES)throw new SQLException("Array parameter exceeds 1MiB","54000");
    }

    private static void validateTree(Value value,int depth,int[] work)throws SQLException {
        if(depth>MAX_DEPTH||++work[2]>MAX_ELEMENTS*MAX_DEPTH)throw new SQLException("Array parameter exceeds its depth or node budget","54000");
        if(value.getTruncated())throw unsupported("A truncated array element cannot authorize a write");
        if(value.hasArray()){
            if(depth>0&&(!value.getArray().getNativeLiteral().isEmpty()||!value.getArray().getNativeBinary().isEmpty()))throw unsupported("Nested array evidence must belong to its outer retained value");
            if(value.getArray().getValuesCount()>MAX_ELEMENTS)throw new SQLException("Array parameter exceeds 1024 elements","54000");
            for(var child:value.getArray().getValuesList())validateTree(child,depth+1,work);
        }else{
            if(++work[0]>MAX_ELEMENTS)throw new SQLException("Array parameter exceeds1024 scalar elements","54000");
            if(value.getDataCase()==Value.DataCase.DATA_NOT_SET)throw unsupported("An unknown array element cannot authorize a write");
            work[1]+=value.getSerializedSize();if(work[1]>MAX_BYTES)throw new SQLException("Array parameter exceeds 1MiB","54000");
        }
    }

    /** Validate the wire header and payload before pgJDBC expands any elements. */
    public static void preflightBinary(ByteBuffer source)throws SQLException {
        var data=source.duplicate().order(ByteOrder.BIG_ENDIAN);
        if(data.remaining()>MAX_BYTES)throw new SQLException("Array field exceeds 1MiB","54000");
        if(data.remaining()<12)throw malformed();int dimensions=data.getInt(),flags=data.getInt(),elementOid=data.getInt();
        if(dimensions<0||dimensions>MAX_DEPTH||flags<0||flags>1||elementOid==0||data.remaining()<dimensions*8)throw malformed();
        long count=dimensions==0?0:1;
        for(int i=0;i<dimensions;i++){int size=data.getInt();data.getInt();if(size<0)throw malformed();count*=size;if(count>MAX_ELEMENTS)throw new SQLException("Array field exceeds 1024 elements","54000");}
        for(long i=0;i<count;i++){if(data.remaining()<4)throw malformed();int length=data.getInt();if(length< -1||length>data.remaining())throw malformed();if(length>=0)data.position(data.position()+length);}
        if(data.hasRemaining())throw malformed();
    }
    private static SQLException malformed(){return new SQLException("Malformed retained binary array","22000");}
    private static SQLFeatureNotSupportedException unsupported(String message){return new SQLFeatureNotSupportedException(message,"0A000");}
}
