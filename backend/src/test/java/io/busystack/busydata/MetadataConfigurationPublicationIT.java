package io.busystack.busydata;

import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.storage.MetadataStore;
import java.lang.reflect.*;
import java.nio.file.Path;
import java.sql.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

/** Real SQLite preference CAS and PostgreSQL physical owner; catalog facts are synthetic. */
class MetadataConfigurationPublicationIT {
    @TempDir Path root;
    private static final IdentifierRules RULES=new IdentifierRules(Engine.POSTGRESQL,0);
    private static final String SCHEMA="synthetic_scope";
    private static final String CONFIGURATION_CAS="INSERT INTO metadata_configuration VALUES(?,?,?) ON CONFLICT(source) DO UPDATE SET revision=excluded.revision,payload=excluded.payload WHERE metadata_configuration.revision=?";
    private static Object invoke(Object target,Method method,Object[] arguments)throws Throwable{
        try{return method.invoke(target,arguments);}catch(InvocationTargetException failure){throw failure.getCause();}
    }
    private static MetadataCoverage coverage(MetadataScope scope,IntrospectionLevel level,long revision,long context){return new MetadataCoverage(scope,level,MetadataState.AVAILABLE,true,"synthetic-fixture",revision,context,System.currentTimeMillis(),"");}
    private static MetadataScope table(String catalog,String name){return new MetadataScope(catalog,SCHEMA,"",ObjectKind.TABLE,name,true,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED);}
    private static MetadataScope columns(String catalog,String name){return new MetadataScope(catalog,SCHEMA,name,ObjectKind.COLUMN);}
    private static SchemaObject relation(String catalog,String name,int id){return SchemaObject.newBuilder().setCatalog(catalog).setSchema(SCHEMA).setName(name).setKind(ObjectKind.TABLE).putProperties("nativeId",Integer.toString(id)).build();}
    private static SchemaObject column(String catalog,String parent,int id){return SchemaObject.newBuilder().setCatalog(catalog).setSchema(SCHEMA).setTable(parent).setName("id").setKind(ObjectKind.COLUMN).putProperties("nativeId",Integer.toString(id)).putProperties("ordinal","1").putProperties("nativeType","bigint").putProperties("nativeTypeId","20").putProperties("jdbcType","-5").build();}

    @Test void essentialPreferenceCasPreservesUnaffectedReferencesAndConcurrentInvalidation()throws Exception{
        var armed=new AtomicBoolean();var entered=new CountDownLatch(1);var release=new CountDownLatch(1);var released=new AtomicBoolean();var releases=new AtomicInteger();var writes=new AtomicInteger();var physicalCalls=new AtomicInteger();var watchPhysical=new AtomicBoolean();
        Runnable releaseOnce=()->{if(released.compareAndSet(false,true)){releases.incrementAndGet();release.countDown();}};
        try(var fixture=new EngineFixture(root.resolve("physical-owner"),"POSTGRESQL",(adapter,request,port)->{
            var physical=adapter.connect(request,port);
            return (Connection)Proxy.newProxyInstance(Connection.class.getClassLoader(),new Class<?>[]{Connection.class},(proxy,method,arguments)->{
                if(watchPhysical.get()&&Set.of("prepareStatement","prepareCall","createStatement","getMetaData","commit","rollback","setAutoCommit","setCatalog","setSchema").contains(method.getName()))physicalCalls.incrementAndGet();
                return invoke(physical,method,arguments);
            });
        });var store=new MetadataStore(root.resolve("policy-owner"),connection->(Connection)Proxy.newProxyInstance(Connection.class.getClassLoader(),new Class<?>[]{Connection.class},(proxy,method,arguments)->{
            var result=invoke(connection,method,arguments);
            if(method.getName().equals("prepareStatement")&&arguments!=null&&arguments.length>0&&CONFIGURATION_CAS.equals(arguments[0])){
                var statement=(PreparedStatement)result;
                return Proxy.newProxyInstance(PreparedStatement.class.getClassLoader(),new Class<?>[]{PreparedStatement.class},(statementProxy,operation,values)->{
                    if(operation.getName().equals("executeUpdate")){
                        writes.incrementAndGet();if(armed.compareAndSet(true,false)){
                            entered.countDown();try{if(!release.await(10,TimeUnit.SECONDS))throw new SQLTimeoutException("Owned configuration CAS was not released","57014");}
                            catch(InterruptedException interrupted){Thread.currentThread().interrupt();throw new SQLTransientException("Owned configuration CAS interrupted","57014",interrupted);}
                        }
                    }
                    return invoke(statement,operation,values);
                });
            }
            return result;
        }));var workers=Executors.newFixedThreadPool(2)){
            var owner=fixture.open();watchPhysical.set(true);var platform=store.metadataPlatform();String catalog=owner.context.catalog();long physicalRevision=owner.revision,contextRevision=owner.contextRevision;var transaction=owner.state;boolean autoCommit=owner.autoCommit;
            var parent=new MetadataScope(catalog,SCHEMA,"",ObjectKind.TABLE);var names=List.of("keep","stale","drop");var relations=new ArrayList<SchemaObject>();for(int i=0;i<names.size();i++)relations.add(relation(catalog,names.get(i),i+1));
            var branches=new LinkedHashMap<MetadataScope,MetadataPlatform.Branch>();branches.put(parent,new MetadataPlatform.Branch(relations,coverage(parent,IntrospectionLevel.NAMES,physicalRevision,contextRevision)));
            for(int i=0;i<names.size();i++){
                var name=names.get(i);var exact=table(catalog,name);var children=columns(catalog,name);branches.put(exact,new MetadataPlatform.Branch(List.of(relations.get(i)),coverage(exact,IntrospectionLevel.STRUCTURE,physicalRevision,contextRevision)));branches.put(children,new MetadataPlatform.Branch(List.of(column(catalog,name,100+i)),coverage(children,IntrospectionLevel.STRUCTURE,physicalRevision,contextRevision)));
            }
            platform.publish(owner,platform.beginRefresh(owner),RULES,branches,false);var before=platform.publishedSnapshot(owner);var keep=table(catalog,"keep");var stale=table(catalog,"stale");var drop=table(catalog,"drop");var keepColumns=columns(catalog,"keep");var staleColumns=columns(catalog,"stale");var dropColumns=columns(catalog,"drop");
            assertTrue(before.complete(parent,IntrospectionLevel.NAMES));for(var scope:List.of(keep,stale,drop,keepColumns,staleColumns,dropColumns))assertTrue(before.complete(scope,IntrospectionLevel.STRUCTURE));
            var keepRelation=before.select(keep).getFirst();var keepColumn=before.select(keepColumns).getFirst();var keepState=before.catalogCoverage().get(keep);var keepColumnState=before.catalogCoverage().get(keepColumns);var current=platform.configuration(owner);
            var next=new MetadataConfiguration(current.revision()+1,current.includedCatalogs(),current.excludedCatalogs(),current.includedSchemas(),current.excludedSchemas(),current.systemObjects(),current.kinds(),current.includePatterns(),List.of("drop"),current.defaultLevel(),current.scopeLevels());var expected=platform.publicationRevision(owner);armed.set(true);
            var configure=workers.submit(()->{platform.configure(owner,next);return true;});
            try{
                assertTrue(entered.await(5,TimeUnit.SECONDS),"The real essential preference CAS must be paused before executing SQL");assertEquals(current,platform.configuration(owner));assertSame(before,platform.publishedSnapshot(owner));
                var effect=DdlEffect.newBuilder().setCatalog(catalog).setSchema(SCHEMA).setName("stale").setKind(ObjectKind.TABLE).setOperation("ALTER").build();
                var invalidated=workers.submit(()->{platform.markStaleIfRevision(owner,expected,List.of(effect),"Concurrent fixture invalidation");return platform.publishedSnapshot(owner);}).get(2,TimeUnit.SECONDS);
                var staleState=invalidated.catalogCoverage().get(stale);var staleColumnState=invalidated.catalogCoverage().get(staleColumns);assertEquals(MetadataState.STALE,staleState.state());assertEquals(MetadataState.STALE,staleColumnState.state());assertSame(keepState,invalidated.catalogCoverage().get(keep));assertSame(keepColumnState,invalidated.catalogCoverage().get(keepColumns));
                assertEquals(MetadataState.STALE,workers.submit(()->platform.proofAdmissionState(owner,platform.proofFence(owner))).get(500,TimeUnit.MILLISECONDS),"Configuration pending denies durable proof without waiting for its SQLite CAS");
                releaseOnce.run();assertTrue(configure.get(10,TimeUnit.SECONDS));var after=platform.publishedSnapshot(owner);
                assertEquals(next,platform.configuration(owner));assertEquals(next,store.metadataConfigurations().get(owner.metadataSourceIdentity));assertEquals(1,writes.get());assertEquals(1,releases.get());
                assertSame(keepRelation,after.select(keep).getFirst());assertSame(keepColumn,after.select(keepColumns).getFirst());assertSame(keepState,after.catalogCoverage().get(keep));assertSame(keepColumnState,after.catalogCoverage().get(keepColumns));assertTrue(after.complete(keep,IntrospectionLevel.STRUCTURE));assertTrue(after.complete(keepColumns,IntrospectionLevel.STRUCTURE));
                assertSame(staleState,after.catalogCoverage().get(stale),"The latest actual invalidation must survive the essential CAS");assertSame(staleColumnState,after.catalogCoverage().get(staleColumns));assertFalse(after.complete(stale,IntrospectionLevel.STRUCTURE));assertFalse(after.complete(staleColumns,IntrospectionLevel.STRUCTURE));
                assertEquals(MetadataState.STALE,after.catalogCoverage().get(parent).state(),"Changing enumeration membership invalidates only its broader names proof");
                assertTrue(after.select(drop).isEmpty());assertTrue(after.select(dropColumns).isEmpty());assertFalse(after.catalogCoverage().containsKey(drop));assertFalse(after.catalogCoverage().containsKey(dropColumns));
                assertEquals(physicalRevision,owner.revision);assertEquals(contextRevision,owner.contextRevision);assertEquals(transaction,owner.state);assertEquals(autoCommit,owner.autoCommit);assertEquals(0,physicalCalls.get(),"Policy publication must not issue user database SQL or resolve its transaction");assertTrue(fixture.jobs.list(owner.id).isEmpty(),"The test performs no user SQL job or automatic retry");
                assertTrue(before.complete(stale,IntrospectionLevel.STRUCTURE));assertEquals(1,before.select(drop).size(),"Held immutable model remains unchanged");
            }finally{releaseOnce.run();configure.get(10,TimeUnit.SECONDS);watchPhysical.set(false);}
        }finally{releaseOnce.run();watchPhysical.set(false);}
    }
}
