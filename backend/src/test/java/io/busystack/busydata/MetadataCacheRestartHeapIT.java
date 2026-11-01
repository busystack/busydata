package io.busystack.busydata;

import java.nio.file.*;
import java.util.*;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

/** A real PostgreSQL owner remains alive across two independently bounded JVMs.
 * Catalog contents are synthetic; normalized SQLite, restart, publication and
 * protocol availability are the production implementations. */
class MetadataCacheRestartHeapIT {
    @Test void largeNormalizedCacheRestartIsExplicitAndCanReconcileAtTheShippedHeap()throws Exception {
        Path run=Files.createTempDirectory(Path.of("target"),"p0-cache-restart-heap-").toAbsolutePath();
        try(var owner=new EngineFixture(run.resolve("physical-owner"),"POSTGRESQL")) {
            Path profile=run.resolve("profile.pb");Files.write(profile,owner.profile.toByteArray());
            String classpath=System.getProperty("surefire.test.class.path",System.getProperty("java.class.path"));
            for(String mode:List.of("seed","restart")) {
                Path temporary=run.resolve(mode+"-tmp");Files.createDirectory(temporary);Path log=run.resolve(mode+".log");
                var child=new ProcessBuilder(Path.of(System.getProperty("java.home"),"bin","java").toString(),
                    "-Xms32m",mode.equals("seed")?"-Xmx256m":"-Xmx128m","-XX:+UseSerialGC","-XX:+NeverActAsServerClassMachine","-XX:MaxDirectMemorySize=64m",
                    "--enable-native-access=ALL-UNNAMED","-Djava.io.tmpdir="+temporary,"-cp",classpath,
                    MetadataCacheRestartHeapProbe.class.getName(),run.toString(),mode)
                    .redirectErrorStream(true).redirectOutput(log.toFile()).start();
                try {
                    assertTrue(child.waitFor(180,TimeUnit.SECONDS),"Cache restart child exceeded180s; see "+log);
                    assertEquals(0,child.exitValue(),()->"Cache restart regression failed; see "+run.resolve(mode+".json")+" and "+log);
                    var report=com.google.gson.JsonParser.parseString(Files.readString(run.resolve(mode+".json"))).getAsJsonObject();
                    assertEquals("passed",report.get("status").getAsString());assertEquals(118000,report.get("fixtureObjects").getAsInt());
                    assertFalse(report.get("nativeCatalogAcceptance").getAsBoolean());
                    if(mode.equals("restart")) {
                        assertTrue(report.get("maxHeapBytes").getAsLong()<=128L*1024*1024);
                        assertTrue(report.get("explicitRestartAvailability").getAsBoolean());
                        assertTrue(report.get("reconciledModelExact").getAsBoolean());assertTrue(report.get("persistedRowsExact").getAsBoolean());
                        assertEquals(report.get("reconciledSnapshotRevision").getAsLong(),report.get("visibleSnapshotRevision").getAsLong());
                        if(report.get("cachePersistenceAcceptance").getAsBoolean()){assertEquals("AVAILABLE",report.get("reconciledCacheState").getAsString());assertTrue(report.get("persistedFreshCoverageExact").getAsBoolean());}
                        else{assertEquals("WRITE_UNAVAILABLE",report.get("reconciledCacheState").getAsString());assertTrue(report.has("cacheFailure"));if(report.get("cacheCommitOutcome").getAsString().equals("NOT_ATTEMPTED"))assertTrue(report.get("priorCacheTransactionPreserved").getAsBoolean());else assertTrue(Set.of("EXACT_OLD","EXACT_NEW").contains(report.get("terminalFailureAtomicGeneration").getAsString()));}
                        assertFalse(report.get("cacheNativeOwnershipActive").getAsBoolean());assertTrue(report.has("callerPublicationMs"));assertTrue(report.has("eventualCacheCompletionWaitMs"));
                        assertEquals(0,report.get("warmAnalysisJdbcCalls").getAsInt());assertEquals(0,report.get("warmAnalysisNewConnections").getAsInt());
                    }
                } finally {
                    if(child.isAlive()){child.destroy();if(!child.waitFor(10,TimeUnit.SECONDS)){child.destroyForcibly();child.waitFor(10,TimeUnit.SECONDS);}}
                }
            }
        }
    }
}
