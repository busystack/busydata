package io.busystack.busydata.metadata;

import io.busystack.busydata.NativeCaseFixtures;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.storage.MetadataStore;
import java.nio.file.*;
import java.sql.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static io.busystack.busydata.metadata.MetadataCacheTestAccess.await;
import static org.junit.jupiter.api.Assertions.*;

class NativeCaseRepositoryTest {
    @TempDir Path root;
    private static final MetadataScope SCOPE=new MetadataScope("db","db","t",ObjectKind.COLUMN);
    private MetadataSnapshot publish(Engine engine)throws Exception{
        var rules=NativeCaseFixtures.rules(engine,1);var column=MetadataObject.from("source","profile","",rules,SchemaObject.newBuilder().setKind(ObjectKind.COLUMN).setCatalog("db").setSchema("db").setTable("t").setName("Mixed").putProperties("type","INT").build(),IntrospectionLevel.STRUCTURE,1,1);
        var snapshot=new MetadataSnapshot("source","profile",1,1,1,rules,List.of(column),Map.of(SCOPE,new MetadataCoverage(SCOPE,IntrospectionLevel.STRUCTURE,MetadataState.AVAILABLE,true,"unchanged-native",1,1,1,"")));
        await(new MetadataRepository(root).publish(snapshot,MetadataSnapshot.empty("source","profile",rules)));return snapshot;
    }
    @Test void nativeEvidenceAndNormalizedObjectsRoundTripWithoutRestoringFreshCoverage()throws Exception{
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB)){
            var before=publish(engine);var after=new MetadataRepository(root).loadNewest().getFirst();
            assertEquals(before.rules(),after.rules());assertTrue(after.rules().complete());assertEquals(before.rules().serverVersion(),after.rules().serverVersion());
            assertEquals(before.identities(),after.identities());assertEquals(MetadataState.STALE,after.coverage(SCOPE).orElseThrow().state());assertFalse(after.complete(SCOPE,IntrospectionLevel.STRUCTURE));
            try(var db=DriverManager.getConnection("jdbc:sqlite:"+root.resolve("metadata_catalog.sqlite"));var statement=db.createStatement();var rows=statement.executeQuery("SELECT length(identifier_rules) FROM publication")){assertTrue(rows.next());assertTrue(rows.getInt(1)>262144);assertTrue(rows.getInt(1)<=IdentifierRules.MAX_ENCODED_BYTES);}
        }
    }
    @Test void oldFormatThreeCannotReviveUnchangedJavaNormalizedKeysOrTouchUserData()throws Exception{
        var profile=Profile.newBuilder().setId("preserved").setEngine(Engine.MYSQL).setDatabase("db").build();
        var draft=StoredEditDraft.newBuilder().setTarget(profile).setDocumentId("document").setSourceSql("SELECT id FROM db.t").setSchemaSignature("original-proof").setChanges(ChangeRequest.newBuilder().setCatalog("db").setSchema("db").setTable("t")).build();
        try(var user=new MetadataStore(root)){
            user.save(profile);String id=user.saveEditDraft("",draft);var config=MetadataConfiguration.defaults();user.metadataConfiguration("source",config);publish(Engine.MYSQL);
            try(var db=DriverManager.getConnection("jdbc:sqlite:"+root.resolve("metadata_catalog.sqlite"));var statement=db.createStatement()){statement.execute("UPDATE object SET lookup_key='obsolete-java-fold'");statement.execute("PRAGMA user_version=3");}
            var cache=new MetadataRepository(root);assertEquals("REBUILT_VERSION",cache.cacheState());assertTrue(cache.load().isEmpty());
            assertEquals(List.of(profile),user.profiles());assertEquals(draft,user.editDraft(id).data());assertEquals(config,user.metadataConfigurations().get("source"));
            try(var db=DriverManager.getConnection("jdbc:sqlite:"+root.resolve("metadata.sqlite"));var statement=db.createStatement();var rows=statement.executeQuery("SELECT MAX(version) FROM migration")){assertTrue(rows.next());assertEquals(4,rows.getInt(1));}
            try(var db=DriverManager.getConnection("jdbc:sqlite:"+root.resolve("metadata_catalog.sqlite"));var statement=db.createStatement();var rows=statement.executeQuery("PRAGMA user_version")){assertTrue(rows.next());assertEquals(5,rows.getInt(1));}
        }
    }
    @Test void storedLookupKeysMustAgreeWithTheirOwnedRuleEvidence()throws Exception{
        publish(Engine.MARIADB);
        try(var db=DriverManager.getConnection("jdbc:sqlite:"+root.resolve("metadata_catalog.sqlite"));var statement=db.createStatement()){statement.execute("UPDATE object SET lookup_key='wrong-generation'");}
        var cache=new MetadataRepository(root);assertTrue(cache.load().isEmpty());assertEquals("REBUILT_CORRUPT",cache.cacheState());
    }
    @Test void oversizedEvidenceIsRejectedBeforeRestoringObjects()throws Exception{
        publish(Engine.MYSQL);
        try(var db=DriverManager.getConnection("jdbc:sqlite:"+root.resolve("metadata_catalog.sqlite"));var statement=db.createStatement()){statement.execute("UPDATE publication SET identifier_rules=zeroblob("+(IdentifierRules.MAX_ENCODED_BYTES+1)+")");}
        var cache=new MetadataRepository(root);assertTrue(cache.load().isEmpty());assertEquals("REBUILT_CORRUPT",cache.cacheState());
    }
}
