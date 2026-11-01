package io.busystack.busydata.transfers;

import io.busystack.busydata.jobs.Jobs;
import io.busystack.busydata.protocol.Profile;
import io.busystack.busydata.protocol.ToolRequest;
import io.busystack.busydata.security.NativeToolTransport;
import java.io.*;
import java.nio.file.*;
import java.nio.file.attribute.BasicFileAttributes;
import java.security.MessageDigest;
import java.util.HexFormat;
import java.util.concurrent.*;

/** Selected, fixed-argument native clients; never a workspace executable hook. */
public final class NativeToolChecks {
    private NativeToolChecks(){}
    public static String reviewedFiles(ToolRequest request,Profile profile)throws Exception {
        var snap=System.getenv("SNAP");
        if(snap!=null&&!snap.isBlank()){
            String executable=switch(profile.getEngine()){case POSTGRESQL->request.getKind()==io.busystack.busydata.protocol.ToolKind.RESTORE?"psql":"pg_dump";case MYSQL->request.getKind()==io.busystack.busydata.protocol.ToolKind.RESTORE?"mysql":"mysqldump";case MARIADB->request.getKind()==io.busystack.busydata.protocol.ToolKind.RESTORE?"mariadb":"mariadb-dump";default->throw new IllegalArgumentException("Unsupported native-client engine");};
            Path required=Path.of(snap).resolve("backend/tools/"+profile.getEngine().name().toLowerCase(java.util.Locale.ROOT)+"/bin/"+executable);
            if(!Path.of(request.getNativeToolPath()).toAbsolutePath().normalize().equals(required.toAbsolutePath().normalize()))throw new IllegalArgumentException("Strict Snap dump/restore requires the package-owned compatible native client");
        }
        var digest=MessageDigest.getInstance("SHA-256");
        file(digest,request.getNativeToolPath(),128L*1024*1024,true);
        for(String path:new String[]{profile.getTls().getCaFile(),profile.getTls().getClientCert(),profile.getTls().getClientKey()})if(!path.isEmpty())file(digest,path,1024*1024,false);
        return HexFormat.of().formatHex(digest.digest());
    }
    private static void file(MessageDigest digest,String value,long limit,boolean executable)throws Exception {
        Path selected=Path.of(value);if(!selected.isAbsolute())throw new IllegalArgumentException("Select an absolute native-tool or TLS file path");
        Path path=selected.toRealPath();var before=Files.readAttributes(path,BasicFileAttributes.class);
        if(!before.isRegularFile()||before.size()>limit||executable&&!Files.isExecutable(path))throw new IllegalArgumentException("Selected native-tool/TLS file is unavailable or exceeds its review budget");
        digest.update(path.toString().getBytes(java.nio.charset.StandardCharsets.UTF_8));long size=0;
        try(var input=Files.newInputStream(path)){byte[] buffer=new byte[65536];int count;while((count=input.read(buffer))!=-1){size+=count;if(size>limit)throw new IOException("Selected native-tool/TLS file changed or exceeds its review budget");digest.update(buffer,0,count);}}
        var after=Files.readAttributes(path,BasicFileAttributes.class);
        if(size!=before.size()||after.size()!=before.size()||!after.lastModifiedTime().equals(before.lastModifiedTime())||!java.util.Objects.equals(after.fileKey(),before.fileKey()))throw new IOException("Selected native-tool/TLS file changed during review");
    }
    static String version(Jobs.Job job,Path executable)throws Exception {
        var builder=new ProcessBuilder(executable.toString(),"--version").redirectErrorStream(true);NativeToolTransport.sanitize(builder);
        Process process=builder.start();job.process=process;
        var response=new CompletableFuture<byte[]>();
        Thread.ofVirtual().start(()->{try(var input=process.getInputStream()){byte[] bytes=input.readNBytes(4097);if(bytes.length>4096)throw new IOException("Native-tool version output exceeds 4KiB");response.complete(bytes);}catch(Exception failure){response.completeExceptionally(failure);}});
        Exception primary=null;
        try {
            long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(5);
            while(!process.waitFor(100,TimeUnit.MILLISECONDS)){job.checkCancel();if(response.isCompletedExceptionally())response.get();if(System.nanoTime()>=deadline)throw new IOException("Native-tool version check timed out");}
            job.checkCancel();String text=new String(response.get(1,TimeUnit.SECONDS),java.nio.charset.StandardCharsets.UTF_8);
            if(process.exitValue()!=0)throw new IOException("Native-tool version check failed");return text;
        }catch(Exception failure){primary=failure;throw failure;}
        finally {try{if(process.isAlive()){process.destroy();if(!process.waitFor(1,TimeUnit.SECONDS)){process.destroyForcibly();process.waitFor(1,TimeUnit.SECONDS);}}}catch(Exception cleanup){if(primary!=null)primary.addSuppressed(cleanup);else throw cleanup;}}
    }
}
