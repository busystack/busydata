package io.busystack.busydata.transfers;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

class PostgresRestoreInputTest {
    @TempDir Path root;
    @Test void replacesOnlyCanonicalDumpGuardsAndPreservesLargeCopyBytes()throws Exception {
        String sql="--\n-- PostgreSQL database dump\n--\n\n\\restrict OldKnownKey\n\nCOPY public.t (text) FROM stdin;\n"+"漢😀\\\\unrestrict OldKnownKey".repeat(10000)+"\n\\.\n-- PostgreSQL database dump complete\n\n\\unrestrict OldKnownKey\n\n";
        Path input=root.resolve("dump.sql");Files.writeString(input,sql);
        var bytes=new ByteArrayOutputStream();PostgresRestoreInput.write(input,bytes,()->{});
        String actual=bytes.toString(StandardCharsets.UTF_8);
        int end=actual.indexOf('\n');assertTrue(actual.substring(0,end).matches("\\\\restrict [a-f0-9]{64}"));
        int footer=sql.lastIndexOf("\\unrestrict OldKnownKey\n");
        String expected=(sql.substring(0,footer)+sql.substring(footer+"\\unrestrict OldKnownKey\n".length())).replace("\n\\restrict OldKnownKey\n","\n");
        var digest=java.security.MessageDigest.getInstance("SHA-256");
        assertArrayEquals(digest.digest(expected.getBytes(StandardCharsets.UTF_8)),digest.digest(actual.substring(end+1).getBytes(StandardCharsets.UTF_8)),"Every COPY byte and SQL line must be preserved");
        var another=new ByteArrayOutputStream();PostgresRestoreInput.write(input,another,()->{});assertNotEquals(actual.substring(0,end),another.toString(StandardCharsets.UTF_8).substring(0,end));
    }
    @Test void ordinarySqlAndEmbeddedClientCommandsStayAuthoritativeButRestricted()throws Exception {
        String sql="SELECT E'quoted\\\\! text'; -- comment\r\nSELECT 1; \\! unreviewed\r\n\\unrestrict KnownToFile\r\n";
        Path input=root.resolve("source.sql");Files.writeString(input,sql);
        var bytes=new ByteArrayOutputStream();PostgresRestoreInput.write(input,bytes,()->{});
        String actual=bytes.toString(StandardCharsets.UTF_8);assertEquals(sql,actual.substring(actual.indexOf('\n')+1));
    }
    @Test void boundedDiagnosticsNeverReturnSecretOrSqlText()throws Exception {
        var diagnostics=new NativeDiagnostics();diagnostics.drain(new ByteArrayInputStream(("ERROR 1045 access denied password=private-secret SELECT private_row FROM private_table"+"x".repeat(200000)).getBytes(StandardCharsets.UTF_8)));
        assertEquals("Native tool exited 2: database authentication denied (database code 1045). Source values and server messages omitted.",diagnostics.summary(2));
    }
}
