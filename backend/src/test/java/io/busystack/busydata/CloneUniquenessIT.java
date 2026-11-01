package io.busystack.busydata;

import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.rpc.WorkbenchFailure;
import io.busystack.busydata.schema.ChangePlanner;
import io.busystack.busydata.sessions.SessionRegistry;
import io.busystack.busydata.results.ResultStore;
import java.nio.file.Path;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

/** Genuine pinned-engine uniqueness facts and ordinary reviewed clone Apply. */
class CloneUniquenessIT {
    @TempDir Path root;
    private static String identity(Engine engine){return engine==Engine.POSTGRESQL?"INTEGER GENERATED ALWAYS AS IDENTITY":"INTEGER AUTO_INCREMENT";}
    private static ChangePlanner planner(EngineFixture fixture){return new ChangePlanner(fixture.safety,fixture.results,fixture.metadata.metadataPlatform());}
    private static ResultStore.Result source(EngineFixture fixture,SessionRegistry.Session session,String table)throws Exception {
        fixture.warm(session,table);String qualified=session.adapter.table(session.context.catalog(),fixture.schema(),table);
        return fixture.results.get(fixture.execute(session,"SELECT * FROM "+qualified).info().getResults(0).getResultId());
    }
    private static CloneRowRequest request(EngineFixture fixture,SessionRegistry.Session session,ResultStore.Result source,String table){
        return CloneRowRequest.newBuilder().setSessionId(session.id).setResultId(source.id).setCatalog(session.context.catalog()).setSchema(fixture.schema()).setTable(table).build();
    }
    private static ChangeRequest change(EngineFixture fixture,SessionRegistry.Session session,ResultStore.Result source,String table,StagedChange clone){
        return ChangeRequest.newBuilder().setSessionId(session.id).setResultId(source.id).setCatalog(session.context.catalog()).setSchema(fixture.schema()).setTable(table).addChanges(clone).build();
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void nullableAndCompositeUniqueKeysPreserveNullIntentThroughReviewAndApply(String engine)throws Exception {
        try(var fixture=new EngineFixture(root,engine)){
            var session=fixture.open();fixture.execute(session,"CREATE TABLE clone_nulls(id "+identity(fixture.engine)+" PRIMARY KEY,code VARCHAR(40) DEFAULT 'default-code',left_key INTEGER,right_key INTEGER DEFAULT 77,payload VARCHAR(40) DEFAULT 'default-payload',UNIQUE(left_key,right_key)); CREATE UNIQUE INDEX clone_nulls_code ON clone_nulls(code); INSERT INTO clone_nulls(code,left_key,right_key,payload) VALUES(NULL,NULL,9,'copy')");
            var source=source(fixture,session,"clone_nulls");var planner=planner(fixture);var clone=planner.cloneRow(session,request(fixture,session,source,"clone_nulls"));
            assertFalse(clone.containsValues(1));assertTrue(clone.getValuesOrThrow(2).hasNullValue());assertTrue(clone.getValuesOrThrow(3).hasNullValue());assertFalse(clone.containsValues(4));assertEquals("copy",clone.getValuesOrThrow(5).getValue().getText());
            var request=change(fixture,session,source,"clone_nulls",clone);var draft=planner.captureDraft(session,request,"clone-null-document");assertTrue(draft.getChanges().getChanges(0).getValuesOrThrow(2).hasNullValue());
            EditingIT.apply(planner,fixture.jobs,session,request);
            var result=fixture.results.get(fixture.execute(session,"SELECT COUNT(*) FROM clone_nulls WHERE code IS NULL AND left_key IS NULL").info().getResults(0).getResultId());assertEquals("2",result.read(0).getValues(0).getSignedInteger());
            var defaults=fixture.results.get(fixture.execute(session,"SELECT right_key FROM clone_nulls WHERE right_key=77").info().getResults(0).getResultId());assertEquals("77",defaults.read(0).getValues(0).getSignedInteger());
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void standaloneUniqueNonNullValuesStayUnsetWithoutBecomingEditableRowIdentity(String engine)throws Exception {
        try(var fixture=new EngineFixture(root,engine)){
            var session=fixture.open();fixture.execute(session,"CREATE TABLE clone_standalone(id "+identity(fixture.engine)+" PRIMARY KEY,code VARCHAR(40),payload VARCHAR(40)); CREATE UNIQUE INDEX clone_standalone_code ON clone_standalone(code); INSERT INTO clone_standalone(code,payload) VALUES('used','copy')");
            var source=source(fixture,session,"clone_standalone");var planner=planner(fixture);var clone=planner.cloneRow(session,request(fixture,session,source,"clone_standalone"));
            assertFalse(clone.containsValues(1));assertFalse(clone.containsValues(2));assertEquals("copy",clone.getValuesOrThrow(3).getValue().getText());
            session.lock.lock();try{var structure=fixture.metadata.metadataPlatform().readTableStructure(session,session.context.catalog(),fixture.schema(),"clone_standalone");assertFalse(structure.identities().contains(Set.of("code")));if(fixture.engine==Engine.POSTGRESQL)assertTrue(structure.constraints().stream().noneMatch(value->value.getName().equals("clone_standalone_code")));}finally{session.lock.unlock();}
            EditingIT.apply(planner,fixture.jobs,session,change(fixture,session,source,"clone_standalone",clone));
            var result=fixture.results.get(fixture.execute(session,"SELECT COUNT(*) FROM clone_standalone").info().getResults(0).getResultId());assertEquals("2",result.read(0).getValues(0).getSignedInteger());
        }
    }
    @Test void postgresNotDistinctAndIncludeKeepNativeUniquenessAndRecoveryFactsSeparate()throws Exception {
        try(var fixture=new EngineFixture(root,"POSTGRESQL")){
            var session=fixture.open();fixture.execute(session,"CREATE TABLE clone_include(id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,code INTEGER DEFAULT 9,payload VARCHAR(40)); CREATE UNIQUE INDEX clone_include_code ON clone_include(code) INCLUDE(payload) NULLS NOT DISTINCT; INSERT INTO clone_include(code,payload) VALUES(NULL,'copy')");
            var source=source(fixture,session,"clone_include");var planner=planner(fixture);var clone=planner.cloneRow(session,request(fixture,session,source,"clone_include"));
            assertFalse(clone.containsValues(2),"NOT DISTINCT NULL must not be copied");assertEquals("copy",clone.getValuesOrThrow(3).getValue().getText(),"INCLUDE is ordinary retained data");
            TableStructure before;session.lock.lock();try{before=fixture.metadata.metadataPlatform().readTableStructure(session,session.context.catalog(),fixture.schema(),"clone_include");}finally{session.lock.unlock();}
            var index=before.indexes().stream().filter(value->value.getName().equals("clone_include_code")).findFirst().orElseThrow();assertEquals("NOT_DISTINCT",index.getPropertiesOrThrow("uniqueNullsPolicy"));assertEquals("1",index.getPropertiesOrThrow("keyColumnCount"));assertEquals("true",index.getPropertiesOrThrow("included.1"));
            EditingIT.apply(planner,fixture.jobs,session,change(fixture,session,source,"clone_include",clone));
            fixture.execute(session,"DROP INDEX clone_include_code; CREATE UNIQUE INDEX clone_include_code ON clone_include(code) INCLUDE(payload) NULLS DISTINCT");
            session.lock.lock();try{var after=fixture.metadata.metadataPlatform().readTableStructure(session,session.context.catalog(),fixture.schema(),"clone_include");assertNotEquals(before.signature(),after.signature());assertEquals(before.recoverySignature(),after.recoverySignature(),"Existing user recovery transport remains unchanged");}finally{session.lock.unlock();}
        }
    }
    @Test void postgresNonNullUniqueIncludeKeepsOrdinaryIncludedPayload()throws Exception {
        try(var fixture=new EngineFixture(root,"POSTGRESQL")){
            var session=fixture.open();fixture.execute(session,"CREATE TABLE clone_nonnull_include(id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,code INTEGER NOT NULL DEFAULT 5,payload VARCHAR(40) NOT NULL); CREATE UNIQUE INDEX clone_nonnull_include_code ON clone_nonnull_include(code) INCLUDE(payload); INSERT INTO clone_nonnull_include(code,payload) VALUES(4,'copy')");
            var source=source(fixture,session,"clone_nonnull_include");var planner=planner(fixture);var clone=planner.cloneRow(session,request(fixture,session,source,"clone_nonnull_include"));
            assertFalse(clone.containsValues(2));assertEquals("copy",clone.getValuesOrThrow(3).getValue().getText());
            EditingIT.apply(planner,fixture.jobs,session,change(fixture,session,source,"clone_nonnull_include",clone));
            var result=fixture.results.get(fixture.execute(session,"SELECT COUNT(*) FROM clone_nonnull_include WHERE payload='copy'").info().getResults(0).getResultId());assertEquals("2",result.read(0).getValues(0).getSignedInteger());
        }
    }
    @Test void postgresExpressionAndPartialUniqueIndexesReturnExplicitUnsupported()throws Exception {
        try(var fixture=new EngineFixture(root,"POSTGRESQL")){
            var session=fixture.open();fixture.execute(session,"CREATE TABLE clone_complex(id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,code VARCHAR(40),active BOOLEAN); INSERT INTO clone_complex(code,active) VALUES('used',true); CREATE UNIQUE INDEX clone_expression ON clone_complex((lower(code)))");
            var planner=planner(fixture);var expression=source(fixture,session,"clone_complex");
            assertEquals(WorkbenchFailure.Reason.UNSUPPORTED,assertThrows(WorkbenchFailure.class,()->planner.cloneRow(session,request(fixture,session,expression,"clone_complex"))).reason());
            fixture.execute(session,"DROP INDEX clone_expression; CREATE UNIQUE INDEX clone_partial ON clone_complex(code) WHERE active");var partial=source(fixture,session,"clone_complex");
            assertEquals(WorkbenchFailure.Reason.UNSUPPORTED,assertThrows(WorkbenchFailure.class,()->planner.cloneRow(session,request(fixture,session,partial,"clone_complex"))).reason());
            var result=fixture.results.get(fixture.execute(session,"SELECT COUNT(*) FROM clone_complex").info().getResults(0).getResultId());assertEquals("1",result.read(0).getValues(0).getSignedInteger());
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void generatedUniqueValuesCannotBeRepeatedByCopyingTheirInputs(String engine)throws Exception {
        try(var fixture=new EngineFixture(root,engine)){
            var session=fixture.open();fixture.execute(session,"CREATE TABLE clone_generated(id "+identity(fixture.engine)+" PRIMARY KEY,input_value INTEGER,computed INTEGER GENERATED ALWAYS AS (input_value*2) STORED,UNIQUE(computed)); INSERT INTO clone_generated(input_value) VALUES(7)");
            var source=source(fixture,session,"clone_generated");var planner=planner(fixture);
            assertEquals(WorkbenchFailure.Reason.UNSUPPORTED,assertThrows(WorkbenchFailure.class,()->planner.cloneRow(session,request(fixture,session,source,"clone_generated"))).reason());
        }
    }
}
