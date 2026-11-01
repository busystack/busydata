package io.busystack.busydata.security;

import java.io.IOException;
import java.nio.channels.Channels;
import java.nio.file.*;

/** Bound selected security material on the opened handle before parsing it. */
public final class SelectedFiles {
    private SelectedFiles(){}
    public static byte[] read(Path requested,String description,int limit)throws IOException {
        if(limit<1||limit>1_048_576)throw new IllegalArgumentException("Invalid security material byte budget");
        if(!requested.isAbsolute())throw new IOException("Select an absolute "+description+" file");
        Path actual=requested.toRealPath();
        if(!Files.isRegularFile(actual,LinkOption.NOFOLLOW_LINKS))throw new IOException("Select a regular "+description+" file");
        try(var channel=Files.newByteChannel(actual,StandardOpenOption.READ,LinkOption.NOFOLLOW_LINKS)) {
            if(channel.size()>limit)throw new IOException(description+" exceeds its byte budget");
            var bytes=Channels.newInputStream(channel).readNBytes(limit+1);
            if(bytes.length>limit){java.util.Arrays.fill(bytes,(byte)0);throw new IOException(description+" changed or exceeds its byte budget");}
            return bytes;
        }
    }
}
