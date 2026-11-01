package io.busystack.busydata.security;

import io.busystack.busydata.protocol.*;
import java.nio.file.*;
import java.util.*;
import javax.net.ssl.SSLContext;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

class NativeToolTransportTest {
    @TempDir Path root;
    private Profile selected(Engine engine,TlsMode mode){return Profile.newBuilder().setEngine(engine).setHost("reviewed.invalid").setPort(3306).setSsh(Ssh.newBuilder().setEnabled(true)).setTls(Tls.newBuilder().setMode(mode)).build();}
    private ProcessBuilder command(Profile profile){
        var arguments=new ArrayList<>(List.of("selected-client.exe","--defaults-file=private-selected.cnf"));
        if(profile.getEngine()==Engine.MYSQL)arguments.add("--no-login-paths");
        arguments.add(profile.getEngine()==Engine.MYSQL?"--ssl-mode=DISABLED":"--skip-ssl");
        arguments.add("--");arguments.add("--host=literal-database");
        return new ProcessBuilder(arguments);
    }
    private NativeToolTransport windows()throws Exception{Files.writeString(root.resolve("busydata_tool_launcher.exe"),"owned process fixture");return new NativeToolTransport(root,"Windows 11");}

    @Test void verifiedWindowsProfilesUsePrivateIpcAndCannotAcknowledgeBeforeAuthentication()throws Exception{
        var transport=windows();
        for(Engine engine:List.of(Engine.MYSQL,Engine.MARIADB)){
            var profile=selected(engine,TlsMode.VERIFY_FULL);var builder=command(profile);
            NativeToolTransport.sanitize(builder);
            try(var relay=transport.forward(builder,profile,54321,SSLContext.getDefault())){
                assertEquals(TlsMode.VERIFY_FULL,profile.getTls().getMode());
                assertEquals(root.resolve("busydata_tool_launcher.exe").toString(),builder.command().getFirst());
                assertTrue(builder.command().contains("--protocol=PIPE"));
                assertTrue(builder.command().contains("--host=."));
                assertEquals(1,builder.command().stream().filter(value->value.startsWith("--socket=BusyData.Native.")).count());
                assertEquals("--host=literal-database",builder.command().getLast());
                assertThrows(java.io.IOException.class,relay::check);
            }
        }
    }
    @Test void privateRoutingPreservesLiteralArgumentsAndLeadingLoginIsolation()throws Exception{
        var transport=windows();
        for(TlsMode mode:List.of(TlsMode.DISABLED,TlsMode.DRIVER_DEFAULT,TlsMode.INSECURE,TlsMode.VERIFY_CA,TlsMode.VERIFY_FULL)){
            var profile=selected(Engine.MYSQL,mode);var builder=command(profile);NativeToolTransport.sanitize(builder);
            var before=List.copyOf(builder.command());
            try(var relay=transport.forward(builder,profile,54321,SSLContext.getDefault())){
                var arguments=builder.command();
                assertEquals(before.subList(0,3),arguments.subList(1,4));
                assertEquals(before.subList(3,before.size()),arguments.subList(7,arguments.size()));
                assertEquals(List.of("--protocol=PIPE","--host=."),arguments.subList(4,6));
                assertFalse(builder.environment().keySet().stream().anyMatch(key->key.startsWith("BUSYDATA_FORWARD_")));
                assertFalse(builder.environment().containsKey("LD_PRELOAD"));
            }
        }
    }
    @Test void preexistingEndpointOptionsCannotOverrideThePrivateTransport()throws Exception{
        var transport=windows();var profile=selected(Engine.MYSQL,TlsMode.VERIFY_FULL);
        for(String invalid:List.of("--host=other.invalid","--host","--port=12345","--port",
                "--protocol=TCP","--protocol","--socket=other","--socket",
                "-hother.invalid","-h","-P12345","-P","-Sother","-S")){
            var builder=command(profile);var arguments=new ArrayList<>(builder.command());arguments.add(3,invalid);builder.command(arguments);
            var before=List.copyOf(arguments);var environment=Map.copyOf(builder.environment());
            assertThrows(IllegalArgumentException.class,()->transport.forward(builder,profile,54321,SSLContext.getDefault()));
            assertEquals(before,builder.command());assertEquals(environment,builder.environment());
        }
    }
    @Test void unsupportedPlatformAndInvalidPortCannotMutateTheReviewedCommand()throws Exception{
        var profile=selected(Engine.MYSQL,TlsMode.VERIFY_FULL);var transport=windows();
        for(int port:List.of(0,65536)){
            var builder=command(profile);var before=List.copyOf(builder.command());
            assertThrows(java.io.IOException.class,()->transport.forward(builder,profile,port,SSLContext.getDefault()));
            assertEquals(before,builder.command());
        }
        var builder=command(profile);var before=List.copyOf(builder.command());
        assertThrows(java.io.IOException.class,()->new NativeToolTransport(root,"Other desktop").forward(builder,profile,54321,SSLContext.getDefault()));
        assertEquals(before,builder.command());
    }
    @Test void missingOrNonregularOwnedLauncherFailsWithoutDirectExecutionFallback(){
        var profile=selected(Engine.MARIADB,TlsMode.VERIFY_FULL);var builder=command(profile);var before=List.copyOf(builder.command());
        assertThrows(java.io.IOException.class,()->new NativeToolTransport(root,"Windows 11").forward(builder,profile,54321,SSLContext.getDefault()));
        assertEquals(before,builder.command());
        assertDoesNotThrow(()->Files.createDirectory(root.resolve("busydata_tool_launcher.exe")));
        assertThrows(java.io.IOException.class,()->new NativeToolTransport(root,"Windows 11").forward(builder,profile,54321,SSLContext.getDefault()));
        assertEquals(before,builder.command());
    }
    @Test void linuxPrivateSocketNeedsNoLoaderInterposition()throws Exception{
        var profile=selected(Engine.MYSQL,TlsMode.VERIFY_FULL);var builder=command(profile);NativeToolTransport.sanitize(builder);
        Path endpoint;
        try(var relay=new NativeToolTransport(root,"Linux").forward(builder,profile,54321,SSLContext.getDefault())){
            assertEquals("selected-client.exe",builder.command().getFirst());
            assertTrue(builder.command().contains("--protocol=SOCKET"));
            assertTrue(builder.command().contains("--host=localhost"));
            endpoint=Path.of(builder.command().stream().filter(value->value.startsWith("--socket=")).findFirst().orElseThrow().substring(9));
            assertTrue(Files.exists(endpoint));assertEquals("rwx------",java.nio.file.attribute.PosixFilePermissions.toString(Files.getPosixFilePermissions(endpoint.getParent())));
            assertEquals("--host=literal-database",builder.command().getLast());
            assertFalse(builder.environment().containsKey("BUSYDATA_FORWARD_HOST"));assertFalse(builder.environment().containsKey("LD_PRELOAD"));
        }
        assertFalse(Files.exists(endpoint.getParent()));
    }
    @Test void inheritedForwardingControlsAreRemovedBeforeOwnedRouting(){
        var builder=new ProcessBuilder("selected-client.exe");
        var variables=List.of("BUSYDATA_FORWARD_HOST","BUSYDATA_FORWARD_READY","BUSYDATA_NATIVE_PIPE","BUSYDATA_NATIVE_PORT","BUSYDATA_NATIVE_TOKEN","LD_PRELOAD","DYLD_INSERT_LIBRARIES","NSS_WRAPPER_HOSTS","MYSQL_PWD","MYSQL_TEST_LOGIN_FILE","PGHOSTADDR");
        for(String key:variables)builder.environment().put(key,"untrusted");
        NativeToolTransport.sanitize(builder);
        for(String key:variables)assertFalse(builder.environment().containsKey(key));
    }
}
