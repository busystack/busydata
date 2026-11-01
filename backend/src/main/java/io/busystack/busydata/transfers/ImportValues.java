package io.busystack.busydata.transfers;

import java.math.*;
import java.sql.*;
import java.time.*;
import java.util.HexFormat;

/** Explicit conversions avoid driver-specific silent text-to-number coercion. */
public final class ImportValues {
    private ImportValues() {}
    public static void bind(PreparedStatement statement,int index,String text,int type)throws SQLException {
        if(text==null){statement.setNull(index,type);return;}
        if(text.length()>262_144)throw new IllegalArgumentException("Import cell exceeds 256Ki UTF-16 units");
        try {
            switch(type) {
                case Types.TINYINT,Types.SMALLINT,Types.INTEGER,Types.BIGINT -> {
                    BigInteger integer=new BigDecimal(text).toBigIntegerExact();
                    if(integer.bitLength()>64)throw new IllegalArgumentException("Integer exceeds 64 bits");
                    statement.setBigDecimal(index,new BigDecimal(integer));
                }
                case Types.NUMERIC,Types.DECIMAL -> statement.setBigDecimal(index,new BigDecimal(text));
                case Types.REAL,Types.FLOAT,Types.DOUBLE -> {
                    double value=Double.parseDouble(text);
                    if(!Double.isFinite(value))throw new IllegalArgumentException("Non-finite numeric import value");
                    statement.setDouble(index,value);
                }
                case Types.BOOLEAN,Types.BIT -> {
                    if(!text.equalsIgnoreCase("true")&&!text.equalsIgnoreCase("false")&&!text.equals("0")&&!text.equals("1"))throw new IllegalArgumentException("Boolean must be true, false, 0, or 1");
                    statement.setBoolean(index,text.equalsIgnoreCase("true")||text.equals("1"));
                }
                case Types.DATE -> statement.setObject(index,LocalDate.parse(text));
                case Types.TIME -> statement.setObject(index,LocalTime.parse(text));
                case Types.TIMESTAMP -> statement.setObject(index,LocalDateTime.parse(text.replace(' ','T')));
                case Types.TIME_WITH_TIMEZONE -> statement.setObject(index,OffsetTime.parse(text));
                case Types.TIMESTAMP_WITH_TIMEZONE -> statement.setObject(index,OffsetDateTime.parse(text.replace(' ','T')));
                case Types.BINARY,Types.VARBINARY,Types.LONGVARBINARY,Types.BLOB -> statement.setBytes(index,HexFormat.of().parseHex(text));
                default -> statement.setObject(index,text,type);
            }
        }catch(IllegalArgumentException|ArithmeticException|java.time.format.DateTimeParseException failure){
            // Do not place source values (which may contain credentials) in errors.
            throw new IllegalArgumentException("Import conversion failed for mapped column "+index+" (JDBC type "+type+")",failure);
        }
    }
}
