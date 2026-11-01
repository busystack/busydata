package io.busystack.busydata;

import io.busystack.busydata.analysis.language.*;
import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.rpc.WorkbenchFailure;
import io.busystack.busydata.schema.*;
import io.busystack.busydata.sessions.SessionRegistry;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

class SmartMetadataInvalidationIT {
    @TempDir Path root;
    private static void phase(Map<String,Object> report,String name,MetadataPlatform platform,SessionRegistry.Session owner,io.busystack.busydata.results.ResultStore.Result source){
        var state=new LinkedHashMap<String,Object>();
        state.put("snapshotRevision",platform.publishedSnapshot(owner).revision());state.put("configurationRevision",platform.configuration(owner).revision());
        state.put("sessionRevision",owner.revision);state.put("contextRevision",owner.contextRevision);
        if(source!=null){var proof=source.metadataProof();state.put("sourceSnapshotRevision",proof.snapshotRevision());state.put("sourceConfigurationRevision",proof.configurationRevision());state.put("sourceState",proof.state().name());}
        report.put(name,state);
    }
    private static void recordJob(Map<String,Object> report,io.busystack.busydata.jobs.Jobs.Job job){
        report.put("jobState",job.state.name());report.put("failureOrigin",job.failureOrigin().name());
        String code=job.info().getErrorCode();report.put("failureReason",code.isEmpty()?"NONE":WorkbenchFailure.Reason.parse(code).map(Enum::name).orElse("OTHER"));
    }
    private static void seed(EngineFixture fixture,SessionRegistry.Session owner,String table)throws Exception {
        owner.lock.lock();try{try(var statement=owner.connection.createStatement()){statement.execute("CREATE TABLE "+table+"(id INTEGER PRIMARY KEY,n INTEGER)");statement.execute("INSERT INTO "+table+" VALUES(1,1)");}owner.refresh();owner.advanceRevision();}finally{owner.lock.unlock();}
    }
    private static ChangeRequest request(EngineFixture fixture,SessionRegistry.Session owner,io.busystack.busydata.results.ResultStore.Result source){
        var change=StagedChange.newBuilder().setKind(ChangeKind.UPDATE).setSourceRow(0).putValues(2,Assignments.value(Value.newBuilder().setSignedInteger("2").build()));
        return ChangeRequest.newBuilder().setSessionId(owner.id).setCatalog("busydata").setSchema(fixture.schema()).setTable("stable_rows").setResultId(source.id).addChanges(change).build();
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void unrelatedTableCreationPreservesKnownSourceAndNeverUpgradesUnknownSource(String engine)throws Exception{
        Path evidence=Files.createTempDirectory(Path.of("target"),"smart-metadata-invalidation-");
        var report=new LinkedHashMap<String,Object>();report.put("engine",engine);report.put("applyAttempts",0);report.put("previewSucceeded",false);
        var counter=new OwnedJdbcOperationCounter();Throwable problem=null;
        try(var f=new EngineFixture(root,engine,counter::connect)){
            var session=f.open();String stable=session.adapter.table("busydata",f.schema(),"stable_rows");
            // Establish native fixture structure without a racing smart task.
            seed(f,session,stable);
            var unknown=f.results.get(f.execute(session,"SELECT id,n FROM "+stable).info().getResults(0).getResultId());assertFalse(unknown.metadataProof().capturedStructure());
            f.warm(session,"stable_rows");var source=f.results.get(f.execute(session,"SELECT id,n FROM "+stable).info().getResults(0).getResultId());assertTrue(source.metadataProof().available(),source.metadataProof().toString());
            var platform=f.metadata.metadataPlatform();phase(report,"capturedKnownSource",platform,session,source);
            String copy=session.adapter.table("busydata",f.schema(),"copied_rows");String create=f.engine==Engine.POSTGRESQL?"CREATE TABLE "+copy+" (LIKE "+stable+" INCLUDING ALL)":"CREATE TABLE "+copy+" LIKE "+stable;
            var effects=DdlImpact.analyze(create,f.engine,session.context.lexical(),new ResolutionContext(session.context.catalog(),session.context.schema(),session.context.searchPath(),true,0,0));
            // Exercise precise invalidation before an asynchronous acquisition can conceal it.
            platform.markStaleEffects(session,effects,"Known unrelated table DDL");
            var stableColumns=new MetadataScope("busydata",f.schema(),"stable_rows",ObjectKind.COLUMN);
            assertTrue(platform.capture(session).complete(stableColumns,IntrospectionLevel.STRUCTURE));
            f.execute(session,create);assertTrue(platform.capture(session).complete(stableColumns,IntrospectionLevel.STRUCTURE));
            phase(report,"afterAcknowledgedDdl",platform,session,source);
            // Finish one explicit metadata acquisition before this fixture's first Apply.
            // Its reservation supersedes older background publication, never replays SQL.
            f.warm(session,"copied_rows");report.put("explicitFragmentRefreshes",1);
            var current=f.results.get(f.execute(session,"SELECT id,n FROM "+stable).info().getResults(0).getResultId());assertTrue(current.metadataProof().available(),current.metadataProof().toString());
            phase(report,"currentSource",platform,session,current);
            var planner=new ChangePlanner(f.safety,f.results,platform);var changes=request(f,session,current);
            var preview=planner.preview(session,changes);report.put("previewSucceeded",true);phase(report,"afterPreview",platform,session,current);
            counter.begin();try{
                report.put("applyAttempts",1);var applied=planner.apply(session,ApplyRequest.newBuilder().setSessionId(session.id).setPlanId(preview.getPlanId()).setExecutionId(UUID.randomUUID().toString()).build(),f.jobs);
                EditingIT.await(applied);recordJob(report,applied);phase(report,"afterApply",platform,session,current);
                assertEquals(JobState.COMPLETED,applied.state,()->"failureOrigin="+applied.failureOrigin()+"\n"+applied.info());
            }finally{counter.end();report.put("applyJdbc",counter.snapshot());}
            assertFalse((boolean)counter.snapshot().get("overflow"));
            assertThrows(WorkbenchFailure.class,()->planner.preview(session,changes.toBuilder().setResultId(unknown.id).build()));
            assertFalse(unknown.metadataProof().capturedStructure(),"Fresh metadata never upgrades an originally unknown retained source");
            report.put("completed",true);
        }catch(Throwable failure){problem=failure;report.put("completed",false);throw failure;}
        finally{counter.end();report.put("failed",problem!=null);report.putIfAbsent("applyJdbc",counter.snapshot());Files.writeString(evidence.resolve("result.json"),new com.google.gson.GsonBuilder().setPrettyPrinting().create().toJson(report)+"\n");}
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void unrelatedPublicationDuringApplyInspectionFailsClosedBeforeGeneratedDml(String engine)throws Exception{
        Path evidence=Files.createTempDirectory(Path.of("target"),"smart-inspection-publication-");
        var report=new LinkedHashMap<String,Object>();report.put("engine",engine);report.put("applyAttempts",0);
        var counter=new OwnedJdbcOperationCounter();Throwable problem=null;
        try(var f=new EngineFixture(root,engine,counter::connect)){
            var owner=f.open();var observer=f.open();String stable=owner.adapter.table("busydata",f.schema(),"stable_rows");seed(f,owner,stable);
            observer.lock.lock();try(var statement=observer.connection.createStatement()){statement.execute("CREATE TABLE "+observer.adapter.table("busydata",f.schema(),"published_rows")+"(id INTEGER PRIMARY KEY)");}finally{observer.lock.unlock();}
            f.warm(owner,"stable_rows");var platform=f.metadata.metadataPlatform();
            var source=f.results.get(f.execute(owner,"SELECT id,n FROM "+stable).info().getResults(0).getResultId());assertTrue(source.metadataProof().available());
            var planner=new ChangePlanner(f.safety,f.results,platform);var preview=planner.preview(owner,request(f,owner,source));phase(report,"afterPreview",platform,owner,source);
            io.busystack.busydata.jobs.Jobs.Job applied=null;
            counter.begin();counter.gateNextIndexRead();
            try{
                report.put("applyAttempts",1);applied=planner.apply(owner,ApplyRequest.newBuilder().setSessionId(owner.id).setPlanId(preview.getPlanId()).setExecutionId(UUID.randomUUID().toString()).build(),f.jobs);
                assertTrue(counter.indexRead.await(5,TimeUnit.SECONDS),"Observe the actual owned native index read after TableInspection owner capture");report.put("nativeIndexReadObserved",true);
                long revision=platform.publishedSnapshot(owner).revision(),physical=owner.revision,context=owner.contextRevision;phase(report,"heldInspection",platform,owner,source);
                f.warm(observer,"published_rows");report.put("explicitFragmentRefreshes",1);
                assertTrue(platform.publishedSnapshot(owner).revision()>revision);assertEquals(physical,owner.revision);assertEquals(context,owner.contextRevision);
                assertTrue(platform.capture(owner).complete(new MetadataScope("busydata",f.schema(),"stable_rows",ObjectKind.COLUMN),IntrospectionLevel.STRUCTURE));
                assertTrue(source.metadataProof().samePhysicalStructure(RetainedMetadataProof.capture(platform.capture(owner),source.columns,owner.targetProfile(),owner.id,owner.context)));
                phase(report,"afterUnrelatedPublication",platform,owner,source);
            }finally{
                counter.releaseIndexRead();try{if(applied!=null)EditingIT.await(applied);}finally{counter.end();report.put("applyJdbc",counter.snapshot());if(applied!=null)recordJob(report,applied);}
            }
            assertEquals(JobState.FAILED,applied.state);assertEquals("stale",applied.info().getErrorCode());assertEquals(WorkbenchFailure.Origin.INSPECTION,applied.failureOrigin());
            counter.noGeneratedDmlOrCommit();assertEquals(1,report.get("applyAttempts"));
            EditingIT.assertRows(owner,"SELECT id,n FROM "+stable,new int[][]{{1,1}});assertEquals("1",io.busystack.busydata.results.Values.text(source.read(0).getValues(1)));
            report.put("completed",true);
        }catch(Throwable failure){problem=failure;report.put("completed",false);throw failure;}
        finally{counter.releaseIndexRead();counter.end();report.put("failed",problem!=null);report.putIfAbsent("applyJdbc",counter.snapshot());Files.writeString(evidence.resolve("result.json"),new com.google.gson.GsonBuilder().setPrettyPrinting().create().toJson(report)+"\n");}
    }
}
