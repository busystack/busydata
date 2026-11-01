package io.busystack.busydata.rpc;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.adapters.JdbcAdapter;
import io.busystack.busydata.analysis.SqlAnalysis;
import io.busystack.busydata.analysis.language.SymbolService;
import io.busystack.busydata.analysis.language.ResolutionContext;
import io.busystack.busydata.jobs.Jobs;
import io.busystack.busydata.results.ResultStore;
import io.busystack.busydata.safety.Safety;
import io.busystack.busydata.schema.*;
import io.busystack.busydata.sessions.SessionRegistry;
import io.busystack.busydata.storage.MetadataStore;
import io.busystack.busydata.transfers.Transfers;
import io.busystack.busydata.transfers.ImportSources;
import io.grpc.*;
import io.grpc.stub.StreamObserver;
import java.util.*;
import java.util.concurrent.*;
import java.security.*;

public final class WorkbenchService extends WorkbenchGrpc.WorkbenchImplBase {
    public static final int PROTOCOL=ProtocolVersion.BUSYDATA_PROTOCOL_VERSION.getNumber();public final String instance=UUID.randomUUID().toString();
    private final SessionRegistry sessions;private final Jobs jobs;private final ResultStore results;private final MetadataStore metadata;private final Safety safety;private final SqlAnalysis analysis;
    private final io.busystack.busydata.results.RetainedViews retainedViews;private final Explorer explorer;private final SchemaTools schemaTools;private final ChangePlanner changes;private final Transfers transfers;private final Runnable shutdown;
    private final SmartMetadataRefresh smartRefresh;
    private final Semaphore languageCpu=new Semaphore(4,true);
    private final Semaphore cpu=new Semaphore(2,true);
    private final Semaphore sourceReviews=new Semaphore(2,true);
    private final io.busystack.busydata.security.SshTrust sshTrust;
    public WorkbenchService(SessionRegistry sessions,Jobs jobs,ResultStore results,MetadataStore metadata,Safety safety,SqlAnalysis analysis,Runnable shutdown){this(sessions,jobs,results,metadata,safety,analysis,shutdown,new io.busystack.busydata.security.SshTrust(metadata,safety));}
    public WorkbenchService(SessionRegistry sessions,Jobs jobs,ResultStore results,MetadataStore metadata,Safety safety,SqlAnalysis analysis,Runnable shutdown,io.busystack.busydata.security.SshTrust sshTrust){this.sessions=sessions;this.jobs=jobs;this.results=results;this.retainedViews=new io.busystack.busydata.results.RetainedViews(results);this.metadata=metadata;this.safety=safety;this.analysis=analysis;this.shutdown=shutdown;this.transfers=new Transfers(results,retainedViews);this.explorer=new Explorer(metadata);this.schemaTools=new SchemaTools(explorer.metadata());this.smartRefresh=jobs.metadataRefresh();this.changes=new ChangePlanner(safety,results,explorer.metadata());this.sshTrust=sshTrust;}
    @FunctionalInterface private interface Action<T>{T run()throws Exception;}
    private <T> void connectionCall(io.busystack.busydata.protocol.Context c,StreamObserver<T> out,Action<T> action){
        call(c,out,()->{try{return action.run();}catch(StatusRuntimeException error){throw error;}catch(Exception error){throw ConnectionErrors.safe(error);}});
    }
    private <T> void call(io.busystack.busydata.protocol.Context c,StreamObserver<T> out,Action<T> action){
        try {
            if(c.getProtocolVersion()!=PROTOCOL)throw Status.FAILED_PRECONDITION.withDescription("Protocol mismatch").asRuntimeException();
            if(!c.getInstanceId().equals(instance))throw new WorkbenchFailure(WorkbenchFailure.Reason.BACKEND_RESTARTED);
            if(c.getRequestId().isBlank()||c.getRequestId().length()>128)throw new WorkbenchFailure(WorkbenchFailure.Reason.MALFORMED_REQUEST);
            out.onNext(action.run());out.onCompleted();
        }catch(WorkbenchFailure e){out.onError(e.asStatusRuntimeException());}
        catch(StatusRuntimeException e){out.onError(e);}
        catch(CancellationException e){out.onError(new WorkbenchFailure(WorkbenchFailure.Reason.CANCELLED).asStatusRuntimeException());}
        catch(Explorer.ContinuationFailure e){var trailers=new Metadata();trailers.put(Metadata.Key.of("busydata-metadata-reason",Metadata.ASCII_STRING_MARSHALLER),"restart-enumeration");out.onError(Status.FAILED_PRECONDITION.withDescription(e.getMessage()).asRuntimeException(trailers));}
        catch(ResultStore.Unavailable e){out.onError(new WorkbenchFailure(WorkbenchFailure.Reason.RESULT_DISPOSED).asStatusRuntimeException());}
        catch(io.busystack.busydata.schema.EditValues.Failure e){var reason=e.code()==io.busystack.busydata.schema.EditValues.Code.UNSUPPORTED?WorkbenchFailure.Reason.UNSUPPORTED:e.code()==io.busystack.busydata.schema.EditValues.Code.METADATA_UNAVAILABLE?WorkbenchFailure.Reason.INCOMPLETE_METADATA:WorkbenchFailure.Reason.MALFORMED_REQUEST;out.onError(new WorkbenchFailure(reason).asStatusRuntimeException());}
        catch(io.busystack.busydata.metadata.MetadataLimit e){out.onError(new WorkbenchFailure(WorkbenchFailure.Reason.INCOMPLETE_METADATA).asStatusRuntimeException());}
        catch(IllegalArgumentException e){out.onError(Status.INVALID_ARGUMENT.withDescription(e.getMessage()).asRuntimeException());}
        catch(IllegalStateException e){out.onError(Status.FAILED_PRECONDITION.withDescription(e.getMessage()).asRuntimeException());}
        catch(UnsupportedOperationException e){out.onError(new WorkbenchFailure(WorkbenchFailure.Reason.UNSUPPORTED).asStatusRuntimeException());}
        catch(java.util.concurrent.TimeoutException|java.sql.SQLTimeoutException e){out.onError(new WorkbenchFailure(WorkbenchFailure.Reason.TIMED_OUT).asStatusRuntimeException());}
        catch(java.sql.SQLException e){
            String state=e.getSQLState();WorkbenchFailure.Reason reason=null;int depth=0;
            for(Throwable cause=e;cause!=null&&depth++<16;cause=cause.getCause()){
                if(cause instanceof java.sql.SQLTimeoutException){reason=WorkbenchFailure.Reason.TIMED_OUT;break;}
                if(cause instanceof java.sql.SQLFeatureNotSupportedException){reason=WorkbenchFailure.Reason.UNSUPPORTED;break;}
                if(cause.getCause()==cause)break;
            }
            var context=io.grpc.Context.current();
            if(reason==null&&context.isCancelled())reason=context.getDeadline()!=null&&context.getDeadline().isExpired()?WorkbenchFailure.Reason.TIMED_OUT:WorkbenchFailure.Reason.CANCELLED;
            if(reason==null&&state!=null&&(state.startsWith("28")||state.equals("42501")||Set.of(1044,1045,1142,1143,1227,1370).contains(e.getErrorCode())))reason=WorkbenchFailure.Reason.DENIED;
            if(reason==null&&state!=null&&state.startsWith("08"))reason=WorkbenchFailure.Reason.UNAVAILABLE;
            if(reason!=null)out.onError(new WorkbenchFailure(reason).asStatusRuntimeException());
            else out.onError(Status.FAILED_PRECONDITION.withDescription("Database request failed; SQLSTATE "+state+". Review server logs without sharing credentials.").asRuntimeException());
        }
        catch(Exception e){out.onError(Status.INTERNAL.withDescription("Operation failed. Check permissions, endpoint, TLS, and host-key configuration.").asRuntimeException());}
    }
    @Override public void ping(io.busystack.busydata.protocol.Context r,StreamObserver<BackendInfo> out){call(r,out,()->BackendInfo.newBuilder().setInstanceId(instance).setProtocolVersion(PROTOCOL).setVersion("0.1.0").build());}
    @Override public void profiles(ProfileRequest r,StreamObserver<ProfileList> out){call(r.getContext(),out,()->{switch(r.getAction()){case SAVE_PROFILE->{JdbcAdapter.validate(r.getProfile());if(r.getProfile().getId().isBlank())throw new IllegalArgumentException("Profile ID required");metadata.save(r.getProfile());}case DELETE_PROFILE->metadata.delete(r.getProfile().getId());case LIST_PROFILES->{}default->throw new IllegalArgumentException("Invalid profile action");}return ProfileList.newBuilder().addAllProfiles(metadata.profiles()).build();});}
    @Override public void testConnection(OpenRequest r,StreamObserver<ConnectionInfo> out){
        var cancelled=new java.util.concurrent.atomic.AtomicBoolean();
        if(out instanceof io.grpc.stub.ServerCallStreamObserver<ConnectionInfo> stream)stream.setOnCancelHandler(()->cancelled.set(true));
        connectionCall(r.getContext(),out,()->sessions.test(r,()->cancelled.get()||io.grpc.Context.current().isCancelled()));
    }
    @Override public void testSshConnection(SshTestRequest r,StreamObserver<SshTestReply> out){
        var cancelled=new java.util.concurrent.atomic.AtomicBoolean();
        if(out instanceof io.grpc.stub.ServerCallStreamObserver<SshTestReply> stream)stream.setOnCancelHandler(()->cancelled.set(true));
        connectionCall(r.getContext(),out,()->sshTrust.test(r,()->cancelled.get()||io.grpc.Context.current().isCancelled()));
    }
    @Override public void describeConnection(ProfileRequest r,StreamObserver<ConnectionDescription> out){call(r.getContext(),out,()->{
        if(r.getProfile().getHost().length()>256||r.getProfile().getDatabase().length()>256||r.getProfile().getPort()>65535)throw new IllegalArgumentException("Invalid connection address");
        return JdbcAdapter.describe(r.getProfile());
    });}
    @Override public void reviewSshHost(SshTrustRequest r,StreamObserver<SshTrustReply> out){call(r.getContext(),out,()->sshTrust.review(r));}
    @Override public void acceptSshHost(SshTrustRequest r,StreamObserver<SshTrustReply> out){call(r.getContext(),out,()->sshTrust.accept(r));}
    @Override public void openSession(OpenRequest r,StreamObserver<SessionInfo> out){
        var opened=new java.util.concurrent.atomic.AtomicReference<SessionRegistry.Session>();
        var cancelled=new java.util.concurrent.atomic.AtomicBoolean();
        if(out instanceof io.grpc.stub.ServerCallStreamObserver<SessionInfo> stream)stream.setOnCancelHandler(()->{cancelled.set(true);var session=opened.get();if(session!=null)sessions.cancelPending(session.id);});
        connectionCall(r.getContext(),out,()->{
            var session=sessions.openPending(r);opened.set(session);
            if(cancelled.get()||out instanceof io.grpc.stub.ServerCallStreamObserver<SessionInfo> stream&&stream.isCancelled()){sessions.cancelPending(session.id);throw Status.CANCELLED.withDescription("Connection setup cancelled; unused session disposed").asRuntimeException();}
            return session.info();
        });
    }
    private String sessionFingerprint(SessionRequest r,SessionRegistry.Session s)throws Exception{var d=MessageDigest.getInstance("SHA-256");d.update(r.toBuilder().clearContext().clearApprovalToken().build().toByteArray());d.update(s.profile.toByteArray());d.update(Long.toString(s.revision).getBytes(java.nio.charset.StandardCharsets.US_ASCII));return HexFormat.of().formatHex(d.digest());}
    @Override public void reviewSession(SessionRequest r,StreamObserver<Approval> out){call(r.getContext(),out,()->{var s=sessions.controlSession(r.getSessionId());return Approval.newBuilder().setToken(safety.issue(sessionFingerprint(r,s))).addStatements(r.getAction()+" · "+s.profile.getName()+" · "+s.state).addRisks("Commit persists pending changes; disconnect rolls back only where the engine permits. Unknown outcomes cannot be recovered by replay.").setExpiresUnixMs(System.currentTimeMillis()+120_000).build();});}
    @Override public void session(SessionRequest r,StreamObserver<SessionInfo> out){call(r.getContext(),out,()->{
        if(r.getAction()==SessionAction.ADOPT_SESSION){var result=sessions.adopt(r.getSessionId());smartRefresh.connected(sessions.get(r.getSessionId()));return result;}
        var s=sessions.controlSession(r.getSessionId());long revision=s.revision;String fingerprint=sessionFingerprint(r,s);
        if(r.getAction()==SessionAction.SESSION_STATUS)return sessions.command(r,()->{});
        if(!s.lock.tryLock())throw new IllegalStateException("Session is busy; cancel its job before transaction commands");
        try{var result=sessions.command(r,()->{if(s.revision!=revision)throw new IllegalStateException("Session changed before control command");safety.consume(r.getApprovalToken(),fingerprint);});smartRefresh.transaction(s,r.getAction());return result;}
        finally{s.lock.unlock();}
    });}
    @Override public void review(ExecuteRequest r,StreamObserver<Approval> out){call(r.getContext(),out,()->{var s=sessions.get(r.getSessionId());return safety.review(r,s);});}
    @Override public void execute(ExecuteRequest r,StreamObserver<JobInfo> out){call(r.getContext(),out,()->jobs.execute(sessions.get(r.getSessionId()),r).info());}
    @Override public void jobs(JobRequest r,StreamObserver<JobList> out){call(r.getContext(),out,()->r.getJobId().isBlank()?jobs.page(r):JobList.newBuilder().addJobs(jobs.get(r.getJobId()).info()).setComplete(true).build());}
    @Override public void retainedResults(RetainedRequest r,StreamObserver<RetainedList> out){call(r.getContext(),out,()->results.list(r));}
    @Override public void cancel(JobRequest r,StreamObserver<JobInfo> out){call(r.getContext(),out,()->jobs.cancel(r.getJobId()));}
    @Override public void resultPage(PageRequest r,StreamObserver<Page> out){call(r.getContext(),out,()->retainedViews.contains(r.getResultId())?retainedViews.get(r.getResultId()).page(r):results.page(r));}
    @Override public void resultValue(ValueRequest r,StreamObserver<ValueChunk> out){call(r.getContext(),out,()->retainedViews.contains(r.getResultId())?retainedViews.get(r.getResultId()).source.value(r):results.get(r.getResultId()).value(r));}
    @Override public void copySql(CopySqlRequest r,StreamObserver<CopySqlReply> out){call(r.getContext(),out,()->CopySqlReply.newBuilder().setText(retainedViews.contains(r.getResultId())?io.busystack.busydata.results.SqlCopy.range(retainedViews.get(r.getResultId()).source,r,retainedViews.get(r.getResultId()).count,retainedViews.get(r.getResultId())::sourceRow):io.busystack.busydata.results.SqlCopy.range(results.get(r.getResultId()),r)).build());}
    @Override public void resultAggregate(ResultAggregateRequest r,StreamObserver<ResultAggregateReply> out){call(r.getContext(),out,()->{
        if(!cpu.tryAcquire())throw new IllegalStateException("Aggregate analysis limit reached");
        try{return new io.busystack.busydata.results.RetainedAggregates(results,retainedViews).calculate(r,io.grpc.Context.current()::isCancelled);}finally{cpu.release();}
    });}
    @Override public void relatedRows(RelatedRowsRequest r,StreamObserver<RelatedRowsReply> out){call(r.getContext(),out,()->new RelatedRows(explorer.metadata(),results).list(sessions.get(r.getSessionId()),r).toBuilder().setBackendInstance(instance).build());}
    @Override public void cloneRow(CloneRowRequest r,StreamObserver<StagedChange> out){call(r.getContext(),out,()->changes.cloneRow(sessions.get(r.getSessionId()),r));}
    @Override public void disposeResult(PageRequest r,StreamObserver<Empty> out){call(r.getContext(),out,()->{results.dispose(r.getResultId());return Empty.getDefaultInstance();});}
    @Override public void createResultView(ResultViewRequest r,StreamObserver<ResultViewInfo> out){call(r.getContext(),out,()->retainedViews.create(r,io.grpc.Context.current()::isCancelled));}
    @Override public void disposeResultView(ResultViewRequest r,StreamObserver<Empty> out){call(r.getContext(),out,()->{retainedViews.dispose(r.getViewId());return Empty.getDefaultInstance();});}
    @Override public void completeSql(AnalysisRequest r,StreamObserver<Analysis> out){language(r,out,AnalysisOperation.COMPLETION);}
    @Override public void diagnoseSql(AnalysisRequest r,StreamObserver<Analysis> out){language(r,out,AnalysisOperation.DIAGNOSTICS);}
    @Override public void sqlParameterInformation(AnalysisRequest r,StreamObserver<Analysis> out){language(r,out,AnalysisOperation.PARAMETER_INFORMATION);}
    @Override public void formatSql(AnalysisRequest r,StreamObserver<Analysis> out){language(r,out,AnalysisOperation.FORMAT);}
    @Override public void resolveSqlSymbol(AnalysisRequest r,StreamObserver<Analysis> out){language(r,out,AnalysisOperation.SYMBOL_RESOLUTION);}
    @Override public void sqlDdlImpact(AnalysisRequest r,StreamObserver<Analysis> out){language(r,out,AnalysisOperation.DDL_IMPACT);}
    private void language(AnalysisRequest request,StreamObserver<Analysis> out,AnalysisOperation expected){
        if(request.getInspectionsCount()>64||request.getInspectionsList().stream().anyMatch(setting->setting.getCode().length()>128||setting.getSeverity().length()>16)){call(request.getContext(),out,()->{throw new WorkbenchFailure(WorkbenchFailure.Reason.MALFORMED_REQUEST);});return;}
        try{io.busystack.busydata.analysis.language.SnippetCatalog.validate(request.getSnippetsMap());}catch(IllegalArgumentException malformed){call(request.getContext(),out,()->{throw new WorkbenchFailure(WorkbenchFailure.Reason.MALFORMED_REQUEST);});return;}
        if(request.getOperation()!=expected){call(request.getContext(),out,()->{throw new WorkbenchFailure(WorkbenchFailure.Reason.MALFORMED_REQUEST);});return;}
        analyze(request,out);
    }
    private void analyze(AnalysisRequest r,StreamObserver<Analysis> out){call(r.getContext(),out,()->{
        if(r.getDocumentId().isBlank()||r.getDocumentId().length()>128||r.getEngine()==Engine.ENGINE_UNSPECIFIED||r.getEngine()==Engine.UNRECOGNIZED)throw new WorkbenchFailure(WorkbenchFailure.Reason.MALFORMED_REQUEST);
        if(!languageCpu.tryAcquire())throw new IllegalStateException("Analysis queue full");
        try {
            var session=r.getSessionId().isBlank()?null:sessions.get(r.getSessionId());
            verifyAnalysisBinding(session,r);
            if(session!=null&&r.getEngine()!=session.profile.getEngine())throw new WorkbenchFailure(WorkbenchFailure.Reason.INVALID_OWNER);
            var settings=session==null?io.busystack.busydata.analysis.LexicalSettings.DEFAULT:session.context.lexical();
            var snapshot=session==null?null:explorer.metadata().capture(session);
            if(snapshot!=null&&((r.getMetadataSnapshotRevision()!=0&&r.getMetadataSnapshotRevision()!=snapshot.revision())||
                (r.getMetadataConfigurationRevision()!=0&&r.getMetadataConfigurationRevision()!=snapshot.configurationRevision())))throw new WorkbenchFailure(WorkbenchFailure.Reason.INVALID_REVISION);
            var context=session==null?ResolutionContext.UNAVAILABLE:new ResolutionContext(session.context.catalog(),session.context.schema(),session.context.searchPath(),
                metadataComplete(session,snapshot),snapshot.revision(),snapshot.configurationRevision(),snapshot.rules(),snapshot,session.context.temporarySchema());
            if(r.getOperation()==AnalysisOperation.SYMBOL_RESOLUTION){
                var symbol=SymbolService.resolve(r,session==null?"":session.profile.getId(),settings,context,io.grpc.Context.current()::isCancelled);
                verifyAnalysisBinding(session,r);verifyAnalysisMetadata(session,snapshot);
                return Analysis.newBuilder().setDocumentId(r.getDocumentId()).setDocumentVersion(r.getDocumentVersion()).setBackendInstance(instance)
                    .setSessionId(r.getSessionId()).setContextRevision(r.getContextRevision()).setSessionRevision(r.getSessionRevision()).setCaretUtf16(r.getCaretUtf16())
                    .setOperation(r.getOperation()).setMetadataSnapshotRevision(snapshot==null?0:snapshot.revision()).setMetadataConfigurationRevision(snapshot==null?0:snapshot.configurationRevision()).setMetadataSourceIdentity(snapshot==null?"":snapshot.source()).setSymbol(symbol).build();
            }
            var result=analysis.analyze(r,settings,context);
            verifyAnalysisBinding(session,r);verifyAnalysisMetadata(session,snapshot);return result;
        }finally{languageCpu.release();}
    });}
    private boolean metadataComplete(SessionRegistry.Session session,io.busystack.busydata.metadata.MetadataSnapshot snapshot){
        var policy=explorer.metadata().configuration(session);
        if(!policy.includePatterns().isEmpty()||!policy.excludePatterns().isEmpty())return false;
        var schemas=session.context.searchPath().isEmpty()?List.of(session.context.schema()):session.context.searchPath();
        if(session.context.catalog().isBlank()||schemas.stream().anyMatch(String::isBlank))return false;
        for(String schema:schemas)for(var kind:List.of(ObjectKind.TABLE,ObjectKind.VIEW,ObjectKind.COLUMN,ObjectKind.ROUTINE))if(!policy.permits(session.context.catalog(),schema,kind,""))return false;
        if(!snapshot.coverage().values().stream().anyMatch(c->c.complete()&&c.level().includes(io.busystack.busydata.metadata.IntrospectionLevel.STRUCTURE))||snapshot.coverage().values().stream().anyMatch(c->!c.complete()))return false;
        for(String schema:schemas)for(var kind:List.of(ObjectKind.TABLE,ObjectKind.VIEW)){
            if(!snapshot.complete(new io.busystack.busydata.metadata.MetadataScope(session.context.catalog(),schema,"",kind),io.busystack.busydata.metadata.IntrospectionLevel.STRUCTURE))return false;
            for(var relation:snapshot.namespace(session.context.catalog(),schema,kind,""))if(!snapshot.complete(new io.busystack.busydata.metadata.MetadataScope(session.context.catalog(),schema,relation.identity().name(),ObjectKind.COLUMN),io.busystack.busydata.metadata.IntrospectionLevel.STRUCTURE))return false;
        }
        return true;
    }
    private void verifyAnalysisMetadata(SessionRegistry.Session session,io.busystack.busydata.metadata.MetadataSnapshot captured){
        if(session==null)return;
        var current=explorer.metadata().capture(session);
        if(current.revision()!=captured.revision()||current.configurationRevision()!=captured.configurationRevision())throw new WorkbenchFailure(WorkbenchFailure.Reason.INVALID_REVISION);
    }
    private void verifyAnalysisBinding(SessionRegistry.Session session,AnalysisRequest request){if(session!=null&&(sessions.get(session.id)!=session||session.contextRevision!=request.getContextRevision()||session.revision!=request.getSessionRevision()))throw new WorkbenchFailure(WorkbenchFailure.Reason.INVALID_REVISION);}

    @Override public void metadataSettings(MetadataSettingsRequest r,StreamObserver<MetadataSettingsReply> out){call(r.getContext(),out,()->{
        SessionRegistry.Session session;
        try{session=sessions.get(r.getSessionId());}
        catch(IllegalArgumentException|IllegalStateException invalidOwner){throw new WorkbenchFailure(WorkbenchFailure.Reason.INVALID_OWNER);}
        return io.busystack.busydata.metadata.MetadataRpc.run(explorer,session,r);
    });}
    @Override public void explore(ExploreRequest r,StreamObserver<SchemaObjects> out){call(r.getContext(),out,()->explorer.explore(sessions.get(r.getSessionId()),r));}
    @Override public void reviewBrowse(BrowseRequest r,StreamObserver<Approval> out){call(r.getContext(),out,()->TableBrowse.review(sessions.get(r.getSessionId()),r,explorer,safety,new RelatedRows(explorer.metadata(),results)));}
    @Override public void browse(BrowseRequest r,StreamObserver<JobInfo> out){call(r.getContext(),out,()->TableBrowse.submit(sessions.get(r.getSessionId()),r,explorer,safety,jobs,new RelatedRows(explorer.metadata(),results)).info());}
    @Override public void schemaTool(SchemaToolRequest r,StreamObserver<SchemaToolResult> out){call(r.getContext(),out,()->{if(!cpu.tryAcquire())throw new IllegalStateException("Schema analysis limit reached");try{return schemaTools.run(sessions.get(r.getSessionId()),r);}finally{cpu.release();}});}
    @Override public void privilegeTool(PrivilegeRequest r,StreamObserver<PrivilegeReply> out){call(r.getContext(),out,()->new io.busystack.busydata.administration.PrivilegeTools().run(sessions.get(r.getSessionId()),r));}
    @Override public void reviewAuthentication(AuthenticationRequest r,StreamObserver<Approval> out){call(r.getContext(),out,()->new io.busystack.busydata.administration.AuthenticationTools(safety).review(sessions.get(r.getSessionId()),r));}
    @Override public void authentication(AuthenticationRequest r,StreamObserver<JobInfo> out){call(r.getContext(),out,()->new io.busystack.busydata.administration.AuthenticationTools(safety).apply(sessions.get(r.getSessionId()),r,jobs).info());}
    @Override public void previewChanges(ChangeRequest r,StreamObserver<ChangePlan> out){call(r.getContext(),out,()->changes.preview(sessions.get(r.getSessionId()),r));}
    @Override public void assessEditability(ChangeRequest r,StreamObserver<Editability> out){call(r.getContext(),out,()->changes.assess(sessions.get(r.getSessionId()),r));}
    @Override public void applyChanges(ApplyRequest r,StreamObserver<JobInfo> out){call(r.getContext(),out,()->changes.apply(sessions.get(r.getSessionId()),r,jobs,metadata).info());}
    @Override public void editDraft(EditDraftRequest r,StreamObserver<EditDraftReply> out){call(r.getContext(),out,()->new EditDrafts(metadata,results,changes).run(sessions,r));}
    private String sourceHash(ToolRequest r)throws Exception {
        if(!sourceReviews.tryAcquire())throw new IllegalStateException("Source-review limit reached; retry after another preview finishes");
        var context=io.grpc.Context.current();
        try {String source=ImportSources.hash(java.nio.file.Path.of(r.getPath()),context::isCancelled);if(!r.getSourceSha256().isEmpty()&&!r.getSourceSha256().equals(source))throw new IllegalStateException("Source changed after preview");return source;}
        finally {sourceReviews.release();}
    }
    private String fingerprint(ToolRequest r,long revision)throws Exception{return fingerprint(r,revision,outputIdentity(r));}
    private String outputIdentity(ToolRequest r)throws Exception{return Set.of(ToolKind.EXPORT_RESULT,ToolKind.EXPORT_QUERY,ToolKind.DUMP).contains(r.getKind())?io.busystack.busydata.transfers.OutputTarget.identity(java.nio.file.Path.of(r.getPath())):"";}
    private void reviewedTransfer(io.busystack.busydata.jobs.Jobs.Job job,ToolRequest r,long revision)throws Exception{String destination=outputIdentity(r);safety.consume(r.getApprovalToken(),fingerprint(r,revision,destination));transfers.run(job,r,destination);}
    private String fingerprint(ToolRequest r,long revision,String destination)throws Exception {
        String source=Set.of(ToolKind.IMPORT_CSV,ToolKind.IMPORT_JSON,ToolKind.RESTORE).contains(r.getKind())?sourceHash(r):"";
        return fingerprint(r,revision,destination,source);
    }
    private String fingerprint(ToolRequest r,long revision,String destination,String reviewedSource)throws Exception{var d=MessageDigest.getInstance("SHA-256");d.update(r.toBuilder().clearContext().clearApprovalToken().clearExecutionId().clearSourceSha256().build().toByteArray());d.update(Long.toString(revision).getBytes(java.nio.charset.StandardCharsets.US_ASCII));if(Set.of(ToolKind.DUMP,ToolKind.RESTORE).contains(r.getKind()))d.update(io.busystack.busydata.transfers.NativeToolChecks.reviewedFiles(r,sessions.get(r.getSessionId()).profile).getBytes(java.nio.charset.StandardCharsets.US_ASCII));if(Set.of(ToolKind.EXPORT_RESULT,ToolKind.EXPORT_QUERY,ToolKind.DUMP).contains(r.getKind()))d.update(destination.getBytes(java.nio.charset.StandardCharsets.UTF_8));if(Set.of(ToolKind.IMPORT_CSV,ToolKind.IMPORT_JSON,ToolKind.RESTORE).contains(r.getKind()))d.update(reviewedSource.getBytes(java.nio.charset.StandardCharsets.US_ASCII));return HexFormat.of().formatHex(d.digest());}
    @Override public void previewImport(ToolRequest r,StreamObserver<ImportPreview> out){call(r.getContext(),out,()->{sessions.get(r.getSessionId());if(!sourceReviews.tryAcquire())throw new IllegalStateException("Source-review limit reached");try{return ImportSources.preview(r);}finally{sourceReviews.release();}});}
    @Override public void activities(ActivityRequest r,StreamObserver<ActivityList> out){call(r.getContext(),out,()->new io.busystack.busydata.administration.Activities().list(sessions.get(r.getSessionId())));}
    @Override public void capabilities(CapabilityRequest r,StreamObserver<CapabilityList> out){call(r.getContext(),out,()->io.busystack.busydata.administration.Capabilities.inspect(sessions.get(r.getSessionId()),r,()->io.grpc.Context.current().isCancelled()));}
    @Override public void reviewTool(ToolRequest r,StreamObserver<Approval> out){call(r.getContext(),out,()->{if(Set.of(ToolKind.CANCEL_ACTIVITY,ToolKind.TERMINATE_ACTIVITY).contains(r.getKind()))sessions.get(r.getSessionId()).metadata(control->{var activity=new io.busystack.busydata.administration.Activities().verify(control,r.getTargetId(),r.getActivityFingerprint());if(r.getKind()==ToolKind.CANCEL_ACTIVITY&&!activity.getCancellable())throw new UnsupportedOperationException("Current statement identity is unavailable or idle; refresh/enable statement instrumentation before cancellation");return activity;});long revision=r.getKind()==ToolKind.EXPORT_RESULT?exportRows(r):sessions.get(r.getSessionId()).revision;boolean importing=Set.of(ToolKind.IMPORT_CSV,ToolKind.IMPORT_JSON).contains(r.getKind());String source=importing?sourceHash(r):"";String token=importing?safety.issueSource(fingerprint(r,revision,"",source),source):safety.issue(fingerprint(r,revision));return Approval.newBuilder().setToken(token).addStatements(r.getKind()+" · "+r.getPath()+" · "+r.getSchema()+"."+r.getTable()).addRisks(r.getKind()==ToolKind.EXPORT_RESULT?"Writes already fetched rows to the selected file; SQL is not rerun. Review overwrite and incomplete-result limits.":"Review target, source, mapping and overwrite choice. Execution-backed plans execute SQL; imports modify rows.").setExpiresUnixMs(System.currentTimeMillis()+120_000).build();});}
    private long exportRows(ToolRequest r){return retainedViews.contains(r.getResultId())?retainedViews.get(r.getResultId()).count:exportResult(r).rows();}
    private ResultStore.Result exportResult(ToolRequest r){var result=retainedViews.contains(r.getResultId())?retainedViews.get(r.getResultId()).source:results.get(r.getResultId());if(result.sourceSessionId.isBlank()||(!r.getSessionId().isBlank()&&!r.getSessionId().equals(result.sourceSessionId)))throw new IllegalArgumentException("Result/session ownership mismatch");if(!result.fetchFinished&&!retainedViews.contains(r.getResultId()))throw new IllegalStateException("Wait for fetching to finish before reviewing export");return result;}
    @Override public void tool(ToolRequest r,StreamObserver<JobInfo> out){call(r.getContext(),out,()->{
        if(r.getKind()==ToolKind.EXPORT_RESULT){var result=exportResult(r);return jobs.submitRetainedExport(result,r.getExecutionId(),job->reviewedTransfer(job,r,exportRows(r)),retainedViews.contains(r.getResultId())?retainedViews.get(r.getResultId()).lease():null).operation(r.getKind()).info();}
        var s=sessions.get(r.getSessionId());
        if(r.getKind()==ToolKind.CANCEL_ACTIVITY||r.getKind()==ToolKind.TERMINATE_ACTIVITY) {
            if(r.getTargetId()<1||r.getTargetId()>Integer.MAX_VALUE)throw new IllegalArgumentException("Choose a real activity identifier");
            if(s.profile.getReadOnly())throw new IllegalArgumentException("Read-only profile rejects activity mutation");
            return jobs.submit(s,r.getExecutionId(),"",job->{safety.consume(r.getApprovalToken(),fingerprint(r,s.revision));
                s.metadata(control->{new io.busystack.busydata.administration.Activities().verify(control,r.getTargetId(),r.getActivityFingerprint());String sql=s.profile.getEngine()==Engine.POSTGRESQL?"SELECT "+(r.getKind()==ToolKind.CANCEL_ACTIVITY?"pg_cancel_backend":"pg_terminate_backend")+"(?)":"KILL "+(r.getKind()==ToolKind.CANCEL_ACTIVITY?"QUERY ":"")+r.getTargetId();
                    try(var st=control.connection.prepareStatement(sql)){if(s.profile.getEngine()==Engine.POSTGRESQL)st.setLong(1,r.getTargetId());st.setQueryTimeout(5);job.statementSession=control;job.statement=st;job.checkCancel();if(st.execute())try(var rows=st.getResultSet()){if(!rows.next()||!rows.getBoolean(1))throw new IllegalStateException("Server did not confirm the activity action");}job.message("Server accepted "+r.getKind()+" for activity "+r.getTargetId());}return null;});
            }).operation(r.getKind()).info();
        }
        if(r.getKind()==ToolKind.EXPORT_QUERY)return jobs.submitSql(s,r.getExecutionId(),r.getSql(),job->reviewedTransfer(job,r,s.revision)).operation(r.getKind()).info();
        if(Set.of(ToolKind.IMPORT_CSV,ToolKind.IMPORT_JSON).contains(r.getKind())){
            long revision=s.revision;
            // Consume within the ordinary review lifetime, before slow IO.
            // The server permit supplies the digest even without a preview.
            String source=safety.consumeSource(r.getApprovalToken(),reviewed->fingerprint(r,revision,"",reviewed));
            if(!r.getSourceSha256().isEmpty()&&!r.getSourceSha256().equals(source))throw new IllegalArgumentException("Reviewed source identity mismatch");
            var bound=r.toBuilder().setSourceSha256(source).build();
            sourceHash(bound);
            if(io.grpc.Context.current().isCancelled())throw new CancellationException();
            if(s.revision!=revision)throw new WorkbenchFailure(WorkbenchFailure.Reason.INVALID_REVISION);
            return jobs.submit(s,r.getExecutionId(),"",job->{
                job.checkCancel();
                if(s.revision!=revision)throw new WorkbenchFailure(WorkbenchFailure.Reason.INVALID_REVISION);
                // The immutable snapshot verifies the bound digest before writes.
                transfers.run(job,bound,"");
            }).operation(r.getKind()).info();
        }
        if(Set.of(ToolKind.DUMP,ToolKind.RESTORE).contains(r.getKind())){
            var bound=r.getKind()==ToolKind.DUMP?r:r.toBuilder().setSourceSha256(sourceHash(r)).build();
            return jobs.submit(s,r.getExecutionId(),"",job->reviewedTransfer(job,bound,s.revision)).operation(r.getKind()).info();
        }
        String sql=io.busystack.busydata.administration.DiagnosticTools.sql(s,r);
        if(r.getKind()==ToolKind.EXPLAIN||r.getKind()==ToolKind.EXPLAIN_ANALYZE){var fragments=analysis.split(r.getSql(),s.profile.getEngine(),s.context.lexical());if(fragments.size()!=1)throw new IllegalArgumentException("EXPLAIN requires one statement");}
        // Every tool is reviewed; the typed request includes target and analysis SQL.
        return jobs.submitSql(s,r.getExecutionId(),sql,job->{
            safety.consume(r.getApprovalToken(),fingerprint(r,s.revision));
            job.plan=r.getKind()==ToolKind.EXPLAIN||r.getKind()==ToolKind.EXPLAIN_ANALYZE;
            if(s.profile.getReadOnly()&&r.getKind()==ToolKind.EXPLAIN_ANALYZE&&!analysis.readOnly(r.getSql()))throw new IllegalArgumentException("Read-only profile rejects execution-backed mutation");
            try(var st=s.adapter.rawStatement(s.connection,false,s.profile.getQueryTimeoutSeconds(),10_000)){
                job.statement=st;job.checkCancel();
                try(var rows=st.executeQuery(sql)){
                    // pgJDBC auto-commit execution returns after ReadyForQuery.
                    // Its acknowledged commit must survive delivery cancellation,
                    // just as on the ordinary raw SQL execution path. MySQL and
                    // MariaDB streaming results must reach their final response.
                    if(s.profile.getEngine()==Engine.POSTGRESQL&&s.connection.getAutoCommit()&&s.adapter.transaction(s.connection)==TransactionState.IDLE)job.commitAcknowledged();
                    jobs.fetch(job,rows,0,10_000);
                    if(s.connection.getAutoCommit()&&s.adapter.transaction(s.connection)==TransactionState.IDLE)job.commitAcknowledged();
                }
            }
        }).operation(r.getKind()).info();
    });}
    @Override public void history(HistoryRequest r,StreamObserver<HistoryList> out){call(r.getContext(),out,()->metadata.history(r));}
    @Override public void historySql(HistorySqlRequest r,StreamObserver<HistorySqlChunk> out){call(r.getContext(),out,()->metadata.historySql(r));}
    @Override public void runtimeStats(io.busystack.busydata.protocol.Context r,StreamObserver<RuntimeStatsReply> out){call(r,out,()->{
        var heap=java.lang.management.ManagementFactory.getMemoryMXBean().getHeapMemoryUsage();long direct=0,mapped=0;
        for(var pool:java.lang.management.ManagementFactory.getPlatformMXBeans(java.lang.management.BufferPoolMXBean.class)){
            if(pool.getName().equals("direct"))direct+=Math.max(0,pool.getMemoryUsed());
            if(pool.getName().startsWith("mapped"))mapped+=Math.max(0,pool.getMemoryUsed());
        }
        return RuntimeStatsReply.newBuilder().setInstanceId(instance).setJavaVersion(System.getProperty("java.runtime.version")).setHeapUsedBytes(heap.getUsed()).setHeapCommittedBytes(heap.getCommitted()).setDirectBufferBytes(direct).setMappedBufferBytes(mapped).setRetainedBytes(results.bytes()).setTransferSnapshotBytes(results.transferBytes()).setPhysicalSessions(sessions.physicalSessionCount()).setActiveJobs((int)jobs.list("").stream().filter(job->!Jobs.terminal(job.getState())).count()).addAllGarbageCollectors(java.lang.management.ManagementFactory.getGarbageCollectorMXBeans().stream().map(java.lang.management.GarbageCollectorMXBean::getName).limit(8).toList()).build();
    });}
    @Override public void shutdown(io.busystack.busydata.protocol.Context r,StreamObserver<Empty> out){call(r,out,()->{CompletableFuture.runAsync(()->{retainedViews.close();shutdown.run();});return Empty.getDefaultInstance();});}
}
