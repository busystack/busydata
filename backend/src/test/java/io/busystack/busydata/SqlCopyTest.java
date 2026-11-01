package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.results.*;
import com.google.protobuf.ByteString;
import java.nio.file.Path;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

class SqlCopyTest {
    @TempDir Path directory;
    @Test void typedLiteralsKeepBooleanBinaryDecimalAndEscapeSemantics(){
        assertEquals("TRUE",SqlCopy.literal(Engine.MYSQL,Value.newBuilder().setBoolean(true).build()));
        assertEquals("X'00ff'",SqlCopy.literal(Engine.MARIADB,Value.newBuilder().setBinary(ByteString.copyFrom(new byte[]{0,(byte)255})).build()));
        assertEquals("decode('00ff','hex')",SqlCopy.literal(Engine.POSTGRESQL,Value.newBuilder().setBinary(ByteString.copyFrom(new byte[]{0,(byte)255})).build()));
        assertEquals("12345678901234567890.123456789",SqlCopy.literal(Engine.POSTGRESQL,Value.newBuilder().setDecimal("12345678901234567890.123456789").build()));
        assertEquals("E'back\\\\slash''quote'",SqlCopy.literal(Engine.POSTGRESQL,Value.newBuilder().setText("back\\slash'quote").build()));
        assertEquals("CONVERT(X'5c27' USING utf8mb4)",SqlCopy.literal(Engine.MYSQL,Value.newBuilder().setText("\\'").build()));
        assertThrows(IllegalArgumentException.class,()->SqlCopy.literal(Engine.MYSQL,Value.newBuilder().setText("preview").setTruncated(true).build()));
    }
    @Test void rangeRejectsOutOfBoundsAndExcessiveClipboardBytes()throws Exception {
        try(var store=new ResultStore(directory,4*1024*1024)){
            var result=store.create(List.of(Column.newBuilder().setName("text").build()),Profile.newBuilder().setEngine(Engine.MYSQL).build(),"session");
            for(int i=0;i<40;i++)result.append(Row.newBuilder().addValues(Value.newBuilder().setText("x".repeat(16384))).build());
            assertThrows(IllegalArgumentException.class,()->SqlCopy.range(result,CopySqlRequest.newBuilder().setRowCount(40).setColumnCount(1).build()));
            assertThrows(IllegalArgumentException.class,()->SqlCopy.range(result,CopySqlRequest.newBuilder().setFirstRow(40).setRowCount(1).setColumnCount(1).build()));
            assertThrows(IllegalArgumentException.class,()->SqlCopy.range(result,CopySqlRequest.newBuilder().setFirstColumn(1).setRowCount(1).setColumnCount(1).build()));
        }
    }
    @Test void postgresTemporalCopyUsesNativeErasAndUnsignedExtendedYears(){
        String[][] dates={
            {"0000-01-01","0001-01-01 BC"},{"-0001-02-28","0002-02-28 BC"},
            {"0000-02-29","0001-02-29 BC"},{"+10000-01-01","10000-01-01"},
            {"+5874896-12-31","5874896-12-31"},
            {"0000-01-01T12:34:56.123456","0001-01-01T12:34:56.123456 BC"},
            {"-0001-01-01T05:30:46Z","0002-01-01T05:30:46Z BC"},
            {"0000-01-01T12:34:56.123456-05:30:45","0001-01-01T12:34:56.123456-05:30:45 BC"},
            {"+294275-12-31T23:59:59.999999","294275-12-31T23:59:59.999999"}};
        for(var pair:dates){
            var value=Value.newBuilder().setTemporal(Temporal.newBuilder().setIso(pair[0]).setKind(pair[0].contains("T")?"timestamp":"date")).build();
            assertEquals("E'"+pair[1]+"'",SqlCopy.literal(Engine.POSTGRESQL,value),pair[0]);
            assertEquals(pair[0],value.getTemporal().getIso());
        }
        for(String ordinary:List.of("2024-02-29","2024-02-29T07:04:11.123456Z","12:34:56.123456-05:30:45","24:00:00"))
            assertEquals("E'"+ordinary+"'",SqlCopy.literal(Engine.POSTGRESQL,Value.newBuilder().setTemporal(Temporal.newBuilder().setIso(ordinary)).build()));
        assertThrows(IllegalArgumentException.class,()->SqlCopy.literal(Engine.POSTGRESQL,Value.newBuilder().setTemporal(Temporal.newBuilder().setIso("0000-02-30")).build()));
    }
    @Test void arrayCopyPreservesNativeBoundsAndEscapesWithoutGuessingTypes(){
        String raw="[0:1]={\"a\\\\b\",\"quote'\"}";var value=Value.newBuilder().setArray(ArrayValue.newBuilder().setNativeLiteral(raw).setElementNativeType("user_type").addValues(Value.newBuilder().setText("a\\b")).addValues(Value.newBuilder().setText("quote'"))).build();
        String copied=SqlCopy.literal(Engine.POSTGRESQL,value);assertEquals("E'"+raw.replace("\\","\\\\").replace("'","''")+"'",copied);assertFalse(copied.contains("::"));assertTrue(copied.contains("[0:1]"));
        assertEquals(raw,Values.text(value));assertEquals(raw,io.busystack.busydata.transfers.Transfers.json(value).getAsString());
        assertThrows(IllegalArgumentException.class,()->SqlCopy.literal(Engine.POSTGRESQL,Value.newBuilder().setArray(ArrayValue.newBuilder().addValues(Value.newBuilder().setSignedInteger("1"))).build()));
        var binary=value.toBuilder().setArray(value.getArray().toBuilder().clearNativeLiteral().setNativeBinary(ByteString.copyFrom(new byte[12]))).build();assertThrows(IllegalArgumentException.class,()->SqlCopy.literal(Engine.POSTGRESQL,binary));assertThrows(IllegalArgumentException.class,()->Values.text(binary));assertThrows(IllegalArgumentException.class,()->io.busystack.busydata.transfers.Transfers.json(binary));
    }
}
