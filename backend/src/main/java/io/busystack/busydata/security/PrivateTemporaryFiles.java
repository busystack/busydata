package io.busystack.busydata.security;

import io.busystack.busydata.results.ResultStore;
import java.io.IOException;
import java.nio.file.*;

/** Owned credential scratch space. Construct only after the metadata writer lease. */
public final class PrivateTemporaryFiles implements AutoCloseable {
    private final Path root;
    private boolean closed;
    public PrivateTemporaryFiles(Path root)throws IOException {
        this.root=root;
        if(Files.isSymbolicLink(root))throw new IOException("Private scratch directory must not be a symlink");
        Files.createDirectories(root);ResultStore.privateDirectory(root);clean();
    }
    public static PrivateTemporaryFiles isolated()throws IOException{return new PrivateTemporaryFiles(Files.createTempDirectory("busydata-private-"));}
    public synchronized Path create(String prefix,String suffix)throws IOException {
        if(closed)throw new IOException("Private scratch space is closed");
        Path file=Files.createTempFile(root,prefix,suffix);ResultStore.privateFile(file);return file;
    }
    private void clean()throws IOException {
        try(var files=Files.list(root)){for(Path file:files.toList()){
            if(Files.isDirectory(file,LinkOption.NOFOLLOW_LINKS))throw new IOException("Unexpected directory in private scratch space");
            Files.delete(file); // This application's dedicated flat directory only, without following symlinks.
        }}
    }
    public synchronized void close()throws IOException{if(closed)return;closed=true;clean();Files.delete(root);}
}
