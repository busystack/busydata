package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.*;
import java.nio.file.Path;
import java.sql.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static io.busystack.busydata.metadata.MetadataCacheTestAccess.await;
import static org.junit.jupiter.api.Assertions.*;

class MetadataStoredContentTest {
    @TempDir Path root;
    private static final String SOURCE="source",PROFILE="profile";
    private static final IdentifierRules RULES=new IdentifierRules(Engine.POSTGRESQL,0);
    private static MetadataObject object(String name) {
        return MetadataObject.from(SOURCE,PROFILE,"",RULES,SchemaObject.newBuilder().setKind(ObjectKind.TABLE)
            .setCatalog("db").setSchema("public").setName(name).putProperties("remarks","exact 😀\u0000value").build(),IntrospectionLevel.STRUCTURE,1,1);
    }
    private static MetadataSnapshot snapshot(long revision,MetadataObject... objects) {
        var scope=new MetadataScope("db","public","",ObjectKind.TABLE);
        var coverage=new MetadataCoverage(scope,IntrospectionLevel.STRUCTURE,MetadataState.AVAILABLE,true,"fresh-"+revision,revision,1,revision,"default namespace", "public");
        return new MetadataSnapshot(SOURCE,PROFILE,revision,1,revision,RULES,List.of(objects),Map.of(scope,coverage));
    }
    private static MetadataSnapshot empty(){return MetadataSnapshot.empty(SOURCE,PROFILE,RULES);}
    private Connection open()throws SQLException{return DriverManager.getConnection("jdbc:sqlite:"+root.resolve("metadata_catalog.sqlite"));}
    private void sql(String statement)throws SQLException{try(var db=open();var s=db.createStatement()){s.execute(statement);}}
    private boolean matches(MetadataSnapshot snapshot)throws SQLException{try(var db=open()){return MetadataStoredContent.matches(db,snapshot,()->{});}}
    private MetadataRepository seed(MetadataSnapshot snapshot)throws Exception {
        var repository=new MetadataRepository(root);await(repository.publish(snapshot,empty()));return repository;
    }
    private void guardBody()throws SQLException {
        for(String table:List.of("object","property"))for(String operation:List.of("INSERT","UPDATE","DELETE"))
            sql("CREATE TRIGGER forbid_"+table+"_"+operation+" BEFORE "+operation+" ON "+table+" BEGIN SELECT RAISE(ABORT,'unchanged cache body rewritten'); END");
    }

    @Test void freshAcquisitionWithoutAMemoryPredecessorRetainsOnlyAnExactlyEqualBody()throws Exception {
        var table=object("table");var first=snapshot(1,table);var repository=seed(first);guardBody();
        var fresh=snapshot(2,table);assertTrue(matches(fresh));await(repository.publish(fresh,empty()));
        try(var db=open();var s=db.createStatement()) {
            try(var rows=s.executeQuery("SELECT revision,configuration_revision,created FROM publication")){assertTrue(rows.next());assertEquals(2,rows.getLong(1));assertEquals(1,rows.getLong(2));assertEquals(2,rows.getLong(3));assertFalse(rows.next());}
            try(var rows=s.executeQuery("SELECT fingerprint,source_revision,refreshed,complete,state,default_namespace FROM coverage")){assertTrue(rows.next());assertEquals("fresh-2",rows.getString(1));assertEquals(2,rows.getLong(2));assertEquals(2,rows.getLong(3));assertTrue(rows.getBoolean(4));assertEquals("AVAILABLE",rows.getString(5));assertEquals("public",rows.getString(6));assertFalse(rows.next());}
        }
        assertEquals(fresh.identities(),new MetadataRepository(root).load().getFirst().identities());
        assertEquals("AVAILABLE",repository.cacheState());assertTrue(repository.activeReceipt().isEmpty());
    }

    @ParameterizedTest @ValueSource(strings={"catalog","schema_name","kind","subtype","parent","name","signature","native_key","display_name","quoted_name","lookup_key","source_text","level","state","source_revision","context_revision"})
    void everyStoredObjectFieldMustMatchBeforeReuse(String column)throws Exception {
        var table=object("table");var repository=seed(snapshot(1,table));
        String replacement=Set.of("kind","subtype","level","source_revision","context_revision").contains(column)?column+"+4294967296":"'different'";
        sql("UPDATE object SET "+column+"="+replacement);
        var fresh=snapshot(2,table);assertFalse(matches(fresh),column);await(repository.publish(fresh,empty()));
        assertTrue(matches(fresh));assertEquals(fresh.identities(),new MetadataRepository(root).load().getFirst().identities());
    }

    @ParameterizedTest @ValueSource(strings={"profile","configuration","future_revision","engine","case_rule","rules_blob","rules_text","rules_large","revision_type"})
    void publicationOwnershipAndNativeRulesMustMatch(String component)throws Exception {
        var table=object("table");var repository=seed(snapshot(1,table));
        sql(switch(component) {
            case "profile"->"UPDATE publication SET profile='other'";
            case "configuration"->"UPDATE publication SET configuration_revision=2";
            case "future_revision"->"UPDATE publication SET revision=3";
            case "engine"->"UPDATE publication SET engine="+Engine.MYSQL.getNumber();
            case "case_rule"->"UPDATE publication SET case_rule=1";
            case "rules_blob"->"UPDATE publication SET identifier_rules=zeroblob(8)";
            case "rules_text"->"UPDATE publication SET identifier_rules=CAST(identifier_rules AS TEXT)";
            case "rules_large"->"UPDATE publication SET identifier_rules=zeroblob("+(IdentifierRules.MAX_ENCODED_BYTES+1)+")";
            case "revision_type"->"UPDATE publication SET revision=1.5";
            default->throw new AssertionError();
        });
        var fresh=snapshot(2,table);assertFalse(matches(fresh),component);await(repository.publish(fresh,empty()));assertTrue(matches(fresh));
    }

    @ParameterizedTest @ValueSource(strings={"missing_object","extra_object","substituted_object","missing_property","extra_property","wrong_value","blob_value","oversized_value","orphan_property","blob_name","blob_identity","wrong_number_type"})
    void missingExtraCorruptAndOversizedRowsCannotBeMistakenForEqualContent(String corruption)throws Exception {
        var table=object("table");var repository=seed(snapshot(1,table));
        switch(corruption) {
            case "missing_object"->sql("DELETE FROM object");
            case "extra_object","substituted_object"->{
                var extra=object("extra");var expanded=snapshot(1,table,extra);await(repository.publish(expanded,snapshot(1,table)));
                if(corruption.equals("substituted_object"))sql("DELETE FROM object WHERE name='table'");
            }
            case "missing_property"->sql("DELETE FROM property");
            case "extra_property"->sql("INSERT INTO property SELECT source,identity,'extra','value' FROM object");
            case "wrong_value"->sql("UPDATE property SET value='different'");
            case "blob_value"->sql("UPDATE property SET value=CAST(value AS BLOB)");
            case "oversized_value"->sql("UPDATE property SET value=replace(hex(zeroblob(150000)),'0','x')");
            case "orphan_property"->sql("INSERT INTO property VALUES('source','missing','extra','value')");
            case "blob_name"->sql("UPDATE object SET name=CAST(name AS BLOB)");
            case "blob_identity"->sql("UPDATE object SET identity=CAST(identity AS BLOB)");
            case "wrong_number_type"->sql("UPDATE object SET source_revision=1.5");
            default->throw new AssertionError();
        }
        var fresh=snapshot(2,table);assertFalse(matches(fresh),corruption);await(repository.publish(fresh,empty()));
        assertTrue(matches(fresh));assertEquals(fresh.identities(),new MetadataRepository(root).load().getFirst().identities());
    }

    @Test void failedHeaderPublicationKeepsTheOldHeaderCoverageAndUnchangedBodyTogether()throws Exception {
        var table=object("table");var first=snapshot(1,table);var repository=seed(first);guardBody();
        sql("CREATE TRIGGER reject_header BEFORE UPDATE ON publication BEGIN SELECT RAISE(ABORT,'fixture header failure'); END");
        assertThrows(SQLException.class,()->await(repository.publish(snapshot(2,table),empty())));
        try(var db=open();var s=db.createStatement()) {
            try(var rows=s.executeQuery("SELECT revision FROM publication")){assertTrue(rows.next());assertEquals(1,rows.getLong(1));}
            try(var rows=s.executeQuery("SELECT fingerprint FROM coverage")){assertTrue(rows.next());assertEquals("fresh-1",rows.getString(1));}
        }
        assertTrue(matches(first));
    }

    @Test void proofChecksItsBudgetDuringRowsAndDoesNotChangeStoredMetadata()throws Exception {
        var first=snapshot(1,object("one"),object("two"));seed(first);
        var checks=new java.util.concurrent.atomic.AtomicInteger();var expired=new SQLTimeoutException("fixture proof deadline","57014");
        try(var db=open()) {
            assertSame(expired,assertThrows(SQLTimeoutException.class,()->MetadataStoredContent.matches(db,snapshot(2,object("one"),object("two")),()->{if(checks.incrementAndGet()==6)throw expired;})));
        }
        assertEquals(6,checks.get());assertTrue(matches(first));
    }
}
