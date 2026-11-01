package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.sessions.SessionRegistry;
import java.io.*;
import java.nio.ByteBuffer;
import java.nio.charset.*;
import java.security.*;
import java.sql.*;
import java.util.*;
import java.util.concurrent.*;

/** One transient native source value. Pinned drivers admit at most an 8MiB
 * packet; this reader separately caps raw reads and retained UTF-8 DDL at 64KiB.
 * JDBC still buffers the received row. Nothing here is a wire-streaming claim. */
public record NativeRoutineSource(String definition,String sqlMode,MetadataState state,int bytesRead) {
    public static final int MAX_BYTES=65_536,MAX_MODE_BYTES=8_192,MAX_ARTIFACT_BYTES=6_291_456;
    public NativeRoutineSource {
        Objects.requireNonNull(definition);Objects.requireNonNull(sqlMode);Objects.requireNonNull(state);
        if(bytesRead<0||bytesRead>MAX_BYTES+1||definition.getBytes(StandardCharsets.UTF_8).length>MAX_BYTES||sqlMode.getBytes(StandardCharsets.UTF_8).length>MAX_MODE_BYTES||state!=MetadataState.AVAILABLE&&!definition.isEmpty())throw new IllegalArgumentException("Invalid bounded routine source evidence");
    }
    public NativeRoutineSource(String definition,String sqlMode,MetadataState state){this(definition,sqlMode,state,definition.getBytes(StandardCharsets.UTF_8).length);}
    public boolean available(){return state==MetadataState.AVAILABLE&&!definition.isEmpty();}
    /** SQL NULL remains distinct from an empty or over-budget field. */
    public record SourceField(String text,MetadataState state,int bytesRead){
        public SourceField{Objects.requireNonNull(state);if(bytesRead<0||bytesRead>MAX_ARTIFACT_BYTES+1||text!=null&&(text.getBytes(StandardCharsets.UTF_8).length>MAX_ARTIFACT_BYTES||state!=MetadataState.AVAILABLE&&!text.isEmpty()))throw new IllegalArgumentException("Invalid bounded routine source field");}
        public boolean available(){return state==MetadataState.AVAILABLE&&text!=null&&!text.isEmpty();}
    }
    /** Length-tagged state and source; no raw source appears in diagnostics. */
    public String fingerprint(){
        try{var hash=MessageDigest.getInstance("SHA-256");for(String value:List.of(state.name(),sqlMode,definition)){byte[] bytes=value.getBytes(StandardCharsets.UTF_8);hash.update(ByteBuffer.allocate(4).putInt(bytes.length).array());hash.update(bytes);}return HexFormat.of().formatHex(hash.digest());}
        catch(NoSuchAlgorithmException impossible){throw new AssertionError(impossible);}
    }
    private static NativeRoutineSource unavailable(MetadataState state,String mode,int bytes){return new NativeRoutineSource("",mode,state,bytes);}
    public static NativeRoutineSource read(SessionRegistry.Session view,SchemaObject routine,long deadline)throws SQLException {
        if(!view.isIndependentMetadataView()&&!view.lock.isHeldByCurrentThread())throw new IllegalStateException("Owned routine source acquisition requires the physical-session lock");
        if(view.profile.getEngine()!=Engine.MYSQL&&view.profile.getEngine()!=Engine.MARIADB)throw new SQLFeatureNotSupportedException("This native routine source reader supports MySQL/MariaDB","0A000");
        String kind=switch(routine.getSubtype()){case FUNCTION->"FUNCTION";case PROCEDURE->"PROCEDURE";default->throw new SQLFeatureNotSupportedException("Exact routine kind is unavailable","0A000");};
        String schema=routine.getSchema(),name=routine.getName();
        if(routine.getKind()!=ObjectKind.ROUTINE||schema.isEmpty()||schema.length()>256||name.isEmpty()||name.length()>256||schema.indexOf(0)>=0||name.indexOf(0)>=0||!schema.equals(view.context.catalog())||!routine.getIdentifier().equals(kind+":"+name))throw new SQLException("Exact routine source identity is unavailable","55000");
        deadline=Math.min(deadline,System.nanoTime()+TimeUnit.SECONDS.toNanos(10));
        String mode="";int consumed=0;
        try(var scope=new ReadPolicy(view,deadline)){
            scope.check();view.connection.clearWarnings();
            String sql="SELECT ROUTINE_TYPE,CASE WHEN OCTET_LENGTH(SQL_MODE)<=8192 THEN SQL_MODE ELSE NULL END,OCTET_LENGTH(SQL_MODE),OCTET_LENGTH(ROUTINE_DEFINITION) FROM information_schema.ROUTINES WHERE BINARY ROUTINE_SCHEMA=BINARY ? AND BINARY ROUTINE_NAME=BINARY ? AND BINARY ROUTINE_TYPE=BINARY ?";
            try(var query=view.adapter.catalogStatement(view.connection,sql);var watched=scope.watch(query)){
                query.setQueryTimeout(10);query.setMaxRows(2);query.setString(1,schema);query.setString(2,name);query.setString(3,kind);
                try(var rows=query.executeQuery()){
                    if(!rows.next())return unavailable(MetadataState.UNAVAILABLE,"",0);
                    if(!kind.equals(rows.getString(1)))throw new SQLException("Routine source kind changed","55000");
                    long modeBytes=rows.getLong(3);if(rows.wasNull()||modeBytes<0)return unavailable(MetadataState.UNAVAILABLE,"",0);
                    if(modeBytes>MAX_MODE_BYTES)return unavailable(MetadataState.LIMITED,"",0);
                    mode=rows.getString(2);if(mode==null)return unavailable(MetadataState.UNAVAILABLE,"",0);
                    long body=rows.getLong(4);boolean bodyUnknown=rows.wasNull();
                    if(!bodyUnknown&&(body<0||body>MAX_BYTES))return unavailable(MetadataState.LIMITED,mode,0);
                    if(rows.next())throw new SQLException("Routine source identity is ambiguous","55000");checkWarnings(view.profile.getEngine(),query,view.connection,rows,false);
                }
            }
            scope.check();
            try(var query=view.adapter.catalogStatement(view.connection,"SHOW CREATE "+kind+" "+view.adapter.table("",schema,name));var watched=scope.watch(query)){
                query.setQueryTimeout(10);query.setMaxRows(2);
                try(var rows=query.executeQuery()){
                    if(!rows.next())return unavailable(MetadataState.UNAVAILABLE,mode,0);
                    if(!name.equals(rows.getString(1)))throw new SQLException("Native routine source identity changed","55000");
                    byte[] modeBytes=bytes(rows.getBinaryStream(2),MAX_MODE_BYTES,scope::check);
                    if(modeBytes==null)return unavailable(MetadataState.UNAVAILABLE,"",0);
                    if(modeBytes.length>MAX_MODE_BYTES)return unavailable(MetadataState.LIMITED,"",0);
                    String storedMode=decode(modeBytes,rows,2,view.profile.getEngine());
                    if(!mode.equals(storedMode))throw new SQLException("Native routine SQL mode changed","55000");
                    var source=readDefinitionField(view,query,rows,3,deadline);
                    // Pinned native SHOW CREATE emits NULL only when the
                    // successful exact row lacks full source-access privilege.
                    if(source.text()==null)return unavailable(MetadataState.DENIED,mode,0);
                    consumed=source.bytesRead();
                    if(!source.available())return unavailable(source.state(),mode,consumed);
                    if(rows.next())throw new SQLException("Native routine source identity is ambiguous","55000");checkWarnings(view.profile.getEngine(),query,view.connection,rows,kind.equals("FUNCTION"));scope.check();
                    return new NativeRoutineSource(source.text(),mode,MetadataState.AVAILABLE,consumed);
                }
            }
        }catch(SQLException failure){
            if(Set.of(1044,1045,1142,1143,1227,1370).contains(failure.getErrorCode())&&Set.of("42000","28000").contains(Objects.toString(failure.getSQLState(),"")))return unavailable(MetadataState.DENIED,mode,consumed);
            throw failure;
        }
    }
    /** The SQL acquisition is shared. Only an independent view may abort its
     * connection; an owned view retains its lock and cancels this statement. */
    private static final class ReadPolicy implements AutoCloseable {
        private final SessionRegistry.Session view;private final long deadline;private final MetadataReadScope independent;
        ReadPolicy(SessionRegistry.Session view,long deadline){this.view=view;this.deadline=deadline;independent=view.isIndependentMetadataView()?new MetadataReadScope(view.connection,deadline):null;}
        void check()throws SQLException {if(independent!=null)independent.check();else{if(!view.lock.isHeldByCurrentThread())throw new IllegalStateException("Routine source physical ownership changed");if(io.grpc.Context.current().isCancelled()||Thread.currentThread().isInterrupted())throw new CancellationException("Routine source cancelled");if(System.nanoTime()>deadline)throw new SQLTimeoutException("Routine source deadline exceeded");}}
        OwnedStatement watch(Statement query){return new OwnedStatement(query,deadline,independent==null);}
        @Override public void close(){if(independent!=null)independent.close();}
    }
    private static final class OwnedStatement implements AutoCloseable {
        private static final ScheduledExecutorService deadlines=Executors.newSingleThreadScheduledExecutor(Thread.ofPlatform().daemon(true).name("routine-source-deadline").factory());
        private static final ExecutorService cancellation=Executors.newVirtualThreadPerTaskExecutor();
        private final Statement query;private final io.grpc.Context context=io.grpc.Context.current();private final io.grpc.Context.CancellationListener listener;
        private final ScheduledFuture<?> timer;private boolean closed;
        OwnedStatement(Statement query,long deadline,boolean owned){this.query=query;listener=ignored->cancel();if(owned){context.addListener(listener,cancellation);timer=deadlines.schedule(this::cancel,Math.max(0,deadline-System.nanoTime()),TimeUnit.NANOSECONDS);}else timer=null;}
        private void cancel(){cancellation.execute(()->{synchronized(this){if(!closed)try{query.cancel();}catch(SQLException ignored){}}});}
        @Override public synchronized void close(){closed=true;if(timer!=null){timer.cancel(false);context.removeListener(listener);}}
    }
    /** Reusable for an explicitly owned schema export. This cancels only its
     * statement; callers own query-execution timeouts and physical connection. */
    public static SourceField readDefinitionField(SessionRegistry.Session view,Statement query,ResultSet rows,int column,long deadline)throws SQLException {
        return readDefinitionField(view,query,rows,column,MAX_BYTES,deadline);
    }
    public static SourceField readDefinitionField(SessionRegistry.Session view,Statement query,ResultSet rows,int column,int maxBytes,long deadline)throws SQLException {
        return readDefinitionField(view.profile.getEngine(),query,rows,column,maxBytes,deadline);
    }
    static SourceField readDefinitionField(Engine engine,Statement query,ResultSet rows,int column,int maxBytes,long deadline)throws SQLException {
        if(maxBytes<1||maxBytes>MAX_ARTIFACT_BYTES)throw new IllegalArgumentException("Routine source field budget is invalid");
        check(query,deadline);byte[] bytes=bytes(rows.getBinaryStream(column),maxBytes,()->check(query,deadline));
        if(bytes==null)return new SourceField(null,MetadataState.UNAVAILABLE,0);
        if(bytes.length>maxBytes)return new SourceField("",MetadataState.LIMITED,bytes.length);
        if(bytes.length==0)return new SourceField("",MetadataState.UNAVAILABLE,0);
        String text=decode(bytes,rows,column,engine);check(query,deadline);
        if(text.getBytes(StandardCharsets.UTF_8).length>maxBytes)return new SourceField("",MetadataState.LIMITED,bytes.length);
        return new SourceField(text,MetadataState.AVAILABLE,bytes.length);
    }
    @FunctionalInterface private interface Check{void check()throws SQLException;}
    private static byte[] bytes(InputStream source,int maximum,Check scope)throws SQLException {
        if(source==null)return null;
        try(source;var out=new ByteArrayOutputStream(Math.min(maximum+1,4096))){
            var buffer=new byte[4096];int remaining=maximum+1;
            while(remaining>0){scope.check();int count=source.read(buffer,0,Math.min(remaining,buffer.length));if(count<0)break;if(count==0)throw new SQLException("Native routine source stream made no progress","HY000");out.write(buffer,0,count);remaining-=count;}
            scope.check();return out.toByteArray();
        }catch(IOException failure){throw new SQLException("Native routine source stream is unavailable","HY000",failure);}
    }
    private static void check(Statement query,long deadline)throws SQLException {
        if(io.grpc.Context.current().isCancelled()||Thread.currentThread().isInterrupted()){try{query.cancel();}catch(SQLException ignored){}throw new java.util.concurrent.CancellationException("Routine source cancelled");}
        if(System.nanoTime()>deadline){try{query.cancel();}catch(SQLException ignored){}throw new SQLTimeoutException("Routine source deadline exceeded");}
    }
    private static String decode(byte[] bytes,ResultSet rows,int column,Engine engine)throws SQLException {
        Charset charset=StandardCharsets.UTF_8;
        if(engine==Engine.MYSQL){
            // Connector/J deliberately leaves character_set_results NULL and
            // reports each field's Java charset through this public extension.
            String encoding=rows.getMetaData().unwrap(com.mysql.cj.jdbc.result.ResultSetMetaData.class).getColumnCharacterEncoding(column);
            if(encoding==null||encoding.isEmpty()||encoding.length()>128)throw new SQLFeatureNotSupportedException("Native routine source character set is unavailable","0A000");
            try{charset=Charset.forName(encoding);}catch(IllegalArgumentException unknown){throw new SQLFeatureNotSupportedException("Native routine source character set is unsupported","0A000");}
        }
        try{return charset.newDecoder().onMalformedInput(CodingErrorAction.REPORT).onUnmappableCharacter(CodingErrorAction.REPORT).decode(ByteBuffer.wrap(bytes)).toString();}
        catch(CharacterCodingException failure){throw new SQLException("Native routine source encoding is unavailable","HY000",failure);}
    }
    /** Call only after verifying the exact SHOW identity and decoding its source.
     * MariaDB 11.8 emits note1585 when loading a stored function whose name also
     * names a native function. It does not transform the SHOW value. All other
     * phases, engines, warnings and malformed chains remain unavailable. */
    public static void checkWarnings(Engine engine,Statement statement,Connection connection,ResultSet rows,boolean nativeFunctionShow)throws SQLException {
        for(var first:new SQLWarning[]{rows.getWarnings(),statement.getWarnings(),connection.getWarnings()}){
            var seen=Collections.newSetFromMap(new IdentityHashMap<SQLException,Boolean>());int count=0;
            for(SQLException warning=first;warning!=null;warning=warning.getNextException()){
                if(++count>32||!seen.add(warning)||!(warning instanceof SQLWarning)||engine!=Engine.MARIADB||!nativeFunctionShow||warning.getErrorCode()!=1585||!Objects.toString(warning.getSQLState(),"").isEmpty())throw new SQLException("Native routine source returned an unexpected warning","01000");
            }
        }
    }
}
