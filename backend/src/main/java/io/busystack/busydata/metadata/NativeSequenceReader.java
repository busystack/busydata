package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.sessions.SessionRegistry;
import java.sql.*;
import java.util.*;

/** Native structural sequence facts; introspection never advances a sequence. */
public final class NativeSequenceReader {
    private NativeSequenceReader(){}
    public static List<SchemaObject> enrich(SessionRegistry.Session session,List<SchemaObject> objects)throws SQLException {
        boolean pg=session.profile.getEngine()==Engine.POSTGRESQL;
        if(session.profile.getEngine()==Engine.MYSQL)throw new UnsupportedOperationException("MySQL has no native sequence objects");
        String sql=pg?"SELECT pg_catalog.format_type(seq.seqtypid,NULL) type,seq.seqtypid::text native_type_id,seq.seqstart::text start_value,seq.seqmin::text min_value,seq.seqmax::text max_value,seq.seqincrement::text increment_value,seq.seqcycle::text cycle,seq.seqcache::text cache_size FROM pg_catalog.pg_sequence seq JOIN pg_catalog.pg_class c ON c.oid=seq.seqrelid JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=? AND c.relname=?":
            "SELECT DATA_TYPE type,'' native_type_id,START_VALUE start_value,MINIMUM_VALUE min_value,MAXIMUM_VALUE max_value,INCREMENT increment_value,CYCLE_OPTION cycle,NUMERIC_PRECISION precision_value,NUMERIC_PRECISION_RADIX precision_radix,NUMERIC_SCALE scale_value FROM information_schema.SEQUENCES WHERE BINARY SEQUENCE_SCHEMA=BINARY ? AND BINARY SEQUENCE_NAME=BINARY ?";
        var result=new ArrayList<SchemaObject>(objects.size());
        for(var object:objects)try(var statement=session.adapter.catalogStatement(session.connection,sql)) {
            statement.setMaxRows(2);statement.setString(1,object.getSchema());statement.setString(2,object.getName());
            try(var rows=statement.executeQuery()){
                if(!rows.next())throw new SQLException("Sequence structure is unavailable or changed during refresh");
                var sequence=object.toBuilder().putProperties("structureAvailability","AVAILABLE").putProperties("lastValueAvailability","NOT_REQUESTED");
                for(String field:List.of("type","native_type_id","start_value","min_value","max_value","increment_value","cycle"))sequence.putProperties(switch(field){case "native_type_id"->"nativeTypeId";case "start_value"->"startValue";case "min_value"->"minValue";case "max_value"->"maxValue";case "increment_value"->"increment";default->field;},Objects.toString(rows.getString(field),""));
                if(pg)sequence.putProperties("cacheSize",rows.getString("cache_size")).putProperties("cacheSizeAvailability","AVAILABLE").putProperties("precisionAvailability","NOT_EXPOSED");
                else sequence.putProperties("precision",rows.getString("precision_value")).putProperties("precisionRadix",rows.getString("precision_radix")).putProperties("scale",rows.getString("scale_value")).putProperties("precisionAvailability","AVAILABLE").putProperties("cacheSizeAvailability","NOT_EXPOSED").putProperties("unsigned",Boolean.toString(rows.getString("type").toUpperCase(Locale.ROOT).contains("UNSIGNED")));
                if(rows.next())throw new SQLException("Sequence structure is ambiguous");result.add(sequence.build());
            }
        }
        return List.copyOf(result);
    }
}
