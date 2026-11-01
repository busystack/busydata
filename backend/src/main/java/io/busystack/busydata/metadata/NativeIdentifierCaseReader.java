package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.Engine;
import io.busystack.busydata.adapters.JdbcAdapter;
import io.busystack.busydata.sessions.SessionRegistry;
import java.sql.*;
import java.util.concurrent.TimeUnit;

/** Fixed-domain public SQL acquisition, exclusively on an independent metadata view.
 * Published readers never perform case conversion through JDBC. */
public final class NativeIdentifierCaseReader {
    public static final int SCALARS=63487;
    static final String FOREIGN_BYTE_QUERY="SELECT j.ord,j.hexByte,HEX(CONVERT(UNHEX(j.hexByte) USING latin1)) AS roundtrip,"+
        "MIN(j.ord) OVER (PARTITION BY CONVERT(UNHEX(j.hexByte) USING latin1) COLLATE latin1_swedish_ci) AS representative "+
        "FROM JSON_TABLE(?, '$[*]' COLUMNS(ord FOR ORDINALITY,hexByte VARCHAR(2) CHARACTER SET ascii PATH '$' ERROR ON EMPTY ERROR ON ERROR)) AS j ORDER BY j.ord";
    private NativeIdentifierCaseReader(){}
    public static IdentifierRules read(SessionRegistry.Session view,IdentifierRules previous,long deadline)throws SQLException {
        if(view.profile.getEngine()==Engine.POSTGRESQL)return previous!=null&&previous.engine()==Engine.POSTGRESQL?previous:new IdentifierRules(Engine.POSTGRESQL,0);
        if(!view.isIndependentMetadataView())throw new IllegalStateException("Native identifier evidence requires an independent metadata connection");
        deadline=Math.min(deadline,System.nanoTime()+TimeUnit.SECONDS.toNanos(5));
        try(var scope=new MetadataReadScope(view.connection,deadline)){try{
            scope.check();view.connection.clearWarnings();var identity=view.identifierContext;
            int mode=identity.lowerCaseTableNames();String version=identity.version();
            if(previous!=null&&previous.matchesServer(identity))return previous;
            String compare=view.profile.getEngine()==Engine.MARIADB?"UPPER(j.ch COLLATE utf8mb3_general1400_as_ci)":"LOWER(j.ch COLLATE utf8mb3_general_ci)";
            String sql="SELECT j.ord,j.ch,LOWER(j.ch COLLATE utf8mb3_general_ci),"+compare+",MIN(j.ord) OVER(PARTITION BY j.ch COLLATE utf8mb3_general_ci) FROM JSON_TABLE(?, '$[*]' COLUMNS(ord FOR ORDINALITY,ch VARCHAR(1) CHARACTER SET utf8mb3 PATH '$' ERROR ON EMPTY ERROR ON ERROR)) AS j ORDER BY j.ord";
            var lower=new char[65536];var comparison=view.profile.getEngine()==Engine.MARIADB?new char[65536]:lower;var dictionary=new char[65536];
            try(var query=view.adapter.catalogStatement(view.connection,sql)){
                query.setQueryTimeout(5);query.setMaxRows(SCALARS+1);
                // The pinned MySQL driver documents this forward-only/read-only
                // streaming sentinel. MariaDB 3.x uses a bounded positive row buffer.
                query.setFetchSize(view.profile.getEngine()==Engine.MYSQL?Integer.MIN_VALUE:256);
                query.setString(1,corpus());
                try(var rows=query.executeQuery()){
                    int count=0;
                    while(rows.next()){
                        if(++count>SCALARS||rows.getInt(1)!=count||rows.wasNull())throw unavailable();
                        char original=scalar(count);String exact=rows.getString(2);
                        if(exact==null||exact.length()!=1||exact.charAt(0)!=original)throw unavailable();
                        lower[original]=one(rows.getString(3));char folded=one(rows.getString(4));
                        if(comparison==lower){if(folded!=lower[original])throw unavailable();}else comparison[original]=folded;
                        int representative=rows.getInt(5);if(rows.wasNull()||representative<1||representative>count)throw unavailable();dictionary[original]=scalar(representative);
                        if((count&255)==0)scope.check();
                    }
                    if(count!=SCALARS)throw unavailable();
                    warnings(query,view.connection,rows);
                }
                warnings(query,view.connection);
            }
            scope.check();
            String foreignBytes=view.profile.getEngine()==Engine.MARIADB?foreignBytes(view,scope):null;
            String lowerMap=new String(lower);
            try{var rules=IdentifierRules.nativeRules(view.profile.getEngine(),mode,version,lowerMap,comparison==lower?lowerMap:new String(comparison),new String(dictionary),foreignBytes,identity.lowerCaseFileSystem());scope.check();return rules;}
            catch(IllegalArgumentException inconsistent){throw new SQLException("Native identifier equivalence evidence is inconsistent","HY000",inconsistent);}
        }catch(SQLException failure){scope.check();throw failure;}}
    }
    /** One bounded header read during physical connection construction, never on
     * an adopted command session or from completion. Full maps remain metadata-only. */
    public static IdentifierRules.ServerIdentity identity(JdbcAdapter adapter,Connection connection)throws SQLException{
        if(adapter.engine()==Engine.POSTGRESQL)return new IdentifierRules.ServerIdentity(Engine.POSTGRESQL,0,"",false);
        if(io.grpc.Context.current().isCancelled()||Thread.currentThread().isInterrupted())throw new java.util.concurrent.CancellationException("Physical identifier context acquisition cancelled");
        connection.clearWarnings();int mode,filesystem;String version;
        try(var query=adapter.catalogStatement(connection,"SELECT @@lower_case_table_names,VERSION(),@@lower_case_file_system")){
            query.setQueryTimeout(5);query.setMaxRows(2);
            try(var rows=query.executeQuery()){
                if(!rows.next())throw unavailable();mode=rows.getInt(1);if(rows.wasNull())throw unavailable();version=rows.getString(2);
                filesystem=rows.getInt(3);if(rows.wasNull()||filesystem<0||filesystem>1)throw unavailable();
                if(mode<0||mode>2||version==null||version.isEmpty()||version.length()>256||version.indexOf(0)>=0||rows.next())throw unavailable();
                warnings(query,connection,rows);
            }
            warnings(query,connection);
        }
        if(io.grpc.Context.current().isCancelled()||Thread.currentThread().isInterrupted())throw new java.util.concurrent.CancellationException("Physical identifier context acquisition cancelled");
        return new IdentifierRules.ServerIdentity(adapter.engine(),mode,version,filesystem==1);
    }
    private static void warnings(Statement query,Connection connection)throws SQLException{if(query.getWarnings()!=null||connection.getWarnings()!=null)throw new SQLException("Native identifier evidence returned a conversion warning","01000");}
    private static void warnings(Statement query,Connection connection,ResultSet rows)throws SQLException{if(rows.getWarnings()!=null)throw new SQLException("Native identifier evidence returned a conversion warning","01000");warnings(query,connection);}
    private static SQLException unavailable(){return new SQLException("Native identifier equivalence evidence is unavailable or incomplete","HY000");}
    private static char one(String value)throws SQLException{if(value==null||value.length()!=1||value.charAt(0)==0||Character.isSurrogate(value.charAt(0)))throw unavailable();return value.charAt(0);}
    static char scalar(int ordinal){if(ordinal<1||ordinal>SCALARS)throw new IllegalArgumentException("Invalid native identifier scalar ordinal");return (char)(ordinal<0xd800?ordinal:ordinal+0x800);}
    static String corpus(){
        var json=new StringBuilder(260000);json.append('[');
        for(int n=1;n<=SCALARS;n++){
            if(n>1)json.append(',');json.append('"');char c=scalar(n);
            if(c=='"'||c=='\\')json.append('\\').append(c);
            else if(c<0x20){json.append("\\u00");json.append(Character.forDigit(c>>>4,16)).append(Character.forDigit(c&15,16));}
            else json.append(c);
            json.append('"');
        }
        return json.append(']').toString();
    }
    /** MariaDB SYS_FOREIGN compares raw UTF-8 bytes with latin1_swedish_ci.
     * UNHEX supplies each exact byte; no Unicode-to-latin1 conversion is used. */
    private static String foreignBytes(SessionRegistry.Session view,MetadataReadScope scope)throws SQLException {
        var representatives=new char[256];int count=0;
        try(var query=view.adapter.catalogStatement(view.connection,FOREIGN_BYTE_QUERY)){
            query.setQueryTimeout(5);query.setMaxRows(257);query.setFetchSize(256);query.setString(1,byteCorpus());
            try(var rows=query.executeQuery()){
                while(rows.next()){
                    scope.check();if(count>=256||rows.getInt(1)!=count+1||rows.wasNull())throw unavailable();
                    String expected=byteHex(count);
                    if(!expected.equals(rows.getString(2))||!expected.equals(rows.getString(3)))throw unavailable();
                    int representative=rows.getInt(4);if(rows.wasNull()||representative<1||representative>count+1)throw unavailable();
                    representatives[count++]=(char)representative;
                }
                if(count!=256)throw unavailable();warnings(query,view.connection,rows);
            }
            warnings(query,view.connection);
        }
        for(int value=0;value<256;value++)if(representatives[representatives[value]-1]!=representatives[value])throw unavailable();
        scope.check();return new String(representatives);
    }
    private static String byteHex(int value){String hex="0123456789ABCDEF";return ""+hex.charAt(value>>>4)+hex.charAt(value&15);}
    static String byteCorpus(){var json=new StringBuilder(1281);json.append('[');for(int value=0;value<256;value++){if(value>0)json.append(',');json.append('"').append(byteHex(value)).append('"');}return json.append(']').toString();}
}
