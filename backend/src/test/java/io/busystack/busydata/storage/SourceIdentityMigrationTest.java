package io.busystack.busydata.storage;

import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import java.nio.file.*;
import java.sql.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

class SourceIdentityMigrationTest {
    @TempDir Path root;
    static Profile profile(){return Profile.newBuilder().setId("profile").setName("Keep my name").setEngine(Engine.POSTGRESQL).setHost("localhost").setPort(5432).setDatabase("data").setUser("reader").putOptions("tcpKeepAlive","true").putOptions("applicationName","BusyData").build();}
    static String previous(Profile profile){return MetadataIdentity.digest(Base64.getEncoder().encodeToString(profile.toBuilder().clearName().clearEnvironment().clearConnectTimeoutSeconds().clearQueryTimeoutSeconds().build().toByteArray()));}
    void legacy(int version)throws Exception {
        try(var store=new MetadataStore(root)){store.save(profile());store.metadataConfiguration(previous(profile()),MetadataConfiguration.defaults());}
        try(var db=DriverManager.getConnection("jdbc:sqlite:"+root.resolve("metadata.sqlite"));var statement=db.createStatement()) {
            statement.execute("DROP TABLE metadata_source_identity");statement.execute("DELETE FROM migration WHERE version>"+version);
        }
    }
    @Test void migrationPreservesSourceAndColumnPreferenceIdentityWithoutCatalogCache()throws Exception {
        legacy(3);String old=previous(profile());byte[] presentation="opaque column presentation and draft preferences".getBytes(java.nio.charset.StandardCharsets.UTF_8);
        Path flutter=root.resolve("flutter-presentation-fixture");Files.write(flutter,presentation);
        var column=new MetadataIdentity(old,profile().getId(),"data","public",ObjectKind.COLUMN,ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED,"parent","id","","");
        assertFalse(Files.exists(root.resolve("metadata_catalog.sqlite")));
        for(int restart=0;restart<2;restart++)try(var store=new MetadataStore(root)) {
            String actual=store.metadataSourceIdentity(profile());assertEquals(old,actual);assertNotEquals(SourceIdentity.fingerprint(profile()),actual);
            var reordered=profile().toBuilder().clearOptions().putOptions("applicationName","BusyData").putOptions("tcpKeepAlive","true").build();
            assertEquals(actual,store.metadataSourceIdentity(reordered));assertEquals(actual,store.metadataSourceIdentity(reordered.toBuilder().setName("New label").setQueryTimeoutSeconds(15).build()));
            assertEquals(column.key(),new MetadataIdentity(actual,profile().getId(),"data","public",ObjectKind.COLUMN,ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED,"parent","id","","").key());
            assertArrayEquals(profile().toByteArray(),store.profiles().getFirst().toByteArray());assertEquals(Set.of(old),store.metadataConfigurations().keySet());
            assertArrayEquals(presentation,Files.readAllBytes(flutter));
        }
    }
    @Test void newBindingsSurviveRestartAndConfigurationChangesRemainSeparate()throws Exception {
        String first,changed;try(var store=new MetadataStore(root)){first=store.metadataSourceIdentity(profile());changed=store.metadataSourceIdentity(profile().toBuilder().setUser("other").build());assertNotEquals(first,changed);}
        try(var store=new MetadataStore(root)){assertEquals(first,store.metadataSourceIdentity(profile()));assertEquals(changed,store.metadataSourceIdentity(profile().toBuilder().setUser("other").build()));}
    }
    @Test void migrationFailureRollsBackDraftRecoveryHistoryAndBindingSchemaTogether()throws Exception {
        legacy(2);String draft;
        // Insert a pending schema-2 draft after creating the real old layout.
        var old=StagedChange.newBuilder().setUnknownFields(com.google.protobuf.UnknownFieldSet.newBuilder().addField(2,com.google.protobuf.UnknownFieldSet.Field.newBuilder().addLengthDelimited(com.google.protobuf.ByteString.copyFrom(new byte[]{8,1,18,3,50,1,120})).build()).build()).build();
        var payload=StoredEditDraft.newBuilder().setChanges(ChangeRequest.newBuilder().addChanges(old)).build().toByteArray();draft="pending";
        try(var db=DriverManager.getConnection("jdbc:sqlite:"+root.resolve("metadata.sqlite"));var statement=db.createStatement()) {
            try(var insert=db.prepareStatement("INSERT INTO edit_drafts VALUES(?,?,?,?)")){insert.setString(1,draft);insert.setBytes(2,payload);insert.setString(3,"APPLYING");insert.setLong(4,1);insert.executeUpdate();}
            statement.execute("INSERT INTO operations VALUES('operation','execution',0)");
            statement.execute("CREATE TRIGGER reject_source_migration BEFORE INSERT ON migration WHEN NEW.version=4 BEGIN SELECT RAISE(ABORT,'fixture migration failure'); END");
        }
        assertThrows(SQLException.class,()->new MetadataStore(root));
        try(var db=DriverManager.getConnection("jdbc:sqlite:"+root.resolve("metadata.sqlite"));var statement=db.createStatement()) {
            try(var rows=statement.executeQuery("SELECT MAX(version) FROM migration")){assertTrue(rows.next());assertEquals(2,rows.getInt(1));}
            try(var rows=statement.executeQuery("SELECT payload,state FROM edit_drafts")){assertTrue(rows.next());assertArrayEquals(payload,rows.getBytes(1));assertEquals("APPLYING",rows.getString(2));}
            try(var rows=statement.executeQuery("SELECT COUNT(*) FROM operations")){assertTrue(rows.next());assertEquals(1,rows.getInt(1));}
            try(var rows=statement.executeQuery("SELECT COUNT(*) FROM sqlite_master WHERE name='metadata_source_identity'")){assertTrue(rows.next());assertEquals(0,rows.getInt(1));}
            statement.execute("DROP TRIGGER reject_source_migration");
        }
        try(var store=new MetadataStore(root)){assertEquals("UNKNOWN_OUTCOME",store.editDraft(draft).state());assertEquals("x",store.editDraft(draft).data().getChanges().getChanges(0).getValuesOrThrow(1).getValue().getText());assertEquals(previous(profile()),store.metadataSourceIdentity(profile()));}
    }
    @Test void unknownConfigurationBindingsArePreservedWithoutGuessingAnOwner()throws Exception {
        legacy(3);String unowned="a".repeat(64);
        try(var db=DriverManager.getConnection("jdbc:sqlite:"+root.resolve("metadata.sqlite"));var statement=db.prepareStatement("INSERT INTO metadata_configuration VALUES(?,?,?)")){statement.setString(1,unowned);statement.setLong(2,1);statement.setString(3,new com.google.gson.Gson().toJson(MetadataConfiguration.defaults()));statement.executeUpdate();}
        try(var store=new MetadataStore(root)){assertTrue(store.metadataConfigurations().containsKey(unowned));assertNotEquals(unowned,store.metadataSourceIdentity(profile()));}
    }
    @Test void bindingLimitRejectsNewOwnerWithoutDeletingExistingBindingsOrQuarantiningStore()throws Exception {
        String existing;
        try(var store=new MetadataStore(root)){store.save(profile());existing=store.metadataSourceIdentity(profile());}
        try(var db=DriverManager.getConnection("jdbc:sqlite:"+root.resolve("metadata.sqlite"));var insert=db.prepareStatement("INSERT INTO metadata_source_identity VALUES(?,?)")) {
            db.setAutoCommit(false);for(int i=1;i<4096;i++){String key=String.format(java.util.Locale.ROOT,"%064x",i);insert.setString(1,key);insert.setString(2,key);insert.addBatch();}insert.executeBatch();db.commit();
        }
        try(var store=new MetadataStore(root)) {
            assertThrows(IllegalStateException.class,()->store.metadataSourceIdentity(profile().toBuilder().setUser("new-owner").build()));
            assertEquals(existing,store.metadataSourceIdentity(profile()));assertEquals(List.of(profile()),store.profiles());
        }
        try(var db=DriverManager.getConnection("jdbc:sqlite:"+root.resolve("metadata.sqlite"));var statement=db.createStatement();var rows=statement.executeQuery("SELECT COUNT(*) FROM metadata_source_identity")){assertTrue(rows.next());assertEquals(4096,rows.getInt(1));}
    }
    @Test void missingCurrentBindingTableFailsWithoutReassigningExistingSourceIds()throws Exception {
        legacy(3);try(var migrated=new MetadataStore(root)){assertEquals(previous(profile()),migrated.metadataSourceIdentity(profile()));}
        try(var db=DriverManager.getConnection("jdbc:sqlite:"+root.resolve("metadata.sqlite"));var statement=db.createStatement()){statement.execute("DROP TABLE metadata_source_identity");}
        assertThrows(SQLException.class,()->new MetadataStore(root));
        try(var db=DriverManager.getConnection("jdbc:sqlite:"+root.resolve("metadata.sqlite"));var statement=db.createStatement();var rows=statement.executeQuery("SELECT payload FROM profiles")){assertTrue(rows.next());assertArrayEquals(profile().toByteArray(),rows.getBytes(1));}
    }
}
