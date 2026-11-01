package io.busystack.busydata;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.jobs.Jobs;
import io.busystack.busydata.results.ResultStore;
import io.busystack.busydata.storage.MetadataStore;
import io.busystack.busydata.analysis.SqlAnalysis;
import io.busystack.busydata.safety.Safety;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;
class JobCatalogTest {
 @TempDir Path root;
 @Test void summaryRetentionHasBoundedPagesIndependentFromResultColumns()throws Exception {
  try(var metadata=new MetadataStore(root);var results=new ResultStore(root,1024)){
   var analysis=new SqlAnalysis();try(var jobs=new Jobs(results,metadata,analysis,new Safety(analysis))){
    var result=results.create(List.of(Column.newBuilder().setName("retained_column").setBaseColumn("base").build()));result.fetchFinished=true;
    for(int number=0;number<130;number++){
     var job=jobs.submitRetainedExport(result,UUID.randomUUID().toString(),operation->{for(int i=0;i<100;i++)operation.message("x".repeat(512));operation.result(StatementResult.newBuilder().setResultId(result.id).addAllColumns(result.columns).build());});
     assertEquals(JobState.COMPLETED,job.finished.get(5,TimeUnit.SECONDS).getState());
    }
    int offset=0,count=0;long revision=0;var ids=new HashSet<String>();
    while(true){var page=jobs.page(JobRequest.newBuilder().setOffset(offset).setLimit(32).setCatalogRevision(revision).build());assertTrue(page.getSerializedSize()<=1048576);assertTrue(page.getJobsCount()>0);for(var job:page.getJobsList()){assertTrue(ids.add(job.getJobId()));assertEquals(0,job.getResults(0).getColumnsCount());}count+=page.getJobsCount();revision=page.getCatalogRevision();if(page.getComplete())break;assertTrue(page.getNextOffset()>offset);offset=page.getNextOffset();}
    assertEquals(128,count);assertEquals("base",results.get(result.id).columns.getFirst().getBaseColumn());
    var stale=jobs.page(JobRequest.newBuilder().setLimit(32).build());var another=jobs.submitRetainedExport(result,UUID.randomUUID().toString(),operation->{});another.finished.get(5,TimeUnit.SECONDS);
    assertThrows(IllegalStateException.class,()->jobs.page(JobRequest.newBuilder().setCatalogRevision(stale.getCatalogRevision()).setLimit(32).build()));
   }
  }
 }
}
