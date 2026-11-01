package io.busystack.busydata;

import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.Explorer;
import java.nio.file.Path;
import java.util.*;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

/** The pinned MariaDB owned inventory is distinct from its durable catalog. */
class MariaTemporaryInventoryIT {
    @TempDir Path root;

    @ParameterizedTest @ValueSource(ints={1,2,3})
    void opaqueCreationRespectsRequestedLevelsPolicyAndPhysicalOwnership(int requested)throws Exception {
        try(var fixture=new EngineFixture(root,"MARIADB")){
            var owner=fixture.open();var other=fixture.open();var explorer=new Explorer(fixture.metadata);var platform=explorer.metadata();
            // Trusted fixture setup creates namespaces and the stored routine;
            // its session-local effects are exercised through normal Jobs CALL.
            other.lock.lock();
            try(var command=other.connection.createStatement()){
                command.execute("CREATE DATABASE inventory_aux");command.execute("CREATE DATABASE inventory_excluded");
                command.execute("CREATE TABLE busydata.inventory_rows(persistent_a INTEGER)");
                command.execute("CREATE PROCEDURE busydata.make_inventory() SQL SECURITY DEFINER BEGIN CREATE TEMPORARY TABLE busydata.inventory_rows(temporary_b INTEGER DEFAULT 7); CREATE TEMPORARY TABLE inventory_aux.inventory_aux_rows(auxiliary_b INTEGER); CREATE TEMPORARY TABLE inventory_excluded.inventory_hidden(hidden_b INTEGER); CREATE TEMPORARY TABLE busydata.inventory_skip(skipped_b INTEGER); END");
                command.execute("CREATE PROCEDURE busydata.remove_inventory() SQL SECURITY DEFINER BEGIN DROP TEMPORARY TABLE busydata.inventory_rows; DROP TEMPORARY TABLE inventory_aux.inventory_aux_rows; DROP TEMPORARY TABLE inventory_excluded.inventory_hidden; DROP TEMPORARY TABLE busydata.inventory_skip; END");
            }finally{other.lock.unlock();}
            var level=IntrospectionLevel.of(requested);var beforeConfig=platform.configuration(owner);
            platform.configure(owner,new MetadataConfiguration(beforeConfig.revision()+1,Set.of("busydata","inventory_aux","inventory_excluded"),Set.of("inventory_excluded"),Set.of(),Set.of(),false,Set.of(ObjectKind.TABLE,ObjectKind.COLUMN),List.of("inventory_*"),List.of("inventory_skip"),level,Map.of(MetadataConfiguration.scopeKey("inventory_aux","inventory_aux"),IntrospectionLevel.NAMES)));
            fixture.warm(owner,"inventory_rows");var permanent=platform.capture(owner).resolve("busydata","busydata",ObjectKind.TABLE,"","inventory_rows",true).getFirst();
            assertTrue(permanent.identity().sessionOwner().isEmpty());

            fixture.execute(owner,"CALL busydata.make_inventory()");
            var captured=platform.capture(owner);var temporary=captured.resolve("busydata","busydata",ObjectKind.TABLE,"","inventory_rows",true).getFirst();
            assertEquals(owner.id,temporary.identity().sessionOwner());assertEquals("true",temporary.properties().get("temporary"));assertEquals(level,temporary.level());assertNotEquals(permanent.identity().key(),temporary.identity().key());
            assertEquals(1,captured.resolve("busydata","busydata",ObjectKind.TABLE,"","inventory_rows",true).size(),"The same-name persistent row is shadowed only in its owner");
            var columns=new MetadataScope("busydata","busydata","inventory_rows",ObjectKind.COLUMN);
            if(requested==1){
                assertFalse(captured.complete(columns,IntrospectionLevel.STRUCTURE));assertTrue(captured.namespace("busydata","busydata",ObjectKind.COLUMN,"inventory_rows").isEmpty(),"Level1 cannot adopt persistent or fabricated temporary columns");
            }else{
                assertTrue(captured.complete(columns,IntrospectionLevel.STRUCTURE));var actual=captured.namespace("busydata","busydata",ObjectKind.COLUMN,"inventory_rows");assertEquals(List.of("temporary_b"),actual.stream().map(object->object.identity().name()).toList());assertTrue(actual.stream().allMatch(object->object.identity().sessionOwner().equals(owner.id)));
            }
            if(requested==3){
                assertEquals("AVAILABLE",temporary.properties().get("sourceAvailability"));assertTrue(temporary.source().startsWith("CREATE TEMPORARY TABLE"));assertTrue(temporary.source().contains("temporary_b"));assertFalse(temporary.source().contains("persistent_a"));
            }else{assertTrue(temporary.source().isEmpty());}
            if(requested==1){
                var elevated=explorer.explore(owner,ExploreRequest.newBuilder().setCatalog("busydata").setSchema("busydata").setTable("inventory_rows").setKind(ObjectKind.COLUMN).setIntrospectionLevel(2).setIndependentMetadata(true).build());
                assertTrue(elevated.getComplete(),"An explicit structural request acquires native owned details rather than fabricating an empty complete branch");assertEquals(List.of("temporary_b"),elevated.getObjectsList().stream().map(SchemaObject::getName).toList());assertEquals(2,elevated.getIntrospectionLevel());
                assertTrue(captured.namespace("busydata","busydata",ObjectKind.COLUMN,"inventory_rows").isEmpty(),"The prior names snapshot remains immutable after explicit elevation");
            }
            var auxiliary=captured.resolve("inventory_aux","inventory_aux",ObjectKind.TABLE,"","inventory_aux_rows",true).getFirst();assertEquals(owner.id,auxiliary.identity().sessionOwner());assertEquals(IntrospectionLevel.NAMES,auxiliary.level());assertFalse(captured.complete(new MetadataScope("inventory_aux","inventory_aux","inventory_aux_rows",ObjectKind.COLUMN),IntrospectionLevel.STRUCTURE));
            assertTrue(captured.resolve("inventory_excluded","inventory_excluded",ObjectKind.TABLE,"","inventory_hidden",true).isEmpty());assertTrue(captured.resolve("busydata","busydata",ObjectKind.TABLE,"","inventory_skip",true).isEmpty());
            assertTrue(platform.capture(other).identities().values().stream().noneMatch(object->!object.identity().sessionOwner().isEmpty()),"Another physical session never receives owned temporary metadata");
            assertEquals(permanent.identity().key(),platform.capture(other).resolve("busydata","busydata",ObjectKind.TABLE,"","inventory_rows",true).getFirst().identity().key());
            assertTrue(platform.publishedSnapshot(owner).identities().values().stream().noneMatch(object->!object.identity().sessionOwner().isEmpty()));
            assertTrue(new MetadataRepository(root).loadNewest().stream().flatMap(snapshot->snapshot.identities().values().stream()).noneMatch(object->!object.identity().sessionOwner().isEmpty()||"true".equals(object.properties().get("temporary"))),"The rebuildable durable cache never persists session temporary objects");

            fixture.execute(owner,"CALL busydata.remove_inventory()");
            var removed=platform.capture(owner);var restored=removed.resolve("busydata","busydata",ObjectKind.TABLE,"","inventory_rows",true).getFirst();
            assertEquals(permanent.identity().key(),restored.identity().key(),()->"Permanent identity="+permanent.identity()+"; captured temporary identity="+temporary.identity()+"; restored identity="+restored.identity()+"; restored temporary="+restored.properties().get("temporary")+"; resolution="+removed.sessionResolution().state());assertTrue(restored.identity().sessionOwner().isEmpty());assertFalse("true".equals(restored.properties().get("temporary")));assertTrue(removed.identities().values().stream().noneMatch(object->object.identity().sessionOwner().equals(owner.id)));
            assertSame(temporary,captured.resolve("busydata","busydata",ObjectKind.TABLE,"","inventory_rows",true).getFirst(),"Published old snapshots keep their exact owned identity after inventory replacement");assertEquals(owner.id,temporary.identity().sessionOwner());assertEquals(level,temporary.level());
            if(requested>1)assertEquals(List.of("temporary_b"),captured.namespace("busydata","busydata",ObjectKind.COLUMN,"inventory_rows").stream().map(object->object.identity().name()).toList());
            assertEquals(Engine.MARIADB,owner.profile.getEngine());assertTrue(owner.connection.getMetaData().getDatabaseProductVersion().startsWith("11.8.9"));
        }
    }
}
