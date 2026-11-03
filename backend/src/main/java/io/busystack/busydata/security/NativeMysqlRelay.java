package io.busystack.busydata.security;

import io.busystack.busydata.protocol.*;
import java.io.*;
import java.net.*;
import java.nio.ByteBuffer;
import java.nio.channels.*;
import java.nio.file.*;
import java.nio.file.attribute.PosixFilePermissions;
import java.security.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicBoolean;
import javax.net.ssl.*;

/** One native client, private local IPC, and one existing owned SSH forwarding port.
 * Only the documented initial MySQL TLS negotiation is translated. Authentication
 * remains the official client's responsibility; command-phase bytes are opaque.
 */
public final class NativeMysqlRelay implements AutoCloseable {
    private static final int SSL=0x0800, PROTOCOL_41=0x0200, AUTH_LIMIT=1_048_576;
    private final Profile profile;
    private final int port;
    private final SSLContext tls;
    private final boolean windows;
    private final String endpoint;
    private final byte[] token=new byte[32];
    private final Path directory;
    private final ServerSocketChannel listener;
    private final CompletableFuture<Void> finished=new CompletableFuture<>();
    private final AtomicBoolean closed=new AtomicBoolean();
    private volatile SocketChannel client;
    private volatile Socket upstream;
    private volatile boolean authenticated;
    private final Thread serving;
    private volatile Thread sendingThread;
    private final ScheduledExecutorService timer=Executors.newSingleThreadScheduledExecutor(Thread.ofVirtual().factory());
    private final ScheduledFuture<?> deadline;

    NativeMysqlRelay(Profile profile,int port,SSLContext tls,boolean windows)throws IOException {
        if(port<1||port>65535)throw new IOException("Owned SSH forwarding port is unavailable");
        this.profile=profile;this.port=port;this.tls=tls;this.windows=windows;
        new SecureRandom().nextBytes(token);
        Path created=null;ServerSocketChannel server=null;
        try {
            if(windows) {
                server=ServerSocketChannel.open();server.bind(new InetSocketAddress(InetAddress.getByName("127.0.0.1"),0),1);
                endpoint="BusyData.Native."+HexFormat.of().formatHex(token,0,16);
            } else {
                // Keep sun_path short even when the application runtime directory is long.
                created=Files.createTempDirectory(Path.of("/tmp"),"busydata-native-",PosixFilePermissions.asFileAttribute(PosixFilePermissions.fromString("rwx------")));
                endpoint=created.resolve("client.sock").toString();
                server=ServerSocketChannel.open(StandardProtocolFamily.UNIX);server.bind(UnixDomainSocketAddress.of(endpoint),1);
                Files.setPosixFilePermissions(Path.of(endpoint),PosixFilePermissions.fromString("rw-------"));
            }
        } catch(IOException|RuntimeException failure) {
            if(server!=null)server.close();
            if(created!=null){Files.deleteIfExists(created.resolve("client.sock"));Files.deleteIfExists(created);}
            throw failure;
        }
        directory=created;listener=server;
        deadline=timer.schedule(()->fail(new IOException("Native SSH connection/authentication timed out")),30,TimeUnit.SECONDS);
        serving=ioThread("busydata-native-relay",this::serve);serving.start();
    }

    private Thread ioThread(String name,Runnable operation) {
        // Windows virtual socket read/write pollers can lose readiness when
        // both directions wait on one socket (OpenJDK JDK-8334574). Keep the
        // pinned SDK and use its public blocking platform-thread interface.
        // Each admitted native transfer owns exactly two IO threads; the
        // existing two-transfer admission limit bounds these to four.
        return windows?Thread.ofPlatform().daemon(true).name(name).unstarted(operation):
            Thread.ofVirtual().name(name).unstarted(operation);
    }

    public void configure(ProcessBuilder builder,Path nativeDirectory)throws IOException {
        var args=new ArrayList<>(builder.command());
        if(args.isEmpty())throw new IllegalArgumentException("Native transport requires one selected client");
        // The reviewed caller leaves routing to this one private endpoint.
        // Never let a later generated option override it; a dump database name
        // after '--' remains literal data, including option-shaped names.
        for(int index=1;index<args.size()&&!args.get(index).equals("--");index++) {
            String argument=args.get(index);
            if(argument.equals("--host")||argument.startsWith("--host=")||
                    argument.equals("--port")||argument.startsWith("--port=")||
                    argument.equals("--protocol")||argument.startsWith("--protocol=")||
                    argument.equals("--socket")||argument.startsWith("--socket=")||
                    argument.startsWith("-h")||argument.startsWith("-P")||argument.startsWith("-S"))
                throw new IllegalArgumentException("Native transport requires generated private endpoint options");
        }
        // These are documented client transport options. No resolver interception,
        // injected libraries, inherited login paths, or arbitrary helper paths.
        int at=1;while(at<args.size()&&(args.get(at).startsWith("--defaults-file=")||args.get(at).equals("--no-login-paths")))at++;
        args.add(at++,"--protocol="+(windows?"PIPE":"SOCKET"));
        args.add(at++,"--host="+(windows?".":"localhost"));
        args.add(at,"--socket="+endpoint);
        if(windows) {
            Path launcher=nativeDirectory.resolve("busydata_tool_launcher.exe");
            if(!Files.isRegularFile(launcher,LinkOption.NOFOLLOW_LINKS)||Files.isSymbolicLink(launcher))throw new IOException("The installed package is missing its native pipe transport");
            args.addFirst(launcher.toString());
            builder.environment().put("BUSYDATA_NATIVE_PIPE",endpoint);
            builder.environment().put("BUSYDATA_NATIVE_PORT",Integer.toString(((InetSocketAddress)listener.getLocalAddress()).getPort()));
            builder.environment().put("BUSYDATA_NATIVE_TOKEN",HexFormat.of().formatHex(token));
        }
        builder.command(args);
    }

    /** Call before acknowledging a successful native dump/restore. */
    public void check()throws IOException {
        if(!authenticated)throw new IOException("Native SSH connection did not authenticate");
        try{finished.get(3,TimeUnit.SECONDS);}
        catch(InterruptedException failure){Thread.currentThread().interrupt();throw new IOException("Native SSH transport completion interrupted",failure);}
        catch(TimeoutException failure){throw new IOException("Native SSH transport completion was not acknowledged",failure);}
        catch(ExecutionException failure){throw new IOException("Native SSH transport failed",failure.getCause());}
    }

    private void serve() {
        try {
            client=listener.accept();listener.close();
            InputStream input=channelInput(client);OutputStream output=channelOutput(client);
            if(windows) {
                byte[] supplied=input.readNBytes(token.length);
                try{if(!MessageDigest.isEqual(token,supplied))throw new IOException("Native pipe handoff authentication failed");}
                finally{Arrays.fill(supplied,(byte)0);Arrays.fill(token,(byte)0);}
            }
            Socket remote=new Socket();upstream=remote;
            remote.connect(new InetSocketAddress("127.0.0.1",port),10_000);remote.setSoTimeout(30_000);remote.setTcpNoDelay(true);
            InputStream serverInput=remote.getInputStream();OutputStream serverOutput=remote.getOutputStream();
            Packet greeting=readPacket(serverInput);
            if(greeting.bytes.length>0&&(greeting.bytes[0]&255)==255) {writePacket(output,greeting,0);finished.complete(null);return;}
            int capabilities=capabilitiesOffset(greeting.bytes);
            boolean supportsTls=(flags(greeting.bytes,capabilities,2)&SSL)!=0;
            greeting.bytes[capabilities+1]&=(byte)~8;
            writePacket(output,greeting,0);
            Packet response=readPacket(input);
            if(response.sequence!=1||response.bytes.length<32||(flags(response.bytes,0,4)&PROTOCOL_41)==0||(flags(response.bytes,0,4)&SSL)!=0)
                throw new IOException("Native client returned an unsupported handshake");
            TlsMode mode=profile.getTls().getMode();
            boolean requested=mode!=TlsMode.DISABLED && !(profile.getEngine()==Engine.MARIADB&&mode==TlsMode.DRIVER_DEFAULT);
            boolean required=requested&&mode!=TlsMode.DRIVER_DEFAULT;
            if(required&&!supportsTls)throw new IOException("Native SSH server does not offer the reviewed TLS policy");
            int shift=0;
            if(requested&&supportsTls) {
                byte[] request=Arrays.copyOf(response.bytes,32);request[1]|=8;
                try{writePacket(serverOutput,new Packet(1,request),0);}finally{Arrays.fill(request,(byte)0);}
                String host=profile.getHost();if(host.startsWith("[")&&host.endsWith("]"))host=host.substring(1,host.length()-1);
                SSLSocket secure=(SSLSocket)tls.getSocketFactory().createSocket(remote,host,profile.getPort(),true);upstream=secure;
                SSLParameters parameters=secure.getSSLParameters();
                if(mode==TlsMode.VERIFY_FULL)parameters.setEndpointIdentificationAlgorithm("HTTPS");
                // JSSE's logical peer is the reviewed host, never the SSH loopback address.
                secure.setSSLParameters(parameters);secure.startHandshake();
                serverInput=secure.getInputStream();serverOutput=secure.getOutputStream();
                response.bytes[1]|=8;shift=1;
            }
            try{writePacket(serverOutput,response,shift);}finally{Arrays.fill(response.bytes,(byte)0);}
            final int delta=shift;final InputStream fromServer=serverInput;final OutputStream toServer=serverOutput;
            var sending=new CompletableFuture<Void>();
            Thread sender=ioThread("busydata-native-client-stream",()->{
                try {
                    for(;;) {
                        // Recheck after reading: auth OK is published before the client can
                        // receive it and send its first command (whose sequence restarts at 0).
                        byte[] header=header(input);if(header==null)break;
                        int size=length(header);boolean auth=!authenticated;
                        if(auth&&size>AUTH_LIMIT)throw new IOException("Native authentication packet exceeds its limit");
                        if(auth)header[3]=(byte)((header[3]+delta)&255);
                        toServer.write(header);copy(input,toServer,size);toServer.flush();
                        if(authenticated){input.transferTo(toServer);toServer.flush();break;}
                    }
                    sending.complete(null);
                } catch(Exception failure){sending.completeExceptionally(failure);fail(failure);}
            });sendingThread=sender;sender.start();
            while(!authenticated) {
                Packet packet=readPacket(fromServer);
                boolean terminal=packet.bytes.length>0&&((packet.bytes[0]&255)==0||(packet.bytes[0]&255)==255);
                if(terminal) {authenticated=(packet.bytes[0]&255)==0;deadline.cancel(false);upstream.setSoTimeout(0);}
                try{writePacket(output,packet,-delta);}finally{Arrays.fill(packet.bytes,(byte)0);}
                if(terminal)break;
            }
            fromServer.transferTo(output);output.flush();
            client.shutdownOutput();sender.join(3000);
            if(sender.isAlive())throw new IOException("Native client stream did not close");
            sending.join();finished.complete(null);
        } catch(Exception failure) {if(!closed.get())fail(failure);}
        finally {closeConnections();}
    }

    private record Packet(int sequence,byte[] bytes){}
    private static int capabilitiesOffset(byte[] greeting)throws IOException {
        if(greeting.length==0||greeting[0]!=10)throw new IOException("Unsupported native server greeting");
        int end=1;while(end<greeting.length&&greeting[end]!=0)end++;
        int offset=end+1+4+8+1;
        if(end==greeting.length||offset+7>greeting.length)throw new IOException("Incomplete native server greeting");
        return offset;
    }
    private static int flags(byte[] bytes,int offset,int count){int value=0;for(int i=0;i<count;i++)value|=(bytes[offset+i]&255)<<(i*8);return value;}
    private static int length(byte[] header){return flags(header,0,3);}
    private static byte[] header(InputStream input)throws IOException {int first=input.read();if(first<0)return null;byte[] rest=input.readNBytes(3);if(rest.length!=3)throw new EOFException("Incomplete native packet header");return new byte[]{(byte)first,rest[0],rest[1],rest[2]};}
    private static Packet readPacket(InputStream input)throws IOException {
        byte[] header=header(input);if(header==null)throw new EOFException("Native peer closed during authentication");
        int size=length(header);if(size>AUTH_LIMIT)throw new IOException("Native authentication packet exceeds its limit");
        byte[] bytes=input.readNBytes(size);if(bytes.length!=size)throw new EOFException("Incomplete native authentication packet");return new Packet(header[3]&255,bytes);
    }
    private static void writePacket(OutputStream output,Packet packet,int shift)throws IOException {
        int size=packet.bytes.length;output.write(new byte[]{(byte)size,(byte)(size>>8),(byte)(size>>16),(byte)(packet.sequence+shift)});output.write(packet.bytes);output.flush();
    }
    private static void copy(InputStream input,OutputStream output,int size)throws IOException {
        byte[] buffer=new byte[Math.min(65536,size)];try{while(size>0){int count=input.read(buffer,0,Math.min(buffer.length,size));if(count<0)throw new EOFException("Incomplete native packet");output.write(buffer,0,count);size-=count;}}finally{Arrays.fill(buffer,(byte)0);}
    }
    // Channels.newInputStream/newOutputStream share a blocking-mode monitor;
    // direct independent channel reads/writes preserve full-duplex operation.
    private static InputStream channelInput(SocketChannel channel){return new InputStream(){public int read()throws IOException{byte[] one=new byte[1];return read(one,0,1)<0?-1:one[0]&255;}public int read(byte[] b,int o,int n)throws IOException{return channel.read(ByteBuffer.wrap(b,o,n));}};}
    private static OutputStream channelOutput(SocketChannel channel){return new OutputStream(){public void write(int b)throws IOException{write(new byte[]{(byte)b});}public void write(byte[] b,int o,int n)throws IOException{ByteBuffer buffer=ByteBuffer.wrap(b,o,n);while(buffer.hasRemaining())channel.write(buffer);}};}
    private void fail(Throwable failure){finished.completeExceptionally(failure);closeConnections();}
    private void closeConnections(){try{listener.close();}catch(IOException ignored){}try{if(client!=null)client.close();}catch(IOException ignored){}try{if(upstream!=null)upstream.close();}catch(IOException ignored){}}
    @Override public void close()throws IOException {
        if(!closed.compareAndSet(false,true))return;
        deadline.cancel(false);timer.shutdownNow();closeConnections();Arrays.fill(token,(byte)0);
        if(directory!=null){Files.deleteIfExists(directory.resolve("client.sock"));Files.delete(directory);}
    }
}
