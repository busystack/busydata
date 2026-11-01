package io.busystack.busydata.security;
import com.mysql.cj.protocol.StandardSocketFactory;
import com.mysql.cj.conf.PropertySet;
import java.io.IOException;
import java.net.Socket;
public final class MysqlTunnelSockets extends StandardSocketFactory {
    @SuppressWarnings("unchecked")
    @Override public <T extends java.io.Closeable> T connect(String host,int port,PropertySet properties,int timeout)throws IOException {
        Integer route=TunnelSockets.PORT.get();if(route==null)throw new IOException("Tunnel route missing");
        return super.connect("127.0.0.1",route,properties,timeout);
    }
}
