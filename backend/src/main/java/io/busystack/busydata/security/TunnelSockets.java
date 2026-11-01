package io.busystack.busydata.security;

import java.io.*;
import java.net.*;
import javax.net.SocketFactory;

/** Internal socket routing preserves the driver host used by certificate verification. */
public final class TunnelSockets extends SocketFactory {
    public static final InheritableThreadLocal<Integer> PORT=new InheritableThreadLocal<>();
    private final int port;
    public TunnelSockets(){this.port=PORT.get()==null?0:PORT.get();}
    public TunnelSockets(String port){this.port=Integer.parseInt(port);}
    private Socket socket(){return new Socket(){@Override public void connect(SocketAddress address,int timeout)throws IOException{if(port==0)throw new IOException("Tunnel route missing");super.connect(new InetSocketAddress("127.0.0.1",port),timeout);}};}
    public Socket createSocket(){return socket();}
    public Socket createSocket(String h,int p)throws IOException{var s=socket();s.connect(new InetSocketAddress(h,p));return s;}
    public Socket createSocket(String h,int p,InetAddress local,int lp)throws IOException{var s=socket();s.bind(new InetSocketAddress(local,lp));s.connect(new InetSocketAddress(h,p));return s;}
    public Socket createSocket(InetAddress h,int p)throws IOException{return createSocket(h.getHostAddress(),p);}
    public Socket createSocket(InetAddress h,int p,InetAddress l,int lp)throws IOException{return createSocket(h.getHostAddress(),p,l,lp);}
}
