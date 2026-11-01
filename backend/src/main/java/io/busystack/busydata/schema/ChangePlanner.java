package io.busystack.busydata.schema;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.metadata.TableStructure;
import io.busystack.busydata.results.Values;
import io.busystack.busydata.results.ResultStore;
import io.busystack.busydata.sessions.SessionRegistry;
import io.busystack.busydata.jobs.Jobs;
import io.busystack.busydata.rpc.WorkbenchFailure;
import io.busystack.busydata.safety.Safety;
import java.sql.*;
import java.util.*;
import java.util.concurrent.*;

/** Editing uses retained row ordinals and verified base identity, never labels. */
public final class ChangePlanner {
    private record Parameter(Value value,int type,int arrayOid){}
    private record Command(String sql,List<Parameter> parameters){}
    private record Plan(ChangeRequest request,List<Command> commands,String metadata,long expiry,int bytes){}
    private record Source(ResultStore.Result result,Map<Integer,Column> columns){}
    private final ConcurrentMap<String,Plan> plans=new ConcurrentHashMap<>();
    private final Safety safety;
    private final ResultStore results;
    private final io.busystack.busydata.metadata.MetadataPlatform metadataPlatform;
    public ChangePlanner(Safety safety,ResultStore results,io.busystack.busydata.metadata.MetadataPlatform metadataPlatform){this.safety=safety;this.results=results;this.metadataPlatform=metadataPlatform;}

    /** Same provenance/identity rules as preview, with no synthetic mutation or approval. */
    public Editability assess(SessionRegistry.Session session,ChangeRequest request)throws Exception {
        if(session.profile.getReadOnly())return notEditable(WorkbenchFailure.Reason.READ_ONLY_POLICY);
        if(session.state==TransactionState.UNKNOWN_TRANSACTION)return notEditable(WorkbenchFailure.Reason.TRANSACTION_UNKNOWN);
        if(request.getChangesCount()!=0)throw new WorkbenchFailure(WorkbenchFailure.Reason.MALFORMED_REQUEST);
        if(!session.lock.tryLock())return notEditable(WorkbenchFailure.Reason.SESSION_BUSY);
        try {
            var source=verifySource(session,request);try(var inspection=table(session,source)){
            var table=inspection.structure();verifyMetadataProof(session,source,inspection);verifyValueIdentities(session,source,table);
            var projected=new HashSet<String>();for(var column:source.columns().values())projected.add(column.getBaseColumn());
            if(table.identities().stream().noneMatch(projected::containsAll))return notEditable(WorkbenchFailure.Reason.EDIT_IDENTITY_REQUIRED);
            var assessment=Editability.newBuilder().setEditable(true);
            for(var column:source.columns().values())if(!column.getReadOnly()&&!table.generated().contains(column.getBaseColumn()))assessment.addEditableColumns(column.getOrdinal());
            if(assessment.getEditableColumnsCount()==0)return notEditable(WorkbenchFailure.Reason.EDIT_COLUMNS_READ_ONLY);
            inspection.checkCurrent();return assessment.build();
            }
        } catch(WorkbenchFailure failure){return notEditable(failure.reason());}
        catch(ResultStore.Unavailable failure){return notEditable(WorkbenchFailure.Reason.RESULT_DISPOSED);}
        catch(io.busystack.busydata.metadata.MetadataLimit failure){return notEditable(WorkbenchFailure.Reason.INCOMPLETE_METADATA);}
        catch(io.busystack.busydata.schema.EditValues.Failure failure){return notEditable(failure.code()==EditValues.Code.UNSUPPORTED?WorkbenchFailure.Reason.UNSUPPORTED:failure.code()==EditValues.Code.METADATA_UNAVAILABLE?WorkbenchFailure.Reason.INCOMPLETE_METADATA:WorkbenchFailure.Reason.MALFORMED_REQUEST);}
        catch(CancellationException failure){return notEditable(WorkbenchFailure.Reason.CANCELLED);}
        catch(RejectedExecutionException failure){return notEditable(WorkbenchFailure.Reason.UNAVAILABLE);}
        // Unknown local assessment failures disclose neither exception text nor
        // an inferred permission/projection cause. Typed subclasses win above.
        catch(IllegalArgumentException|IllegalStateException failure){return notEditable(WorkbenchFailure.Reason.UNAVAILABLE);}
        finally{session.lock.unlock();}
    }

    private static Editability notEditable(WorkbenchFailure.Reason reason){return Editability.newBuilder().setReasonCode(reason.wire()).build();}

    private Source verifySource(SessionRegistry.Session session,ChangeRequest request)throws Exception {
        var result=results.get(request.getResultId());
        if(!result.sourceSessionId.equals(session.id))throw new WorkbenchFailure(WorkbenchFailure.Reason.INVALID_OWNER);
        if(!result.fetchFinished)throw new WorkbenchFailure(WorkbenchFailure.Reason.EDIT_RESULT_NOT_READY);
        if(result.columns.isEmpty())throw new WorkbenchFailure(WorkbenchFailure.Reason.EDIT_PROJECTION_UNSUPPORTED);
        var first=result.columns.getFirst();
        String firstScope=session.profile.getEngine()==Engine.POSTGRESQL?first.getSchema():first.getCatalog();
        var names=new HashSet<String>();var columns=new LinkedHashMap<Integer,Column>();
        int expected=1;
        for(var column:result.columns){
            String scope=session.profile.getEngine()==Engine.POSTGRESQL?column.getSchema():column.getCatalog();
            String requestedScope=session.profile.getEngine()==Engine.POSTGRESQL?request.getSchema():
                request.getCatalog().isEmpty()?request.getSchema():request.getCatalog();
            if(!column.getProvenanceKnown()||column.getBaseColumn().isEmpty())
                throw new WorkbenchFailure(WorkbenchFailure.Reason.EDIT_PROJECTION_UNSUPPORTED);
            if(!column.getTable().equals(request.getTable())||!scope.equals(requestedScope)){
                // A valid projection from several relations is unsupported;
                // a request naming another target is malformed. Neither can
                // expose the retained metadata proof or inspect native JDBC.
                if(first.getTable().equals(request.getTable())&&firstScope.equals(requestedScope)&&
                        (!column.getTable().equals(first.getTable())||!scope.equals(firstScope)))
                    throw new WorkbenchFailure(WorkbenchFailure.Reason.EDIT_PROJECTION_UNSUPPORTED);
                throw new WorkbenchFailure(WorkbenchFailure.Reason.MALFORMED_REQUEST);
            }
            if(column.getOrdinal()!=expected++)throw new WorkbenchFailure(WorkbenchFailure.Reason.MALFORMED_REQUEST);
            if(!names.add(column.getBaseColumn()))throw new WorkbenchFailure(WorkbenchFailure.Reason.EDIT_PROJECTION_UNSUPPORTED);
            columns.put(column.getOrdinal(),column);
        }
        for(var change:request.getChangesList()){
            if(!columns.keySet().containsAll(change.getValuesMap().keySet()))
                throw new WorkbenchFailure(WorkbenchFailure.Reason.MALFORMED_REQUEST);
            if(change.getKind()!=ChangeKind.INSERT)result.read(change.getSourceRow());
        }
        // Ownership and exact retained ordinals win before exposing a proof
        // failure. An already-unavailable proof needs no reparse or native SQL.
        var retained=result.metadataProof();if(!retained.capturedStructure())throw metadataFailure(retained.state());
        try {
            var parsed=io.busystack.busydata.analysis.SqlParsing.parse(result.sourceSql,session.profile.getEngine(),result.sourceLexical);
            if(!(parsed instanceof net.sf.jsqlparser.statement.select.PlainSelect body))throw new WorkbenchFailure(WorkbenchFailure.Reason.EDIT_PROJECTION_UNSUPPORTED);
            if(!(body.getFromItem() instanceof net.sf.jsqlparser.schema.Table)||body.getDistinct()!=null||
                body.getGroupBy()!=null||body.getHaving()!=null||
                (body.getJoins()!=null&&!body.getJoins().isEmpty())||
                (body.getWithItemsList()!=null&&!body.getWithItemsList().isEmpty()))throw new WorkbenchFailure(WorkbenchFailure.Reason.EDIT_PROJECTION_UNSUPPORTED);
        }catch(CancellationException|RejectedExecutionException control){throw control;}
        catch(net.sf.jsqlparser.JSQLParserException error){
            int depth=0;for(Throwable cause=error;cause!=null&&depth++<16;cause=cause.getCause()){
                if(cause instanceof InterruptedException){Thread.currentThread().interrupt();throw new WorkbenchFailure(WorkbenchFailure.Reason.CANCELLED);}
                if(cause instanceof CancellationException)throw new WorkbenchFailure(WorkbenchFailure.Reason.CANCELLED);
                if(cause instanceof TimeoutException)throw new WorkbenchFailure(WorkbenchFailure.Reason.TIMED_OUT,WorkbenchFailure.Origin.SOURCE_PARSE);
                if(cause instanceof RejectedExecutionException)throw new WorkbenchFailure(WorkbenchFailure.Reason.UNAVAILABLE);
                if(cause.getCause()==cause)break;
            }
            throw new WorkbenchFailure(WorkbenchFailure.Reason.EDIT_PROJECTION_UNSUPPORTED);
        }catch(IllegalArgumentException error){throw new WorkbenchFailure(WorkbenchFailure.Reason.EDIT_PROJECTION_UNSUPPORTED);}
        return new Source(result,Map.copyOf(columns));
    }

    private io.busystack.busydata.metadata.MetadataPlatform.TableInspection table(SessionRegistry.Session session,Source source)throws Exception {
        var retained=source.result().metadataProof();
        return metadataPlatform.inspectTable(session,retained.catalog(),retained.schema(),retained.table(),source.result().columns);
    }

    private static void verifyValueIdentities(SessionRegistry.Session session,Source source,TableStructure table){
        var projected=new HashSet<String>();for(var column:source.columns().values())projected.add(column.getBaseColumn());
        for(var column:table.columns())if(projected.contains(column.getName()))EnumSetAssignments.verifyRetainedIdentity(column,session.profile.getEngine());
    }

    private static io.busystack.busydata.rpc.WorkbenchFailure metadataFailure(io.busystack.busydata.metadata.MetadataState state){
        return new io.busystack.busydata.rpc.WorkbenchFailure(switch(state){
            case DENIED->io.busystack.busydata.rpc.WorkbenchFailure.Reason.DENIED;
            case UNSUPPORTED->io.busystack.busydata.rpc.WorkbenchFailure.Reason.UNSUPPORTED;
            case STALE->io.busystack.busydata.rpc.WorkbenchFailure.Reason.STALE;
            case TIMED_OUT->io.busystack.busydata.rpc.WorkbenchFailure.Reason.TIMED_OUT;
            case CANCELLED->io.busystack.busydata.rpc.WorkbenchFailure.Reason.CANCELLED;
            case UNAVAILABLE,FAILED->io.busystack.busydata.rpc.WorkbenchFailure.Reason.UNAVAILABLE;
            default->io.busystack.busydata.rpc.WorkbenchFailure.Reason.INCOMPLETE_METADATA;
        },io.busystack.busydata.rpc.WorkbenchFailure.Origin.RETAINED_PROOF);
    }
    private void verifyMetadataProof(SessionRegistry.Session session,Source source,io.busystack.busydata.metadata.MetadataPlatform.TableInspection inspected)throws Exception{
        var captured=source.result().metadataProof();
        if(!captured.capturedStructure())throw metadataFailure(captured.state());
        var current=inspected.proof();
        if(!current.available())throw metadataFailure(current.state());
        if(!captured.samePhysicalStructure(current))
            throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.STALE,io.busystack.busydata.rpc.WorkbenchFailure.Origin.RETAINED_PROOF);
        source.result().verifyMetadataWitness(session,null);
    }

    private static Map<String,Value> originals(Source source,Row row){
        var values=new TreeMap<String,Value>();
        for(var column:source.columns().values())values.put(column.getBaseColumn(),row.getValues(column.getOrdinal()-1));
        return values;
    }

    private static boolean needsRetainedProof(StagedChange change){
        return change.getValuesMap().values().stream().anyMatch(assignment->assignment.hasValue()&&(assignment.getValue().hasArray()||assignment.getValue().hasEngineValue()));
    }
    private static Parameter parameter(SessionRegistry.Session session,Value value,SchemaObject column,int jdbcType){
        if(column==null)throw new IllegalArgumentException("Verified native column metadata is unavailable");
        int arrayOid=0;
        if(value.hasArray())try{io.busystack.busydata.results.ArrayParameters.requireContext(value,session.context,column.getPropertiesOrDefault("arrayElementBaseName","").isEmpty()?column.getPropertiesOrDefault("arrayElementType",""):column.getPropertiesOrDefault("arrayElementBaseName",""));arrayOid=Integer.parseUnsignedInt(column.getPropertiesOrDefault("nativeTypeId",""));}catch(java.sql.SQLFeatureNotSupportedException unsupported){throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.UNSUPPORTED);}catch(NumberFormatException unavailable){throw new IllegalArgumentException("Verified native array type identity is unavailable");}
        // Domain values keep native type identity in metadata; pgJDBC accepts the
        // exact bound representation through OTHER rather than JDBC DISTINCT.
        int material=jdbcType==Types.DISTINCT||Set.of("e","d").contains(column.getPropertiesOrDefault("nativeTypeKind",""))||value.hasEngineValue()&&!column.getPropertiesOrDefault("nativeTypeId","").isEmpty()?Types.OTHER:jdbcType;
        return new Parameter(value,material,arrayOid);
    }
    private static Parameter assignmentParameter(SessionRegistry.Session session,Value value,SchemaObject column,int jdbcType){
        var bound=EnumSetAssignments.bound(value,column,session.profile.getEngine());
        return parameter(session,bound,column,bound==value?jdbcType:Types.NUMERIC);
    }

    private static Profile target(SessionRegistry.Session session,ChangeRequest request){
        String database=session.profile.getEngine()==Engine.POSTGRESQL?session.context.catalog():request.getCatalog().isEmpty()?request.getSchema():request.getCatalog();
        return session.profile.toBuilder().setDatabase(database).build();
    }

    public ChangePlan preview(SessionRegistry.Session session,ChangeRequest request)throws Exception {
        if(session.profile.getReadOnly())throw new IllegalArgumentException("Profile is read-only");
        if(request.getChangesCount()<1||request.getChangesCount()>1000)throw new IllegalArgumentException("Stage 1–1000 changes");
        if(!session.lock.tryLock())throw new IllegalStateException("Session is busy");
        try {
            var source=verifySource(session,request);try(var inspection=table(session,source)){
            var table=inspection.structure();verifyMetadataProof(session,source,inspection);verifyValueIdentities(session,source,table);
            var nativeColumns=new HashMap<String,SchemaObject>();for(var column:table.columns())nativeColumns.put(column.getName(),column);
            String target=session.adapter.table(request.getCatalog(),request.getSchema(),request.getTable());
            var commands=new ArrayList<Command>();var reviewedChanges=new ArrayList<ReviewedChange>();int reviewBytes=0;
            var valueBudget=new io.busystack.busydata.results.RetainedEditValues.Budget();
            for(var change:request.getChangesList()){
                var changed=new TreeMap<String,ValueAssignment>();
                Row proofRow=change.getKind()!=ChangeKind.INSERT||needsRetainedProof(change)?io.busystack.busydata.results.RetainedEditValues.row(source.result(),change.getSourceRow(),valueBudget):null;
                var original=change.getKind()==ChangeKind.INSERT?Map.<String,Value>of():originals(source,proofRow);
                for(var entry:change.getValuesMap().entrySet()){
                    var column=source.columns().get(entry.getKey());String name=column.getBaseColumn();
                    if(!table.types().containsKey(name)||table.generated().contains(name)||column.getReadOnly())
                        throw new IllegalArgumentException("Changed column is unknown, generated or read-only: "+name);
                    if(entry.getValue().getAssignmentCase()==ValueAssignment.AssignmentCase.ASSIGNMENT_NOT_SET)continue;
                    var assignment=entry.getValue();var nativeColumn=nativeColumns.get(name);
                    if(nativeColumn==null)throw new IllegalArgumentException("Verified native column metadata is unavailable");
                    if(assignment.hasNullValue()&&Set.of("NO","FALSE","0").contains(nativeColumn.getPropertiesOrDefault("nullable","").toUpperCase(Locale.ROOT)))throw new IllegalArgumentException("NULL cannot be assigned to a nonnullable column");
                    if(assignment.hasValue()){
                        Assignments.value(assignment.getValue());
                        var evidence=inspection.typeEvidence(nativeColumn);
                        var canonical=EditValues.convert(assignment.getValue(),evidence,session.profile.getEngine(),proofRow==null?null:proofRow.getValues(column.getOrdinal()-1));
                        if(canonical.hasArray())io.busystack.busydata.results.ArrayParameters.validate(canonical);
                        valueBudget.reserve(canonical.getSerializedSize()+8L);
                        assignment=Assignments.value(canonical);
                    }
                    changed.put(name,assignment);
                }
                var names=new ArrayList<>(changed.keySet());var parameters=new ArrayList<Parameter>();String sql;
                if(change.getKind()==ChangeKind.INSERT){
                    sql=names.isEmpty()?"INSERT INTO "+target+(session.profile.getEngine()==Engine.POSTGRESQL?" DEFAULT VALUES":" () VALUES ()"):
                        "INSERT INTO "+target+" ("+String.join(",",names.stream().map(session.adapter::quote).toList())+") VALUES ("+String.join(",",names.stream().map(name->changed.get(name).hasDefaultValue()?"DEFAULT":"?").toList())+")";
                    for(var name:names)if(!changed.get(name).hasDefaultValue())parameters.add(assignmentParameter(session,Assignments.bound(changed.get(name)),nativeColumns.get(name),table.types().get(name)));
                }else {
                    if(table.identities().stream().noneMatch(identity->original.keySet().containsAll(identity)&&identity.stream().noneMatch(name->original.get(name).hasNullValue())))
                        throw new WorkbenchFailure(WorkbenchFailure.Reason.EDIT_IDENTITY_REQUIRED);
                    if(original.values().stream().anyMatch(Value::getTruncated))
                        throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.VALUE_TRUNCATED);
                    if(!table.types().keySet().containsAll(original.keySet()))throw new IllegalArgumentException("Retained base columns no longer match table metadata");
                    if(change.getKind()==ChangeKind.UPDATE){
                        if(names.isEmpty())throw new IllegalArgumentException("No changed values");
                        sql="UPDATE "+target+" SET "+String.join(",",names.stream().map(name->session.adapter.quote(name)+(changed.get(name).hasDefaultValue()?"=DEFAULT":"=?")).toList());
                        for(var name:names)if(!changed.get(name).hasDefaultValue())parameters.add(assignmentParameter(session,Assignments.bound(changed.get(name)),nativeColumns.get(name),table.types().get(name)));
                    }else if(change.getKind()==ChangeKind.DELETE)sql="DELETE FROM "+target;
                    else throw new IllegalArgumentException("Invalid change kind");
                    var conditions=new ArrayList<String>();
                    for(var entry:original.entrySet()){
                        var originalParameter=parameter(session,entry.getValue(),nativeColumns.get(entry.getKey()),table.types().get(entry.getKey()));
                        var predicate=RowVerification.predicate(session,session.adapter.quote(entry.getKey()),entry.getValue(),originalParameter.type(),originalParameter.arrayOid());
                        conditions.add(predicate.sql());
                        if(predicate.value()!=null)parameters.add(new Parameter(predicate.value(),predicate.jdbcType(),predicate.arrayOid()));
                    }
                    sql+=" WHERE "+String.join(" AND ",conditions);
                }
                var reviewed=ReviewedChange.newBuilder().setKind(change.getKind()).setSourceRow(change.getSourceRow()).putAllValues(changed);
                if(change.getKind()!=ChangeKind.INSERT)reviewed.putAllOriginal(original);
                reviewBytes+=reviewed.build().getSerializedSize()+sql.length()*3+8;
                if(reviewBytes>1_048_576)throw new IllegalArgumentException("Change review exceeds 1MiB; stage a smaller batch");
                reviewedChanges.add(reviewed.build());commands.add(new Command(sql,List.copyOf(parameters)));
            }
            inspection.checkCurrent();String id;long expiry=System.currentTimeMillis()+120_000;
            synchronized(plans){
                plans.entrySet().removeIf(entry->entry.getValue().expiry()<System.currentTimeMillis());
                long retained=plans.values().stream().mapToLong(Plan::bytes).sum();
                if(plans.size()>=32||retained+reviewBytes>8_388_608)throw new IllegalStateException("Change-review budget reached; finish or let prior previews expire before reviewing another batch");
                id=safety.issue(Safety.changeFingerprint(request,target(session,request),session.revision,table.signature()));
                plans.put(id,new Plan(request,List.copyOf(commands),table.signature(),expiry,reviewBytes));
            }
            return ChangePlan.newBuilder().setPlanId(id).addAllSql(commands.stream().map(Command::sql).toList())
                .addAllChanges(reviewedChanges).setTarget(target(session,request))
                .addRisks("Changes use verified base columns and server-retained original values. Optimistic predicates cover projected values; unselected fields are not checked. Conflicts roll back this batch; staged edits remain available.")
                .addRisks(session.profile.getEnvironment()==Environment.PRODUCTION?"PRODUCTION target":"Writable target").setExpiresUnixMs(expiry).build();
            }
        }finally{session.lock.unlock();}
    }

    /** Returns reviewed intentions; native uniqueness policy determines copied NULLs and omitted keys. */
    public StagedChange cloneRow(SessionRegistry.Session session,CloneRowRequest request)throws Exception {
        if(!session.lock.tryLock())throw new IllegalStateException("Session is busy");
        try {
            var target=ChangeRequest.newBuilder().setSessionId(request.getSessionId()).setResultId(request.getResultId())
                .setCatalog(request.getCatalog()).setSchema(request.getSchema()).setTable(request.getTable()).build();
            if(session.profile.getReadOnly()||!session.id.equals(request.getSessionId()))throw new IllegalArgumentException("Clone requires the editable source session");
            var source=verifySource(session,target);try(var inspection=table(session,source)){
            var table=inspection.structure();verifyMetadataProof(session,source,inspection);verifyValueIdentities(session,source,table);var row=io.busystack.busydata.results.RetainedEditValues.row(source.result(),request.getSourceRow(),new io.busystack.busydata.results.RetainedEditValues.Budget());
            var retained=new HashMap<String,Value>();for(var column:source.columns().values())if(!column.getReadOnly()&&!table.generated().contains(column.getBaseColumn()))retained.put(column.getBaseColumn(),row.getValues(column.getOrdinal()-1));
            var omitted=CloneRowPolicy.omitted(table,retained);
            var clone=StagedChange.newBuilder().setKind(ChangeKind.INSERT).setSourceRow(request.getSourceRow());
            for(var column:source.columns().values())if(!column.getReadOnly()&&!table.generated().contains(column.getBaseColumn())&&!omitted.contains(column.getBaseColumn()))
                clone.putValues(column.getOrdinal(),Assignments.value(row.getValues(column.getOrdinal()-1)));
            var staged=clone.build();if(staged.getSerializedSize()>io.busystack.busydata.results.RetainedEditValues.MAX_BYTES)throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.VALUE_TRUNCATED);inspection.checkCurrent();return staged;
            }
        }finally{session.lock.unlock();}
    }

    public StoredEditDraft captureDraft(SessionRegistry.Session session,ChangeRequest request,String document)throws Exception {
        var result=results.get(request.getResultId());try(var lease=result.lease()){
            var reviewed=preview(session,request);plans.remove(reviewed.getPlanId());safety.discard(reviewed.getPlanId());
            if(!session.lock.tryLock())throw new IllegalStateException("Session is busy");
            try{var source=verifySource(session,request);try(var inspection=table(session,source)){
                verifyMetadataProof(session,source,inspection);
                var data=StoredEditDraft.newBuilder().setChanges(request.toBuilder().clearContext().clearRecoveryId()).addAllColumns(result.columns).setSourceSql(result.sourceSql).setSourceSqlMode(result.sourceLexical.sqlMode()).setStandardConformingStrings(result.sourceLexical.standardConformingStrings()).setSourceTimeZone(session.context.timeZone()).setSourceSystemTimeZone(session.context.systemTimeZone())
                    .setTarget(target(session,request).toBuilder().clearCredentialRef()).setSchemaSignature(inspection.structure().recoverySignature()).setDocumentId(document);
                var rows=new TreeSet<Long>();for(var change:request.getChangesList())if(change.getKind()!=ChangeKind.INSERT||needsRetainedProof(change))rows.add(change.getSourceRow());
                var valueBudget=new io.busystack.busydata.results.RetainedEditValues.Budget(data.build().getSerializedSize());for(long index:rows){var row=io.busystack.busydata.results.RetainedEditValues.row(result,index,valueBudget);valueBudget.reserve(16);data.addRows(EditDraftRow.newBuilder().setSourceRow(index).setRow(row));}var stored=data.build();if(stored.getSerializedSize()>1048576)throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.VALUE_TRUNCATED);inspection.checkCurrent();return stored;
            }}finally{session.lock.unlock();}
        }
    }
    public Jobs.Job apply(SessionRegistry.Session session,ApplyRequest request,Jobs jobs)throws Exception {return apply(session,request,jobs,null);}
    public Jobs.Job apply(SessionRegistry.Session session,ApplyRequest request,Jobs jobs,io.busystack.busydata.storage.MetadataStore metadata)throws Exception {
        var plan=plans.remove(request.getPlanId());
        if(plan==null||!plan.request().getSessionId().equals(session.id)||plan.expiry()<System.currentTimeMillis())throw new IllegalArgumentException("Change plan is stale");
        return jobs.submitSql(session,request.getExecutionId(),"",job->{
            verifySource(session,plan.request());
            if(session.profile.getReadOnly())throw new IllegalArgumentException("Read-only profile rejects row changes");
            var currentSource=verifySource(session,plan.request());try(var inspection=table(session,currentSource)){
                var currentTable=inspection.structure();verifyMetadataProof(session,verifySource(session,plan.request()),inspection);
                inspection.checkCurrent();safety.consume(request.getPlanId(),Safety.changeFingerprint(plan.request(),target(session,plan.request()),session.revision,currentTable.signature()));
            }
            if(!session.connection.getAutoCommit()||session.state!=TransactionState.IDLE)throw new IllegalArgumentException("Finish the console transaction before applying a reviewed edit batch");
            String recovery=plan.request().getRecoveryId();
            if(!recovery.isEmpty()){
                if(metadata==null)throw new IllegalStateException("Edit recovery ownership is unavailable");
                var draft=metadata.editDraft(recovery);
                if(!draft.data().getChanges().toBuilder().clearContext().clearRecoveryId().build().equals(plan.request().toBuilder().clearContext().clearRecoveryId().build()))throw new IllegalStateException("Save changed staged edits before applying their recovery-bound plan");
                metadata.editDraftState(recovery,"STAGED","APPLYING");
            }
            boolean committed=false;
            try(var transaction=session.ownedTransaction()) {
                // Hold the target's native metadata lock through transaction
                // resolution. An external DROP/replacement cannot slip between
                // identity verification and the reviewed mutation.
                try(var identityLock=session.adapter.catalogStatement(session.connection,"SELECT 1 FROM "+session.adapter.table(plan.request().getCatalog(),plan.request().getSchema(),plan.request().getTable())+" LIMIT 0")){
                    identityLock.setQueryTimeout(session.profile.getQueryTimeoutSeconds()==0?60:session.profile.getQueryTimeoutSeconds());
                    job.statement=identityLock;job.checkCancel();try(var ignored=identityLock.executeQuery()){}
                }finally{job.statement=null;}
                var lockedStructure=metadataPlatform.readTableStructure(session,plan.request().getCatalog(),plan.request().getSchema(),plan.request().getTable());
                if(!lockedStructure.signature().equals(plan.metadata()))throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.STALE,io.busystack.busydata.rpc.WorkbenchFailure.Origin.LOCKED_STRUCTURE);
                results.get(plan.request().getResultId()).verifyMetadataWitness(session,job);
                int index=0;
                for(var command:plan.commands()){
                    job.checkCancel();
                    try(var statement=session.connection.prepareStatement(command.sql())){
                        statement.setQueryTimeout(session.profile.getQueryTimeoutSeconds()==0?60:session.profile.getQueryTimeoutSeconds());
                        job.statement=statement;int position=1;
                        var arrays=new ArrayList<java.sql.Array>();
                        try{
                            for(var parameter:command.parameters()){
                                if(parameter.value().hasArray())arrays.add(io.busystack.busydata.results.ArrayParameters.bind(statement,position++,parameter.value(),parameter.arrayOid(),session.context));
                                else Values.bind(statement,position++,parameter.value(),parameter.type());
                            }
                            job.checkCancel();long count=statement.executeLargeUpdate();if(count!=1)throw new SQLException("Optimistic conflict","40001");
                            job.result(StatementResult.newBuilder().setStatementIndex(index++).setUpdateCount(count).setComplete(true).build());
                        }finally{for(var array:arrays)try{array.free();}catch(SQLException ignored){/* Statement cleanup still runs; no execution is retried. */}}
                    }finally{job.statement=null;}
                }
                transaction.commit(job::beginCommit,job::commitAcknowledged);committed=true;
            }finally{
                if(!recovery.isEmpty()){
                    String state=committed?"COMMITTED":session.state==TransactionState.UNKNOWN_TRANSACTION||session.state==TransactionState.DISCONNECTED?"UNKNOWN_OUTCOME":"STAGED";
                    try{metadata.editDraftState(recovery,"APPLYING",state);}catch(Exception cleanup){job.message("Recovery outcome could not be saved; this record prohibits replay until reconciled");}
                }
            }
        });
    }
}
