package io.busystack.busydata.security;

import java.net.InetSocketAddress;
import java.net.UnixDomainSocketAddress;
import java.nio.ByteBuffer;
import java.nio.channels.SocketChannel;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;
import java.util.HexFormat;

/** Exercise the platform's actual relay handoff without starting a native tool. */
final class NativeRelayFixture {
    static final boolean WINDOWS=System.getProperty("os.name").startsWith("Windows");

    static void launcher(Path directory)throws Exception {
        if(WINDOWS&&!Files.exists(directory.resolve("busydata_tool_launcher.exe")))
            Files.createFile(directory.resolve("busydata_tool_launcher.exe"));
    }

    static String endpoint(ProcessBuilder builder) {
        return builder.command().stream().filter(x->x.startsWith("--socket=")).findFirst().orElseThrow().substring(9);
    }

    static SocketChannel connect(ProcessBuilder builder)throws Exception {
        if(!WINDOWS)return SocketChannel.open(UnixDomainSocketAddress.of(endpoint(builder)));
        var channel=SocketChannel.open(new InetSocketAddress("127.0.0.1",Integer.parseInt(builder.environment().get("BUSYDATA_NATIVE_PORT"))));
        byte[] token=HexFormat.of().parseHex(builder.environment().get("BUSYDATA_NATIVE_TOKEN"));
        try {
            ByteBuffer handoff=ByteBuffer.wrap(token);
            while(handoff.hasRemaining())channel.write(handoff);
            return channel;
        } catch(Exception failure) {channel.close();throw failure;}
        finally {Arrays.fill(token,(byte)0);}
    }
}
