package io.busystack.busydata;

import io.busystack.busydata.metadata.CompactProperties;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class CompactPropertiesTest {
    @Test void unicodeEmptyPresenceAndMalformedUtf16RemainExact(){
        var source=new LinkedHashMap<String,String>();source.put("type","numeric(40,12)");source.put("enumLabel.0","");source.put("remarks","漢字 İ Ä 😀\r\n");source.put("synthetic","before\ud800after");
        var compact=CompactProperties.copyOf(source);assertEquals(source,compact);assertEquals(source.hashCode(),compact.hashCode());assertTrue(compact.containsKey("enumLabel.0"));assertEquals("",compact.get("enumLabel.0"));assertNull(compact.get("unknown"));assertEquals(source.get("synthetic"),compact.get("synthetic"));
        source.clear();assertEquals(4,compact.size());assertEquals("漢字 İ Ä 😀\r\n",compact.get("remarks"));assertEquals(compact,CompactProperties.copyOf(new TreeMap<>(compact)));assertSame(compact,CompactProperties.copyOf(compact));
    }
    @Test void noMutationCanChangePublishedAttributes(){var compact=CompactProperties.copyOf(Map.of("type","integer"));assertThrows(UnsupportedOperationException.class,()->compact.put("type","text"));assertThrows(UnsupportedOperationException.class,()->compact.remove("type"));assertThrows(UnsupportedOperationException.class,compact::clear);assertThrows(UnsupportedOperationException.class,()->compact.entrySet().iterator().next().setValue("text"));assertThrows(UnsupportedOperationException.class,()->{var iterator=compact.entrySet().iterator();iterator.next();iterator.remove();});}
    @Test void emptyLayoutAndByteAdmissionAreBounded(){assertEquals(Map.of(),CompactProperties.copyOf(Map.of()));var oversized=new HashMap<String,String>();for(int index=0;index<20;index++)oversized.put("field"+index,"漢".repeat(20000));assertThrows(IllegalArgumentException.class,()->CompactProperties.copyOf(oversized));}
}
