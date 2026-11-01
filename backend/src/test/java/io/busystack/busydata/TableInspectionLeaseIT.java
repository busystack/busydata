package io.busystack.busydata;

import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.rpc.WorkbenchFailure;
import io.busystack.busydata.sessions.SessionRegistry;
import java.nio.file.Path;
import java.util.*;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

/** Live ownership and bounded-lifetime contract; no private counter or reflection. */
class TableInspectionLeaseIT {
    private static final String TABLE="inspection_lease_rows";
    private static final int ACQUISITION_LIMIT=32;
    @TempDir Path root;

    private static void seed(EngineFixture fixture,SessionRegistry.Session owner)throws Exception{
        owner.lock.lock();try(var statement=owner.connection.createStatement()){
            statement.execute("CREATE TABLE "+owner.adapter.table("busydata",fixture.schema(),TABLE)+"(id INTEGER PRIMARY KEY,n INTEGER NOT NULL DEFAULT 7)");
        }finally{owner.lock.unlock();}
        fixture.warm(owner,TABLE);
    }
    private static MetadataObject relation(MetadataSnapshot snapshot,EngineFixture fixture){
        var values=snapshot.resolve("busydata",fixture.schema(),ObjectKind.TABLE,"",TABLE,true);
        assertEquals(1,values.size());assertTrue(values.getFirst().identity().sessionOwner().isEmpty());return values.getFirst();
    }
    private static io.busystack.busydata.results.ResultStore.Result source(EngineFixture fixture,SessionRegistry.Session owner)throws Exception{
        var job=fixture.execute(owner,"SELECT id,n FROM "+owner.adapter.table("busydata",fixture.schema(),TABLE));
        var result=fixture.results.get(job.info().getResults(0).getResultId());
        assertTrue(result.metadataProof().available());assertEquals(2,result.columns.size());return result;
    }
    private static void stale(MetadataPlatform.TableInspection inspection){
        var failure=assertThrows(WorkbenchFailure.class,inspection::checkCurrent);
        assertEquals(WorkbenchFailure.Reason.STALE,failure.reason());assertEquals(WorkbenchFailure.Origin.INSPECTION,failure.origin());
    }
    private static void closeAll(List<MetadataPlatform.AcquisitionAdmission> admissions){
        RuntimeException failure=null;
        for(int index=admissions.size()-1;index>=0;index--)try{admissions.get(index).close();}
            catch(RuntimeException error){if(failure==null)failure=error;else failure.addSuppressed(error);}
        admissions.clear();if(failure!=null)throw failure;
    }
    private static void full(MetadataPlatform platform,String reason){
        assertThrows(IllegalStateException.class,()->{
            // Even a broken cap returning an unexpected extra lease cannot
            // make this failing assertion itself leak that lease.
            try(var unexpected=platform.admitAcquisition()){}
        },reason);
    }
    /** Behavioural resource proof through ordinary admission, not a private size getter. */
    private static void allSlotsAvailable(MetadataPlatform platform){
        var admitted=new ArrayList<MetadataPlatform.AcquisitionAdmission>();
        try{
            for(int index=0;index<ACQUISITION_LIMIT;index++)admitted.add(platform.admitAcquisition());
            full(platform,"The existing thirty-two acquisition bound must remain exact");
        }finally{closeAll(admitted);}
    }
    private static MetadataConfiguration nextConfiguration(MetadataConfiguration previous){
        return new MetadataConfiguration(previous.revision()+1,previous.includedCatalogs(),previous.excludedCatalogs(),
            previous.includedSchemas(),previous.excludedSchemas(),previous.systemObjects(),previous.kinds(),
            previous.includePatterns(),previous.excludePatterns(),previous.defaultLevel(),previous.scopeLevels());
    }

    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void freshRequestOwnedProofConsumesOneAdmissionAndCloseReleasesExactlyOne(String engine)throws Exception{
        try(var fixture=new EngineFixture(root,engine)){
            var owner=fixture.open();var external=fixture.open();seed(fixture,owner);var platform=fixture.metadata.metadataPlatform();var result=source(fixture,owner);
            var cached=platform.capture(owner);var durable=platform.publishedSnapshot(owner);var permanent=relation(cached,fixture);
            var original=result.metadataProof();int overlays=platform.sessionOverlayCount(),witnesses=PreparedMetadataWitness.retainedForSession(owner.id),jobs=fixture.jobs.list(owner.id).size();
            // Raw external DDL leaves the cached view unchanged. A fresh proof
            // must come from this request's authoritative native inspection.
            external.lock.lock();try(var statement=external.connection.createStatement()){
                statement.execute("ALTER TABLE "+external.adapter.table("busydata",fixture.schema(),TABLE)+" ALTER COLUMN n SET DEFAULT 9");
            }finally{external.lock.unlock();}
            var admissions=new ArrayList<MetadataPlatform.AcquisitionAdmission>();
            owner.lock.lock();
            try(var inspection=platform.inspectTable(owner,"busydata",fixture.schema(),TABLE,result.columns)){
                inspection.checkCurrent();var fresh=inspection.proof();var structure=inspection.structure();
                assertTrue(fresh.available());assertEquals(permanent.identity().key(),fresh.tableIdentity());assertEquals(original.tableIdentity(),fresh.tableIdentity());
                var nativeColumn=structure.columns().stream().filter(value->value.getName().equals("n")).findFirst().orElseThrow();
                assertEquals(RetainedMetadataProof.columnFingerprint(nativeColumn),fresh.columns().get(2).fingerprint());
                assertNotEquals(original.columns().get(2).fingerprint(),fresh.columns().get(2).fingerprint());
                assertSame(durable,platform.publishedSnapshot(owner));assertSame(cached,platform.capture(owner));
                assertEquals(overlays,platform.sessionOverlayCount());assertEquals(witnesses,PreparedMetadataWitness.retainedForSession(owner.id));assertEquals(jobs,fixture.jobs.list(owner.id).size());
                for(int index=0;index<ACQUISITION_LIMIT-1;index++)admissions.add(platform.admitAcquisition());
                full(platform,"The live inspection occupies the last admitted slot");
                inspection.close();stale(inspection);
                assertThrows(WorkbenchFailure.class,()->inspection.proof());assertThrows(WorkbenchFailure.class,()->inspection.typeEvidence(nativeColumn));assertThrows(WorkbenchFailure.class,inspection::structure);
                admissions.add(platform.admitAcquisition());
                full(platform,"Closing one inspection releases exactly one slot");
                inspection.close();full(platform,"Repeated close cannot release another caller's admission");
            }finally{try{closeAll(admissions);}finally{owner.lock.unlock();}}
            allSlotsAvailable(platform);assertSame(durable,platform.publishedSnapshot(owner));assertSame(cached,platform.capture(owner));
        }
    }

    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void sourceAndConfigurationRevisionsRetireARequestOwnedProofBeforeUse(String engine)throws Exception{
        try(var fixture=new EngineFixture(root,engine)){
            var owner=fixture.open();seed(fixture,owner);var platform=fixture.metadata.metadataPlatform();var result=source(fixture,owner);
            owner.lock.lock();
            try{
                try(var inspection=platform.inspectTable(owner,"busydata",fixture.schema(),TABLE,result.columns)){
                    inspection.checkCurrent();var held=inspection.proof();String identity=held.tableIdentity();
                    platform.markStale(owner,"Explicit source invalidation in the owned inspection regression");
                    stale(inspection);assertEquals(identity,held.tableIdentity(),"A compact held proof remains exact while inspection use authority is stale");
                }
                allSlotsAvailable(platform);
                try(var inspection=platform.inspectTable(owner,"busydata",fixture.schema(),TABLE,result.columns)){
                    inspection.checkCurrent();long configuration=inspection.configurationRevision();
                    platform.configure(owner,nextConfiguration(platform.configuration(owner)));
                    assertTrue(platform.configuration(owner).revision()>configuration);stale(inspection);
                }
            }finally{owner.lock.unlock();}
            allSlotsAvailable(platform);
        }
    }

    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void physicalSessionRetirementRejectsUseAndCloseStillReturnsAdmission(String engine)throws Exception{
        try(var fixture=new EngineFixture(root,engine)){
            var owner=fixture.open();var other=fixture.open();seed(fixture,owner);var platform=fixture.metadata.metadataPlatform();var result=source(fixture,owner);
            owner.lock.lock();
            try(var inspection=platform.inspectTable(owner,"busydata",fixture.schema(),TABLE,result.columns)){
                inspection.checkCurrent();var held=inspection.proof();String identity=held.tableIdentity();
                owner.lock.unlock();
                try{
                    other.lock.lock();try{
                        var failure=assertThrows(WorkbenchFailure.class,inspection::checkCurrent);assertEquals(WorkbenchFailure.Reason.INVALID_OWNER,failure.reason());
                    }finally{other.lock.unlock();}
                }finally{owner.lock.lock();}
                inspection.checkCurrent();
                fixture.sessions.close(owner.id,true);assertTrue(owner.physicalEnded());
                stale(inspection);assertEquals(identity,held.tableIdentity());
            }finally{owner.lock.unlock();}
            allSlotsAvailable(platform);assertEquals(0,PreparedMetadataWitness.retainedForSession(owner.id));assertEquals(0,platform.sessionOverlayCount());
        }
    }

    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void sameResolutionEpochReplacementStillRetiresTheCapturedOwner(String engine)throws Exception{
        try(var fixture=new EngineFixture(root,engine)){
            var owner=fixture.open();seed(fixture,owner);var platform=fixture.metadata.metadataPlatform();var result=source(fixture,owner);
            owner.lock.lock();
            try{
                long epoch=platform.markSessionResolutionUnknown(owner,"Owned record replacement contract");
                assertTrue(platform.markSessionRelationVerified(owner,epoch,"busydata",fixture.schema(),TABLE,MetadataSnapshot.PhysicalRelationKind.PERSISTENT));
                try(var inspection=platform.inspectTable(owner,"busydata",fixture.schema(),TABLE,result.columns)){
                    inspection.checkCurrent();var proof=inspection.proof();assertTrue(proof.available());
                    platform.invalidateSessionRelation(owner,"busydata",fixture.schema(),TABLE);
                    assertEquals(epoch,platform.sessionResolutionEpoch(owner),"Resolution epoch deliberately stays unchanged while the exact verified-owner record is replaced");
                    stale(inspection);assertEquals(result.metadataProof().tableIdentity(),proof.tableIdentity());
                }
            }finally{owner.lock.unlock();}
            allSlotsAvailable(platform);
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void realAcknowledgedExecutionRevisionRetiresTheCapturedInspection(String engine)throws Exception{
        try(var fixture=new EngineFixture(root,engine)){
            var owner=fixture.open();seed(fixture,owner);var platform=fixture.metadata.metadataPlatform();var result=source(fixture,owner);
            owner.lock.lock();
            try(var inspection=platform.inspectTable(owner,"busydata",fixture.schema(),TABLE,result.columns)){
                inspection.checkCurrent();long revision=owner.revision;
                owner.lock.unlock();try{fixture.execute(owner,"SELECT 1");}finally{owner.lock.lock();}
                assertTrue(owner.revision>revision);stale(inspection);
            }finally{owner.lock.unlock();}
            allSlotsAvailable(platform);
        }
    }

}
