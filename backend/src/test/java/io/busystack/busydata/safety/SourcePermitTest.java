package io.busystack.busydata.safety;

import io.busystack.busydata.analysis.SqlAnalysis;
import java.util.concurrent.atomic.AtomicLong;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class SourcePermitTest {
    private static final String SOURCE="a".repeat(64);
    @Test void sourcePermitIsConsumedBeforeLongAdmissionAndCannotBeReplayed()throws Exception {
        var clock=new AtomicLong(1_000);var safety=new Safety(new SqlAnalysis(),clock::get);
        String token=safety.issueSource("request-revision-and-"+SOURCE,SOURCE);
        clock.addAndGet(119_000);
        String source=safety.consumeSource(token,reviewed->{
            clock.addAndGet(300_000);
            return "request-revision-and-"+reviewed;
        });
        assertEquals(SOURCE,source);
        assertThrows(IllegalArgumentException.class,()->safety.consumeSource(token,reviewed->"request-revision-and-"+reviewed));
    }
    @Test void expiredOrChangedRequestsCannotAcquireReviewedSource()throws Exception {
        var clock=new AtomicLong(1_000);var safety=new Safety(new SqlAnalysis(),clock::get);
        String expired=safety.issueSource("request",SOURCE);clock.addAndGet(120_001);
        assertThrows(IllegalArgumentException.class,()->safety.consumeSource(expired,reviewed->fail("Expired permit must not evaluate a request")));
        String changed=safety.issueSource("request",SOURCE);
        assertThrows(IllegalArgumentException.class,()->safety.consumeSource(changed,reviewed->"changed mapping or revision"));
        assertThrows(IllegalArgumentException.class,()->safety.consumeSource(changed,reviewed->"request"));
    }
    @Test void ordinaryAndSourcePermitsCannotBeInterchangedAndShareCapacity()throws Exception {
        var safety=new Safety(new SqlAnalysis());
        assertThrows(IllegalArgumentException.class,()->safety.issueSource("request","invalid"));
        String source=safety.issueSource("request",SOURCE);
        assertThrows(IllegalArgumentException.class,()->safety.consume(source,"request"));
        String ordinary=safety.issue("request");
        assertThrows(IllegalArgumentException.class,()->safety.consumeSource(ordinary,reviewed->"request"));
        for(int index=0;index<256;index++)if(index%2==0)safety.issue("request");else safety.issueSource("request",SOURCE);
        assertThrows(IllegalStateException.class,()->safety.issueSource("request",SOURCE));
    }
}
