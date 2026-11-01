package io.busystack.busydata;

import java.nio.file.*;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class ProductionMetadataHeapTest {
    @Test void normalizedLargeCatalogAndFourOperationsFitTheShippedHeap()throws Exception {
        String classpath=System.getProperty("surefire.test.class.path",System.getProperty("java.class.path"));
        Path run=Files.createTempDirectory(Path.of("target"),"p0-production-heap-");
        for(String workload:java.util.List.of("language","atomic-publication","allocation-pressure")){
        Path evidence=run.resolve(workload+".json"),log=run.resolve(workload+".log");
        var child=new ProcessBuilder(Path.of(System.getProperty("java.home"),"bin","java").toString(),"-Xms32m","-Xmx128m","-XX:+UseSerialGC","-XX:+NeverActAsServerClassMachine","-XX:MaxDirectMemorySize=64m","--enable-native-access=ALL-UNNAMED","-cp",classpath,ProductionMetadataHeapProbe.class.getName(),evidence.toString(),workload).redirectErrorStream(true).redirectOutput(log.toFile()).start();
        try{assertTrue(child.waitFor(120,TimeUnit.SECONDS),"Production heap probe exceeded120s; see "+log);assertEquals(0,child.exitValue(),()->{try{return Files.readString(log);}catch(Exception failure){return failure.toString();}});}finally{if(child.isAlive())child.destroyForcibly();}
        }
    }
}
