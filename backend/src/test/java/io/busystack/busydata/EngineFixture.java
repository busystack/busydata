package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.analysis.SqlAnalysis;
import io.busystack.busydata.sessions.SessionRegistry;
import io.busystack.busydata.security.PrivateTemporaryFiles;
import io.busystack.busydata.results.ResultStore;
import io.busystack.busydata.storage.MetadataStore;
import io.busystack.busydata.safety.Safety;
import io.busystack.busydata.jobs.Jobs;
import io.busystack.busydata.schema.Explorer;
import java.nio.file.Path;
import java.time.Duration;
import java.util.UUID;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.wait.strategy.Wait;
import org.testcontainers.utility.DockerImageName;

/** Disposable real-engine fixture, using the production adapters and job path. */
final class EngineFixture implements AutoCloseable {
    final Engine engine;final GenericContainer<?> database;final Profile profile;
    final SessionRegistry sessions;final MetadataStore metadata;final ResultStore results;
    final SqlAnalysis analysis=new SqlAnalysis();final Safety safety=new Safety(analysis);final Jobs jobs;
    EngineFixture(Path root,String name)throws Exception {this(root,name,(adapter,request,port)->adapter.connect(request,port));}
    EngineFixture(Path root,String name,SessionRegistry.ConnectionOpener opener)throws Exception {this(root,name,opener,c->{});}
    EngineFixture(Path root,String name,java.util.function.Consumer<GenericContainer<?>> configure)throws Exception {this(root,name,(adapter,request,port)->adapter.connect(request,port),configure);}
    EngineFixture(Path root,String name,SessionRegistry.ConnectionOpener opener,java.util.function.Consumer<GenericContainer<?>> configure)throws Exception {
        this(root,name,opener,configure,connection->connection);
    }
    EngineFixture(Path root,String name,SessionRegistry.ConnectionOpener opener,java.util.function.Consumer<GenericContainer<?>> configure,java.util.function.UnaryOperator<java.sql.Connection> metadataDecorator)throws Exception {
        engine=Engine.valueOf(name);int port=engine==Engine.POSTGRESQL?5432:3306;
        String image=switch(engine){case POSTGRESQL->"postgres:17.11";case MYSQL->"mysql:8.4.10";case MARIADB->"mariadb:11.8.9";default->throw new AssertionError();};
        database=new GenericContainer<>(DockerImageName.parse(image)).withExposedPorts(port).withStartupTimeout(Duration.ofMinutes(3));
        if(engine==Engine.POSTGRESQL)database.withEnv("POSTGRES_PASSWORD","fixture").withEnv("POSTGRES_USER","busydata").withEnv("POSTGRES_DB","busydata").waitingFor(Wait.forLogMessage(".*database system is ready to accept connections.*\\n",2));
        else database.withEnv(engine==Engine.MYSQL?"MYSQL_ROOT_PASSWORD":"MARIADB_ROOT_PASSWORD","fixture").withEnv(engine==Engine.MYSQL?"MYSQL_DATABASE":"MARIADB_DATABASE","busydata").withCommand("--character-set-server=utf8mb4","--collation-server=utf8mb4_unicode_ci").waitingFor(Wait.forListeningPort());
        configure.accept(database);
        database.start();
        profile=Profile.newBuilder().setId("fault-fixture").setName("Disposable fixture").setEngine(engine).setHost(database.getHost()).setPort(database.getMappedPort(port)).setDatabase("busydata").setUser(engine==Engine.POSTGRESQL?"busydata":"root").setTls(Tls.newBuilder().setMode(engine==Engine.MYSQL?TlsMode.INSECURE:TlsMode.DISABLED)).setConnectTimeoutSeconds(10).setQueryTimeoutSeconds(30).build();
        sessions=new SessionRegistry(PrivateTemporaryFiles.isolated(),opener);metadata=new MetadataStore(root,metadataDecorator);results=new ResultStore(root,64L*1024*1024);jobs=new Jobs(results,metadata,analysis,safety);
    }
    SessionRegistry.Session open()throws Exception {return sessions.open(OpenRequest.newBuilder().setProfile(profile).setPassword("fixture").build());}
    Jobs.Job execute(SessionRegistry.Session session,String sql)throws Exception {return EditingIT.execute(jobs,safety,session,sql);}
    void warm(SessionRegistry.Session session,String... tables)throws Exception {warm(metadata,session,tables);}
    void introspectionLevel(SessionRegistry.Session session,io.busystack.busydata.metadata.IntrospectionLevel level)throws Exception {
        var platform=metadata.metadataPlatform();var before=platform.configuration(session);
        platform.configure(session,new io.busystack.busydata.metadata.MetadataConfiguration(before.revision()+1,before.includedCatalogs(),before.excludedCatalogs(),before.includedSchemas(),before.excludedSchemas(),before.systemObjects(),before.kinds(),before.includePatterns(),before.excludePatterns(),level,before.scopeLevels()));
    }
    /** Explicit user-style introspection before a query captures immutable editing proof. */
    static void warm(MetadataStore metadata,SessionRegistry.Session session,String... tables)throws Exception {
        var explorer=new Explorer(metadata);
        String catalog=session.context.catalog(),schema=session.profile.getEngine()==Engine.POSTGRESQL?session.context.schema():catalog;
        for(String table:tables)explorer.refreshFragment(session,catalog,schema,table,ObjectKind.TABLE);
    }
    Jobs.Job submit(SessionRegistry.Session session,String sql)throws Exception {
        var request=ExecuteRequest.newBuilder().setSessionId(session.id).setExecutionId(UUID.randomUUID().toString()).setSql(sql).setRowLimit(1000).build();
        return jobs.execute(session,request.toBuilder().setApprovalToken(safety.review(request,session).getToken()).build());
    }
    String schema(){return engine==Engine.POSTGRESQL?"public":"busydata";}
    public void close(){jobs.close();sessions.close();results.close();try{metadata.close();}catch(Exception ignored){}database.close();}
}
