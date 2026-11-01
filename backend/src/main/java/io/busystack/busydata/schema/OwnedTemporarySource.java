package io.busystack.busydata.schema;

import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.sessions.SessionRegistry;
import io.busystack.busydata.jobs.Jobs;
import io.busystack.busydata.rpc.WorkbenchFailure;
import java.io.Reader;
import java.sql.*;
import java.util.*;
import java.util.concurrent.*;

/** A native temporary definition belongs to its locked physical session only. */
public final class OwnedTemporarySource {
    private OwnedTemporarySource(){}
    public record Definition(String text,String availability,String sqlMode){}
    private static final ExecutorService control=Executors.newVirtualThreadPerTaskExecutor();
    private static final ScheduledExecutorService deadlines=Executors.newSingleThreadScheduledExecutor(Thread.ofPlatform().daemon(true).name("owned-metadata-deadline").factory());
    public static Definition read(SessionRegistry.Session session,MetadataObject object,long deadline)throws Exception {return read(session,object,deadline,null);}
    public static Definition read(SessionRegistry.Session session,MetadataObject object,long deadline,Jobs.Job job)throws Exception {
        if(io.grpc.Context.current().isCancelled()||Thread.currentThread().isInterrupted())throw new CancellationException("Owned temporary source cancelled");
        var identity=object.identity();
        if(!session.lock.isHeldByCurrentThread()||!identity.sessionOwner().equals(session.id)||identity.kind()!=ObjectKind.TABLE||!"true".equals(object.properties().get("temporary"))||!identity.source().equals(session.metadataSourceIdentity))throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.INVALID_OWNER);
        if(session.profile.getEngine()==Engine.POSTGRESQL)throw new IllegalArgumentException("This native source path is for MySQL/MariaDB temporary tables");
        String sqlMode=session.context.sqlMode();
        try{
            String renderer=renderer(session,sqlMode,deadline,job);
            try(var read=new Read(session,session.adapter.table(identity.catalog(),identity.schema(),identity.name()),Math.min(deadline,System.nanoTime()+TimeUnit.SECONDS.toNanos(10)),job)) {
            read.check();
            try(var rows=read.statement.executeQuery()) {
                read.check();if(!rows.next())throw new SQLException("Native temporary definition is unavailable");
                String text;
                try(var reader=rows.getCharacterStream(2)){text=bounded(reader,read::check);}
                read.check();if(rows.next())throw new SQLException("Native temporary definition is ambiguous");
                if(text==null)return new Definition("","LIMITED",sqlMode);
                var header=NativeTableHeader.parse(text.substring(0,Math.min(text.length(),NativeTableHeader.MAX_HEADER_UNITS)),text.length()>NativeTableHeader.MAX_HEADER_UNITS,session.profile.getEngine(),session.context.lexical());
                if(header.kind()!=MetadataSnapshot.PhysicalRelationKind.TEMPORARY||header.nameAvailability()!=MetadataState.AVAILABLE)throw new WorkbenchFailure(WorkbenchFailure.Reason.STALE);
                if(session.identifierContext.lowerCaseTableNames()!=2&&!header.name().equals(identity.name()))throw new WorkbenchFailure(WorkbenchFailure.Reason.STALE);
                return new Definition(text,NativeDefinitionEvidence.sourceAvailability(session.profile.getEngine(),sqlMode,renderer).name(),sqlMode);
            }
            }
        }catch(Exception failure){
            if(failure instanceof SQLException sql)session.failure(sql,false);
            if(session.state==TransactionState.UNKNOWN_TRANSACTION)throw transactionUnknown(failure);
            if(failure instanceof SQLException sql&&("42S02".equals(sql.getSQLState())||sql.getErrorCode()==1146))throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.STALE);
            throw failure;
        }
    }
    /** An observation of the name resolved by this physical session, never its durable catalog alone. */
    public static final class Classification {
        private final MetadataState state,nativeNameAvailability;private final MetadataSnapshot.PhysicalRelationKind kind;private final String nativeName,nativeNameProvenance;
        private final NativeDefinitionEvidence definition;private final MetadataPlatform.TemporaryObservation observation;private final String catalog,schema,requested;private final boolean reused;private final ObjectKind nativeObjectKind;
        public Classification(MetadataState state,MetadataSnapshot.PhysicalRelationKind kind){this(state,kind,"",MetadataState.NOT_REQUESTED,"");}
        public Classification(MetadataState state,MetadataSnapshot.PhysicalRelationKind kind,String nativeName,MetadataState nativeNameAvailability,String nativeNameProvenance){this(state,kind,nativeName,nativeNameAvailability,nativeNameProvenance,NativeDefinitionEvidence.unavailable(),null,"","","",false,null);}
        private Classification(MetadataState state,MetadataSnapshot.PhysicalRelationKind kind,String nativeName,MetadataState nativeNameAvailability,String nativeNameProvenance,NativeDefinitionEvidence definition,MetadataPlatform.TemporaryObservation observation,String catalog,String schema,String requested,boolean reused,ObjectKind nativeObjectKind){
            this.state=Objects.requireNonNull(state);this.kind=kind;this.nativeName=Objects.requireNonNull(nativeName);this.nativeNameAvailability=Objects.requireNonNull(nativeNameAvailability);this.nativeNameProvenance=Objects.requireNonNull(nativeNameProvenance);this.definition=Objects.requireNonNull(definition);this.observation=observation;this.catalog=catalog;this.schema=schema;this.requested=requested;this.reused=reused;this.nativeObjectKind=nativeObjectKind;
            if(nativeNameAvailability==MetadataState.AVAILABLE&&(nativeName.isEmpty()||!NativeTableHeader.PROVENANCE.equals(nativeNameProvenance)))throw new IllegalArgumentException("Exact native name provenance required");
        }
        public MetadataState state(){return state;}public MetadataSnapshot.PhysicalRelationKind kind(){return kind;}public String nativeName(){return nativeName;}public MetadataState nativeNameAvailability(){return nativeNameAvailability;}public String nativeNameProvenance(){return nativeNameProvenance;}
        public NativeDefinitionEvidence definition(){return definition;}
        /** Actual native kind; neither persistence nor a display alias proves base-table editability. */
        public ObjectKind nativeObjectKind(){return nativeObjectKind;}
        private static Classification observed(NativeTableHeader.Header header){
            var state=header.kind()!=null&&header.nameAvailability()==MetadataState.AVAILABLE?MetadataState.AVAILABLE:header.nameAvailability();
            return new Classification(state,header.kind(),"",MetadataState.NOT_REQUESTED,"",NativeDefinitionEvidence.unavailable(),null,"","","",false,header.objectKind());
        }
        public void checkCurrent(MetadataPlatform platform,SessionRegistry.Session session,String expectedCatalog,String expectedSchema,String expectedName){
            requireNativeName();if(!nativeName.equals(expectedName)||!sameScope(platform,session,expectedCatalog,expectedSchema)||!platform.temporaryObservationCurrent(session,observation,catalog,schema,requested))throw new WorkbenchFailure(WorkbenchFailure.Reason.STALE);
        }
        private boolean sameScope(MetadataPlatform platform,SessionRegistry.Session session,String expectedCatalog,String expectedSchema){var rules=platform.capture(session).rules();return rules.complete()&&rules.matches(ObjectKind.CATALOG,catalog,expectedCatalog,true)&&rules.matches(ObjectKind.SCHEMA,schema,expectedSchema,true);}
        public boolean reusesOwnedShape(MetadataPlatform platform,SessionRegistry.Session session){return reused&&platform.reuseTemporaryObservation(session,observation,catalog,schema,requested,nativeName,definition);}
        public void requireNativeName(){if(nativeNameAvailability!=MetadataState.AVAILABLE||nativeName.isEmpty())throw new WorkbenchFailure(nativeNameAvailability==MetadataState.UNSUPPORTED?WorkbenchFailure.Reason.UNSUPPORTED:nativeNameAvailability==MetadataState.STALE?WorkbenchFailure.Reason.STALE:WorkbenchFailure.Reason.INCOMPLETE_METADATA);}
        public boolean available(){return state==MetadataState.AVAILABLE&&kind!=null;}
        public void requirePersistent(){
            if(available()&&kind==MetadataSnapshot.PhysicalRelationKind.PERSISTENT)return;
            if(available())throw new WorkbenchFailure(kind==MetadataSnapshot.PhysicalRelationKind.ABSENT?WorkbenchFailure.Reason.STALE:WorkbenchFailure.Reason.UNSUPPORTED);
            throw new WorkbenchFailure(switch(state){
                case DENIED->WorkbenchFailure.Reason.DENIED;case TIMED_OUT->WorkbenchFailure.Reason.TIMED_OUT;
                case STALE->WorkbenchFailure.Reason.STALE;case UNSUPPORTED->WorkbenchFailure.Reason.UNSUPPORTED;
                case UNAVAILABLE,FAILED->WorkbenchFailure.Reason.UNAVAILABLE;case CANCELLED->WorkbenchFailure.Reason.CANCELLED;
                default->WorkbenchFailure.Reason.INCOMPLETE_METADATA;
            },WorkbenchFailure.Origin.NATIVE_CLASSIFICATION);
        }
    }
    /** Read before user SELECT or generated operations, while no user result stream is open. */
    public static Classification verify(MetadataPlatform platform,SessionRegistry.Session session,String catalog,String schema,String name,long deadline,Jobs.Job job)throws Exception {
        if(!session.lock.isHeldByCurrentThread())throw new IllegalStateException("Physical-session ownership is required for relation classification");
        if(session.profile.getEngine()==Engine.POSTGRESQL)throw new IllegalArgumentException("PostgreSQL resolution uses its owned native namespace model");
        for(String part:List.of(catalog,schema,name))if(part.isEmpty()||part.length()>256||part.indexOf('\0')>=0)throw new IllegalArgumentException("Exact physical relation identity required");
        long revision=session.revision,context=session.contextRevision,epoch=platform.sessionResolutionEpoch(session);String sqlMode=session.context.sqlMode();
        var prior=platform.temporaryObservation(session,catalog,schema,name);
        Classification result;NativeTableHeader.Header observed=null;NativeDefinitionEvidence definition=NativeDefinitionEvidence.unavailable();
        try{
            String renderer=renderer(session,sqlMode,deadline,job);
            try(var read=new Read(session,session.adapter.table(catalog,schema,name),Math.min(deadline,System.nanoTime()+TimeUnit.SECONDS.toNanos(10)),job)){
            read.check();
            try(var rows=read.statement.executeQuery()){
                read.check();if(!rows.next())throw new SQLException("Native relation classification is unavailable");
                try(var reader=rows.getCharacterStream(2)){var nativeRead=NativeTableHeader.observe(reader,session.profile.getEngine(),session.context.lexical(),sqlMode,renderer,read::check);observed=nativeRead.header();definition=nativeRead.definition();}
                read.check();if(rows.next())throw new SQLException("Native relation classification is ambiguous");
                result=Classification.observed(observed);
            }
            }
        }catch(Exception failure){
            if(failure instanceof SQLException sql)session.failure(sql,false);
            epoch=retireObservation(platform,session,catalog,schema,name,"Native physical relation observation did not complete");
            if(session.state==TransactionState.UNKNOWN_TRANSACTION)throw transactionUnknown(failure);
            if(job!=null)job.checkCancel();
            if(failure instanceof CancellationException||failure instanceof InterruptedException)throw failure;
            if(io.grpc.Context.current().isCancelled()||Thread.currentThread().isInterrupted())throw new CancellationException("Physical relation classification cancelled");
            if(failure instanceof WorkbenchFailure stale&&stale.reason()==WorkbenchFailure.Reason.STALE)result=new Classification(MetadataState.STALE,null);
            else if(failure instanceof SQLException sql&&("42S02".equals(sql.getSQLState())||sql.getErrorCode()==1146))result=new Classification(MetadataState.AVAILABLE,MetadataSnapshot.PhysicalRelationKind.ABSENT);
            else result=new Classification(failure instanceof SQLException sql&&("54000".equals(sql.getSQLState())||sql.getErrorCode()==1153||sql.getErrorCode()==2020)?MetadataState.LIMITED:failure instanceof SQLTimeoutException?MetadataState.TIMED_OUT:failure instanceof SQLException sql&&(sql.getErrorCode()==1142||sql.getErrorCode()==1044||sql.getErrorCode()==1045||"42000".equals(sql.getSQLState()))?MetadataState.DENIED:MetadataState.UNAVAILABLE,null);
        }
        if(revision!=session.revision||context!=session.contextRevision){retireObservation(platform,session,catalog,schema,name,"Physical relation owner changed during native classification");return new Classification(MetadataState.STALE,null);}
        if(!result.available()){
            retireObservation(platform,session,catalog,schema,name,"The owning physical session could not prove native relation resolution");
            return result;
        }
        if(result.kind()==MetadataSnapshot.PhysicalRelationKind.TEMPORARY){
            // A cached persistent claim or unknown/incomplete owned shape must
            // retire immediately. Only prior complete owned authority is even
            // eligible for equality after the real, fully drained SHOW.
            boolean retired=!platform.priorCompleteTemporaryShape(prior);
            if(retired)epoch=retireObservation(platform,session,catalog,schema,name,"Native SHOW observed an owned temporary relation");
            try{
                if(job!=null)job.checkCancel();var rules=platform.ensureOwnedIdentifierRules(session,deadline);if(job!=null)job.checkCancel();
                if(revision!=session.revision||context!=session.contextRevision){retireObservation(platform,session,catalog,schema,name,"Native temporary owner changed");return new Classification(MetadataState.STALE,null);}
                var exact=NativeTableHeader.authority(observed,rules,catalog,name);
                if(!exact.available()){
                    if(!retired)retireObservation(platform,session,catalog,schema,name,"Native temporary identity could not be proved");
                    return new Classification(exact.availability(),MetadataSnapshot.PhysicalRelationKind.TEMPORARY,"",exact.availability(),exact.provenance());
                }
                if(!retired&&platform.reuseTemporaryObservation(session,prior,catalog,schema,name,exact.exact(),definition))return new Classification(MetadataState.AVAILABLE,MetadataSnapshot.PhysicalRelationKind.TEMPORARY,exact.exact(),exact.availability(),exact.provenance(),definition,prior,catalog,schema,name,true,ObjectKind.TABLE);
                if(!retired)epoch=retireObservation(platform,session,catalog,schema,name,"Native temporary definition or its owner changed");
                // Bootstrap may have retired the provisional epoch. The native
                // SHOW is still on this exact locked physical owner.
                epoch=platform.sessionResolutionEpoch(session);
                if(epoch==0)epoch=platform.markSessionResolutionUnknown(session,"A session-local relation changed native name resolution");
                if(!platform.markSessionRelationVerified(session,epoch,catalog,schema,exact.exact(),MetadataSnapshot.PhysicalRelationKind.TEMPORARY))return new Classification(MetadataState.STALE,null);
                var current=platform.temporaryObservation(session,catalog,schema,exact.exact());
                return new Classification(MetadataState.AVAILABLE,MetadataSnapshot.PhysicalRelationKind.TEMPORARY,exact.exact(),exact.availability(),exact.provenance(),definition,current,catalog,schema,exact.exact(),false,ObjectKind.TABLE);
            }catch(Exception unavailable){
                // The deferred-retirement candidate is not reusable after a
                // cancelled, failed, or otherwise incomplete observation.
                retireObservation(platform,session,catalog,schema,name,"Native temporary identity observation did not complete");
                if(job!=null)job.checkCancel();
                if(session.state==TransactionState.UNKNOWN_TRANSACTION||unavailable instanceof CancellationException||unavailable instanceof InterruptedException)throw unavailable;
                if(unavailable instanceof WorkbenchFailure failure&&failure.reason()==WorkbenchFailure.Reason.CANCELLED)throw failure;
                if(io.grpc.Context.current().isCancelled()||Thread.currentThread().isInterrupted())throw new CancellationException("Physical relation classification cancelled");
                platform.markSessionResolutionUnknown(session,"Native comparison evidence could not be acquired for the observed temporary relation");
                MetadataState state=unavailable instanceof WorkbenchFailure failure?switch(failure.reason()){
                    case DENIED->MetadataState.DENIED;case TIMED_OUT->MetadataState.TIMED_OUT;case STALE,INVALID_REVISION->MetadataState.STALE;case UNSUPPORTED->MetadataState.UNSUPPORTED;default->MetadataState.UNAVAILABLE;
                }:unavailable instanceof SQLTimeoutException||unavailable instanceof TimeoutException?MetadataState.TIMED_OUT:MetadataState.UNAVAILABLE;
                return new Classification(state,null);
            }
        }
        if(result.kind()==MetadataSnapshot.PhysicalRelationKind.PERSISTENT){
            // Exact identifiers still come from the selected central object.
            // The fixed native SHOW proves this physical resolution is a table
            // or view; its first display column never supplies a stored name.
            var rules=platform.capture(session).rules();var kind=result.nativeObjectKind();
            if(observed==null||observed.nameAvailability()!=MetadataState.AVAILABLE||kind!=ObjectKind.TABLE&&kind!=ObjectKind.VIEW){
                retireObservation(platform,session,catalog,schema,name,"Native persistent relation identity was unavailable");return new Classification(MetadataState.UNAVAILABLE,null);
            }
            // A fully drained, recognized persistent header does not establish
            // identifier authority while central rules are still uninspected.
            // Leave existing physical-resolution authority unchanged: no rule
            // bootstrap, verified entry, publication, or UNKNOWN upgrade.
            if(!rules.complete()||!rules.kindAvailable(kind))return new Classification(MetadataState.UNAVAILABLE,null);
            if(!observed.catalog().isEmpty()&&!rules.matches(ObjectKind.CATALOG,observed.catalog(),catalog,true)
                    ||!rules.matches(kind,observed.name(),name,true)){
                retireObservation(platform,session,catalog,schema,name,"Native persistent relation target changed");return new Classification(MetadataState.STALE,null);
            }
        }
        if(epoch==0&&result.kind()!=MetadataSnapshot.PhysicalRelationKind.PERSISTENT)epoch=platform.markSessionResolutionUnknown(session,"A session-local relation changed native name resolution");
        if(!platform.markSessionRelationVerified(session,epoch,catalog,schema,name,result.kind()))return new Classification(MetadataState.STALE,null);
        return result;
    }
    /** Actual renderer variables belong to this physical owner. Stale raw SET
     * effects never acquire a digest under a cached context's SQL modes. */
    private static String renderer(SessionRegistry.Session session,String expectedMode,long deadline,Jobs.Job job)throws Exception{
        String sql=session.profile.getEngine()==Engine.MYSQL?"SELECT @@session.sql_mode,@@session.sql_quote_show_create,@@session.show_gipk_in_create_table_and_information_schema":"SELECT @@session.sql_mode,@@session.sql_quote_show_create";
        return query(session,sql,deadline,job,(statement,check)->{
            statement.setMaxRows(2);
            try(var rows=statement.executeQuery()){
                check.run();if(!rows.next())throw new SQLException("Native source renderer is unavailable");
                String actualMode=rows.getString(1),quote=rows.getString(2),gipk=session.profile.getEngine()==Engine.MYSQL?rows.getString(3):"N/A";
                check.run();if(rows.next())throw new SQLException("Native source renderer is ambiguous");
                if(actualMode==null||actualMode.length()>4096||!actualMode.equals(expectedMode))throw new WorkbenchFailure(WorkbenchFailure.Reason.STALE);
                if(!Set.of("0","1").contains(quote)||!Set.of("0","1","N/A").contains(gipk))throw new SQLException("Native source renderer is unavailable");
                return "quote="+quote+";gipk="+gipk;
            }
        });
    }
    private static long retireObservation(MetadataPlatform platform,SessionRegistry.Session session,String catalog,String schema,String name,String reason){
        long epoch=platform.sessionResolutionEpoch(session);
        if(epoch==0)return platform.markSessionResolutionUnknown(session,reason);
        platform.invalidateSessionRelation(session,catalog,schema,name);return platform.sessionResolutionEpoch(session);
    }
    @FunctionalInterface public interface Check {void run()throws Exception;}
    @FunctionalInterface public interface NativeQuery<T> {T run(PreparedStatement statement,Check check)throws Exception;}
    @FunctionalInterface public interface NativeOperation<T> {T run(Check check)throws Exception;}
    /**
     * Shared physical read envelope for bounded central readers which create
     * nested JDBC statements. The prepared anchor is never executed. Existing
     * Session.cancel also sends native physical cancellation, so the envelope
     * controls the current operation, including driver metadata reads.
     */
    public static <T> T operation(SessionRegistry.Session session,long deadline,Jobs.Job job,NativeOperation<T> action)throws Exception {
        if(!session.lock.isHeldByCurrentThread())throw new IllegalStateException("Physical-session ownership is required for native metadata");
        if(job!=null)job.checkCancel();
        try(var read=new Read(session,session.adapter.catalogStatement(session.connection,"SELECT 1"),Math.min(deadline,System.nanoTime()+TimeUnit.SECONDS.toNanos(10)),job)){
            read.check();T result=action.run(read::check);read.check();return result;
        }catch(Exception failure){
            if(failure instanceof SQLException sqlFailure)session.failure(sqlFailure,false);
            if(session.state==TransactionState.UNKNOWN_TRANSACTION)throw transactionUnknown(failure);
            throw failure;
        }
    }
    /** Shared owned read budget for native temporary inventory/structure. No independent connection. */
    public static <T> T query(SessionRegistry.Session session,String sql,long deadline,Jobs.Job job,NativeQuery<T> action)throws Exception {
        if(!session.lock.isHeldByCurrentThread())throw new IllegalStateException("Physical-session ownership is required for native metadata");
        if(job!=null)job.checkCancel();
        try(var read=new Read(session,session.adapter.catalogStatement(session.connection,sql),Math.min(deadline,System.nanoTime()+TimeUnit.SECONDS.toNanos(10)),job)){
            // SHOW may fall back to client preparation: a positive MySQL fetch
            // size is then merely a hint. Its explicit streaming sentinel is
            // required; pinned MariaDB uses StreamingResult for nonzero fetch.
            read.statement.setFetchSize(session.profile.getEngine()==Engine.MYSQL?Integer.MIN_VALUE:1);
            read.check();T result=action.run(read.statement,read::check);read.check();return result;
        }catch(Exception failure){
            if(failure instanceof SQLException sqlFailure)session.failure(sqlFailure,false);
            if(session.state==TransactionState.UNKNOWN_TRANSACTION)throw transactionUnknown(failure);
            throw failure;
        }
    }
    /** Preserve the first typed uncertainty boundary and its exact cause and cleanup diagnostics. */
    static WorkbenchFailure transactionUnknown(Exception failure){
        if(failure instanceof WorkbenchFailure unknown&&unknown.reason()==WorkbenchFailure.Reason.TRANSACTION_UNKNOWN)return unknown;
        var unknown=new WorkbenchFailure(WorkbenchFailure.Reason.TRANSACTION_UNKNOWN);unknown.initCause(failure);return unknown;
    }
    /** null means explicitly limited; no prefix is passed off as full source. */
    static String bounded(Reader reader,Check check)throws Exception {
        if(reader==null)throw new SQLException("Native temporary source is unavailable");
        var text=new StringBuilder();var chunk=new char[4096];long bytes=0;boolean surrogate=false;
        for(int count;(count=reader.read(chunk))!=-1;) {
            check.run();
            for(int index=0;index<count;index++) {
                char value=chunk[index];
                if(surrogate){if(!Character.isLowSurrogate(value))throw new SQLException("Invalid native source encoding","22021");bytes+=4;surrogate=false;}
                else if(Character.isHighSurrogate(value))surrogate=true;
                else if(Character.isLowSurrogate(value))throw new SQLException("Invalid native source encoding","22021");
                else bytes+=value<128?1:value<2048?2:3;
                if(bytes>65536||text.length()>=65536)return null;
                text.append(value);
            }
        }
        check.run();if(surrogate)throw new SQLException("Invalid native source encoding","22021");return text.toString();
    }
    private static final class Read implements AutoCloseable {
        final SessionRegistry.Session session;final PreparedStatement statement;final int networkTimeout;final Jobs.Job job;
        final Object fence=new Object();volatile boolean active=true,expired;Future<?> cancelling;
        final io.grpc.Context context=io.grpc.Context.current();final io.grpc.Context.CancellationListener listener;
        final ScheduledFuture<?> timeout;
        Read(SessionRegistry.Session session,String qualified,long deadline)throws Exception {this(session,qualified,deadline,null);}
        Read(SessionRegistry.Session session,String qualified,long deadline,Jobs.Job job)throws Exception {
            this(session,SchemaTools.nativeDefinitionStatement(session,"TABLE",qualified),deadline,job);
        }
        Read(SessionRegistry.Session session,PreparedStatement prepared,long deadline,Jobs.Job job)throws Exception {
            this.session=session;this.job=job;statement=prepared;
            try{networkTimeout=session.connection.getNetworkTimeout();}catch(Exception failure){try{statement.close();}catch(Exception cleanup){failure.addSuppressed(cleanup);}throw failure;}
            try{statement.setQueryTimeout(0);session.connection.setNetworkTimeout(control,(int)Math.max(1,Math.min(10_000,TimeUnit.NANOSECONDS.toMillis(Math.max(1,deadline-System.nanoTime())))));}
            catch(Exception failure){try{if(!session.connection.isClosed())session.connection.setNetworkTimeout(control,networkTimeout);}catch(Exception cleanup){failure.addSuppressed(cleanup);session.quarantine(cleanup);}try{statement.close();}catch(Exception cleanup){failure.addSuppressed(cleanup);}throw failure;}
            if(job!=null)synchronized(job){job.statementSession=session;job.statement=statement;}
            listener=ignored->cancel();context.addListener(listener,Runnable::run);
            timeout=deadlines.schedule(()->{expired=true;cancel();},Math.max(0,deadline-System.nanoTime()),TimeUnit.NANOSECONDS);
        }
        void cancel(){synchronized(fence){if(active&&cancelling==null)cancelling=control.submit(()->{try{session.cancel(statement,()->active);}catch(Exception failure){throw new CompletionException(failure);}});}}
        void check()throws Exception {if(job!=null)job.checkCancel();if(expired)throw new SQLTimeoutException("Owned temporary source deadline exceeded");if(context.isCancelled()||Thread.currentThread().isInterrupted())throw new CancellationException("Owned temporary source cancelled");}
        @Override public void close()throws Exception {
            Future<?> pending;synchronized(fence){active=false;pending=cancelling;}context.removeListener(listener);timeout.cancel(false);
            Future<?> jobCancellation=null;if(job!=null)synchronized(job){if(job.statement==statement){job.statement=null;jobCancellation=job.cancelFinished;}}
            long cleanupDeadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(6);
            boolean interrupted=Thread.interrupted();Exception failure=null;
            try {
                for(var cancellation:List.of(pending==null?CompletableFuture.completedFuture(null):pending,jobCancellation==null?CompletableFuture.completedFuture(null):jobCancellation))try{cancellation.get(Math.max(1,cleanupDeadline-System.nanoTime()),TimeUnit.NANOSECONDS);}catch(Exception unsettled){if(failure==null)failure=unsettled;else failure.addSuppressed(unsettled);session.quarantine(unsettled);}
                try{statement.close();}catch(Exception cleanup){session.quarantine(cleanup);if(failure==null)failure=cleanup;else failure.addSuppressed(cleanup);}
                if(!session.physicalEnded())try{session.connection.setNetworkTimeout(control,networkTimeout);if(pending!=null||job!=null&&job.cancel.get())session.validateAfterCancellation();}catch(SQLException cleanup){session.quarantine(cleanup);if(failure==null)failure=cleanup;else failure.addSuppressed(cleanup);}
            }finally{if(interrupted)Thread.currentThread().interrupt();}
            if(failure!=null)throw failure;
        }
    }
}
