package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.*;
import java.nio.file.*;
import java.lang.reflect.*;
import java.sql.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static io.busystack.busydata.metadata.MetadataCacheTestAccess.await;
import static org.junit.jupiter.api.Assertions.*;

class MetadataRepositoryTest {
    @TempDir Path root;
    private static final IdentifierRules RULES=new IdentifierRules(Engine.POSTGRESQL,0);
    private static MetadataObject object(String source,String name,String value){return MetadataObject.from(source,"profile-"+source,"",RULES,SchemaObject.newBuilder().setKind(ObjectKind.TABLE).setCatalog("db").setSchema("public").setName(name).putProperties("remarks",value).build(),IntrospectionLevel.STRUCTURE,1,1);}
    private static MetadataSnapshot snapshot(String source,long revision,MetadataObject... objects){
        var coverage=new HashMap<MetadataScope,MetadataCoverage>();
        for(var object:objects){var id=object.identity();var scope=new MetadataScope(id.catalog(),id.schema(),id.parent(),id.kind(),id.name(),true,id.signature(),id.subtype());coverage.put(scope,new MetadataCoverage(scope,IntrospectionLevel.STRUCTURE,MetadataState.AVAILABLE,true,"fixture-"+revision,revision,1,revision,""));}
        return new MetadataSnapshot(source,"profile-"+source,revision,1,revision,RULES,List.of(objects),coverage);
    }
    private static MetadataSnapshot empty(String source){return MetadataSnapshot.empty(source,"profile-"+source,RULES);}
    private Connection open()throws SQLException{return DriverManager.getConnection("jdbc:sqlite:"+root.resolve("metadata_catalog.sqlite"));}
    private void sql(String sql)throws SQLException{try(var db=open();var statement=db.createStatement()){statement.execute(sql);}}
    private static MetadataSnapshot loaded(MetadataRepository repository,String source)throws Exception{return repository.load().stream().filter(value->value.source().equals(source)).findFirst().orElseThrow();}
    private static void stale(MetadataSnapshot value){assertTrue(value.catalogCoverage().values().stream().allMatch(scope->scope.state()==MetadataState.STALE&&!scope.complete()));for(var scope:value.catalogCoverage().keySet())assertFalse(value.complete(scope,IntrospectionLevel.NAMES));}

    @Test void failedCachePublicationThenNextMemoryDeltaRepairsAllChangesWithoutPhantoms()throws Exception {
        var repository=new MetadataRepository(root);var before=snapshot("source",1,object("source","changed","old"),object("source","removed","old"));
        var unrelated=snapshot("other",1,object("other","untouched","preserved"));await(repository.publish(before,empty("source")));await(repository.publish(unrelated,empty("other")));
        var changed=object("source","changed","new");var added=object("source","added","retained");var failedMemory=snapshot("source",2,changed,added);
        sql("CREATE TRIGGER reject_property BEFORE INSERT ON property WHEN NEW.source='source' AND NEW.value='new' BEGIN SELECT RAISE(ABORT,'fixture cache failure'); END");
        assertThrows(SQLException.class,()->await(repository.publish(failedMemory,before)));
        assertEquals("WRITE_UNAVAILABLE",repository.cacheState());
        var afterFailure=loaded(repository,"source");assertEquals(1,afterFailure.revision());assertEquals(before.identities(),afterFailure.identities());
        sql("DROP TRIGGER reject_property");
        // These two objects are unchanged from memory publication 2, which the
        // cache never received. A blind delta would omit both and keep removed.
        var next=snapshot("source",3,changed,added,object("source","later","third"));await(repository.publish(next,failedMemory));
        assertEquals("AVAILABLE",repository.cacheState());
        var after=loaded(new MetadataRepository(root),"source");assertEquals(next.identities(),after.identities());assertEquals(3,after.revision());stale(after);
        var other=loaded(repository,"other");assertEquals(unrelated.identities(),other.identities());assertEquals(1,other.revision());stale(other);
    }

    @Test void exactPredecessorRetainsTheIncrementalWritePath()throws Exception {
        var repository=new MetadataRepository(root);var unchanged=object("source","unchanged","preserved");var before=snapshot("source",1,unchanged,object("source","removed","old"));await(repository.publish(before,empty("source")));
        sql("CREATE TRIGGER reject_rewrite BEFORE INSERT ON object WHEN NEW.source='source' AND NEW.name='unchanged' BEGIN SELECT RAISE(ABORT,'fixture unchanged object rewrite'); END");
        var next=snapshot("source",2,unchanged,object("source","new","added"));await(repository.publish(next,before));
        var restored=loaded(repository,"source");assertEquals(next.identities(),restored.identities());stale(restored);
    }

    @Test void committedPolicyFiltersAnOlderCacheBeforeExposureAndNextWriteRemovesExcludedRows()throws Exception {
        var repository=new MetadataRepository(root);var kept=object("source","keep_table","retained");var excluded=object("source","keep_secret_table","excluded");var includeRejected=object("source","other_table","excluded");
        var keptColumn=MetadataObject.from("source","profile-source","",RULES,SchemaObject.newBuilder().setKind(ObjectKind.COLUMN).setCatalog("db").setSchema("public").setTable("keep_table").setName("ordinary_column").putProperties("type","integer").build(),IntrospectionLevel.STRUCTURE,1,1);
        var excludedColumn=MetadataObject.from("source","profile-source","",RULES,SchemaObject.newBuilder().setKind(ObjectKind.COLUMN).setCatalog("db").setSchema("public").setTable("keep_secret_table").setName("ordinary_column").putProperties("type","integer").build(),IntrospectionLevel.STRUCTURE,1,1);
        var otherSchema=MetadataObject.from("source","profile-source","",RULES,SchemaObject.newBuilder().setKind(ObjectKind.TABLE).setCatalog("db").setSchema("audit").setName("keep_other").build(),IntrospectionLevel.STRUCTURE,1,1);
        var otherCatalog=MetadataObject.from("source","profile-source","",RULES,SchemaObject.newBuilder().setKind(ObjectKind.TABLE).setCatalog("other").setSchema("public").setName("keep_other").build(),IntrospectionLevel.STRUCTURE,1,1);
        var routine=MetadataObject.from("source","profile-source","",RULES,SchemaObject.newBuilder().setKind(ObjectKind.ROUTINE).setSubtype(ObjectSubtype.FUNCTION).setCatalog("db").setSchema("public").setName("keep_routine").setIdentifier("keep_routine()").build(),IntrospectionLevel.STRUCTURE,1,1);
        var before=snapshot("source",1,kept,excluded,includeRejected,keptColumn,excludedColumn,otherSchema,otherCatalog,routine);await(repository.publish(before,empty("source")));
        var policy=new MetadataConfiguration(2,Set.of("db"),Set.of(),Set.of("public"),Set.of(),false,Set.of(ObjectKind.TABLE,ObjectKind.COLUMN),List.of("keep*"),List.of("*secret*"),IntrospectionLevel.NAMES,Map.of());
        var restored=repository.loadNewest(Map.of("source",policy)).getFirst();assertEquals(2,restored.configurationRevision());assertEquals(Set.of(kept.identity().key(),keptColumn.identity().key()),restored.identities().keySet());stale(restored);
        assertTrue(restored.catalogCoverage().keySet().stream().allMatch(scope->scope.catalog().equals("db")&&scope.schema().equals("public")&&(scope.kind()==ObjectKind.TABLE||scope.kind()==ObjectKind.COLUMN)&&!scope.parent().equals("keep_secret_table")&&!scope.search().equals("keep_secret_table")));
        try(var db=open();var statement=db.createStatement();var rows=statement.executeQuery("SELECT configuration_revision FROM publication WHERE source='source'")){assertTrue(rows.next());assertEquals(1,rows.getInt(1),"Read filtering must not pretend the failed configuration cache write succeeded");}
        var next=new MetadataSnapshot(restored.source(),restored.profileId(),2,2,2,RULES,restored.identities().values(),restored.catalogCoverage());await(repository.publish(next,restored));
        assertEquals(restored.identities(),loaded(repository,"source").identities(),"A changed committed policy forces full repair of the older stored header");stale(loaded(repository,"source"));
    }

    @Test void matchingCommittedPolicyStillCannotRestoreFreshness()throws Exception {
        var repository=new MetadataRepository(root);var before=snapshot("source",1,object("source","table","retained"));await(repository.publish(before,empty("source")));
        var restored=repository.loadNewest(Map.of("source",MetadataConfiguration.defaults())).getFirst();assertEquals(before.identities(),restored.identities());assertEquals(1,restored.configurationRevision());stale(restored);
    }

    @ParameterizedTest @ValueSource(strings={"profile","revision","configuration_revision","created","engine","case_rule","rules","text_rules","oversized_rules"})
    void everyStoredHeaderComponentMustMatchBeforeADeltaIsSafe(String component)throws Exception {
        var repository=new MetadataRepository(root);var unchanged=object("source","unchanged","correct");var before=snapshot("source",1,unchanged);await(repository.publish(before,empty("source")));
        sql("UPDATE property SET value='wrong-cache-generation' WHERE source='source'");
        switch(component){
            case "profile"->sql("UPDATE publication SET profile='other-profile' WHERE source='source'");
            case "revision"->sql("UPDATE publication SET revision=17 WHERE source='source'");
            case "configuration_revision"->sql("UPDATE publication SET configuration_revision=17 WHERE source='source'");
            case "created"->sql("UPDATE publication SET created=17 WHERE source='source'");
            case "engine"->sql("UPDATE publication SET engine="+Engine.MYSQL.getNumber()+" WHERE source='source'");
            case "case_rule"->sql("UPDATE publication SET case_rule=1 WHERE source='source'");
            case "rules"->{byte[] bytes=RULES.encode();bytes[bytes.length-1]^=1;try(var db=open();var update=db.prepareStatement("UPDATE publication SET identifier_rules=? WHERE source='source'")){update.setBytes(1,bytes);update.executeUpdate();}}
            case "text_rules"->sql("UPDATE publication SET identifier_rules=CAST(identifier_rules AS TEXT) WHERE source='source'");
            case "oversized_rules"->sql("UPDATE publication SET identifier_rules=zeroblob("+(IdentifierRules.MAX_ENCODED_BYTES+1)+") WHERE source='source'");
            default->throw new AssertionError();
        }
        var next=snapshot("source",2,unchanged,object("source","new","added"));await(repository.publish(next,before));
        var restored=loaded(repository,"source");assertEquals(next.identities(),restored.identities(),component);assertEquals(next.rules(),restored.rules());stale(restored);
    }

    @ParameterizedTest @ValueSource(strings={"encoded_text","oversized_text"})
    void restoreRejectsNonBlobRulesBeforeDecodingEvenWhenCharacterLengthFits(String payload)throws Exception {
        var repository=new MetadataRepository(root);await(repository.publish(snapshot("source",1,object("source","table","retained")),empty("source")));
        if(payload.equals("encoded_text"))sql("UPDATE publication SET identifier_rules=CAST(identifier_rules AS TEXT) WHERE source='source'");
        else try(var db=open();var update=db.prepareStatement("UPDATE publication SET identifier_rules=? WHERE source='source'")){update.setString(1,"😀".repeat(200001));update.executeUpdate();}
        try(var db=open();var statement=db.createStatement();var rows=statement.executeQuery("SELECT typeof(identifier_rules),length(identifier_rules),length(CAST(identifier_rules AS BLOB)) FROM publication WHERE source='source'")){
            assertTrue(rows.next());assertEquals("text",rows.getString(1));assertTrue(rows.getLong(2)<=IdentifierRules.MAX_ENCODED_BYTES);if(payload.equals("oversized_text"))assertTrue(rows.getLong(3)>IdentifierRules.MAX_ENCODED_BYTES);
        }
        assertTrue(repository.load().isEmpty());assertEquals("REBUILT_CORRUPT",repository.cacheState());
    }

    @Test void sqlRuleProjectionDoesNotReturnAnOversizedOrWrongTypePayload()throws Exception {
        var repository=new MetadataRepository(root);await(repository.publish(snapshot("source",1,object("source","table","retained")),empty("source")));
        var field=MetadataRepository.class.getDeclaredField("RULE_PAYLOAD");field.setAccessible(true);String projection=(String)field.get(null);
        try(var db=open();var statement=db.createStatement();var rows=statement.executeQuery("SELECT "+projection+" FROM publication WHERE source='source'")){assertTrue(rows.next());assertArrayEquals(RULES.encode(),rows.getBytes(1));}
        for(String update:List.of("CAST(identifier_rules AS TEXT)","zeroblob("+(IdentifierRules.MAX_ENCODED_BYTES+1)+")","zeroblob(0)")){
            sql("UPDATE publication SET identifier_rules="+update+" WHERE source='source'");
            try(var db=open();var statement=db.createStatement();var rows=statement.executeQuery("SELECT "+projection+" FROM publication WHERE source='source'")){assertTrue(rows.next());assertNull(rows.getObject(1),"The SQLite result itself must not contain the rejected payload");}
        }
    }

    @ParameterizedTest @ValueSource(strings={"create","execute","execute_and_close"})
    void initializationFailureClosesItsOwnedConnectionAndPreservesTheOriginalFailure(String phase)throws Exception {
        var original=new SQLException("fixture initialization failure","08006");var statementClose=new SQLException("fixture statement close","08006");var connectionClose=new SQLException("fixture connection close","08006");var closes=new AtomicInteger();
        var statement=(Statement)Proxy.newProxyInstance(Statement.class.getClassLoader(),new Class[]{Statement.class},(p,m,a)->switch(m.getName()){
            case "execute"->throw original;
            case "close"->{if(phase.equals("execute_and_close"))throw statementClose;yield null;}
            default->throw new AssertionError("Unexpected initialization statement operation");
        });
        var connection=(Connection)Proxy.newProxyInstance(Connection.class.getClassLoader(),new Class[]{Connection.class},(p,m,a)->switch(m.getName()){
            case "createStatement"->{if(phase.equals("create"))throw original;yield statement;}
            case "close"->{closes.incrementAndGet();if(phase.equals("execute_and_close"))throw connectionClose;yield null;}
            default->throw new AssertionError("Unexpected initialization connection operation");
        });
        // Reflection reaches only our private resource-initialization helper;
        // no driver registry, production injection seam or SDK class is changed.
        var initialize=MetadataRepository.class.getDeclaredMethod("initializeConnection",Connection.class);initialize.setAccessible(true);
        assertSame(original,assertThrows(InvocationTargetException.class,()->initialize.invoke(null,connection)).getCause());assertEquals(1,closes.get());
        assertEquals(phase.equals("execute_and_close")?List.of(statementClose,connectionClose):List.of(),List.of(original.getSuppressed()));
    }

    @Test void expiredCancelledAndInterruptedWritesLeaveTheCommittedPredecessorIntact()throws Exception {
        var repository=new MetadataRepository(root);var before=snapshot("source",1,object("source","old","retained"));await(repository.publish(before,empty("source")));var next=snapshot("source",2,object("source","new","changed"));
        assertThrows(SQLTimeoutException.class,()->await(repository.publish(next,before,0)));
        var context=io.grpc.Context.current().withCancellation();var previous=context.attach();
        try{context.cancel(null);assertEquals("57014",assertThrows(SQLException.class,()->await(repository.publish(next,before))).getSQLState());}finally{context.detach(previous);context.close();}
        Thread.currentThread().interrupt();try{assertEquals("57014",assertThrows(SQLException.class,()->await(repository.publish(next,before))).getSQLState());assertTrue(Thread.currentThread().isInterrupted());}finally{Thread.interrupted();}
        assertEquals(before.identities(),loaded(repository,"source").identities());
        await(repository.publish(next,before));assertEquals(next.identities(),loaded(repository,"source").identities());
    }

    @Test void sqliteBusyWaitHonorsTheCallerDeadlineAndRollsBackBeforeLockRelease()throws Exception {
        var repository=new MetadataRepository(root);var before=snapshot("source",1,object("source","old","retained"));await(repository.publish(before,empty("source")));var next=snapshot("source",2,object("source","new","changed"));
        try(var blocker=open();var lock=blocker.createStatement();var workers=Executors.newVirtualThreadPerTaskExecutor()){
            lock.execute("BEGIN IMMEDIATE");
            try{var finished=workers.submit(()->{
                    var receipt=repository.publish(next,before,System.nanoTime()+TimeUnit.MILLISECONDS.toNanos(300));
                    long until=System.nanoTime()+TimeUnit.SECONDS.toNanos(30);
                    var failure=assertThrows(SQLException.class,()->receipt.await(until));
                    return Map.entry(failure,receipt.awaitCompletion(until));
                });
                var terminal=finished.get(3,TimeUnit.SECONDS);
                var timeout=assertInstanceOf(SQLTimeoutException.class,terminal.getKey(),"The write must stop while the external SQLite writer is still held");assertEquals("57014",timeout.getSQLState());
                var completion=terminal.getValue();var facts=completion.failure();assertNotNull(facts);assertEquals(MetadataRepository.FailureReason.TIMED_OUT,facts.primary().reason());assertEquals("57014",facts.primary().sqlState());assertFalse(facts.factsLimited());
                assertEquals(1,facts.suppressed().size(),"The exact failed BEGIN must retain its single SQLITE_BUSY fact");assertEquals(5,facts.suppressed().getFirst().vendorCode());
                assertFalse(completion.transactionBegan());assertFalse(completion.rollbackAttempted(),"A BEGIN that never acquired a transaction must not attempt a spurious rollback");assertFalse(completion.rollbackAcknowledged());
                assertEquals(MetadataRepository.CommitOutcome.NOT_ATTEMPTED,completion.metrics().commitOutcome());assertEquals(0,completion.metrics().rollbackNanos());
                assertEquals(before.identities(),loaded(repository,"source").identities());
            }finally{lock.execute("ROLLBACK");}
        }
        await(repository.publish(next,before));assertEquals(next.identities(),loaded(repository,"source").identities());
    }

    @Test void releasedSqliteWriteReservationAllowsOneCompletePublicationWithoutReplay()throws Exception {
        var repository=new MetadataRepository(root);var before=snapshot("source",1,object("source","old","retained"));await(repository.publish(before,empty("source")));var next=snapshot("source",2,object("source","new","changed"));
        sql("CREATE TABLE publication_attempt(n INTEGER)");sql("CREATE TRIGGER count_publication BEFORE INSERT ON publication WHEN NEW.revision=2 BEGIN INSERT INTO publication_attempt VALUES(1); END");
        try(var blocker=open();var lock=blocker.createStatement();var workers=Executors.newVirtualThreadPerTaskExecutor()){
            lock.execute("BEGIN IMMEDIATE");var entered=new CountDownLatch(1);
            var finished=workers.submit(()->{entered.countDown();await(repository.publish(next,before,System.nanoTime()+TimeUnit.SECONDS.toNanos(3)));return true;});
            try{assertTrue(entered.await(1,TimeUnit.SECONDS));assertThrows(TimeoutException.class,()->finished.get(100,TimeUnit.MILLISECONDS),"The cache writer must wait for its initial write reservation");}finally{lock.execute("ROLLBACK");}
            assertTrue(finished.get(3,TimeUnit.SECONDS));
        }
        assertEquals(next.identities(),loaded(repository,"source").identities());assertEquals("AVAILABLE",repository.cacheState());
        try(var db=open();var statement=db.createStatement();var rows=statement.executeQuery("SELECT COUNT(*) FROM publication_attempt")){assertTrue(rows.next());assertEquals(1,rows.getInt(1));}
    }

    @Test void sqliteVmDeadlineRollsBackPartialBatchesInsteadOfPublishingATruncatedCache()throws Exception {
        var repository=new MetadataRepository(root);var before=snapshot("source",1,object("source","old","retained"));await(repository.publish(before,empty("source")));
        sql("CREATE TRIGGER slow_write BEFORE INSERT ON object WHEN NEW.name='slow' BEGIN SELECT SUM(x) FROM (WITH RECURSIVE count(x) AS (VALUES(0) UNION ALL SELECT x+1 FROM count WHERE x<10000000) SELECT x FROM count); END");
        var next=snapshot("source",2,object("source","earlier","written-first"),object("source","slow","delayed"));
        assertThrows(SQLTimeoutException.class,()->await(repository.publish(next,before,System.nanoTime()+TimeUnit.MILLISECONDS.toNanos(100))));
        assertEquals(before.identities(),loaded(repository,"source").identities());sql("DROP TRIGGER slow_write");
        await(repository.publish(next,before));assertEquals(next.identities(),loaded(repository,"source").identities());
    }
}
