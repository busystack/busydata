package io.busystack.busydata.schema;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.sessions.SessionRegistry;
import io.busystack.busydata.storage.MetadataStore;
import io.busystack.busydata.results.ResultStore;
import java.util.*;

/** Recovery stores verified snapshots in Java metadata; no connection or SQL replay. */
public final class EditDrafts {
 private final MetadataStore metadata;private final ResultStore results;private final ChangePlanner planner;
 public EditDrafts(MetadataStore metadata,ResultStore results,ChangePlanner planner){this.metadata=metadata;this.results=results;this.planner=planner;}
 private EditDraftInfo info(MetadataStore.EditDraftRecord record){var data=record.data();return EditDraftInfo.newBuilder().setDraftId(record.id()).setDocumentId(data.getDocumentId()).setTarget(data.getTarget()).setSchema(data.getChanges().getSchema()).setTable(data.getChanges().getTable()).setChanges(data.getChanges().getChangesCount()).setState(record.state()).setCreatedUnixMs(record.created()).build();}
 public EditDraftReply run(SessionRegistry sessions,EditDraftRequest request)throws Exception{
  if(request.getDraftId().length()>128||request.getDocumentId().length()>128)throw new IllegalArgumentException("Invalid recovery identifier");
  switch(request.getAction()){
   case SAVE_EDIT_DRAFT->{
    if(!request.getSessionId().equals(request.getChanges().getSessionId()))throw new IllegalArgumentException("Recovery session ownership mismatch");
    var data=planner.captureDraft(sessions.get(request.getSessionId()),request.getChanges(),request.getDocumentId());
    String id=metadata.saveEditDraft(request.getDraftId(),data);return EditDraftReply.newBuilder().addDrafts(info(metadata.editDraft(id))).build();
   }
   case DELETE_EDIT_DRAFT->metadata.deleteEditDraft(request.getDraftId());
   case REBIND_EDIT_DRAFT->{return rebind(sessions.get(request.getSessionId()),request);}
   case LIST_EDIT_DRAFTS->{}
   default->throw new IllegalArgumentException("Unknown edit recovery operation");
  }
  var reply=EditDraftReply.newBuilder();for(var record:metadata.editDrafts())reply.addDrafts(info(record));return reply.build();
 }
 private EditDraftReply rebind(SessionRegistry.Session session,EditDraftRequest request)throws Exception{
  var record=metadata.editDraft(request.getDraftId());var data=record.data();
  if(!record.state().equals("STAGED"))throw new IllegalStateException("This edit batch was committed or has an uncertain outcome. Reconcile actual database contents; recovery never replays it.");
  var target=data.getTarget();var actual=session.profile;
  if(actual.getReadOnly()||actual.getEngine()!=target.getEngine()||!actual.getHost().equals(target.getHost())||actual.getPort()!=target.getPort()||!actual.getUser().equals(target.getUser())||!session.context.catalog().equals(target.getDatabase()))throw new IllegalArgumentException("Connect an explicitly writable console to the exact original engine, endpoint, database and user before rebinding staged edits");
  if(!session.lock.tryLock())throw new IllegalStateException("The selected console is busy");
  try{
   if(session.state!=TransactionState.IDLE||!session.autoCommit)throw new IllegalStateException("Finish the console transaction before rebinding recovery");
   var changes=data.getChanges().toBuilder().setSessionId(session.id).clearContext().setRecoveryId(record.id());
   var platform=metadata.metadataPlatform();
   try(var inspection=platform.inspectTable(session,changes.getCatalog(),changes.getSchema(),changes.getTable(),data.getColumnsList())){
   var proofFence=platform.proofFence(session);
   if(!inspection.structure().recoverySignature().equals(data.getSchemaSignature()))throw new IllegalStateException("Table metadata changed since staging. The saved edits are preserved; inspect and reconcile them before creating a new batch.");
   // Explicit rebind has verified the durable recovery shape and exact target.
   // It reconstructs current physical proof for a fresh review; SQL is not replayed.
   boolean timestamp=session.profile.getEngine()!=Engine.POSTGRESQL&&data.getColumnsList().stream().anyMatch(column->column.getTypeName().equalsIgnoreCase("TIMESTAMP")||column.getTypeName().toUpperCase(java.util.Locale.ROOT).startsWith("TIMESTAMP("));
   if(timestamp){String captured=data.hasSourceTimeZone()&&data.hasSourceSystemTimeZone()?io.busystack.busydata.metadata.TimestampContext.key(data.getSourceTimeZone(),data.getSourceSystemTimeZone()):"",current=io.busystack.busydata.metadata.TimestampContext.key(session.context);if(captured.isEmpty()||current.isEmpty())throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.UNSUPPORTED);if(!captured.equals(current))throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.STALE);}
   var metadataProof=inspection.proof();
   if(!metadataProof.available())throw new io.busystack.busydata.rpc.WorkbenchFailure(metadataProof.state()==io.busystack.busydata.metadata.MetadataState.UNSUPPORTED?io.busystack.busydata.rpc.WorkbenchFailure.Reason.UNSUPPORTED:metadataProof.state()==io.busystack.busydata.metadata.MetadataState.DENIED?io.busystack.busydata.rpc.WorkbenchFailure.Reason.DENIED:io.busystack.busydata.rpc.WorkbenchFailure.Reason.INCOMPLETE_METADATA);
   verifyArrayRecovery(session,data,inspection);
   var rawColumns=data.getColumnsList().stream().map(column->column.toBuilder().clearMetadataIdentity().clearMetadataSnapshotRevision().build()).toList();
   var result=results.create(rawColumns,session.profile,session.id);
   try{
    if(!data.hasStandardConformingStrings())throw new IllegalStateException("Saved edit recovery lacks the original SQL quoting context. The record is preserved; reconcile it with the original document before creating a fresh batch.");
    result.sourceLexical=session.profile.getEngine()==Engine.POSTGRESQL?new io.busystack.busydata.analysis.LexicalSettings(false,false,data.getStandardConformingStrings()):io.busystack.busydata.analysis.LexicalSettings.mysql(data.getSourceSqlMode());
    result.sourceSql=data.getSourceSql();result.captureSql(data.getSourceSql());result.documentId=request.getDocumentId();result.jobId="recovery-"+UUID.randomUUID();result.executionId=UUID.randomUUID().toString();result.jobState=JobState.COMPLETED;
    var ordinals=new HashMap<Long,Long>();for(var row:data.getRowsList()){ordinals.put(row.getSourceRow(),result.rows());result.append(io.busystack.busydata.results.RetainedEditValues.retainRow(result,row.getRow()));}
    result.complete=true;result.fetchFinished=true;changes.setResultId(result.id).clearChanges();
    for(var change:data.getChanges().getChangesList()){var next=change.toBuilder();if(change.getKind()!=ChangeKind.INSERT||ordinals.containsKey(change.getSourceRow())){Long ordinal=ordinals.get(change.getSourceRow());if(ordinal==null)throw new IllegalStateException("Verified recovery row is unavailable; record preserved");next.setSourceRow(ordinal);}changes.addChanges(next);}
    inspection.checkCurrent();try(var prepared=results.prepareProof(result,metadataProof)){platform.publishRetainedProof(session,proofFence,prepared);}
    if(!result.metadataProof().available())throw new io.busystack.busydata.rpc.WorkbenchFailure(result.metadataProof().state()==io.busystack.busydata.metadata.MetadataState.STALE?io.busystack.busydata.rpc.WorkbenchFailure.Reason.STALE:io.busystack.busydata.rpc.WorkbenchFailure.Reason.UNAVAILABLE);
    if(session.profile.getEngine()==Engine.MARIADB){var witness=inspection.captureWitness(null);if(witness==null)throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.INCOMPLETE_METADATA);if(!result.attachMetadataWitness(witness)){witness.close();throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.INCOMPLETE_METADATA);}}
    var rebound=changes.build();var refreshed=data.toBuilder().setChanges(rebound.toBuilder().clearRecoveryId()).setDocumentId(request.getDocumentId()).build();
    inspection.checkCurrent();metadata.saveEditDraft(record.id(),refreshed);
    return EditDraftReply.newBuilder().addDrafts(info(metadata.editDraft(record.id()))).setChanges(rebound).setResult(result.retained()).build();
   }catch(Exception error){try{result.close();}catch(Exception cleanup){error.addSuppressed(cleanup);}throw error;}
   }
  }finally{session.lock.unlock();}
 }
 private static void verifyArrayRecovery(SessionRegistry.Session session,StoredEditDraft data,io.busystack.busydata.metadata.MetadataPlatform.TableInspection inspection){
  if(session.profile.getEngine()!=Engine.POSTGRESQL)return;
  for(var column:data.getColumnsList())if(column.getJdbcType()==java.sql.Types.ARRAY){
   var found=inspection.structure().columns().stream().filter(value->value.getName().equals(column.getBaseColumn())).toList();
   if(found.size()!=1)throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.INCOMPLETE_METADATA);
   var structural=inspection.typeEvidence(found.getFirst());String element=structural.getPropertiesOrDefault("arrayElementType","");
   if(structural.getPropertiesOrDefault("arrayElementKind","").equals("d"))element=structural.getPropertiesOrDefault("arrayElementBaseName","");
   if(!Set.of("date","timestamp","timestamptz").contains(element))continue;
   // Older records have no DateStyle field. Prove their exact stored literal
   // uses the supported ISO form rather than assigning the current context to
   // an ambiguous historic text representation. No value is transformed.
   for(var saved:data.getRowsList()){
    int index=column.getOrdinal()-1;if(index<0||index>=saved.getRow().getValuesCount())throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.MALFORMED_REQUEST);
    var value=saved.getRow().getValues(index);if(!value.hasArray()||!value.getArray().getNativeBinary().isEmpty())continue;
    try{io.busystack.busydata.results.ArrayAssignments.convert(value,structural);}
    catch(IllegalArgumentException unsupported){throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.UNSUPPORTED);}
   }
  }
 }
}
