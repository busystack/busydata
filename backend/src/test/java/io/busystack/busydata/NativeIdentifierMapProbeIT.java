package io.busystack.busydata;

import com.google.gson.GsonBuilder;
import io.busystack.busydata.metadata.MetadataReadScope;
import io.busystack.busydata.protocol.Engine;
import io.busystack.busydata.sessions.SessionRegistry;
import java.io.ByteArrayOutputStream;
import java.io.DataOutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.security.MessageDigest;
import java.sql.*;
import java.util.*;
import java.util.concurrent.TimeUnit;
import java.util.stream.Stream;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;
import static org.junit.jupiter.api.Assertions.*;

/** Public-SQL acquisition experiment only; no production rule implementation. */
class NativeIdentifierMapProbeIT {
    @TempDir Path root;
    private static final int DOMAIN=63_487,MAX_ROWS=63_488,MAX_JSON=1024*1024;
    private static final long DEADLINE=TimeUnit.SECONDS.toNanos(5);
    // VARCHAR preserves the actual SPACE input. The whole partition is used;
    // ord is ordered only outside the window, with no running-frame semantics.
    static final String JSON_ROWS=
        "FROM JSON_TABLE(?, '$[*]' COLUMNS(ord FOR ORDINALITY,ch VARCHAR(1) CHARACTER SET utf8mb3 PATH '$' ERROR ON EMPTY ERROR ON ERROR)) AS j ORDER BY j.ord";
    private record Acquisition(char[] lower,char[] upper,char[] equivalence,long nanos,String serverVersion){}
    static Stream<Arguments> enginesAndCaseModes(){return NativeIdentifierCaseRulesIT.enginesAndCaseModes();}

    @ParameterizedTest(name="{0}, native map probe, lower_case_table_names={1}")
    @MethodSource("enginesAndCaseModes")
    void boundedFullBmpMapsUsePublicNativeOperators(String engine,int mode)throws Exception {
        var report=new LinkedHashMap<String,Object>();report.put("engine",engine);report.put("lowerCaseTableNames",mode);
        report.put("scope","Native public-SQL map experiment, not a production rule or performance acceptance claim");
        try(var fixture=new EngineFixture(root,engine,database->{
            if(!engine.equals("POSTGRESQL"))database.withCommand("--lower_case_table_names="+mode,
                "--character-set-server=utf8mb4","--collation-server=utf8mb4_unicode_ci");
        })){
            var session=fixture.open();
            assertFalse(session.identifierContext.lowerCaseFileSystem(),"Pinned native matrix requires a case-sensitive server filesystem");
            report.put("lowerCaseFileSystem",session.identifierContext.lowerCaseFileSystem());
            if(fixture.engine==Engine.POSTGRESQL){
                try(var statement=session.connection.createStatement();var rows=statement.executeQuery("SELECT 17 AS ΟΣAscii,19 AS \"ΟΣAscii\"")){
                    assertTrue(rows.next());assertEquals("ΟΣascii",rows.getMetaData().getColumnLabel(1));assertEquals("ΟΣAscii",rows.getMetaData().getColumnLabel(2));
                    assertEquals(17,rows.getInt(1));assertEquals(19,rows.getInt(2));assertFalse(rows.next());
                }
                report.put("nativeOperator","PostgreSQL UTF8 unquoted ASCII-only identifier fold; no MySQL/Maria map query");
                report.put("serverVersion",session.connection.getMetaData().getDatabaseProductVersion());report.put("status","passed");
                return;
            }
            StringBuilder values=new StringBuilder(DOMAIN);var array=new ArrayList<String>(DOMAIN);
            for(int scalar=1;scalar<=0xffff;scalar++)if(scalar<0xd800||scalar>0xdfff){values.append((char)scalar);array.add(String.valueOf((char)scalar));}
            String corpus=values.toString(),json=new GsonBuilder().disableHtmlEscaping().create().toJson(array);
            assertEquals(DOMAIN,corpus.length());assertEquals(188_287,corpus.getBytes(StandardCharsets.UTF_8).length);
            assertTrue(json.getBytes(StandardCharsets.UTF_8).length<=MAX_JSON);
            report.put("corpusScalars",corpus.length());report.put("corpusUtf8Bytes",corpus.getBytes(StandardCharsets.UTF_8).length);
            report.put("jsonUtf8Bytes",json.getBytes(StandardCharsets.UTF_8).length);report.put("corpusSha256",hash(corpus.getBytes(StandardCharsets.UTF_8)));
            String query="SELECT j.ord,j.ch,LOWER(j.ch COLLATE utf8mb3_general_ci),"+
                (fixture.engine==Engine.MARIADB?"UPPER(j.ch COLLATE utf8mb3_general1400_as_ci)":"LOWER(j.ch COLLATE utf8mb3_general_ci)")+
                ",MIN(j.ord) OVER (PARTITION BY j.ch COLLATE utf8mb3_general_ci) AS representative "+JSON_ROWS;
            report.put("deadlineMillis",5000);report.put("maxRows",MAX_ROWS);report.put("query",query);
            report.put("identifierCaseOperator",fixture.engine==Engine.MARIADB?"upper1400":"legacyLower");
            report.put("heapUsedBefore",Runtime.getRuntime().totalMemory()-Runtime.getRuntime().freeMemory());
            Acquisition acquired=session.metadata(view->{
                long started=System.nanoTime();String version=view.connection.getMetaData().getDatabaseProductVersion();
                try(var deadline=new MetadataReadScope(view.connection,started+DEADLINE)){
                    char[][] maps=partitions(view,query,json,corpus,deadline);deadline.check();
                    return new Acquisition(maps[0],maps[1],maps[2],System.nanoTime()-started,version);
                }
            });
            report.put("elapsedMillis",acquired.nanos()/1_000_000.0);report.put("serverVersion",acquired.serverVersion());
            report.put("heapUsedAfter",Runtime.getRuntime().totalMemory()-Runtime.getRuntime().freeMemory());
            report.put("mapPayloadBytes",3L*65536*Character.BYTES);report.put("lowerSha256",hash(acquired.lower()));
            report.put("upperSha256",hash(acquired.upper()));report.put("equivalenceSha256",hash(acquired.equivalence()));
            assertTrue(acquired.nanos()<DEADLINE,"Public native rule acquisition exceeded five seconds");
            assertEquals('σ',acquired.lower()['Σ']);assertEquals('i',acquired.lower()['İ']);
            assertEquals(acquired.equivalence()['N'],acquired.equivalence()['Ñ']);
            assertEquals(acquired.equivalence()['Σ'],acquired.equivalence()['ς']);
            // PAD SPACE is a string-level rule. Do not trim a whole class as
            // if it were literal SPACE unless this native map proves singleton.
            for(int index=0;index<corpus.length();index++)if(acquired.equivalence()[corpus.charAt(index)]==acquired.equivalence()[' '])
                assertEquals(' ',corpus.charAt(index),"Native SPACE equivalence class is not a singleton");
            if(fixture.engine==Engine.MARIADB){assertEquals('Σ',acquired.upper()['ς']);assertNotEquals(acquired.upper()['İ'],acquired.upper()['i']);}
            report.put("warningsRejected",true);report.put("spaceClassSingleton",true);report.put("status","passed");
        }catch(SQLException failure){
            report.put("status","failed");report.put("sqlState",Objects.toString(failure.getSQLState(),""));report.put("nativeCode",failure.getErrorCode());
            throw new AssertionError("Native map probe sqlState="+Objects.toString(failure.getSQLState(),"")+",nativeCode="+failure.getErrorCode());
        }finally{
            Path output=Path.of("target/p0-identifier-map-probe-"+engine+"-"+mode+".json");Files.createDirectories(output.getParent());
            if(!report.containsKey("status"))report.put("status","failed-before-completion");
            Files.writeString(output,new GsonBuilder().setPrettyPrinting().create().toJson(report));
        }
    }

    private static PreparedStatement statement(SessionRegistry.Session view,String sql)throws SQLException {
        var statement=view.adapter.catalogStatement(view.connection,sql);statement.setQueryTimeout(5);statement.setMaxRows(MAX_ROWS);
        // Both pinned drivers expose streaming without a server cursor or a
        // changed SQL mode. MySQL's documented MIN_VALUE sentinel is explicit.
        statement.setFetchSize(view.profile.getEngine()==Engine.MYSQL?Integer.MIN_VALUE:256);return statement;
    }
    private static char[][] partitions(SessionRegistry.Session view,String query,String json,String corpus,MetadataReadScope scope)throws SQLException {
        char[] lower=new char[65536],upper=new char[65536],mapping=new char[65536];int count=0;
        try(var statement=statement(view,query)){
            statement.setString(1,json);
            try(var rows=statement.executeQuery()){
                while(rows.next()){
                    if((count&255)==0)scope.check();assertTrue(count<DOMAIN,"Extra native partition row");
                    assertEquals(count+1,rows.getLong(1));char original=corpus.charAt(count);
                    assertEquals(original,scalar(rows.getString(2)),"JSON_TABLE changed an input scalar");
                    lower[original]=scalar(rows.getString(3));upper[original]=scalar(rows.getString(4));
                    long representative=rows.getLong(5);assertFalse(rows.wasNull());
                    assertTrue(representative>=1&&representative<=DOMAIN);mapping[corpus.charAt(count)]=corpus.charAt((int)representative-1);count++;
                }
                assertEquals(DOMAIN,count,"Missing native partition row");warnings(view,statement,rows);scope.check();
            }
        }
        for(int index=0;index<corpus.length();index++){
            char value=corpus.charAt(index);assertEquals(mapping[value],mapping[mapping[value]],"Native representative is not canonical");
        }
        return new char[][]{lower,upper,mapping};
    }
    private static char scalar(String value){
        assertNotNull(value);assertEquals(1,value.length(),"Native scalar cardinality changed");char result=value.charAt(0);
        assertTrue(result!=0&&(result<0xd800||result>0xdfff),"Invalid native scalar output");return result;
    }
    private static void warnings(SessionRegistry.Session view,Statement statement,ResultSet rows)throws SQLException {
        for(SQLWarning warning:new SQLWarning[]{rows.getWarnings(),statement.getWarnings(),view.connection.getWarnings()})
            if(warning!=null)throw new AssertionError("Native map warning sqlState="+Objects.toString(warning.getSQLState(),"")+",nativeCode="+warning.getErrorCode());
    }
    private static String hash(char[] values)throws Exception {
        var bytes=new ByteArrayOutputStream(values.length*Character.BYTES);
        try(var data=new DataOutputStream(bytes)){for(char value:values)data.writeChar(value);}
        return hash(bytes.toByteArray());
    }
    private static String hash(byte[] bytes)throws Exception {return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes));}
}
