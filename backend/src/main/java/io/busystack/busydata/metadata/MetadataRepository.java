package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.*;
import java.nio.file.*;
import java.sql.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;
import java.util.concurrent.locks.ReentrantLock;

/** Rebuildable, normalized cache. User profiles/history/recovery live elsewhere. */
public final class MetadataRepository {
    private static final int VERSION=5;
    public static final long MAX_CACHE_BYTES=512L*1024*1024;
    public enum FailureReason { TIMED_OUT,CANCELLED,LIMITED,DENIED,IO,INVALID_CACHE,UNAVAILABLE }
    /** Closed diagnostic vocabulary: never retain SQL, driver prose or values. */
    public record WriteFailure(FailureReason reason,String sqlState,int vendorCode) {
        public WriteFailure {Objects.requireNonNull(reason);if(sqlState==null||!sqlState.matches("[A-Z0-9]{5}"))sqlState="";}
    }
    public enum CommitOutcome { NOT_ATTEMPTED,UNKNOWN,ACKNOWLEDGED }
    public record WriteIdentity(long attemptId,long sourceOwner,String source,String profileId,long snapshotRevision,long configurationRevision,String rulesFingerprint,long deadlineNanos) {
        public boolean matches(MetadataSnapshot value){return source.equals(value.source())&&profileId.equals(value.profileId())&&snapshotRevision==value.revision()&&configurationRevision==value.configurationRevision()&&rulesFingerprint.equals(value.rules().fingerprint());}
    }
    public enum SqlCategory { TIMEOUT,TRANSIENT,NON_TRANSIENT,GENERAL,NON_SQL }
    public record FailureFacts(WriteFailure primary,SqlCategory category,List<WriteFailure> suppressed,boolean factsLimited) {
        public FailureFacts {suppressed=List.copyOf(suppressed);if(suppressed.size()>8)throw new IllegalArgumentException("Cache failure fact bound exceeded");}
        static FailureFacts of(Throwable failure){var facts=new ArrayList<WriteFailure>();var suppressed=failure.getSuppressed();for(int n=0;n<Math.min(8,suppressed.length);n++)facts.add(writeFailure(suppressed[n]));var category=failure instanceof SQLTimeoutException?SqlCategory.TIMEOUT:failure instanceof SQLTransientException?SqlCategory.TRANSIENT:failure instanceof SQLNonTransientException?SqlCategory.NON_TRANSIENT:failure instanceof SQLException?SqlCategory.GENERAL:SqlCategory.NON_SQL;return new FailureFacts(writeFailure(failure),category,facts,suppressed.length>8);}
        FailureFacts add(Throwable failure){var facts=new ArrayList<>(suppressed);boolean limited=factsLimited;if(facts.size()<8)facts.add(writeFailure(failure));else limited=true;return new FailureFacts(primary,category,facts,limited);}
    }
    public record WriteCompletion(WriteIdentity identity,WriteMetrics metrics,FailureFacts failure,boolean transactionBegan,boolean rollbackAttempted,boolean rollbackAcknowledged){}
    @FunctionalInterface interface CompletionListener {void completed(WriteCompletion completion);}
    /** One receipt owns one native terminal operation. A wait timeout never
     * cancels its future, releases its slot or claims that COMMIT rolled back. */
    public static final class WriteReceipt {
        private final WriteIdentity identity;private final CompletableFuture<WriteCompletion> result=new CompletableFuture<>();private final CountDownLatch ready=new CountDownLatch(1);
        private final AtomicBoolean cancelled=new AtomicBoolean();private volatile io.grpc.Context requestContext=io.grpc.Context.current();private volatile Thread worker;private volatile Terminal terminal;private CompletionListener listener;private boolean observed;private WriteCompletion undelivered;
        private WriteReceipt(WriteIdentity identity){this.identity=identity;}
        public WriteIdentity identity(){return identity;}
        public boolean active(){var value=result.getNow(null);return value==null||value.metrics().terminalCloseFailed()||worker!=null&&worker.isAlive();}
        public Optional<WriteCompletion> completed(){return Optional.ofNullable(result.getNow(null));}
        public void cancel(){cancelled.set(true);}
        public boolean cancellationRequested(){return cancelled.get()||requestContext.isCancelled();}
        synchronized void observe(CompletionListener observer){if(observed)throw new IllegalStateException("Cache receipt already observed");observed=true;listener=Objects.requireNonNull(observer);if(undelivered!=null){var value=undelivered;undelivered=null;deliver(value);}else{var value=result.getNow(null);if(value!=null)try{observer.completed(value);}finally{listener=null;}}}
        private synchronized void complete(WriteCompletion value){requestContext=io.grpc.Context.ROOT;if(identity.sourceOwner()!=0&&listener==null){undelivered=value;return;}deliver(value);}
        private void deliver(WriteCompletion value){try{if(listener!=null)listener.completed(value);}finally{listener=null;result.complete(value);}}
        public WriteCompletion awaitCompletion(long deadline)throws SQLException {
            try{var value=result.get(Math.max(0,deadline-System.nanoTime()),TimeUnit.NANOSECONDS);var thread=worker;if(thread!=null&&thread!=Thread.currentThread()&&thread.isAlive()){long remaining=deadline-System.nanoTime();if(remaining>0)thread.join(java.time.Duration.ofNanos(remaining));}return value;}
            catch(TimeoutException timedOut){throw new SQLTimeoutException("Metadata cache completion remains pending; commit outcome may be unknown","57014");}
            catch(InterruptedException interrupted){Thread.currentThread().interrupt();cancel();throw new SQLTransientException("Metadata cache completion wait cancelled","57014");}
            catch(ExecutionException impossible){throw new SQLException("Metadata cache completion is unavailable");}
        }
        public WriteMetrics await(long deadline)throws SQLException {var completion=awaitCompletion(deadline);if(completion.failure()!=null)throw sqlFailure(completion.failure());return completion.metrics();}
        private static SQLException sqlFailure(FailureFacts facts){var failure=facts.primary();return switch(facts.category()){case TIMEOUT->new SQLTimeoutException("Metadata cache attempt timed out",failure.sqlState(),failure.vendorCode());case TRANSIENT->new SQLTransientException("Metadata cache attempt unavailable",failure.sqlState(),failure.vendorCode());case NON_TRANSIENT->new SQLNonTransientException("Metadata cache attempt unavailable",failure.sqlState(),failure.vendorCode());default->new SQLException("Metadata cache attempt unavailable",failure.sqlState(),failure.vendorCode());};}
    }
    /** Exact local cache-call durations, not a deadline guarantee. OPEN_AND_SETUP
     * includes BEGIN/predecessor inspection; DATA_MUTATION ends before COMMIT.
     * Detach, rollback and close include exceptional cleanup. TOTAL includes gaps. */
    public record WriteMetrics(String source,String profileId,long snapshotRevision,long configurationRevision,CommitOutcome commitOutcome,
            boolean deadlineOverrun,boolean terminalCloseFailed,long admissionNanos,long openAndSetupNanos,long dataMutationNanos,
            long commitNanos,long callbackDetachNanos,long connectionCloseNanos,long rollbackNanos,long totalNanos) {
        public boolean matches(MetadataSnapshot value){return source.equals(value.source())&&profileId.equals(value.profileId())&&snapshotRevision==value.revision()&&configurationRevision==value.configurationRevision();}
    }
    /** One synchronous call owns this recorder. It is neither a callback nor a cache. */
    private enum Phase { ADMISSION,OPEN_AND_SETUP,DATA_MUTATION,COMMIT,CALLBACK_DETACH,CONNECTION_CLOSE,ROLLBACK }
    private static final class WriteAttempt {
        final String source,profileId;final long snapshotRevision,configurationRevision,deadline,began=System.nanoTime();final long[] durations=new long[Phase.values().length];
        Phase phase=Phase.ADMISSION;long phaseBegan=began;volatile CommitOutcome outcome=CommitOutcome.NOT_ATTEMPTED;boolean closeFailed;
        WriteAttempt(MetadataSnapshot snapshot,long deadline){source=snapshot.source();profileId=snapshot.profileId();snapshotRevision=snapshot.revision();configurationRevision=snapshot.configurationRevision();this.deadline=deadline;}
        void phase(Phase next){end();phase=next;phaseBegan=System.nanoTime();}
        void end(){if(phase!=null){durations[phase.ordinal()]+=System.nanoTime()-phaseBegan;phase=null;}}
        void commit(Connection db)throws SQLException {phase(Phase.COMMIT);outcome=CommitOutcome.UNKNOWN;try{db.setAutoCommit(true);outcome=CommitOutcome.ACKNOWLEDGED;}finally{end();}}
        WriteMetrics finish(){end();long finished=System.nanoTime();return new WriteMetrics(source,profileId,snapshotRevision,configurationRevision,outcome,finished>=deadline,closeFailed,durations[0],durations[1],durations[2],durations[3],durations[4],durations[5],durations[6],finished-began);}
    }
    private static void closeConnection(Connection db,WriteAttempt attempt)throws SQLException {
        if(attempt!=null)attempt.phase(Phase.CONNECTION_CLOSE);
        try{db.close();}catch(SQLException|RuntimeException|Error failure){if(attempt!=null)attempt.closeFailed=true;throw failure;}finally{if(attempt!=null)attempt.end();}
    }
    private record ConnectionOwner(Connection connection){}
    private static final class Terminal {final ConnectionOwner connection;final WriteBudget budget;final WriteAttempt attempt;final boolean begun;FailureFacts failure;Terminal(ConnectionOwner connection,WriteBudget budget,WriteAttempt attempt,boolean begun,FailureFacts failure){this.connection=connection;this.budget=budget;this.attempt=attempt;this.begun=begun;this.failure=failure;}}
    private static final class CacheLimit extends SQLException {CacheLimit(){super("Metadata cache page budget is unavailable","54000",13);}}
    public static WriteFailure writeFailure(Throwable failure){
        if(failure instanceof CancellationException)return new WriteFailure(FailureReason.CANCELLED,"",0);
        if(!(failure instanceof SQLException sql))return new WriteFailure(FailureReason.UNAVAILABLE,"",0);
        FailureReason reason;
        if(sql instanceof SQLTimeoutException)reason=FailureReason.TIMED_OUT;
        else if(sql instanceof CacheLimit)reason=FailureReason.LIMITED;
        else if("57014".equals(sql.getSQLState())||Thread.currentThread().isInterrupted()||io.grpc.Context.current().isCancelled())reason=FailureReason.CANCELLED;
        else reason=switch(sql.getErrorCode()&255){case 9->FailureReason.CANCELLED;case 7,13,18->FailureReason.LIMITED;case 3,8,23->FailureReason.DENIED;case 10,14->FailureReason.IO;case 11,26->FailureReason.INVALID_CACHE;default->FailureReason.UNAVAILABLE;};
        return new WriteFailure(reason,sql.getSQLState(),sql.getErrorCode());
    }
    private static final String RULE_LENGTH="CASE WHEN typeof(identifier_rules)='blob' THEN length(identifier_rules) ELSE -1 END";
    private static final String RULE_PAYLOAD="CASE WHEN ("+RULE_LENGTH+") BETWEEN 1 AND "+IdentifierRules.MAX_ENCODED_BYTES+" THEN identifier_rules ELSE NULL END";
    private static final class VersionChanged extends SQLException {VersionChanged(){super("Rebuildable metadata cache version changed","",26);}}
    private final Path file;
    @FunctionalInterface interface ConnectionFactory {Connection open(Path file,Properties options)throws SQLException;}
    private final ConnectionFactory connections;private final Object terminalSlot=new Object();private final AtomicLong attemptIds=new AtomicLong();private WriteReceipt activeWrite;
    private final ReentrantLock transaction=new ReentrantLock(true);
    private volatile String cacheState="AVAILABLE";
    public MetadataRepository(Path root)throws Exception {
        this(root,(path,options)->DriverManager.getConnection("jdbc:sqlite:"+path,options));
    }
    MetadataRepository(Path root,ConnectionFactory connections)throws Exception {
        this.connections=Objects.requireNonNull(connections);
        Files.createDirectories(root);file=root.resolve("metadata_catalog.sqlite");
        boolean existed=Files.exists(file)&&Files.size(file)>0;
        for(String suffix:List.of("","-wal","-shm"))if(Files.isSymbolicLink(Path.of(file+suffix)))throw new SecurityException("Metadata cache must not be a symbolic link");
        try{initialize();}
        catch(SQLException failure) {
            if(failure.getErrorCode()!=11&&failure.getErrorCode()!=26&&!(existed&&failure.getErrorCode()==1))throw failure;
            // Only this disposable cache is removed; never the user-data store.
            for(String suffix:List.of("","-wal","-shm"))Files.deleteIfExists(Path.of(file+suffix));
            cacheState=failure instanceof VersionChanged?"REBUILT_VERSION":"REBUILT_CORRUPT";
            initialize();
        }
        try{Files.setPosixFilePermissions(file,java.nio.file.attribute.PosixFilePermissions.fromString("rw-------"));}catch(UnsupportedOperationException ignored){}
    }
    private Connection open()throws SQLException {
        return initializeConnection(connect(false));
    }
    private Connection connect(boolean write)throws SQLException {
        var options=new org.sqlite.SQLiteConfig();if(write)options.setTransactionMode(org.sqlite.SQLiteConfig.TransactionMode.IMMEDIATE);
        return connections.open(file,options.toProperties());
    }
    private static Connection initializeConnection(Connection db)throws SQLException {
        try{return configureConnection(db);}
        catch(SQLException|RuntimeException|Error failure){try{closeConnection(db,null);}catch(SQLException|RuntimeException|Error cleanup){if(cleanup!=failure)failure.addSuppressed(cleanup);}throw failure;}
    }
    private static Connection configureConnection(Connection db)throws SQLException {try(var statement=db.createStatement()){statement.execute("PRAGMA foreign_keys=ON");statement.execute("PRAGMA busy_timeout=5000");return db;}}
    private void initialize()throws SQLException {
        try(var db=open();var s=db.createStatement()) {
            try(var check=s.executeQuery("PRAGMA quick_check(1)")){if(!check.next()||!check.getString(1).equals("ok"))throw new SQLException("Metadata cache is corrupt","",11);}
            s.execute("PRAGMA journal_mode=WAL");int pageSize;try(var size=s.executeQuery("PRAGMA page_size")){if(!size.next())throw new SQLException("Metadata cache page size unavailable");pageSize=size.getInt(1);}s.execute("PRAGMA max_page_count="+(MAX_CACHE_BYTES/pageSize));
            try(var version=s.executeQuery("PRAGMA user_version")){if(version.next()&&version.getInt(1)!=0&&version.getInt(1)!=VERSION)throw new VersionChanged();}
            s.execute("CREATE TABLE IF NOT EXISTS publication(source TEXT PRIMARY KEY,profile TEXT NOT NULL,revision INTEGER NOT NULL,configuration_revision INTEGER NOT NULL,created INTEGER NOT NULL,engine INTEGER NOT NULL,case_rule INTEGER NOT NULL,identifier_rules BLOB NOT NULL)");
            s.execute("CREATE TABLE IF NOT EXISTS object(source TEXT NOT NULL,identity TEXT NOT NULL,catalog TEXT NOT NULL,schema_name TEXT NOT NULL,kind INTEGER NOT NULL,subtype INTEGER NOT NULL,parent TEXT NOT NULL,name TEXT NOT NULL,signature TEXT NOT NULL,native_key TEXT NOT NULL,display_name TEXT NOT NULL,quoted_name TEXT NOT NULL,lookup_key TEXT NOT NULL,source_text TEXT NOT NULL,level INTEGER NOT NULL,state TEXT NOT NULL,source_revision INTEGER NOT NULL,context_revision INTEGER NOT NULL,PRIMARY KEY(source,identity),FOREIGN KEY(source) REFERENCES publication(source) ON DELETE CASCADE)");
            s.execute("CREATE INDEX IF NOT EXISTS object_namespace ON object(source,catalog,schema_name,kind,parent,name)");
            s.execute("CREATE INDEX IF NOT EXISTS object_lookup ON object(source,catalog,schema_name,kind,parent,lookup_key,signature)");
            s.execute("CREATE TABLE IF NOT EXISTS property(source TEXT NOT NULL,identity TEXT NOT NULL,name TEXT NOT NULL,value TEXT NOT NULL,PRIMARY KEY(source,identity,name),FOREIGN KEY(source,identity) REFERENCES object(source,identity) ON DELETE CASCADE) WITHOUT ROWID");
            s.execute("CREATE INDEX IF NOT EXISTS property_lookup ON property(source,name,value,identity)");
            s.execute("CREATE TABLE IF NOT EXISTS coverage(source TEXT NOT NULL,identity TEXT NOT NULL,catalog TEXT NOT NULL,schema_name TEXT NOT NULL,parent TEXT NOT NULL,kind INTEGER NOT NULL,search TEXT NOT NULL,exact_name INTEGER NOT NULL,signature TEXT NOT NULL,subtype INTEGER NOT NULL,level INTEGER NOT NULL,state TEXT NOT NULL,complete INTEGER NOT NULL,fingerprint TEXT NOT NULL,source_revision INTEGER NOT NULL,context_revision INTEGER NOT NULL,refreshed INTEGER NOT NULL,limitation TEXT NOT NULL,default_namespace TEXT NOT NULL,PRIMARY KEY(source,identity),FOREIGN KEY(source) REFERENCES publication(source) ON DELETE CASCADE)");
            try(var check=s.executeQuery("PRAGMA foreign_key_check")){if(check.next())throw new SQLException("Metadata cache relationships failed validation","",11);}
            s.execute("PRAGMA user_version="+VERSION);
        }
    }
    public String cacheState(){synchronized(terminalSlot){if(activeWrite!=null&&activeWrite.completed().isEmpty())return System.nanoTime()>=activeWrite.identity.deadlineNanos()?"WRITE_UNAVAILABLE":"WRITE_PENDING";return cacheState;}}
    public Optional<WriteReceipt> activeReceipt(){synchronized(terminalSlot){return activeWrite==null||!activeWrite.active()?Optional.empty():Optional.of(activeWrite);}}
    private void requireTerminalIdle()throws SQLException {synchronized(terminalSlot){if(activeWrite!=null){if(activeWrite.active())throw new SQLTransientException("Metadata cache terminal operation remains owned","55000");activeWrite=null;}}}
    private WriteReceipt reserve(MetadataSnapshot snapshot,long deadline,long sourceOwner)throws SQLException {
        synchronized(terminalSlot){requireTerminalIdle();long id=attemptIds.incrementAndGet();if(id<=0)throw new SQLException("Metadata cache attempt identity exhausted");
            var receipt=new WriteReceipt(new WriteIdentity(id,sourceOwner,snapshot.source(),snapshot.profileId(),snapshot.revision(),snapshot.configurationRevision(),snapshot.rules().fingerprint(),deadline));
            receipt.worker=Thread.ofPlatform().daemon(true).inheritInheritableThreadLocals(false).name("metadata-cache-terminal").unstarted(()->runTerminal(receipt));activeWrite=receipt;
            try{receipt.worker.start();}catch(RuntimeException|Error unavailable){activeWrite=null;throw unavailable;}return receipt;
        }
    }
    private void handoff(WriteReceipt receipt,Terminal terminal){
        if(terminal.budget!=null){terminal.budget.transferred=true;terminal.budget.receipt=receipt;}
        receipt.terminal=terminal;receipt.ready.countDown();
    }
    private static FailureFacts append(FailureFacts current,Throwable failure){return current==null?FailureFacts.of(failure):current.add(failure);}
    private void runTerminal(WriteReceipt receipt){
        boolean interrupted=false;for(;;)try{receipt.ready.await();break;}catch(InterruptedException cancelled){interrupted=true;receipt.cancel();}
        var terminal=receipt.terminal;var attempt=terminal.attempt;FailureFacts failure=terminal.failure;boolean rollbackAttempted=false,rollbackAcknowledged=false;
        if(failure==null)try{terminal.budget.check();attempt.commit(terminal.connection.connection());}
        catch(SQLException problem){Throwable reported=problem;try{terminal.budget.check();}catch(SQLException stopped){stopped.addSuppressed(problem);reported=stopped;}failure=append(failure,reported);}
        catch(RuntimeException|Error problem){failure=append(failure,problem);}
        if(terminal.budget!=null)try{terminal.budget.closeTerminal();}catch(SQLException|RuntimeException|Error problem){failure=append(failure,problem);}
        if(failure!=null&&terminal.begun&&attempt.outcome!=CommitOutcome.ACKNOWLEDGED){
            rollbackAttempted=true;attempt.phase(Phase.ROLLBACK);try(var rollback=terminal.connection.connection().createStatement()){rollback.execute("ROLLBACK");rollbackAcknowledged=true;}catch(SQLException|RuntimeException|Error problem){failure=append(failure,problem);}finally{attempt.end();}
        }
        if(terminal.connection!=null)try{closeConnection(terminal.connection.connection(),attempt);}catch(SQLException|RuntimeException|Error problem){failure=append(failure,problem);}
        var completion=new WriteCompletion(receipt.identity,attempt.finish(),failure,terminal.begun,rollbackAttempted,rollbackAcknowledged);cacheState=failure==null?"AVAILABLE":"WRITE_UNAVAILABLE";
        try{receipt.complete(completion);}finally{receipt.terminal=null;if(interrupted)Thread.currentThread().interrupt();}
    }
    public List<MetadataSnapshot> load()throws Exception{return load(8,null);}
    public List<MetadataSnapshot> loadNewest()throws Exception{return load(1,null);}
    /** Application restore supplies the committed user policy before exposing
     * cached candidates. No loaded coverage is fresh, even on a matching policy. */
    public List<MetadataSnapshot> load(Map<String,MetadataConfiguration> committedPolicies)throws Exception{return load(8,Map.copyOf(committedPolicies));}
    public List<MetadataSnapshot> loadNewest(Map<String,MetadataConfiguration> committedPolicies)throws Exception{return load(1,Map.copyOf(committedPolicies));}
    private List<MetadataSnapshot> load(int maximumSources,Map<String,MetadataConfiguration> committedPolicies)throws Exception {
        requireTerminalIdle();
        transaction.lock();try{
            requireTerminalIdle();
            try{return read(maximumSources,committedPolicies);}
            catch(SQLException failure){if(failure.getErrorCode()!=11&&failure.getErrorCode()!=26&&failure.getErrorCode()!=1)throw failure;}
            catch(IllegalArgumentException|NullPointerException corrupt){}
            for(String suffix:List.of("","-wal","-shm"))Files.deleteIfExists(Path.of(file+suffix));
            initialize();cacheState="REBUILT_CORRUPT";return List.of();
        }finally{transaction.unlock();}
    }
    private List<MetadataSnapshot> read(int maximumSources,Map<String,MetadataConfiguration> committedPolicies)throws Exception {
        var result=new ArrayList<MetadataSnapshot>();
        long loadedBytes=0;
        try(var db=open();var statement=db.createStatement();var sources=statement.executeQuery("SELECT source,profile,revision,configuration_revision,created,engine,case_rule,"+RULE_PAYLOAD+","+RULE_LENGTH+" FROM publication ORDER BY created DESC LIMIT 9")) {
            while(sources.next()) {
                if(result.size()==maximumSources)break;
                String source=sources.getString(1),profile=sources.getString(2);
                var policy=committedPolicies==null?null:committedPolicies.getOrDefault(source,MetadataConfiguration.defaults());
                boolean changedPolicy=policy!=null&&policy.revision()!=sources.getLong(4);
                long ruleBytes=sources.getLong(9);if(sources.wasNull()||ruleBytes<1||ruleBytes>IdentifierRules.MAX_ENCODED_BYTES)throw new SQLException("Metadata cache identifier evidence budget failed validation","",11);
                var rules=IdentifierRules.decode(Engine.forNumber(sources.getInt(6)),sources.getInt(7),sources.getBytes(8));
                try(var validation=db.prepareStatement("SELECT (SELECT COUNT(*) FROM object WHERE source=?),EXISTS(SELECT 1 FROM property WHERE source=? AND (length(name)>256 OR length(value)>65536)),EXISTS(SELECT 1 FROM object WHERE source=? AND (length(source_text)>65536 OR length(display_name)>8192 OR kind<0 OR kind>11 OR level<1 OR level>3))")) {
                    validation.setString(1,source);validation.setString(2,source);validation.setString(3,source);try(var rows=validation.executeQuery()){if(!rows.next()||rows.getLong(1)>MetadataSnapshot.MAX_OBJECTS||rows.getBoolean(2)||rows.getBoolean(3))throw new SQLException("Metadata cache content failed validation","",11);}
                }
                long estimate;
                try(var admission=db.prepareStatement("SELECT COALESCE((SELECT SUM(1024+4*(length(display_name)+length(quoted_name)+length(lookup_key)+length(source_text)+length(catalog)+length(schema_name)+length(parent)+length(name)+length(signature))) FROM object WHERE source=?),0)+COALESCE((SELECT SUM(128+4*(length(name)+length(value))) FROM property WHERE source=?),0)")) {
                    admission.setString(1,source);admission.setString(2,source);try(var rows=admission.executeQuery()){if(!rows.next())throw new SQLException("Metadata cache resource inspection unavailable");estimate=rows.getLong(1);}
                }
                estimate+=rules.estimatedBytes();
                if(estimate>MetadataSnapshot.MAX_BYTES||loadedBytes+estimate>MetadataPlatform.MAX_TOTAL_BYTES)continue;
                var properties=new HashMap<String,Map<String,String>>();long bytes=0;
                try(var query=db.prepareStatement("SELECT identity,name,value FROM property WHERE source=?")) {
                    query.setString(1,source);try(var rows=query.executeQuery()){while(rows.next()) {
                        String key=rows.getString(1),name=rows.getString(2),value=rows.getString(3);
                        if((bytes+=64L+2L*(name.length()+value.length()))>MetadataSnapshot.MAX_BYTES)throw new SQLException("Metadata cache property budget exceeded","",11);
                        properties.computeIfAbsent(key,k->new HashMap<>()).put(name,value);
                    }}
                }
                var entries=new ArrayList<MetadataObject>();int readObjects=0;
                try(var query=db.prepareStatement("SELECT * FROM object WHERE source=? LIMIT ?")) {
                    query.setString(1,source);query.setInt(2,MetadataSnapshot.MAX_OBJECTS+1);
                    try(var rows=query.executeQuery()){while(rows.next()) {
                        if(++readObjects>MetadataSnapshot.MAX_OBJECTS)throw new SQLException("Metadata cache object budget exceeded","",11);
                        var identity=new MetadataIdentity(source,profile,rows.getString("catalog"),rows.getString("schema_name"),ObjectKind.forNumber(rows.getInt("kind")),ObjectSubtype.forNumber(rows.getInt("subtype")),rows.getString("parent"),rows.getString("name"),rows.getString("signature"),"",rows.getString("native_key"));
                        if(!identity.key().equals(rows.getString("identity")))throw new SQLException("Metadata cache identity failed validation","",11);
                        var attributes=properties.remove(identity.key());
                        var object=new MetadataObject(identity,rows.getString("display_name"),rows.getString("quoted_name"),rows.getString("lookup_key"),attributes==null?Map.of():attributes,rows.getString("source_text"),IntrospectionLevel.of(rows.getInt("level")),MetadataState.valueOf(rows.getString("state")),rows.getLong("source_revision"),rows.getLong("context_revision"));
                        if(object.withRules(rules)!=object)throw new SQLException("Metadata cache identifier normalization failed validation","",11);
                        if(!changedPolicy||permitted(policy,object.identity()))entries.add(object);
                    }}
                }
                var coverage=new HashMap<MetadataScope,MetadataCoverage>();int readScopes=0;
                try(var query=db.prepareStatement("SELECT * FROM coverage WHERE source=? LIMIT 100001")) {
                    query.setString(1,source);try(var rows=query.executeQuery()){while(rows.next()) {
                        if(++readScopes>100_000)throw new SQLException("Metadata cache scope budget exceeded","",11);
                        var scope=new MetadataScope(rows.getString("catalog"),rows.getString("schema_name"),rows.getString("parent"),ObjectKind.forNumber(rows.getInt("kind")),rows.getString("search"),rows.getBoolean("exact_name"),rows.getString("signature"),ObjectSubtype.forNumber(rows.getInt("subtype")));
                        if(changedPolicy&&!permitted(policy,scope))continue;
                        coverage.put(scope,new MetadataCoverage(scope,IntrospectionLevel.of(rows.getInt("level")),MetadataState.STALE,false,rows.getString("fingerprint"),rows.getLong("source_revision"),rows.getLong("context_revision"),rows.getLong("refreshed"),"Backend restarted; reconcile this cached scope before relying on absence",rows.getString("default_namespace")));
                    }}
                }
                var snapshot=new MetadataSnapshot(source,profile,sources.getLong(3),changedPolicy?policy.revision():sources.getLong(4),sources.getLong(5),rules,entries,coverage);
                if(loadedBytes+snapshot.estimatedBytes()>MetadataPlatform.MAX_TOTAL_BYTES)continue;
                result.add(snapshot);loadedBytes+=snapshot.estimatedBytes();
            }
        }
        return List.copyOf(result);
    }
    private static boolean permitted(MetadataConfiguration policy,MetadataIdentity identity){return policy.permits(identity.catalog(),identity.schema(),identity.kind(),identity.parent().isEmpty()?identity.name():identity.parent());}
    private static boolean permitted(MetadataConfiguration policy,MetadataScope scope){return policy.permits(scope.catalog(),scope.schema(),scope.kind(),!scope.parent().isEmpty()?scope.parent():scope.exactName()?scope.search():"");}
    /** Every caller submits to the same owned terminal path and explicitly
     * awaits its receipt when persistence is needed before its next operation. */
    public WriteReceipt publish(MetadataSnapshot snapshot,MetadataSnapshot previous)throws SQLException {return publish(snapshot,previous,System.nanoTime()+TimeUnit.SECONDS.toNanos(30));}
    public WriteReceipt publish(MetadataSnapshot snapshot,MetadataSnapshot previous,long deadline)throws SQLException {return publish(snapshot,previous,deadline,0);}
    WriteReceipt publish(MetadataSnapshot snapshot,MetadataSnapshot previous,long deadline,long sourceOwner)throws SQLException {
        Objects.requireNonNull(snapshot);Objects.requireNonNull(previous);
        if(snapshot.composed()||previous.composed())throw new IllegalArgumentException("Session-owned metadata compositions cannot be persisted");
        if(!snapshot.source().equals(previous.source())||!snapshot.profileId().equals(previous.profileId()))throw new IllegalArgumentException("Metadata cache predecessor belongs to another source");
        var attempt=new WriteAttempt(snapshot,deadline);for(var object:snapshot.identities().values()){check(deadline);if(!object.identity().sessionOwner().isEmpty())throw new IllegalArgumentException("Session metadata cannot be persisted");}
        var receipt=reserve(snapshot,deadline,sourceOwner);ConnectionOwner owned=null;WriteBudget budget=null;boolean locked=false,begun=false;
        FailureFacts failure=null;
        try{
            check(deadline);
            lock(deadline);locked=true;attempt.phase(Phase.OPEN_AND_SETUP);owned=new ConnectionOwner(connect(true));var db=owned.connection();configureConnection(db);
            budget=new WriteBudget(db,deadline,attempt);prepareBudget(db,deadline,budget);
            budget.check();db.setAutoCommit(false);begun=true;
            boolean delta=headerMatches(db,previous,budget);
            // A cache rejected by restore admission has no in-memory predecessor.
            // Fresh acquisition remains authoritative: retain its stored body
            // only after a bounded comparison of every scalar and property.
            boolean retainedObjects=!delta&&MetadataStoredContent.matches(db,snapshot,budget::check);
            attempt.phase(Phase.DATA_MUTATION);
            if(!delta)for(String table:retainedObjects?List.of("coverage"):List.of("property","object","coverage"))try(var clear=db.prepareStatement("DELETE FROM "+table+" WHERE source=?")){budget.check();clear.setString(1,snapshot.source());clear.executeUpdate();}
            var oldObjects=delta?previous.identities():retainedObjects?snapshot.identities():Map.<String,MetadataObject>of();
            var oldCoverage=delta?previous.coverage():Map.<MetadataScope,MetadataCoverage>of();
            var newCoverage=snapshot.coverage();
            try(var s=db.prepareStatement("INSERT INTO publication(source,profile,revision,configuration_revision,created,engine,case_rule,identifier_rules) VALUES(?,?,?,?,?,?,?,?) ON CONFLICT(source) DO UPDATE SET profile=excluded.profile,revision=excluded.revision,configuration_revision=excluded.configuration_revision,created=excluded.created,engine=excluded.engine,case_rule=excluded.case_rule,identifier_rules=excluded.identifier_rules")) {
                budget.check();s.setString(1,snapshot.source());s.setString(2,snapshot.profileId());s.setLong(3,snapshot.revision());s.setLong(4,snapshot.configurationRevision());s.setLong(5,snapshot.createdUnixMs());s.setInt(6,snapshot.rules().engine().getNumber());s.setInt(7,snapshot.rules().lowerCaseTableNames());s.setBytes(8,snapshot.rules().encode());s.executeUpdate();
            }
            try(var remove=db.prepareStatement("DELETE FROM object WHERE source=? AND identity=?")) {
                int pending=0;for(String id:oldObjects.keySet()){budget.check();if(!snapshot.identities().containsKey(id)){remove.setString(1,snapshot.source());remove.setString(2,id);remove.addBatch();if(++pending==256){remove.executeBatch();pending=0;}}}budget.check();remove.executeBatch();
            }
            try(var object=db.prepareStatement("INSERT OR REPLACE INTO object VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)");var property=db.prepareStatement("INSERT INTO property VALUES(?,?,?,?)")) {
                int pending=0;
                for(var o:snapshot.persistenceObjects()) {
                    budget.check();String id=o.identity().key();if(o.equals(oldObjects.get(id)))continue;
                    var i=o.identity();int n=1;object.setString(n++,snapshot.source());object.setString(n++,id);object.setString(n++,i.catalog());object.setString(n++,i.schema());object.setInt(n++,i.kind().getNumber());object.setInt(n++,i.subtype().getNumber());object.setString(n++,i.parent());object.setString(n++,i.name());object.setString(n++,i.signature());object.setString(n++,i.nativeKey());object.setString(n++,o.displayName());object.setString(n++,o.quotedIdentifier());object.setString(n++,o.lookupKey());object.setString(n++,o.source());object.setInt(n++,o.level().number());object.setString(n++,o.state().name());object.setLong(n++,o.sourceRevision());object.setLong(n,o.contextRevision());object.addBatch();
                    if(++pending==256){object.executeBatch();pending=0;}
                }
                budget.check();object.executeBatch();pending=0;
                for(var o:snapshot.persistenceObjects()){
                    budget.check();String id=o.identity().key();if(o.equals(oldObjects.get(id)))continue;
                    for(var p:o.properties().entrySet()){
                        budget.check();property.setString(1,snapshot.source());property.setString(2,id);property.setString(3,p.getKey());property.setString(4,p.getValue());property.addBatch();if(++pending==512){property.executeBatch();pending=0;}
                    }
                }
                budget.check();property.executeBatch();
            }
            try(var remove=db.prepareStatement("DELETE FROM coverage WHERE source=? AND identity=?")){
                int pending=0;for(var scope:oldCoverage.keySet()){budget.check();if(!newCoverage.containsKey(scope)){remove.setString(1,snapshot.source());remove.setString(2,scope.key());remove.addBatch();if(++pending==256){remove.executeBatch();pending=0;}}}budget.check();remove.executeBatch();
            }
            try(var s=db.prepareStatement("INSERT OR REPLACE INTO coverage VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)")) {
                int pending=0;for(var entry:newCoverage.entrySet()) {
                    budget.check();var c=entry.getValue();if(c.equals(oldCoverage.get(entry.getKey())))continue;
                    var scope=c.scope();int n=1;s.setString(n++,snapshot.source());s.setString(n++,scope.key());s.setString(n++,scope.catalog());s.setString(n++,scope.schema());s.setString(n++,scope.parent());s.setInt(n++,scope.kind().getNumber());s.setString(n++,scope.search());s.setBoolean(n++,scope.exactName());s.setString(n++,scope.signature());s.setInt(n++,scope.subtype().getNumber());s.setInt(n++,c.level().number());s.setString(n++,c.state().name());s.setBoolean(n++,c.complete());s.setString(n++,c.fingerprint());s.setLong(n++,c.sourceRevision());s.setLong(n++,c.contextRevision());s.setLong(n++,c.refreshedUnixMs());s.setString(n++,c.limitation());s.setString(n,c.defaultNamespace());s.addBatch();if(++pending==256){s.executeBatch();pending=0;}
                }budget.check();s.executeBatch();
            }
            budget.check();try(var s=db.createStatement()){s.executeUpdate("DELETE FROM publication WHERE source NOT IN (SELECT source FROM publication ORDER BY created DESC LIMIT 8)");}
            budget.check();
        }catch(SQLException|RuntimeException|Error problem){
            Throwable reported=problem;if(problem instanceof SQLException sql)try{check(deadline);}catch(SQLException expired){expired.addSuppressed(sql);reported=expired;}
            failure=FailureFacts.of(reported);
            if(problem instanceof RuntimeException runtime)throw runtime;if(problem instanceof Error error)throw error;
        }finally{
            handoff(receipt,new Terminal(owned,budget,attempt,begun,failure));if(locked)transaction.unlock();
        }
        return receipt;
    }
    private static WriteBudget prepareWriter(Connection db,long deadline)throws SQLException {
        var budget=new WriteBudget(db,deadline,null);
        try{
            prepareBudget(db,deadline,budget);return budget;
        }catch(SQLException|RuntimeException failure){
            try{budget.close();}catch(SQLException cleanup){failure.addSuppressed(cleanup);}
            if(failure instanceof SQLException sql)try{check(deadline);}catch(SQLException expired){expired.addSuppressed(sql);throw expired;}
            throw failure;
        }
    }
    private static void prepareBudget(Connection db,long deadline,WriteBudget budget)throws SQLException {budget.install();budget.check();enforcePageLimit(db,MAX_CACHE_BYTES);budget.check();}
    /** The runtime always supplies MAX_CACHE_BYTES. A smaller bound lets the
     * real SQLite regression exercise FULL without allocating a512MiB fixture. */
    static void enforcePageLimit(Connection db,long maximumBytes)throws SQLException {
        if(maximumBytes<512||maximumBytes>MAX_CACHE_BYTES)throw new IllegalArgumentException("Invalid metadata cache page bound");
        try(var statement=db.createStatement()){
            long pageSize,pageCount;
            try(var rows=statement.executeQuery("PRAGMA page_size")){if(!rows.next())throw new CacheLimit();pageSize=rows.getLong(1);}
            if(pageSize<512||pageSize>65536||(pageSize&(pageSize-1))!=0)throw new CacheLimit();
            long maximumPages=maximumBytes/pageSize;if(maximumPages==0)throw new CacheLimit();
            try(var rows=statement.executeQuery("PRAGMA page_count")){if(!rows.next())throw new CacheLimit();pageCount=rows.getLong(1);}
            // SQLite cannot lower its pager maximum below an existing file's
            // size. Reject that cache without deleting, copying or truncating it.
            if(pageCount>maximumPages)throw new CacheLimit();
            try(var rows=statement.executeQuery("PRAGMA max_page_count="+maximumPages)){
                if(!rows.next()||rows.getLong(1)!=maximumPages)throw new CacheLimit();
            }
            try(var rows=statement.executeQuery("PRAGMA max_page_count")){
                if(!rows.next()||rows.getLong(1)!=maximumPages)throw new CacheLimit();
            }
        }
    }
    private static boolean headerMatches(Connection db,MetadataSnapshot previous,WriteBudget budget)throws SQLException {
        if(previous.revision()==0)return false;
        try(var query=db.prepareStatement("SELECT source,profile,revision,configuration_revision,created,engine,case_rule,"+RULE_LENGTH+","+RULE_PAYLOAD+" FROM publication WHERE source=?")){
            budget.check();query.setString(1,previous.source());try(var rows=query.executeQuery()){
                if(!rows.next())return false;
                long bytes=rows.getLong(8);if(rows.wasNull()||bytes<1||bytes>IdentifierRules.MAX_ENCODED_BYTES)return false;
                boolean same=previous.source().equals(rows.getString(1))&&previous.profileId().equals(rows.getString(2))&&previous.revision()==rows.getLong(3)&&previous.configurationRevision()==rows.getLong(4)&&previous.createdUnixMs()==rows.getLong(5)&&previous.rules().engine().getNumber()==rows.getInt(6)&&previous.rules().lowerCaseTableNames()==rows.getInt(7)&&Arrays.equals(previous.rules().encode(),rows.getBytes(9));
                budget.check();return same&&!rows.next();
            }
        }
    }
    private void lock(long deadline)throws SQLException {
        for(;;){check(deadline);try{if(transaction.tryLock(Math.min(TimeUnit.MILLISECONDS.toNanos(50),Math.max(1,deadline-System.nanoTime())),TimeUnit.NANOSECONDS))return;}catch(InterruptedException interrupted){Thread.currentThread().interrupt();throw new SQLTransientException("Metadata cache write cancelled","57014",interrupted);}}
    }
    private static void check(long deadline)throws SQLException {
        if(Thread.currentThread().isInterrupted()||io.grpc.Context.current().isCancelled())throw new SQLTransientException("Metadata cache write cancelled","57014");
        if(System.nanoTime()>=deadline)throw new SQLTimeoutException("Metadata cache write deadline exceeded","57014");
    }
    /** Public SQLite callbacks bound VM work and busy waits on this private
     * connection. They never interrupt a user's database or another writer. */
    private static final class WriteBudget implements AutoCloseable {
        private final Connection db;private final long deadline;private final io.grpc.Context context=io.grpc.Context.current();private final WriteAttempt attempt;private boolean closed,transferred;private WriteReceipt receipt;
        WriteBudget(Connection db,long deadline,WriteAttempt attempt)throws SQLException {
            this.db=db;this.deadline=deadline;this.attempt=attempt;
        }
        void install()throws SQLException {
            org.sqlite.ProgressHandler.setHandler(db,1000,new org.sqlite.ProgressHandler(){@Override protected int progress(){return stopped()?1:0;}});
            org.sqlite.BusyHandler.setHandler(db,new org.sqlite.BusyHandler(){private long began;@Override protected int callback(int attempts){if(attempts==0)began=System.nanoTime();if(stopped()||System.nanoTime()-began>=TimeUnit.SECONDS.toNanos(5))return 0;try{Thread.sleep(5);}catch(InterruptedException interrupted){Thread.currentThread().interrupt();return 0;}return stopped()?0:1;}});
        }
        private boolean stopped(){return Thread.currentThread().isInterrupted()||context.isCancelled()||receipt!=null&&receipt.cancelled.get()||System.nanoTime()>=deadline;}
        void check()throws SQLException {if(Thread.currentThread().isInterrupted()||context.isCancelled()||receipt!=null&&receipt.cancelled.get())throw new SQLTransientException("Metadata cache write cancelled","57014");if(System.nanoTime()>=deadline)throw new SQLTimeoutException("Metadata cache write deadline exceeded","57014");}
        @Override public void close()throws SQLException {
            if(transferred)return;closeTerminal();
        }
        void closeTerminal()throws SQLException {
            if(closed)return;closed=true;if(attempt!=null)attempt.phase(Phase.CALLBACK_DETACH);
            try{SQLException failure=null;try{org.sqlite.ProgressHandler.clearHandler(db);}catch(SQLException error){failure=error;}try{org.sqlite.BusyHandler.clearHandler(db);}catch(SQLException error){if(failure==null)failure=error;else failure.addSuppressed(error);}if(failure!=null)throw failure;}
            finally{if(attempt!=null)attempt.end();}
        }
    }
}
