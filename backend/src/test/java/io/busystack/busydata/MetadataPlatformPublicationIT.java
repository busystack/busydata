package io.busystack.busydata;

import java.nio.file.*;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

/** Synthetic model scalability on real Platform/SQLite; PostgreSQL is only the physical owner/control. */
class MetadataPlatformPublicationIT {
    @ParameterizedTest @ValueSource(strings={"large","cache"})
    void publicationLeavesInteractiveProofAndReadOnlyJobsAvailableAtProductionHeap(String mode)throws Exception{
        Path out=Files.createTempDirectory(Path.of("target"),"platform-publication-"+mode+"-").toAbsolutePath();Path log=out.resolve("child.log"),temporary=out.resolve("tmp");Files.createDirectories(temporary);
        String classpath=System.getProperty("surefire.test.class.path",System.getProperty("java.class.path"));
        var child=new ProcessBuilder(Path.of(System.getProperty("java.home"),"bin","java").toString(),"-Xms32m","-Xmx128m","-XX:+UseSerialGC","-XX:+NeverActAsServerClassMachine","-XX:MaxDirectMemorySize=64m","--enable-native-access=ALL-UNNAMED","-Djava.io.tmpdir="+temporary,"-cp",classpath,MetadataPlatformPublicationProbe.class.getName(),out.toString(),mode).redirectErrorStream(true).redirectOutput(log.toFile()).start();
        try{assertTrue(child.waitFor(180,TimeUnit.SECONDS),"Publication child exceeded180s; see "+log);assertEquals(0,child.exitValue(),()->"Publication regression failed; see "+out.resolve("result.json")+" and "+log);}
        finally{if(child.isAlive()){child.destroy();if(!child.waitFor(10,TimeUnit.SECONDS)){child.destroyForcibly();child.waitFor(10,TimeUnit.SECONDS);}}}
    }
}
