package io.busystack.busydata.adapters;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.security.*;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.sql.*;
import java.util.*;

public final class JdbcAdapter {
    private final Engine engine;
    private final PrivateTemporaryFiles temporaryFiles;
    public JdbcAdapter(Engine engine){this(engine,null);}
    public JdbcAdapter(Engine engine,PrivateTemporaryFiles temporaryFiles){if(engine==Engine.ENGINE_UNSPECIFIED||engine==Engine.UNRECOGNIZED)throw new IllegalArgumentException("Choose a database engine");this.engine=engine;this.temporaryFiles=temporaryFiles;}
    public Engine engine(){return engine;}
    public void initialContext(Connection connection,String catalog,String schema)throws SQLException {
        if(catalog.length()>256||schema.length()>256||catalog.indexOf('\0')>=0||schema.indexOf('\0')>=0)throw new IllegalArgumentException("Invalid requested connection scope");
        if(engine==Engine.POSTGRESQL) {
            if(!catalog.isEmpty()&&!catalog.equals(connection.getCatalog()))throw new IllegalArgumentException("PostgreSQL database changes require a separate configured connection");
            if(!schema.isEmpty()) {
                boolean found=false;
                try(var lookup=connection.prepareStatement("SELECT 1 FROM pg_catalog.pg_namespace WHERE nspname=? AND pg_catalog.has_schema_privilege(oid,'USAGE')")) {
                    lookup.setString(1,schema);
                    try(var scopes=lookup.executeQuery()){found=scopes.next();}
                }
                if(!found)throw new IllegalArgumentException("Requested schema is unavailable; choose an accessible schema explicitly");
                connection.setSchema(schema);
            }
        } else {
            String selected=catalog.isEmpty()?schema:catalog;
            if(!catalog.isEmpty()&&!schema.isEmpty()&&!catalog.equals(schema))throw new IllegalArgumentException("MySQL and MariaDB use catalogs for database scope");
            if(!selected.isEmpty())connection.setCatalog(selected);
        }
    }
    public static void validate(Profile p) {
        new JdbcAdapter(p.getEngine());
        if(p.getName().isBlank()||p.getHost().isBlank()||!p.getHost().matches("[A-Za-z0-9_.:\\[\\]-]+")||p.getPort()<1||p.getPort()>65535||p.getUser().isBlank())throw new IllegalArgumentException("Invalid endpoint or user");
        if(p.getConnectTimeoutSeconds()<1||p.getConnectTimeoutSeconds()>120||p.getQueryTimeoutSeconds()>3600)throw new IllegalArgumentException("Invalid timeout");
        if(p.getOptionsCount()>8||!Set.of("applicationName","tcpKeepAlive").containsAll(p.getOptionsMap().keySet()))throw new IllegalArgumentException("Unreviewed driver option");
        if(p.getOptionsMap().containsKey("tcpKeepAlive")&&!Set.of("true","false").contains(p.getOptionsMap().get("tcpKeepAlive")))throw new IllegalArgumentException("tcpKeepAlive must be true or false");
        if(p.getDatabase().length()>256||p.getName().length()>256||p.getHost().length()>256)throw new IllegalArgumentException("Profile fields too long");
        if(p.getEnvironment()==Environment.UNRECOGNIZED||p.getTls().getMode()==TlsMode.UNRECOGNIZED)throw new IllegalArgumentException("Invalid profile environment/TLS mode");
        if(p.getTls().hasConfiguredMode()&&!Set.of(TlsMode.INSECURE,TlsMode.VERIFY_CA,TlsMode.VERIFY_FULL).contains(p.getTls().getConfiguredMode()))throw new IllegalArgumentException("Invalid configured TLS mode");
        if(p.getSsh().getEnabled()&&(p.getSsh().getHost().isBlank()||!p.getSsh().getHost().matches("[A-Za-z0-9_.:\\[\\]-]+")||p.getSsh().getHost().length()>256||p.getSsh().getUser().isBlank()||p.getSsh().getPort()<0||p.getSsh().getPort()>65535))throw new IllegalArgumentException("Invalid SSH endpoint");
    }
    /** The exact non-secret address passed to JDBC, also used by settings. */
    public static String address(Profile p) {
        String host=p.getHost().contains(":")&&!p.getHost().startsWith("[")?"["+p.getHost()+"]":p.getHost();
        return "jdbc:"+switch(p.getEngine()){case POSTGRESQL->"postgresql";case MYSQL->"mysql";case MARIADB->"mariadb";default->throw new IllegalArgumentException("Invalid engine");}+"://"+host+":"+p.getPort()+"/"+(p.getEngine()==Engine.MARIADB?"":URLEncoder.encode(p.getDatabase(),StandardCharsets.UTF_8).replace("+","%20"));
    }
    public static ConnectionDescription describe(Profile p) throws Exception {
        Class<?> driver=Class.forName(switch(p.getEngine()){case POSTGRESQL->"org.postgresql.Driver";case MYSQL->"com.mysql.cj.jdbc.Driver";case MARIADB->"org.mariadb.jdbc.Driver";default->throw new IllegalArgumentException("Invalid engine");});
        String version=driver.getPackage().getImplementationVersion();
        return ConnectionDescription.newBuilder().setJdbcUrl(address(p)).setInitialDatabase(p.getDatabase()).setDriverClass(driver.getName()).setDriverVersion(version==null?"bundled":version).build();
    }
    public Connection connect(OpenRequest r,Integer tunnel)throws Exception {
        if(temporaryFiles==null)throw new IllegalStateException("Connection adapters require owned private scratch space");
        Profile p=r.getProfile();validate(p);
        var props=new Properties();props.setProperty("user",p.getUser());props.setProperty("password",r.getPassword());
        String url=address(p);
        String timeout=Integer.toString(p.getConnectTimeoutSeconds()*1000);
        if(engine==Engine.POSTGRESQL) {
            props.setProperty("maxResultBuffer","8M");props.setProperty("adaptiveFetch","true");props.setProperty("defaultRowFetchSize","16");props.setProperty("adaptiveFetchMinimum","1");props.setProperty("adaptiveFetchMaximum","256");props.setProperty("logServerErrorDetail","false");
            props.setProperty("connectTimeout",Integer.toString(p.getConnectTimeoutSeconds()));props.setProperty("socketTimeout","300");props.setProperty("cancelSignalTimeout","5");props.setProperty("ApplicationName","BusyData");
            props.setProperty("sslmode",switch(p.getTls().getMode()){case VERIFY_FULL->"verify-full";case INSECURE->"require";case DISABLED->"disable";case VERIFY_CA->"verify-ca";case DRIVER_DEFAULT->"prefer";default->throw new IllegalArgumentException("Invalid TLS mode");});
            if(!p.getTls().getCaFile().isEmpty())props.setProperty("sslrootcert",p.getTls().getCaFile());
            props.setProperty("sslcert",p.getTls().getClientCert());props.setProperty("sslkey",p.getTls().getClientKey()); // Empty strings disable pgJDBC's implicit ~/.postgresql identity discovery.
            props.setProperty("readOnlyMode","always");
            props.setProperty("autosave","never");
            if(tunnel!=null){props.setProperty("socketFactory",TunnelSockets.class.getName());props.setProperty("socketFactoryArg",Integer.toString(tunnel));}
        } else {
            props.setProperty("maxAllowedPacket","8388608");
            props.setProperty("tinyInt1isBit","false");
            props.setProperty("yearIsDateType","false");
            props.setProperty("connectTimeout",timeout);props.setProperty("socketTimeout","300000");props.setProperty("allowLocalInfile","false");props.setProperty("allowLoadLocalInfile","false");props.setProperty("allowUrlInLocalInfile","false");
            if(engine==Engine.MYSQL) {
                props.setProperty("sslMode",switch(p.getTls().getMode()){case VERIFY_FULL->"VERIFY_IDENTITY";case INSECURE->"REQUIRED";case DISABLED->"DISABLED";case VERIFY_CA->"VERIFY_CA";case DRIVER_DEFAULT->"PREFERRED";default->throw new IllegalArgumentException("Invalid TLS mode");});
                props.setProperty("allowMultiQueries","false");props.setProperty("useCursorFetch","true");props.setProperty("useServerPrepStmts","true");
                // Connector/J's implicit streaming-timeout SET clears cached transaction
                // flags during cleanup. Keep server session settings and status intact.
                props.setProperty("netTimeoutForStreamingResults","0");
                if(tunnel!=null)props.setProperty("socketFactory",MysqlTunnelSockets.class.getName());
            } else {
                props.setProperty("disableSslContextCache","true"); // Pinned 3.5.10: keep private key/trust managers owned by the live connection.
                props.setProperty("maxAllowedColumns","2048");props.setProperty("maxQuerySizeToLog","0");
                props.setProperty("sslMode",switch(p.getTls().getMode()){case VERIFY_FULL->"verify-full";case INSECURE->"trust";case DISABLED->"disable";case VERIFY_CA->"verify-ca";case DRIVER_DEFAULT->"disable";default->throw new IllegalArgumentException("Invalid TLS mode");});
                if(!p.getTls().getCaFile().isEmpty())props.setProperty("serverSslCert",p.getTls().getCaFile());
                if(tunnel!=null)props.setProperty("socketFactory",TunnelSockets.class.getName());
            }
        }
        if(p.getOptionsMap().containsKey("tcpKeepAlive"))props.setProperty("tcpKeepAlive",p.getOptionsMap().get("tcpKeepAlive"));
        if(p.getOptionsMap().containsKey("applicationName")){String name=p.getOptionsMap().get("applicationName");if(name.length()>256)throw new IllegalArgumentException("Application name exceeds 256 characters");if(engine==Engine.POSTGRESQL)props.setProperty("ApplicationName",name);else if(engine==Engine.MARIADB)props.setProperty("connectionAttributes","applicationName:"+name);else throw new IllegalArgumentException("MySQL applicationName option is not supported");}
        TunnelSockets.PORT.set(tunnel);
        Connection owned=null;
        try(var tls=new JdbcTlsMaterial(temporaryFiles)) {tls.configure(p,props,r.getTlsKeyPassword());var c=DriverManager.getConnection(url,props);owned=c;try{
            // MariaDB Connector/J treats URL database text literally; setCatalog
            // supplies the exact identifier without URL options or encoding.
            if(engine==Engine.MARIADB&&!p.getDatabase().isEmpty())c.setCatalog(p.getDatabase());
            c.setReadOnly(p.getReadOnly());
            if(p.getReadOnly()&&engine!=Engine.POSTGRESQL)try(var s=c.createStatement()){s.execute("SET SESSION TRANSACTION READ ONLY");}
            return c;
            }catch(Exception error){try{c.close();}catch(Exception cleanup){error.addSuppressed(cleanup);}throw error;}
        } catch(Exception failure){if(owned!=null)try{owned.close();}catch(Exception cleanup){failure.addSuppressed(cleanup);}throw failure;} finally{props.clear();TunnelSockets.PORT.remove();}
    }
    public String quote(String name){if(name.isEmpty()||name.indexOf('\0')>=0||name.length()>256)throw new IllegalArgumentException("Invalid identifier");return new io.busystack.busydata.metadata.IdentifierRules(engine,0).quote(name);}
    public String table(String catalog,String schema,String table){String scope=engine==Engine.POSTGRESQL?schema:catalog.isEmpty()?schema:catalog;return (scope.isEmpty()?"":quote(scope)+".")+quote(table);}
    /** Raw editor SQL has no JDBC parameters or escape-rewrite contract. Generated
     * bound operations use prepareStatement at their own parameterized callers. */
    public Statement rawStatement(Connection c,boolean streaming,int timeout,long rowLimit)throws SQLException {
        var s=c.createStatement(ResultSet.TYPE_FORWARD_ONLY,ResultSet.CONCUR_READ_ONLY);
        s.setEscapeProcessing(false);
        s.setQueryTimeout(timeout==0?60:timeout);s.setMaxRows((int)Math.min(Integer.MAX_VALUE,rowLimit));
        if(engine==Engine.POSTGRESQL){s.setFetchSize(c.getAutoCommit()?0:16);s.unwrap(org.postgresql.PGStatement.class).setAdaptiveFetch(true);}
        else if(engine==Engine.MYSQL)s.setFetchSize(Integer.MIN_VALUE); // Connector/J forward-only text streaming; cursor cancellation leaves unread protocol packets in 26.7.0.
        else s.setFetchSize(256);
        return engine==Engine.POSTGRESQL?PostgresRawStatements.wrap(c,s):s;
    }
    /** Fixed parameterized catalog SQL can contain large definitions. Positive
     * single-row driver fetching prevents aggregate MySQL/MariaDB buffering;
     * PostgreSQL's maxResultBuffer remains enforced without changing a user's
     * auto-commit or transaction merely to obtain a cursor. */
    public PreparedStatement catalogStatement(Connection connection,String sql)throws SQLException {
        var statement=connection.prepareStatement(sql,ResultSet.TYPE_FORWARD_ONLY,ResultSet.CONCUR_READ_ONLY);
        try {
            statement.setQueryTimeout(10);statement.setFetchSize(1);statement.setMaxRows(10001);
            if(engine==Engine.POSTGRESQL)statement.unwrap(org.postgresql.PGStatement.class).setAdaptiveFetch(false);
            return statement;
        }catch(SQLException error){try{statement.close();}catch(SQLException cleanup){error.addSuppressed(cleanup);}throw error;}
    }
    public ConnectionInfo info(Connection c)throws SQLException {
        var m=c.getMetaData();String product=m.getDatabaseProductName(),version=m.getDatabaseProductVersion();
        var info=ConnectionInfo.newBuilder().setProduct(product.substring(0,Math.min(product.length(),128))).setVersion(version.substring(0,Math.min(version.length(),512)));
        // Read the actual owned connection. Encryption is not a verification claim.
        try(var statement=c.createStatement()) {
            statement.setQueryTimeout(5);
            try(var rows=statement.executeQuery(engine==Engine.POSTGRESQL?"SELECT ssl, cipher FROM pg_catalog.pg_stat_ssl WHERE pid=pg_backend_pid()":"SHOW SESSION STATUS LIKE 'Ssl_cipher'")) {
                if(rows.next()) {String cipher=rows.getString(2);info.setTlsObserved(true).setTlsCipher(cipher==null?"":cipher.substring(0,Math.min(cipher.length(),128)));}
            }
        } catch(SQLException unavailable) { /* Reachability does not invent a TLS-state observation. */ }
        return info.build();
    }
    public record LiveContext(String catalog,String schema,List<String> searchPath,String temporarySchema,String sqlMode,boolean standardConformingStrings,String timeZone,String systemTimeZone,boolean arrayNulls,String dateStyle) {
        public LiveContext(String catalog,String schema,List<String> searchPath,String temporarySchema){this(catalog,schema,searchPath,temporarySchema,"",true,"","",true,"");}
        public LiveContext(String catalog,String schema,List<String> searchPath,String temporarySchema,String sqlMode,boolean standardConformingStrings){this(catalog,schema,searchPath,temporarySchema,sqlMode,standardConformingStrings,"","",true,"");}
        public LiveContext(String catalog,String schema,List<String> searchPath,String temporarySchema,String sqlMode,boolean standardConformingStrings,String timeZone,String systemTimeZone){this(catalog,schema,searchPath,temporarySchema,sqlMode,standardConformingStrings,timeZone,systemTimeZone,true,"");}
        public LiveContext {searchPath=List.copyOf(searchPath);Objects.requireNonNull(timeZone);Objects.requireNonNull(systemTimeZone);Objects.requireNonNull(dateStyle);}
        public io.busystack.busydata.analysis.LexicalSettings lexical(){var lexical=io.busystack.busydata.analysis.LexicalSettings.mysql(sqlMode);return new io.busystack.busydata.analysis.LexicalSettings(lexical.noBackslashEscapes(),lexical.ansiQuotes(),standardConformingStrings,lexical.ignoreSpace(),lexical.pipesAsConcat(),lexical.highNotPrecedence(),lexical.noUnsignedSubtraction(),lexical.realAsFloat(),lexical.sqlMode());}
    }
    public LiveContext context(Connection connection)throws SQLException {
        try(var statement=connection.createStatement()) {
            statement.setQueryTimeout(5);statement.setMaxRows(1);
            String sql=engine==Engine.POSTGRESQL?"SELECT current_database(), current_schema(), (current_schemas(false))[1:64], (SELECT nspname FROM pg_namespace WHERE oid=pg_my_temp_schema()), current_setting('standard_conforming_strings'), current_setting('array_nulls'), current_setting('DateStyle')":"SELECT DATABASE(), @@session.sql_mode, @@session.time_zone, @@system_time_zone";
            if(engine==Engine.POSTGRESQL) {
                // The fixed inspection must not implicitly BEGIN an idle manual
                // console. It never changes auto-commit or commits user work.
                statement.unwrap(org.postgresql.jdbc.PgStatement.class).executeWithFlags(sql,org.postgresql.core.QueryExecutor.QUERY_SUPPRESS_BEGIN);
            }else statement.execute(sql);
            try(var rows=statement.getResultSet()) {
                if(!rows.next())throw new SQLException("Live context unavailable","08006");
                String catalog=Objects.requireNonNullElse(rows.getString(1),"");
                if(engine!=Engine.POSTGRESQL)return new LiveContext(catalog,catalog,catalog.isEmpty()?List.of():List.of(catalog),"",rows.getString(2),true,Objects.toString(rows.getString(3),""),Objects.toString(rows.getString(4),""));
                String schema=Objects.requireNonNullElse(rows.getString(2),""),temporary=Objects.requireNonNullElse(rows.getString(4),"");
                var path=new ArrayList<String>();var array=rows.getArray(3);
                if(array!=null)try{for(Object name:(Object[])array.getArray())path.add(name.toString());}finally{array.free();}
                return new LiveContext(catalog,schema,path,temporary,"","on".equals(rows.getString(5)),"","","on".equals(rows.getString(6)),Objects.toString(rows.getString(7),""));
            }
        }
    }
    public void metadataContext(Connection connection,LiveContext context)throws SQLException {
        if(engine!=Engine.POSTGRESQL){if(!context.catalog().isEmpty())connection.setCatalog(context.catalog());try(var statement=connection.prepareStatement("SET SESSION sql_mode=?")){statement.setString(1,context.sqlMode());statement.setQueryTimeout(5);statement.execute();}if(!context.timeZone().isEmpty())try(var statement=connection.prepareStatement("SET SESSION time_zone=?")){statement.setString(1,context.timeZone());statement.setQueryTimeout(5);statement.execute();}return;}
        String path=String.join(",",context.searchPath().stream().filter(name->!name.startsWith("pg_temp_")).map(this::quote).toList());
        try(var statement=connection.prepareStatement("SELECT set_config('search_path',?,false)")){statement.setString(1,path);statement.setQueryTimeout(5);statement.execute();}
        try(var statement=connection.prepareStatement("SELECT set_config('standard_conforming_strings',?,false)")){statement.setString(1,context.standardConformingStrings()?"on":"off");statement.setQueryTimeout(5);statement.execute();}
        try(var statement=connection.prepareStatement("SELECT set_config('array_nulls',?,false)")){statement.setString(1,context.arrayNulls()?"on":"off");statement.setQueryTimeout(5);statement.execute();}
        if(!context.dateStyle().isEmpty())try(var statement=connection.prepareStatement("SELECT set_config('DateStyle',?,false)")){statement.setString(1,context.dateStyle());statement.setQueryTimeout(5);statement.execute();}
    }
    public TransactionState transaction(Connection c)throws SQLException {
        if(c.isClosed())return TransactionState.DISCONNECTED;
        if(engine==Engine.POSTGRESQL) {
            var state=c.unwrap(org.postgresql.core.BaseConnection.class).getTransactionState();
            return switch(state){case IDLE->TransactionState.IDLE;case OPEN->TransactionState.ACTIVE;case FAILED->TransactionState.FAILED_TRANSACTION;};
        }
        if(engine==Engine.MYSQL)return c.unwrap(com.mysql.cj.jdbc.JdbcConnection.class).getSession().getServerSession().inTransactionOnServer()?TransactionState.ACTIVE:TransactionState.IDLE;
        return (c.unwrap(org.mariadb.jdbc.Connection.class).getContext().getServerStatus()&org.mariadb.jdbc.util.constants.ServerStatus.IN_TRANSACTION)!=0?TransactionState.ACTIVE:TransactionState.IDLE;
    }
    public String toolSql(ToolRequest r) {
        String target= r.getTable().isBlank()?"":table("",r.getSchema(),r.getTable());
        return switch(r.getKind()) {
            case EXPLAIN->(engine==Engine.POSTGRESQL?"EXPLAIN (FORMAT JSON) ":"EXPLAIN FORMAT=JSON ")+r.getSql();
            case EXPLAIN_ANALYZE->(engine==Engine.POSTGRESQL?"EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) ":engine==Engine.MARIADB?"ANALYZE FORMAT=JSON ":"EXPLAIN ANALYZE ")+r.getSql();
            case ACTIVITY->engine==Engine.POSTGRESQL?"SELECT pid,usename,datname,state,wait_event_type,wait_event,query_start,pg_blocking_pids(pid) AS blockers,query FROM pg_stat_activity": "SELECT ID,USER,HOST,DB,COMMAND,TIME,STATE,INFO FROM information_schema.PROCESSLIST";
            case LOCKS->engine==Engine.POSTGRESQL?"SELECT pid,locktype,database,relation,mode,granted FROM pg_locks":engine==Engine.MYSQL?"SELECT * FROM performance_schema.data_lock_waits":"SELECT * FROM information_schema.INNODB_LOCK_WAITS";
            case STATISTICS->engine==Engine.POSTGRESQL?"SELECT * FROM pg_stat_user_indexes":"SELECT TABLE_SCHEMA,TABLE_NAME,INDEX_NAME,NON_UNIQUE,SEQ_IN_INDEX,COLUMN_NAME,CARDINALITY FROM information_schema.STATISTICS";
            case QUERY_STATISTICS->engine==Engine.POSTGRESQL?"SELECT queryid,calls,total_exec_time,mean_exec_time,rows,shared_blks_hit,shared_blks_read,LEFT(query,8192) AS query FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 500":"SELECT SCHEMA_NAME,DIGEST,LEFT(DIGEST_TEXT,8192) AS statement,COUNT_STAR,SUM_TIMER_WAIT/1000000000000 AS total_seconds,AVG_TIMER_WAIT/1000000000000 AS mean_seconds,SUM_ROWS_SENT,SUM_ROWS_EXAMINED,SUM_CREATED_TMP_DISK_TABLES FROM performance_schema.events_statements_summary_by_digest WHERE DIGEST IS NOT NULL ORDER BY SUM_TIMER_WAIT DESC LIMIT 500";
            case INDEX_DIAGNOSTICS->engine==Engine.POSTGRESQL?"SELECT s.schemaname,s.relname,s.indexrelname,s.idx_scan,s.idx_tup_read,s.idx_tup_fetch,pg_relation_size(s.indexrelid) AS index_bytes,x.indisunique,x.indisvalid,x.indisready FROM pg_stat_user_indexes s JOIN pg_index x ON x.indexrelid=s.indexrelid ORDER BY s.schemaname,s.relname,s.indexrelname":"SELECT OBJECT_SCHEMA,OBJECT_NAME,INDEX_NAME,COUNT_READ,COUNT_FETCH,SUM_TIMER_READ/1000000000000 AS read_seconds FROM performance_schema.table_io_waits_summary_by_index_usage WHERE OBJECT_SCHEMA NOT IN ('mysql','sys','performance_schema','information_schema') ORDER BY OBJECT_SCHEMA,OBJECT_NAME,INDEX_NAME LIMIT 500";
            case ROLES->engine==Engine.POSTGRESQL?"SELECT rolname,rolsuper,rolinherit,rolcreaterole,rolcreatedb,rolcanlogin,rolvaliduntil FROM pg_roles":"SELECT User,Host,plugin FROM mysql.user";
            case GRANTS->engine==Engine.POSTGRESQL?"SELECT grantee,table_schema,table_name,privilege_type,is_grantable FROM information_schema.role_table_grants":"SELECT GRANTEE,'global' AS scope,'' AS target_schema,'' AS target_object,PRIVILEGE_TYPE,IS_GRANTABLE FROM information_schema.USER_PRIVILEGES UNION ALL SELECT GRANTEE,'database',TABLE_SCHEMA,'',PRIVILEGE_TYPE,IS_GRANTABLE FROM information_schema.SCHEMA_PRIVILEGES UNION ALL SELECT GRANTEE,'table',TABLE_SCHEMA,TABLE_NAME,PRIVILEGE_TYPE,IS_GRANTABLE FROM information_schema.TABLE_PRIVILEGES ORDER BY GRANTEE,scope,target_schema,target_object,PRIVILEGE_TYPE";
            case DEFINITION->engine==Engine.POSTGRESQL?"SELECT pg_get_viewdef("+literal(table("",r.getSchema(),r.getTable()))+"::regclass,true)":"SHOW CREATE TABLE "+target;
            case SNAPSHOT->"SELECT table_schema,table_name,column_name,ordinal_position,column_default,is_nullable,data_type,character_maximum_length,numeric_precision,numeric_scale FROM information_schema.columns WHERE table_schema NOT IN ('information_schema','pg_catalog','mysql','performance_schema','sys') ORDER BY table_schema,table_name,ordinal_position";
            default->throw new UnsupportedOperationException("This tool requires a transfer handler");
        };
    }
    private static String literal(String value){return "'"+value.replace("'","''")+"'";}
}
