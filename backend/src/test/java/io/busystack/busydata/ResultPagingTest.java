package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.results.ResultStore;
import java.nio.file.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

class ResultPagingTest {
    @TempDir Path root;
    @Test void widePagesContinueByTheirActualRangeWithinTheSameByteBudget()throws Exception {
        try(var store=new ResultStore(root,16L*1024*1024)){
            var result=store.create(List.of(Column.newBuilder().setName("wide").build()));
            var expected=new ArrayList<Row>();
            for(int i=0;i<20;i++){var row=Row.newBuilder().addValues(Value.newBuilder().setText("row-"+i+" "+"x".repeat(131000))).build();expected.add(row);result.append(row);}
            result.fetchFinished=true;result.complete=true;long offset=0;int pages=0;
            while(offset<20){
                var page=result.page(PageRequest.newBuilder().setOffset(offset).setLimit(200).setMaxBytes(262144).build());
                assertEquals(offset,page.getFirstOffset());assertTrue(page.getRowsCount()>0);assertEquals(offset+page.getRowsCount(),page.getNextOffset());
                assertTrue(page.getSerializedSize()<=262144);assertTrue(page.getRowsCount()<200);
                for(int i=0;i<page.getRowsCount();i++)assertEquals(expected.get((int)offset+i),page.getRows(i));
                offset=page.getNextOffset();pages++;
            }
            assertTrue(pages>1);assertEquals(PageState.PAGE_END,result.page(PageRequest.newBuilder().setOffset(20).setLimit(5).setMaxBytes(262144).build()).getState());
            var backward=result.page(PageRequest.newBuilder().setOffset(3).setLimit(200).setMaxBytes(262144).build());assertEquals(expected.get(3),backward.getRows(0));
        }
    }
    @Test void metadataRowWaitingEndAndDisposalAreDistinctAndZeroProgressIsExplicit()throws Exception {
        try(var store=new ResultStore(root,16L*1024*1024)){
            var result=store.create(List.of(Column.newBuilder().setName("n").build()));
            var request=PageRequest.newBuilder().setResultId(result.id).setLimit(5).setMaxBytes(262144).build();
            assertEquals(PageState.PAGE_WAITING,result.page(request).getState());
            result.append(Row.newBuilder().addValues(Value.newBuilder().setSignedInteger("1")).build());
            assertEquals("1",result.page(request).getRows(0).getValues(0).getSignedInteger());
            assertEquals(PageState.PAGE_WAITING,result.page(request.toBuilder().setOffset(1).build()).getState());
            result.fetchFinished=true;result.complete=false;
            assertEquals(PageState.PAGE_END,result.page(request.toBuilder().setOffset(1).build()).getState());
            result.close();assertEquals(PageState.PAGE_DISPOSED,store.page(request).getState());
            var columns=new ArrayList<Column>();var row=Row.newBuilder();
            for(int i=0;i<16;i++){columns.add(Column.newBuilder().setName("c"+i+"x".repeat(4000)).build());row.addValues(Value.newBuilder().setText("v".repeat(15000)));}
            var wide=store.create(columns);wide.append(row.build());wide.fetchFinished=true;
            var shortPage=wide.page(request);assertEquals(PageState.PAGE_ROW_TOO_LARGE,shortPage.getState());assertEquals(0,shortPage.getRowsCount());assertEquals(0,shortPage.getNextOffset());assertTrue(shortPage.getSerializedSize()<=262144);
            assertEquals(row.build(),wide.page(request.toBuilder().setMaxBytes(1048576).build()).getRows(0));
            var huge=store.create(List.of(Column.newBuilder().setName("x".repeat(262100)).build()));
            var metadata=huge.page(request);assertEquals(PageState.PAGE_METADATA_TOO_LARGE,metadata.getState());assertEquals(0,metadata.getColumnsCount());assertTrue(metadata.getSerializedSize()<=262144);
        }
    }
    @Test void corruptRetainedRowsReportPersistentFailureInsteadOfAnEmptyLoadingPage()throws Exception {
        try(var store=new ResultStore(root,1048576)){
            var result=store.create(List.of(Column.newBuilder().setName("n").build()));result.append(Row.newBuilder().addValues(Value.newBuilder().setText("retained")).build());result.fetchFinished=true;
            Files.write(root.resolve("results").resolve(result.id+".rows"),new byte[0],StandardOpenOption.TRUNCATE_EXISTING);
            var page=result.page(PageRequest.newBuilder().setLimit(5).setMaxBytes(262144).build());
            assertEquals(PageState.PAGE_FAILED,page.getState());assertFalse(page.getAvailability().isBlank());assertEquals(0,page.getNextOffset());
        }
    }
}
