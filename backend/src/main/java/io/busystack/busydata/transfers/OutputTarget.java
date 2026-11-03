package io.busystack.busydata.transfers;

import java.io.*;
import java.nio.file.*;
import java.nio.file.attribute.BasicFileAttributes;
import java.security.*;
import java.util.HexFormat;

/** Reviewed file identity; hashes bytes using a fixed buffer before replacement. */
public final class OutputTarget {
    private OutputTarget(){}
    /** No-follow entry identity, independent of content approval. */
    record EntryIdentity(Object key, String kind) {}
    static EntryIdentity entryIdentity(Path path)throws IOException {
        if(System.getProperty("os.name", "").startsWith("Windows")) {
            try{return WindowsOutputFiles.entryIdentity(path);}catch(NoSuchFileException missing){return null;}
        }
        final BasicFileAttributes attributes;
        try{attributes=Files.readAttributes(path,BasicFileAttributes.class,LinkOption.NOFOLLOW_LINKS);}
        catch(NoSuchFileException missing){return null;}
        if(attributes.fileKey()==null)throw new IOException("Filesystem does not expose directory-entry identity");
        return new EntryIdentity(attributes.fileKey(),attributes.isSymbolicLink()?"link":attributes.isDirectory()?"directory":attributes.isRegularFile()?"file":"special");
    }
    public static String identity(Path target)throws Exception {
        target=target.toAbsolutePath().normalize();
        return parentIdentity(target)+":"+fileIdentity(target);
    }
    static String parentIdentity(Path target)throws IOException {
        Path parent=target.toAbsolutePath().normalize().getParent();if(parent==null)throw new IOException("Destination has no parent directory");
        if(parent.getNameCount()>128)throw new IOException("Destination directory depth exceeds 128");
        StringBuilder identity=new StringBuilder(parent.toString());Path current=parent.getRoot();
        for(Path component:parent){current=current.resolve(component);var entry=entryIdentity(current);if(entry==null||!entry.kind().equals("directory"))throw new IOException("Destination ancestors must be identifiable ordinary directories");identity.append('|').append(entry.key());}
        return identity.toString();
    }
    static String fileIdentity(Path target)throws Exception {
        final BasicFileAttributes before;
        try{before=Files.readAttributes(target,BasicFileAttributes.class,LinkOption.NOFOLLOW_LINKS);}catch(NoSuchFileException missing){return "absent";}
        if(!before.isRegularFile()||before.isSymbolicLink())throw new IOException("Destination must be an ordinary file");
        Object beforeKey=fileKey(target,before);
        if(before.size()>32L*1024*1024*1024)throw new IOException("Existing destination exceeds the 32GiB reviewed-output limit");
        var digest=MessageDigest.getInstance("SHA-256");
        try(var input=Files.newInputStream(target,LinkOption.NOFOLLOW_LINKS)) {
            byte[] buffer=new byte[65536];int count;long bytes=0;
            while((count=input.read(buffer))>=0){if(Thread.currentThread().isInterrupted()||io.grpc.Context.current().isCancelled())throw new InterruptedIOException("Destination review cancelled");bytes+=count;if(bytes>32L*1024*1024*1024)throw new IOException("Destination grew beyond the 32GiB reviewed-output limit");digest.update(buffer,0,count);}
        }
        var after=Files.readAttributes(target,BasicFileAttributes.class,LinkOption.NOFOLLOW_LINKS);
        Object afterKey=fileKey(target,after);
        if(!java.util.Objects.equals(beforeKey,afterKey)||before.size()!=after.size()||!before.lastModifiedTime().equals(after.lastModifiedTime()))throw new IOException("Destination changed during review");
        if(afterKey==null)throw new IOException("Filesystem does not expose destination identity");
        return afterKey+":"+after.size()+":"+HexFormat.of().formatHex(digest.digest());
    }
    private static Object fileKey(Path path,BasicFileAttributes attributes)throws IOException {
        if(System.getProperty("os.name", "").startsWith("Windows")) {
            var entry=WindowsOutputFiles.entryIdentity(path);
            if(!entry.kind().equals("file"))throw new IOException("Destination must be an ordinary file");
            return entry.key();
        }
        return attributes.fileKey();
    }
    public static long quota(io.busystack.busydata.protocol.ToolRequest request) {
        long quota=request.getOutputLimitBytes()==0?8L*1024*1024*1024:request.getOutputLimitBytes();
        if(quota<1||quota>32L*1024*1024*1024)throw new IllegalArgumentException("Export output quota must be 1 byte–32GiB");return quota;
    }
    public static OutputStream stream(Path partial,long limit)throws IOException {
        return new FilterOutputStream(Files.newOutputStream(partial,StandardOpenOption.WRITE,StandardOpenOption.TRUNCATE_EXISTING,LinkOption.NOFOLLOW_LINKS)) {
            long written;
            @Override public void write(int value)throws IOException {if(written>=limit)throw new IOException("EXPORT_OUTPUT_QUOTA");out.write(value);written++;}
            @Override public void write(byte[] values,int offset,int length)throws IOException {if(length>limit-written)throw new IOException("EXPORT_OUTPUT_QUOTA");out.write(values,offset,length);written+=length;}
        };
    }
}
