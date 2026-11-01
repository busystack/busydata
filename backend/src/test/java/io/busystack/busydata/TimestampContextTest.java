package io.busystack.busydata;

import io.busystack.busydata.adapters.JdbcAdapter.LiveContext;
import io.busystack.busydata.metadata.TimestampContext;
import java.util.List;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class TimestampContextTest {
    @Test void fixedOffsetsAndNativeUtcSystemContextHaveStableKeys(){
        assertEquals("timestamp-offset:+00:00",TimestampContext.key("SYSTEM","UTC"));assertEquals(TimestampContext.key("+00:00","ignored"),TimestampContext.key("-00:00","ignored"));for(String offset:List.of("-13:59","+14:00","+05:30","-08:00"))assertEquals("timestamp-offset:"+offset,TimestampContext.key(offset,"ignored"));
    }
    @Test void namedDstMissingAndMalformedContextsRemainExplicitlyUnknown(){for(String zone:List.of("","UTC","Europe/Berlin","America/Vancouver","+14:01","-14:00","+01:60","+1:00","+0000"," +00:00"))assertEquals("",TimestampContext.key(zone,"UTC"),zone);for(String system:List.of("","GMT","CET","CEST","PST","UTC+1"))assertEquals("",TimestampContext.key("SYSTEM",system));}
    @Test void contextEqualityChangesWhenEitherNativeTimezoneFactChanges(){var original=new LiveContext("db","db",List.of("db"),"","",true,"+00:00","UTC");assertNotEquals(original,new LiveContext("db","db",List.of("db"),"","",true,"+01:00","UTC"));assertNotEquals(original,new LiveContext("db","db",List.of("db"),"","",true,"+00:00","CET"));assertEquals("timestamp-offset:+00:00",TimestampContext.key(original));}
}
