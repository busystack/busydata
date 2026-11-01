package io.busystack.busydata.jobs;

import io.busystack.busydata.analysis.SqlAnalysis;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.results.*;
import io.busystack.busydata.safety.Safety;
import io.busystack.busydata.sessions.SessionRegistry;
import io.busystack.busydata.storage.MetadataStore;
import java.sql.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;

public final class Jobs implements AutoCloseable {
    @FunctionalInterface public interface Task{void run(Job job)throws Exception;}
    private final io.busystack.busydata.schema.SmartMetadataRefresh metadataRefresh;
    public io.busystack.busydata.schema.SmartMetadataRefresh metadataRefresh(){return metadataRefresh;}
    private void metadataStatement(SessionRegistry.Session session,String sql,Job job){
        // Each acknowledged statement is a real reconciliation boundary.
        // Independent metadata must not wait for a later script statement;
        // reservation/revision guards retire an attempt if execution advances.
        try{metadataRefresh.acknowledged(session,sql);metadataRefresh.settled(session);}catch(RuntimeException unavailable){job.message("Metadata effect is unavailable; refresh metadata explicitly before relying on it");}
    }
    private void metadataSettled(SessionRegistry.Session session,Job job){
        try{metadataRefresh.settled(session);}catch(RuntimeException unavailable){job.message("Metadata reconciliation is unavailable; refresh explicitly");}
    }
    public static final class Job {
        public final String id=UUID.randomUUID().toString();public volatile SessionRegistry.Session session;public final String execution,sourceSessionId;public volatile Profile targetProfile;
        public final AtomicBoolean cancel=new AtomicBoolean();public volatile Statement statement;public volatile Process process;public volatile JobState state=JobState.QUEUED;public volatile long progress;
        public volatile SessionRegistry.Session statementSession;
        public volatile String sourceSql="",documentId="",sourceSchema="";
        private io.busystack.busydata.metadata.ExecutionMetadata statementMetadata;
        private io.busystack.busydata.metadata.MetadataPlatform.ProofFence proofFence;
        private io.busystack.busydata.metadata.MetadataPlatform.ExternalMutation externalLease;
        private final io.busystack.busydata.schema.SmartMetadataRefresh metadataCoordinator;
        private io.busystack.busydata.metadata.RetainedMetadataProof statementProofFailure;
        private io.busystack.busydata.adapters.JdbcAdapter.LiveContext statementContext;
        private io.busystack.busydata.metadata.PreparedMetadataWitness metadataWitness;
        private String witnessSql="";
        public volatile boolean plan;private volatile ToolKind toolKind;
        public synchronized Job operation(ToolKind kind){toolKind=kind;return this;}
        public volatile long committedRows,rejectedRows;
        private AutoCloseable retainedLease;
        public volatile CompletableFuture<Void> cancelFinished=CompletableFuture.completedFuture(null);
        public final CompletableFuture<JobInfo> finished=new CompletableFuture<>();
        private volatile Thread worker;
        private volatile boolean waitingForSession,queueExpired,committing,acknowledged,rollbackUnconfirmed,workStarted;
        private volatile boolean externalMutation;
        private volatile io.busystack.busydata.rpc.WorkbenchFailure.Origin failureOrigin=io.busystack.busydata.rpc.WorkbenchFailure.Origin.UNCLASSIFIED;
        /** Bounded internal diagnostic; the public JobInfo contract is unchanged. */
        public io.busystack.busydata.rpc.WorkbenchFailure.Origin failureOrigin(){return failureOrigin;}
        private final ArrayList<StatementResult> results=new ArrayList<>();private final ArrayList<String> messages=new ArrayList<>();private String error="";private long started=System.currentTimeMillis(),startedNanos=System.nanoTime(),duration;
        Job(SessionRegistry.Session session,Profile profile,String sessionId,String execution,io.busystack.busydata.schema.SmartMetadataRefresh metadataCoordinator){this.metadataCoordinator=metadataCoordinator;this.session=session;this.statementSession=session;this.targetProfile=profile;this.sourceSessionId=sessionId;this.execution=execution;this.sourceSchema=session==null?"":session.context.schema();}
        public synchronized JobInfo info(){var target=Profile.newBuilder().setId(targetProfile.getId()).setName(targetProfile.getName()).setEngine(targetProfile.getEngine()).setHost(targetProfile.getHost()).setPort(targetProfile.getPort()).setDatabase(targetProfile.getDatabase()).setUser(targetProfile.getUser()).setEnvironment(targetProfile.getEnvironment()).setReadOnly(targetProfile.getReadOnly());var info=JobInfo.newBuilder().setJobId(id).setSessionId(sourceSessionId).setExecutionId(execution).setState(state).addAllResults(results.stream().map(result->result.toBuilder().clearColumns().build()).toList()).addAllMessages(messages).setDurationMs(terminal(state)?duration:TimeUnit.NANOSECONDS.toMillis(System.nanoTime()-startedNanos)).setErrorCode(error).setProgressRows(progress).setCommittedRows(committedRows).setRejectedRows(rejectedRows).setTarget(target).setSourceSchema(sourceSchema);if(toolKind!=null)info.setToolKind(toolKind);return info.build();}
        public synchronized void result(StatementResult r){r=r.toBuilder().clearColumns().build();if(r.getSerializedSize()>256)throw new IllegalStateException("Statement summary exceeds its byte budget");for(int i=0;i<results.size();i++)if(results.get(i).getResultId().equals(r.getResultId())&&!r.getResultId().isBlank()){results.set(i,r);return;}if(results.size()>=2000)throw new IllegalStateException("Statement/result association limit (2000) reached; previous outcomes remain available");results.add(r);}
        public synchronized void message(String m){if(messages.size()<100){int end=Math.min(m.length(),512);if(end>0&&end<m.length()&&Character.isHighSurrogate(m.charAt(end-1)))end--;messages.add(m.substring(0,end));}}
        public void checkCancel()throws InterruptedException{if(cancel.get()&&!acknowledged)throw new InterruptedException("Cancelled");}
        public void checkFetchCancel()throws InterruptedException{if(cancel.get())throw new InterruptedException("Fetching cancelled; acknowledged database outcomes remain acknowledged");}
        public synchronized void beginCommit()throws InterruptedException{checkCancel();committing=true;statement=null;}
        public synchronized void commitAcknowledged(){acknowledged=true;committing=false;statement=null;}
        public synchronized void boundaryAcknowledged(){committing=false;statement=null;}
        public void beforeExternalMutation(){
            if(!session.lock.isHeldByCurrentThread())throw new IllegalStateException("Physical session owner required before native mutation");
            if(externalLease!=null)throw new IllegalStateException("Native mutation was already prepared");
            externalLease=metadataCoordinator.externalMutationStarting(session);
            if(session.physicalEnded()||session.state==TransactionState.DISCONNECTED||session.state==TransactionState.UNKNOWN_TRANSACTION)throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.TRANSACTION_UNKNOWN);
        }
        public synchronized void externalMutationStarted(){if(externalLease==null)throw new IllegalStateException("Native mutation was not prepared");externalMutation=true;}
        public void externalMutationAcknowledged(){if(!externalMutation)throw new IllegalStateException("Native mutation was not started");commitAcknowledged();finishExternalMutation(true);}
        private void finishExternalMutation(boolean acknowledged){var lease=externalLease;externalLease=null;if(lease!=null)metadataCoordinator.externalMutationFinished(session,lease,externalMutation,acknowledged);}
    }
    private final ConcurrentMap<String,Job> jobs=new ConcurrentHashMap<>();private final Set<String> executions=ConcurrentHashMap.newKeySet();
    private final ExecutorService workers=Executors.newVirtualThreadPerTaskExecutor(),controls=Executors.newVirtualThreadPerTaskExecutor();private final Semaphore slots=new Semaphore(32,true);
    private final ScheduledExecutorService deadlines=Executors.newSingleThreadScheduledExecutor(Thread.ofPlatform().daemon().name("busydata-sql-deadline").factory());
    private final ResultStore results;private final MetadataStore metadata;private final SqlAnalysis analysis;private final Safety safety;
    private final io.busystack.busydata.metadata.MetadataPlatform metadataPlatform;
    private final long queueWaitMillis;private final AtomicBoolean closed=new AtomicBoolean();
    private final AtomicLong listingRevision=new AtomicLong(1);
    private long admittedSqlBytes;
    public Jobs(ResultStore results,MetadataStore metadata,SqlAnalysis analysis,Safety safety){this(results,metadata,analysis,safety,java.time.Duration.ofSeconds(30));}
    public Jobs(ResultStore results,MetadataStore metadata,SqlAnalysis analysis,Safety safety,java.time.Duration queueWait){this.results=results;this.metadata=metadata;this.analysis=analysis;this.safety=safety;this.metadataPlatform=metadata.metadataPlatform();this.metadataRefresh=new io.busystack.busydata.schema.SmartMetadataRefresh(new io.busystack.busydata.schema.Explorer(metadataPlatform),results);queueWaitMillis=queueWait.toMillis();if(queueWaitMillis<1||queueWaitMillis>300_000)throw new IllegalArgumentException("Queue deadline must be 1ms–5min");}
    public io.busystack.busydata.metadata.MetadataPlatform metadataPlatform(){return metadataPlatform;}
    public Job get(String id){var j=jobs.get(id);if(j==null)throw new IllegalArgumentException("Job is stale or unknown");return j;}
    public List<JobInfo> list(String session){return jobs.values().stream().filter(j->session.isBlank()||j.sourceSessionId.equals(session)).map(Job::info).toList();}
    public synchronized JobList page(JobRequest request){
        if(request.getOffset()<0||request.getOffset()>128||request.getLimit()<0||request.getLimit()>32)throw new IllegalArgumentException("Job catalog page must contain 1–32 summaries");
        long revision=listingRevision.get();if(request.getCatalogRevision()!=0&&request.getCatalogRevision()!=revision)throw new IllegalStateException("Job catalog changed; refresh from its first page");
        var selected=jobs.values().stream().filter(job->request.getSessionId().isBlank()||job.sourceSessionId.equals(request.getSessionId())).sorted(Comparator.comparingLong((Job job)->job.started).thenComparing(job->job.id)).toList();
        int limit=request.getLimit()==0?32:request.getLimit(),index=request.getOffset();var page=JobList.newBuilder().setCatalogRevision(revision);int bytes=64;
        while(index<selected.size()&&page.getJobsCount()<limit){var info=selected.get(index).info();int size=info.getSerializedSize()+8;if(size>524288)throw new IllegalStateException("Job summary exceeds its bounded budget");if(bytes+size>1048576)break;page.addJobs(info);bytes+=size;index++;}
        return page.setNextOffset(index).setComplete(index>=selected.size()).build();
    }
    public Job submit(SessionRegistry.Session s,String execution,String historySql,Task task)throws Exception{return submit(s,s.targetProfile(),s.id,execution,historySql,task,analysis.readOnly(historySql));}
    public Job submitRetainedExport(ResultStore.Result result,String execution,Task task)throws Exception {return submitRetainedExport(result,execution,task,null);}
    public Job submitRetainedExport(ResultStore.Result result,String execution,Task task,AutoCloseable additional)throws Exception {
        AutoCloseable source=null;
        try {
            source=result.lease();final AutoCloseable owned=source;
            AutoCloseable combined=()->{try{owned.close();}finally{if(additional!=null)additional.close();}};
            var job=submit(null,result.targetProfile,result.sourceSessionId,execution,"",task,true,combined);job.sourceSchema=result.sourceSchema;return job;
        } catch(Exception failure) {
            if(source!=null)try{source.close();}catch(Exception cleanup){failure.addSuppressed(cleanup);}
            if(additional!=null)try{additional.close();}catch(Exception cleanup){failure.addSuppressed(cleanup);}throw failure;
        }
    }
    private Job submit(SessionRegistry.Session s,Profile profile,String sessionId,String execution,String historySql,Task task,boolean readOnly)throws Exception{return submit(s,profile,sessionId,execution,historySql,task,readOnly,null);}
    private Job submit(SessionRegistry.Session s,Profile profile,String sessionId,String execution,String historySql,Task task,boolean readOnly,AutoCloseable lease)throws Exception {
        return submit(s,profile,sessionId,execution,historySql,task,readOnly,lease,historySql.length()*2L);
    }
    private synchronized Job submit(SessionRegistry.Session s,Profile profile,String sessionId,String execution,String historySql,Task task,boolean readOnly,AutoCloseable lease,long sqlBytes)throws Exception {
        if(closed.get())throw new IllegalStateException("Backend is shutting down");
        if(execution.isBlank()||execution.length()>128)throw new IllegalArgumentException("Execution identifier required");
        if(executions.contains(execution))throw new IllegalArgumentException("DUPLICATE_EXECUTION");
        if(executions.size()>=100_000)throw new IllegalStateException("Execution ledger limit reached; disconnect and restart without replay");
        if(jobs.size()>=128){jobs.values().stream().filter(j->terminal(j.state)).min(Comparator.comparingLong(j->j.started)).ifPresent(j->{jobs.remove(j.id);listingRevision.incrementAndGet();});}
        if(jobs.size()>=128||!slots.tryAcquire())throw new IllegalStateException("Job limit reached");
        if(sqlBytes>16_000_000||admittedSqlBytes+sqlBytes>33_554_432){slots.release();throw new IllegalStateException("Active/queued SQL text budget reached; wait or cancel work before submitting another document");}
        admittedSqlBytes+=sqlBytes;
        Job job=new Job(s,profile,sessionId,execution,metadataRefresh);job.retainedLease=lease;executions.add(execution);jobs.put(job.id,job);listingRevision.incrementAndGet();
        try{metadata.started(job.info(),profile,historySql,job.started,readOnly);}catch(Exception error){admittedSqlBytes-=sqlBytes;slots.release();jobs.remove(job.id);listingRevision.incrementAndGet();throw error;}
        var queueDeadline=deadlines.schedule(()->{synchronized(job){if(job.state==JobState.QUEUED||job.waitingForSession){job.queueExpired=true;job.message("Queue-wait deadline exceeded before execution; no SQL was submitted");cancel(job.id);}}},queueWaitMillis,TimeUnit.MILLISECONDS);
        workers.submit(()->{
            JobState outcome=JobState.COMPLETED;
            boolean locked=false;
            try {
                synchronized(job){job.worker=Thread.currentThread();job.waitingForSession=s!=null;job.checkCancel();}
                if(s!=null){s.lock.lockInterruptibly();locked=true;}
                synchronized(job){job.waitingForSession=false;job.checkCancel();job.state=JobState.EXECUTING;}
                queueDeadline.cancel(false);
                if(s!=null&&(s.state==TransactionState.UNKNOWN_TRANSACTION||s.state==TransactionState.DISCONNECTED))throw new IllegalStateException("Disconnect this uncertain session; SQL is never replayed");
                // Queued context changes become authoritative only after this
                // job acquires the physical session. Update existing history,
                // preserving concurrent deletion and SQL-retention choices.
                if(s!=null){job.targetProfile=s.targetProfile();job.sourceSchema=s.context.schema();metadata.retarget(job.id,job.targetProfile);}
                job.workStarted=true;task.run(job);job.checkCancel();
            } catch(InterruptedException e){
                if(job.acknowledged)outcome=JobState.COMPLETED;
                else if(job.externalMutation)outcome=JobState.UNKNOWN_OUTCOME;
                else if(job.workStarted&&s!=null&&s.state==TransactionState.UNKNOWN_TRANSACTION)outcome=readOnly?JobState.INTERRUPTED:JobState.UNKNOWN_OUTCOME;
                else outcome=job.queueExpired?JobState.FAILED:JobState.CANCELLED;
                if(job.queueExpired)job.error="QUEUE_WAIT_TIMEOUT";
            }
            catch(SQLException e){
                String state=e.getSQLState()==null?"":e.getSQLState();job.error="SQLSTATE_"+state;
                if(s!=null&&!(e instanceof SessionRegistry.MetadataFailure))s.failure(e,job.rollbackUnconfirmed);
                if(job.acknowledged){outcome=JobState.COMPLETED;job.message("Database execution was acknowledged; result delivery or physical-session cleanup failed. Inspect retained-result completeness; SQL is not replayed.");}
                else if(s!=null&&s.state==TransactionState.UNKNOWN_TRANSACTION){outcome=readOnly?JobState.INTERRUPTED:JobState.UNKNOWN_OUTCOME;}
                else outcome=job.cancel.get()?JobState.CANCELLED:JobState.FAILED;
                job.message("Database operation failed ("+state+"). Server message omitted because it may contain SQL or credentials.");
            } catch(Exception e){job.error=e instanceof io.busystack.busydata.rpc.WorkbenchFailure failure?failure.reason().wire():e instanceof io.busystack.busydata.transfers.NativeToolFailure nativeFailure?nativeFailure.errorCode():e instanceof java.io.IOException fileFailure?io.busystack.busydata.storage.IoFailure.code(fileFailure):"OPERATION_FAILED";
                if(e instanceof io.busystack.busydata.rpc.WorkbenchFailure failure)job.failureOrigin=failure.origin();
                if(e instanceof io.busystack.busydata.transfers.OutputCommit.RecoveryRequired recovery){
                    job.message(recovery.published?"Output was published; completion or recovery cleanup remains unresolved. Do not rerun the export, backup or SQL automatically.":"Output was not published; restoration or staging cleanup remains unresolved.");
                    if(recovery.recovery!=null)job.message("Recovery location: "+recovery.recovery+". Verify its entry before explicit recovery.");
                    if(recovery.partial!=null)job.message("Staging location (cleanup attempted separately): "+recovery.partial);
                    job.message("Filesystem finalization: "+recovery.reason);
                    if(recovery.getCause() instanceof java.io.IOException reason)job.message("Output failure: "+io.busystack.busydata.storage.IoFailure.code(reason));
                    for(var reason:recovery.getSuppressed())if(reason instanceof java.io.IOException fileReason&&!(reason instanceof io.busystack.busydata.transfers.OutputCommit.RecoveryRequired))job.message("Restoration/cleanup failure: "+io.busystack.busydata.storage.IoFailure.code(fileReason)+" ("+fileReason.getMessage()+")");
                }
                if(job.acknowledged)outcome=JobState.COMPLETED;
                else if(job.externalMutation){outcome=JobState.UNKNOWN_OUTCOME;job.message("Native restore did not acknowledge completion; some statements may have committed. SQL is never replayed.");}
                else if(job.workStarted&&s!=null&&s.state==TransactionState.UNKNOWN_TRANSACTION)outcome=readOnly?JobState.INTERRUPTED:JobState.UNKNOWN_OUTCOME;
                else if(e instanceof io.busystack.busydata.transfers.OutputCommit.RecoveryRequired)outcome=JobState.FAILED;
                else outcome=job.cancel.get()?JobState.CANCELLED:JobState.FAILED;
                job.message("Operation failed; retained rows and staged changes remain available.");
                for(var cleanup:e.getSuppressed()){
                    if(cleanup instanceof io.busystack.busydata.transfers.OutputCommit.RecoveryRequired staging){
                        job.message("Output staging cleanup unresolved at "+staging.partial+": "+staging.reason+". Primary failure retained; review ownership before cleanup.");
                    } else job.message(cleanup instanceof SQLException sql?"Cleanup failed: SQLSTATE "+sql.getSQLState()+"; session reuse is prohibited":"Cleanup failed; primary failure retained");
                }}
            catch(VirtualMachineError e){job.error="BACKEND_RESOURCE_FAILURE";if(s!=null)s.quarantine(e);outcome=readOnly?JobState.INTERRUPTED:JobState.UNKNOWN_OUTCOME;}
            finally {
                queueDeadline.cancel(false);
                job.statement=null;
                if(locked){try{job.finishExternalMutation(false);}catch(RuntimeException unavailable){job.message("Native source metadata remains unavailable; refresh explicitly without replay");}
                s.advanceRevision();
                // Release an unused observer while this job still owns the
                // physical session. Deferred close must not race the next
                // interactive request after this job reports completion.
                if(job.metadataWitness!=null){job.metadataWitness.close();job.metadataWitness=null;}
                try{job.cancelFinished.get(6,TimeUnit.SECONDS);}catch(Exception e){s.quarantine(e);job.message("Cancellation control did not finish; disconnect this uncertain physical session before further SQL");}
                try{if(job.cancel.get()&&s.state!=TransactionState.UNKNOWN_TRANSACTION)s.validateAfterCancellation();}catch(SQLException e){s.quarantine(e);job.message("Cancelled session could not be validated (SQLSTATE "+e.getSQLState()+"); disconnect before further SQL");}
                try{s.refresh();}catch(SQLException e){s.quarantine(e);if(job.error.isBlank())job.error="SQLSTATE_"+Objects.toString(e.getSQLState(),"unknown");job.message("Physical-session cleanup/context status could not be confirmed (SQLSTATE "+Objects.toString(e.getSQLState(),"unknown")+"); disconnect without replaying SQL. Acknowledged outcomes remain acknowledged.");}
                // Cleanup can discover uncertainty after the catch block chose
                // CANCELLED/FAILED. Never leave that definite outcome attached
                // to an unacknowledged operation on a quarantined connection.
                if(!job.acknowledged&&job.workStarted&&outcome!=JobState.COMPLETED&&s.state==TransactionState.UNKNOWN_TRANSACTION)outcome=readOnly?JobState.INTERRUPTED:JobState.UNKNOWN_OUTCOME;
                try{metadataSettled(s,job);}finally{s.lock.unlock();}}
                var retainedLease=job.retainedLease;job.retainedLease=null;
                if(retainedLease!=null)try{retainedLease.close();}catch(Exception cleanup){job.message("Retained result cleanup failed; retry explicit disposal to recover quota");}
                slots.release();
                // A bounded immutable summary must not keep a closed physical
                // connection (and the driver's packet buffers), metadata view,
                // process or released result lease alive. Retained data has its
                // own catalog/leases and immutable source identifiers.
                synchronized(job){job.waitingForSession=false;job.worker=null;job.session=null;job.statementSession=null;job.process=null;job.duration=TimeUnit.NANOSECONDS.toMillis(System.nanoTime()-job.startedNanos);job.state=outcome;}
                results.finishJob(job.id,outcome);
                try{metadata.history(job.info(),job.targetProfile,historySql,job.started);}catch(Exception e){job.message("History could not be saved");}
                if(job.metadataWitness!=null){job.metadataWitness.close();job.metadataWitness=null;}job.sourceSql="";job.statementMetadata=null;job.statementProofFailure=null;job.statementContext=null;job.proofFence=null;
                synchronized(Jobs.this){admittedSqlBytes-=sqlBytes;}
                job.finished.complete(job.info());
            }
        });return job;
    }
    public Job execute(SessionRegistry.Session session,ExecuteRequest r)throws Exception {
        if(r.getRowLimit()<0||r.getRowLimit()>1_000_000)throw new IllegalArgumentException("Row limit exceeds 1,000,000");
        if(r.getSql().isBlank())throw new IllegalArgumentException("No executable statement");
        // Review is validated after waiting for session ownership, so queued intervening work invalidates it.
        String historySql=r.getMode()==ExecutionMode.CURRENT_STATEMENT
            ?analysis.execution(r,session.profile.getEngine(),session.context.lexical()).getFirst().text():r.getSql();
        // The queued closure still owns the full captured request. Charge it,
        // plus the separate selected text, even though only that text belongs
        // in history and transaction-outcome classification.
        long sqlBytes=r.getSql().length()*2L+(historySql==r.getSql()?0:historySql.length()*2L);
        return submitSql(session,r.getExecutionId(),historySql,sqlBytes,false,job->{
            job.documentId=r.getDocumentId();
            safety.authorize(r,session);
            var selected=new ArrayList<>(analysis.execution(r,session.profile.getEngine(),session.context.lexical()));
            boolean ownedRead=r.getStreamingRead()&&session.connection.getAutoCommit()&&session.state==TransactionState.IDLE;
            if(r.getStreamingRead()&&session.profile.getEngine()==Engine.POSTGRESQL&&session.connection.getAutoCommit()&&!ownedRead)throw new IllegalArgumentException("Streaming cannot take ownership of a direct-SQL transaction; disable JDBC auto-commit explicitly or use ordinary bounded execution");
            if(ownedRead&&(selected.size()!=1||!Set.of("SELECT","WITH").contains(analysis.leadingKeyword(selected.getFirst().text()))))throw new IllegalArgumentException("Streaming read requires one reviewed SELECT or WITH query");
            try(var transaction=ownedRead?session.ownedTransaction():null) {
                if(ownedRead){try(var st=session.connection.createStatement()){st.setQueryTimeout(5);st.execute("SET TRANSACTION READ ONLY");}job.message("Dedicated read transaction owned by this job; the execution deadline includes fetching.");}
                else if(session.profile.getEngine()==Engine.POSTGRESQL&&session.connection.getAutoCommit())job.message("PostgreSQL auto-commit uses bounded row count, not cursor streaming. Choose streaming read for large SELECTs.");
                int index=0;SQLException scriptFailure=null;
                while(index<selected.size()) {
                    if(index>=1000)throw new IllegalArgumentException("Script exceeds 1000 statements");
                    var fragment=selected.get(index);var lexical=session.context.lexical();
                    job.sourceSql=fragment.text();
                    job.checkCancel();job.state=JobState.EXECUTING;
                    String leading=analysis.leadingKeyword(fragment.text());job.plan=leading.equals("EXPLAIN");
                    boolean commit=Set.of("COMMIT","END").contains(leading);
                    boolean ordinaryAutoCommit=session.connection.getAutoCommit()&&session.state==TransactionState.IDLE&&!ownedRead;
                    boolean finalStatement=index==selected.size()-1;
                    job.rollbackUnconfirmed=leading.equals("ROLLBACK");
                    if(commit)job.beginCommit();
                    prepareExecutionMetadata(job,session,fragment.text());
                    try(var statement=session.adapter.rawStatement(session.connection,r.getStreamingRead(),session.profile.getQueryTimeoutSeconds(),r.getRowLimit()==0?10_000:r.getRowLimit())) {
                        job.statement=statement;job.checkCancel();boolean isResult=statement.execute(fragment.text());
                        job.rollbackUnconfirmed=false;
                        if(commit){if(index==selected.size()-1)job.commitAcknowledged();else job.committing=false;}
                        // An ordinary auto-commit write is durable when its final
                        // statement response is acknowledged. A late cancellation
                        // cannot turn that acknowledged outcome into cancellation.
                        if(finalStatement&&session.adapter.transaction(session.connection)==TransactionState.IDLE
                            &&((ordinaryAutoCommit&&session.profile.getEngine()==Engine.POSTGRESQL)||!isResult&&Set.of("INSERT","UPDATE","DELETE","MERGE","TRUNCATE","ALTER","CREATE","DROP","GRANT","REVOKE","ROLLBACK","CALL","DO").contains(leading)))job.commitAcknowledged();
                        while(true) {
                            if(isResult)try(var rs=statement.getResultSet()){fetch(job,rs,index,r.getRowLimit()==0?10_000:r.getRowLimit());}
                            else {long count=statement.getLargeUpdateCount();if(count==-1)break;job.result(StatementResult.newBuilder().setStatementIndex(index).setUpdateCount(count).setComplete(true).build());}
                            isResult=statement.getMoreResults(Statement.CLOSE_CURRENT_RESULT);job.checkCancel();
                        }
                        if(finalStatement&&ordinaryAutoCommit&&session.adapter.transaction(session.connection)==TransactionState.IDLE)job.commitAcknowledged();
                        for(var warning=statement.getWarnings();warning!=null;warning=warning.getNextWarning())job.message("Database warning: "+warning.getSQLState());
                        synchronized(job){job.statement=null;}
                        session.refresh();
                        // A script can acknowledge DDL/context changes and then
                        // block in another statement. Invalidate catalog-bound
                        // analysis now, rather than only at whole-job cleanup.
                        session.advanceRevision();
                        metadataStatement(session,fragment.text(),job);
                        if(r.getMode()!=ExecutionMode.CURRENT_STATEMENT&&!lexical.equals(session.context.lexical())){
                            selected.subList(index+1,selected.size()).clear();int offset=fragment.nextOffset();
                            for(var next:analysis.split(r.getSql().substring(offset),session.profile.getEngine(),session.context.lexical(),fragment.delimiter()))selected.add(next.shifted(offset));
                        }
                    } catch(SQLException e){if(r.getErrorPolicy()==ErrorPolicy.STOP_ON_ERROR)throw e;scriptFailure=e;job.message("Statement "+(index+1)+" failed: SQLSTATE "+e.getSQLState());if(session.profile.getEngine()==Engine.POSTGRESQL&&session.adapter.transaction(session.connection)==TransactionState.FAILED_TRANSACTION)throw e;}
                    finally{job.statement=null;}
                    index++;
                }
                if(scriptFailure!=null)throw scriptFailure;
            }
        });
    }
    public Job submitSql(SessionRegistry.Session session,String execution,String sql,Task task)throws Exception {
        return submitSql(session,execution,sql,sql.length()*2L,true,task);
    }
    private Job submitSql(SessionRegistry.Session session,String execution,String sql,long sqlBytes,boolean prepareMetadata,Task task)throws Exception {
        return submit(session,session.targetProfile(),session.id,execution,sql,job->{
            job.sourceSql=sql;
            if(prepareMetadata)prepareExecutionMetadata(job,session,sql);
            int seconds=session.profile.getQueryTimeoutSeconds()==0?60:session.profile.getQueryTimeoutSeconds();
            var deadline=deadlines.schedule(()->{job.message("Execution deadline exceeded, including result fetching. Cancellation does not undo statements already committed.");cancel(job.id);},seconds,TimeUnit.SECONDS);
            try{task.run(job);}finally{deadline.cancel(false);}
        },analysis.readOnly(sql),null,sqlBytes);
    }
    public void fetch(Job job,ResultSet rs,int index,long limit)throws Exception {
        var columns=Values.columns(rs.getMetaData());var target=job.session==null?job.targetProfile:job.session.targetProfile();
        var proof=job.statementProofFailure!=null?job.statementProofFailure:job.statementMetadata==null?io.busystack.busydata.metadata.RetainedMetadataProof.unavailable("UNAVAILABLE: execution metadata was not captured"):job.statementMetadata.proof(columns);
        if(proof.available()&&target.getEngine()==Engine.MARIADB&&(job.metadataWitness==null||!job.metadataWitness.matches(job.session,proof)))proof=io.busystack.busydata.metadata.RetainedMetadataProof.unavailable("Native execution metadata witness was unavailable before SQL execution");
        var retained=results.create(columns,target,job.sourceSessionId);
        try(var prepared=results.prepareProof(retained,proof)){
            if(job.session==null)prepared.complete(prepared.proof());
            else metadataPlatform.publishRetainedProof(job.session,job.proofFence,prepared);
        }
        job.state=JobState.FETCHING;
        if(job.metadataWitness!=null&&retained.attachMetadataWitness(job.metadataWitness)){job.metadataWitness=null;job.witnessSql="";}
        retained.jobId=job.id;retained.executionId=job.execution;retained.documentId=job.documentId;retained.statementIndex=index;
        retained.plan=job.plan;retained.sourceSchema=job.session==null?job.sourceSchema:job.session.context.schema();
        retained.sourceSql=job.sourceSql.length()<=65_536?job.sourceSql:"";
        if(job.session!=null)retained.sourceLexical=job.session.context.lexical();
        job.result(summary(retained,index));
        try {
            retained.captureSql(job.sourceSql);
            while(rs.next()){job.checkFetchCancel();if(retained.rows()>=limit){retained.limited=true;break;}retained.append(Values.row(rs,retained.columns,retained));job.progress++;if(retained.rows()%256==0)job.result(summary(retained,index));}
            if(retained.rows()>=limit)retained.limited=true;retained.complete=!retained.limited;
        }finally{retained.fetchFinished=true;job.result(summary(retained,index));}
    }
    private void prepareExecutionMetadata(Job job,SessionRegistry.Session session,String sql)throws Exception {
        job.statementProofFailure=null;job.statementMetadata=null;job.checkCancel();metadataRefresh.beforeExecution(session,sql);
        job.statementContext=session.context;job.proofFence=metadataPlatform.proofFence(session);
        var admission=metadataPlatform.proofAdmissionState(session,job.proofFence);
        if(admission!=io.busystack.busydata.metadata.MetadataState.AVAILABLE&&admission!=io.busystack.busydata.metadata.MetadataState.UNAVAILABLE){
            String reason=admission==io.busystack.busydata.metadata.MetadataState.STALE?"Persistent metadata authority changed or is unavailable; reconcile explicitly":"Native identifier comparison evidence is unavailable for this physical connection";
            job.statementProofFailure=io.busystack.busydata.metadata.RetainedMetadataProof.unavailable(admission,reason);return;
        }
        if(session.profile.getEngine()!=Engine.POSTGRESQL){
            var source=physicalSource(session,sql);
            if(source!=null){
                // This read ends and its cancellation transport is fenced before
                // the original SELECT is submitted. Never query an unread stream.
                long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(10);
                var physical=io.busystack.busydata.schema.OwnedTemporarySource.verify(metadataPlatform,session,source.catalog(),source.schema(),source.name(),deadline,job);
                if(!physical.available())job.statementProofFailure=io.busystack.busydata.metadata.RetainedMetadataProof.unavailable(physical.state(),"Native physical relation classification was unavailable before this statement");
                if(physical.available()&&physical.kind()==io.busystack.busydata.metadata.MetadataSnapshot.PhysicalRelationKind.PERSISTENT&&source.sessionOwned())try(var maintenance=metadataPlatform.ownedMaintenance(session)){metadataPlatform.removeTemporary(session,source.catalog(),source.schema(),source.name());}
                if(physical.available()&&physical.kind()==io.busystack.busydata.metadata.MetadataSnapshot.PhysicalRelationKind.TEMPORARY){
                    job.statementProofFailure=io.busystack.busydata.metadata.RetainedMetadataProof.unavailable(io.busystack.busydata.metadata.MetadataState.UNSUPPORTED,"The statement selected an owned temporary table without durable editable generation evidence");
                    String nativeCatalog=metadataPlatform.capture(session).rules().lookup(ObjectKind.CATALOG,source.catalog(),true);
                    String nativeName=physical.nativeName();
                    // A real complete observation may preserve an already
                    // complete exact owned shape. This applies to every SELECT,
                    // with no generated-SQL exception or revision rebinding.
                    if(!physical.reusesOwnedShape(metadataPlatform,session))try(var maintenance=metadataPlatform.ownedMaintenance(session)){io.busystack.busydata.metadata.SessionMetadataOverlay.refresh(new io.busystack.busydata.schema.Explorer(metadataPlatform),session,nativeCatalog,nativeCatalog,nativeName,job,deadline,physical);}
                    catch(Exception unavailable){job.checkCancel();if(session.state==TransactionState.UNKNOWN_TRANSACTION||unavailable instanceof CancellationException||unavailable instanceof InterruptedException)throw unavailable;metadataPlatform.markSessionResolutionUnknown(session,"Owned temporary structure could not be acquired before selection");}
                }
            }
        }
        // A native TEMP observation may have published the initial empty
        // header. Only this real pre-execution boundary captures its new fence;
        // stale external authority still exits before any physical read above.
        job.checkCancel();job.proofFence=metadataPlatform.proofFence(session);
        admission=metadataPlatform.proofAdmissionState(session,job.proofFence);
        if(admission!=io.busystack.busydata.metadata.MetadataState.AVAILABLE){job.statementProofFailure=io.busystack.busydata.metadata.RetainedMetadataProof.unavailable(admission,"Native identifier comparison evidence is unavailable for this physical connection");return;}
        var snapshot=metadataPlatform.capture(session);
        prepareMetadataWitness(job,session,sql,snapshot);
        job.statementMetadata=io.busystack.busydata.metadata.ExecutionMetadata.prepare(snapshot,session.targetProfile(),session.id,sql,job.statementContext);
    }
    /** The immutable catalog and parser frame end before native physical reads. */
    private record PhysicalSource(String catalog,String schema,String name,boolean sessionOwned){}
    private PhysicalSource physicalSource(SessionRegistry.Session session,String sql){
        var snapshot=metadataPlatform.capture(session);
        var found=io.busystack.busydata.metadata.RetainedMetadataProof.sourceRelation(snapshot,session.targetProfile(),session.id,sql,session.context);
        if(found.isPresent()){var identity=found.get().identity();return new PhysicalSource(identity.catalog(),identity.schema(),identity.name(),!identity.sessionOwner().isEmpty());}
        // This candidate is NEVER execution provenance or a generated-operation
        // identity. Native quoted SHOW alone decides what this session resolves.
        var candidate=io.busystack.busydata.metadata.RetainedMetadataProof.parsedReference(session.targetProfile(),sql,session.context);
        return candidate.map(value->new PhysicalSource(value.database(),value.database(),value.name(),false)).orElse(null);
    }
    private void prepareMetadataWitness(Job job,SessionRegistry.Session session,String sql,io.busystack.busydata.metadata.MetadataSnapshot snapshot)throws Exception{
        if(session.profile.getEngine()!=Engine.MARIADB)return;
        if(job.metadataWitness!=null&&job.witnessSql.equals(sql)&&job.metadataWitness.available())return;
        if(job.metadataWitness!=null){job.metadataWitness.close();job.metadataWitness=null;}
        job.metadataWitness=io.busystack.busydata.metadata.PreparedMetadataWitness.capture(session,snapshot,sql,job);job.witnessSql=sql;
    }
    private static StatementResult summary(ResultStore.Result r,int index){return StatementResult.newBuilder().setStatementIndex(index).setPlan(r.plan).setResultId(r.id).addAllColumns(r.columns).setUpdateCount(-1).setFetchedRows(r.rows()).setComplete(r.complete).setLimited(r.limited).build();}
    public JobInfo cancel(String id){var job=get(id);final Statement statement;final SessionRegistry.Session owner;final Process process;final CompletableFuture<Void> finished;synchronized(job){if(terminal(job.state)||job.cancel.get())return job.info();if(job.acknowledged){if(job.state==JobState.FETCHING){job.cancel.set(true);job.message("Fetching stopped after database acknowledgement; committed changes remain committed. Retained results may be incomplete.");}return job.info();}if(job.committing){job.message("Commit acknowledgement is pending; cancellation cannot undo this boundary");return job.info();}
        boolean queued=job.state==JobState.QUEUED||job.waitingForSession;
        job.cancel.set(true);job.state=JobState.CANCELLING;
        if(queued){if(job.worker!=null)job.worker.interrupt();return job.info();}
        statement=job.statement;owner=job.statementSession;process=job.process;finished=new CompletableFuture<>();job.cancelFinished=finished;}
        // Capture identity under the monitor, then perform blocking driver I/O
        // outside it. Status, cancellation admission and terminal cleanup must
        // remain responsive when a cancellation connection is slow. The worker
        // waits for this control before releasing its physical-session lock;
        // an unconfirmed timeout quarantines that connection before any reuse.
        try{controls.submit(()->{try{if(statement!=null&&owner!=null)owner.cancel(statement,()->job.statement==statement&&!job.acknowledged&&!terminal(job.state));if(process!=null&&job.process==process&&!terminal(job.state))process.destroy();}catch(Exception e){job.message("Driver cancellation could not be confirmed");}finally{finished.complete(null);}});}
        catch(RejectedExecutionException failure){finished.completeExceptionally(failure);job.message("Cancellation control unavailable during shutdown; physical-session reuse requires confirmed cleanup");}
        return job.info();}
    public static boolean terminal(JobState s){return Set.of(JobState.COMPLETED,JobState.FAILED,JobState.CANCELLED,JobState.INTERRUPTED,JobState.UNKNOWN_OUTCOME).contains(s);}
    public synchronized void close(){if(!closed.compareAndSet(false,true))return;if(metadataRefresh!=null)metadataRefresh.close();for(var j:jobs.values())if(!terminal(j.state))cancel(j.id);deadlines.shutdownNow();workers.shutdownNow();controls.shutdownNow();try{workers.awaitTermination(3,TimeUnit.SECONDS);}catch(InterruptedException e){Thread.currentThread().interrupt();}}
}
