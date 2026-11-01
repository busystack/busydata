package io.busystack.busydata;

import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.Explorer;
import io.busystack.busydata.schema.SchemaTools;
import io.busystack.busydata.schema.SchemaConstraints;
import java.nio.file.Path;
import java.util.*;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

/** MySQL documents a separate namespace for each constraint type. The three
 * native catalog oracles are independent of central-model identity rules. */
class StructuralConstraintNamespacesIT {
    @TempDir Path root;
    private static final String CHILD="namespace_child", SHARED="shared_name";
    private static final Set<String> TYPES=Set.of("CHECK","FOREIGN KEY","UNIQUE");
    private static void components(List<SchemaObject> objects,String check){
        var typed=new HashMap<String,SchemaObject>();
        for(var object:objects){assertEquals(SHARED,object.getName());assertNull(typed.put(object.getPropertiesOrThrow("type"),object),"No actual constraint type may overwrite another");}
        assertEquals(TYPES,typed.keySet());
        var foreign=typed.get("FOREIGN KEY");assertEquals("1",foreign.getPropertiesOrThrow("columnCount"));assertEquals("parent_id",foreign.getPropertiesOrThrow("column.0"));assertFalse(foreign.containsProperties("expression"));
        var unique=typed.get("UNIQUE");assertEquals("1",unique.getPropertiesOrThrow("columnCount"));assertEquals("unique_value",unique.getPropertiesOrThrow("column.0"));assertFalse(unique.containsProperties("expression"));
        var checked=typed.get("CHECK");assertEquals(check,checked.getPropertiesOrThrow("expression"));assertEquals("0",checked.getPropertiesOrDefault("columnCount","0"));assertFalse(checked.containsProperties("column.0"));
    }
    @Test void sameNamedForeignUniqueAndCheckKeepNativeComponentsAndCentralIdentities()throws Exception {
        try(var fixture=new EngineFixture(root,"MYSQL")){
            var owner=fixture.open();var platform=fixture.metadata.metadataPlatform();var explorer=new Explorer(platform);
            String parent=owner.adapter.table("busydata","busydata","namespace_parent"),child=owner.adapter.table("busydata","busydata",CHILD),shared=owner.adapter.quote(SHARED);
            var request=ExploreRequest.newBuilder().setCatalog("busydata").setSchema("busydata").setTable(CHILD).setKind(ObjectKind.CONSTRAINT).setSearch(SHARED).setExactName(true).setLimit(500).build();
            String nativeCheck,structuralFingerprint;Explorer.BranchScan nativeScan;
            owner.lock.lock();try{
                // The FK's explicit supporting index avoids implicit index-name
                // allocation; UNIQUE, FOREIGN KEY and CHECK deliberately share
                // their actual native constraint name on different columns.
                try(var statement=owner.connection.createStatement()){
                    statement.setQueryTimeout(10);statement.execute("CREATE TABLE "+parent+" (id INTEGER PRIMARY KEY)");
                    statement.execute("CREATE TABLE "+child+" (id INTEGER PRIMARY KEY,unique_value INTEGER NOT NULL,parent_id INTEGER,check_value INTEGER,UNIQUE KEY "+shared+" (unique_value),KEY fk_support (parent_id),CONSTRAINT "+shared+" FOREIGN KEY (parent_id) REFERENCES "+parent+" (id),CONSTRAINT "+shared+" CHECK (check_value > 0))");
                }
                owner.refresh();owner.advanceRevision();
                try(var statement=owner.connection.prepareStatement("SELECT CONSTRAINT_TYPE FROM information_schema.TABLE_CONSTRAINTS WHERE BINARY TABLE_SCHEMA=BINARY ? AND BINARY TABLE_NAME=BINARY ? AND BINARY CONSTRAINT_NAME=BINARY ?")){
                    statement.setQueryTimeout(5);statement.setString(1,"busydata");statement.setString(2,CHILD);statement.setString(3,SHARED);
                    try(var rows=statement.executeQuery()){var types=new HashSet<String>();int count=0;while(rows.next()){count++;assertTrue(types.add(rows.getString(1)));}assertEquals(3,count);assertEquals(TYPES,types);}
                }
                try(var statement=owner.connection.prepareStatement("SELECT COLUMN_NAME,REFERENCED_TABLE_NAME FROM information_schema.KEY_COLUMN_USAGE WHERE BINARY TABLE_SCHEMA=BINARY ? AND BINARY TABLE_NAME=BINARY ? AND BINARY CONSTRAINT_NAME=BINARY ?")){
                    statement.setQueryTimeout(5);statement.setString(1,"busydata");statement.setString(2,CHILD);statement.setString(3,SHARED);
                    try(var rows=statement.executeQuery()){var columns=new HashMap<Boolean,String>();int count=0;while(rows.next()){count++;String referenced=rows.getString(2);assertNull(columns.put(referenced!=null,rows.getString(1)));if(referenced!=null)assertEquals("namespace_parent",referenced);}assertEquals(2,count);assertEquals(Map.of(false,"unique_value",true,"parent_id"),columns);}
                }
                try(var statement=owner.connection.prepareStatement("SELECT CHECK_CLAUSE FROM information_schema.CHECK_CONSTRAINTS WHERE BINARY CONSTRAINT_SCHEMA=BINARY ? AND BINARY CONSTRAINT_NAME=BINARY ?")){
                    statement.setQueryTimeout(5);statement.setString(1,"busydata");statement.setString(2,SHARED);
                    try(var rows=statement.executeQuery()){assertTrue(rows.next());nativeCheck=rows.getString(1);assertNotNull(nativeCheck);assertFalse(rows.next());}
                }
                var structural=request.toBuilder().setIntrospectionLevel(2).build();
                components(explorer.fetchBranch(owner,structural,System.nanoTime()+TimeUnit.SECONDS.toNanos(10)),nativeCheck);
                nativeScan=explorer.scanBranch(owner,structural);assertEquals(3,nativeScan.count());
                structuralFingerprint=StructuralDetails.constraintFingerprint(owner,"busydata",CHILD);assertEquals(structuralFingerprint,StructuralDetails.constraintFingerprint(owner,"busydata",CHILD));
                var foreign=request.toBuilder().setKind(ObjectKind.FOREIGN_KEY).setIntrospectionLevel(2).build();assertEquals(1,explorer.scanBranch(owner,foreign).count());
                var keys=explorer.fetchBranch(owner,foreign,System.nanoTime()+TimeUnit.SECONDS.toNanos(10));assertEquals(1,keys.size());assertEquals("parent_id",keys.getFirst().getPropertiesOrThrow("column.0"));
            }finally{owner.lock.unlock();}
            fixture.introspectionLevel(owner,IntrospectionLevel.STRUCTURE);
            var names=explorer.explore(owner,request.toBuilder().setIntrospectionLevel(1).build());assertTrue(names.getComplete());assertEquals(3,names.getObjectsCount());
            var identities=new HashSet<String>();var types=new HashSet<String>();for(var object:names.getObjectsList()){assertFalse(object.getStableIdentity().isEmpty());assertTrue(identities.add(object.getStableIdentity()));types.add(object.getPropertiesOrThrow("type"));}assertEquals(TYPES,types);
            var structural=explorer.explore(owner,request.toBuilder().setIntrospectionLevel(2).build());assertTrue(structural.getComplete());components(structural.getObjectsList(),nativeCheck);
            assertEquals(identities,structural.getObjectsList().stream().map(SchemaObject::getStableIdentity).collect(java.util.stream.Collectors.toSet()));
            fixture.introspectionLevel(owner,IntrospectionLevel.SOURCE);
            var tools=new SchemaTools(platform);var artifact=tools.capture(owner,"busydata");assertEquals(2,artifact.get("version").getAsInt());
            var artifactTable=artifact.getAsJsonObject("tables").getAsJsonObject(CHILD);
            var definitions=new HashMap<String,String>();for(String type:TYPES){var record=SchemaConstraints.find(artifactTable,SHARED,type);assertNotNull(record);assertEquals(SHARED,record.get("name").getAsString());definitions.put(type,record.get("definition").getAsString());}
            assertTrue(definitions.get("UNIQUE").contains("`unique_value`"));assertTrue(definitions.get("FOREIGN KEY").contains("`parent_id`"));assertTrue(definitions.get("CHECK").contains("`check_value`"));
            var equivalent=tools.run(owner,SchemaToolRequest.newBuilder().setAction(SchemaToolAction.COMPARE_SCHEMA).setSourceSnapshot(artifact.toString()).setTargetSnapshot(artifact.toString()).build());assertTrue(equivalent.getComplete());assertTrue(equivalent.getEquivalent());assertEquals(0,equivalent.getSqlCount());
            var sources=explorer.explore(owner,request.toBuilder().setIntrospectionLevel(3).build());assertTrue(sources.getComplete());assertEquals(3,sources.getObjectsCount());
            for(var source:sources.getObjectsList()){String type=source.getPropertiesOrThrow("type");assertEquals(type,source.getIdentifier());assertEquals(definitions.get(type),source.getDefinition());assertEquals("AVAILABLE",source.getPropertiesOrThrow("sourceAvailability"));
                var exact=tools.run(owner,SchemaToolRequest.newBuilder().setAction(SchemaToolAction.OBJECT_DEFINITION).setCatalog("busydata").setSchema("busydata").setTable(CHILD).setObjectName(SHARED).setKind(ObjectKind.CONSTRAINT).setIdentifier(type).build());assertTrue(exact.getComplete());assertEquals(type,exact.getInspectedObject().getIdentifier());assertEquals(definitions.get(type),exact.getDefinition());}
            var ambiguous=tools.run(owner,SchemaToolRequest.newBuilder().setAction(SchemaToolAction.OBJECT_DEFINITION).setCatalog("busydata").setSchema("busydata").setTable(CHILD).setObjectName(SHARED).setKind(ObjectKind.CONSTRAINT).build());assertFalse(ambiguous.getComplete());assertFalse(ambiguous.getUnsupportedList().isEmpty());
            var desired=artifact.deepCopy();var changed=SchemaConstraints.find(desired.getAsJsonObject("tables").getAsJsonObject(CHILD),SHARED,"CHECK");changed.addProperty("definition","CONSTRAINT `shared_name` CHECK (`check_value` >= 0)");assertNotEquals(artifact,desired);
            var planned=tools.run(owner,SchemaToolRequest.newBuilder().setAction(SchemaToolAction.COMPARE_SCHEMA).setSourceSnapshot(artifact.toString()).setTargetSnapshot(desired.toString()).build());assertTrue(planned.getComplete(),planned.toString());String migration=String.join("\n",planned.getSqlList());assertTrue(migration.contains("DROP CHECK `shared_name`"));assertFalse(migration.contains("DROP INDEX `shared_name`"));assertFalse(migration.contains("ADD UNIQUE KEY `shared_name`"));
            owner.lock.lock();try{
                var inspected=platform.readTableStructure(owner,"busydata","busydata",CHILD);assertEquals(4,inspected.constraints().size());
                var primary=inspected.constraints().stream().filter(value->value.getName().equals("PRIMARY")).toList();assertEquals(1,primary.size());assertEquals("PRIMARY KEY",primary.getFirst().getPropertiesOrThrow("type"));
                components(inspected.constraints().stream().filter(value->value.getName().equals(SHARED)).toList(),nativeCheck);
                assertTrue(inspected.identities().contains(Set.of("id")));assertTrue(inspected.identities().contains(Set.of("unique_value")));
                var publishedPrimary=platform.capture(owner).resolve("busydata","busydata",ObjectKind.CONSTRAINT,CHILD,"PRIMARY",true);assertEquals(1,publishedPrimary.size());assertEquals("PRIMARY KEY",publishedPrimary.getFirst().properties().get("type"));
                assertEquals(nativeScan,explorer.scanBranch(owner,request.toBuilder().setIntrospectionLevel(2).build()));
                assertEquals(structuralFingerprint,StructuralDetails.constraintFingerprint(owner,"busydata",CHILD));
            }finally{owner.lock.unlock();}
        }
    }
    @Test void postgresStandaloneUniqueIndexKeepsRowIdentityWithoutBecomingANativeConstraint()throws Exception {
        try(var fixture=new EngineFixture(root,"POSTGRESQL")){
            var owner=fixture.open();var platform=fixture.metadata.metadataPlatform();String catalog=owner.context.catalog(),schema=fixture.schema(),table="native_constraint_kinds";
            fixture.introspectionLevel(owner,IntrospectionLevel.STRUCTURE);
            String parent=owner.adapter.table(catalog,schema,"constraint_parent"),child=owner.adapter.table(catalog,schema,table);
            var expectedTypes=new HashMap<String,String>();var nativeIds=new HashMap<String,String>();
            owner.lock.lock();try{
                try(var statement=owner.connection.createStatement()){
                    statement.setQueryTimeout(10);statement.execute("CREATE TABLE "+parent+" (id INTEGER PRIMARY KEY)");
                    statement.execute("CREATE TABLE "+child+" (id INTEGER,unique_value INTEGER NOT NULL,indexed_value INTEGER NOT NULL,parent_id INTEGER,check_value INTEGER,CONSTRAINT declared_primary PRIMARY KEY (id),CONSTRAINT declared_unique UNIQUE (unique_value),CONSTRAINT declared_foreign FOREIGN KEY (parent_id) REFERENCES "+parent+" (id),CONSTRAINT declared_check CHECK (check_value > 0))");
                    statement.execute("CREATE UNIQUE INDEX standalone_unique ON "+child+" (indexed_value)");
                }
                owner.refresh();owner.advanceRevision();
                try(var statement=owner.connection.prepareStatement("SELECT con.conname,con.contype::text,con.oid::text FROM pg_catalog.pg_constraint con JOIN pg_catalog.pg_class t ON t.oid=con.conrelid JOIN pg_catalog.pg_namespace n ON n.oid=t.relnamespace WHERE n.nspname=? AND t.relname=?")){
                    statement.setQueryTimeout(5);statement.setString(1,schema);statement.setString(2,table);
                    try(var rows=statement.executeQuery()){while(rows.next()){assertNull(expectedTypes.put(rows.getString(1),rows.getString(2)));assertNull(nativeIds.put(rows.getString(1),rows.getString(3)));}}
                }
                assertEquals(Map.of("declared_primary","p","declared_unique","u","declared_foreign","f","declared_check","c"),expectedTypes);
                try(var statement=owner.connection.prepareStatement("SELECT x.indisunique,EXISTS(SELECT 1 FROM pg_catalog.pg_constraint c WHERE c.conindid=x.indexrelid) FROM pg_catalog.pg_index x JOIN pg_catalog.pg_class i ON i.oid=x.indexrelid JOIN pg_catalog.pg_namespace n ON n.oid=i.relnamespace WHERE n.nspname=? AND i.relname=?")){
                    statement.setQueryTimeout(5);statement.setString(1,schema);statement.setString(2,"standalone_unique");try(var rows=statement.executeQuery()){assertTrue(rows.next());assertTrue(rows.getBoolean(1));assertFalse(rows.getBoolean(2));assertFalse(rows.next());}
                }
                var explorer=new Explorer(platform);var request=ExploreRequest.newBuilder().setCatalog(catalog).setSchema(schema).setTable(table).setKind(ObjectKind.CONSTRAINT).setLimit(500).build();
                var names=explorer.explore(owner,request.toBuilder().setIntrospectionLevel(1).build());assertTrue(names.getComplete());assertEquals(4,names.getObjectsCount());var stableNames=new HashMap<String,String>();
                for(var object:names.getObjectsList()){assertEquals(nativeIds.get(object.getName()),object.getPropertiesOrThrow("nativeId"));assertFalse(object.getStableIdentity().isEmpty());stableNames.put(object.getName(),object.getStableIdentity());}
                var actual=StructuralDetails.readConstraints(owner,catalog,schema,table);assertEquals(expectedTypes.size(),actual.size());
                for(var constraint:actual){assertEquals(expectedTypes.get(constraint.getName()),constraint.getPropertiesOrThrow("type"));assertEquals(nativeIds.get(constraint.getName()),constraint.getPropertiesOrThrow("nativeId"));assertEquals(ObjectKind.CONSTRAINT,constraint.getKind());assertEquals(catalog,constraint.getCatalog());assertEquals(schema,constraint.getSchema());assertEquals(table,constraint.getTable());}
                var structure=platform.readTableStructure(owner,catalog,schema,table);assertEquals(4,structure.constraints().size());
                for(var constraint:structure.constraints()){assertEquals(expectedTypes.get(constraint.getName()),constraint.getPropertiesOrThrow("type"));assertEquals(nativeIds.get(constraint.getName()),constraint.getPropertiesOrThrow("nativeId"));}
                assertTrue(structure.identities().contains(Set.of("id")));assertTrue(structure.identities().contains(Set.of("unique_value")));assertTrue(structure.identities().contains(Set.of("indexed_value")),"An independent unique index remains row-identity evidence");
                var snapshot=platform.capture(owner);assertTrue(snapshot.resolve(catalog,schema,ObjectKind.CONSTRAINT,table,"standalone_unique",true).isEmpty());
                var primary=snapshot.resolve(catalog,schema,ObjectKind.CONSTRAINT,table,"declared_primary",true);assertEquals(1,primary.size());assertEquals("p",primary.getFirst().properties().get("type"));assertEquals(nativeIds.get("declared_primary"),primary.getFirst().properties().get("nativeId"));
                var structural=explorer.explore(owner,request.toBuilder().setIntrospectionLevel(2).build());assertTrue(structural.getComplete());assertEquals(4,structural.getObjectsCount());for(var object:structural.getObjectsList()){assertEquals(stableNames.get(object.getName()),object.getStableIdentity());assertEquals(nativeIds.get(object.getName()),object.getPropertiesOrThrow("nativeId"));}
                var indexes=new Explorer(platform).fetchBranch(owner,ExploreRequest.newBuilder().setCatalog(catalog).setSchema(schema).setTable(table).setKind(ObjectKind.INDEX).setIntrospectionLevel(2).build(),System.nanoTime()+TimeUnit.SECONDS.toNanos(10));assertEquals(1,indexes.stream().filter(value->value.getName().equals("standalone_unique")).count());
            }finally{owner.lock.unlock();}
        }
    }
}
