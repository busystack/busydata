package io.busystack.busydata;

import com.google.gson.GsonBuilder;
import io.busystack.busydata.metadata.MetadataReadScope;
import io.busystack.busydata.sessions.SessionRegistry;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.security.MessageDigest;
import java.sql.*;
import java.util.*;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

/** Isolated public-SQL experiment for MariaDB's internal FK uniqueness domain.
 * This deliberately does not claim that DROP FK uses the same comparator. */
class NativeForeignKeyByteMapProbeIT {
    @TempDir Path root;
    private static final long DEADLINE=TimeUnit.SECONDS.toNanos(5);
    private static final String QUERY="SELECT j.ord,j.hexByte,HEX(CONVERT(UNHEX(j.hexByte) USING latin1)) AS roundtrip,"+
        "MIN(j.ord) OVER (PARTITION BY CONVERT(UNHEX(j.hexByte) USING latin1) COLLATE latin1_swedish_ci) AS representative "+
        "FROM JSON_TABLE(?, '$[*]' COLUMNS(ord FOR ORDINALITY,hexByte VARCHAR(2) CHARACTER SET ascii PATH '$' ERROR ON EMPTY ERROR ON ERROR)) AS j ORDER BY j.ord";
    private record Acquisition(int[] map,long nanos,String version){}
    private record Outcome(boolean accepted,String sqlState,int nativeCode){}
    private record Family(String tag,String original,List<String> variants){}
    private static final List<Family> FAMILIES=List.of(
        new Family("ascii","Aa",List.of("Aa","aa","AA")),
        new Family("sigma","ΟΣ",List.of("ΟΣ","οσ","ος")),
        new Family("dotted-i","İ",List.of("İ","i","I","i\u0307")),
        new Family("sharp-s","ẞ",List.of("ẞ","ß","SS")),
        new Family("accent","Ñ",List.of("Ñ","ñ","N")));

    @ParameterizedTest(name="MariaDB native FK byte partition, lower_case_table_names={0}")
    @ValueSource(ints={0,1})
    void publicBytePartitionsAgreeWithNativeForeignKeyUniqueness(int mode)throws Exception {
        var report=new LinkedHashMap<String,Object>();report.put("engine","MARIADB");report.put("lowerCaseTableNames",mode);
        report.put("scope","Experimental native FK uniqueness byte evidence; not production acceptance or a DROP-FK lookup claim");
        report.put("query",QUERY);report.put("deadlineMillis",5000);report.put("maxRows",257);
        try(var fixture=new EngineFixture(root,"MARIADB",database->database.withCommand("--lower_case_table_names="+mode,
            "--character-set-server=utf8mb4","--collation-server=utf8mb4_unicode_ci"))){
            var session=fixture.open();assertFalse(session.identifierContext.lowerCaseFileSystem());
            report.put("lowerCaseFileSystem",session.identifierContext.lowerCaseFileSystem());var hex=new ArrayList<String>(256);
            for(int value=0;value<256;value++)hex.add(String.format(Locale.ROOT,"%02X",value));
            String json=new GsonBuilder().disableHtmlEscaping().create().toJson(hex);
            report.put("jsonUtf8Bytes",json.getBytes(StandardCharsets.UTF_8).length);
            report.put("inputSha256",hash(json.getBytes(StandardCharsets.UTF_8)));
            Acquisition acquired=session.metadata(view->{
                long started=System.nanoTime();String version=view.connection.getMetaData().getDatabaseProductVersion();
                try(var scope=new MetadataReadScope(view.connection,started+DEADLINE);
                    var statement=view.adapter.catalogStatement(view.connection,QUERY)){
                    statement.setQueryTimeout(5);statement.setMaxRows(257);statement.setFetchSize(256);statement.setString(1,json);
                    int[] map=new int[256];int count=0;
                    try(var rows=statement.executeQuery()){
                        while(rows.next()){
                            scope.check();assertTrue(count<256,"Extra native byte partition row");assertEquals(count+1,rows.getLong(1));
                            assertEquals(hex.get(count),rows.getString(2));assertEquals(hex.get(count),rows.getString(3),"Native byte roundtrip changed");
                            long representative=rows.getLong(4);assertFalse(rows.wasNull());assertTrue(representative>=1&&representative<=256);
                            map[count++]=(int)representative-1;
                        }
                        assertEquals(256,count,"Missing native byte partition row");warnings(view,statement,rows);scope.check();
                    }
                    for(int value=0;value<map.length;value++)assertEquals(map[value],map[map[value]],"Byte representative is not canonical");
                    return new Acquisition(map,System.nanoTime()-started,version);
                }
            });
            assertTrue(acquired.nanos()<DEADLINE,"Native byte acquisition exceeded five seconds");
            report.put("serverVersion",acquired.version());report.put("elapsedMillis",acquired.nanos()/1_000_000.0);
            report.put("byteCount",acquired.map().length);report.put("representatives",acquired.map());
            byte[] encoded=new byte[256];for(int value=0;value<256;value++)encoded[value]=(byte)acquired.map()[value];
            report.put("mapSha256",hash(encoded));report.put("warningsRejected",true);

            execute(session,"CREATE TABLE fk_byte_parent(id INTEGER PRIMARY KEY)","parent");
            execute(session,"CREATE TABLE fk_byte_control(id INTEGER PRIMARY KEY,parent_id INTEGER)","control");
            String identical="ALTER TABLE fk_byte_control ADD CONSTRAINT "+quote(session,"fk_byte_control_name")+
                " FOREIGN KEY(parent_id) REFERENCES fk_byte_parent(id)";
            execute(session,identical,"control-original");Outcome control=duplicate(session,identical,"control-duplicate");
            assertFalse(control.accepted());report.put("duplicateControl",control);
            var comparisons=new ArrayList<Map<String,Object>>();int index=0;
            for(var family:FAMILIES)for(int variant=0;variant<family.variants().size();variant++){
                String table="fk_byte_child_"+index,prefix="fk_byte_"+index+"_";index++;
                execute(session,"CREATE TABLE "+quote(session,table)+"(id INTEGER PRIMARY KEY,parent_id INTEGER)","child");
                String exact=prefix+family.original(),candidate=prefix+family.variants().get(variant);
                String tail=" FOREIGN KEY(parent_id) REFERENCES fk_byte_parent(id)";
                execute(session,"ALTER TABLE "+quote(session,table)+" ADD CONSTRAINT "+quote(session,exact)+tail,"original");
                Outcome outcome=duplicate(session,"ALTER TABLE "+quote(session,table)+" ADD CONSTRAINT "+quote(session,candidate)+tail,"variant");
                if(!outcome.accepted())assertEquals(control,outcome,"Unrecognized duplicate outcome");
                boolean same=key(exact,acquired.map()).equals(key(candidate,acquired.map()));
                var evidence=new LinkedHashMap<String,Object>();evidence.put("family",family.tag());evidence.put("variant",variant);
                evidence.put("accepted",outcome.accepted());evidence.put("sqlState",outcome.sqlState());evidence.put("nativeCode",outcome.nativeCode());
                evidence.put("byteMapEquivalent",same);comparisons.add(evidence);
                report.put("comparisons",comparisons);
                assertEquals(!outcome.accepted(),same,"FK uniqueness disagrees with byte map: "+family.tag()+"/"+variant);
            }
            report.put("status","passed");
        }catch(SQLException error){
            report.put("status","sql-failure");report.put("sqlState",Objects.toString(error.getSQLState(),""));report.put("nativeCode",error.getErrorCode());
            throw new AssertionError("Native FK probe sqlState="+Objects.toString(error.getSQLState(),"")+",nativeCode="+error.getErrorCode());
        }finally{
            if(!report.containsKey("status"))report.put("status","failed-before-completion");
            Path output=Path.of("target/p0-native-fk-byte-map-probe-MARIADB-"+mode+".json");Files.createDirectories(output.getParent());
            Files.writeString(output,new GsonBuilder().setPrettyPrinting().create().toJson(report));
        }
    }
    private static String key(String value,int[] map){
        byte[] utf8=value.getBytes(StandardCharsets.UTF_8);int end=utf8.length;
        while(end>0&&map[Byte.toUnsignedInt(utf8[end-1])]==map[' '])end--;
        var out=new StringBuilder(2*end);for(int index=0;index<end;index++)out.append(String.format(Locale.ROOT,"%02X",map[Byte.toUnsignedInt(utf8[index])]));
        return out.toString();
    }
    private static String quote(SessionRegistry.Session session,String name){return session.adapter.quote(name);}
    private static void execute(SessionRegistry.Session session,String sql,String phase)throws SQLException {
        try(var statement=session.connection.createStatement()){statement.setQueryTimeout(5);statement.execute(sql);}
        catch(SQLException error){throw new AssertionError(phase+" sqlState="+Objects.toString(error.getSQLState(),"")+",nativeCode="+error.getErrorCode());}
    }
    private static Outcome duplicate(SessionRegistry.Session session,String sql,String phase)throws SQLException {
        try(var statement=session.connection.createStatement()){statement.setQueryTimeout(5);statement.execute(sql);return new Outcome(true,"",0);}
        catch(SQLException error){String state=Objects.toString(error.getSQLState(),"");int code=error.getErrorCode();
            if(!state.equals("HY000")||code!=1005)throw new AssertionError(phase+" unexpected sqlState="+state+",nativeCode="+code);
            return new Outcome(false,state,code);}
    }
    private static void warnings(SessionRegistry.Session view,Statement statement,ResultSet rows)throws SQLException {
        for(SQLWarning warning:new SQLWarning[]{rows.getWarnings(),statement.getWarnings(),view.connection.getWarnings()})
            if(warning!=null)throw new AssertionError("Native byte map warning sqlState="+Objects.toString(warning.getSQLState(),"")+",nativeCode="+warning.getErrorCode());
    }
    private static String hash(byte[] bytes)throws Exception{return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes));}
}
