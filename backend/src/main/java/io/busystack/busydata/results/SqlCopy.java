package io.busystack.busydata.results;

import io.busystack.busydata.protocol.*;
import java.nio.charset.StandardCharsets;
import java.util.HexFormat;

/** Dialect-aware SQL VALUES serialization of retained data. Never executes SQL. */
public final class SqlCopy {
    private SqlCopy() {}
    @FunctionalInterface public interface SourceRows {long sourceRow(long row)throws Exception;}
    public static String range(ResultStore.Result result,CopySqlRequest request)throws Exception {return range(result,request,result.rows(),row->row);}
    public static String range(ResultStore.Result result,CopySqlRequest request,long available,SourceRows mapping)throws Exception {
        int rows=request.getRowCount(),columns=request.getColumnCount(),firstColumn=request.getFirstColumn();long first=request.getFirstRow();
        if(rows<1||columns<1||(long)rows*columns>10_000||first<0||first>available-rows||firstColumn<0||firstColumn>result.columns.size()-columns)throw new IllegalArgumentException("Choose 1–10,000 cells within retained rows and columns");
        var output=new StringBuilder();int bytes=0;
        for(int row=0;row<rows;row++){
            var values=result.read(mapping.sourceRow(first+row));String separator=row==0?"(":",\n(";output.append(separator);bytes+=separator.length();
            for(int column=firstColumn;column<firstColumn+columns;column++){
                String literal=literal(result.targetProfile.getEngine(),values.getValues(column));
                if(column!=firstColumn){output.append(", ");bytes+=2;}
                bytes+=literal.getBytes(StandardCharsets.UTF_8).length;
                if(bytes>1_048_576)throw new IllegalArgumentException("SQL copy exceeds 1MiB; export retained data instead");
                output.append(literal);
            }
            output.append(')');if(++bytes>1_048_576)throw new IllegalArgumentException("SQL copy exceeds 1MiB; export retained data instead");
        }
        return output.toString();
    }
    public static String literal(Engine engine,Value value){
        if(engine!=Engine.POSTGRESQL&&engine!=Engine.MYSQL&&engine!=Engine.MARIADB)throw new IllegalArgumentException("SQL copy requires a supported source engine");
        if(value.getTruncated())throw new IllegalArgumentException("A truncated preview is not a SQL value; export the full retained cell instead");
        return switch(value.getDataCase()){
            case NULL_VALUE->"NULL";
            case BOOLEAN->value.getBoolean()?"TRUE":"FALSE";
            case SIGNED_INTEGER->number(value.getSignedInteger());
            case UNSIGNED_INTEGER->number(value.getUnsignedInteger());
            case DECIMAL->number(value.getDecimal());
            case REAL->{double number=value.getReal();if(Double.isFinite(number))yield Double.toString(number);if(engine!=Engine.POSTGRESQL)throw new IllegalArgumentException("Non-finite SQL literals are unsupported for this engine");yield string(engine,Double.toString(number))+"::double precision";}
            case TEXT->string(engine,value.getText());
            case BINARY->{String hex=HexFormat.of().formatHex(value.getBinary().toByteArray());yield engine==Engine.POSTGRESQL?"decode('"+hex+"','hex')":"X'"+hex+"'";}
            case TEMPORAL->string(engine,temporal(engine,value.getTemporal()));
            case JSON->string(engine,value.getJson());
            case ENGINE_VALUE->string(engine,value.getEngineValue().getText());
            case ARRAY->{
                if(engine!=Engine.POSTGRESQL)throw new IllegalArgumentException("SQL array copy is unsupported for this engine");
                try{ArrayParameters.validate(value);}catch(java.sql.SQLException unavailable){throw new IllegalArgumentException("Complete retained native array evidence is required for SQL copy");}
                if(value.getArray().getNativeLiteral().isEmpty())throw new IllegalArgumentException("SQL copy of a binary-only retained array is unavailable; export its exact retained value");
                // Preserve the existing SQL unknown-string contract. The target
                // column supplies its verified type; never infer a cast from a
                // display/native name that may be shadowed in another schema.
                yield string(engine,value.getArray().getNativeLiteral());
            }
            case DATA_NOT_SET->throw new IllegalArgumentException("Unset typed value cannot be copied as SQL");
        };
    }
    private static String temporal(Engine engine,Temporal temporal){
        String iso=temporal.getIso();
        if(engine!=Engine.POSTGRESQL)return iso;
        int separator=iso.indexOf('T');String dateText=separator<0?iso:iso.substring(0,separator);
        if(!dateText.matches("[+-]?[0-9]{4,}-[0-9]{2}-[0-9]{2}"))return iso;
        java.time.LocalDate date;
        try{date=java.time.LocalDate.parse(dateText);}catch(java.time.DateTimeException invalid){throw new IllegalArgumentException("Invalid retained ISO date representation",invalid);}
        int year=date.getYear();if(year>=1&&year<=9999)return iso;
        // java.time uses proleptic year zero and signed extended years. Native
        // PostgreSQL input uses an unsigned year of era, with BC after any offset.
        int yearOfEra=year<=0?1-year:year;String digits=Integer.toString(yearOfEra);
        String nativeDate="0".repeat(Math.max(0,4-digits.length()))+digits+dateText.substring(dateText.length()-6);
        return nativeDate+iso.substring(dateText.length())+(year<=0?" BC":"");
    }
    private static String number(String text){if(!text.matches("[+-]?[0-9]+(?:\\.[0-9]+)?(?:[eE][+-]?[0-9]+)?"))throw new IllegalArgumentException("Invalid numeric representation");return text;}
    private static String string(Engine engine,String text){
        if(engine==Engine.POSTGRESQL)return "E'"+text.replace("\\","\\\\").replace("'","''")+"'";
        // Hex text avoids dependence on NO_BACKSLASH_ESCAPES and preserves UTF-8.
        if(text.isEmpty())return "''";
        return "CONVERT(X'"+HexFormat.of().formatHex(text.getBytes(StandardCharsets.UTF_8))+"' USING utf8mb4)";
    }
}
