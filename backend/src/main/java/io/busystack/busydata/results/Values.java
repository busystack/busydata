package io.busystack.busydata.results;

import com.google.protobuf.ByteString;
import io.busystack.busydata.protocol.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.sql.*;
import java.math.*;
import java.util.*;

public final class Values {
    public static final int CELL_PREVIEW=16_384;
    private Values(){}
    public static List<Column> columns(ResultSetMetaData m)throws SQLException {
        int count=m.getColumnCount();
        if(count<1||count>2048)throw new IllegalArgumentException("Result requires 1–2048 columns");
        var out=new ArrayList<Column>(count);int bytes=0;
        for(int i=1;i<=count;i++){
            String schema=Objects.toString(m.getSchemaName(i),""),table=Objects.toString(m.getTableName(i),""),baseColumn="";
            if(m instanceof org.postgresql.PGResultSetMetaData base){schema=base.getBaseSchemaName(i);table=base.getBaseTableName(i);baseColumn=base.getBaseColumnName(i);}
            else if(m instanceof com.mysql.cj.jdbc.result.ResultSetMetaData||m instanceof org.mariadb.jdbc.client.result.ResultSetMetaData){baseColumn=Objects.toString(m.getColumnName(i),"");}
            // Generic JDBC implementations are not assumed to provide base names.
            var column=Column.newBuilder().setName(Objects.toString(m.getColumnLabel(i),""))
                .setBaseColumn(baseColumn).setOrdinal(i).setProvenanceKnown(!table.isEmpty()&&!baseColumn.isEmpty())
                .setTypeName(m.getColumnTypeName(i)).setJdbcType(m.getColumnType(i)).setPrecision(Math.max(0,m.getPrecision(i))).setScale(m.getScale(i))
                .setNullable(m.isNullable(i)!=ResultSetMetaData.columnNoNulls).setSigned(m.isSigned(i))
                .setCatalog(Objects.toString(m.getCatalogName(i),"")).setSchema(schema).setTable(table).setReadOnly(m.isReadOnly(i)).build();
            bytes+=column.getSerializedSize()+8;if(bytes>262_144)throw new IllegalArgumentException("Result column metadata exceeds 256KiB");out.add(column);
        }
        return List.copyOf(out);
    }
    public static Row row(ResultSet r,List<Column> columns)throws Exception {
        return row(r,columns,null);
    }
    public static Row row(ResultSet r,List<Column> columns,ResultStore.Result retained)throws Exception {
        var row=Row.newBuilder();int bytes=0;
        for(int i=1;i<=columns.size();i++){
            var value=value(r,i,columns.get(i-1),retained);bytes+=value.getSerializedSize()+8;
            if(bytes>262_144)throw new IOException("ROW_TOO_WIDE");row.addValues(value);
        }return row.build();
    }
    public static Value value(ResultSet r,int i,Column col)throws Exception {
        return value(r,i,col,null);
    }
    private static Value value(ResultSet r,int i,Column col,ResultStore.Result retained)throws Exception {
        var v=Value.newBuilder();String type=col.getTypeName().toLowerCase(Locale.ROOT);
        switch(col.getJdbcType()) {
            case Types.BOOLEAN->{boolean b=r.getBoolean(i);if(r.wasNull())return nil();v.setBoolean(b);}
            case Types.BIT->{
                if(r instanceof org.postgresql.jdbc.PgResultSet&&!Set.of("bool","boolean").contains(type)){
                    try(var input=r.getCharacterStream(i)){
                        if(input==null)return nil();char[] buffer=new char[CELL_PREVIEW+1];int length=0,count;
                        while(length<buffer.length&&(count=input.read(buffer,length,buffer.length-length))>0)length+=count;
                        String raw=new String(buffer,0,Math.min(length,CELL_PREVIEW));v.setEngineValue(EngineValue.newBuilder().setTypeName(col.getTypeName()).setText(raw));
                        if(length>CELL_PREVIEW){v.setTruncated(true);if(retained!=null){String id=retained.storeText(new String(buffer,0,length),input);v.setValueId(id).setOriginalBytes(java.nio.file.Files.size(retained.cell(id)));}}
                    }
                }else if(col.getPrecision()>1){byte[] bits=r.getBytes(i);if(bits==null)return nil();if(bits.length>CELL_PREVIEW)throw new SQLException("Bit field exceeds preview limit","54000");v.setBinary(ByteString.copyFrom(bits));}else{boolean b=r.getBoolean(i);if(r.wasNull())return nil();v.setBoolean(b);}}
            case Types.TINYINT,Types.SMALLINT,Types.INTEGER,Types.BIGINT->{String s=r.getString(i);if(s==null)return nil();if(col.getSigned())v.setSignedInteger(s);else v.setUnsignedInteger(s);}
            case Types.DECIMAL,Types.NUMERIC->{
                String raw=r.getString(i);if(raw==null)return nil();
                if(r instanceof org.postgresql.jdbc.PgResultSet&&Set.of("NaN","Infinity","-Infinity").contains(raw))v.setEngineValue(EngineValue.newBuilder().setTypeName(col.getTypeName()).setText(raw));
                else {BigDecimal d=r.getBigDecimal(i);if(d==null)return nil();v.setDecimal(d.toPlainString());}
            }
            case Types.REAL,Types.FLOAT,Types.DOUBLE->{double d=r.getDouble(i);if(r.wasNull())return nil();v.setReal(d);}
            case Types.BINARY,Types.VARBINARY,Types.LONGVARBINARY,Types.BLOB->{
                try(var in=r.getBinaryStream(i)){if(in==null)return nil();byte[] bytes=in.readNBytes(CELL_PREVIEW+1);v.setBinary(ByteString.copyFrom(bytes,0,Math.min(bytes.length,CELL_PREVIEW)));if(bytes.length>CELL_PREVIEW){v.setTruncated(true);if(retained!=null){String id=retained.storeBinary(bytes,in);v.setValueId(id).setOriginalBytes(java.nio.file.Files.size(retained.cell(id)));}}}
            }
            case Types.DATE,Types.TIME,Types.TIMESTAMP,Types.TIME_WITH_TIMEZONE,Types.TIMESTAMP_WITH_TIMEZONE->{String s=r.getString(i);if(s==null)return nil();
                // MySQL/MariaDB TIME is a signed duration, and PostgreSQL also
                // permits 24:00:00. LocalTime would silently normalize or reject
                // these exact values before they reach the retained result.
                if(col.getJdbcType()==Types.TIME&&(!(r instanceof org.postgresql.jdbc.PgResultSet)||s.startsWith("24:00:00"))){
                    if(type.equals("timetz")&&s.startsWith("24:00:00"))v.setEngineValue(EngineValue.newBuilder().setTypeName(col.getTypeName()).setText(s));
                    else v.setTemporal(Temporal.newBuilder().setIso(s).setKind(type).setZone("local, no timezone"));break;
                }
                try{boolean timestampZone=type.equals("timestamptz")||col.getJdbcType()==Types.TIMESTAMP_WITH_TIMEZONE;boolean timeZone=type.equals("timetz")||col.getJdbcType()==Types.TIME_WITH_TIMEZONE;String iso=timestampZone?r.getObject(i,java.time.OffsetDateTime.class).toString():timeZone?r.getObject(i,java.time.OffsetTime.class).toString():switch(col.getJdbcType()){case Types.DATE->r.getObject(i,java.time.LocalDate.class).toString();case Types.TIME->r.getObject(i,java.time.LocalTime.class).toString();default->r.getObject(i,java.time.LocalDateTime.class).toString();};if(s.equals("infinity")||s.equals("-infinity"))throw new IllegalArgumentException();v.setTemporal(Temporal.newBuilder().setIso(iso).setKind(type).setZone(timestampZone||timeZone?"offset in value":"local, no timezone"));}catch(SQLException|IllegalArgumentException|java.time.DateTimeException e){v.setEngineValue(EngineValue.newBuilder().setTypeName(col.getTypeName()).setText(s));}}
            case Types.ARRAY->{
                Object a=r.getObject(i);if(a==null)return nil();var sqlArray=(java.sql.Array)a;
                try{
                    String nativeLiteral="",elementType="";ByteString nativeBinary=ByteString.EMPTY;
                    if(sqlArray instanceof org.postgresql.jdbc.PgArray pg){
                        if(pg.isBinary()){
                            byte[] raw=pg.toBytes();if(raw==null)throw new SQLException("Native array bytes are unavailable","22000");
                            ArrayParameters.preflightBinary(java.nio.ByteBuffer.wrap(raw));nativeBinary=ByteString.copyFrom(raw);
                        }else{
                            nativeLiteral=pg.toString();if(nativeLiteral==null)throw new SQLException("Native array text is unavailable","22000");
                            preflightArrayText(new StringReader(nativeLiteral));
                        }
                        elementType=pg.getBaseTypeName();
                    }else preflightArray(r,i);
                    var structured=arrayObject(sqlArray.getArray(),0,new int[]{1024});if(!structured.hasArray())throw new SQLException("Array field has no structured array representation","22000");
                    return structured.toBuilder().setArray(structured.getArray().toBuilder().setNativeLiteral(nativeLiteral).setElementNativeType(elementType).setNativeBinary(nativeBinary)).build();
                }finally{sqlArray.free();}
            }
            default->{
                try(var in=r.getCharacterStream(i)) {
                    if(in==null)return nil();var text=new StringBuilder();char[] buffer=new char[1024];int count;
                    while(text.length()<=CELL_PREVIEW&&(count=in.read(buffer,0,Math.min(buffer.length,CELL_PREVIEW+1-text.length())))>0)text.append(buffer,0,count);
                    boolean truncated=text.length()>CELL_PREVIEW;
                    if(truncated&&retained!=null){String id=retained.storeText(text.toString(),in);v.setValueId(id).setOriginalBytes(java.nio.file.Files.size(retained.cell(id)));}
                    if(truncated)text.setLength(Character.isHighSurrogate(text.charAt(CELL_PREVIEW-1))?CELL_PREVIEW-1:CELL_PREVIEW);
                    String s=text.toString();v.setTruncated(truncated);
                    if(type.equals("json")||type.equals("jsonb"))v.setJson(s);
                    else if(col.getJdbcType()==Types.OTHER)v.setEngineValue(EngineValue.newBuilder().setTypeName(col.getTypeName()).setText(s));else v.setText(s);
                } catch(SQLFeatureNotSupportedException e){Object o=r.getObject(i);if(o==null)return nil();String s=o.toString();v.setEngineValue(EngineValue.newBuilder().setTypeName(col.getTypeName()).setText(s.substring(0,Math.min(s.length(),CELL_PREVIEW)))).setTruncated(s.length()>CELL_PREVIEW);}
            }
        }return v.build();
    }
    private static void preflightArray(ResultSet result,int ordinal)throws SQLException,IOException {
        // pgJDBC Array.getArray() expands every element before application
        // preview limits can apply. Bound its raw field before that allocation.
        try(var input=result.getCharacterStream(ordinal)) {
            if(input==null)return;
            preflightArrayText(input);
        }
    }
    private static void preflightArrayText(Reader input)throws SQLException,IOException {
            int depth=0,elements=0,characters=0;boolean quoted=false,escape=false;
            char[] buffer=new char[1024];int size;
            while((size=input.read(buffer))!=-1)for(int i=0;i<size;i++) {
                if(++characters>CELL_PREVIEW)throw new SQLException("Array field exceeds 16Ki UTF-16 units; select a bounded slice or unnest explicitly","54000");
                char c=buffer[i];if(quoted){if(escape)escape=false;else if(c=='\\')escape=true;else if(c=='"')quoted=false;continue;}
                if(c=='"')quoted=true;
                else if(c=='{'&&++depth>16)throw new SQLException("Array nesting exceeds 16 levels","54000");
                else if(c=='}')depth--;
                else if(c==','&&++elements>=1024)throw new SQLException("Array field exceeds 1024 elements; select a bounded slice or unnest explicitly","54000");
            }
    }
    private static Value arrayObject(Object o,int depth,int[] remaining){
        if(o==null)return nil();var b=Value.newBuilder();
        if(depth>16||remaining[0]--<=0)return b.setText("[array preview limit]").setTruncated(true).build();
        if(o instanceof BigDecimal d)b.setDecimal(d.toPlainString());
        else if(o instanceof Float||o instanceof Double)b.setReal(((Number)o).doubleValue());
        else if(o instanceof Number)b.setSignedInteger(o.toString());
        else if(o instanceof Boolean bool)b.setBoolean(bool);
        else if(o instanceof byte[] bytes)b.setBinary(ByteString.copyFrom(bytes,0,Math.min(bytes.length,CELL_PREVIEW))).setTruncated(bytes.length>CELL_PREVIEW);
        else if(o.getClass().isArray()){
            int length=java.lang.reflect.Array.getLength(o);var array=ArrayValue.newBuilder();
            for(int i=0;i<length&&remaining[0]>0;i++)array.addValues(arrayObject(java.lang.reflect.Array.get(o,i),depth+1,remaining));
            b.setArray(array).setTruncated(array.getValuesCount()<length||array.getValuesList().stream().anyMatch(Value::getTruncated));
        }else{String text=o.toString();int end=Math.min(text.length(),CELL_PREVIEW);if(end<text.length()&&Character.isHighSurrogate(text.charAt(end-1)))end--;b.setText(text.substring(0,end)).setTruncated(end<text.length());}
        return b.build();
    }
    public static Value nil(){return Value.newBuilder().setNullValue(Null.getDefaultInstance()).build();}
    public static String text(Value v){return switch(v.getDataCase()){case NULL_VALUE->"NULL";case BOOLEAN->Boolean.toString(v.getBoolean());case SIGNED_INTEGER->v.getSignedInteger();case UNSIGNED_INTEGER->v.getUnsignedInteger();case DECIMAL->v.getDecimal();case REAL->Double.toString(v.getReal());case TEXT->v.getText();case BINARY->HexFormat.of().formatHex(v.getBinary().toByteArray());case TEMPORAL->v.getTemporal().getIso();case JSON->v.getJson();case ENGINE_VALUE->v.getEngineValue().getText();case ARRAY->{
        if(v.getTruncated()||!v.getArray().getNativeBinary().isEmpty()||v.getArray().getNativeLiteral().isEmpty())throw new IllegalArgumentException("Exact native array text is unavailable; select an explicit server-side textual projection");
        yield v.getArray().getNativeLiteral();
    }default->"";};}
    private static void bindTemporal(PreparedStatement statement,int index,Temporal temporal,int jdbcType)throws SQLException {
        String raw=temporal.getIso(),kind=temporal.getKind().toLowerCase(Locale.ROOT);
        try{
            if(kind.equals("timestamptz")||kind.contains("timestamp with time zone")||jdbcType==Types.TIMESTAMP_WITH_TIMEZONE)statement.setObject(index,java.time.OffsetDateTime.parse(raw));
            else if(kind.equals("timetz")||kind.contains("time with time zone")||jdbcType==Types.TIME_WITH_TIMEZONE){
                if(raw.startsWith("24:00:00")&&statement.getConnection() instanceof org.postgresql.core.BaseConnection){var exact=new org.postgresql.util.PGobject();exact.setType("timetz");exact.setValue(raw);statement.setObject(index,exact);}
                else statement.setObject(index,java.time.OffsetTime.parse(raw));
            }
            else if(jdbcType==Types.DATE)statement.setObject(index,java.time.LocalDate.parse(raw));
            else if(jdbcType==Types.TIMESTAMP)statement.setObject(index,java.time.LocalDateTime.parse(raw));
            else if(jdbcType==Types.TIME){
                if(statement.getConnection() instanceof org.postgresql.core.BaseConnection){
                    if(raw.startsWith("24:00:00")){var exact=new org.postgresql.util.PGobject();exact.setType("time");exact.setValue(raw);statement.setObject(index,exact);}
                    else statement.setObject(index,java.time.LocalTime.parse(raw));
                }else statement.setString(index,raw); // Native signed TIME duration, not a clock time.
            }else throw new SQLFeatureNotSupportedException("Temporal parameter type is unavailable","0A000");
        }catch(java.time.DateTimeException malformed){throw new SQLException("Invalid exact temporal parameter","22007");}
    }
    public static void bind(PreparedStatement s,int index,Value v,int jdbcType)throws SQLException {
        if(v.getTruncated())throw new IllegalArgumentException("Truncated values cannot authorize edits");
        switch(v.getDataCase()) {
            case NULL_VALUE->s.setNull(index,jdbcType);
            case BOOLEAN->s.setBoolean(index,v.getBoolean());
            case SIGNED_INTEGER->s.setBigDecimal(index,new BigDecimal(v.getSignedInteger()));
            case UNSIGNED_INTEGER->{
                var exact=new java.math.BigInteger(v.getUnsignedInteger());
                if(s.getConnection() instanceof com.mysql.cj.jdbc.JdbcConnection)s.unwrap(com.mysql.cj.jdbc.JdbcPreparedStatement.class).setBigInteger(index,exact);
                else if(s.getConnection() instanceof org.mariadb.jdbc.Connection)s.setObject(index,exact);
                else s.setBigDecimal(index,new BigDecimal(exact));
            }
            case DECIMAL->s.setBigDecimal(index,new BigDecimal(v.getDecimal()));
            case REAL->s.setDouble(index,v.getReal());
            case BINARY->s.setBytes(index,v.getBinary().toByteArray());
            case TEMPORAL->bindTemporal(s,index,v.getTemporal(),jdbcType);
            case ENGINE_VALUE->{if(s.getConnection() instanceof org.postgresql.core.BaseConnection)s.setObject(index,text(v),Types.OTHER);else s.setString(index,text(v));}
            case TEXT,JSON->s.setObject(index,text(v),jdbcType);
            default->throw new IllegalArgumentException("Unsupported parameter type");
        }
    }
}
