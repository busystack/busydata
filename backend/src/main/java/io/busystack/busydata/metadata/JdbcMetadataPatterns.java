package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.sessions.SessionRegistry;
import java.sql.*;
import java.util.*;

/** One exact JDBC transport descriptor path; native structure is enriched separately. */
public final class JdbcMetadataPatterns {
    private static final java.util.concurrent.ExecutorService CANCELLATION=java.util.concurrent.Executors.newVirtualThreadPerTaskExecutor();
    private JdbcMetadataPatterns(){}
    private static String text(String value){return Objects.toString(value,"");}
    public static String exactPattern(String value,String escape){if(escape==null||escape.isEmpty())throw new IllegalArgumentException("JDBC metadata escape unavailable");return value.replace(escape,escape+escape).replace("%",escape+"%").replace("_",escape+"_");}
    private static void check(){if(io.grpc.Context.current().isCancelled()||Thread.currentThread().isInterrupted())throw new java.util.concurrent.CancellationException("Metadata refresh cancelled");}
    public static List<SchemaObject> columns(SessionRegistry.Session session,String catalog,String schema,String table)throws Exception {
        return columns(session,catalog,schema,table,ignored->{});
    }
    /** Optional peak driver accounting; exact transport facts still use one JDBC reader. */
    public static List<SchemaObject> columns(SessionRegistry.Session session,String catalog,String schema,String table,java.util.function.LongConsumer driverScratch)throws Exception {
        for(String identifier:List.of(catalog,schema,table))if(identifier.isEmpty()||identifier.length()>256||identifier.indexOf('\0')>=0)throw new IllegalArgumentException("Exact column metadata identity required");
        if(session.profile.getEngine()==Engine.POSTGRESQL){if(!catalog.equals(session.context.catalog()))throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.INVALID_OWNER);return driverColumns(session,catalog,schema,table,driverScratch);}
        if(session.profile.getEngine()!=Engine.MYSQL&&session.profile.getEngine()!=Engine.MARIADB)throw new SQLFeatureNotSupportedException("Native JDBC metadata unavailable");
        // Never alter a console SQL mode or ask another physical session about
        // its temporary tables. Native temporary overlays have their own owner.
        if(!session.isIndependentMetadataView())return session.metadata(catalog,view->privateColumns(view,catalog,schema,table));
        return privateColumns(session,catalog,schema,table);
    }
    private static List<SchemaObject> privateColumns(SessionRegistry.Session view,String catalog,String schema,String table)throws Exception {
        if(!view.isIndependentMetadataView())throw new IllegalStateException("Independent metadata ownership required");
        ColumnMetadataReader.preflight(view,schema,table);
        try(var mode=new MetadataMode(view)) {return driverColumns(view,catalog,schema,table,ignored->{});}
        catch(SQLException failure){check();throw failure;}
    }
    private static List<SchemaObject> driverColumns(SessionRegistry.Session session,String catalog,String schema,String table,java.util.function.LongConsumer driverScratch)throws SQLException {
        if(session.profile.getEngine()==Engine.POSTGRESQL)driverScratch.accept(postgresDriverBytes(session,schema,table));
        var metadata=session.connection.getMetaData();String escape=metadata.getSearchStringEscape();var result=new ArrayList<SchemaObject>();boolean pg=session.profile.getEngine()==Engine.POSTGRESQL;
        try(var rows=metadata.getColumns(catalog,pg?exactPattern(schema,escape):null,exactPattern(table,escape),null)){
            while(rows.next()){check();if(!catalog.equals(rows.getString("TABLE_CAT"))||pg&&!schema.equals(rows.getString("TABLE_SCHEM"))||!table.equals(rows.getString("TABLE_NAME")))continue;if(result.size()>=2048)throw new IllegalArgumentException("Table column metadata budget exceeded");
                result.add(SchemaObject.newBuilder().setKind(ObjectKind.COLUMN).setCatalog(catalog).setSchema(schema).setTable(table).setName(rows.getString("COLUMN_NAME"))
                    .putProperties("type",text(rows.getString("TYPE_NAME"))).putProperties("jdbcNativeType",text(rows.getString("TYPE_NAME"))).putProperties("jdbcType",Integer.toString(rows.getInt("DATA_TYPE")))
                    .putProperties("precision",text(rows.getString("COLUMN_SIZE"))).putProperties("scale",text(rows.getString("DECIMAL_DIGITS"))).putProperties("nullable",nullable(rows.getInt("NULLABLE")))
                    .putProperties("default",text(rows.getString("COLUMN_DEF"))).putProperties("defaultAvailability",rows.getString("COLUMN_DEF")==null?"ABSENT":"AVAILABLE")
                    .putProperties("ordinal",text(rows.getString("ORDINAL_POSITION"))).putProperties("generated",text(rows.getString("IS_GENERATEDCOLUMN"))).putProperties("autoIncrement",text(rows.getString("IS_AUTOINCREMENT"))).putProperties("remarks",text(rows.getString("REMARKS"))).build());
            }
        }return List.copyOf(result);
    }
    private static void postgresScope(SessionRegistry.Session session,String schema)throws SQLException {
        if(!session.context.catalog().equals(session.connection.getCatalog()))throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.INVALID_REVISION);
        boolean temporary=!session.context.temporarySchema().isEmpty()&&schema.equals(session.context.temporarySchema());
        if(schema.startsWith("pg_temp_")&&!temporary||temporary&&!session.lock.isHeldByCurrentThread())throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.INVALID_OWNER);
    }
    /** Point getTables also retains its full native description eagerly. */
    static long postgresTableBytes(SessionRegistry.Session session,String schema,String table)throws SQLException {
        postgresScope(session,schema);
        try(var statement=session.adapter.catalogStatement(session.connection,"SELECT COUNT(*),COALESCE(SUM(OCTET_LENGTH(COALESCE(obj_description(c.oid,'pg_class'),''))),0) FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=? AND c.relname=?")) {
            statement.setString(1,schema);statement.setString(2,table);
            try(var rows=statement.executeQuery()) {
                check();if(!rows.next())throw new SQLException("PostgreSQL table metadata resource evidence is unavailable");
                long count=rows.getLong(1),bytes=rows.getLong(2);
                if(count<0||count>1||bytes<0||bytes>65_536)throw new MetadataLimit();return 1_048_576L+4096L*count+4L*bytes;
            }
        }
    }
    /** pgJDBC getColumns materializes every tuple, including full descriptions,
     * before returning its ResultSet. Reject oversize declarations before that
     * driver allocation; a post-getString check cannot enforce this boundary. */
    private static long postgresDriverBytes(SessionRegistry.Session session,String schema,String table)throws SQLException {
        postgresScope(session,schema);
        String sql="SELECT COUNT(*),COALESCE(SUM(OCTET_LENGTH(COALESCE(pg_get_expr(d.adbin,d.adrelid),''))),0),COALESCE(MAX(OCTET_LENGTH(COALESCE(pg_get_expr(d.adbin,d.adrelid),''))),0),COALESCE(SUM(OCTET_LENGTH(COALESCE(col_description(t.oid,a.attnum),''))),0),COALESCE(MAX(OCTET_LENGTH(COALESCE(col_description(t.oid,a.attnum),''))),0) FROM pg_catalog.pg_attribute a JOIN pg_catalog.pg_class t ON t.oid=a.attrelid JOIN pg_catalog.pg_namespace n ON n.oid=t.relnamespace LEFT JOIN pg_catalog.pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum WHERE n.nspname=? AND t.relname=? AND a.attnum>0 AND NOT a.attisdropped";
        try(var statement=session.adapter.catalogStatement(session.connection,sql)) {
            statement.setString(1,schema);statement.setString(2,table);
            try(var rows=statement.executeQuery()){
                check();if(!rows.next())throw new SQLException("PostgreSQL JDBC metadata resource evidence is unavailable");
                long count=rows.getLong(1),defaults=rows.getLong(2),remarks=rows.getLong(4);
                if(count<0||count>2048||defaults<0||defaults>4_194_304||rows.getLong(3)>65_536||remarks<0||remarks>4_194_304||rows.getLong(5)>65_536)
                    throw new MetadataLimit();
                return 1_048_576L+4096L*count+4L*(defaults+remarks);
            }
        }
    }
    /** Only this private view temporarily normalizes LIKE escaping for pinned drivers. */
    private static final class MetadataMode implements AutoCloseable {
        private final Connection connection;private final int networkTimeout;private final io.grpc.Context context=io.grpc.Context.current();
        private final io.grpc.Context.CancellationListener listener;private String original;private boolean changed;
        MetadataMode(SessionRegistry.Session view)throws SQLException {
            connection=view.connection;networkTimeout=connection.getNetworkTimeout();
            listener=ignored->{try{connection.abort(Runnable::run);}catch(SQLException ignoredFailure){}};
            connection.setNetworkTimeout(Runnable::run,networkTimeout>0?Math.min(networkTimeout,10000):10000);context.addListener(listener,CANCELLATION);
            try{
                check();try(var statement=connection.createStatement();var rows=statement.executeQuery("SELECT @@SESSION.sql_mode")){if(!rows.next())throw new SQLException("Metadata SQL mode unavailable");original=rows.getString(1);if(original==null||original.length()>8192||rows.next())throw new SQLException("Metadata SQL mode unavailable");}
                String masked=String.join(",",Arrays.stream(original.split(",")).filter(mode->!mode.equalsIgnoreCase("NO_BACKSLASH_ESCAPES")).toList());
                if(!masked.equals(original)){changed=true;setMode(masked);}
            }catch(SQLException|RuntimeException failure){try{close();}catch(SQLException cleanup){failure.addSuppressed(cleanup);}throw failure;}
        }
        private void setMode(String mode)throws SQLException {try(var statement=connection.prepareStatement("SET SESSION sql_mode=?")){statement.setString(1,mode);statement.execute();}}
        @Override public void close()throws SQLException {
            context.removeListener(listener);
            if(!connection.isClosed())try{if(changed)setMode(original);}finally{connection.setNetworkTimeout(Runnable::run,networkTimeout);}
        }
    }
    private static String nullable(int value){return switch(value){case DatabaseMetaData.columnNoNulls->"NO";case DatabaseMetaData.columnNullable->"YES";default->"UNKNOWN";};}
}
