package io.busystack.busydata.metadata;

import com.google.gson.JsonParser;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.HexFormat;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class NativeIdentifierCaseReaderTest {
    @Test void publicSqlCorpusContainsEveryLegalBmpScalarExactlyOnce()throws Exception {
        var values=JsonParser.parseString(NativeIdentifierCaseReader.corpus()).getAsJsonArray();
        assertEquals(63487,values.size());
        var raw=new StringBuilder(63487);int position=0;
        for(int codepoint=1;codepoint<=0xffff;codepoint++)if(codepoint<0xd800||codepoint>0xdfff){
            String value=values.get(position).getAsString();assertEquals(1,value.length());
            assertEquals((char)codepoint,value.charAt(0));assertEquals((char)codepoint,NativeIdentifierCaseReader.scalar(++position));raw.append(value);
        }
        // JSON escape choices may differ while every decoded scalar remains exact.
        assertTrue(NativeIdentifierCaseReader.corpus().getBytes(StandardCharsets.UTF_8).length<=400000);
        // Bound to the independently executed native public-SQL probe corpus.
        assertEquals("8b480d0689a1675fcb612c4a773797101ca09bf738bb092ebdce2d3178418f5d",HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(raw.toString().getBytes(StandardCharsets.UTF_8))));
        assertThrows(IllegalArgumentException.class,()->NativeIdentifierCaseReader.scalar(0));
        assertThrows(IllegalArgumentException.class,()->NativeIdentifierCaseReader.scalar(63488));
    }
    @Test void publicByteCorpusIsExactBoundedAndMatchesTheExecutedNativeProbe()throws Exception {
        String corpus=NativeIdentifierCaseReader.byteCorpus();var values=JsonParser.parseString(corpus).getAsJsonArray();
        assertEquals(256,values.size());assertEquals(1281,corpus.getBytes(StandardCharsets.UTF_8).length);
        for(int value=0;value<256;value++)assertEquals(String.format(java.util.Locale.ROOT,"%02X",value),values.get(value).getAsString());
        assertEquals("7c0908db8a8216ee0f533f2b2bd702f77c9127db798d75f0f3b199e0b6f0df51",HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(corpus.getBytes(StandardCharsets.UTF_8))));
        assertTrue(NativeIdentifierCaseReader.FOREIGN_BYTE_QUERY.contains("HEX(CONVERT(UNHEX(j.hexByte) USING latin1))"));
        assertTrue(NativeIdentifierCaseReader.FOREIGN_BYTE_QUERY.contains("COLLATE latin1_swedish_ci"));
        assertFalse(NativeIdentifierCaseReader.FOREIGN_BYTE_QUERY.contains("WEIGHT_STRING"));
    }
}
