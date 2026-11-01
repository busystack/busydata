package io.busystack.busydata.security;

import io.busystack.busydata.protocol.Profile;
import java.io.IOException;
import java.nio.file.*;
import java.util.*;
import javax.net.ssl.SSLContext;

/** Package-owned transport configuration; official clients remain unmodified. */
public final class NativeToolTransport {
    private final Path directory;
    private final String platform;
    public NativeToolTransport(){this(bundledDirectory());}
    public NativeToolTransport(Path directory){this(directory,System.getProperty("os.name"));}
    NativeToolTransport(Path directory,String platform){this.directory=directory.toAbsolutePath();this.platform=platform;}
    private static Path bundledDirectory(){
        try{return Path.of(NativeToolTransport.class.getProtectionDomain().getCodeSource().getLocation().toURI()).getParent().getParent().resolve("native");}
        catch(Exception failure){throw new IllegalStateException("Bundled native transport path is unavailable",failure);}
    }
    public static void sanitize(ProcessBuilder builder) {
        for(String variable:new ArrayList<>(builder.environment().keySet()))if(variable.startsWith("NSS_WRAPPER_")||variable.startsWith("BUSYDATA_FORWARD_")||variable.startsWith("BUSYDATA_NATIVE_")||Set.of("LD_PRELOAD","DYLD_INSERT_LIBRARIES","MYSQL_PWD","MYSQL_TEST_LOGIN_FILE","PGPASSWORD","PGOPTIONS","PGSERVICE","PGSERVICEFILE","PGSYSCONFDIR","PGHOSTADDR").contains(variable))builder.environment().remove(variable);
    }
    public NativeMysqlRelay forward(ProcessBuilder builder,Profile profile,int localPort,SSLContext context)throws IOException {
        boolean windows=platform.startsWith("Windows");
        if(!windows&&!platform.equals("Linux"))throw new IOException("Native backup transport requires an approved desktop platform");
        var relay=new NativeMysqlRelay(profile,localPort,context,windows);
        try{relay.configure(builder,directory);return relay;}
        catch(IOException|RuntimeException failure){
            try{relay.close();}catch(IOException cleanup){failure.addSuppressed(cleanup);}
            throw failure;
        }
    }
}
