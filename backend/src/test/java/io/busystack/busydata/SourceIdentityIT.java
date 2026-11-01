package io.busystack.busydata;

import io.busystack.busydata.analysis.SqlAnalysis;
import io.busystack.busydata.jobs.Jobs;
import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.results.ResultStore;
import io.busystack.busydata.safety.Safety;
import io.busystack.busydata.schema.Explorer;
import io.busystack.busydata.security.PrivateTemporaryFiles;
import io.busystack.busydata.sessions.SessionRegistry;
import io.busystack.busydata.storage.MetadataStore;
import java.nio.file.Path;
import java.sql.DriverManager;
import java.util.Base64;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

class SourceIdentityIT {
    @TempDir Path root;
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void migratedPhysicalOwnersShareMetadataAndRetainedProofAcrossOptionOrder(String engine)throws Exception {
        try(var fixture=new EngineFixture(root.resolve("fixture"),engine)) {
            var firstProfile=fixture.profile.toBuilder().putOptions("tcpKeepAlive","true");
            // applicationName is supported by pgJDBC and MariaDB Connector/J.
            // MySQL's approved option allowlist contains only tcpKeepAlive.
            if(fixture.engine!=Engine.MYSQL)firstProfile.putOptions("applicationName","BusyData identity fixture");
            Profile first=firstProfile.build();Path support=root.resolve("migrated");
            String preserved=MetadataIdentity.digest(Base64.getEncoder().encodeToString(first.toBuilder().clearName().clearEnvironment().clearConnectTimeoutSeconds().clearQueryTimeoutSeconds().build().toByteArray()));
            try(var old=new MetadataStore(support)){old.save(first);}
            try(var db=DriverManager.getConnection("jdbc:sqlite:"+support.resolve("metadata.sqlite"));var statement=db.createStatement()){statement.execute("DROP TABLE metadata_source_identity");statement.execute("DELETE FROM migration WHERE version=4");}
            var reversed=first.toBuilder().clearOptions();if(fixture.engine!=Engine.MYSQL)reversed.putOptions("applicationName","BusyData identity fixture");reversed.putOptions("tcpKeepAlive","true");
            try(var metadata=new MetadataStore(support);var files=PrivateTemporaryFiles.isolated();
                var sessions=new SessionRegistry(files,(adapter,request,port)->adapter.connect(request,port),null,metadata::metadataSourceIdentity);
                var results=new ResultStore(support,64L*1024*1024)) {
                var analysis=new SqlAnalysis();var safety=new Safety(analysis);
                try(var jobs=new Jobs(results,metadata,analysis,safety)) {
                    var a=sessions.open(OpenRequest.newBuilder().setProfile(first).setPassword("fixture").build());
                    var b=sessions.open(OpenRequest.newBuilder().setProfile(reversed).setPassword("fixture").build());
                    assertEquals(preserved,a.metadataSourceIdentity);assertEquals(preserved,b.info().getMetadataSourceIdentity());
                    assertNotEquals(a.id,b.id);assertEquals(first,a.profile);assertEquals(reversed.build(),b.profile);
                    EditingIT.execute(jobs,safety,a,"CREATE TABLE identity_rows(id integer PRIMARY KEY, body varchar(40))");
                    new Explorer(metadata).refreshFragment(a,"busydata",fixture.schema(),"identity_rows",ObjectKind.TABLE);
                    var platform=metadata.metadataPlatform();
                    var aSnapshot=platform.capture(a);var bSnapshot=platform.capture(b);
                    assertEquals(preserved,aSnapshot.source());assertEquals(preserved,bSnapshot.source());
                    var aTable=aSnapshot.identities().values().stream().filter(value->value.identity().kind()==ObjectKind.TABLE&&value.identity().name().equals("identity_rows")).findFirst().orElseThrow();
                    var bTable=bSnapshot.identities().values().stream().filter(value->value.identity().kind()==ObjectKind.TABLE&&value.identity().name().equals("identity_rows")).findFirst().orElseThrow();
                    assertEquals(aTable.identity().key(),bTable.identity().key());
                    a.metadata(control->{assertEquals(preserved,control.metadataSourceIdentity);assertNotEquals(SourceIdentity.fingerprint(control.profile),preserved);return null;});
                    if(fixture.engine==Engine.POSTGRESQL) {
                        var unresolved=EditingIT.execute(jobs,safety,a,"SELECT id,body FROM identity_rows");
                        var unresolvedProof=results.get(unresolved.info().getResults(0).getResultId()).metadataProof();
                        assertEquals(MetadataState.PARTIAL,unresolvedProof.state(),unresolvedProof.availability());
                        assertFalse(unresolvedProof.capturedStructure(),"Excluded implicit pg_catalog must not be presumed empty");
                    }
                    // A configured public-table fragment cannot prove absence
                    // in an earlier excluded PostgreSQL search-path namespace.
                    var retained=EditingIT.execute(jobs,safety,a,"SELECT id,body FROM "+fixture.schema()+".identity_rows");
                    assertEquals(JobState.COMPLETED,retained.state);var result=results.get(retained.info().getResults(0).getResultId());
                    assertTrue(result.metadataProof().available(),result.metadataProof().availability());assertEquals(preserved,result.metadataProof().sourceKey());
                    if(fixture.engine==Engine.MARIADB)assertTrue(result.columns.stream().allMatch(column->column.getMetadataIdentity().isEmpty()),"MariaDB does not fabricate persistent column IDs");
                    else assertTrue(result.columns.stream().allMatch(column->!column.getMetadataIdentity().isEmpty()));
                    if(fixture.engine==Engine.MYSQL)assertThrows(IllegalArgumentException.class,()->sessions.open(OpenRequest.newBuilder().setProfile(first.toBuilder().putOptions("applicationName","unsupported")).setPassword("fixture").build()));
                }
            }
        }
    }
}
