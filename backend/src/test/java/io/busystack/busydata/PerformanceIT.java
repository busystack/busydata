package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.analysis.SqlAnalysis;
import io.busystack.busydata.sessions.SessionRegistry;
import io.busystack.busydata.results.*;
import io.busystack.busydata.storage.MetadataStore;
import io.busystack.busydata.safety.Safety;
import io.busystack.busydata.jobs.Jobs;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;
import java.lang.management.ManagementFactory;
import com.google.gson.*;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.io.TempDir;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.wait.strategy.Wait;
import static org.junit.jupiter.api.Assertions.*;

class PerformanceIT {
 @TempDir Path root;
 @Test void millionRowsAndMultiGigabyteSourceRespectSpoolQuota()throws Exception {
  try(var db=new GenericContainer<>("postgres:17.11").withExposedPorts(5432).withEnv("POSTGRES_PASSWORD","performance-fixture").waitingFor(Wait.forLogMessage(".*database system is ready to accept connections.*\\n",2))) {
   db.start();var p=Profile.newBuilder().setId("fixture").setName("Performance fixture").setEngine(Engine.POSTGRESQL).setHost(db.getHost()).setPort(db.getMappedPort(5432)).setUser("postgres").setDatabase("postgres").setTls(Tls.newBuilder().setMode(TlsMode.DISABLED)).setConnectTimeoutSeconds(10).setQueryTimeoutSeconds(120).build();
   try(var sessions=new SessionRegistry();var metadata=new MetadataStore(root);var spool=new ResultStore(root,128L*1024*1024)) {
    var analysis=new SqlAnalysis();var safety=new Safety(analysis);try(var jobs=new Jobs(spool,metadata,analysis,safety)) {
     var s=sessions.open(OpenRequest.newBuilder().setProfile(p).setPassword("performance-fixture").build());
     var request=ExecuteRequest.newBuilder().setSessionId(s.id).setExecutionId(UUID.randomUUID().toString()).setSql("SELECT n, repeat('x',64) AS text FROM generate_series(1,1000000) n").setStreamingRead(true).setRowLimit(1_000_000).build();
     var start=System.nanoTime();var job=jobs.execute(s,request);long first=0,peak=0;
     while(!Jobs.terminal(job.state)){if(first==0&&job.progress>0)first=System.nanoTime()-start;peak=Math.max(peak,ManagementFactory.getMemoryMXBean().getHeapMemoryUsage().getUsed());if(System.nanoTime()-start>TimeUnit.SECONDS.toNanos(120)){jobs.cancel(job.id);fail("Million-row budget exceeded");}Thread.sleep(5);}
     assertEquals(JobState.COMPLETED,job.state,job.info().toString());assertEquals(1_000_000,job.progress);assertTrue(first<TimeUnit.SECONDS.toNanos(5),"Time to first row budget 5 seconds");assertTrue(peak<256L*1024*1024,"Measured JVM heap exceeds 256MiB");assertTrue(spool.bytes()<=128L*1024*1024);long millionBytes=spool.bytes();
     for(var result:job.info().getResultsList())spool.get(result.getResultId()).close();
     var large=jobs.execute(s,request.toBuilder().setExecutionId(UUID.randomUUID().toString()).setSql("SELECT n, repeat('x',65536) AS text FROM generate_series(1,32768) n").setRowLimit(32768).build());
     long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(120);while(!Jobs.terminal(large.state)&&System.nanoTime()<deadline)Thread.sleep(20);
     assertEquals(JobState.FAILED,large.state,"2GiB source must report quota exhaustion with a partial retained result");assertTrue(spool.bytes()<=128L*1024*1024);
     var report=new JsonObject();report.addProperty("java",System.getProperty("java.runtime.version"));report.addProperty("os",System.getProperty("os.name"));report.addProperty("cpu",Runtime.getRuntime().availableProcessors());report.addProperty("fixture","postgres:17.11");report.addProperty("fetchSize",256);report.addProperty("rows",job.progress);report.addProperty("firstRowMs",first/1_000_000);report.addProperty("durationMs",job.info().getDurationMs());report.addProperty("peakJvmHeapBytes",peak);report.addProperty("millionSpoolBytes",millionBytes);report.addProperty("twoGiBSourceState",large.state.name());report.addProperty("quotaBytes",128L*1024*1024);report.addProperty("flutterMemoryMeasured",false);
     Path target=Path.of("target/performance-postgres.json");Files.createDirectories(target.getParent());Files.writeString(target,new GsonBuilder().setPrettyPrinting().create().toJson(report));
    }
   }
  }
 }
}
