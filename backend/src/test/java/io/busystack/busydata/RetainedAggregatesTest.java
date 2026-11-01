package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.results.*;
import java.nio.file.Path;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

class RetainedAggregatesTest {
    @TempDir Path root;
    @Test void exactDecimalsNullsDistinctAndRepeatingAverageHaveNoFloatingPointProxy()throws Exception {
        try(var results=new ResultStore(root,16_777_216);var views=new RetainedViews(results)){
            var result=results.create(List.of(Column.newBuilder().setOrdinal(1).setName("n").build()));
            for(String n:List.of("9007199254740993.1","9007199254740993.10","9007199254740993.2"))result.append(Row.newBuilder().addValues(Value.newBuilder().setDecimal(n)).build());
            result.append(Row.newBuilder().addValues(Value.newBuilder().setNullValue(Null.getDefaultInstance())).build());result.fetchFinished=true;
            var reply=new RetainedAggregates(results,views).calculate(ResultAggregateRequest.newBuilder().setResultId(result.id).setRowCount(4).addOrdinals(1).build(),()->false);
            var value=reply.getColumns(0);assertEquals(4,value.getSelectedCount());assertEquals(1,value.getNullCount());assertEquals(2,value.getDistinctCount());
            assertEquals("27021597764222979.40",value.getSum());assertEquals("27021597764222979.40/3",value.getAverage());assertEquals("9007199254740993.2",value.getMaximum().getDecimal());assertTrue(reply.getPartial());
        }
    }
    @Test void viewMappingAndCancellationUseTheOriginalRetainedOwner()throws Exception {
        try(var results=new ResultStore(root,512L*1024*1024);var views=new RetainedViews(results)){
            var result=results.create(List.of(Column.newBuilder().setOrdinal(1).setName("n").build()));
            for(int n:new int[]{1,5,9})result.append(Row.newBuilder().addValues(Value.newBuilder().setSignedInteger(""+n)).build());result.fetchFinished=true;result.complete=true;
            var view=views.create(ResultViewRequest.newBuilder().setResultId(result.id).addOrder(RowOrder.newBuilder().setColumn("#1").setDescending(true)).build(),()->false);
            var request=ResultAggregateRequest.newBuilder().setResultId(result.id).setViewId(view.getViewId()).setRowCount(2).addOrdinals(1).build();
            var service=new RetainedAggregates(results,views);assertEquals("14",service.calculate(request,()->false).getColumns(0).getSum());
            assertThrows(java.util.concurrent.CancellationException.class,()->service.calculate(request,()->true));
            assertThrows(IllegalArgumentException.class,()->service.calculate(request.toBuilder().setRowCount(100001).build(),()->false));
            var foreign=results.create(result.columns);assertThrows(IllegalArgumentException.class,()->service.calculate(request.toBuilder().setResultId(foreign.id).build(),()->false));
        }
    }
    @Test void temporalOrderingPreservesExactOriginalValuesAndNormalizesOffsetInstants()throws Exception {
        try(var results=new ResultStore(root,16_777_216);var views=new RetainedViews(results)){
            var result=results.create(List.of(Column.newBuilder().setOrdinal(1).setName("moment").build()));
            for(String iso:List.of("2026-10-24T01:00:00+02:00","2026-10-23T23:00:00Z","2026-10-24T00:00:00Z"))result.append(Row.newBuilder().addValues(Value.newBuilder().setTemporal(Temporal.newBuilder().setKind("timestamptz").setZone("offset in value").setIso(iso))).build());
            var aggregate=new RetainedAggregates(results,views).calculate(ResultAggregateRequest.newBuilder().setResultId(result.id).setRowCount(3).addOrdinals(1).build(),()->false).getColumns(0);
            assertEquals(2,aggregate.getDistinctCount());assertEquals("2026-10-24T00:00:00Z",aggregate.getMaximum().getTemporal().getIso());assertTrue(aggregate.getSum().isEmpty());assertEquals("available",aggregate.getAvailability());
        }
    }
    @Test void mixedAndTruncatedValuesCannotBecomeMisleadingNumericTotals()throws Exception {
        try(var results=new ResultStore(root,16_777_216);var views=new RetainedViews(results)){
            var result=results.create(List.of(Column.newBuilder().setOrdinal(1).setName("n").build()));
            result.append(Row.newBuilder().addValues(Value.newBuilder().setSignedInteger("2")).build());result.append(Row.newBuilder().addValues(Value.newBuilder().setText("3")).build());
            var request=ResultAggregateRequest.newBuilder().setResultId(result.id).setRowCount(2).addOrdinals(1).build();var service=new RetainedAggregates(results,views);
            var mixed=service.calculate(request,()->false).getColumns(0);assertEquals("incompatible-types",mixed.getAvailability());assertTrue(mixed.getSum().isEmpty());
            result.append(Row.newBuilder().addValues(Value.newBuilder().setText("preview").setTruncated(true)).build());
            assertThrows(IllegalArgumentException.class,()->service.calculate(request.toBuilder().setFirstRow(2).setRowCount(1).build(),()->false));
        }
    }
}
