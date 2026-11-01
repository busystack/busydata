package io.busystack.busydata;

import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.Explorer;
import io.busystack.busydata.sessions.SessionRegistry;
import java.nio.file.Path;
import java.util.*;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

class FragmentDependenciesIT {
    @TempDir Path root;
    private static void ddl(SessionRegistry.Session session,String... statements)throws Exception{session.lock.lock();try{try(var command=session.connection.createStatement()){for(String statement:statements)command.execute(statement);}session.refresh();session.advanceRevision();}finally{session.lock.unlock();}}
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void aFragmentRefreshesPreviousAndCurrentTargetsOneHopAcrossConfiguredNamespaces(String engine)throws Exception {
        var otherConnections=new AtomicInteger();
        try(var f=new EngineFixture(root,engine,(adapter,request,port)->{if(request.getProfile().getReadOnly()&&request.getProfile().getDatabase().equals("dependency_other"))otherConnections.incrementAndGet();return adapter.connect(request,port);})){
            var session=f.open();var external=f.open();var explorer=new Explorer(f.metadata);var platform=explorer.metadata();String local=f.schema(),remote=f.engine==Engine.POSTGRESQL?"dependency_schema":"dependency_other";
            ddl(external,(f.engine==Engine.POSTGRESQL?"CREATE SCHEMA ":"CREATE DATABASE ")+remote);
            String oldTarget=session.adapter.table("busydata",local,"dependency_before"),source=session.adapter.table("busydata",local,"dependency_source"),target=session.adapter.table(f.engine==Engine.POSTGRESQL?"busydata":remote,remote,"dependency_target"),third=session.adapter.table(f.engine==Engine.POSTGRESQL?"busydata":remote,remote,"dependency_third");
            ddl(external,"CREATE TABLE "+oldTarget+"(id INTEGER PRIMARY KEY)","CREATE TABLE "+third+"(id INTEGER PRIMARY KEY)","CREATE TABLE "+target+"(id INTEGER PRIMARY KEY,third_id INTEGER,CONSTRAINT target_third FOREIGN KEY(third_id) REFERENCES "+third+"(id))","CREATE TABLE "+source+"(id INTEGER PRIMARY KEY,parent_id INTEGER,CONSTRAINT source_target FOREIGN KEY(parent_id) REFERENCES "+oldTarget+"(id))");
            var config=platform.configuration(session);platform.configure(session,new MetadataConfiguration(config.revision()+1,f.engine==Engine.POSTGRESQL?Set.of("busydata"):Set.of("busydata",remote),Set.of(),f.engine==Engine.POSTGRESQL?Set.of(local,remote):Set.of(),Set.of(),false,config.kinds(),List.of(),List.of(),IntrospectionLevel.STRUCTURE,Map.of()));
            explorer.refreshContext(session,MetadataPlatform.RefreshMode.FULL);String remoteCatalog=f.engine==Engine.POSTGRESQL?"busydata":remote;
            explorer.explore(session,ExploreRequest.newBuilder().setCatalog(remoteCatalog).setSchema(remote).setKind(ObjectKind.TABLE).setIntrospectionLevel(3).setIndependentMetadata(true).build());
            explorer.explore(session,ExploreRequest.newBuilder().setCatalog(remoteCatalog).setSchema(remote).setKind(ObjectKind.TABLE).setSearch("dependency_third").setExactName(true).setIntrospectionLevel(3).setIndependentMetadata(true).build());
            var before=platform.publishedSnapshot(session);var remoteSources=new MetadataScope(remoteCatalog,remote,"",ObjectKind.TABLE);var exactThirdSource=new MetadataScope(remoteCatalog,remote,"",ObjectKind.TABLE,"dependency_third",true,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED);assertTrue(before.complete(remoteSources,IntrospectionLevel.SOURCE));
            var thirdObject=before.resolve(remoteCatalog,remote,ObjectKind.TABLE,"","dependency_third",true).getFirst();var thirdColumns=new MetadataScope(remoteCatalog,remote,"dependency_third",ObjectKind.COLUMN);long thirdTime=before.coverage(thirdColumns).orElseThrow().refreshedUnixMs();
            ddl(external,"ALTER TABLE "+third+" ADD COLUMN unrequested_change INTEGER","DROP TABLE "+source,"CREATE TABLE "+source+"(id INTEGER PRIMARY KEY,parent_id INTEGER,CONSTRAINT source_target FOREIGN KEY(parent_id) REFERENCES "+target+"(id))");
            int connections=otherConnections.get();var after=explorer.refreshFragment(session,"busydata",local,"dependency_source",ObjectKind.TABLE);
            var relationship=after.outgoing("busydata",local,"dependency_source").getFirst();assertEquals(remote,relationship.properties().get("referencedSchema"));assertEquals("dependency_target",relationship.properties().get("referencedTable"));assertTrue(after.relationshipComplete(relationship),"The new outgoing target must have verified identity and current columns");
            assertTrue(after.complete(new MetadataScope("busydata",local,"dependency_before",ObjectKind.COLUMN),IntrospectionLevel.STRUCTURE),"Previous targets are reconciled even when no longer returned by native exported keys");assertEquals(MetadataState.AVAILABLE,after.resolve("busydata",local,ObjectKind.TABLE,"","dependency_before",true).getFirst().state());assertTrue(after.complete(new MetadataScope(remoteCatalog,remote,"dependency_target",ObjectKind.COLUMN),IntrospectionLevel.STRUCTURE));
            assertSame(thirdObject,after.resolve(remoteCatalog,remote,ObjectKind.TABLE,"","dependency_third",true).getFirst(),"A dependency target's other outgoing keys must not trigger a transitive component refresh");assertEquals(thirdTime,after.coverage(thirdColumns).orElseThrow().refreshedUnixMs());assertTrue(after.resolve(remoteCatalog,remote,ObjectKind.COLUMN,"dependency_third","unrequested_change",true).isEmpty());
            assertEquals(MetadataState.STALE,after.coverage(remoteSources).orElseThrow().state(),"Replacing one target at Level 2 cannot leave broader Level 3 source coverage complete");assertTrue(after.complete(exactThirdSource,IntrospectionLevel.SOURCE),"Unchanged exact source evidence is not downgraded by an unrelated structural refresh");
            if(f.engine!=Engine.POSTGRESQL)assertTrue(otherConnections.get()>connections,"A verified cross-database target uses its own independent metadata connection");assertTrue(f.jobs.list("").isEmpty());
        }
    }
}
