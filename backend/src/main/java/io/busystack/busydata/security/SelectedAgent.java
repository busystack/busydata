package io.busystack.busydata.security;

import java.io.IOException;
import java.net.*;
import java.nio.ByteBuffer;
import java.nio.channels.*;
import java.nio.file.Path;
import java.security.*;
import java.util.*;
import java.util.concurrent.TimeUnit;
import org.apache.sshd.agent.*;
import org.apache.sshd.agent.common.AbstractAgentProxy;
import org.apache.sshd.common.config.keys.KeyUtils;
import org.apache.sshd.common.session.SessionContext;
import org.apache.sshd.common.util.buffer.Buffer;
import org.apache.sshd.common.util.buffer.ByteArrayBuffer;

/** MINA owns agent encoding/signatures. This transport exposes one selected identity only. */
public final class SelectedAgent extends AbstractAgentProxy {
    private static final java.util.concurrent.Semaphore WINDOWS_IO=new java.util.concurrent.Semaphore(8,true);
    private SocketChannel socket;
    private Selector selector;
    private FileChannel pipe;
    private final String fingerprint;
    private final long timeoutNanos;
    public SelectedAgent(String socketPath,String fingerprint,int timeoutSeconds)throws IOException {
        super(null);
        if(!fingerprint.matches("SHA256:[A-Za-z0-9+/]{43}=?"))throw new IOException("Select a SHA256 key fingerprint");
        this.fingerprint=fingerprint;timeoutNanos=TimeUnit.SECONDS.toNanos(Math.max(1,Math.min(120,timeoutSeconds)));
        if(System.getProperty("os.name").startsWith("Windows")){
            if(!socketPath.startsWith("\\\\.\\pipe\\")||!socketPath.substring(9).matches("[A-Za-z0-9_.-]{1,128}"))throw new IOException("Select an explicit Windows SSH-agent named pipe, for example \\\\.\\pipe\\openssh-ssh-agent");
            if(!WINDOWS_IO.tryAcquire())throw new IOException("Selected Windows SSH-agent operation limit reached; wait for pending I/O to finish");
            var expired=new java.util.concurrent.atomic.AtomicBoolean();
            var opened=new java.util.concurrent.CompletableFuture<FileChannel>();
            Thread.ofVirtual().start(()->{
                FileChannel channel=null;
                try{channel=FileChannel.open(Path.of(socketPath),java.nio.file.StandardOpenOption.READ,java.nio.file.StandardOpenOption.WRITE);
                    if(expired.get()||!opened.complete(channel))channel.close();}
                catch(Exception failure){opened.completeExceptionally(failure);}
                finally{WINDOWS_IO.release();}
            });
            try{pipe=opened.get(timeoutNanos,TimeUnit.NANOSECONDS);}
            catch(Exception failure){expired.set(true);opened.thenAccept(channel->{try{channel.close();}catch(IOException ignored){}});throw new IOException("Selected Windows SSH-agent pipe could not be opened within the connection timeout",failure);}
            return;
        }
        if(!System.getProperty("os.name").equals("Linux")||!Path.of(socketPath).isAbsolute())throw new IOException("Select an absolute Linux agent socket or an explicit Windows named pipe");
        socket=SocketChannel.open(StandardProtocolFamily.UNIX);selector=Selector.open();
        try{socket.configureBlocking(false);socket.register(selector,SelectionKey.OP_CONNECT);long deadline=System.nanoTime()+timeoutNanos;if(!socket.connect(UnixDomainSocketAddress.of(socketPath))){while(!socket.finishConnect())ready(SelectionKey.OP_CONNECT,deadline);}}
        catch(IOException|RuntimeException error){close();throw error;}
    }
    private void ready(int operation,long deadline)throws IOException {
        long remaining=deadline-System.nanoTime();if(remaining<=0)throw new IOException("SSH agent request timed out");
        socket.keyFor(selector).interestOps(operation);selector.select(Math.max(1,TimeUnit.NANOSECONDS.toMillis(remaining)));selector.selectedKeys().clear();
    }
    private void transfer(ByteBuffer bytes,boolean write,long deadline)throws IOException {
        while(bytes.hasRemaining()){int count=pipe!=null?(write?pipe.write(bytes):pipe.read(bytes)):(write?socket.write(bytes):socket.read(bytes));if(count<0)throw new IOException("SSH agent disconnected");if(count==0){if(pipe==null)ready(write?SelectionKey.OP_WRITE:SelectionKey.OP_READ,deadline);else if(System.nanoTime()>=deadline)throw new IOException("SSH agent pipe timed out");}}
    }
    @Override protected synchronized Buffer request(Buffer message)throws IOException {
        long deadline=System.nanoTime()+timeoutNanos;
        if(pipe!=null){
            if(!WINDOWS_IO.tryAcquire())throw new IOException("Selected Windows SSH-agent operation limit reached; wait for pending I/O to finish");
            var response=new java.util.concurrent.CompletableFuture<Buffer>();
            Thread.ofVirtual().start(()->{try{response.complete(exchange(message,deadline));}catch(Throwable error){response.completeExceptionally(error);}finally{WINDOWS_IO.release();}});
            try{return response.get(timeoutNanos,TimeUnit.NANOSECONDS);}
            catch(Exception failure){close();throw new IOException("Selected Windows SSH-agent request failed or timed out",failure);}
        }
        return exchange(message,deadline);
    }
    private Buffer exchange(Buffer message,long deadline)throws IOException {
        try{
            byte[] request=message.getCompactData();if(request.length>262144)throw new IOException("Agent request limit exceeded");
            transfer(ByteBuffer.wrap(request),true,deadline);var length=ByteBuffer.allocate(4);transfer(length,false,deadline);length.flip();int size=length.getInt();
            if(size<1||size>262144)throw new IOException("Agent response limit exceeded");var reply=ByteBuffer.allocate(size);transfer(reply,false,deadline);return new ByteArrayBuffer(reply.array());
        }catch(IOException error){close();throw error;}
    }
    @Override public Iterable<? extends Map.Entry<PublicKey,String>> getIdentities()throws IOException {
        var selected=new ArrayList<Map.Entry<PublicKey,String>>();
        for(var identity:super.getIdentities())if(KeyUtils.getFingerPrint(identity.getKey()).equals(fingerprint))selected.add(identity);
        if(selected.size()!=1)throw new IOException("The selected SSH-agent identity is unavailable or ambiguous");
        return List.copyOf(selected);
    }
    @Override public Map.Entry<String,byte[]> sign(SessionContext session,PublicKey key,String algorithm,byte[] data)throws IOException {
        if(!KeyUtils.getFingerPrint(key).equals(fingerprint))throw new IOException("Unselected SSH-agent identity rejected");
        return super.sign(session,key,algorithm,data);
    }
    @Override public void addIdentity(KeyPair identity,String comment,SshAgentKeyConstraint... constraints)throws IOException {throw new IOException("Agent mutation is disabled");}
    @Override public void removeIdentity(PublicKey key)throws IOException {throw new IOException("Agent mutation is disabled");}
    @Override public void removeAllIdentities()throws IOException {throw new IOException("Agent mutation is disabled");}
    @Override public boolean isOpen(){return pipe!=null?pipe.isOpen():socket!=null&&socket.isOpen();}
    @Override public void close()throws IOException {try{if(pipe!=null)pipe.close();if(socket!=null)socket.close();}finally{if(selector!=null)selector.close();super.close();}}
}
