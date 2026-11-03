package io.busystack.busydata.sessions;

import io.busystack.busydata.adapters.JdbcAdapter;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.security.SshTunnel;
import io.busystack.busydata.security.PrivateTemporaryFiles;
import java.sql.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.locks.ReentrantLock;
import java.util.concurrent.atomic.AtomicBoolean;

public final class SessionRegistry implements AutoCloseable {
    @FunctionalInterface public interface ConnectionOpener {
        Connection open(JdbcAdapter adapter,OpenRequest request,Integer forwardingPort)throws Exception;
    }
    @FunctionalInterface public interface SourceIdentityResolver {
        String resolve(Profile profile)throws Exception;
    }
    /** Failure belongs to an independently owned metadata/control connection. */
    public static final class MetadataFailure extends SQLException {
        public final boolean uncertain;
        MetadataFailure(SQLException cause,boolean uncertain,String catalog){super("Independent catalog/control connection for database "+catalog+" failed (SQLSTATE "+cause.getSQLState()+")",cause.getSQLState(),cause.getErrorCode(),cause);this.uncertain=uncertain;}
    }
    public static final class Session implements AutoCloseable {
        @FunctionalInterface public interface MetadataAction<T>{T run(Session session)throws Exception;}
        private static final Semaphore metadataSlots=new Semaphore(2,true);
        public final String id=UUID.randomUUID().toString();public final Profile profile;public final JdbcAdapter adapter;public final Connection connection;public final ReentrantLock lock=new ReentrantLock(true);
        public final String metadataSourceIdentity;
        public final PrivateTemporaryFiles temporaryFiles;
        private final ConnectionInfo databaseInfo;
        public final io.busystack.busydata.metadata.IdentifierRules.ServerIdentity identifierContext;
        private final ConnectionOpener opener;
        private final AtomicBoolean resourcesClosed=new AtomicBoolean();
        private final java.util.IdentityHashMap<Object,Runnable> physicalEndListeners=new java.util.IdentityHashMap<>();
        public boolean physicalEnded(){return resourcesClosed.get();}
        /** Bounded backend owners may release non-JDBC session state exactly once. */
        public void onPhysicalEnd(Object owner,Runnable listener){
            boolean ended;
            synchronized(physicalEndListeners){ended=resourcesClosed.get();if(!ended&&!physicalEndListeners.containsKey(owner)){if(physicalEndListeners.size()>=8)throw new IllegalStateException("Physical-session listener admission limit reached");physicalEndListeners.put(owner,listener);}}
            if(ended)listener.run();
        }
        private volatile Throwable cleanupFailure;
        public Throwable cleanupFailure(){return cleanupFailure;}
        public synchronized long advanceRevision(){return ++revision;}
        private volatile boolean adopted=true;private ScheduledFuture<?> adoptionExpiry;
        public volatile JdbcAdapter.LiveContext context=new JdbcAdapter.LiveContext("","",List.of(),"");
        public volatile long contextRevision;
        public volatile TransactionState state=TransactionState.IDLE;public volatile boolean autoCommit=true;public volatile long revision;private final char[] password,tlsKeyPassword;private final SshTunnel tunnel;private final Semaphore permits;private Connection cancellation;
        Session(OpenRequest r,Semaphore permits,PrivateTemporaryFiles temporaryFiles,ConnectionOpener opener,io.busystack.busydata.security.SshTrust trust,String metadataSourceIdentity)throws Exception {
            String catalog=r.getCatalog();
            if(catalog.length()>256||catalog.indexOf('\0')>=0)throw new IllegalArgumentException("Invalid requested connection scope");
            this.opener=opener;
            if(metadataSourceIdentity==null||!metadataSourceIdentity.matches("[0-9a-f]{64}"))throw new IllegalArgumentException("Invalid metadata source owner");
            this.metadataSourceIdentity=metadataSourceIdentity;
            this.permits=permits;this.temporaryFiles=temporaryFiles;password=r.getPassword().toCharArray();tlsKeyPassword=r.getTlsKeyPassword().toCharArray();profile=r.getProfile();adapter=new JdbcAdapter(profile.getEngine(),temporaryFiles);
            // A new dedicated PostgreSQL session can choose a database at
            // connection creation. The saved profile and existing sessions keep
            // their identities; initialContext still refuses physical retargeting.
            var opening=profile.getEngine()==Engine.POSTGRESQL&&!catalog.isEmpty()?r.toBuilder().setProfile(profile.toBuilder().setDatabase(catalog)).build():r;
            SshTunnel t=null;Connection opened=null;
            try{t=profile.getSsh().getEnabled()?new SshTunnel(r,trust==null?null:trust.resolve(profile),temporaryFiles):null;opened=opener.open(adapter,opening,t==null?null:t.port());if(profile.getEngine()==Engine.MYSQL)cancellation=opener.open(adapter,r,t==null?null:t.port());connection=opened;adapter.initialContext(opened,r.getCatalog(),r.getSchema());databaseInfo=adapter.info(opened);identifierContext=io.busystack.busydata.metadata.NativeIdentifierCaseReader.identity(adapter,connection);autoCommit=connection.getAutoCommit();state=adapter.transaction(connection);context=adapter.context(connection);contextRevision=1;configureQueryReadDeadline();}catch(Exception e){if(opened!=null)try{opened.close();}catch(Exception cleanup){e.addSuppressed(cleanup);}if(cancellation!=null)try{cancellation.close();}catch(Exception cleanup){e.addSuppressed(cleanup);}if(t!=null)try{t.close();}catch(Exception cleanup){e.addSuppressed(cleanup);}Arrays.fill(password,'\0');Arrays.fill(tlsKeyPassword,'\0');throw e;}
            this.tunnel=t;
        }
        private void configureQueryReadDeadline()throws SQLException {
            // Only the initialized console owns the selected SQL deadline.
            // Setup, metadata views and cancellation connections keep their
            // existing read bound. Allow the five-second cancellation window
            // before an idle physical read can close this console connection.
            int milliseconds=Math.toIntExact(Math.max(300000L,profile.getQueryTimeoutSeconds()*1000L+5000L));
            if(milliseconds>300000)connection.setNetworkTimeout(Runnable::run,milliseconds);
        }
        private Session(Session original,String catalog)throws Exception {
            opener=original.opener;
            var intended=original.context;
            boolean sameDatabase=catalog.equals(intended.catalog());
            permits=metadataSlots;temporaryFiles=original.temporaryFiles;profile=original.profile.toBuilder().setDatabase(catalog).setReadOnly(true).build();adapter=original.adapter;password=new char[0];tlsKeyPassword=new char[0];tunnel=null;
            metadataSourceIdentity=original.metadataSourceIdentity;
            connection=opener.open(adapter,OpenRequest.newBuilder().setProfile(profile).setPassword(original.password()).setTlsKeyPassword(new String(original.tlsKeyPassword)).build(),original.tunnel==null?null:original.tunnel.port());
            databaseInfo=original.databaseInfo;
            try{
                if(sameDatabase)adapter.metadataContext(connection,intended);
                else if(profile.getEngine()!=Engine.POSTGRESQL)adapter.metadataContext(connection,new JdbcAdapter.LiveContext(catalog,catalog,List.of(catalog),"",intended.sqlMode(),intended.standardConformingStrings()));
                context=adapter.context(connection);
                if(!context.catalog().equals(catalog))throw new SQLException("Metadata connection did not acknowledge the requested database","08006");
                identifierContext=io.busystack.busydata.metadata.NativeIdentifierCaseReader.identity(adapter,connection);
                contextRevision=original.contextRevision;
            }
            catch(Exception failure){try{connection.close();}catch(Exception cleanup){failure.addSuppressed(cleanup);}throw failure;}
        }
        public <T> T metadata(MetadataAction<T> action)throws Exception {
            return metadata(context.catalog(),action);
        }
        public boolean isIndependentMetadataView(){return permits==metadataSlots;}
        /** An ephemeral catalog view shares credentials and the owned transport,
         * never the console connection or its transaction. PostgreSQL is opened
         * at the requested database; setCatalog cannot change that boundary. */
        public <T> T metadata(String catalog,MetadataAction<T> action)throws Exception {
            if(catalog.length()>256||catalog.indexOf('\0')>=0)throw new IllegalArgumentException("Invalid metadata database scope");
            if(state==TransactionState.DISCONNECTED||state==TransactionState.UNKNOWN_TRANSACTION)throw new IllegalStateException("Session disconnected or uncertain");
            if(io.grpc.Context.current().isCancelled())throw new CancellationException("Metadata request cancelled");
            if(!metadataSlots.tryAcquire())throw new IllegalStateException("Metadata connection limit reached");
            Session view;
            try{view=new Session(this,catalog);}catch(SQLException e){metadataSlots.release();throw new MetadataFailure(e,e.getSQLState()!=null&&e.getSQLState().startsWith("08"),catalog);}catch(Exception e){metadataSlots.release();throw e;}
            Throwable primary=null;
            try{if(io.grpc.Context.current().isCancelled())throw new CancellationException("Metadata request cancelled");return action.run(view);}
            catch(SQLException failure){
                primary=failure;
                try{view.failure(failure,false);}catch(Exception cleanup){failure.addSuppressed(cleanup);}
                throw new MetadataFailure(failure,view.state==TransactionState.UNKNOWN_TRANSACTION,catalog);
            }
            catch(Exception failure){primary=failure;throw failure;}
            finally{view.close();if(view.cleanupFailure!=null){if(primary!=null)primary.addSuppressed(view.cleanupFailure);else throw new IllegalStateException("Independent catalog/control connection cleanup failed",view.cleanupFailure);}}
        }
        public SessionInfo info(){var current=context;return SessionInfo.newBuilder().setSessionId(id).setProfile(profile).setMetadataSourceIdentity(metadataSourceIdentity).setAutoCommit(autoCommit).setTransaction(state).setDatabase(databaseInfo).setContextRevision(contextRevision).setSessionRevision(revision).setCurrentCatalog(current.catalog()).setCurrentSchema(current.schema()).addAllSearchPath(current.searchPath()).setSqlMode(current.sqlMode()).setStandardConformingStrings(current.standardConformingStrings()).build();}
        /** Immutable execution target; never changes the saved profile. */
        public Profile targetProfile(){return profile.toBuilder().setDatabase(context.catalog()).build();}
        public String password(){return new String(password);}
        public int nativePort(){return tunnel==null?profile.getPort():tunnel.port();}
        public void cancel(Statement executing,java.util.function.BooleanSupplier stillCurrent)throws Exception {
            if(cancellation!=null) {
                long target=connection.unwrap(com.mysql.cj.jdbc.JdbcConnection.class).getSession().getThreadId();
                cancelQuery(cancellation,target,stillCurrent);
            } else if(profile.getEngine()==Engine.MARIADB) {
                // Connector/J's cancel opens a new connection from its stored
                // configuration. Its selected TLS scratch is deliberately gone
                // after the initial handshake; its thread-local SSH forwarding
                // context is also absent on this control worker. Acquire a
                // fresh, bounded owned view with the original transport policy.
                long target=connection.unwrap(org.mariadb.jdbc.Connection.class).getThreadId();
                metadata(view->{cancelQuery(view.connection,target,stillCurrent);return null;});
            } else {
                if(!stillCurrent.getAsBoolean())return;
                executing.cancel();
                // A statement-level cancel can arrive before PostgreSQL starts
                // the command, then suppress further calls in pgJDBC's cancelled
                // statement state. Its connection API sends a fresh native
                // CancelRequest. The job keeps this physical session locked
                // until control finishes; no later statement can be targeted.
                var nativeConnection=connection.unwrap(org.postgresql.PGConnection.class);
                long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(4);
                while(stillCurrent.getAsBoolean()&&System.nanoTime()<deadline) {
                    Thread.sleep(10);
                    if(!stillCurrent.getAsBoolean())return;
                    nativeConnection.cancelQuery();
                }
            }
        }
        private static void cancelQuery(Connection control,long target,java.util.function.BooleanSupplier stillCurrent)throws SQLException {
            if(target<=0)throw new SQLException("Invalid cancellation thread identity","08006");
            long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(4);
            while(stillCurrent.getAsBoolean()&&System.nanoTime()<deadline) {
                boolean running;
                try(var st=control.createStatement()) {
                    st.setQueryTimeout(3);
                    try(var rows=st.executeQuery("SELECT COMMAND FROM information_schema.PROCESSLIST WHERE ID="+target)) {
                        running=rows.next()&&!rows.getString(1).equalsIgnoreCase("Sleep");
                    }
                }
                if(running) {
                    try(var st=control.createStatement()){st.setQueryTimeout(3);st.execute("KILL QUERY "+target);}
                    return;
                }
                try{Thread.sleep(10);}catch(InterruptedException e){Thread.currentThread().interrupt();return;}
            }
        }
        public void refresh()throws SQLException{
            // Uncertainty is sticky, including when an underlying driver still
            // reports a seemingly healthy cached transaction state.
            if(state==TransactionState.UNKNOWN_TRANSACTION||state==TransactionState.DISCONNECTED)return;
            try{autoCommit=connection.getAutoCommit();state=adapter.transaction(connection);
                if(state!=TransactionState.FAILED_TRANSACTION){var current=adapter.context(connection);if(!current.equals(context)){context=current;contextRevision++;}}
            }
            catch(SQLException error){quarantine(error);throw error;}
        }
        public void failure(Throwable failure,boolean rollbackUnconfirmed){
            boolean uncertain=rollbackUnconfirmed;
            for(Throwable current=failure;current!=null;current=current.getCause())
                if(current instanceof SQLException sql&&sql.getSQLState()!=null&&sql.getSQLState().startsWith("08"))uncertain=true;
            try{if(connection.isClosed())uncertain=true;}catch(SQLException error){uncertain=true;failure.addSuppressed(error);}
            if(uncertain)quarantine(failure);
            else try{refresh();}catch(SQLException cleanup){failure.addSuppressed(cleanup);}
        }
        public void quarantine(Throwable primary){state=TransactionState.UNKNOWN_TRANSACTION;releaseResources(primary);}
        public OwnedTransaction ownedTransaction()throws SQLException{return new OwnedTransaction(this);}
        public void validateAfterCancellation()throws SQLException {
            if(profile.getEngine()!=Engine.MYSQL)return;
            // A cursor cancellation may leave a deferred 70100 packet. Consume it
            // with a side-effect-free health probe, never by retrying user SQL.
            for(int attempt=0;attempt<2;attempt++)try(var st=connection.createStatement()){st.setQueryTimeout(2);try(var rows=st.executeQuery("SELECT 1")){if(!rows.next()||rows.getInt(1)!=1)throw new SQLException("Session health probe failed","08006");}return;}
            catch(SQLException e){if(!"70100".equals(e.getSQLState())||attempt==1)throw e;}
        }
        private void releaseResources(Throwable primary){
            if(!resourcesClosed.compareAndSet(false,true))return;
            java.util.List<Runnable> ended;
            synchronized(physicalEndListeners){ended=java.util.List.copyOf(physicalEndListeners.values());physicalEndListeners.clear();}
            for(var listener:ended)try{listener.run();}catch(RuntimeException cleanup){recordCleanup(primary,cleanup);}
            io.busystack.busydata.metadata.PreparedMetadataWitness.endSession(id);
            try{connection.close();}catch(Exception cleanup){recordCleanup(primary,cleanup);}
            try{if(cancellation!=null)cancellation.close();}catch(Exception cleanup){recordCleanup(primary,cleanup);}
            try{if(tunnel!=null)tunnel.close();}catch(Exception cleanup){recordCleanup(primary,cleanup);}
            finally{Arrays.fill(password,'\0');Arrays.fill(tlsKeyPassword,'\0');permits.release();}
        }
        private void recordCleanup(Throwable primary,Exception cleanup){
            if(primary!=null)primary.addSuppressed(cleanup);
            if(cleanupFailure==null)cleanupFailure=cleanup;else cleanupFailure.addSuppressed(cleanup);
        }
        public void close(){releaseResources(null);state=TransactionState.DISCONNECTED;}
    }
    private final Semaphore permits=new Semaphore(8,true);
    // A quarantined console releases its physical permit but retains its
    // uncertain handle until explicit disconnection. Bound that ownership too:
    // closed JDBC drivers can still retain substantial packet buffers.
    private final Semaphore handles=new Semaphore(8,true);
    private final ConcurrentMap<String,Session> sessions=new ConcurrentHashMap<>();
    private final PrivateTemporaryFiles temporaryFiles;
    private final ConnectionOpener opener;
    private final SourceIdentityResolver sourceIdentityResolver;
    private final Object lifecycle=new Object();private boolean closed;
    private final ScheduledExecutorService adoptionTimer=Executors.newSingleThreadScheduledExecutor(Thread.ofPlatform().daemon().name("busydata-session-adoption").factory());
    private final io.busystack.busydata.security.SshTrust trust;
    public SessionRegistry()throws java.io.IOException{this(PrivateTemporaryFiles.isolated());}
    public SessionRegistry(PrivateTemporaryFiles temporaryFiles){this(temporaryFiles,(adapter,request,port)->adapter.connect(request,port));}
    public SessionRegistry(PrivateTemporaryFiles temporaryFiles,ConnectionOpener opener){this(temporaryFiles,opener,null);}
    public SessionRegistry(PrivateTemporaryFiles temporaryFiles,ConnectionOpener opener,io.busystack.busydata.security.SshTrust trust){this(temporaryFiles,opener,trust,io.busystack.busydata.metadata.SourceIdentity::fingerprint);}
    public SessionRegistry(PrivateTemporaryFiles temporaryFiles,ConnectionOpener opener,io.busystack.busydata.security.SshTrust trust,SourceIdentityResolver sourceIdentityResolver){this.temporaryFiles=temporaryFiles;this.opener=opener;this.trust=trust;this.sourceIdentityResolver=Objects.requireNonNull(sourceIdentityResolver);}
    public Session open(OpenRequest r)throws Exception{return open(r,false);}
    public Session openPending(OpenRequest r)throws Exception{return open(r,true);}
    private Session open(OpenRequest r,boolean pending)throws Exception{
        JdbcAdapter.validate(r.getProfile());synchronized(lifecycle){if(closed)throw new IllegalStateException("Backend is shutting down");if(!handles.tryAcquire())throw new IllegalStateException("Session ownership limit (8) reached; explicitly disconnect unused or uncertain consoles before opening another connection");if(!permits.tryAcquire()){handles.release();throw new IllegalStateException("Connection limit (8) reached");}}
        Session opened=null;
        try{opened=new Session(r,permits,temporaryFiles,opener,trust,sourceIdentityResolver.resolve(r.getProfile()));synchronized(lifecycle){if(closed)throw new IllegalStateException("Backend shut down during connection setup");opened.adopted=!pending;sessions.put(opened.id,opened);if(pending){String id=opened.id;opened.adoptionExpiry=adoptionTimer.schedule(()->cancelPending(id),60,TimeUnit.SECONDS);}}return opened;}
        catch(Exception failure){if(opened==null)permits.release();else {synchronized(lifecycle){sessions.remove(opened.id,opened);}opened.releaseResources(failure);opened.state=TransactionState.DISCONNECTED;}handles.release();throw failure;}
    }
    public ConnectionInfo test(OpenRequest r)throws Exception{return test(r,()->false);}
    public ConnectionInfo test(OpenRequest r,java.util.function.BooleanSupplier cancelled)throws Exception {
        if(cancelled.getAsBoolean())throw new java.util.concurrent.CancellationException("Connection test cancelled");
        var s=open(r);
        Throwable primary=null;
        try{if(cancelled.getAsBoolean())throw new java.util.concurrent.CancellationException("Connection test cancelled; unused physical session disposed");return s.adapter.info(s.connection).toBuilder().setHost(s.profile.getHost()).setPort(s.profile.getPort()).setDatabase(s.context.catalog()).setSchema(s.context.schema()).build();}
        catch(Exception failure){primary=failure;throw failure;}
        finally{close(s.id,true);if(s.cleanupFailure()!=null){if(primary!=null)primary.addSuppressed(s.cleanupFailure());else throw new IllegalStateException("Connection test cleanup failed; profile and credentials were not adopted",s.cleanupFailure());}}
    }
    public Session controlSession(String id){var s=sessions.get(id);if(s==null||s.state==TransactionState.DISCONNECTED)throw new IllegalArgumentException("Session is disconnected or stale");return s;}
    public Session get(String id){var s=controlSession(id);if(!s.adopted)throw new IllegalStateException("Adopt the opened session before submitting database work");return s;}
    public SessionInfo adopt(String id){synchronized(lifecycle){var s=controlSession(id);if(closed)throw new IllegalStateException("Backend is shutting down");s.adopted=true;if(s.adoptionExpiry!=null)s.adoptionExpiry.cancel(false);return s.info();}}
    /** RPC cancellation/expiry must never dispose an already acknowledged owner. */
    public void cancelPending(String id){synchronized(lifecycle){var s=sessions.get(id);if(s!=null&&!s.adopted&&sessions.remove(id,s)){try{s.close();}finally{handles.release();}}}}
    public int size(){return sessions.size();}
    public int physicalSessionCount(){return 8-permits.availablePermits();}
    public SessionInfo command(SessionRequest r)throws Exception {
        return command(r,()->{});
    }
    public SessionInfo command(SessionRequest r,Runnable authorize)throws Exception {
        if(r.getAction()==SessionAction.ADOPT_SESSION)return adopt(r.getSessionId());
        var s=controlSession(r.getSessionId());if(!s.adopted&&r.getAction()!=SessionAction.DISCONNECT&&r.getAction()!=SessionAction.SESSION_STATUS)throw new IllegalStateException("Session ownership has not been adopted");
        if(r.getAction()==SessionAction.SESSION_STATUS)return s.info();
        if(!s.lock.tryLock())throw new IllegalStateException("Session is busy; cancel its job before transaction commands");
        boolean boundaryAcknowledged=false;
        try {
            if(r.getAction()!=SessionAction.SESSION_STATUS)authorize.run();
            if(s.state==TransactionState.UNKNOWN_TRANSACTION&&r.getAction()!=SessionAction.SESSION_STATUS&&r.getAction()!=SessionAction.DISCONNECT)throw new IllegalStateException("Unknown transaction outcome: disconnect without replaying SQL");
            switch(r.getAction()) {
                case BEGIN->{if(s.state!=TransactionState.IDLE)throw new IllegalStateException("Transaction already active");s.connection.setAutoCommit(false);try(var st=s.connection.createStatement()){st.execute(s.profile.getEngine()==Engine.POSTGRESQL?"BEGIN":"START TRANSACTION");}}
                case COMMIT->{try(var st=s.connection.createStatement()){st.execute("COMMIT");boundaryAcknowledged=true;}}
                case ROLLBACK->{try(var st=s.connection.createStatement()){st.execute("ROLLBACK");boundaryAcknowledged=true;}}
                case AUTO_COMMIT_ON->{if(s.state!=TransactionState.IDLE)throw new IllegalStateException("Commit or rollback first");s.connection.setAutoCommit(true);}
                case AUTO_COMMIT_OFF->s.connection.setAutoCommit(false);
                case DISCONNECT->{if(!r.getForce()&&s.state!=TransactionState.IDLE)throw new IllegalStateException("Transaction pending: explicitly rollback or confirm disconnect");close(s.id,r.getForce());return s.info().toBuilder().setCommandWarning(s.cleanupFailure()==null?"":"Session disconnected; one or more resource cleanup actions failed. Credentials and connection permits were released; no SQL was replayed.").build();}
                case SESSION_STATUS->{return s.info();}
                default->throw new IllegalArgumentException("Invalid session action");
            }
            s.advanceRevision();s.refresh();return s.info().toBuilder().setCommandAcknowledged(boundaryAcknowledged).setAcknowledgedAction(boundaryAcknowledged?r.getAction():SessionAction.SESSION_STATUS).build();
        }catch(SQLException failure){
            s.advanceRevision();
            s.failure(failure,!boundaryAcknowledged&&r.getAction()==SessionAction.ROLLBACK);
            if(boundaryAcknowledged){s.quarantine(failure);return s.info().toBuilder().setCommandAcknowledged(true).setAcknowledgedAction(r.getAction()).setCommandWarning("Database acknowledged "+r.getAction().name()+"; session cleanup/context refresh failed (SQLSTATE "+Objects.toString(failure.getSQLState(),"unknown")+"). Disconnect; never repeat the transaction command.").build();}
            throw failure;
        }finally{s.lock.unlock();}
    }
    public void close(String id,boolean force){synchronized(lifecycle){var s=sessions.remove(id);if(s!=null){try{if(s.adoptionExpiry!=null)s.adoptionExpiry.cancel(false);s.close();}finally{handles.release();}}}}
    public void close(){
        Throwable cleanup=null;
        synchronized(lifecycle){if(closed)return;closed=true;int retained=sessions.size();for(var s:sessions.values()){s.close();if(s.cleanupFailure()!=null){if(cleanup==null)cleanup=s.cleanupFailure();else cleanup.addSuppressed(s.cleanupFailure());}}sessions.clear();handles.release(retained);adoptionTimer.shutdownNow();}
        try{temporaryFiles.close();}catch(java.io.IOException failure){if(cleanup==null)cleanup=failure;else cleanup.addSuppressed(failure);}
        if(cleanup!=null)throw new IllegalStateException("Session registry resource cleanup failed",cleanup);
    }
}
