package io.busystack.busydata;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;
import static org.junit.jupiter.api.Assertions.*;

class BootstrapInputMonitorTest {
    @TempDir Path root;

    @Test void parentPipeDoesNotStarveControlWorkAndEofStillClosesOnce()throws Exception {
        Path log=root.resolve("monitor.log");
        String classpath=System.getProperty("surefire.test.class.path",System.getProperty("java.class.path"));
        var child=new ProcessBuilder(Path.of(System.getProperty("java.home"),"bin","java").toString(),
            "-XX:ActiveProcessorCount=2","-Xms32m","-Xmx128m","-XX:MaxDirectMemorySize=64m",
            "-XX:+UseSerialGC","-XX:+NeverActAsServerClassMachine","-cp",classpath,Probe.class.getName())
            .redirectErrorStream(true).redirectOutput(log.toFile()).start();
        try {
            assertTrue(awaitLine(log,"READY",10),()->"Input monitor did not start: "+read(log));
            assertTrue(awaitLine(log,"CONTROL",5),()->"Parent input occupied a carrier and starved control work: "+read(log));
        } finally {
            child.getOutputStream().close();
            if(!child.waitFor(10,TimeUnit.SECONDS)){child.destroy();assertTrue(child.waitFor(5,TimeUnit.SECONDS),"Owned monitor probe did not terminate");}
        }
        assertEquals(0,child.exitValue(),()->read(log));
        assertTrue(read(log).contains("CLOSED_ONCE"),()->read(log));
    }

    private static boolean awaitLine(Path path,String line,int seconds)throws Exception {
        long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(seconds);
        do {if(Files.exists(path)&&Files.readString(path).lines().anyMatch(line::equals))return true;Thread.sleep(10);}while(System.nanoTime()<deadline);
        return false;
    }
    private static String read(Path path){try{return Files.readString(path);}catch(IOException error){return error.toString();}}

    public static final class Probe {
        public static void main(String[] args)throws Exception {
            var entered=new CountDownLatch(1);var eof=new CountDownLatch(1);var closes=new AtomicInteger();
            var input=new FilterReader(new BufferedReader(new InputStreamReader(System.in,StandardCharsets.UTF_8))){
                @Override public int read()throws IOException {entered.countDown();return super.read();}
            };
            Thread monitor=Main.startInputMonitor(input,()->{closes.incrementAndGet();eof.countDown();});
            if(!entered.await(5,TimeUnit.SECONDS))throw new AssertionError("Input monitor did not enter its reader");
            Thread.sleep(100);
            var working=new CountDownLatch(1);var finished=new CountDownLatch(1);var stop=new AtomicBoolean();
            Thread.ofVirtual().start(()->{long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(10);working.countDown();while(!stop.get()&&System.nanoTime()<deadline)Thread.onSpinWait();finished.countDown();});
            if(!working.await(5,TimeUnit.SECONDS))throw new AssertionError("Bounded work did not start");
            System.out.println("READY");System.out.flush();
            var control=new CountDownLatch(1);Thread.ofVirtual().start(control::countDown);
            if(!control.await(15,TimeUnit.SECONDS))throw new AssertionError("Control work never ran");
            System.out.println("CONTROL");System.out.flush();stop.set(true);
            if(!finished.await(2,TimeUnit.SECONDS)||!eof.await(10,TimeUnit.SECONDS))throw new AssertionError("Owned work or input did not close");
            monitor.join(1000);
            if(monitor.isAlive()||closes.get()!=1)throw new AssertionError("Input close ownership changed");
            System.out.println("CLOSED_ONCE");System.out.flush();
        }
    }
}
