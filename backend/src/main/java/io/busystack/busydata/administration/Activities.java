package io.busystack.busydata.administration;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.sessions.SessionRegistry;
import java.sql.*;
import java.util.*;
import java.security.MessageDigest;
import java.nio.charset.StandardCharsets;

/** Live server identities are separate from UI selection and saved profiles. */
public final class Activities {
    private static String sql(Engine engine) {
        return switch(engine) {
            case POSTGRESQL -> "SELECT pid,COALESCE(usename,''),COALESCE(datname,''),COALESCE(state,''),LEFT(COALESCE(query,''),8192),backend_start::text,COALESCE(query_start::text,''),pg_blocking_pids(pid),COALESCE(wait_event_type||':'||wait_event,'') FROM pg_stat_activity WHERE pid<>pg_backend_pid()";
            case MYSQL -> "SELECT t.PROCESSLIST_ID,COALESCE(t.PROCESSLIST_USER,''),COALESCE(t.PROCESSLIST_DB,''),COALESCE(t.PROCESSLIST_STATE,t.PROCESSLIST_COMMAND,''),LEFT(COALESCE(t.PROCESSLIST_INFO,''),8192),CAST(t.THREAD_ID AS CHAR),COALESCE(CAST(e.EVENT_ID AS CHAR),''),NULL,COALESCE(t.PROCESSLIST_STATE,'') FROM performance_schema.threads t LEFT JOIN performance_schema.events_statements_current e ON e.THREAD_ID=t.THREAD_ID WHERE t.PROCESSLIST_ID IS NOT NULL AND t.PROCESSLIST_ID<>CONNECTION_ID()";
            case MARIADB -> "SELECT ID,USER,COALESCE(DB,''),COALESCE(STATE,COMMAND,''),LEFT(COALESCE(INFO,''),8192),HOST,CAST(QUERY_ID AS CHAR),NULL,COALESCE(STATE,'') FROM information_schema.PROCESSLIST WHERE ID<>CONNECTION_ID()";
            default -> throw new IllegalArgumentException("Choose a supported engine");
        };
    }
    private static Activity row(ResultSet row,Engine engine)throws Exception {
        var value=Activity.newBuilder().setId(row.getLong(1)).setPrincipal(row.getString(2)).setDatabase(row.getString(3)).setState(row.getString(4)).setQueryPreview(row.getString(5)).setWait(row.getString(9));
        var digest=MessageDigest.getInstance("SHA-256");
        for(int i:new int[]{1,2,3,5,6,7}){digest.update(Objects.toString(row.getString(i),"").getBytes(StandardCharsets.UTF_8));digest.update((byte)0);}
        value.setCancellable(!row.getString(5).isBlank()&&!Objects.toString(row.getString(7),"").isBlank());
        var blockers=engine==Engine.POSTGRESQL?row.getArray(8):null;if(blockers!=null)try{var ids=(Object[])blockers.getArray();if(ids.length>512)throw new IllegalStateException("Blocking relation limit reached");for(var id:ids)value.addBlockers(((Number)id).longValue());}finally{blockers.free();}
        return value.setFingerprint(HexFormat.of().formatHex(digest.digest())).build();
    }
    public ActivityList list(SessionRegistry.Session session)throws Exception {
        return session.metadata(view->{var result=ActivityList.newBuilder();int bytes=128;
            try(var statement=view.connection.createStatement()){statement.setQueryTimeout(5);statement.setMaxRows(513);try(var rows=statement.executeQuery(sql(view.profile.getEngine())+" ORDER BY 1")){while(rows.next()) {
                var entry=row(rows,view.profile.getEngine());if(result.getEntriesCount()>=512||bytes+entry.getSerializedSize()>1_048_576){result.setLimited(true);break;}
                result.addEntries(entry);bytes+=entry.getSerializedSize()+8;
            }}}
            String lockAvailability="";
            if(view.profile.getEngine()!=Engine.POSTGRESQL) {
                String locks=view.profile.getEngine()==Engine.MYSQL?"SELECT r.PROCESSLIST_ID,b.PROCESSLIST_ID FROM performance_schema.data_lock_waits w JOIN performance_schema.threads r ON r.THREAD_ID=w.REQUESTING_THREAD_ID JOIN performance_schema.threads b ON b.THREAD_ID=w.BLOCKING_THREAD_ID LIMIT 513":"SELECT r.trx_mysql_thread_id,b.trx_mysql_thread_id FROM information_schema.INNODB_LOCK_WAITS w JOIN information_schema.INNODB_TRX r ON r.trx_id=w.requesting_trx_id JOIN information_schema.INNODB_TRX b ON b.trx_id=w.blocking_trx_id LIMIT 513";
                var relationships=new HashMap<Long,Set<Long>>();int count=0;
                try(var statement=view.connection.createStatement()){statement.setQueryTimeout(5);try(var rows=statement.executeQuery(locks)){while(rows.next()){if(++count>512){lockAvailability=" Blocking relationships limited to 512 edges.";break;}relationships.computeIfAbsent(rows.getLong(1),ignored->new TreeSet<>()).add(rows.getLong(2));}}}
                catch(SQLException denied){lockAvailability=" Blocking relationships unavailable; SQLSTATE "+denied.getSQLState()+". Activity visibility is independent.";}
                for(int i=0;i<result.getEntriesCount();i++){var entry=result.getEntries(i);result.setEntries(i,entry.toBuilder().addAllBlockers(relationships.getOrDefault(entry.getId(),Set.of())));}
            }
            return result.setAvailability(lockAvailability+" Live visible activities; permissions may restrict visibility. Refresh explicitly or poll at most once every five seconds.").build();
        });
    }
    public Activity verify(SessionRegistry.Session view,long id,String expected)throws Exception {
        if(id<1||id>Integer.MAX_VALUE||!expected.matches("[a-f0-9]{64}"))throw new IllegalArgumentException("Choose a displayed live activity and refresh its identity before review");
        try(var statement=view.connection.prepareStatement(sql(view.profile.getEngine())+" AND "+(view.profile.getEngine()==Engine.POSTGRESQL?"pid":view.profile.getEngine()==Engine.MYSQL?"t.PROCESSLIST_ID":"ID")+"=?")) {
            statement.setLong(1,id);statement.setQueryTimeout(5);try(var rows=statement.executeQuery()){if(!rows.next())throw new IllegalStateException("Activity ended or is no longer visible; refresh the list");var actual=row(rows,view.profile.getEngine());if(!actual.getFingerprint().equals(expected))throw new IllegalStateException("Activity identity or current statement changed after inspection; refresh and review again");return actual;}
        }
    }
}
