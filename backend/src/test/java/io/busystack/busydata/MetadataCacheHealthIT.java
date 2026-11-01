package io.busystack.busydata;

import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.Explorer;
import java.nio.file.Path;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.sql.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.locks.LockSupport;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

/** A cache-only failure must never revoke or misreport a committed fresh model.
 * These cases may expire while awaiting BEGIN; repository FULL/trigger tests
 * separately establish rollback after rows have actually been written. */
class MetadataCacheHealthIT {
    @TempDir Path root;
    private static final IdentifierRules RULES=new IdentifierRules(Engine.POSTGRESQL,0);
    private static Map<MetadataScope,MetadataPlatform.Branch> branch(io.busystack.busydata.sessions.SessionRegistry.Session owner,String name){
        var scope=new MetadataScope(owner.context.catalog(),"synthetic_cache","",ObjectKind.TABLE);
        var object=SchemaObject.newBuilder().setKind(ObjectKind.TABLE).setCatalog(owner.context.catalog()).setSchema("synthetic_cache").setName(name).putProperties("nativeId",name).build();
        var coverage=new MetadataCoverage(scope,IntrospectionLevel.STRUCTURE,MetadataState.AVAILABLE,true,name,owner.revision,owner.contextRevision,System.currentTimeMillis(),"");return Map.of(scope,new MetadataPlatform.Branch(List.of(object),coverage));
    }
    private static String persisted(Path cache)throws Exception{
        var digest=MessageDigest.getInstance("SHA-256");
        try(var db=DriverManager.getConnection("jdbc:sqlite:"+cache.resolve("metadata_catalog.sqlite"));var statement=db.createStatement()){
            for(String table:List.of("publication","object","property","coverage"))try(var rows=statement.executeQuery("SELECT * FROM "+table+" ORDER BY "+(table.equals("publication")?"source":table.equals("property")?"source,identity,name":"source,identity"))){
                int columns=rows.getMetaData().getColumnCount();while(rows.next())for(int c=1;c<=columns;c++){byte[] value=c==8&&table.equals("publication")?rows.getBytes(c):Objects.toString(rows.getString(c),"").getBytes(StandardCharsets.UTF_8);digest.update((byte)(value.length>>>24));digest.update((byte)(value.length>>>16));digest.update((byte)(value.length>>>8));digest.update((byte)value.length);digest.update(value);}
            }
        }return HexFormat.of().formatHex(digest.digest());
    }
    @ParameterizedTest @ValueSource(strings={"timeout","cancelled"})
    void cacheFailureKeepsCurrentMemoryAvailableAndItsPriorAtomicCacheUntouched(String mode)throws Exception{
        Path cache=root.resolve("cache");var platform=new MetadataPlatform(cache);
        try(var fixture=new EngineFixture(root.resolve("physical"),"POSTGRESQL");var worker=Executors.newSingleThreadExecutor()){
            var owner=fixture.open();var initial=platform.publish(owner,platform.beginRefresh(owner),RULES,branch(owner,"prior"),false);String diskBefore=persisted(cache);
            try(var blocker=DriverManager.getConnection("jdbc:sqlite:"+cache.resolve("metadata_catalog.sqlite"));var lock=blocker.createStatement()){
                lock.execute("BEGIN IMMEDIATE");var cancellation=io.grpc.Context.current().withCancellation();var reservation=platform.reserveRefresh(owner);long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(mode.equals("timeout")?1:30);
                var future=worker.submit(cancellation.wrap(()->MetadataCacheTestAccess.publish(platform,owner,reservation,RULES,branch(owner,"current"),deadline)));
                try{
                    long wait=System.nanoTime()+TimeUnit.SECONDS.toNanos(5);
                    while(System.nanoTime()<wait&&!future.isDone()&&!(platform.cacheState(owner).equals("WRITE_PENDING")&&platform.publishedSnapshot(owner).revision()>initial.revision()))LockSupport.parkNanos(TimeUnit.MILLISECONDS.toNanos(1));
                    if(mode.equals("cancelled")){assertEquals("WRITE_PENDING",platform.cacheState(owner));assertTrue(platform.publishedSnapshot(owner).revision()>initial.revision());cancellation.cancel(null);}
                    var current=future.get(4,TimeUnit.SECONDS);assertTrue(current.revision()>initial.revision());assertEquals("WRITE_UNAVAILABLE",platform.cacheState(owner));
                    var receipt=platform.cacheWriteReceipt(owner);if(receipt.isPresent()){receipt.orElseThrow().awaitCompletion(System.nanoTime()+TimeUnit.SECONDS.toNanos(4));var phases=platform.cacheWriteMetrics(owner).orElseThrow();assertTrue(phases.matches(current));assertEquals(MetadataRepository.CommitOutcome.NOT_ATTEMPTED,phases.commitOutcome());assertEquals(0,phases.commitNanos());}
                    else{assertEquals("cancelled",mode,"Only cancellation before writer reservation can omit its native receipt");assertTrue(platform.cacheWriteMetrics(owner).isEmpty());}
                    assertEquals(mode.equals("timeout")?MetadataRepository.FailureReason.TIMED_OUT:MetadataRepository.FailureReason.CANCELLED,platform.cacheFailure(owner).orElseThrow().reason());
                    assertTrue(current.coverage().values().stream().allMatch(state->state.complete()&&state.state()==MetadataState.AVAILABLE));assertTrue(current.identities().values().stream().anyMatch(value->value.identity().name().equals("current")));
                    var settings=MetadataRpc.run(new Explorer(platform),owner,MetadataSettingsRequest.newBuilder().setSessionId(owner.id).setSessionRevision(owner.revision).setContextRevision(owner.contextRevision).setAction(MetadataSettingsAction.READ_METADATA_SETTINGS).setLimit(1).build());
                    assertEquals(current.revision(),settings.getSnapshotRevision());assertEquals(owner.id,settings.getSessionId());assertEquals("WRITE_UNAVAILABLE",settings.getCacheState());assertEquals("AVAILABLE",settings.getScopes(0).getState());assertTrue(settings.getScopes(0).getComplete());
                    assertEquals(diskBefore,persisted(cache),"Failed cache transaction changed its exact header, facts, properties or coverage");
                }finally{cancellation.close();lock.execute("ROLLBACK");future.get(5,TimeUnit.SECONDS);}
            }
            assertEquals(diskBefore,persisted(cache));
        }
    }
}
