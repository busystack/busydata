package io.busystack.busydata;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.security.NativeTlsPolicy;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
class NativeTlsPolicyTest {
 @Test void modesPreserveGuaranteesAndOldNumbers(){
  assertEquals(0,TlsMode.VERIFY_FULL.getNumber());assertEquals(1,TlsMode.INSECURE.getNumber());assertEquals(2,TlsMode.DISABLED.getNumber());
  assertEquals("VERIFY_CA",NativeTlsPolicy.mysqlMode(TlsMode.VERIFY_CA));assertEquals("verify-ca",NativeTlsPolicy.postgresMode(TlsMode.VERIFY_CA));
  assertEquals("PREFERRED",NativeTlsPolicy.mysqlMode(TlsMode.DRIVER_DEFAULT));assertEquals("prefer",NativeTlsPolicy.postgresMode(TlsMode.DRIVER_DEFAULT));
  assertThrows(IllegalArgumentException.class,()->NativeTlsPolicy.mysqlMode(TlsMode.UNRECOGNIZED));
 }
 @Test void nativeCapabilitiesAreCheckedBeforeConnection()throws Exception{
  var selected=Profile.newBuilder().setEngine(Engine.POSTGRESQL).setTls(Tls.newBuilder().setMode(TlsMode.VERIFY_CA).setCaFile("/selected/ca.pem").setJavaTrust(false)).build();
  assertDoesNotThrow(()->NativeTlsPolicy.preflight(selected));
  assertDoesNotThrow(()->NativeTlsPolicy.preflight(selected.toBuilder().setTls(selected.getTls().toBuilder().setJavaTrust(true)).build()));
  assertThrows(IllegalArgumentException.class,()->NativeTlsPolicy.preflight(selected.toBuilder().setEngine(Engine.MARIADB).build()));
  assertDoesNotThrow(()->NativeTlsPolicy.preflight(selected.toBuilder().setTls(selected.getTls().toBuilder().setMode(TlsMode.DISABLED).setClientKey("/missing/inactive")).build()));
 }
}
