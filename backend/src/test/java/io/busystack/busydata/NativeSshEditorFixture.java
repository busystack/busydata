package io.busystack.busydata;

import com.google.gson.Gson;
import io.busystack.busydata.results.ResultStore;
import java.nio.file.*;
import java.util.Map;
import java.util.concurrent.*;

/** Disposable SSH endpoint for visible-control acceptance, excluded from the product. */
public final class NativeSshEditorFixture {
    public static void main(String[] arguments)throws Exception {
        if(arguments.length!=1)throw new IllegalArgumentException("One private fixture directory is required");
        Path root=Path.of(arguments[0]).toAbsolutePath();Files.createDirectories(root);ResultStore.privateDirectory(root);
        try(var fixture=new SshConnectionTest.Fixture(root,Files.readString(root.resolve("password")));
            var updates=Executors.newSingleThreadScheduledExecutor()) {
            ResultStore.privateFile(fixture.known);
            var gson=new Gson();
            Files.writeString(root.resolve("endpoint.json"),gson.toJson(Map.of("host","127.0.0.1","port",fixture.server.getPort(),"user","ssh-user")));
            updates.scheduleAtFixedRate(()->{
                try {
                    Path temporary=root.resolve("metrics.json.tmp");
                    Files.writeString(temporary,gson.toJson(Map.of("authentications",fixture.authentications.get(),"forwards",fixture.forwards.get(),"activeSessions",fixture.server.getActiveSessions().size())));
                    Files.move(temporary,root.resolve("metrics.json"),StandardCopyOption.REPLACE_EXISTING,StandardCopyOption.ATOMIC_MOVE);
                }catch(java.io.IOException error){throw new java.io.UncheckedIOException(error);}
            },0,100,TimeUnit.MILLISECONDS);
            // The controller owns this process and releases it by closing stdin.
            while(System.in.read()!=-1){}
            updates.shutdownNow();updates.awaitTermination(2,TimeUnit.SECONDS);
        }
    }
}
