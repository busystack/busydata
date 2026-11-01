package io.busystack.busydata.transfers;

import java.io.IOException;
import java.nio.channels.FileChannel;
import java.nio.file.*;
import java.nio.file.attribute.*;
import java.util.*;

/** One owner for reviewed outputs: private staging, no-clobber publication/recovery, cleanup. */
public final class OutputCommit implements AutoCloseable {
    enum Phase { PREPARED, PRESERVED_UNVERIFIED, PRESERVED_VERIFIED, PUBLISHED, FINISHED }
    public static final class RecoveryRequired extends IOException {
        public final Path recovery, partial;
        public final boolean published;
        public final String reason;
        RecoveryRequired(Path recovery,Path partial,boolean published,Exception primary){
            super(published?"OUTPUT_PUBLISHED_RECOVERY_REQUIRED":"OUTPUT_RECOVERY_REQUIRED",primary);
            this.recovery=recovery;this.partial=partial;this.published=published;
            // This exception is built only inside the filesystem policy, never
            // from JDBC diagnostics, SQL text or native-tool stderr.
            reason=primary.getMessage()==null?primary.getClass().getSimpleName():primary.getMessage();
        }
    }
    public interface Faults {
        default void beforeCommit(Path target,Path partial)throws Exception{}
        default void beforePrimitive(Path target,Path partial)throws Exception{}
        default void afterPreserve(Path target,Path recovery)throws Exception{}
        default void beforeVerify(Path recovery)throws Exception{}
        default void beforePublish(Path target,Path partial)throws Exception{}
        default void beforeRestore(Path target,Path recovery)throws Exception{}
        default void beforeCleanup(Path target,Path recovery)throws Exception{}
        default void afterPrimitive(Path target,Path partial)throws Exception{}
        default void delete(Path partial)throws IOException{Files.deleteIfExists(partial);}
    }
    private static final Faults NONE=new Faults(){};
    private final Path target,parent,partial;
    private final String reviewed,parentIdentity;
    private final OutputTarget.EntryIdentity stagingIdentity;
    private final Faults faults;
    private final LinuxOutputFiles linux;
    private final WindowsOutputFiles windows;
    private boolean closed;
    private Phase phase=Phase.PREPARED;
    private Path recovery;
    private OutputTarget.EntryIdentity displaced;

    public static OutputCommit open(Path target,boolean overwrite)throws Exception {
        return open(target,overwrite,OutputTarget.identity(target),NONE);
    }
    public static OutputCommit open(Path target,boolean overwrite,String reviewed)throws Exception {
        return open(target,overwrite,reviewed,NONE);
    }
    public static OutputCommit open(Path target,boolean overwrite,String reviewed,Faults faults)throws Exception {
        return new OutputCommit(target,overwrite,reviewed,faults);
    }
    private OutputCommit(Path destination,boolean overwrite,String reviewed,Faults faults)throws Exception {
        target=destination.toAbsolutePath().normalize();parent=target.getParent();this.faults=faults;
        if(parent==null||target.getFileName()==null)throw new IOException("Select an ordinary destination file");
        parentIdentity=OutputTarget.parentIdentity(target);
        if(!OutputTarget.identity(target).equals(reviewed))throw new IOException("Destination changed after review; review it again");
        this.reviewed=reviewed.substring(parentIdentity.length()+1);
        if(!this.reviewed.equals("absent")&&!overwrite)throw new FileAlreadyExistsException(target.toString());
        LinuxOutputFiles openedLinux=null;WindowsOutputFiles openedWindows=null;Path staging=null;
        OutputTarget.EntryIdentity created=null;
        try {
            String os=System.getProperty("os.name").toLowerCase(Locale.ROOT);
            if(os.contains("linux"))openedLinux=LinuxOutputFiles.open(parent);
            else if(os.contains("windows"))openedWindows=WindowsOutputFiles.open(parent);
            else throw new IOException("Safe destination commit is supported only on Linux and Windows");
            Path directory=openedLinux==null?parent:openedLinux.directory();
            if(!Objects.equals(Files.readAttributes(parent,BasicFileAttributes.class,LinkOption.NOFOLLOW_LINKS).fileKey(),Files.readAttributes(directory,BasicFileAttributes.class).fileKey()))throw new IOException("Destination parent changed during opening");
            if(!this.reviewed.equals(OutputTarget.fileIdentity(directory.resolve(target.getFileName()))))throw new IOException("Destination changed during opening; review it again");
            staging=Files.createTempFile(directory,".busydata-",".partial");
            created=OutputTarget.entryIdentity(staging);makePrivate(staging);
            if(!parentIdentity.equals(OutputTarget.parentIdentity(target)))throw new IOException("Destination parent changed during opening");
        }catch(Exception primary){
            if(staging!=null)try{deleteOwned(staging,created);}catch(Exception failure){primary.addSuppressed(new RecoveryRequired(null,parent.resolve(staging.getFileName()),false,failure));}
            if(openedLinux!=null)try{openedLinux.close();}catch(Exception failure){primary.addSuppressed(failure);}
            if(openedWindows!=null)try{openedWindows.close();}catch(Exception failure){primary.addSuppressed(failure);}
            throw primary;
        }
        linux=openedLinux;windows=openedWindows;partial=staging;stagingIdentity=created;
    }
    public Path partial(){if(closed)throw new IllegalStateException("Output closed");return partial;}
    private Path anchored(Path path){return (linux==null?parent:linux.directory()).resolve(path.getFileName());}
    private Path visible(Path path){
        if(path==null)return null;
        if(linux!=null)try{return linux.directory().toRealPath().resolve(path.getFileName());}catch(IOException ignored){/* Original display path plus reported parent uncertainty. */}
        return parent.resolve(path.getFileName());
    }
    private void checkParent()throws IOException {
        if(!parentIdentity.equals(OutputTarget.parentIdentity(target)))throw new IOException("Destination parent changed; entries remain in the held original directory");
    }
    public void commit()throws Exception {
        if(closed||phase!=Phase.PREPARED)throw new IllegalStateException("Output already finalized");
        try {
            faults.beforeCommit(target,partial);checkParent();
            if(!reviewed.equals(OutputTarget.fileIdentity(anchored(target))))throw new IOException("Destination changed after review; original file preserved");
            requireEntry(partial,stagingIdentity);
            String produced=OutputTarget.fileIdentity(partial);
            var producedAttributes=Files.readAttributes(partial,BasicFileAttributes.class,LinkOption.NOFOLLOW_LINKS);
            try(var channel=FileChannel.open(partial,StandardOpenOption.WRITE,LinkOption.NOFOLLOW_LINKS)){channel.force(true);}
            faults.beforePrimitive(target,partial);checkParent();requireEntry(partial,stagingIdentity);
            if(!reviewed.equals("absent")) {
                Path selectedRecovery=parent.resolve(".busydata-"+UUID.randomUUID()+".recovery");
                moveNew(target,selectedRecovery);
                // Record the move before identity inspection or any hook can fail.
                recovery=selectedRecovery;phase=Phase.PRESERVED_UNVERIFIED;
                displaced=OutputTarget.entryIdentity(anchored(recovery));
                if(displaced==null)throw new IOException("Displaced entry disappeared before identification");
                faults.afterPreserve(target,recovery);faults.beforeVerify(anchored(recovery));
                if(!reviewed.equals(OutputTarget.fileIdentity(anchored(recovery))))throw new IOException("Displaced entry was not approved for replacement");
                phase=Phase.PRESERVED_VERIFIED;
                requireEntry(anchored(recovery),displaced);makePrivate(anchored(recovery));
            }
            faults.beforePublish(target,partial);checkParent();
            requireEntry(partial,stagingIdentity);
            var currentAttributes=Files.readAttributes(partial,BasicFileAttributes.class,LinkOption.NOFOLLOW_LINKS);
            if(currentAttributes.size()!=producedAttributes.size()||!currentAttributes.lastModifiedTime().equals(producedAttributes.lastModifiedTime()))throw new IOException("Produced partial changed before publication");
            if(recovery!=null)requireEntry(anchored(recovery),displaced);
            moveNew(partial,target);phase=Phase.PUBLISHED;
            faults.afterPrimitive(target,partial);checkParent();
            if(!produced.equals(OutputTarget.fileIdentity(anchored(target))))throw new IOException("Another writer changed the published destination; no further replacement attempted");
            if(recovery!=null) {
                faults.beforeCleanup(target,recovery);checkParent();
                requireEntry(anchored(target),stagingIdentity);
                requireEntry(anchored(recovery),displaced);
                if(!reviewed.equals(OutputTarget.fileIdentity(anchored(recovery))))throw new IOException("Recovery content changed; cleanup refused");
                faults.delete(anchored(recovery));recovery=null;
            }
            phase=Phase.FINISHED;
        } catch(Exception primary) {
            if(phase==Phase.PUBLISHED||phase==Phase.FINISHED)throw new RecoveryRequired(visible(recovery),null,true,primary);
            if(recovery!=null) {
                try {
                    faults.beforeRestore(target,recovery);
                    // Compensation uses metadata + no-replace rename, never hashing,
                    // following links, chmod, or traversal of a displaced directory.
                    requireEntry(anchored(recovery),displaced);
                    moveNew(recovery,target);recovery=null;phase=Phase.PREPARED;
                }catch(Exception restore){
                    var failure=new RecoveryRequired(visible(recovery),visible(partial),false,primary);
                    failure.addSuppressed(restore);throw failure;
                }
            }
            throw primary;
        }
    }
    private void moveNew(Path source,Path destination)throws IOException {
        if(linux!=null)linux.moveNew(source.getFileName().toString(),destination.getFileName().toString());
        else windows.moveNew(source,destination);
    }
    private static void requireEntry(Path path,OutputTarget.EntryIdentity expected)throws IOException {
        if(expected==null||!expected.equals(OutputTarget.entryIdentity(path)))throw new IOException("Entry ownership changed or cannot be established: "+path.getFileName());
    }
    private static void deleteOwned(Path path,OutputTarget.EntryIdentity expected)throws IOException {
        if(OutputTarget.entryIdentity(path)==null)return;
        requireEntry(path,expected);
        if(!expected.kind().equals("file"))throw new IOException("Automatic cleanup requires an owned ordinary file");
        Files.delete(path);
    }
    /** Cleanup staging independently of recovery; try-with-resources retains both failures. */
    @Override public void close()throws IOException {
        if(closed)return;closed=true;IOException primary=null;
        try {
            if(OutputTarget.entryIdentity(partial)!=null) {
                requireEntry(partial,stagingIdentity);faults.delete(partial);
            }
        }catch(Exception failure){primary=new RecoveryRequired(null,visible(partial),phase==Phase.PUBLISHED||phase==Phase.FINISHED,failure);}
        try{if(linux!=null)linux.close();if(windows!=null)windows.close();}catch(IOException failure){if(primary==null)primary=failure;else primary.addSuppressed(failure);}
        if(primary!=null)throw primary;
    }
    private static void makePrivate(Path path)throws IOException {
        var posix=Files.getFileAttributeView(path,PosixFileAttributeView.class,LinkOption.NOFOLLOW_LINKS);
        if(posix!=null){posix.setPermissions(PosixFilePermissions.fromString("rw-------"));return;}
        var acl=Files.getFileAttributeView(path,AclFileAttributeView.class,LinkOption.NOFOLLOW_LINKS);
        if(acl==null)throw new IOException("Private output permissions are unavailable");
        acl.setAcl(List.of(AclEntry.newBuilder().setType(AclEntryType.ALLOW).setPrincipal(acl.getOwner()).setPermissions(EnumSet.allOf(AclEntryPermission.class)).build()));
    }
}
