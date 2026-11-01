package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.results.*;
import java.nio.file.Path;
import java.sql.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

/** Exact native calendar round trips through production retention and SQL copy. */
class TemporalSqlCopyIT {
    @TempDir Path root;
    @Test void postgresTemporalCopyRoundTripsBcExtendedYearsAndDriverDecodeLimits()throws Exception {
        try(var fixture=new EngineFixture(root,"POSTGRESQL")){
            var session=fixture.open();
            String[][] cases={
                {"date","0001-01-01 BC"},{"date","0002-02-28 BC"},{"date","0001-02-29 BC"},
                {"date","10000-01-01"},{"date","5874896-12-31"},{"date","2024-02-29"},{"date","infinity"},
                {"timestamp","0001-01-01 12:34:56.123456 BC"},{"timestamp","0002-12-31 23:59:59.999999 BC"},
                {"timestamp","10000-01-01 00:00:00"},{"timestamp","294275-12-31 23:59:59.999999"},
                {"timestamp","2024-02-29 12:34:56.123456"},{"timestamp","-infinity"},
                {"timestamptz","0001-01-01 12:34:56.123456+00 BC"},{"timestamptz","0002-01-01 00:00:01-05:30:45 BC"},
                {"timestamptz","10000-01-01 00:00:00+00"},{"timestamptz","2024-02-29 12:34:56.123456+05:30:45"},
                {"timetz","12:34:56.123456-05:30:45"},{"time","24:00:00"}};
            for(boolean prepared:new boolean[]{false,true})for(var item:cases){
                String expression=item[0]+" '"+item[1]+"'";
                Value retained=read(session.connection,expression,prepared);
                if(!prepared&&item[1].equals("0001-02-29 BC")){
                    assertTrue(retained.hasEngineValue());assertEquals(item[1],retained.getEngineValue().getText());
                }
                String copied=SqlCopy.literal(Engine.POSTGRESQL,retained);
                try(var statement=session.connection.createStatement();var rows=statement.executeQuery("SELECT CAST("+copied+" AS "+item[0]+") = "+expression)){
                    assertTrue(rows.next());assertTrue(rows.getBoolean(1),expression+" prepared="+prepared+" copied="+copied);
                }
            }
        }
    }
    private static Value read(Connection connection,String expression,boolean prepared)throws Exception {
        if(!prepared)try(var statement=connection.createStatement();var rows=statement.executeQuery("SELECT "+expression)){
            assertTrue(rows.next());return Values.value(rows,1,Values.columns(rows.getMetaData()).getFirst());
        }
        try(var statement=connection.prepareStatement("SELECT "+expression)){
            statement.unwrap(org.postgresql.PGStatement.class).setPrepareThreshold(1);Value value=null;
            for(int attempt=0;attempt<2;attempt++)try(var rows=statement.executeQuery()){
                assertTrue(rows.next());value=Values.value(rows,1,Values.columns(rows.getMetaData()).getFirst());
            }
            return value;
        }
    }
}
