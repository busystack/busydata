package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.Explorer;
import java.nio.file.Path;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

/** Real catalogs: similarly named objects must retain their physical database. */
class ExplorerNamespacesIT {
    @TempDir Path root;

    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void wideColumnsRetainExactOrdinalGeneratedEvidenceAndBrowseScope(String engine)throws Exception {
        try(var f=new EngineFixture(root,engine)) {
            var s=f.open();var explorer=new Explorer(f.metadata);boolean pg=f.engine==Engine.POSTGRESQL;
            var columns=new ArrayList<String>();columns.add("id INTEGER PRIMARY KEY");
            for(int i=0;i<160;i++)columns.add("c%03d INTEGER DEFAULT 0".formatted(i));
            columns.add("z_generated INTEGER GENERATED ALWAYS AS (c159+1) STORED");
            columns.add(pg?"z_identity INTEGER GENERATED ALWAYS AS IDENTITY":"z_identity INTEGER AUTO_INCREMENT UNIQUE");
            f.execute(s,"CREATE TABLE wide_columns("+String.join(",",columns)+"); INSERT INTO wide_columns(id,c159) VALUES(1,41)");
            var request=ExploreRequest.newBuilder().setKind(ObjectKind.COLUMN).setCatalog("busydata").setSchema(f.schema()).setTable("wide_columns").build();
            var first=explorer.explore(s,request);assertEquals(128,first.getObjectsCount());assertFalse(first.getComplete());assertEquals("available",first.getAvailability());assertFalse(first.getContinuation().isEmpty());
            var second=explorer.explore(s,request.toBuilder().setContinuation(first.getContinuation()).build());assertTrue(second.getComplete());assertEquals(163,first.getObjectsCount()+second.getObjectsCount());
            assertEquals("YES",second.getObjectsList().stream().filter(o->o.getName().equals("z_generated")).findFirst().orElseThrow().getPropertiesOrThrow("generated"));
            assertEquals("YES",second.getObjectsList().stream().filter(o->o.getName().equals("z_identity")).findFirst().orElseThrow().getPropertiesOrThrow("autoIncrement"));
            var exact=explorer.explore(s,request.toBuilder().setExactName(true).setSearch("c159").setLimit(1).build());assertTrue(exact.getComplete());assertEquals(1,exact.getObjectsCount());
            var column=exact.getObjects(0);assertEquals("busydata",column.getCatalog());assertEquals(f.schema(),column.getSchema());assertEquals("wide_columns",column.getTable());assertEquals("161",column.getPropertiesOrThrow("ordinal"));
            var selected=explorer.explore(s,ExploreRequest.newBuilder().setKind(ObjectKind.TABLE).setCatalog("busydata").setSchema(f.schema()).setSearch("wide_columns").setExactName(true).setIntrospectionLevel(2).setLimit(2).build());
            assertTrue(selected.getComplete());assertEquals(1,selected.getObjectsCount());
            var browse=BrowseRequest.newBuilder().setSessionId(s.id).setMetadataObjectIdentity(selected.getObjects(0).getStableIdentity()).setMetadataSnapshotRevision(selected.getMetadataSnapshotRevision()).setCatalog("busydata").setSchema(f.schema()).setTable("wide_columns").setDocumentId("wide-owner").setRowLimit(10)
                .addConditions(RowCondition.newBuilder().setColumn("c159").setPredicate(ValuePredicate.EQUAL).setValue(Value.newBuilder().setSignedInteger("41"))).build();
            assertTrue(io.busystack.busydata.schema.TableBrowse.prepare(s,browse,explorer).sql().contains("c159"));
            f.warm(s,"wide_columns");
            String source=s.adapter.table(s.context.catalog(),f.schema(),"wide_columns");
            var job=f.execute(s,"SELECT id,z_generated,z_identity FROM "+source);var id=job.info().getResults(0).getResultId();
            var change=ChangeRequest.newBuilder().setSchema(f.schema()).setTable("wide_columns").setResultId(id);
            var planner=new io.busystack.busydata.schema.ChangePlanner(f.safety,f.results,f.metadata.metadataPlatform());
            assertFalse(planner.assess(s,change.build()).getEditableColumnsList().contains(2));
            assertThrows(IllegalArgumentException.class,()->planner.preview(s,change.addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE).setSourceRow(0).putValues(2,io.busystack.busydata.schema.Assignments.value(Value.newBuilder().setSignedInteger("99").build()))).build()));
        }
    }

    @Test void byteLimitedColumnPagesAndNamespaceWindowsAreNotCompleteEnumerations()throws Exception {
        try(var f=new EngineFixture(root,"POSTGRESQL")) {
            var s=f.open();var explorer=new Explorer(f.metadata);var columns=new ArrayList<String>();
            for(int i=0;i<160;i++)columns.add("c%03d VARCHAR(10000) DEFAULT '%s'".formatted(i,"x".repeat(8000)));
            f.execute(s,"CREATE TABLE byte_columns("+String.join(",",columns)+")");
            var request=ExploreRequest.newBuilder().setKind(ObjectKind.COLUMN).setSchema("public").setTable("byte_columns").build();
            var first=explorer.explore(s,request);assertFalse(first.getComplete());assertTrue(first.getObjectsCount()<128);assertEquals("available",first.getAvailability());
            var seen=new HashSet<String>();String cursor="";int pages=0;
            do {var page=explorer.explore(s,request.toBuilder().setContinuation(cursor).build());for(var object:page.getObjectsList())assertTrue(seen.add(object.getName()));cursor=page.getContinuation();assertTrue(++pages<10);}while(!cursor.isEmpty());
            assertEquals(160,seen.size());
            explorer.explore(s,request.toBuilder().setRefresh(true).build());
            assertThrows(Explorer.ContinuationFailure.class,()->explorer.explore(s,request.toBuilder().setContinuation(first.getContinuation()).build()));
            for(int i=0;i<160;i++)f.execute(s,"CREATE SCHEMA namespace_%03d".formatted(i));
            var namespaces=explorer.explore(s,ExploreRequest.newBuilder().setKind(ObjectKind.SCHEMA).setIndependentMetadata(true).build());
            assertFalse(namespaces.getComplete());assertTrue(namespaces.getTotalCount()>128);
            var exact=explorer.explore(s,ExploreRequest.newBuilder().setKind(ObjectKind.SCHEMA).setSearch("namespace_159").setExactName(true).setLimit(1).build());
            assertEquals("namespace_159",exact.getObjects(0).getName());assertEquals("busydata",exact.getObjects(0).getCatalog());assertEquals("busydata",s.context.catalog());
        }
    }

    @Test void postgresSchemasComeFromTheRequestedPhysicalDatabase()throws Exception {
        try(var fixture=new EngineFixture(root,"POSTGRESQL")) {
            var source=fixture.open();
            fixture.execute(source,"CREATE SCHEMA first_only; CREATE TABLE public.customers(first_database integer); CREATE DATABASE second_database");
            var second=fixture.sessions.open(OpenRequest.newBuilder().setProfile(fixture.profile).setCatalog("second_database").setPassword("fixture").build());
            assertEquals("second_database",second.context.catalog());assertEquals("busydata",second.profile.getDatabase());
            fixture.execute(second,"CREATE SCHEMA second_only; CREATE TABLE public.customers(second_database text); ALTER ROLE busydata IN DATABASE second_database SET search_path=second_only,public");
            var explorer=new Explorer(fixture.metadata);
            var schemas=explorer.explore(source,ExploreRequest.newBuilder().setKind(ObjectKind.SCHEMA).setCatalog("second_database").build());
            assertTrue(schemas.getObjectsList().stream().anyMatch(o->o.getName().equals("second_only")),schemas.toString());
            assertFalse(schemas.getObjectsList().stream().anyMatch(o->o.getName().equals("first_only")));
            assertTrue(schemas.getObjectsList().stream().allMatch(o->o.getCatalog().equals("second_database")));
            assertEquals("second_only",schemas.getObjectsList().stream().filter(o->o.getPropertiesOrDefault("defaultNamespace","").equals("true")).findFirst().orElseThrow().getName());
            assertEquals("second_only",schemas.getDefaultNamespace());
            var exactSchema=explorer.explore(source,ExploreRequest.newBuilder().setKind(ObjectKind.SCHEMA).setCatalog("second_database").setSearch("second_only").setExactName(true).setLimit(1).build());
            assertEquals(1,exactSchema.getTotalCount());assertEquals("second_only",exactSchema.getObjects(0).getName());assertEquals("second_only",exactSchema.getDefaultNamespace());
            var columns=explorer.explore(source,ExploreRequest.newBuilder().setKind(ObjectKind.COLUMN).setCatalog("second_database").setSchema("public").setTable("customers").build());
            assertEquals(List.of("second_database"),columns.getObjectsList().stream().map(SchemaObject::getName).toList());
            var ddl=new io.busystack.busydata.schema.SchemaTools(fixture.metadata.metadataPlatform()).run(source,SchemaToolRequest.newBuilder().setAction(SchemaToolAction.OBJECT_DEFINITION).setCatalog("second_database").setSchema("public").setTable("customers").setKind(ObjectKind.TABLE).build());
            assertTrue(ddl.getDefinition().contains("CREATE TABLE"));assertTrue(ddl.getDefinition().contains("second_database"));assertFalse(ddl.getDefinition().contains("first_database"));assertEquals("second_database",ddl.getInspectedObject().getCatalog());
            var tools=new io.busystack.busydata.schema.SchemaTools(fixture.metadata.metadataPlatform());
            var capture=SchemaToolRequest.newBuilder().setAction(SchemaToolAction.CAPTURE_SCHEMA).setSchema("public").setTable("customers").setKind(ObjectKind.TABLE);
            var firstSnapshot=tools.run(source,capture.setCatalog("busydata").build());
            var secondSnapshot=tools.run(source,capture.setCatalog("second_database").build());
            assertEquals("busydata",firstSnapshot.getInspectedObject().getCatalog());
            assertEquals("second_database",secondSnapshot.getInspectedObject().getCatalog());
            var comparison=tools.run(source,SchemaToolRequest.newBuilder().setAction(SchemaToolAction.COMPARE_SCHEMA).setSchema("public")
                .setSourceSnapshot(firstSnapshot.getSnapshot()).setTargetSnapshot(secondSnapshot.getSnapshot()).build());
            assertFalse(comparison.getEquivalent());assertTrue(comparison.getDifferencesList().stream().anyMatch(d->d.getName().equals("customers")));
            assertThrows(IllegalArgumentException.class,()->tools.run(source,capture.setTable("missing_table").build()));
            assertEquals("busydata",source.connection.getCatalog());
            assertEquals("busydata",source.context.catalog());
            for(int attempt=0;attempt<4;attempt++)assertThrows(Exception.class,()->explorer.explore(source,ExploreRequest.newBuilder().setKind(ObjectKind.SCHEMA).setCatalog("missing_database").build()));
            assertEquals("second_database",source.metadata("second_database",view->{assertTrue(view.profile.getReadOnly());assertTrue(view.connection.isReadOnly());return view.connection.getCatalog();}));
            assertEquals(TransactionState.IDLE,source.state);
            fixture.execute(source,"SELECT 17");
            fixture.execute(source,"CREATE DATABASE restricted_database; REVOKE CONNECT ON DATABASE restricted_database FROM PUBLIC; CREATE ROLE limited_metadata LOGIN PASSWORD 'fixture'");
            var limited=fixture.sessions.open(OpenRequest.newBuilder().setProfile(fixture.profile.toBuilder().setUser("limited_metadata")).setPassword("fixture").build());
            var discovery=explorer.explore(limited,ExploreRequest.newBuilder().setKind(ObjectKind.CATALOG).build());
            assertTrue(discovery.getObjectsList().stream().anyMatch(o->o.getName().equals("restricted_database")&&o.getCatalog().equals("restricted_database")));
            var denied=assertThrows(java.sql.SQLException.class,()->explorer.explore(limited,ExploreRequest.newBuilder().setKind(ObjectKind.SCHEMA).setCatalog("restricted_database").build()));
            assertEquals("42501",denied.getSQLState());assertEquals(TransactionState.IDLE,limited.state);assertEquals("busydata",limited.connection.getCatalog());
        }
    }

    @ParameterizedTest @ValueSource(strings={"MYSQL","MARIADB"})
    void mysqlFamilyScopesAndSearchAgreeAcrossIdenticallyNamedTables(String engine)throws Exception {
        try(var fixture=new EngineFixture(root,engine)) {
            var first=fixture.open();fixture.execute(first,"CREATE TABLE customers(marker integer); INSERT INTO customers VALUES(11); CREATE DATABASE second_database");
            var second=fixture.sessions.open(OpenRequest.newBuilder().setProfile(fixture.profile).setCatalog("second_database").setPassword("fixture").build());
            fixture.execute(second,"CREATE TABLE customers(marker varchar(20)); INSERT INTO customers VALUES('29'); CREATE TABLE Customers(other_column integer)");
            var explorer=new Explorer(fixture.metadata);
            for(boolean catalog:List.of(true,false)) {
                var scope=ExploreRequest.newBuilder().setKind(ObjectKind.COLUMN).setTable("customers");
                if(catalog)scope.setCatalog("second_database");else scope.setSchema("second_database");
                var columns=explorer.explore(first,scope.build());
                assertEquals("second_database",columns.getCatalog());assertEquals(1,columns.getObjectsCount());
                assertEquals("second_database",columns.getObjects(0).getCatalog());assertEquals("second_database",columns.getObjects(0).getSchema());
                assertEquals(Integer.toString(java.sql.Types.VARCHAR),columns.getObjects(0).getPropertiesOrThrow("jdbcType"));
            }
            var found=explorer.explore(first,ExploreRequest.newBuilder().setGlobalSearch(true).setCatalog("second_database").setSearch("customers").build());
            assertEquals(2,found.getObjectsCount());assertTrue(found.getObjectsList().stream().allMatch(o->o.getCatalog().equals("second_database")));assertEquals(1,found.getObjectsList().stream().filter(o->o.getName().equals("customers")).count());
            var ddl=new io.busystack.busydata.schema.SchemaTools(fixture.metadata.metadataPlatform()).run(first,SchemaToolRequest.newBuilder().setAction(SchemaToolAction.OBJECT_DEFINITION).setCatalog("second_database").setSchema("second_database").setTable("customers").setKind(ObjectKind.TABLE).build());
            assertTrue(ddl.getDefinition().toUpperCase(Locale.ROOT).contains("CREATE TABLE"));assertTrue(ddl.getDefinition().contains("marker"));assertFalse(ddl.getDefinition().contains("other_column"));assertTrue(ddl.getComplete());
            EditingIT.assertRows(first,"SELECT marker FROM customers",new int[][]{{11}});
            EditingIT.assertRows(second,"SELECT marker FROM customers",new int[][]{{29}});
            assertEquals("busydata",first.connection.getCatalog());assertEquals("busydata",first.profile.getDatabase());
        }
    }

    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void ordinaryTreePagesReachBeyondTheFrontendBudgetWithoutDuplicateIdentities(String engine)throws Exception {
        try(var fixture=new EngineFixture(root,engine)) {
            var session=fixture.open();fixture.introspectionLevel(session,io.busystack.busydata.metadata.IntrospectionLevel.NAMES);var ddl=new StringBuilder();
            for(int i=0;i<2305;i++) {
                ddl.append("CREATE TABLE page_").append(String.format(Locale.ROOT,"%04d",i)).append("(id integer);");
                if(i%50==49||i==2304){fixture.execute(session,ddl.toString());ddl.setLength(0);}
            }
            var explorer=new Explorer(fixture.metadata);
            var request=ExploreRequest.newBuilder().setKind(ObjectKind.TABLE).setCatalog("busydata").setSchema(fixture.schema()).setSearch("page_").setLimit(128).build();
            var names=new LinkedHashSet<String>();String continuation="";
            do {
                var page=explorer.explore(session,request.toBuilder().setContinuation(continuation).build());
                assertTrue(page.getObjectsCount()<=128,"The ordinary tree must honor the requested limit");
                assertEquals(MetadataCount.AUTHORITATIVE_TOTAL,page.getCountAvailability());
                assertTrue(page.hasTotalCount());assertEquals(2305,page.getTotalCount());
                assertEquals(session.profile.getId(),page.getProfileId());assertEquals(session.id,page.getSessionId());
                assertEquals("busydata",page.getCatalog());assertEquals(fixture.schema(),page.getSchema());
                assertTrue(page.getObjectsList().stream().allMatch(o->o.getSubtype()==ObjectSubtype.ORDINARY_TABLE));
                assertTrue(page.getObjectsCount()>0,"Every nonterminal continuation must make progress");
                for(var object:page.getObjectsList())assertTrue(names.add(object.getName()),"Duplicate page identity: "+object.getName());
                assertEquals(page.getComplete(),page.getContinuation().isEmpty());
                continuation=page.getContinuation();
                assertTrue(names.size()<=2305);
            }while(!continuation.isEmpty());
            assertEquals(2305,names.size());assertEquals("page_2304",names.stream().reduce((a,b)->b).orElseThrow());
            var exact=explorer.explore(session,request.toBuilder().setSearch("page_2304").setExactName(true).setLimit(1).build());
            assertEquals(1,exact.getTotalCount());assertTrue(exact.getComplete());assertEquals("page_2304",exact.getObjects(0).getName());
            var definition=new io.busystack.busydata.schema.SchemaTools(fixture.metadata.metadataPlatform()).run(session,SchemaToolRequest.newBuilder().setAction(SchemaToolAction.OBJECT_DEFINITION).setCatalog("busydata").setSchema(fixture.schema()).setTable("page_2304").setKind(ObjectKind.TABLE).build());
            assertTrue(definition.getDefinition().toUpperCase(Locale.ROOT).contains("CREATE TABLE"));assertTrue(definition.getSnapshot().isEmpty(),"A definition request must not capture the 2,305-table schema");
            var first=explorer.explore(session,request);
            assertThrows(IllegalArgumentException.class,()->explorer.explore(session,request.toBuilder().setSchema("another_scope").setContinuation(first.getContinuation()).build()));
            assertThrows(IllegalArgumentException.class,()->explorer.explore(session,request.toBuilder().setContinuation("A"+first.getContinuation()).build()));
            var external=fixture.open();try(var statement=external.connection.createStatement()){statement.execute("CREATE TABLE page_2305(id integer)");}
            var retainedPage=explorer.explore(session,request.toBuilder().setContinuation(first.getContinuation()).build());
            assertEquals(first.getMetadataSnapshotRevision(),retainedPage.getMetadataSnapshotRevision(),"A continuation reads its immutable published snapshot until refresh");
            assertEquals(2305,retainedPage.getTotalCount(),"External DDL cannot splice a different catalog into an existing snapshot");
            explorer.explore(session,request.toBuilder().setRefresh(true).build());
            assertThrows(IllegalArgumentException.class,()->explorer.explore(session,request.toBuilder().setContinuation(first.getContinuation()).build()));
            var added=explorer.explore(session,request.toBuilder().setSearch("page_2305").setExactName(true).build());assertEquals("page_2305",added.getObjects(0).getName());
        }
    }

    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MARIADB"})
    void sequencesAreRealObjectsAndNeverOrdinaryTables(String engine)throws Exception {
        try(var fixture=new EngineFixture(root,engine)) {
            var session=fixture.open();fixture.execute(session,"CREATE SEQUENCE sequence_fixture START WITH 41 INCREMENT BY 3");
            var explorer=new Explorer(fixture.metadata);
            var request=ExploreRequest.newBuilder().setCatalog("busydata").setSchema(fixture.schema());
            var sequences=explorer.explore(session,request.setKind(ObjectKind.SEQUENCE).build());
            assertEquals(List.of("sequence_fixture"),sequences.getObjectsList().stream().map(SchemaObject::getName).toList());
            assertEquals(ObjectSubtype.NATIVE_SEQUENCE,sequences.getObjects(0).getSubtype());
            assertEquals(1,sequences.getTotalCount());
            assertEquals("41",sequences.getObjects(0).getPropertiesOrThrow("startValue"));assertEquals("3",sequences.getObjects(0).getPropertiesOrThrow("increment"));assertEquals("AVAILABLE",sequences.getObjects(0).getPropertiesOrThrow("structureAvailability"));
            var found=explorer.explore(session,request.build().toBuilder().setGlobalSearch(true).setSearch("sequence_fixture").build());
            assertTrue(found.getObjectsList().stream().anyMatch(o->o.getName().equals("sequence_fixture")&&o.getKind()==ObjectKind.SEQUENCE&&o.getSubtype()==ObjectSubtype.NATIVE_SEQUENCE));
            assertFalse(found.getObjectsList().stream().anyMatch(o->o.getName().equals("sequence_fixture")&&o.getKind()==ObjectKind.TABLE));
            var definition=new io.busystack.busydata.schema.SchemaTools(fixture.metadata.metadataPlatform()).run(session,SchemaToolRequest.newBuilder().setAction(SchemaToolAction.OBJECT_DEFINITION).setCatalog("busydata").setSchema(fixture.schema()).setTable("sequence_fixture").setKind(ObjectKind.SEQUENCE).build());
            assertTrue(definition.getDefinition().toUpperCase(Locale.ROOT).contains("CREATE SEQUENCE"));
            if(fixture.engine==Engine.POSTGRESQL){assertFalse(definition.getInspectedObject().containsProperties("lastValue"));assertEquals("unavailable",definition.getInspectedObject().getPropertiesOrThrow("lastValueAvailability"));}
            var tables=explorer.explore(session,request.setKind(ObjectKind.TABLE).build());
            assertTrue(tables.getObjectsList().stream().noneMatch(o->o.getName().equals("sequence_fixture")));
            // Inspection must leave the first value available for the user's call.
            try(var statement=session.connection.createStatement();var values=statement.executeQuery(fixture.engine==Engine.POSTGRESQL?"SELECT nextval('sequence_fixture')":"SELECT NEXT VALUE FOR sequence_fixture")) {
                assertTrue(values.next());assertEquals(41,values.getLong(1));
            }
        }
    }

    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void compoundChildrenAreCountedAsObjectsAndColumnTypesRemainExact(String engine)throws Exception {
        try(var fixture=new EngineFixture(root,engine)) {
            var session=fixture.open();fixture.execute(session,"CREATE TABLE composite_parent(a integer,b integer,PRIMARY KEY(a,b)); CREATE TABLE composite_child(a integer,b integer,CONSTRAINT composite_fk FOREIGN KEY(a,b) REFERENCES composite_parent(a,b)); CREATE INDEX composite_index ON composite_child(a,b)");
            var explorer=new Explorer(fixture.metadata);var scope=ExploreRequest.newBuilder().setCatalog("busydata").setSchema(fixture.schema()).setTable("composite_child").setLimit(1);
            var keys=explorer.explore(session,scope.setKind(ObjectKind.FOREIGN_KEY).build());
            assertEquals(1,keys.getTotalCount());assertTrue(keys.getComplete());assertEquals(1,keys.getObjectsCount());assertEquals("2",keys.getObjects(0).getPropertiesOrThrow("columnCount"));
            String ordered=fixture.engine==Engine.POSTGRESQL?"a, b":"`a`, `b`";
            assertEquals(ordered,keys.getObjects(0).getPropertiesOrThrow("column"));assertEquals(ordered,keys.getObjects(0).getPropertiesOrThrow("referencedColumn"));
            var indexes=explorer.explore(session,scope.setKind(ObjectKind.INDEX).setSearch("composite_index").build());
            assertEquals(1,indexes.getTotalCount());assertTrue(indexes.getComplete());assertEquals("composite_index",indexes.getObjects(0).getName());
            assertEquals(ordered,indexes.getObjects(0).getPropertiesOrThrow("column"));
            var columns=explorer.explore(session,scope.clearSearch().setKind(ObjectKind.COLUMN).build());
            assertEquals(2,columns.getTotalCount());assertFalse(columns.getComplete());assertEquals(Integer.toString(java.sql.Types.INTEGER),columns.getObjects(0).getPropertiesOrThrow("jdbcType"));
            var tools=new io.busystack.busydata.schema.SchemaTools(fixture.metadata.metadataPlatform());
            var snapshot=tools.run(session,SchemaToolRequest.newBuilder().setAction(SchemaToolAction.CAPTURE_SCHEMA).setCatalog("busydata").setSchema(fixture.schema()).setTable("composite_child").setKind(ObjectKind.TABLE).build());
            var capturedTables=com.google.gson.JsonParser.parseString(snapshot.getSnapshot()).getAsJsonObject().getAsJsonObject("tables");
            assertEquals(Set.of("composite_child"),capturedTables.keySet());assertEquals(ObjectSubtype.ORDINARY_TABLE,snapshot.getInspectedObject().getSubtype());
            assertTrue(tools.run(session,SchemaToolRequest.newBuilder().setAction(SchemaToolAction.COMPARE_SCHEMA).setSourceSnapshot(snapshot.getSnapshot()).setTargetSnapshot(snapshot.getSnapshot()).build()).getEquivalent());
            var childDefinition=new io.busystack.busydata.schema.SchemaTools(fixture.metadata.metadataPlatform()).run(session,SchemaToolRequest.newBuilder().setAction(SchemaToolAction.OBJECT_DEFINITION).setCatalog("busydata").setSchema(fixture.schema()).setTable("composite_child").setObjectName("a").setKind(ObjectKind.COLUMN).build());
            assertEquals("a",childDefinition.getInspectedObject().getName());assertEquals("composite_child",childDefinition.getInspectedObject().getTable());assertFalse(childDefinition.getDefinition().isEmpty());assertTrue(childDefinition.getSnapshot().isEmpty());
            if(fixture.engine==Engine.MYSQL)assertThrows(IllegalArgumentException.class,()->explorer.explore(session,scope.setTable("").setKind(ObjectKind.SEQUENCE).build()));
            if(fixture.engine==Engine.POSTGRESQL) {
                fixture.execute(session,"CREATE TABLE partition_fixture(id integer) PARTITION BY RANGE(id); CREATE VIEW view_fixture AS SELECT a FROM composite_child; CREATE MATERIALIZED VIEW materialized_fixture AS SELECT b FROM composite_child; CREATE EXTENSION postgres_fdw; CREATE SERVER unused_foreign_server FOREIGN DATA WRAPPER postgres_fdw; CREATE FOREIGN TABLE foreign_fixture(id integer) SERVER unused_foreign_server");
                var nativeScope=scope.clearTable().setLimit(128);
                var tables=explorer.explore(session,nativeScope.setKind(ObjectKind.TABLE).build());
                assertEquals(ObjectSubtype.PARTITIONED_TABLE,tables.getObjectsList().stream().filter(o->o.getName().equals("partition_fixture")).findFirst().orElseThrow().getSubtype());
                assertEquals(ObjectSubtype.FOREIGN_TABLE,tables.getObjectsList().stream().filter(o->o.getName().equals("foreign_fixture")).findFirst().orElseThrow().getSubtype());
                var views=explorer.explore(session,nativeScope.setKind(ObjectKind.VIEW).build());
                assertEquals(Set.of(ObjectSubtype.REGULAR_VIEW,ObjectSubtype.MATERIALIZED_VIEW),views.getObjectsList().stream().map(SchemaObject::getSubtype).collect(java.util.stream.Collectors.toSet()));
                var definition=new io.busystack.busydata.schema.SchemaTools(fixture.metadata.metadataPlatform()).run(session,SchemaToolRequest.newBuilder().setAction(SchemaToolAction.OBJECT_DEFINITION).setCatalog("busydata").setSchema("public").setTable("materialized_fixture").setKind(ObjectKind.VIEW).build());
                assertTrue(definition.getDefinition().contains("CREATE MATERIALIZED VIEW"));assertEquals(ObjectSubtype.MATERIALIZED_VIEW,definition.getInspectedObject().getSubtype());assertFalse(definition.getComplete());
                fixture.execute(session,"CREATE FUNCTION trigger_parent_fn() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RETURN NEW; END $$; CREATE TRIGGER repeated_trigger BEFORE INSERT ON composite_parent FOR EACH ROW EXECUTE FUNCTION trigger_parent_fn(); CREATE TRIGGER repeated_trigger BEFORE INSERT ON composite_child FOR EACH ROW EXECUTE FUNCTION trigger_parent_fn()");
                var triggers=nativeScope.setKind(ObjectKind.TRIGGER).setLimit(1).build();
                var first=explorer.explore(session,triggers);var next=explorer.explore(session,triggers.toBuilder().setContinuation(first.getContinuation()).build());
                assertEquals(2,first.getTotalCount());assertEquals(1,first.getObjectsCount());assertEquals(1,next.getObjectsCount());assertTrue(next.getComplete());
                assertEquals(Set.of("composite_child","composite_parent"),Set.of(first.getObjects(0).getTable(),next.getObjects(0).getTable()));
            }
        }
    }
}
