package io.busystack.busydata;
import io.busystack.busydata.results.*;
import io.busystack.busydata.protocol.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import java.nio.file.Path;
import java.util.concurrent.CancellationException;
import static org.junit.jupiter.api.Assertions.*;
class RetainedViewsTest {
  @TempDir Path root;
  @Test void fixedSnapshotSortsUncachedRowsWithExactNumbersAndStableSourceIdentity() throws Exception {
    try(var store=new ResultStore(root,512L*1024*1024);var views=new RetainedViews(store)) {
      var source=store.create(java.util.List.of(Column.newBuilder().setName("n").setOrdinal(1).build()), Profile.newBuilder().setEngine(Engine.POSTGRESQL).build(),"physical-session");
      for(int i=0;i<2500;i++)source.append(Row.newBuilder().addValues(Value.newBuilder().setDecimal("9007199254740993."+String.format("%04d",i))).build());
      var info=views.create(ResultViewRequest.newBuilder().setResultId(source.id).addConditions(RowCondition.newBuilder().setColumn("#1").setPredicate(ValuePredicate.GREATER).setValue(Value.newBuilder().setDecimal("9007199254740993.2000"))).addOrder(RowOrder.newBuilder().setColumn("#1").setDescending(true)).build(),()->false);
      source.append(Row.newBuilder().addValues(Value.newBuilder().setDecimal("9007199254740994" )).build());
      assertEquals(2500,info.getSourceRows());assertEquals(499,info.getVisibleRows());assertTrue(info.getPartial());
      var view=views.get(info.getViewId());
      assertEquals(2499,view.sourceRow(0));assertEquals(2001,view.sourceRow(498));
      var page=view.page(PageRequest.newBuilder().setOffset(300).setLimit(200).setMaxBytes(1048576).build());
      assertEquals(2199,page.getSourceRows(0));assertEquals(199,page.getRowsCount());
      assertEquals("9007199254740993.2199",page.getRows(0).getValues(0).getDecimal());
      var copied=SqlCopy.range(source,CopySqlRequest.newBuilder().setFirstRow(0).setRowCount(2).setColumnCount(1).build(),view.count,view::sourceRow);
      assertEquals("(9007199254740993.2499),\n(9007199254740993.2498)",copied);
    }
  }
  @Test void disposalRetainsSourceLeaseAndCancellationReleasesQuota() throws Exception {
    try(var store=new ResultStore(root,512L*1024*1024);var views=new RetainedViews(store)) {
      var source=store.create(java.util.List.of(Column.newBuilder().setName("value").build()));
      source.append(Row.newBuilder().addValues(Value.newBuilder().setText("hello")).build());source.fetchFinished=true;source.complete=true;
      long bytes=store.bytes();
      assertThrows(CancellationException.class,()->views.create(ResultViewRequest.newBuilder().setResultId(source.id).build(),()->true));
      assertEquals(bytes,store.bytes());
      var info=views.create(ResultViewRequest.newBuilder().setResultId(source.id).build(),()->false);
      store.dispose(source.id);assertTrue(source.retained().getDisposalPending());
      var view=views.get(info.getViewId());assertEquals("hello",source.read(view.sourceRow(0)).getValues(0).getText());
      var lease=view.lease();views.dispose(info.getViewId());assertTrue(views.contains(info.getViewId()));
      lease.close();lease.close();assertFalse(views.contains(info.getViewId()));assertEquals(0,store.bytes());
      assertThrows(IllegalArgumentException.class,()->store.get(source.id));
    }
  }
  @Test void nullsAndUnsupportedLargeValuesHaveExplicitComparisonContracts() {
    assertTrue(RetainedViews.matches(Value.newBuilder().setNullValue(Null.getDefaultInstance()).build(),RowCondition.newBuilder().setPredicate(ValuePredicate.IS_NULL).build()));
    assertFalse(RetainedViews.matches(Value.newBuilder().setNullValue(Null.getDefaultInstance()).build(),RowCondition.newBuilder().setPredicate(ValuePredicate.EQUAL).setValue(Value.newBuilder().setText("")).build()));
    assertThrows(IllegalArgumentException.class,()->RetainedViews.key(Value.newBuilder().setText("preview").setTruncated(true).build()));
    assertEquals(0,RetainedViews.compareKey("1:9007199254740993.0","1:9007199254740993"));
  }
  @Test void invalidOperandsAreRejectedEvenForAnEmptySnapshotWithoutIndexAdmission() throws Exception {
    try(var store=new ResultStore(root,512L*1024*1024);var views=new RetainedViews(store)) {
      var source=store.create(java.util.List.of(Column.newBuilder().setName("n").build()));
      long bytes=store.bytes();
      for(var value:java.util.List.of(Value.newBuilder().setDecimal("not numeric").build(),Value.newBuilder().setSignedInteger("invalid").build(),Value.newBuilder().setEngineValue(EngineValue.newBuilder().setText("unsupported")).build())) {
        assertThrows(IllegalArgumentException.class,()->views.create(ResultViewRequest.newBuilder().setResultId(source.id).addConditions(RowCondition.newBuilder().setColumn("#1").setPredicate(ValuePredicate.EQUAL).setValue(value)).build(),()->false));
        assertEquals(bytes,store.bytes());
      }
    }
  }
  @Test void duplicateLabelsAndOrdinalLookingAliasesCannotRetargetExactOperations() throws Exception {
    try(var store=new ResultStore(root,512L*1024*1024);var views=new RetainedViews(store)) {
      var source=store.create(java.util.List.of(
        Column.newBuilder().setName("duplicate").setOrdinal(1).build(),
        Column.newBuilder().setName("duplicate").setOrdinal(2).build(),
        Column.newBuilder().setName("#2").setOrdinal(3).build()));
      for(int index=0;index<3;index++)source.append(Row.newBuilder()
        .addValues(Value.newBuilder().setText("left-"+index))
        .addValues(index==2?Value.newBuilder().setNullValue(Null.getDefaultInstance()):Value.newBuilder().setDecimal(index==0?"9007199254740993.1000":"9007199254740993.2000"))
        .addValues(Value.newBuilder().setText("alias-"+index)).build());
      source.fetchFinished=true;source.complete=true;
      long bytes=store.bytes();
      assertThrows(IllegalArgumentException.class,()->views.create(ResultViewRequest.newBuilder().setResultId(source.id).addOrder(RowOrder.newBuilder().setColumn("duplicate")).build(),()->false));
      assertEquals(bytes,store.bytes());
      var info=views.create(ResultViewRequest.newBuilder().setResultId(source.id)
        .addConditions(RowCondition.newBuilder().setColumn("#2").setPredicate(ValuePredicate.GREATER).setValue(Value.newBuilder().setDecimal("9007199254740993.1001")))
        .addOrder(RowOrder.newBuilder().setColumn("#2").setDescending(true)).build(),()->false);
      assertEquals(1,info.getVisibleRows());assertFalse(info.getPartial());
      var view=views.get(info.getViewId());assertEquals(1,view.sourceRow(0));
      var row=view.page(PageRequest.newBuilder().setLimit(1).setMaxBytes(1048576).build()).getRows(0);
      assertEquals("9007199254740993.2000",row.getValues(1).getDecimal());assertEquals("alias-1",row.getValues(2).getText());
      var nulls=views.create(ResultViewRequest.newBuilder().setResultId(source.id).addConditions(RowCondition.newBuilder().setColumn("#2").setPredicate(ValuePredicate.IS_NULL)).build(),()->false);
      assertEquals(1,nulls.getVisibleRows());assertEquals(2,views.get(nulls.getViewId()).sourceRow(0));
    }
  }
}
