package io.busystack.busydata;

import io.busystack.busydata.adapters.JdbcAdapter;
import io.busystack.busydata.analysis.SqlParsing;
import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import java.lang.reflect.Modifier;
import java.sql.Types;
import java.util.*;
import java.util.concurrent.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class ExecutionMetadataTest {
    private static final String SOURCE="source",PROFILE="profile",CATALOG="db";
    private static Profile profile(Engine engine){return Profile.newBuilder().setId(PROFILE).setEngine(engine).setDatabase(CATALOG).build();}
    private static JdbcAdapter.LiveContext context(Engine engine){return new JdbcAdapter.LiveContext(CATALOG,engine==Engine.POSTGRESQL?"public":CATALOG,List.of(engine==Engine.POSTGRESQL?"public":CATALOG),"","",true,"+00:00","UTC",true,"ISO, MDY");}
    private static Column selected(Engine engine,String name,int ordinal){return Column.newBuilder().setCatalog(CATALOG).setSchema(engine==Engine.POSTGRESQL?"public":CATALOG).setTable("t").setBaseColumn(name).setName("alias_"+ordinal).setOrdinal(ordinal).setJdbcType(Types.INTEGER).setProvenanceKnown(true).build();}
    private static MetadataObject object(Engine engine,String session,String schema,ObjectKind kind,String parent,String name,Map<String,String> properties){return MetadataObject.from(SOURCE,PROFILE,session,io.busystack.busydata.NativeCaseFixtures.rules(engine,0),SchemaObject.newBuilder().setCatalog(CATALOG).setSchema(schema).setKind(kind).setTable(parent).setName(name).putAllProperties(properties).build(),IntrospectionLevel.STRUCTURE,1,1);}
    private static MetadataSnapshot fixture(Engine engine,boolean badColumn){
        String schema=engine==Engine.POSTGRESQL?"public":CATALOG;var entries=new ArrayList<MetadataObject>();
        entries.add(object(engine,"",schema,ObjectKind.TABLE,"","t",Map.of("nativeId","7","nativeGeneration","generation-7","nativeGenerationAvailability","AVAILABLE")));
        entries.add(object(engine,"",schema,ObjectKind.COLUMN,"t","id",Map.of("nativeId","7:1","jdbcType",Integer.toString(Types.INTEGER),"jdbcNativeType","integer","type","integer","ordinal","1","nativeTypeId","23")));
        entries.add(object(engine,"",schema,ObjectKind.COLUMN,"t","other",Map.of("nativeId","7:2","jdbcType",Integer.toString(engine==Engine.POSTGRESQL?Types.ARRAY:Types.TIMESTAMP),"jdbcNativeType",engine==Engine.POSTGRESQL?"_date":"TIMESTAMP","type",engine==Engine.POSTGRESQL?"_date":"TIMESTAMP","ordinal","2","arrayElementType","date")));
        if(badColumn){var original=entries.removeLast();entries.add(new MetadataObject(original.identity(),original.displayName(),original.quotedIdentifier(),original.lookupKey(),original.properties(),original.source(),original.level(),MetadataState.DENIED,1,1));}
        var scope=new MetadataScope(CATALOG,schema,"t",ObjectKind.COLUMN);var coverage=new HashMap<MetadataScope,MetadataCoverage>();coverage.put(scope,new MetadataCoverage(scope,IntrospectionLevel.STRUCTURE,MetadataState.AVAILABLE,true,"complete",1,1,1,""));
        for(String namespace:List.of("pg_catalog","public"))for(var kind:List.of(ObjectKind.TABLE,ObjectKind.VIEW)){var branch=new MetadataScope(CATALOG,namespace,"",kind);coverage.put(branch,new MetadataCoverage(branch,IntrospectionLevel.NAMES,MetadataState.AVAILABLE,true,"names",1,1,1,""));}
        return new MetadataSnapshot(SOURCE,PROFILE,11,3,1,io.busystack.busydata.NativeCaseFixtures.rules(engine,0),entries,coverage);
    }
    private static MetadataSnapshot temporaryFixture(MetadataSnapshot original){
        var temporary=new ArrayList<MetadataObject>();for(var value:original.identities().values())temporary.add(object(Engine.POSTGRESQL,"owner","pg_temp_7",value.identity().kind(),value.identity().parent(),value.identity().name(),value.properties()));
        var scope=new MetadataScope(CATALOG,"pg_temp_7","t",ObjectKind.COLUMN);
        return new MetadataSnapshot(SOURCE,PROFILE,13,3,1,original.rules(),temporary,Map.of(scope,new MetadataCoverage(scope,IntrospectionLevel.STRUCTURE,MetadataState.AVAILABLE,true,"complete",1,1,1,"")));
    }
    private static void assertAvailable(RetainedMetadataProof proof){assertTrue(proof.available(),()->proof.state()+": "+proof.availability());}
    @Test void executionAndRecoveryShareExactSelectedProofWithActualOrdinals(){
        for(var engine:List.of(Engine.POSTGRESQL,Engine.MYSQL,Engine.MARIADB)){
            var snapshot=fixture(engine,false);var columns=List.of(selected(engine,"id",5));String sql="SELECT id AS alias_5 FROM "+(engine==Engine.POSTGRESQL?"public.t":"db.t");
            var candidate=ExecutionMetadata.prepare(snapshot,profile(engine),"session",sql,context(engine));var proof=candidate.proof(columns);
            assertTrue(proof.available(),engine+" "+proof.state()+": "+proof.availability());assertEquals(11,proof.snapshotRevision());assertEquals(3,proof.configurationRevision());assertEquals(Set.of(5),proof.columns().keySet());
            assertEquals(RetainedMetadataProof.capture(snapshot,columns,profile(engine),"session",context(engine)),proof);
            assertEquals(RetainedMetadataProof.captureExecution(snapshot,columns,profile(engine),"session",sql,context(engine)),proof);
            assertTrue(candidate.estimatedBytes()<=ExecutionMetadata.MAX_BYTES);assertEquals(2,candidate.columnCount());
            assertDetached(candidate,new IdentityHashMap<>());
        }
    }
    @Test void unselectedUnsupportedArrayOrTimestampDoesNotDisableIntegerProjection(){
        for(var engine:List.of(Engine.POSTGRESQL,Engine.MYSQL,Engine.MARIADB)){
            var invalid=new JdbcAdapter.LiveContext(CATALOG,engine==Engine.POSTGRESQL?"public":CATALOG,List.of("public"),"","",true,"","",false,"SQL, DMY");
            var candidate=ExecutionMetadata.prepare(fixture(engine,false),profile(engine),"session","SELECT id FROM "+(engine==Engine.POSTGRESQL?"public.t":"db.t"),invalid);
            assertAvailable(candidate.proof(List.of(selected(engine,"id",1))));
            var unavailable=candidate.proof(List.of(selected(engine,"other",2).toBuilder().setJdbcType(engine==Engine.POSTGRESQL?Types.ARRAY:Types.TIMESTAMP).build()));
            assertFalse(unavailable.available());assertEquals(MetadataState.UNSUPPORTED,unavailable.state());
        }
    }
    @Test void unselectedDeniedColumnDoesNotDisableExactAvailableColumn(){
        var candidate=ExecutionMetadata.prepare(fixture(Engine.POSTGRESQL,true),profile(Engine.POSTGRESQL),"session","SELECT id FROM public.t",context(Engine.POSTGRESQL));
        assertAvailable(candidate.proof(List.of(selected(Engine.POSTGRESQL,"id",1))));
        assertFalse(candidate.proof(List.of(selected(Engine.POSTGRESQL,"other",2))).available());
    }
    @Test void actualProvenanceAndOrdinalAreValidatedAfterExecution(){
        var candidate=ExecutionMetadata.prepare(fixture(Engine.POSTGRESQL,false),profile(Engine.POSTGRESQL),"session","SELECT id FROM public.t",context(Engine.POSTGRESQL));var column=selected(Engine.POSTGRESQL,"id",1);
        for(var forged:List.of(column.toBuilder().setCatalog("another").build(),column.toBuilder().setSchema("audit").build(),column.toBuilder().setTable("other").build(),column.toBuilder().setBaseColumn("missing").build(),column.toBuilder().setProvenanceKnown(false).build(),column.toBuilder().setOrdinal(0).build(),column.toBuilder().setOrdinal(2049).build()))assertFalse(candidate.proof(List.of(forged)).available());
        assertFalse(candidate.proof(List.of(column,column)).available());assertFalse(candidate.proof(List.of()).available());
    }
    @Test void searchPathViewShadowIncompleteNamespaceAndExactTemporaryOwnerRemainConservative(){
        var original=fixture(Engine.POSTGRESQL,false);var entries=new ArrayList<>(original.identities().values());entries.add(object(Engine.POSTGRESQL,"","audit",ObjectKind.VIEW,"","t",Map.of()));
        var shadowed=new MetadataSnapshot(SOURCE,PROFILE,12,3,1,original.rules(),entries,original.catalogCoverage());var ctx=new JdbcAdapter.LiveContext(CATALOG,"audit",List.of("audit","public"),"");var columns=List.of(selected(Engine.POSTGRESQL,"id",1));
        assertFalse(ExecutionMetadata.prepare(shadowed,profile(Engine.POSTGRESQL),"session","SELECT id FROM t",ctx).proof(columns).available());
        assertAvailable(ExecutionMetadata.prepare(shadowed,profile(Engine.POSTGRESQL),"session","SELECT id FROM public.t",ctx).proof(columns));
        assertFalse(ExecutionMetadata.prepare(original,profile(Engine.POSTGRESQL),"session","SELECT id FROM t",ctx).proof(columns).available());
        var temp=temporaryFixture(original);
        var tempContext=new JdbcAdapter.LiveContext(CATALOG,"public",List.of("public"),"pg_temp_7");var tempColumns=List.of(columns.getFirst().toBuilder().setSchema("pg_temp_7").build());
        assertAvailable(ExecutionMetadata.prepare(temp,profile(Engine.POSTGRESQL),"owner","SELECT id FROM pg_temp.t",tempContext).proof(tempColumns));
        assertAvailable(ExecutionMetadata.prepare(temp,profile(Engine.POSTGRESQL),"owner","SELECT id FROM PG_TEMP.t",tempContext).proof(tempColumns));
        assertFalse(ExecutionMetadata.prepare(temp,profile(Engine.POSTGRESQL),"owner","SELECT id FROM \"PG_TEMP\".t",tempContext).proof(tempColumns).available());
        assertFalse(ExecutionMetadata.prepare(temp,profile(Engine.POSTGRESQL),"other","SELECT id FROM pg_temp.t",tempContext).proof(tempColumns).available());
    }
    @Test void parserAdmissionFailuresRemainTypedWithoutChangingTheTemporaryOwner()throws Exception {
        var snapshot=temporaryFixture(fixture(Engine.POSTGRESQL,false));var context=new JdbcAdapter.LiveContext(CATALOG,"public",List.of("public"),"pg_temp_7");
        var columns=List.of(selected(Engine.POSTGRESQL,"id",1).toBuilder().setSchema("pg_temp_7").build());String sql="SELECT id FROM pg_temp.t";
        var field=SqlParsing.class.getDeclaredField("CPU");field.setAccessible(true);var pool=(ThreadPoolExecutor)field.get(null);
        var entered=new CountDownLatch(2);var release=new CountDownLatch(1);var blockers=new ArrayList<Future<?>>();
        try{
            for(int index=0;index<2;index++)blockers.add(pool.submit(()->{entered.countDown();release.await();return null;}));
            assertTrue(entered.await(10,TimeUnit.SECONDS),"Both owned parser workers must acknowledge their admission gate");
            var failure=assertThrows(net.sf.jsqlparser.JSQLParserException.class,()->SqlParsing.parse(sql,Engine.POSTGRESQL,context.lexical()));
            Throwable cause=failure;boolean timedOut=false;for(int depth=0;cause!=null&&depth<16;depth++,cause=cause.getCause())if(cause instanceof TimeoutException)timedOut=true;
            assertTrue(timedOut,"The direct parser must expose its actual nested timeout type");
            var proof=ExecutionMetadata.prepare(snapshot,profile(Engine.POSTGRESQL),"owner",sql,context).proof(columns);
            assertFalse(proof.available());assertEquals(MetadataState.TIMED_OUT,proof.state(),proof.availability());
            assertFalse(proof.availability().contains(sql),"The fixed availability reason must not include SQL");
            assertFalse(Thread.currentThread().isInterrupted());
            try{
                Thread.currentThread().interrupt();
                var cancelled=ExecutionMetadata.prepare(snapshot,profile(Engine.POSTGRESQL),"owner",sql,context).proof(columns);
                assertFalse(cancelled.available());assertEquals(MetadataState.CANCELLED,cancelled.state(),cancelled.availability());
                assertTrue(Thread.currentThread().isInterrupted(),"The parser's interruption must remain set for its caller");
            }finally{Thread.interrupted();}
            int remaining=pool.getQueue().remainingCapacity();
            for(int index=0;index<remaining;index++)blockers.add(pool.submit(()->null));
            assertEquals(0,pool.getQueue().remainingCapacity(),"Only owned queued tasks fill the unchanged parser admission budget");
            var limited=ExecutionMetadata.prepare(snapshot,profile(Engine.POSTGRESQL),"owner",sql,context).proof(columns);
            assertFalse(limited.available());assertEquals(MetadataState.LIMITED,limited.state(),limited.availability());
            assertEquals(13,snapshot.revision());assertEquals("owner",snapshot.namespace(CATALOG,"pg_temp_7",ObjectKind.TABLE,"").getFirst().identity().sessionOwner());
        }finally{
            release.countDown();for(var blocker:blockers)blocker.get(10,TimeUnit.SECONDS);
        }
    }
    @Test void evidenceBudgetIncludesWholeCapturedContextBeforeAnyJdbc(){
        var snapshot=fixture(Engine.POSTGRESQL,false);var oversized=new JdbcAdapter.LiveContext(CATALOG,"public",List.of("public"),"","",true,"x".repeat(600_000),"UTC",true,"ISO, MDY");
        var proof=ExecutionMetadata.prepare(snapshot,profile(Engine.POSTGRESQL),"session","SELECT id FROM public.t",oversized).proof(List.of(selected(Engine.POSTGRESQL,"id",1)));
        assertEquals(MetadataState.LIMITED,proof.state());assertFalse(proof.available());
    }
    @Test void detachedNativeFingerprintMatchesExistingExactProjectionWithoutCopyingUnrelatedProperties(){
        var snapshot=fixture(Engine.POSTGRESQL,false);var base=snapshot.namespace(CATALOG,"public",ObjectKind.COLUMN,"t").getFirst();var properties=new HashMap<>(base.properties());properties.put("comment","x".repeat(65536));
        var richer=new MetadataObject(base.identity(),base.displayName(),base.quotedIdentifier(),base.lookupKey(),properties,"ignored source body",base.level(),base.state(),base.sourceRevision(),base.contextRevision());
        assertEquals(RetainedMetadataProof.columnFingerprint(richer.projection(11,3)),RetainedMetadataProof.columnFingerprint(richer));
    }
    @Test void completeColumnCoverageCannotUpgradeStaleNamesOnlyOrDeniedRawTable(){
        var original=fixture(Engine.POSTGRESQL,false);var table=original.resolve(CATALOG,"public",ObjectKind.TABLE,"","t",true).getFirst();
        for(var state:List.of(MetadataState.STALE,MetadataState.DENIED,MetadataState.AVAILABLE)){
            var entries=new ArrayList<>(original.identities().values());entries.remove(table);entries.add(new MetadataObject(table.identity(),table.displayName(),table.quotedIdentifier(),table.lookupKey(),table.properties(),table.source(),state==MetadataState.AVAILABLE?IntrospectionLevel.NAMES:IntrospectionLevel.STRUCTURE,state,1,1));
            var snapshot=new MetadataSnapshot(SOURCE,PROFILE,12,3,1,original.rules(),entries,original.catalogCoverage());
            var proof=ExecutionMetadata.prepare(snapshot,profile(Engine.POSTGRESQL),"session","SELECT id FROM public.t",context(Engine.POSTGRESQL)).proof(List.of(selected(Engine.POSTGRESQL,"id",1)));
            assertFalse(proof.available());assertEquals(state==MetadataState.AVAILABLE?MetadataState.NOT_REQUESTED:state,proof.state());
        }
    }
    @Test void missingStructuralCoverageAndNamesOnlyColumnsStayExplicitlyIncomplete(){
        var original=fixture(Engine.POSTGRESQL,false);var scope=new MetadataScope(CATALOG,"public","t",ObjectKind.COLUMN);var columns=List.of(selected(Engine.POSTGRESQL,"id",1));
        var coverage=new HashMap<>(original.catalogCoverage());coverage.remove(scope);
        var absent=new MetadataSnapshot(SOURCE,PROFILE,12,3,1,original.rules(),original.identities().values(),coverage);
        var missing=ExecutionMetadata.prepare(absent,profile(Engine.POSTGRESQL),"session","SELECT id FROM public.t",context(Engine.POSTGRESQL)).proof(columns);
        assertFalse(missing.available());assertEquals(MetadataState.PARTIAL,missing.state(),missing.availability());
        coverage.put(scope,new MetadataCoverage(scope,IntrospectionLevel.STRUCTURE,MetadataState.TIMED_OUT,false,"deadline",1,1,1,""));
        var timedOut=new MetadataSnapshot(SOURCE,PROFILE,13,3,1,original.rules(),original.identities().values(),coverage);
        var precise=ExecutionMetadata.prepare(timedOut,profile(Engine.POSTGRESQL),"session","SELECT id FROM public.t",context(Engine.POSTGRESQL)).proof(columns);
        assertFalse(precise.available());assertEquals(MetadataState.TIMED_OUT,precise.state(),precise.availability());
        var column=original.resolve(CATALOG,"public",ObjectKind.COLUMN,"t","id",true).getFirst();var entries=new ArrayList<>(original.identities().values());entries.remove(column);
        entries.add(new MetadataObject(column.identity(),column.displayName(),column.quotedIdentifier(),column.lookupKey(),column.properties(),column.source(),IntrospectionLevel.NAMES,MetadataState.AVAILABLE,1,1));
        var namesOnly=new MetadataSnapshot(SOURCE,PROFILE,14,3,1,original.rules(),entries,original.catalogCoverage());
        var unrequested=ExecutionMetadata.prepare(namesOnly,profile(Engine.POSTGRESQL),"session","SELECT id FROM public.t",context(Engine.POSTGRESQL)).proof(columns);
        assertFalse(unrequested.available());assertEquals(MetadataState.NOT_REQUESTED,unrequested.state(),unrequested.availability());
    }
    private static MetadataSnapshot renamed(Engine engine,int casePolicy,String catalog,String schema,String table){
        var original=fixture(engine,false);var rules=io.busystack.busydata.NativeCaseFixtures.rules(engine,casePolicy);var entries=new ArrayList<MetadataObject>();
        for(var value:original.identities().values()){var id=value.identity();var wire=value.projection(11,3).toBuilder().setCatalog(catalog).setSchema(schema).setName(id.kind()==ObjectKind.TABLE?table:id.name()).setTable(id.parent().isEmpty()?"":table).build();entries.add(MetadataObject.from(SOURCE,PROFILE,"",rules,wire,IntrospectionLevel.STRUCTURE,1,1));}
        var scope=new MetadataScope(catalog,schema,table,ObjectKind.COLUMN);return new MetadataSnapshot(SOURCE,PROFILE,11,3,1,rules,entries,Map.of(scope,new MetadataCoverage(scope,IntrospectionLevel.STRUCTURE,MetadataState.AVAILABLE,true,"complete",1,1,1,"")));
    }
    @Test void mysqlAndMariaDatabaseAndResultCaseFollowOnlyCapturedServerPolicy(){
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB))for(int mode=0;mode<=2;mode++){
            String catalog=mode==1?"db":"Db",table=mode==1?"table_t":"Table_T";var snapshot=renamed(engine,mode,catalog,catalog,table);var profile=profile(engine).toBuilder().setDatabase(catalog).build();var context=new JdbcAdapter.LiveContext(catalog,catalog,List.of(catalog),"","",true,"+00:00","UTC");
            var exact=selected(engine,"ID",7).toBuilder().setCatalog(catalog).setSchema(catalog).setTable(table).build();String exactSql="SELECT ID FROM `"+catalog+"`.`"+table+"`";
            assertAvailable(ExecutionMetadata.prepare(snapshot,profile,"session",exactSql,context).proof(List.of(exact)));
            var folded=exact.toBuilder().setCatalog("DB").setSchema("DB").setTable("TABLE_T").build();String variantSql="SELECT ID FROM `dB`.`tABLE_t`";
            var proof=ExecutionMetadata.prepare(snapshot,profile,"session",variantSql,context).proof(List.of(folded));
            assertEquals(mode!=0,proof.available(),engine+" case policy "+mode+" "+proof.state()+": "+proof.availability());
            assertEquals(mode!=0,RetainedMetadataProof.sourceRelation(snapshot,profile,"session",variantSql,context).isPresent());
            var captured=RetainedMetadataProof.capture(snapshot,List.of(folded),profile,"session",context);assertEquals(mode!=0,captured.available(),captured.state()+": "+captured.availability());
            if(mode!=0){assertEquals(catalog,proof.catalog());assertEquals(catalog,proof.schema());assertEquals(table,proof.table());assertEquals(Set.of(7),proof.columns().keySet());assertFalse(ExecutionMetadata.prepare(snapshot,profile,"session",variantSql,context).proof(List.of(folded.toBuilder().setCatalog("wrong").build())).available());}
        }
    }
    @Test void postgresUnquotedCatalogFoldsButQuotedCatalogAndSchemaRemainExact(){
        var snapshot=fixture(Engine.POSTGRESQL,false);var columns=List.of(selected(Engine.POSTGRESQL,"id",1));
        assertAvailable(ExecutionMetadata.prepare(snapshot,profile(Engine.POSTGRESQL),"session","SELECT id FROM DB.PUBLIC.T",context(Engine.POSTGRESQL)).proof(columns));
        for(String sql:List.of("SELECT id FROM \"DB\".public.t","SELECT id FROM db.\"PUBLIC\".t"))assertFalse(ExecutionMetadata.prepare(snapshot,profile(Engine.POSTGRESQL),"session",sql,context(Engine.POSTGRESQL)).proof(columns).available());
        var mixed=renamed(Engine.POSTGRESQL,0,"Db","Mixed","T");var profile=profile(Engine.POSTGRESQL).toBuilder().setDatabase("Db").build();var context=new JdbcAdapter.LiveContext("Db","Mixed",List.of("Mixed"),"");var mixedColumns=List.of(columns.getFirst().toBuilder().setCatalog("Db").setSchema("Mixed").setTable("T").build());
        assertAvailable(ExecutionMetadata.prepare(mixed,profile,"session","SELECT id FROM \"Db\".\"Mixed\".\"T\"",context).proof(mixedColumns));
        assertFalse(ExecutionMetadata.prepare(mixed,profile,"session","SELECT id FROM \"Db\".Mixed.\"T\"",context).proof(mixedColumns).available());
    }
    private static void assertDetached(Object value,IdentityHashMap<Object,Boolean> seen){
        if(value==null||value instanceof String||value instanceof Number||value instanceof Boolean||value instanceof Enum<?>||seen.put(value,Boolean.TRUE)!=null)return;
        assertFalse(value instanceof MetadataSnapshot||value instanceof MetadataObject||value instanceof SchemaObject||value instanceof MetadataIdentity,"Held evidence must never retain catalog ownership");
        if(value instanceof Map<?,?> map){map.forEach((key,item)->{assertDetached(key,seen);assertDetached(item,seen);});return;}
        if(value instanceof Collection<?> values){values.forEach(item->assertDetached(item,seen));return;}
        assertTrue(value.getClass().getName().startsWith("io.busystack.busydata."),"Unexpected retained object "+value.getClass());
        for(var field:value.getClass().getDeclaredFields())if(!Modifier.isStatic(field.getModifiers()))try{field.setAccessible(true);assertDetached(field.get(value),seen);}catch(ReflectiveOperationException inaccessible){throw new AssertionError(inaccessible);}
    }
}
