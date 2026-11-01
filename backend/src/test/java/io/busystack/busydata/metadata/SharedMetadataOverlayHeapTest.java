package io.busystack.busydata.metadata;

import java.nio.file.*;
import java.util.concurrent.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class SharedMetadataOverlayHeapTest {
    @Test void eightOwnedViewsShare118000DurableObjectsUnderTheShippedHeap()throws Exception{
        Path run=Files.createTempDirectory(Path.of("target"),"p0-production-heap-owned-");Path report=run.resolve("shared-owned.json"),log=run.resolve("shared-owned.log");String classpath=System.getProperty("surefire.test.class.path",System.getProperty("java.class.path"));var child=new ProcessBuilder(Path.of(System.getProperty("java.home"),"bin","java").toString(),"-Xms32m","-Xmx128m","-XX:+UseSerialGC","-XX:+NeverActAsServerClassMachine","-XX:MaxDirectMemorySize=64m","--enable-native-access=ALL-UNNAMED","-cp",classpath,SharedMetadataOverlayHeapProbe.class.getName(),report.toString()).redirectErrorStream(true).redirectOutput(log.toFile()).start();
        try{assertTrue(child.waitFor(120,TimeUnit.SECONDS),"Shared owned-model heap guard exceeded120s; see "+log);assertEquals(0,child.exitValue(),()->{try{return Files.readString(log);}catch(Exception failure){return failure.toString();}});var result=com.google.gson.JsonParser.parseString(Files.readString(report)).getAsJsonObject();assertEquals("passed",result.get("status").getAsString());assertEquals(118000,result.get("fixtureObjects").getAsInt());assertEquals(8,result.get("physicalOwnerViews").getAsInt());assertEquals(4,result.get("collectedDurableGenerations").getAsInt());assertEquals(32*1024*1024,result.get("retainedAllocationPressureBytes").getAsInt());assertFalse(result.get("jdbcWork").getAsBoolean());}finally{if(child.isAlive())child.destroyForcibly();}
    }
}
