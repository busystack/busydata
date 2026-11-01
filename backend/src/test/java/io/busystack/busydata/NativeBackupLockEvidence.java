package io.busystack.busydata;

import com.google.gson.Gson;
import io.busystack.busydata.adapters.JdbcAdapter;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.sessions.SessionRegistry;
import java.io.Reader;
import java.sql.*;
import java.util.*;
import java.util.concurrent.TimeUnit;
import java.util.regex.Pattern;

/** Failure-only disposable-server postmortem. Never retains SQL or arbitrary names. */
final class NativeBackupLockEvidence {
    private static final int ROWS=64,CHARS=65536;
    private static final long BUDGET=TimeUnit.SECONDS.toNanos(15);
    private static final Pattern TRANSACTION=Pattern.compile("^\\*\\*\\* \\(([1-9][0-9]?)\\) TRANSACTION:$"),
        TRANSACTION_ID=Pattern.compile("^TRANSACTION ([0-9]{1,20}),.*$"),
        CONNECTION_ID=Pattern.compile("^MariaDB thread id ([0-9]{1,20}),.*$"),
        VICTIM=Pattern.compile("^\\*\\*\\* WE ROLL BACK TRANSACTION \\(([1-9][0-9]?)\\).*$");
    private static final Set<String> LOCK_TYPES=Set.of("SHARED","SHARED_HIGH_PRIO","SHARED_READ","SHARED_WRITE","SHARED_UPGRADABLE","SHARED_NO_WRITE","SHARED_NO_READ_WRITE","EXCLUSIVE","INTENTION_EXCLUSIVE");
    private static final Set<String> LOCK_STATUS=Set.of("GRANTED","PENDING","VICTIM","TIMEOUT","KILLED","POST_RELEASE_NOTIFY","PRE_ACQUIRE_NOTIFY");
    private static final Set<String> TRX_STATE=Set.of("RUNNING","LOCK WAIT","ROLLING BACK","COMMITTING");
    private NativeBackupLockEvidence(){}
    static String capture(EngineFixture fixture,SessionRegistry.Session source){
        long deadline=System.nanoTime()+BUDGET;
        var result=new LinkedHashMap<String,Object>();result.put("diagnosticOnly",true);result.put("engine","MARIADB");
        result.put("historicalCycleIsNotInferredFromCurrentLocks",true);result.put("historyMayPredateFailure",true);
        if(fixture.engine!=Engine.MARIADB||!fixture.database.getContainerId().matches("[a-f0-9]{64}")||!source.profile.equals(fixture.profile)
            ||source.profile.getSsh().getEnabled()||source.profile.getTls().getMode()!=TlsMode.DISABLED)return "{\"availability\":\"WRONG_FIXTURE\"}";
        try {
            if(source.lock.tryLock(200,TimeUnit.MILLISECONDS))try {
                // Public driver identity getter: no SQL or transaction change on
                // the console connection after the uncertain external restore.
                result.put("sourceConnectionId",Long.toUnsignedString(source.connection.unwrap(org.mariadb.jdbc.Connection.class).getThreadId()));
            }finally{source.lock.unlock();}
            else result.put("sourceConnectionAvailability","OWNER_BUSY");
        }catch(InterruptedException interrupted){Thread.currentThread().interrupt();return "{\"availability\":\"INTERRUPTED\"}";}
        catch(Exception unavailable){result.put("sourceConnectionAvailability",failure(unavailable));}
        var profile=fixture.profile.toBuilder().setConnectTimeoutSeconds(2).setQueryTimeoutSeconds(2).build();
        var properties=new Properties();properties.setProperty("user",profile.getUser());properties.setProperty("password",source.password());
        // This failure-only fixture observer uses the official driver's public
        // timeouts, without opening another production metadata owner or altering
        // server instrumentation, console state, or native restore behavior.
        properties.setProperty("connectTimeout","2000");properties.setProperty("socketTimeout","2000");properties.setProperty("sslMode","disable");
        properties.setProperty("allowLocalInfile","false");properties.setProperty("allowLoadLocalInfile","false");properties.setProperty("allowUrlInLocalInfile","false");
        try(var connection=DriverManager.getConnection(JdbcAdapter.address(profile),properties)){
            connection.setNetworkTimeout(Runnable::run,2000);connection.setCatalog("busydata");
            result.put("latestDeadlock",latest(connection,deadline));
            result.put("transactions",query(connection,deadline,"SELECT trx_id,trx_mysql_thread_id,trx_state FROM information_schema.INNODB_TRX LIMIT 65",rows->Map.of(
                "transactionId",number(rows.getString(1)),"connectionId",number(rows.getString(2)),"state",known(rows.getString(3),TRX_STATE))));
            result.put("waitEdges",query(connection,deadline,"SELECT requesting_trx_id,blocking_trx_id FROM information_schema.INNODB_LOCK_WAITS LIMIT 65",rows->Map.of(
                "requestingTransactionId",number(rows.getString(1)),"blockingTransactionId",number(rows.getString(2)))));
            var instrumentation=query(connection,deadline,"SELECT @@performance_schema,EXISTS(SELECT 1 FROM performance_schema.setup_instruments WHERE NAME='wait/lock/metadata/sql/mdl' AND ENABLED='YES')",rows->Map.of(
                "performanceSchema",rows.getBoolean(1)?"ENABLED":"DISABLED","metadataLocks",rows.getBoolean(2)?"ENABLED":"DISABLED"));
            result.put("instrumentation",instrumentation);
            if(!instrumentation.equals(Map.of("availability","AVAILABLE","rows",List.of(Map.of("performanceSchema","ENABLED","metadataLocks","ENABLED")))))result.put("metadataLocks",Map.of("availability","NOT_INSTRUMENTED_OR_UNAVAILABLE"));
            else result.put("metadataLocks",query(connection,deadline,"SELECT l.OWNER_THREAD_ID,t.PROCESSLIST_ID,l.LOCK_TYPE,l.LOCK_DURATION,l.LOCK_STATUS,l.OBJECT_NAME FROM performance_schema.metadata_locks l LEFT JOIN performance_schema.threads t ON t.THREAD_ID=l.OWNER_THREAD_ID WHERE l.OBJECT_SCHEMA='busydata' LIMIT 65",rows->Map.of(
                "ownerThreadId",number(rows.getString(1)),"connectionId",number(rows.getString(2)),"type",known(rows.getString(3),LOCK_TYPES),
                "duration",known(rows.getString(4),Set.of("STATEMENT","TRANSACTION","EXPLICIT")),"status",known(rows.getString(5),LOCK_STATUS),
                "targetRole",switch(Objects.toString(rows.getString(6),"")){case "backup_data"->"BACKUP_TABLE";case "backup_view"->"BACKUP_VIEW";default->"OTHER_FIXTURE_OBJECT";})));
        }catch(Exception unavailable){result.put("connectionAvailability",failure(unavailable));}
        finally{properties.clear();}
        String json=new Gson().toJson(result);return json.length()<=CHARS?json:"{\"availability\":\"EVIDENCE_LIMIT\"}";
    }
    @FunctionalInterface private interface Row {Map<String,String> read(ResultSet rows)throws SQLException;}
    private static Map<String,Object> query(Connection connection,long deadline,String sql,Row project){
        if(System.nanoTime()>=deadline)return Map.of("availability","DEADLINE");
        try(var statement=connection.createStatement()){
            statement.setQueryTimeout(2);statement.setMaxRows(ROWS+1);var result=new ArrayList<Map<String,String>>();
            try(var rows=statement.executeQuery(sql)){while(rows.next()){if(System.nanoTime()>=deadline)return Map.of("availability","DEADLINE");if(result.size()==ROWS)return Map.of("availability","ROW_LIMIT");result.add(project.read(rows));}}
            return Map.of("availability","AVAILABLE","rows",result);
        }catch(Exception unavailable){return Map.of("availability","UNAVAILABLE","failure",failure(unavailable));}
    }
    private static Map<String,Object> latest(Connection connection,long deadline){
        if(System.nanoTime()>=deadline)return Map.of("availability","DEADLINE");
        try(var statement=connection.createStatement()){
            statement.setQueryTimeout(2);statement.setMaxRows(1);
            try(var rows=statement.executeQuery("SHOW ENGINE INNODB STATUS")){
                if(!rows.next())return Map.of("availability","UNAVAILABLE");
                try(Reader text=rows.getCharacterStream(3)){
                    var bounded=new StringBuilder();char[] buffer=new char[4096];int count;
                    while((count=text.read(buffer))!=-1){if(System.nanoTime()>=deadline)return Map.of("availability","DEADLINE");if(bounded.length()+count>CHARS)return Map.of("availability","CHAR_LIMIT");bounded.append(buffer,0,count);}
                    return parseLatestDeadlock(bounded.toString());
                }
            }
        }catch(Exception unavailable){return Map.of("availability","UNAVAILABLE","failure",failure(unavailable));}
    }
    static Map<String,Object> parseLatestDeadlock(String text){
        if(text==null||text.length()>CHARS)return Map.of("availability","CHAR_LIMIT");
        int start=text.indexOf("LATEST DETECTED DEADLOCK");if(start<0)return Map.of("availability","HISTORY_NOT_PRESENT");
        int end=text.indexOf("\nTRANSACTIONS",start);String section=text.substring(start,end<0?text.length():end);
        var entries=new ArrayList<Map<String,String>>();Map<String,String> entry=null;String victim="UNAVAILABLE";
        for(String line:section.split("\\R")){
            var transaction=TRANSACTION.matcher(line);
            if(transaction.matches()){if(entries.size()==ROWS)return Map.of("availability","ROW_LIMIT");entry=new LinkedHashMap<>();entry.put("slot",transaction.group(1));entries.add(entry);continue;}
            if(entry!=null){
                var id=TRANSACTION_ID.matcher(line);
                if(id.matches())entry.put("transactionId",id.group(1));
                var thread=CONNECTION_ID.matcher(line);
                if(thread.matches())entry.put("connectionId",thread.group(1));
            }
            var rollback=VICTIM.matcher(line);
            if(rollback.matches())victim=rollback.group(1);
        }
        return Map.of("availability",entries.isEmpty()?"UNRECOGNIZED_HISTORY":"AVAILABLE","transactions",entries,"victimSlot",victim);
    }
    private static String number(String value){return value!=null&&value.matches("[0-9]{1,20}")?value:"UNAVAILABLE";}
    private static String known(String value,Set<String> allowed){return allowed.contains(Objects.toString(value,""))?value:"OTHER";}
    private static Map<String,Object> failure(Exception failure){
        if(failure instanceof SQLException sql){String state=sql.getSQLState();return Map.of("type","SQL_EXCEPTION","sqlState",state!=null&&state.matches("[A-Z0-9]{5}")?state:"UNAVAILABLE","vendorCode",sql.getErrorCode());}
        if(failure instanceof InterruptedException){Thread.currentThread().interrupt();return Map.of("type","INTERRUPTED");}
        return Map.of("type","DIAGNOSTIC_UNAVAILABLE");
    }
}
