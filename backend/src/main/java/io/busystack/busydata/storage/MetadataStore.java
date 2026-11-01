package io.busystack.busydata.storage;

import io.busystack.busydata.protocol.*;
import java.nio.file.*;
import java.nio.channels.*;
import java.sql.*;
import java.util.*;

/** Sole writer. Contains no database passwords, SSH passwords, or private-key material. */
public final class MetadataStore implements AutoCloseable {
    private final Path root;
    private io.busystack.busydata.metadata.MetadataPlatform metadataPlatform;
    private final Connection db;
    private boolean quarantined,closed;
    private final FileChannel leaseChannel;private final FileLock lease;
    public MetadataStore(Path root)throws Exception {this(root,connection->connection);}
    public MetadataStore(Path root,java.util.function.UnaryOperator<Connection> decorator)throws Exception {
        this.root=root.toAbsolutePath().normalize();
        Files.createDirectories(root);
        try{Files.setPosixFilePermissions(root,java.nio.file.attribute.PosixFilePermissions.fromString("rwx------"));}catch(UnsupportedOperationException ignored){}
        leaseChannel=FileChannel.open(root.resolve("metadata.lock"),StandardOpenOption.CREATE,StandardOpenOption.WRITE);
        FileLock acquired;try{acquired=leaseChannel.tryLock();if(acquired==null)throw new IllegalStateException("Metadata writer already exists");}catch(Exception error){leaseChannel.close();throw error;}lease=acquired;
        Connection opened=null;
        try {
        opened=DriverManager.getConnection("jdbc:sqlite:"+root.resolve("metadata.sqlite"));
        try(var s=opened.createStatement()){s.execute("PRAGMA journal_mode=WAL");s.execute("PRAGMA busy_timeout=5000");}
        opened.setAutoCommit(false);
        try(var s=opened.createStatement()) {
            s.execute("CREATE TABLE IF NOT EXISTS migration(version INTEGER PRIMARY KEY)");
            try(var versions=s.executeQuery("SELECT version FROM migration")){while(versions.next())if(versions.getInt(1)!=1&&versions.getInt(1)!=2&&versions.getInt(1)!=3&&versions.getInt(1)!=4)throw new IllegalStateException("Metadata schema is newer or unsupported; preserve the file and use its matching release");}
            s.execute("INSERT OR IGNORE INTO migration VALUES(1)");
            s.execute("CREATE TABLE IF NOT EXISTS profiles(id TEXT PRIMARY KEY, payload BLOB NOT NULL)");
            s.execute("CREATE TABLE IF NOT EXISTS ssh_trust(id TEXT PRIMARY KEY,profile TEXT NOT NULL,host TEXT NOT NULL,port INTEGER NOT NULL,key TEXT NOT NULL)");
            s.execute("CREATE TABLE IF NOT EXISTS history(id TEXT PRIMARY KEY,target TEXT NOT NULL,sql TEXT NOT NULL,state INTEGER,duration INTEGER,started INTEGER)");
            s.execute("CREATE TABLE IF NOT EXISTS preferences(id INTEGER PRIMARY KEY CHECK(id=1),retain_sql INTEGER NOT NULL,days INTEGER NOT NULL)");
            s.execute("INSERT OR IGNORE INTO preferences VALUES(1,0,30)");
            s.execute("CREATE TABLE IF NOT EXISTS operations(id TEXT PRIMARY KEY,execution TEXT NOT NULL,readonly INTEGER NOT NULL)");
            s.execute("DROP TABLE IF EXISTS schema_cache");
            s.execute("CREATE TABLE IF NOT EXISTS metadata_configuration(source TEXT PRIMARY KEY,revision INTEGER NOT NULL,payload TEXT NOT NULL)");
            s.execute("CREATE TABLE IF NOT EXISTS edit_drafts(id TEXT PRIMARY KEY,payload BLOB NOT NULL,state TEXT NOT NULL,created INTEGER NOT NULL)");
            s.execute("UPDATE edit_drafts SET state='UNKNOWN_OUTCOME' WHERE state='APPLYING'");
            s.execute("INSERT OR IGNORE INTO migration VALUES(2)");
            s.execute("UPDATE history SET state=CASE WHEN (SELECT readonly FROM operations WHERE operations.id=history.id)=1 THEN 7 ELSE 8 END WHERE id IN (SELECT id FROM operations)");
            s.execute("DELETE FROM operations");
        }
        UserDataMigration.migrate(opened);
        try(var s=opened.createStatement();var rows=s.executeQuery("SELECT fingerprint,source FROM metadata_source_identity LIMIT 4097")) {
            int count=0;while(rows.next())if(++count>4096||!rows.getString(1).matches("[0-9a-f]{64}")||!rows.getString(2).matches("[0-9a-f]{64}"))throw new IllegalStateException("Metadata source identity bindings are invalid; records preserved");
        }
        opened.commit();opened.setAutoCommit(true);
        db=decorator.apply(opened);
        }catch(Exception error){if(opened!=null){try{if(!opened.getAutoCommit())opened.rollback();}catch(Exception cleanup){error.addSuppressed(cleanup);}try{opened.close();}catch(Exception cleanup){error.addSuppressed(cleanup);}}try{lease.release();leaseChannel.close();}catch(Exception cleanup){error.addSuppressed(cleanup);}throw error;}
    }
    public Path root(){return root;}
    public synchronized io.busystack.busydata.metadata.MetadataPlatform metadataPlatform(){
        if(closed||quarantined)throw new IllegalStateException("Metadata owner is unavailable");
        if(metadataPlatform==null)try{metadataPlatform=new io.busystack.busydata.metadata.MetadataPlatform(this);}catch(Exception failure){throw new IllegalStateException("Central metadata initialization failed",failure);}
        return metadataPlatform;
    }
    public synchronized List<Profile> profiles()throws Exception {
        var out=new ArrayList<Profile>();try(var s=db().createStatement();var r=s.executeQuery("SELECT payload,length(payload) FROM profiles ORDER BY id LIMIT 129")){while(r.next()){if(out.size()>=128||r.getLong(2)>8192)throw new IllegalStateException("Saved profile catalog exceeds the 128-profile / 8KiB per-profile budget; existing records are preserved");out.add(Profile.parseFrom(r.getBytes(1)));}}return out;
    }
    public synchronized void save(Profile p)throws Exception {if(p.getSerializedSize()>8192)throw new IllegalArgumentException("Profile exceeds 8KiB");try(var count=db().prepareStatement("SELECT COUNT(*) FROM profiles WHERE id<>?")){count.setString(1,p.getId());try(var rows=count.executeQuery()){if(rows.next()&&rows.getInt(1)>=128)throw new IllegalStateException("Saved profile limit (128) reached");}}try(var s=db().prepareStatement("INSERT INTO profiles VALUES(?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload")){s.setString(1,p.getId());s.setBytes(2,p.toByteArray());s.executeUpdate();}}
    public synchronized void delete(String id)throws Exception {try(var s=db().prepareStatement("DELETE FROM profiles WHERE id=?")){s.setString(1,id);s.executeUpdate();}}
    /** Called once when acquiring a physical session, never on a semantic read. */
    public synchronized String metadataSourceIdentity(Profile profile)throws SQLException {
        String fingerprint=io.busystack.busydata.metadata.SourceIdentity.fingerprint(profile);
        try(var statement=db().prepareStatement("SELECT source FROM metadata_source_identity WHERE fingerprint=?")) {
            statement.setString(1,fingerprint);try(var rows=statement.executeQuery()){if(rows.next())return rows.getString(1);}
        }
        transaction(()->{
            try(var statement=db().createStatement();var rows=statement.executeQuery("SELECT COUNT(*) FROM metadata_source_identity")){if(rows.next()&&rows.getInt(1)>=4096)throw new IllegalStateException("Metadata source identity limit reached; existing preferences preserved");}
            try(var statement=db().prepareStatement("INSERT INTO metadata_source_identity VALUES(?,?)")){statement.setString(1,fingerprint);statement.setString(2,fingerprint);statement.executeUpdate();}
        });
        return fingerprint;
    }
    public record SshHost(String profile,String host,int port,String key){}
    public synchronized SshHost sshTrust(String id)throws SQLException{
        try(var statement=db().prepareStatement("SELECT profile,host,port,key FROM ssh_trust WHERE id=?")){statement.setString(1,id);try(var rows=statement.executeQuery()){if(!rows.next())throw new IllegalArgumentException("SSH trust binding is unavailable on this machine; review the host key");return new SshHost(rows.getString(1),rows.getString(2),rows.getInt(3),rows.getString(4));}}
    }
    public synchronized String sshTrust(SshHost host)throws SQLException{
        try(var statement=db().createStatement();var count=statement.executeQuery("SELECT COUNT(*) FROM ssh_trust")){if(count.next()&&count.getInt(1)>=512)throw new IllegalStateException("SSH trust record limit reached");}
        String id=UUID.randomUUID().toString();try(var statement=db().prepareStatement("INSERT INTO ssh_trust VALUES(?,?,?,?,?)")){statement.setString(1,id);statement.setString(2,host.profile());statement.setString(3,host.host());statement.setInt(4,host.port());statement.setString(5,host.key());statement.executeUpdate();}return id;
    }
    public synchronized void history(JobInfo job,Profile p,String sql,long started)throws SQLException {
        transaction(()->{
            boolean write=true;String retained=sql;
            try(var existing=db().prepareStatement("SELECT h.sql FROM operations o LEFT JOIN history h ON h.id=o.id WHERE o.id=?")){existing.setString(1,job.getJobId());try(var row=existing.executeQuery()){if(row.next()){retained=row.getString(1);write=retained!=null;}}}
            // Enabling retention during a job cannot retroactively retain its SQL;
            // clearing/deleting active history cannot be undone by job completion.
            if(write)writeHistory(job,p,retained,started);
            try(var delete=db().prepareStatement("DELETE FROM operations WHERE id=?")){delete.setString(1,job.getJobId());delete.executeUpdate();}
        });
        purge();
    }
    public synchronized void started(JobInfo job,Profile profile,String sql,long started,boolean readonly)throws SQLException {
        transaction(()->{writeHistory(job,profile,sql,started);try(var statement=db().prepareStatement("INSERT INTO operations VALUES(?,?,?)")){statement.setString(1,job.getJobId());statement.setString(2,job.getExecutionId());statement.setBoolean(3,readonly);statement.executeUpdate();}});
        purge();
    }
    public synchronized void retarget(String jobId,Profile profile)throws SQLException {
        try(var statement=db().prepareStatement("UPDATE history SET target=? WHERE id=?")){statement.setString(1,target(profile));statement.setString(2,jobId);statement.executeUpdate();}
    }
    private static String target(Profile profile){return profile.getName()+" · "+profile.getEngine()+" · "+profile.getHost()+"/"+profile.getDatabase();}
    @FunctionalInterface private interface SqlAction {void run()throws SQLException;}
    private Connection db()throws SQLException{if(quarantined||closed)throw new SQLException("Metadata writer unavailable; restart without replaying SQL","08006");return db;}
    private void quarantine(Throwable primary){quarantined=true;try{db.close();}catch(SQLException cleanup){primary.addSuppressed(cleanup);}}
    private void transaction(SqlAction action)throws SQLException {
        try{db().setAutoCommit(false);}catch(SQLException failure){quarantine(failure);throw failure;}
        try {action.run();db().commit();}
        catch(SQLException|RuntimeException primary){
            if(primary instanceof SQLException sql&&sql.getSQLState()!=null&&sql.getSQLState().startsWith("08")){quarantine(primary);throw primary;}
            try{db().rollback();}catch(SQLException cleanup){primary.addSuppressed(cleanup);quarantine(primary);throw primary;}
            try{db().setAutoCommit(true);}catch(SQLException cleanup){primary.addSuppressed(cleanup);quarantine(primary);}
            throw primary;
        }
        try{db().setAutoCommit(true);}catch(SQLException cleanup){quarantine(cleanup);throw cleanup;}
    }
    private void writeHistory(JobInfo job,Profile p,String sql,long started)throws SQLException {
        boolean retain=retainSql();
        try(var s=db().prepareStatement("INSERT OR REPLACE INTO history VALUES(?,?,?,?,?,?)")) {
            s.setString(1,job.getJobId());s.setString(2,target(p));s.setString(3,retain?sql:"");s.setInt(4,job.getStateValue());s.setLong(5,job.getDurationMs());s.setLong(6,started);s.executeUpdate();
        }
    }
    public synchronized Map<String,io.busystack.busydata.metadata.MetadataConfiguration> metadataConfigurations()throws SQLException {
        var result=new HashMap<String,io.busystack.busydata.metadata.MetadataConfiguration>();
        try(var statement=db().createStatement();var rows=statement.executeQuery("SELECT source,payload FROM metadata_configuration LIMIT 129")) {
            while(rows.next()){String payload=rows.getString(2);if(result.size()==128||payload.length()>65536)throw new IllegalStateException("Metadata introspection configuration exceeds its budget; existing preferences preserved");result.put(rows.getString(1),new com.google.gson.Gson().fromJson(payload,io.busystack.busydata.metadata.MetadataConfiguration.class));}
        }return Map.copyOf(result);
    }
    public synchronized void metadataConfiguration(String source,io.busystack.busydata.metadata.MetadataConfiguration configuration)throws SQLException {
        String payload=new com.google.gson.Gson().toJson(configuration);if(payload.length()>65536)throw new IllegalArgumentException("Metadata introspection configuration exceeds 64KiB");
        transaction(()->{
            try(var count=db().prepareStatement("SELECT COUNT(*) FROM metadata_configuration WHERE source<>?")){count.setString(1,source);try(var rows=count.executeQuery()){if(rows.next()&&rows.getInt(1)>=128)throw new IllegalStateException("Metadata configuration source limit reached");}}
            try(var statement=db().prepareStatement("INSERT INTO metadata_configuration VALUES(?,?,?) ON CONFLICT(source) DO UPDATE SET revision=excluded.revision,payload=excluded.payload WHERE metadata_configuration.revision=?")) {
                statement.setString(1,source);statement.setLong(2,configuration.revision());statement.setString(3,payload);statement.setLong(4,configuration.revision()-1);if(statement.executeUpdate()!=1)throw new IllegalStateException("Metadata introspection configuration revision changed");
            }
        });
    }
    private boolean retainSql()throws SQLException{try(var s=db().createStatement();var r=s.executeQuery("SELECT retain_sql FROM preferences")){return r.next()&&r.getBoolean(1);}}
    private int days()throws SQLException{try(var s=db().createStatement();var r=s.executeQuery("SELECT days FROM preferences")){return r.next()?r.getInt(1):30;}}
    private void purge()throws SQLException{
        try(var s=db().prepareStatement("DELETE FROM history WHERE started<? AND id NOT IN(SELECT id FROM operations)")){s.setLong(1,System.currentTimeMillis()-days()*86_400_000L);s.executeUpdate();}
        try(var statement=db().createStatement()){
            statement.executeUpdate("DELETE FROM history WHERE id IN (SELECT id FROM (SELECT id,ROW_NUMBER() OVER(ORDER BY started DESC,id DESC) AS n,SUM(length(CAST(sql AS BLOB))+length(CAST(target AS BLOB))+128) OVER(ORDER BY started DESC,id DESC) AS bytes FROM history) WHERE (n>10000 OR bytes>67108864) AND id NOT IN(SELECT id FROM operations))");
        }
    }
    public synchronized HistoryList history(HistoryRequest request)throws SQLException {
        if(request.getSearch().length()>1024||request.getOffset()<0||request.getOffset()>1_000_000||request.getLimit()<0||request.getLimit()>100)throw new IllegalArgumentException("History search/page limit exceeded");
        if(request.getAction()==HistoryAction.UNRECOGNIZED)throw new IllegalArgumentException("Invalid history action");
        if(request.getAction()==HistoryAction.DELETE_HISTORY_ENTRY){if(request.getEntryId().isBlank())throw new IllegalArgumentException("History entry required");try(var statement=db().prepareStatement("DELETE FROM history WHERE id=?")){statement.setString(1,request.getEntryId());statement.executeUpdate();}}
        if(request.getAction()==HistoryAction.CLEAR_HISTORY)try(var s=db().createStatement()){s.executeUpdate("DELETE FROM history");}
        if(request.getAction()==HistoryAction.SET_PRIVACY) {
            if(request.getRetentionDays()<1||request.getRetentionDays()>3650)throw new IllegalArgumentException("Retention must be 1–3650 days");
            try(var s=db().prepareStatement("UPDATE preferences SET retain_sql=?,days=?")){s.setBoolean(1,request.getRetainSql());s.setInt(2,request.getRetentionDays());s.executeUpdate();}
            if(!request.getRetainSql())try(var s=db().createStatement()){s.executeUpdate("UPDATE history SET sql='' ");}
        }
        purge();var out=HistoryList.newBuilder().setRetainSql(retainSql()).setRetentionDays(days());
        int limit=request.getLimit()==0?50:request.getLimit();
        try(var s=db().prepareStatement("SELECT id,target,substr(sql,1,4097),state,duration,started FROM history WHERE sql LIKE ? OR target LIKE ? ORDER BY started DESC,id DESC LIMIT ? OFFSET ?")) {
            s.setString(1,"%"+request.getSearch()+"%");s.setString(2,"%"+request.getSearch()+"%");
            s.setInt(3,limit+1);s.setInt(4,request.getOffset());
            try(var r=s.executeQuery()){while(r.next()){if(out.getEntriesCount()==limit){out.setLimited(true);break;}String text=r.getString(3);boolean truncated=text.codePointCount(0,text.length())>4096;if(truncated)text=text.substring(0,text.offsetByCodePoints(0,4096));out.addEntries(HistoryEntry.newBuilder().setId(r.getString(1)).setTarget(r.getString(2)).setSql(text).setSqlTruncated(truncated).setStateValue(r.getInt(4)).setDurationMs(r.getLong(5)).setStartedUnixMs(r.getLong(6)));}}
            out.setNextOffset(request.getOffset()+out.getEntriesCount());
        }return out.build();
    }
    public synchronized HistorySqlChunk historySql(HistorySqlRequest request)throws SQLException {
        if(request.getEntryId().isBlank()||request.getMaxUnits()<0||request.getMaxUnits()>65_536)throw new IllegalArgumentException("History entry and bounded chunk required");
        try(var statement=db().prepareStatement("SELECT sql FROM history WHERE id=?")){statement.setString(1,request.getEntryId());try(var rows=statement.executeQuery()){if(!rows.next())throw new IllegalArgumentException("History entry no longer available");String text=rows.getString(1);int offset=request.getOffsetUtf16();if(offset<0||offset>text.length()||(offset>0&&offset<text.length()&&Character.isLowSurrogate(text.charAt(offset))))throw new IllegalArgumentException("Invalid UTF-16 offset");int end=Math.min(text.length(),offset+(request.getMaxUnits()==0?65_536:request.getMaxUnits()));if(end<text.length()&&end>offset&&Character.isHighSurrogate(text.charAt(end-1)))end--;if(end==offset&&offset<text.length())throw new IllegalArgumentException("Chunk must fit a Unicode character");return HistorySqlChunk.newBuilder().setText(text.substring(offset,end)).setTotalUnits(text.length()).setNextOffsetUtf16(end).setComplete(end==text.length()).build();}}
    }
    public record EditDraftRecord(String id,StoredEditDraft data,String state,long created){}
    public synchronized List<EditDraftRecord> editDrafts()throws Exception{
        var records=new ArrayList<EditDraftRecord>();int total=0;
        try(var st=db().createStatement();var rows=st.executeQuery("SELECT id,payload,state,created,length(payload) FROM edit_drafts ORDER BY created,id LIMIT 33")){while(rows.next()){if(records.size()>=32||rows.getInt(5)>1048576||(total+=rows.getInt(5))>8388608)throw new IllegalStateException("Edit recovery catalog exceeds its budget; records preserved");records.add(new EditDraftRecord(rows.getString(1),StoredEditDraft.parseFrom(rows.getBytes(2)),rows.getString(3),rows.getLong(4)));}}return List.copyOf(records);
    }
    public synchronized EditDraftRecord editDraft(String id)throws Exception{return editDrafts().stream().filter(record->record.id().equals(id)).findFirst().orElseThrow(()->new IllegalArgumentException("Edit recovery record is unavailable"));}
    public synchronized String saveEditDraft(String id,StoredEditDraft data)throws Exception{
        int size=data.getSerializedSize();if(size>1048576)throw new IllegalArgumentException("Staged edit recovery exceeds 1MiB; stage a smaller batch");
        var records=editDrafts();if(!id.isEmpty()&&!editDraft(id).state().equals("STAGED"))throw new IllegalStateException("Committed or uncertain edits cannot be overwritten/replayed; reconcile the database before discarding their recovery record");
        if(records.stream().filter(record->!record.id().equals(id)).count()>=32||records.stream().filter(record->!record.id().equals(id)).mapToLong(record->record.data().getSerializedSize()).sum()+size>8388608)throw new IllegalStateException("Staged edit recovery budget (32 records / 8MiB) reached");
        String key=id.isEmpty()?UUID.randomUUID().toString():id;
        try(var st=db().prepareStatement("INSERT INTO edit_drafts VALUES(?,?,'STAGED',?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload")){st.setString(1,key);st.setBytes(2,data.toByteArray());st.setLong(3,System.currentTimeMillis());st.executeUpdate();}return key;
    }
    public synchronized void editDraftState(String id,String expected,String state)throws Exception{
        try(var st=db().prepareStatement("UPDATE edit_drafts SET state=? WHERE id=? AND state=?")){st.setString(1,state);st.setString(2,id);st.setString(3,expected);if(st.executeUpdate()!=1)throw new IllegalStateException("Edit recovery outcome changed; refresh without replay");}
    }
    public synchronized void deleteEditDraft(String id)throws Exception{try(var st=db().prepareStatement("DELETE FROM edit_drafts WHERE id=? AND state<>'APPLYING'")){st.setString(1,id);if(st.executeUpdate()!=1)throw new IllegalStateException("An active edit batch cannot be discarded");}}
    public synchronized void close()throws Exception{if(closed)return;closed=true;Exception failure=null;try{db.close();}catch(Exception error){failure=error;}try{lease.release();}catch(Exception error){if(failure==null)failure=error;else failure.addSuppressed(error);}try{leaseChannel.close();}catch(Exception error){if(failure==null)failure=error;else failure.addSuppressed(error);}if(failure!=null)throw failure;}
}
