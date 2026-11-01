package io.busystack.busydata.metadata;

import io.busystack.busydata.jobs.Jobs;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.rpc.WorkbenchFailure;
import io.busystack.busydata.sessions.SessionRegistry;
import java.math.BigInteger;
import java.sql.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;

/** MariaDB's retained native table-definition observer; it never replays user SQL. */
public final class PreparedMetadataWitness implements AutoCloseable {
    private static final int MAXIMUM=96;
    private static final AtomicInteger admitted=new AtomicInteger();
    private static final ConcurrentMap<String,Set<PreparedMetadataWitness>> owners=new ConcurrentHashMap<>();
    private static final ExecutorService cleanup=new ThreadPoolExecutor(2,2,0,TimeUnit.MILLISECONDS,new ArrayBlockingQueue<>(MAXIMUM),Thread.ofVirtual().name("metadata-witness-close-",0).factory());
    private static final ExecutorService controls=Executors.newVirtualThreadPerTaskExecutor();
    private volatile SessionRegistry.Session owner;
    private volatile PreparedStatement statement;
    private final String sessionId;
    private final String tableIdentity;
    private final AtomicBoolean closing=new AtomicBoolean(),released=new AtomicBoolean();
    private volatile boolean stale;
    private PreparedMetadataWitness(SessionRegistry.Session owner,PreparedStatement statement,String identity){this.owner=owner;this.statement=statement;sessionId=owner.id;tableIdentity=identity;owners.computeIfAbsent(owner.id,ignored->ConcurrentHashMap.newKeySet()).add(this);}
    public static PreparedMetadataWitness capture(SessionRegistry.Session owner,MetadataSnapshot snapshot,String sql,Jobs.Job job)throws Exception {
        if(owner.profile.getEngine()!=Engine.MARIADB)return null;
        if(!owner.lock.isHeldByCurrentThread())throw new IllegalStateException("Native witness requires physical-session ownership");
        var relation=RetainedMetadataProof.sourceTable(snapshot,owner.targetProfile(),owner.id,sql,owner.context);if(relation.isEmpty())return null;
        var identity=relation.get().identity();return prepare(owner,identity.catalog(),identity.schema(),identity.name(),identity.key(),job);
    }
    /** Only the central physically-owned inspector calls this compact entry;
     * native preparation/lifetime is the same implementation as execution. */
    static PreparedMetadataWitness captureInspection(SessionRegistry.Session owner,RetainedMetadataProof proof,Jobs.Job job)throws Exception {
        if(owner.profile.getEngine()!=Engine.MARIADB)return null;
        if(!owner.lock.isHeldByCurrentThread())throw new IllegalStateException("Native witness requires physical-session ownership");
        if(!proof.available()||!proof.capturedStructure()||!proof.sourceKey().equals(owner.metadataSourceIdentity)||proof.estimatedBytes()>ExecutionMetadata.MAX_BYTES)return null;
        return prepare(owner,proof.catalog(),proof.schema(),proof.table(),proof.tableIdentity(),job);
    }
    private static PreparedMetadataWitness prepare(SessionRegistry.Session owner,String catalog,String schema,String table,String identity,Jobs.Job job)throws Exception {
        if(admitted.incrementAndGet()>MAXIMUM){admitted.decrementAndGet();return null;}
        PreparedStatement prepared=null;
        try(var budget=new ReadBudget(owner,job)){
            String query="SELECT 1 FROM "+owner.adapter.table(catalog,schema,table)+" LIMIT 0 /* busydata metadata witness "+UUID.randomUUID()+" */";
            // Pinned Connector/J's public method forces this one statement onto
            // the server, leaving the connection's preparation policy intact.
            var nativeConnection=owner.connection.unwrap(org.mariadb.jdbc.Connection.class);
            prepared=nativeConnection.prepareInternal(query,Statement.NO_GENERATED_KEYS,ResultSet.TYPE_FORWARD_ONLY,ResultSet.CONCUR_READ_ONLY,true);
            prepared.setQueryTimeout(0);prepared.setMaxRows(1);budget.before(prepared);
            if(io.grpc.Context.current().isCancelled())throw new CancellationException("Metadata witness preparation cancelled");
            if(!(prepared instanceof org.mariadb.jdbc.ServerPreparedStatement)||prepared.getMetaData().getColumnCount()!=1)throw new SQLException("Native metadata witness preparation is unavailable");
            // A witness must be fresh, and disposal must close its server ID.
            // Uncache only this nonce-qualified packet; other driver statements
            // and their cache/lifetimes remain owned by their existing callers.
            if(nativeConnection.cachePrepStmts()){var packet=nativeConnection.getContext().getPrepareCacheCmd(query,null);if(packet instanceof org.mariadb.jdbc.message.server.CachedPrepareResultPacket cached)cached.unCache(nativeConnection.getClient());}
            // getMetaData prepares the observer without executing SELECT or
            // opening an idle manual transaction.
        }catch(SQLException unavailable){if(prepared!=null)try{prepared.close();}catch(SQLException close){unavailable.addSuppressed(close);}admitted.decrementAndGet();if(Objects.toString(unavailable.getSQLState(),"").startsWith("08")){owner.failure(unavailable,false);throw unavailable;}return null;}
        catch(Exception failure){if(prepared!=null)try{prepared.close();}catch(SQLException close){failure.addSuppressed(close);}admitted.decrementAndGet();throw failure;}
        finally{if(job!=null)job.statement=null;}
        return new PreparedMetadataWitness(owner,prepared,identity);
    }
    public boolean matches(SessionRegistry.Session session,RetainedMetadataProof proof){return owner==session&&proof.available()&&tableIdentity.equals(proof.tableIdentity())&&available();}
    public boolean matches(String session,RetainedMetadataProof proof){return sessionId.equals(session)&&proof.available()&&tableIdentity.equals(proof.tableIdentity())&&available();}
    public boolean available(){var current=owner;return current!=null&&!stale&&!closing.get()&&current.state!=TransactionState.DISCONNECTED&&current.state!=TransactionState.UNKNOWN_TRANSACTION;}
    public void verify(SessionRegistry.Session session,Jobs.Job job)throws Exception {
        var current=owner;var prepared=statement;
        if(current!=session)throw new WorkbenchFailure(WorkbenchFailure.Reason.INVALID_OWNER);
        if(!current.lock.isHeldByCurrentThread())throw new IllegalStateException("Native witness verification requires physical-session ownership");
        if(!available())throw new WorkbenchFailure(stale?WorkbenchFailure.Reason.STALE:WorkbenchFailure.Reason.INCOMPLETE_METADATA,WorkbenchFailure.Origin.NATIVE_WITNESS);
        if(!current.autoCommit&&current.state==TransactionState.IDLE)throw new WorkbenchFailure(WorkbenchFailure.Reason.INCOMPLETE_METADATA);
        try(var budget=new ReadBudget(current,job)){
            if(job!=null)job.checkCancel();if(io.grpc.Context.current().isCancelled())throw new CancellationException("Metadata witness verification cancelled");
            var before=counter(current.connection,budget);budget.before(prepared);
            try(var rows=prepared.executeQuery()){if(rows.next())throw new SQLException("Native metadata witness returned unexpected rows");}
            var after=counter(current.connection,budget);
            if(!before.equals(after)){stale=true;throw new WorkbenchFailure(WorkbenchFailure.Reason.STALE,WorkbenchFailure.Origin.NATIVE_WITNESS);}
            if(job!=null)job.checkCancel();if(io.grpc.Context.current().isCancelled())throw new CancellationException("Metadata witness verification cancelled");
        }catch(SQLException failed){stale=true;current.failure(failed,false);throw new WorkbenchFailure(current.state==TransactionState.UNKNOWN_TRANSACTION?WorkbenchFailure.Reason.TRANSACTION_UNKNOWN:WorkbenchFailure.Reason.INCOMPLETE_METADATA);}
        finally{if(job!=null)job.statement=null;}
    }
    private static BigInteger counter(Connection connection,ReadBudget budget)throws Exception {
        try(var query=connection.createStatement()){query.setQueryTimeout(0);query.setMaxRows(2);budget.before(query);try(var rows=query.executeQuery("SHOW SESSION STATUS LIKE 'Com_stmt_reprepare'")){
            if(!rows.next()||!rows.getString(1).equalsIgnoreCase("Com_stmt_reprepare"))throw new SQLException("Native reprepare counter is unavailable");String value=rows.getString(2);
            if(value==null||!value.matches("[0-9]{1,20}"))throw new SQLException("Native reprepare counter is malformed");var result=new BigInteger(value);if(rows.next())throw new SQLException("Native reprepare counter is ambiguous");return result;
        }}
    }
    @Override public void close(){if(!closing.compareAndSet(false,true))return;var current=owner;if(current==null)return;if(current.lock.tryLock())try{closeOwned();}finally{current.lock.unlock();}else cleanup.execute(()->{current.lock.lock();try{closeOwned();}finally{current.lock.unlock();}});}
    private void closeOwned(){if(!released.compareAndSet(false,true))return;var current=owner;var prepared=statement;try{if(prepared!=null)prepared.close();}catch(SQLException failure){if(current!=null)current.quarantine(failure);}finally{statement=null;owner=null;var source=owners.get(sessionId);if(source!=null){source.remove(this);if(source.isEmpty())owners.remove(sessionId,source);}admitted.decrementAndGet();}}
    public static int retainedForSession(String session){var source=owners.get(session);return source==null?0:source.size();}
    public static void endSession(String session){var source=owners.get(session);if(source!=null)for(var witness:List.copyOf(source))witness.close();}
    /** Physical reads use a restored socket deadline and the owned cancellation transport. */
    private static final class ReadBudget implements AutoCloseable {
        private final SessionRegistry.Session owner;private final Jobs.Job job;private final int originalTimeout;private final long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(5);
        private final AtomicBoolean active=new AtomicBoolean(true);private final AtomicReference<CompletableFuture<Void>> cancelling=new AtomicReference<>();private volatile Statement statement;
        private final io.grpc.Context context=io.grpc.Context.current();private final io.grpc.Context.CancellationListener listener;
        ReadBudget(SessionRegistry.Session owner,Jobs.Job job)throws SQLException{this.owner=owner;this.job=job;originalTimeout=owner.connection.getNetworkTimeout();listener=ignored->{var future=new CompletableFuture<Void>();if(!cancelling.compareAndSet(null,future))return;controls.execute(()->{var current=statement;if(current==null||!active.get()){future.complete(null);return;}try{owner.cancel(current,()->active.get()&&statement==current);future.complete(null);}catch(Exception failure){try{owner.connection.abort(Runnable::run);}catch(SQLException abort){failure.addSuppressed(abort);}owner.quarantine(failure);future.completeExceptionally(failure);}});};context.addListener(listener,controls);}
        void before(Statement next)throws Exception{if(job!=null)job.checkCancel();if(context.isCancelled())throw new CancellationException("Native metadata read cancelled");long remaining=TimeUnit.NANOSECONDS.toMillis(deadline-System.nanoTime());if(remaining<1)throw new SQLTimeoutException("Native metadata read deadline exceeded","HYT00");int timeout=(int)Math.min(5000,remaining);if(originalTimeout>0)timeout=Math.min(timeout,originalTimeout);owner.connection.setNetworkTimeout(Runnable::run,Math.max(1,timeout));statement=next;if(job!=null)job.statement=next;}
        @Override public void close()throws Exception{active.set(false);context.removeListener(listener);var cancellation=cancelling.get();if(cancellation!=null)try{cancellation.get(6,TimeUnit.SECONDS);}catch(Exception failed){try{owner.connection.abort(Runnable::run);}catch(SQLException abort){failed.addSuppressed(abort);}owner.quarantine(failed);throw failed;}finally{if(job!=null)job.statement=null;}if(!owner.connection.isClosed())owner.connection.setNetworkTimeout(Runnable::run,originalTimeout);}
    }
}
