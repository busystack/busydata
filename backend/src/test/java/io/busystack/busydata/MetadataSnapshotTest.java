package io.busystack.busydata;

import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import java.nio.file.*;
import java.sql.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static io.busystack.busydata.metadata.MetadataCacheTestAccess.await;
import static org.junit.jupiter.api.Assertions.*;

class MetadataSnapshotTest {
    @TempDir Path root;
    private static final IdentifierRules PG=new IdentifierRules(Engine.POSTGRESQL,0);
    private static MetadataObject object(String schema,String parent,String name,ObjectKind kind,Map<String,String> properties) {
        return MetadataObject.from("source","profile","",PG,SchemaObject.newBuilder().setCatalog("database").setSchema(schema).setTable(parent).setName(name).setKind(kind).putAllProperties(properties).build(),IntrospectionLevel.STRUCTURE,7,3);
    }
    private static MetadataSnapshot snapshot(long revision,List<MetadataObject> objects) {
        var scope=new MetadataScope("database","public","",ObjectKind.TABLE);
        return new MetadataSnapshot("source","profile",revision,2,123,PG,objects,Map.of(scope,new MetadataCoverage(scope,IntrospectionLevel.STRUCTURE,MetadataState.AVAILABLE,true,"fingerprint",7,3,123,"")));
    }
    @Test void exactIdentityQuotedLookupOverloadsAndParentsAreIndependentOfLabels() {
        var table=object("public","","Mixed table",ObjectKind.TABLE,Map.of());
        var column=object("public","Mixed table","value, quoted\"",ObjectKind.COLUMN,Map.of("type","numeric(40,12)"));
        var same=object("audit","","Mixed table",ObjectKind.TABLE,Map.of());
        var model=snapshot(4,List.of(table,column,same));
        assertEquals(1,model.resolve("database","public",ObjectKind.TABLE,"","Mixed table",true).size());
        assertTrue(model.resolve("database","public",ObjectKind.TABLE,"","Mixed table",false).isEmpty());
        assertEquals(table.identity().key(),model.projection(column).getParentIdentity());
        assertEquals("\"value, quoted\"\"\"",model.projection(column).getQuotedIdentifier());
        assertNotEquals(table.identity().key(),same.identity().key());
        var one=new MetadataIdentity("source","profile","database","public",ObjectKind.ROUTINE,ObjectSubtype.FUNCTION,"","f","f(integer)","");
        var two=new MetadataIdentity("source","profile","database","public",ObjectKind.ROUTINE,ObjectSubtype.FUNCTION,"","f","f(text)","");
        assertNotEquals(one.key(),two.key());
        assertNotEquals(new MetadataIdentity("a","bc","database","public",ObjectKind.TABLE,ObjectSubtype.ORDINARY_TABLE,"","t","","").key(),new MetadataIdentity("ab","c","database","public",ObjectKind.TABLE,ObjectSubtype.ORDINARY_TABLE,"","t","","").key());
        assertThrows(UnsupportedOperationException.class,()->model.identities().clear());assertThrows(UnsupportedOperationException.class,()->model.objects().clear());
    }
    @Test void engineCaseRulesAndQuotingUseServerPolicy() {
        assertEquals("mixed",PG.lookup(ObjectKind.TABLE,"Mixed",false));assertEquals("Mixed",PG.lookup(ObjectKind.TABLE,"Mixed",true));
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB)) {
            assertEquals("Mixed",new IdentifierRules(engine,0).lookup(ObjectKind.TABLE,"Mixed",false));
            assertEquals("mixed",new IdentifierRules(engine,1).lookup(ObjectKind.TABLE,"Mixed",true));
            assertEquals("mixed",new IdentifierRules(engine,2).lookup(ObjectKind.TABLE,"Mixed",false));
            assertEquals("mixed",new IdentifierRules(engine,0).lookup(ObjectKind.COLUMN,"Mixed",true));
            assertEquals("`a``b`",new IdentifierRules(engine,0).quote("a`b"));
        }
    }
    @Test void partialNamesAndStaleCoverageCannotImplyStructuralAbsence() {
        var scope=new MetadataScope("database","public","",ObjectKind.TABLE);
        var names=new MetadataSnapshot("source","profile",1,1,123,PG,List.of(object("public","","t",ObjectKind.TABLE,Map.of())),Map.of(scope,new MetadataCoverage(scope,IntrospectionLevel.NAMES,MetadataState.AVAILABLE,true,"v1",7,3,123,"")));
        assertTrue(names.complete(scope,IntrospectionLevel.NAMES));assertFalse(names.complete(scope,IntrospectionLevel.STRUCTURE));
        var stale=new MetadataSnapshot("source","profile",2,1,124,PG,names.identities().values(),Map.of(scope,names.coverage(scope).orElseThrow().stale("External DDL requires reconciliation")));
        assertFalse(stale.complete(scope,IntrospectionLevel.NAMES));assertEquals(names.objects().size(),stale.objects().size());assertTrue(names.complete(scope,IntrospectionLevel.NAMES));
        assertFalse(names.incomingComplete());assertFalse(names.outgoingComplete("database","public","t"));
    }
    @Test void compositeRelationshipsPreserveExactComponentsAndIncomingIndex() {
        var relation=object("public","child","fk, exact",ObjectKind.FOREIGN_KEY,Map.of("relationshipVerified","true","columnCount","2","column.0","a,b","column.1","c\"d","referencedColumn.0","x,y","referencedColumn.1","z\"q","referencedCatalog","database","referencedSchema","audit","referencedTable","parent"));
        var model=snapshot(3,List.of(relation));
        assertEquals(List.of(relation),model.outgoing("database","public","child"));assertEquals(List.of(relation),model.incoming("database","audit","parent"));
        assertEquals("a,b",model.incoming("database","audit","parent").getFirst().properties().get("column.0"));
        assertTrue(model.incoming("another database","audit","parent").isEmpty());
    }
    @Test void normalizedPersistenceIsAtomicAndRestartIsExplicitlyStale()throws Exception {
        var repository=new MetadataRepository(root);var empty=MetadataSnapshot.empty("source","profile",PG);
        var before=snapshot(1,List.of(object("public","","before",ObjectKind.TABLE,Map.of("remarks","one"))));await(repository.publish(before,empty));
        try(var db=DriverManager.getConnection("jdbc:sqlite:"+root.resolve("metadata_catalog.sqlite"));var statement=db.createStatement()) {
            try(var rows=statement.executeQuery("SELECT COUNT(*) FROM object")){assertTrue(rows.next());assertEquals(1,rows.getInt(1));}
            try(var rows=statement.executeQuery("SELECT name,value FROM property")){assertTrue(rows.next());assertEquals("remarks",rows.getString(1));assertEquals("one",rows.getString(2));}
            statement.execute("CREATE TRIGGER reject_new BEFORE INSERT ON object WHEN NEW.name='after' BEGIN SELECT RAISE(ABORT,'fixture publication failure'); END");
        }
        assertThrows(SQLException.class,()->await(repository.publish(snapshot(2,List.of(object("public","","after",ObjectKind.TABLE,Map.of()))),before)));
        var restarted=new MetadataRepository(root).load().getFirst();assertEquals(1,restarted.revision());assertEquals("before",restarted.objects().getFirst().getName());assertTrue(restarted.coverage().values().stream().allMatch(c->c.state()==MetadataState.STALE&&!c.complete()));
    }
    @ParameterizedTest @ValueSource(ints={2,3,4})
    void previousCacheFormatCannotRestoreMergedRoutineParametersOrChangeUserRecords(int previousFormat)throws Exception {
        var profile=Profile.newBuilder().setId("profile").setName("Preserved profile").setEngine(Engine.MYSQL).setDatabase("db").build();
        var configuration=MetadataConfiguration.defaults();
        var draft=StoredEditDraft.newBuilder().setTarget(profile).setDocumentId("preserved-document").setSourceSql("SELECT id FROM db.preserved_rows").setSchemaSignature("preserved-structural-proof")
            .setChanges(ChangeRequest.newBuilder().setCatalog("db").setSchema("db").setTable("preserved_rows")).build();
        try(var user=new io.busystack.busydata.storage.MetadataStore(root)) {
            user.save(profile);user.metadataConfiguration("source",configuration);String draftId=user.saveEditDraft("",draft);
            var rules=new IdentifierRules(Engine.MYSQL,0);var scope=new MetadataScope("db","db","",ObjectKind.ROUTINE);
            var merged=SchemaObject.newBuilder().setCatalog("db").setSchema("db").setName("same_name").setKind(ObjectKind.ROUTINE).setSubtype(ObjectSubtype.FUNCTION).setIdentifier("FUNCTION:same_name")
                .putProperties("parameterCount","5").putProperties("signatureAvailability","AVAILABLE").putProperties("signature","same_name(int, int, int, int, int)").build();
            var cached=new MetadataSnapshot("source","profile",1,1,123,rules,List.of(MetadataObject.from("source","profile","",rules,merged,IntrospectionLevel.STRUCTURE,1,1)),
                Map.of(scope,new MetadataCoverage(scope,IntrospectionLevel.STRUCTURE,MetadataState.AVAILABLE,true,"unchanged-native-last-altered",1,1,123,"")));
            await(new MetadataRepository(root).publish(cached,MetadataSnapshot.empty("source","profile",rules)));
            // Real previous layouts used a rowid properties table. Format 2
            // could additionally merge function/procedure PARAMETERS rows.
            try(var db=DriverManager.getConnection("jdbc:sqlite:"+root.resolve("metadata_catalog.sqlite"));var statement=db.createStatement()){
                statement.execute("ALTER TABLE property RENAME TO current_property");
                statement.execute("CREATE TABLE property(source TEXT NOT NULL,identity TEXT NOT NULL,name TEXT NOT NULL,value TEXT NOT NULL,PRIMARY KEY(source,identity,name),FOREIGN KEY(source,identity) REFERENCES object(source,identity) ON DELETE CASCADE)");
                statement.execute("INSERT INTO property SELECT source,identity,name,value FROM current_property");
                statement.execute("DROP TABLE current_property");
                try(var rows=statement.executeQuery("SELECT sql FROM sqlite_master WHERE name='property'")){assertTrue(rows.next());assertFalse(rows.getString(1).contains("WITHOUT ROWID"));}
                statement.execute("PRAGMA user_version="+previousFormat);
            }
            var rebuilt=new MetadataRepository(root);assertEquals("REBUILT_VERSION",rebuilt.cacheState());assertTrue(rebuilt.load().isEmpty(),"An unchanged native fingerprint cannot revive parameters acquired with obsolete semantics");
            try(var db=DriverManager.getConnection("jdbc:sqlite:"+root.resolve("metadata_catalog.sqlite"));var statement=db.createStatement()){
                try(var rows=statement.executeQuery("PRAGMA user_version")){assertTrue(rows.next());assertEquals(5,rows.getInt(1));}
                try(var rows=statement.executeQuery("SELECT sql FROM sqlite_master WHERE name='property'")){assertTrue(rows.next());assertTrue(rows.getString(1).contains("WITHOUT ROWID"));}
                try(var rows=statement.executeQuery("SELECT COUNT(*) FROM property")){assertTrue(rows.next());assertEquals(0,rows.getInt(1));}
            }
            assertEquals(List.of(profile),user.profiles());assertEquals(configuration,user.metadataConfigurations().get("source"));assertEquals(draft,user.editDraft(draftId).data());
            try(var db=DriverManager.getConnection("jdbc:sqlite:"+root.resolve("metadata.sqlite"));var statement=db.createStatement();var rows=statement.executeQuery("SELECT MAX(version) FROM migration")){assertTrue(rows.next());assertEquals(4,rows.getInt(1),"Rebuilding the catalog preserves the separate user-data schema");}
            var current=new MetadataRepository(root);assertEquals("AVAILABLE",current.cacheState());assertTrue(current.load().isEmpty());
        }
    }
    @Test void cacheCorruptionRebuildsOnlyDisposableMetadata()throws Exception {
        Files.writeString(root.resolve("metadata_catalog.sqlite"),"this is not a sqlite catalog");Files.writeString(root.resolve("user-drafts"),"preserve exact user intentions");
        assertTrue(new MetadataRepository(root).load().isEmpty());assertEquals("preserve exact user intentions",Files.readString(root.resolve("user-drafts")));
    }
    @Test void logicallyCorruptCacheRowsRebuildAfterClosingReaders()throws Exception {
        var repository=new MetadataRepository(root);await(repository.publish(snapshot(1,List.of(object("public","","table",ObjectKind.TABLE,Map.of()))),MetadataSnapshot.empty("source","profile",PG)));
        try(var db=DriverManager.getConnection("jdbc:sqlite:"+root.resolve("metadata_catalog.sqlite"));var statement=db.createStatement()){statement.executeUpdate("UPDATE object SET kind=999");}
        var recovered=new MetadataRepository(root);assertTrue(recovered.load().isEmpty());assertEquals("REBUILT_CORRUPT",recovered.cacheState());assertTrue(new MetadataRepository(root).load().isEmpty());
    }
    @Test void configurationPatternsAndScopeKeysAreBoundedAndUnambiguous() {
        assertTrue(MetadataConfiguration.matches("audit_*?","audit_table1"));assertFalse(MetadataConfiguration.matches("audit_*?","audit_"));
        var key=MetadataConfiguration.scopeKey("database/one","schema.漢");assertEquals(List.of("database/one","schema.漢"),MetadataConfiguration.scopeParts(key));
        var config=new MetadataConfiguration(2,Set.of("database"),Set.of(),Set.of("public"),Set.of(),false,Set.of(ObjectKind.TABLE),List.of("allowed*"),List.of("*private*"),IntrospectionLevel.NAMES,Map.of(MetadataConfiguration.scopeKey("database","public"),IntrospectionLevel.SOURCE));
        assertTrue(config.permits("database","public",ObjectKind.TABLE,"allowed_table"));assertFalse(config.permits("database","public",ObjectKind.TABLE,"allowed_private_table"));assertFalse(config.permits("database","audit",ObjectKind.TABLE,"allowed_table"));assertEquals(IntrospectionLevel.SOURCE,config.level("database","public"));
    }
    @Test void scopeOverlapDetectsBroadAndExactRefreshRacesWithoutConflatingNamespaces() {
        var broad=new MetadataScope("database","public","",ObjectKind.TABLE);
        var exact=new MetadataScope("database","public","",ObjectKind.TABLE,"one",true,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED);
        assertTrue(broad.overlaps(exact));assertTrue(exact.overlaps(broad));assertTrue(broad.encloses(exact));assertFalse(exact.encloses(broad));
        assertFalse(exact.overlaps(new MetadataScope("database","public","",ObjectKind.TABLE,"another",true,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED)));
        assertFalse(broad.overlaps(new MetadataScope("database","audit","",ObjectKind.TABLE)));
        assertTrue(new MetadataScope("database","public","",ObjectKind.COLUMN).overlaps(new MetadataScope("database","public","one",ObjectKind.COLUMN)));
        var routines=new MetadataScope("database","public","",ObjectKind.ROUTINE);
        var function=new MetadataScope("database","public","",ObjectKind.ROUTINE,"same",true,"",ObjectSubtype.FUNCTION);
        var procedure=new MetadataScope("database","public","",ObjectKind.ROUTINE,"same",true,"",ObjectSubtype.PROCEDURE);
        assertTrue(routines.overlaps(function));assertTrue(function.overlaps(routines));assertTrue(routines.overlaps(procedure));assertTrue(procedure.overlaps(routines));
        assertFalse(function.overlaps(procedure));assertFalse(procedure.overlaps(function));
    }
    @Test void largeCatalogKeepsTargetedLookupIndexedAndBounded() {
        var entries=new ArrayList<MetadataObject>();
        for(int index=0;index<10_000;index++) {
            String schema="schema_"+(index%100),table="table_"+(index/100);entries.add(object(schema,"",table,ObjectKind.TABLE,Map.of()));
            for(int column=0;column<10;column++)entries.add(object(schema,table,"c"+column,ObjectKind.COLUMN,Map.of("type","numeric","jdbcType",Integer.toString(Types.NUMERIC))));
            if(index<3000)entries.add(object(schema,table,"pk",ObjectKind.CONSTRAINT,Map.of("type","PRIMARY KEY","column.0","c0","columnCount","1")));
            if(index<2000)entries.add(object(schema,table,"fk",ObjectKind.FOREIGN_KEY,Map.of("relationshipVerified","true","referencedCatalog","database","referencedSchema","schema_0","referencedTable","table_0","columnCount","1","column.0","c1","referencedColumn.0","c0")));
        }
        for(int index=0;index<3000;index++)entries.add(MetadataObject.from("source","profile","",PG,SchemaObject.newBuilder().setCatalog("database").setSchema("schema_"+(index%100)).setName("routine_"+(index/100)).setKind(ObjectKind.ROUTINE).setIdentifier("routine_"+(index/100)+"(integer)").putProperties("signature","(integer)").build(),IntrospectionLevel.STRUCTURE,7,3));
        var model=new MetadataSnapshot("source","profile",1,1,123,PG,entries,Map.of());assertEquals(118_000,model.identities().size());assertTrue(model.estimatedBytes()<=MetadataSnapshot.MAX_BYTES);
        var timings=new long[1000];for(int i=0;i<timings.length;i++){long start=System.nanoTime();assertEquals(1,model.resolve("database","schema_99",ObjectKind.COLUMN,"table_99","c9",true).size());timings[i]=System.nanoTime()-start;}
        Arrays.sort(timings);System.out.println("Metadata fixture: 10000 relations, 100000 columns, 3000 constraints, 2000 FKs, 3000 routines; indexed lookup p95 nanoseconds="+timings[950]+"; estimated bytes="+model.estimatedBytes());
    }
}
