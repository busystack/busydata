package io.busystack.busydata;

import java.nio.file.*;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import io.busystack.busydata.protocol.Engine;
import static org.junit.jupiter.api.Assertions.*;

class ExecutionMetadataHeapTest {
    @ParameterizedTest @EnumSource(value=Engine.class,names={"MYSQL","MARIADB"})
    void syntheticNativeMapsAreSharedBySevenBlockedCapturesWithinTheSameShippedHeap(Engine engine)throws Exception{
        String classpath=System.getProperty("surefire.test.class.path",System.getProperty("java.class.path"));Path run=Files.createTempDirectory(Path.of("target"),"p0-native-case-proof-heap-");
        Path evidence=run.resolve(engine.name()+".json"),log=run.resolve(engine.name()+".log");
        var child=new ProcessBuilder(Path.of(System.getProperty("java.home"),"bin","java").toString(),"-Xms32m","-Xmx128m","-XX:+UseSerialGC","-XX:+NeverActAsServerClassMachine","-XX:MaxDirectMemorySize=64m","--enable-native-access=ALL-UNNAMED","-cp",classpath,ExecutionMetadataHeapProbe.class.getName(),evidence.toString(),"compact",engine.name()).redirectErrorStream(true).redirectOutput(log.toFile()).start();
        try{
            assertTrue(child.waitFor(120,TimeUnit.SECONDS),"Synthetic native-rule heap guard exceeded120s; see "+log);
            assertEquals(0,child.exitValue(),()->{try{return Files.readString(log);}catch(Exception failure){return failure.toString();}});
            var report=com.google.gson.JsonParser.parseString(Files.readString(evidence)).getAsJsonObject();
            assertEquals("passed",report.get("status").getAsString());assertEquals(engine.name(),report.get("fixtureEngine").getAsString());assertTrue(report.get("syntheticNativeAsciiMaps").getAsBoolean());assertEquals(118000,report.get("fixtureObjects").getAsInt());
            assertEquals(7,report.get("oldGenerationWeakRefsCollected").getAsInt());assertEquals(7,report.get("heldExecutionCandidates").getAsInt());assertEquals(7,report.get("exactFinalizedProofs").getAsInt());assertEquals(32*1024*1024,report.get("retainedAllocationPressureBytes").getAsInt());assertTrue(report.get("nativeRuleEstimatedBytes").getAsLong()>=262144);
        }finally{if(child.isAlive())child.destroyForcibly();}
    }
    @Test void sevenBlockedCapturesReleaseOld118000ObjectIndexesWithinTheShipped128MiBHeap()throws Exception{
        String classpath=System.getProperty("surefire.test.class.path",System.getProperty("java.class.path"));Path run=Files.createTempDirectory(Path.of("target"),"p0-execution-proof-heap-");
        for(String mode:java.util.List.of("compact","full-snapshot-control")){
            Path evidence=run.resolve(mode+".json"),log=run.resolve(mode+".log");
            var child=new ProcessBuilder(Path.of(System.getProperty("java.home"),"bin","java").toString(),"-Xms32m","-Xmx128m","-XX:+UseSerialGC","-XX:+NeverActAsServerClassMachine","-XX:MaxDirectMemorySize=64m","--enable-native-access=ALL-UNNAMED","-cp",classpath,ExecutionMetadataHeapProbe.class.getName(),evidence.toString(),mode).redirectErrorStream(true).redirectOutput(log.toFile()).start();
            try{
                assertTrue(child.waitFor(120,TimeUnit.SECONDS),"Execution-proof heap experiment exceeded120s; see "+log);assertTrue(Files.isRegularFile(evidence),"Missing source-bound heap evidence");
                var report=com.google.gson.JsonParser.parseString(Files.readString(evidence)).getAsJsonObject();assertEquals(mode,report.get("mode").getAsString());assertEquals(118000,report.get("fixtureObjects").getAsInt());
                if(mode.equals("compact")){
                    assertEquals(0,child.exitValue(),()->{try{return Files.readString(log);}catch(Exception failure){return failure.toString();}});assertEquals("passed",report.get("status").getAsString());assertEquals(7,report.get("oldGenerationWeakRefsCollected").getAsInt());assertEquals(7,report.get("heldExecutionCandidates").getAsInt());assertEquals(7,report.get("exactFinalizedProofs").getAsInt());assertEquals(32*1024*1024,report.get("retainedAllocationPressureBytes").getAsInt());
                }else if(child.exitValue()!=0){assertEquals("java.lang.OutOfMemoryError",report.get("failure").getAsString(),"Control must fail only from the measured old snapshot resource retention");}
                else assertEquals(7,report.get("exactFinalizedProofs").getAsInt(),"A successful control must also finalize every captured proof");
            }finally{if(child.isAlive())child.destroyForcibly();}
        }
    }
}
