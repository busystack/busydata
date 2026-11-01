package io.busystack.busydata;

import com.google.protobuf.ByteString;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.results.*;
import io.busystack.busydata.rpc.WorkbenchFailure;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

class RetainedEditValuesTest {
    @TempDir Path root;
    @Test void completeOriginalsPreserveExactTextJsonBinaryAndLeavePreviewUnchanged()throws Exception {
        try(var store=new ResultStore(root,8_388_608)) {
            var result=store.create(columns());String text="exact漢😀\r\n".repeat(9000),json="{\"n\":123456789012345678901234567890.000000001,\"n\":-0.0001,\"text\":\""+"x".repeat(40000)+"\"}";
            byte[] binary=new byte[70000];new Random(23).nextBytes(binary);
            Value textPreview=text(result,text,false),jsonPreview=text(result,json,true),binaryPreview=binary(result,binary);var saved=textPreview.toByteArray();var budget=new RetainedEditValues.Budget();
            assertEquals(text,RetainedEditValues.complete(result,textPreview,budget).getText());assertEquals(json,RetainedEditValues.complete(result,jsonPreview,budget).getJson());assertArrayEquals(binary,RetainedEditValues.complete(result,binaryPreview,budget).getBinary().toByteArray());
            var full=RetainedEditValues.complete(result,textPreview,new RetainedEditValues.Budget());assertFalse(full.getTruncated());assertTrue(full.getValueId().isEmpty());assertEquals(0,full.getOriginalBytes());assertArrayEquals(saved,textPreview.toByteArray());assertTrue(budget.bytes()>binary.length);
        }
    }
    @Test void foreignCellIdentityAndMismatchedProvenanceNeverExpand()throws Exception {
        try(var store=new ResultStore(root,8_388_608)) {
            var owner=store.create(columns());var other=store.create(columns());var preview=text(owner,"owned value".repeat(5000),false);
            assertReason(WorkbenchFailure.Reason.INVALID_OWNER,()->RetainedEditValues.complete(other,preview,new RetainedEditValues.Budget()));
            assertReason(WorkbenchFailure.Reason.VALUE_TRUNCATED,()->RetainedEditValues.complete(owner,preview.toBuilder().setOriginalBytes(preview.getOriginalBytes()+1).build(),new RetainedEditValues.Budget()));
            assertReason(WorkbenchFailure.Reason.VALUE_TRUNCATED,()->RetainedEditValues.complete(owner,preview.toBuilder().setText("forged prefix").build(),new RetainedEditValues.Budget()));
            assertReason(WorkbenchFailure.Reason.VALUE_TRUNCATED,()->RetainedEditValues.complete(owner,preview.toBuilder().clearValueId().build(),new RetainedEditValues.Budget()));
        }
    }
    @Test void malformedUtf8TextAndUnsupportedTruncatedTypesFailWithoutLosingRawBytes()throws Exception {
        try(var store=new ResultStore(root,8_388_608)) {
            var result=store.create(columns());byte[] malformed={(byte)0xc0,(byte)0x80};String id=result.storeBinary(malformed,InputStream.nullInputStream());
            var preview=Value.newBuilder().setText("").setTruncated(true).setOriginalBytes(2).setValueId(id).build();
            assertReason(WorkbenchFailure.Reason.VALUE_TRUNCATED,()->RetainedEditValues.complete(result,preview,new RetainedEditValues.Budget()));
            var binary=preview.toBuilder().setBinary(ByteString.copyFrom(malformed)).build();assertArrayEquals(malformed,RetainedEditValues.complete(result,binary,new RetainedEditValues.Budget()).getBinary().toByteArray());
            assertReason(WorkbenchFailure.Reason.UNSUPPORTED,()->RetainedEditValues.complete(result,preview.toBuilder().setEngineValue(EngineValue.newBuilder().setTypeName("unknown").setText("raw")).build(),new RetainedEditValues.Budget()));
        }
    }
    @Test void aggregateByteAndUtf16BudgetsRejectBeforePublishingFullValues()throws Exception {
        try(var store=new ResultStore(root,8_388_608)) {
            var result=store.create(columns());var preview=text(result,"x".repeat(70000),false);
            assertReason(WorkbenchFailure.Reason.VALUE_TRUNCATED,()->RetainedEditValues.complete(result,preview,new RetainedEditValues.Budget(1_000_000)));
            var oversizedText=text(result,"x".repeat(262145),false);assertReason(WorkbenchFailure.Reason.VALUE_TRUNCATED,()->RetainedEditValues.complete(result,oversizedText,new RetainedEditValues.Budget()));
            var oversizedBytes=binary(result,new byte[1_048_577]);assertReason(WorkbenchFailure.Reason.VALUE_TRUNCATED,()->RetainedEditValues.complete(result,oversizedBytes,new RetainedEditValues.Budget()));
        }
    }
    @Test void recoveryRechunksLargeOriginalsIntoBoundedRowsWithNewOwnedCellIds()throws Exception {
        try(var store=new ResultStore(root,8_388_608)) {
            var source=store.create(columns());String text="漢😀".repeat(30000),json="{\"text\":\""+"j".repeat(90000)+"\"}";byte[] bytes=new byte[120000];new Random(7).nextBytes(bytes);
            var original=Row.newBuilder().addValues(Value.newBuilder().setText(text)).addValues(Value.newBuilder().setJson(json)).addValues(Value.newBuilder().setBinary(ByteString.copyFrom(bytes))).build();assertTrue(original.getSerializedSize()>262144);
            var retained=RetainedEditValues.retainRow(source,original);assertTrue(retained.getSerializedSize()<262144);assertTrue(retained.getValuesList().stream().allMatch(Value::getTruncated));source.append(retained);
            assertEquals(original,RetainedEditValues.row(source,0,new RetainedEditValues.Budget()));
            var recovered=store.create(columns());var rebound=RetainedEditValues.retainRow(recovered,original);recovered.append(rebound);assertNotEquals(retained.getValues(0).getValueId(),rebound.getValues(0).getValueId());assertEquals(original,RetainedEditValues.row(recovered,0,new RetainedEditValues.Budget()));
            assertReason(WorkbenchFailure.Reason.INVALID_OWNER,()->RetainedEditValues.complete(recovered,retained.getValues(0),new RetainedEditValues.Budget()));
        }
    }
    @Test void cancelledOrDisposedOriginalsCannotCreateACompleteValue()throws Exception {
        try(var store=new ResultStore(root,8_388_608)) {
            var result=store.create(columns());var preview=text(result,"owned".repeat(6000),false);
            try(var context=io.grpc.Context.current().withCancellation()){
                context.cancel(null);context.run(()->assertReason(WorkbenchFailure.Reason.CANCELLED,()->RetainedEditValues.complete(result,preview,new RetainedEditValues.Budget())));
            }
            result.fetchFinished=true;result.jobState=JobState.COMPLETED;store.dispose(result.id);
            assertReason(WorkbenchFailure.Reason.RESULT_DISPOSED,()->RetainedEditValues.complete(result,preview,new RetainedEditValues.Budget()));
        }
    }
    private static List<Column> columns(){return List.of(Column.newBuilder().setName("text").setTypeName("text").setJdbcType(java.sql.Types.VARCHAR).setOrdinal(1).build(),Column.newBuilder().setName("json").setTypeName("json").setJdbcType(java.sql.Types.OTHER).setOrdinal(2).build(),Column.newBuilder().setName("bytes").setTypeName("binary").setJdbcType(java.sql.Types.VARBINARY).setOrdinal(3).build());}
    private static Value text(ResultStore.Result result,String text,boolean json)throws Exception {String id=result.storeText("",new StringReader(text));var value=Value.newBuilder().setTruncated(true).setValueId(id).setOriginalBytes(text.getBytes(StandardCharsets.UTF_8).length);if(json)value.setJson(text.substring(0,Math.min(8,text.length())));else value.setText(text.substring(0,Math.min(8,text.length())));return value.build();}
    private static Value binary(ResultStore.Result result,byte[] bytes)throws Exception {String id=result.storeBinary(bytes,InputStream.nullInputStream());return Value.newBuilder().setBinary(ByteString.copyFrom(bytes,0,Math.min(8,bytes.length))).setTruncated(true).setOriginalBytes(bytes.length).setValueId(id).build();}
    @FunctionalInterface private interface Checked {void run()throws Exception;}
    private static void assertReason(WorkbenchFailure.Reason reason,Checked operation){assertEquals(reason,assertThrows(WorkbenchFailure.class,operation::run).reason());}
}
