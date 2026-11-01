package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.Explorer;
import java.nio.file.Path;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

class SessionContextIT {
    @TempDir Path root;
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void independentFirstUseAcknowledgesRequestedScopeAndRejectsMissingScope(String engine)throws Exception {
        try(var f=new EngineFixture(root,engine)) {
            var setup=f.open();
            String catalog=f.engine==Engine.POSTGRESQL?"busydata":"busydata_scope";
            String schema=f.engine==Engine.POSTGRESQL?"Quoted scope":"";
            if(f.engine==Engine.POSTGRESQL) {
                f.execute(setup,"CREATE SCHEMA \"Quoted scope\"; CREATE TABLE \"Quoted scope\".first_use(id INTEGER PRIMARY KEY); INSERT INTO \"Quoted scope\".first_use VALUES(71)");
            }else {
                f.execute(setup,"CREATE DATABASE busydata_scope; CREATE TABLE busydata_scope.first_use(id INTEGER PRIMARY KEY); INSERT INTO busydata_scope.first_use VALUES(71)");
                var catalogObject=new Explorer(f.metadata).explore(setup,ExploreRequest.newBuilder().setKind(ObjectKind.CATALOG).setCatalog("busydata").build()).getObjectsList().stream().filter(object->object.getName().equals(catalog)).findFirst().orElseThrow();
                assertEquals(catalog,catalogObject.getCatalog(),"An Explorer catalog must identify its own database, not the configured default");
                var fromExplorer=f.sessions.open(OpenRequest.newBuilder().setProfile(f.profile).setPassword("fixture").setCatalog(catalogObject.getCatalog()).setSchema(catalogObject.getName()).build());
                EditingIT.assertRows(fromExplorer,"SELECT id FROM first_use",new int[][]{{71}});
            }
            var request=OpenRequest.newBuilder().setProfile(f.profile).setPassword("fixture").setCatalog(catalog).setSchema(schema).build();
            var independent=f.sessions.open(request);
            assertNotEquals(setup.id,independent.id);
            String source=io.busystack.busydata.metadata.SourceIdentity.fingerprint(f.profile);
            assertTrue(source.matches("[0-9a-f]{64}"));
            assertEquals(source,setup.info().getMetadataSourceIdentity());
            assertEquals(source,independent.info().getMetadataSourceIdentity(),"Different live catalogs/schemas retain the saved data-source identity");
            assertEquals(source,io.busystack.busydata.metadata.SourceIdentity.fingerprint(f.profile.toBuilder().setName("Presentation name").setEnvironment(Environment.PRODUCTION).setConnectTimeoutSeconds(11).setQueryTimeoutSeconds(13).build()),"Presentation and timeout settings do not change a source");
            assertNotEquals(source,io.busystack.busydata.metadata.SourceIdentity.fingerprint(f.profile.toBuilder().setUser("another-user").build()),"Different visibility principals must not share configuration floors");
            assertEquals(catalog,independent.info().getCurrentCatalog());
            if(f.engine==Engine.POSTGRESQL)assertEquals(schema,independent.info().getCurrentSchema());
            assertEquals("busydata",independent.info().getProfile().getDatabase(),"Acknowledged live scope must not rewrite saved configuration");
            EditingIT.assertRows(independent,"SELECT id FROM first_use",new int[][]{{71}});
            int handles=f.sessions.size(),physical=f.sessions.physicalSessionCount();
            var missing=f.engine==Engine.POSTGRESQL?request.toBuilder().setSchema("absent_scope"):request.toBuilder().setCatalog("absent_scope");
            assertThrows(Exception.class,()->f.sessions.open(missing.build()));
            if(f.engine==Engine.POSTGRESQL)assertThrows(java.sql.SQLException.class,()->f.sessions.open(request.toBuilder().setCatalog("another_database").build()),"A new database-targeted physical connection must reject a missing database");
            if(f.engine==Engine.POSTGRESQL) {
                f.execute(setup,"CREATE SCHEMA denied_scope; REVOKE ALL ON SCHEMA denied_scope FROM PUBLIC; CREATE USER limited_scope WITH PASSWORD 'fixture'; GRANT CONNECT ON DATABASE busydata TO limited_scope");
                assertThrows(IllegalArgumentException.class,()->f.sessions.open(request.toBuilder().setProfile(f.profile.toBuilder().setUser("limited_scope")).setSchema("denied_scope").build()),"Existing but inaccessible schemas must be rejected before acknowledgement");
            }
            assertEquals(handles,f.sessions.size(),"Rejected scope must not leave an adoptable session");
            assertEquals(physical,f.sessions.physicalSessionCount(),"Rejected scope must release its JDBC permit");
            EditingIT.assertRows(independent,"SELECT id FROM first_use",new int[][]{{71}});
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void contextFollowsExecutionWithoutChangingTheSavedProfile(String engine)throws Exception {
        try(var f=new EngineFixture(root,engine)) {
            var s=f.open();long before=s.info().getContextRevision();
            if(f.engine==Engine.POSTGRESQL) {
                f.execute(s,"CREATE SCHEMA \"Quoted 漢\"; SET search_path TO \"Quoted 漢\", public; CREATE TABLE local_context(id INTEGER PRIMARY KEY); CREATE TEMP TABLE temporary_context(v INTEGER)");
                assertEquals("Quoted 漢",s.info().getCurrentSchema());assertEquals(java.util.List.of("Quoted 漢","public"),s.info().getSearchPathList());
            }else {
                f.execute(s,"CREATE DATABASE other_context; USE other_context; CREATE TABLE local_context(id INTEGER PRIMARY KEY)");
                assertEquals("other_context",s.info().getCurrentCatalog());
            }
            assertTrue(s.info().getContextRevision()>before);assertEquals("busydata",s.info().getProfile().getDatabase());
            var execution=f.execute(s,"SELECT 1");
            var history=f.metadata.history(HistoryRequest.newBuilder().setLimit(100).build()).getEntriesList().stream().filter(entry->entry.getId().equals(execution.id)).findFirst().orElseThrow();
            assertTrue(history.getTarget().endsWith("/"+s.context.catalog()),"History must identify the live execution database");
            assertEquals(s.context.catalog(),execution.targetProfile.getDatabase(),"Queued jobs must capture their live target at execution");
            var explorer=new Explorer(f.metadata);var columns=explorer.explore(s,ExploreRequest.newBuilder().setKind(ObjectKind.COLUMN).setTable("local_context").build());
            assertEquals("id",columns.getObjects(0).getName());
            f.execute(s,"INSERT INTO local_context VALUES(1)");
            f.warm(s,"local_context");
            var contextual=f.results.get(f.execute(s,"SELECT id FROM local_context").info().getResults(0).getResultId());
            assertEquals(s.context.catalog(),contextual.targetProfile.getDatabase());
            String exact=s.adapter.table(s.context.catalog(),s.context.schema(),"local_context");
            var retained=f.results.get(f.execute(s,"SELECT id FROM "+exact).info().getResults(0).getResultId());
            var changes=ChangeRequest.newBuilder().setSessionId(s.id).setResultId(retained.id).setTable("local_context").setCatalog(s.context.catalog()).setSchema(s.context.schema()).addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE).putValues(1,io.busystack.busydata.schema.Assignments.value(EditingIT.integer(2)))).build();
            var planner=new io.busystack.busydata.schema.ChangePlanner(f.safety,f.results,f.metadata.metadataPlatform());var plan=planner.preview(s,changes);
            assertEquals(s.context.catalog(),plan.getTarget().getDatabase());
            var applied=planner.apply(s,ApplyRequest.newBuilder().setSessionId(s.id).setPlanId(plan.getPlanId()).setExecutionId(java.util.UUID.randomUUID().toString()).build(),f.jobs);
            assertEquals(JobState.COMPLETED,applied.finished.get(10,java.util.concurrent.TimeUnit.SECONDS).getState());
            EditingIT.assertRows(s,"SELECT id FROM local_context",new int[][]{{2}});
            if(f.engine==Engine.POSTGRESQL) {
                f.execute(s,"CREATE VIEW \"live.view 漢\" AS SELECT id FROM local_context");
                for(String scope:java.util.List.of("", "Quoted 漢")) {
                    String definition=s.adapter.toolSql(ToolRequest.newBuilder().setKind(ToolKind.DEFINITION).setSchema(scope).setTable("live.view 漢").build());
                    try(var statement=s.connection.createStatement();var rows=statement.executeQuery(definition)) {
                        assertTrue(rows.next());assertTrue(rows.getString(1).contains("local_context"));
                    }
                }
                var temporary=explorer.explore(s,ExploreRequest.newBuilder().setKind(ObjectKind.COLUMN).setTable("temporary_context").build());
                assertEquals("v",temporary.getObjects(0).getName());
                f.sessions.command(SessionRequest.newBuilder().setSessionId(s.id).setAction(SessionAction.BEGIN).build());
                f.execute(s,"SET LOCAL search_path TO public");assertEquals("public",s.info().getCurrentSchema());
                f.sessions.command(SessionRequest.newBuilder().setSessionId(s.id).setAction(SessionAction.ROLLBACK).build());
                assertEquals("Quoted 漢",s.info().getCurrentSchema());
                assertEquals(TransactionState.IDLE,s.state,"Context refresh must not start an idle manual transaction");
            }
        }
    }

    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void queuedTargetAndProductionReviewUseLiveContext(String engine)throws Exception {
        try(var f=new EngineFixture(root,engine)) {
            var profile=f.profile.toBuilder().setEnvironment(Environment.PRODUCTION).build();
            var s=f.sessions.open(OpenRequest.newBuilder().setProfile(profile).setPassword("fixture").build());
            String change=f.engine==Engine.POSTGRESQL?"SET search_path TO pg_catalog, public":"CREATE DATABASE queued_context; USE queued_context";
            var started=new java.util.concurrent.CountDownLatch(1);var resume=new java.util.concurrent.CountDownLatch(1);
            var first=f.jobs.submit(s,java.util.UUID.randomUUID().toString(),"",job->{started.countDown();assertTrue(resume.await(5,java.util.concurrent.TimeUnit.SECONDS));for(var fragment:f.analysis.split(change,f.engine)){try(var statement=s.connection.createStatement()){statement.execute(fragment.text());}}s.refresh();});
            assertTrue(started.await(5,java.util.concurrent.TimeUnit.SECONDS));
            var actualTarget=new java.util.concurrent.atomic.AtomicReference<String>();
            var second=f.jobs.submit(s,java.util.UUID.randomUUID().toString(),"",job->actualTarget.set(job.targetProfile.getDatabase()));
            resume.countDown();
            assertEquals(JobState.COMPLETED,first.finished.get(10,java.util.concurrent.TimeUnit.SECONDS).getState());
            assertEquals(JobState.COMPLETED,second.finished.get(10,java.util.concurrent.TimeUnit.SECONDS).getState());
            assertEquals(s.context.catalog(),actualTarget.get());
            var request=ExecuteRequest.newBuilder().setSessionId(s.id).setSql("SELECT 1").build();
            var review=f.safety.review(request,s);
            assertTrue(review.getRisksList().contains("PRODUCTION: "+profile.getHost()+":"+profile.getPort()+"/"+s.context.catalog()));
            if(f.engine==Engine.POSTGRESQL)assertTrue(review.getRisksList().contains("Current search path: pg_catalog, public"));
            assertEquals("busydata",s.profile.getDatabase());
            var history=f.metadata.history(HistoryRequest.newBuilder().setLimit(100).build()).getEntriesList().stream().filter(entry->entry.getId().equals(second.id)).findFirst().orElseThrow();
            assertTrue(history.getTarget().endsWith("/"+s.context.catalog()));
        }
    }
}
