package io.busystack.busydata.transfers;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.security.SecureRandom;
import java.util.HexFormat;
import java.util.regex.Pattern;

/** A fresh psql restriction key is delivered only through the owned stdin pipe.
 * Standard pg_dump header/footer guards are replaced; all SQL/COPY bytes remain
 * authoritative. Other client commands are rejected by psql itself, including
 * backslashes occurring after SQL rather than only at the start of a line. */
final class PostgresRestoreInput {
    private static final Pattern HEADER=Pattern.compile("\\A((?:[ \\t\\r\\n]|--[^\\r\\n]*(?:\\r?\\n))*)\\\\restrict[ \\t]+[A-Za-z0-9]{1,256}[ \\t]*\\r?\\n");
    private static final Pattern FOOTER=Pattern.compile("(?m)^\\\\unrestrict[ \\t]+[A-Za-z0-9]{1,256}[ \\t]*\\r?\\n(?=(?:[ \\t\\r\\n]|--[^\\r\\n]*(?:\\r?\\n|$))*\\z)");
    static void write(Path source,OutputStream output,ImportSources.Cancellation cancellation)throws Exception {
        byte[] secret=new byte[32];new SecureRandom().nextBytes(secret);
        output.write(("\\restrict "+HexFormat.of().formatHex(secret)+"\n").getBytes(StandardCharsets.US_ASCII));
        try(var input=new BufferedInputStream(Files.newInputStream(source,LinkOption.NOFOLLOW_LINKS),65536)) {
            byte[] first=input.readNBytes(4096);
            String header=new String(first,StandardCharsets.ISO_8859_1);
            var match=HEADER.matcher(header);boolean nativeDump=match.find();
            if(nativeDump)first=(header.substring(0,match.start())+match.group(1)+header.substring(match.end())).getBytes(StandardCharsets.ISO_8859_1);
            byte[] pending=first,buffer=new byte[65536];int count;
            while((count=input.read(buffer))!=-1) {
                cancellation.check();
                int keep=Math.min(4096,pending.length+count),emit=pending.length+count-keep;
                int fromPending=Math.min(emit,pending.length);
                output.write(pending,0,fromPending);output.write(buffer,0,emit-fromPending);
                byte[] next=new byte[keep];int old=pending.length-fromPending;
                if(old>0)System.arraycopy(pending,fromPending,next,0,old);
                System.arraycopy(buffer,emit-fromPending,next,old,count-(emit-fromPending));pending=next;
            }
            cancellation.check();
            if(nativeDump) {
                String tail=new String(pending,StandardCharsets.ISO_8859_1);
                pending=FOOTER.matcher(tail).replaceAll("").getBytes(StandardCharsets.ISO_8859_1);
            }
            output.write(pending);
            // EOF leaves psql restricted. No source line is allowed to discover
            // or interpolate this new key, and no shell ever receives it.
        }
    }
}
