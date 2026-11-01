package io.busystack.busydata;

import io.busystack.busydata.analysis.*;
import io.busystack.busydata.analysis.language.ResolutionContext;
import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.Explorer;
import io.busystack.busydata.security.PrivateTemporaryFiles;
import io.busystack.busydata.sessions.SessionRegistry;
import java.lang.management.*;
import java.lang.reflect.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.security.MessageDigest;
import java.sql.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;

/** Large-cache resource regression, not a native catalog or desktop benchmark. */
public final class MetadataCacheRestartHeapProbe {
    private static final IdentifierRules RULES=new IdentifierRules(Engine.POSTGRESQL,0);
    private static final int OBJECTS=118000,WARMUP=5,MEASURED=20;
    private static final Set<String> JDBC_METHODS=Set.of("createStatement","prepareStatement","prepareCall","getMetaData");
    private static final String SQL="SELECT t.column_0, t.column_9 FROM namespace_0.table_0 t WHERE t.column_0 > :minimum ORDER BY t.column_9 LIMIT 100 OFFSET 5";
    private MetadataCacheRestartHeapProbe(){}
    private record Acquired(List<MetadataObject> objects,Map<MetadataScope,MetadataCoverage> coverage){}
    private static void require(boolean condition,String message){if(!condition)throw new AssertionError(message);}
    private static MetadataCoverage coverage(MetadataScope scope,long source,long context){return new MetadataCoverage(scope,IntrospectionLevel.STRUCTURE,MetadataState.AVAILABLE,true,"synthetic-cache-restart",source,context,1,"");}
    private static MetadataObject object(String source,Profile profile,ObjectKind kind,String schema,String parent,String name,String signature,Map<String,String> properties,long revision,long context){
        return MetadataObject.from(source,profile.getId(),"",RULES,SchemaObject.newBuilder().setCatalog(profile.getDatabase()).setSchema(schema).setTable(parent).setName(name).setKind(kind).setIdentifier(signature).putAllProperties(properties).build(),IntrospectionLevel.STRUCTURE,revision,context);
    }
    /** Same declared scale as the existing production-heap fixture. Build native
     * facts directly so reconciliation does not require a second full catalog. */
    private static Acquired acquire(Profile profile,long revision,long context){
        String source=io.busystack.busydata.metadata.SourceIdentity.fingerprint(profile);var objects=new ArrayList<MetadataObject>(OBJECTS);var coverage=new HashMap<MetadataScope,MetadataCoverage>();
        for(int n=0;n<10;n++)for(var kind:List.of(ObjectKind.TABLE,ObjectKind.VIEW,ObjectKind.SEQUENCE,ObjectKind.ROUTINE)){
            var scope=new MetadataScope(profile.getDatabase(),"namespace_"+n,"",kind);coverage.put(scope,coverage(scope,revision,context));
        }
        for(int table=0;table<10000;table++){
            String schema="namespace_"+(table/1000),name="table_"+(table%1000);
            objects.add(object(source,profile,ObjectKind.TABLE,schema,"",name,"",Map.of("nativeId",Integer.toString(table+1),"nativeGeneration",Integer.toString(table+1)),revision,context));
            var scope=new MetadataScope(profile.getDatabase(),schema,name,ObjectKind.COLUMN);coverage.put(scope,coverage(scope,revision,context));
            for(int column=0;column<10;column++)objects.add(object(source,profile,ObjectKind.COLUMN,schema,name,"column_"+column,"",Map.of("nativeType",column==9?"numeric(38,12)":"bigint","type",column==9?"numeric":"int8","jdbcType",column==9?"2":"-5","nativeTypeId",column==9?"1700":"20","ordinal",Integer.toString(column+1),"nullable","1","autoIncrement","NO","generated","NO"),revision,context));
        }
        for(int n=0;n<3000;n++)objects.add(object(source,profile,ObjectKind.CONSTRAINT,"namespace_"+(n/1000),"table_"+(n%1000),"pk_"+n,"",Map.of("type","PRIMARY KEY","column.0","column_0","columnCount","1"),revision,context));
        for(int n=0;n<2000;n++)objects.add(object(source,profile,ObjectKind.FOREIGN_KEY,"namespace_"+(n/1000),"table_"+(n%1000),"fk_"+n,"",Map.of("relationshipVerified","true","columnCount","1","column.0","column_0","referencedColumn.0","column_0","referencedCatalog",profile.getDatabase(),"referencedSchema","namespace_"+(n/1000),"referencedTable","table_"+((n+1)%1000)),revision,context));
        for(int n=0;n<3000;n++){
            String name="routine_"+(n%100),type="heap_type_"+(n/100),signature=name+"("+type+", integer)";
            objects.add(object(source,profile,ObjectKind.ROUTINE,"namespace_0","",name,signature,Map.of("signature",signature,"parameterCount","2","parameter.0.type",type,"parameter.1.type","integer","returnType","numeric","parameter.0.nativeTypeId",Integer.toString(20000+n/100),"parameter.1.nativeTypeId","23"),revision,context));
        }
        require(objects.size()==OBJECTS,"Synthetic scale changed");return new Acquired(objects,coverage);
    }
    /** The accepted branch already proved every exact fact against the seed.
     * An unchanged synthetic acquisition shares those native objects, matching
     * incremental publication instead of retaining two fixture-built catalogs. */
    private static Acquired unchanged(MetadataSnapshot accepted,long revision,long context){
        var states=new HashMap<MetadataScope,MetadataCoverage>();for(var scope:accepted.catalogCoverage().keySet())states.put(scope,coverage(scope,revision,context));
        return new Acquired(List.copyOf(accepted.identities().values()),states);
    }
    private static MetadataSnapshot snapshot(Profile profile,Acquired acquired){return new MetadataSnapshot(io.busystack.busydata.metadata.SourceIdentity.fingerprint(profile),profile.getId(),1,1,1,RULES,acquired.objects(),acquired.coverage());}
    private static Map<MetadataScope,MetadataPlatform.Branch> branches(Profile profile,Acquired acquired,long revision,long context){
        var grouped=new EnumMap<ObjectKind,List<MetadataObject>>(ObjectKind.class);for(var object:acquired.objects())grouped.computeIfAbsent(object.identity().kind(),ignored->new ArrayList<>()).add(object);
        var branches=new LinkedHashMap<MetadataScope,MetadataPlatform.Branch>();
        for(var entry:grouped.entrySet()){
            var scope=new MetadataScope(profile.getDatabase(),"","",entry.getKey());branches.put(scope,new MetadataPlatform.Branch(List.of(),coverage(scope,revision,context),entry.getValue(),false));
        }
        // All facts in these structural branches were just acquired above. Reuse
        // adds their exact coverage without projecting a second protobuf model.
        for(var entry:acquired.coverage().entrySet())branches.put(entry.getKey(),MetadataPlatform.Branch.reused(entry.getValue()));
        return branches;
    }
    private static void model(MetadataSnapshot snapshot,Profile profile){
        require(snapshot.identities().size()==OBJECTS,"Partial model was accepted");String source=io.busystack.busydata.metadata.SourceIdentity.fingerprint(profile);var counts=new EnumMap<ObjectKind,Long>(ObjectKind.class);
        for(var object:snapshot.identities().values()){
            counts.merge(object.identity().kind(),1L,Long::sum);require(object.identity().source().equals(source)&&object.identity().profileId().equals(profile.getId())&&object.identity().sessionOwner().isEmpty(),"Wrong source/physical owner");
            if(object.identity().kind()==ObjectKind.TABLE)require(snapshot.catalogCoverage().containsKey(new MetadataScope(profile.getDatabase(),object.identity().schema(),object.identity().name(),ObjectKind.COLUMN)),"A relation lost structural coverage");
        }
        require(counts.equals(Map.of(ObjectKind.TABLE,10000L,ObjectKind.COLUMN,100000L,ObjectKind.CONSTRAINT,3000L,ObjectKind.FOREIGN_KEY,2000L,ObjectKind.ROUTINE,3000L)),"Wrong object kinds/counts");
        for(int namespace=0;namespace<10;namespace++){
            require(snapshot.resolve(profile.getDatabase(),"namespace_"+namespace,ObjectKind.TABLE,"","table_0",true).size()==1,"Duplicate namespace table identity was lost");
            var columns=snapshot.resolve(profile.getDatabase(),"namespace_"+namespace,ObjectKind.COLUMN,"table_0","column_9",true);require(columns.size()==1&&"numeric(38,12)".equals(columns.getFirst().properties().get("nativeType")),"Exact native column was lost");
        }
        require(snapshot.resolve(profile.getDatabase(),"namespace_0",ObjectKind.ROUTINE,"","routine_0",true).size()==30,"Routine signature identities were lost");
    }
    private static void part(MessageDigest digest,String value){byte[] bytes=value.getBytes(StandardCharsets.UTF_8);digest.update((byte)(bytes.length>>>24));digest.update((byte)(bytes.length>>>16));digest.update((byte)(bytes.length>>>8));digest.update((byte)bytes.length);digest.update(bytes);}
    /** Order-independent digest of every native object and exact property. */
    private static String modelDigest(MetadataSnapshot snapshot)throws Exception {
        byte[] sum=new byte[32];var sha=MessageDigest.getInstance("SHA-256");
        for(var object:snapshot.identities().values()){
            sha.reset();var identity=object.identity();for(String component:List.of(identity.key(),identity.source(),identity.profileId(),identity.catalog(),identity.schema(),identity.kind().name(),identity.subtype().name(),identity.parent(),identity.name(),identity.signature(),identity.sessionOwner(),identity.nativeKey()))part(sha,component);part(sha,object.displayName());part(sha,object.quotedIdentifier());part(sha,object.lookupKey());part(sha,object.source());part(sha,object.level().name());part(sha,object.state().name());part(sha,Long.toString(object.sourceRevision()));part(sha,Long.toString(object.contextRevision()));
            for(var property:new TreeMap<>(object.properties()).entrySet()){part(sha,property.getKey());part(sha,property.getValue());}
            byte[] value=sha.digest();int carry=0;for(int n=31;n>=0;n--){int v=(sum[n]&255)+(value[n]&255)+carry;sum[n]=(byte)v;carry=v>>>8;}
        }
        return HexFormat.of().formatHex(sum);
    }
    private static Map<String,Object> persisted(Path cache)throws Exception {
        var evidence=new LinkedHashMap<String,Object>();var sha=MessageDigest.getInstance("SHA-256");long count=0;
        try(var db=DriverManager.getConnection("jdbc:sqlite:"+cache.resolve("metadata_catalog.sqlite"));var statement=db.createStatement()){
            for(String table:List.of("object","property")){
                try(var rows=statement.executeQuery("SELECT * FROM "+table+" ORDER BY source,identity"+(table.equals("property")?",name":""))){int columns=rows.getMetaData().getColumnCount();while(rows.next()){for(int c=1;c<=columns;c++)part(sha,Objects.toString(rows.getString(c),""));count++;}}
                evidence.put(table+"Count",count);count=0;
            }
            try(var rows=statement.executeQuery("SELECT COUNT(*) FROM coverage")){require(rows.next(),"Coverage count unavailable");evidence.put("coverageCount",rows.getLong(1));}
            var coverageDigest=MessageDigest.getInstance("SHA-256");var rowDigest=MessageDigest.getInstance("SHA-256");byte[] coverageContent=new byte[32];
            try(var rows=statement.executeQuery("SELECT * FROM coverage ORDER BY source,identity")){
                int columns=rows.getMetaData().getColumnCount();require(columns==19,"Persisted coverage shape changed");
                while(rows.next()){rowDigest.reset();for(int c=1;c<=columns;c++){String value=Objects.toString(rows.getString(c),"");part(coverageDigest,value);part(rowDigest,value);}sumDigest(coverageContent,rowDigest.digest());}
            }
            evidence.put("coverageSha256",HexFormat.of().formatHex(coverageDigest.digest()));evidence.put("coverageContentSha256",HexFormat.of().formatHex(coverageContent));
            var headers=new ArrayList<Map<String,Object>>();
            try(var rows=statement.executeQuery("SELECT source,profile,revision,configuration_revision,created,engine,case_rule,identifier_rules FROM publication ORDER BY source LIMIT 9")){
                while(rows.next())headers.add(Map.of("source",rows.getString(1),"profile",rows.getString(2),"revision",rows.getLong(3),"configurationRevision",rows.getLong(4),"created",rows.getLong(5),"engine",rows.getInt(6),"caseRule",rows.getInt(7),"rulesSha256",HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(rows.getBytes(8)))));
            }
            evidence.put("headers",headers);
            try(var rows=statement.executeQuery("SELECT COALESCE((SELECT SUM(1024+4*(length(display_name)+length(quoted_name)+length(lookup_key)+length(source_text)+length(catalog)+length(schema_name)+length(parent)+length(name)+length(signature))) FROM object),0)+COALESCE((SELECT SUM(128+4*(length(name)+length(value))) FROM property),0)")){
                require(rows.next(),"Restore estimate unavailable");evidence.put("restorePreflightEstimateExcludingRulesBytes",rows.getLong(1));
            }
        }
        require(((Number)evidence.get("objectCount")).longValue()==OBJECTS,"Persisted result was partial");evidence.put("objectAndPropertySha256",HexFormat.of().formatHex(sha.digest()));return evidence;
    }
    private static void sumDigest(byte[] sum,byte[] value){int carry=0;for(int n=31;n>=0;n--){int v=(sum[n]&255)+(value[n]&255)+carry;sum[n]=(byte)v;carry=v>>>8;}}
    /** Independent row projection from the fresh in-memory contract. Constant
     * working storage avoids sorting/copying the complete coverage map. */
    private static Map<String,Object> coverageProof(MetadataSnapshot snapshot)throws Exception{
        var digest=MessageDigest.getInstance("SHA-256");byte[] sum=new byte[32];long count=0;
        for(var entry:snapshot.catalogCoverage().entrySet()){
            var scope=entry.getKey();var coverage=entry.getValue();require(scope.equals(coverage.scope()),"Coverage owner does not match its exact scope identity");digest.reset();
            for(String field:List.of(snapshot.source(),scope.key(),scope.catalog(),scope.schema(),scope.parent(),Integer.toString(scope.kind().getNumber()),scope.search(),scope.exactName()?"1":"0",scope.signature(),Integer.toString(scope.subtype().getNumber()),Integer.toString(coverage.level().number()),coverage.state().name(),coverage.complete()?"1":"0",coverage.fingerprint(),Long.toString(coverage.sourceRevision()),Long.toString(coverage.contextRevision()),Long.toString(coverage.refreshedUnixMs()),coverage.limitation(),coverage.defaultNamespace()))part(digest,field);
            sumDigest(sum,digest.digest());count++;
        }
        return Map.of("count",count,"sha256",HexFormat.of().formatHex(sum));
    }
    private static long gcCount(){return ManagementFactory.getGarbageCollectorMXBeans().stream().mapToLong(value->Math.max(0,value.getCollectionCount())).sum();}
    private static long gcMillis(){return ManagementFactory.getGarbageCollectorMXBeans().stream().mapToLong(value->Math.max(0,value.getCollectionTime())).sum();}
    private static MetadataSettingsReply settings(Explorer explorer,SessionRegistry.Session session)throws Exception {
        return MetadataRpc.run(explorer,session,MetadataSettingsRequest.newBuilder().setSessionId(session.id).setSessionRevision(session.revision).setContextRevision(session.contextRevision).setAction(MetadataSettingsAction.READ_METADATA_SETTINGS).setLimit(1).build());
    }
    private static void warm(MetadataSnapshot snapshot,Profile profile,SessionRegistry.Session session,AtomicInteger jdbc,AtomicInteger connections,Map<String,Object> report)throws Exception {
        var context=new ResolutionContext(profile.getDatabase(),"namespace_0",List.of("namespace_0"),true,snapshot.revision(),snapshot.configurationRevision(),snapshot.rules(),snapshot);
        var service=new SqlAnalysis();var request=AnalysisRequest.newBuilder().setEngine(Engine.POSTGRESQL).setDocumentId("cache-restart").setDocumentVersion(1).setSql(SQL).setCaretUtf16(SQL.indexOf("column_9")+6).setOperation(AnalysisOperation.COMPLETION).build();
        String call="SELECT namespace_0.routine_0(1, 2)";var parameter=request.toBuilder().setSql(call).setCaretUtf16(call.length()-1).setOperation(AnalysisOperation.PARAMETER_INFORMATION).build();
        int beforeConnections=connections.get(),beforeJdbc=jdbc.get();var times=new EnumMap<AnalysisOperation,List<Long>>(AnalysisOperation.class);var warmups=new ArrayList<Map<String,Object>>();report.put("warmups",warmups);
        for(var operation:List.of(request,parameter)){
            var samples=new ArrayList<Long>();for(int n=0;n<WARMUP+MEASURED;n++){
                long start=System.nanoTime();var result=service.analyze(operation,session.context.lexical(),context);long elapsed=System.nanoTime()-start;
                if(n<WARMUP)warmups.add(Map.of("operation",operation.getOperation().name(),"iteration",n,"elapsedMs",elapsed/1_000_000.0,"availability",result.getAvailability(),"diagnostics",result.getDiagnosticsList().stream().map(Diagnostic::getCode).toList()));
                if(n>=WARMUP-1){require(result.getAvailability().equals("available"),"Warm analysis was incomplete");if(operation.getOperation()==AnalysisOperation.COMPLETION)require(result.getCompletionsList().stream().anyMatch(value->value.getLabel().equals("column_9")),"Completion lost the exact field");else require(result.getParameterInformation().getAvailability().equals("available")&&result.getParameterInformation().getOverloadsCount()==30,"Parameter signatures were incomplete");if(n>=WARMUP)samples.add(elapsed);}
            }
            Collections.sort(samples);double p95=samples.get(18)/1_000_000.0;require(p95<=250,"Warm analysis exceeded250ms");times.put(operation.getOperation(),samples);report.put(operation.getOperation().name().toLowerCase(Locale.ROOT)+"P95Ms",p95);
        }
        report.put("warmAnalysisJdbcCalls",jdbc.get()-beforeJdbc);report.put("warmAnalysisNewConnections",connections.get()-beforeConnections);require(jdbc.get()==beforeJdbc&&connections.get()==beforeConnections,"Warm analysis performed native JDBC work");
        report.put("warmupIterations",WARMUP);report.put("measuredIterations",MEASURED);report.put("languageNanos",times);
    }
    private static void seed(Path root,Profile profile,Map<String,Object> report)throws Exception {
        require(Runtime.getRuntime().maxMemory()<=256L*1024*1024,"Seed heap was not bounded");Path cache=root.resolve("cache");var repository=new MetadataRepository(cache);var value=snapshot(profile,acquire(profile,0,1));model(value,profile);report.put("modelSha256",modelDigest(value));report.put("snapshotEstimatedBytes",value.estimatedBytes());
        var seeded=repository.publish(value,MetadataSnapshot.empty(value.source(),value.profileId(),RULES));report.put("seedWriteMetrics",seeded.await(System.nanoTime()+TimeUnit.SECONDS.toNanos(120)));require(repository.cacheState().equals("AVAILABLE"),"Seed publication failed");report.put("persisted",persisted(cache));
    }
    private static void restart(Path root,Profile profile,Map<String,Object> report)throws Exception {
        report.put("cachePersistenceAcceptance",false);
        require(Runtime.getRuntime().maxMemory()<=128L*1024*1024,"Restart must use the unchanged production heap");var seed=com.google.gson.JsonParser.parseString(Files.readString(root.resolve("seed.json"))).getAsJsonObject();
        var jdbc=new AtomicInteger();var connections=new AtomicInteger();Thread owner=Thread.currentThread();
        try(var files=new PrivateTemporaryFiles(root.resolve("private"));var sessions=new SessionRegistry(files,(adapter,request,port)->{
            connections.incrementAndGet();var connection=adapter.connect(request,port);return (Connection)Proxy.newProxyInstance(Connection.class.getClassLoader(),new Class[]{Connection.class},(proxy,method,args)->{if(Thread.currentThread()==owner&&JDBC_METHODS.contains(method.getName()))jdbc.incrementAndGet();try{return method.invoke(connection,args);}catch(InvocationTargetException error){throw error.getCause();}});
        })){
            var session=sessions.open(OpenRequest.newBuilder().setProfile(profile).setPassword("fixture").build());var platform=new MetadataPlatform(root.resolve("cache"));var explorer=new Explorer(platform);var before=platform.capture(session);var initial=settings(explorer,session);
            report.put("restartCacheState",initial.getCacheState());report.put("restartSnapshotObjects",before.identities().size());report.put("restartSnapshotRevision",before.revision());report.put("restartExposedScopes",initial.getScopesCount());
            if(before.identities().isEmpty()){
                require(Set.of("UNAVAILABLE","LIMITED").contains(initial.getCacheState())&&initial.getScopesCount()==0,"Rejected cache was advertised as a complete empty catalog");
                require(before.coverage().isEmpty()&&before.revision()==0,"Rejected cache exposed partial coverage");
            }else{
                model(before,profile);require(before.coverage().size()==seed.getAsJsonObject("persisted").get("coverageCount").getAsInt(),"Restored coverage was partial");require(modelDigest(before).equals(seed.get("modelSha256").getAsString()),"Restored native model changed");require(before.coverage().values().stream().allMatch(value->value.state()==MetadataState.STALE&&!value.complete()),"Restart promoted cached evidence to freshness");require(initial.getCacheState().equals("PARTIAL_OR_STALE"),"Restored cache staleness was hidden");
            }
            report.put("explicitRestartAvailability",true);
            var diskBefore=persisted(root.resolve("cache"));require(diskBefore.get("objectAndPropertySha256").equals(seed.getAsJsonObject("persisted").get("objectAndPropertySha256").getAsString()),"Restart modified durable cache content");report.put("persistedBeforeReconciliation",diskBefore);
            long began=System.nanoTime(),gcBefore=gcCount(),gcTimeBefore=gcMillis();
            var acquired=before.identities().isEmpty()?acquire(profile,session.revision,session.contextRevision):unchanged(before,session.revision,session.contextRevision);long acquiredAt=System.nanoTime();
            var acquiredBranches=branches(profile,acquired,session.revision,session.contextRevision);long groupedAt=System.nanoTime();
            var value=platform.publish(session,platform.beginRefresh(session),RULES,acquiredBranches,false);long publishedAt=System.nanoTime(),callerGcCount=gcCount(),callerGcMs=gcMillis();
            report.put("callerPublicationMs",(publishedAt-groupedAt)/1_000_000.0);report.put("callerCacheState",platform.cacheState(session));
            var receipt=platform.cacheWriteReceipt(session).orElseThrow();report.put("cacheWriteIdentity",receipt.identity());long terminalWait=System.nanoTime();
            var completion=receipt.awaitCompletion(System.nanoTime()+TimeUnit.SECONDS.toNanos(60));report.put("eventualCacheCompletionWaitMs",(System.nanoTime()-terminalWait)/1_000_000.0);report.put("cacheCommitOutcome",completion.metrics().commitOutcome().name());report.put("cacheFailureFacts",completion.failure());report.put("cacheNativeOwnershipActive",receipt.active());
            var cacheMetrics=platform.cacheWriteMetrics(session);report.put("cacheWriteMetricsAvailable",cacheMetrics.isPresent());cacheMetrics.ifPresent(metrics->report.put("cacheWriteMetrics",metrics));
            require(!receipt.active(),"Native cache closure remains uncertain; no further cache operation is admitted");
            require(cacheMetrics.isPresent()&&cacheMetrics.orElseThrow().matches(value),"Cache phase metrics do not belong to this exact published source and revision");
            report.put("reconciliationMs",(publishedAt-began)/1_000_000.0);report.put("acquisitionMs",(acquiredAt-began)/1_000_000.0);report.put("branchPreparationMs",(groupedAt-acquiredAt)/1_000_000.0);report.put("publicationMs",(publishedAt-groupedAt)/1_000_000.0);report.put("cacheWriteMs",platform.cacheWriteNanos(session)/1_000_000.0);report.put("reconciliationGcCount",callerGcCount-gcBefore);report.put("reconciliationGcMs",callerGcMs-gcTimeBefore);report.put("eventualCacheGcCount",gcCount()-callerGcCount);report.put("eventualCacheGcMs",gcMillis()-callerGcMs);
            report.put("reconciledSnapshotRevision",value.revision());report.put("reconciledObjectCount",value.identities().size());report.put("reconciledCoverageStates",value.coverage().values().stream().map(state->state.state().name()+":"+state.complete()).distinct().sorted().toList());
            var visible=settings(explorer,session);report.put("reconciledCacheState",visible.getCacheState());report.put("visibleSnapshotRevision",visible.getSnapshotRevision());report.put("visibleConfigurationRevision",visible.getConfigurationRevision());report.put("visibleScopeStates",visible.getScopesList().stream().map(state->state.getState()+":"+state.getComplete()).toList());
            platform.cacheFailure(session).ifPresent(failure->report.put("cacheFailure",Map.of("reason",failure.reason().name(),"sqlState",failure.sqlState(),"vendorCode",failure.vendorCode())));
            var expectedCoverage=coverageProof(value);report.put("expectedFreshCoverage",expectedCoverage);
            var after=persisted(root.resolve("cache"));report.put("persistedAfterReconciliation",after);
            var expectedHeader=Map.of("source",value.source(),"profile",value.profileId(),"revision",value.revision(),"configurationRevision",value.configurationRevision(),"created",value.createdUnixMs(),"engine",value.rules().engine().getNumber(),"caseRule",value.rules().lowerCaseTableNames(),"rulesSha256",HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(value.rules().encode())));report.put("expectedFreshHeader",expectedHeader);
            boolean stored=visible.getCacheState().equals("AVAILABLE");
            model(value,profile);require(value.coverage().values().stream().allMatch(state->state.state()==MetadataState.AVAILABLE&&state.complete()),"Reconciliation left stale or incomplete structural coverage");require(modelDigest(value).equals(seed.get("modelSha256").getAsString()),"Reconciled model changed exact native facts");report.put("reconciledModelExact",true);require(value.revision()>before.revision(),"Reconciliation did not advance revision");
            require(visible.getSnapshotRevision()==value.revision()&&visible.getConfigurationRevision()==value.configurationRevision(),"Fresh metadata revision was not available to the same protocol owner");
            require(visible.getSessionId().equals(session.id)&&visible.getProfileId().equals(session.profile.getId())&&visible.getSessionRevision()==session.revision&&visible.getContextRevision()==session.contextRevision,"Metadata settings changed the physical owner");
            require(visible.getScopesCount()>0&&visible.getScopesList().stream().allMatch(state->state.getState().equals("AVAILABLE")&&state.getComplete()),"Fresh metadata scope availability was lost");
            require(Set.of("AVAILABLE","WRITE_UNAVAILABLE").contains(visible.getCacheState()),"Completed cache attempt did not have an explicit terminal state");
            require(after.get("objectAndPropertySha256").equals(diskBefore.get("objectAndPropertySha256")),"Reconciliation changed persisted facts or silently omitted objects");report.put("persistedRowsExact",true);
            if(stored){
                require(platform.cacheFailure(session).isEmpty(),"Successful persistence retained a failed attempt diagnostic");
                @SuppressWarnings("unchecked") var headers=(List<Map<String,Object>>)after.get("headers");
                require(headers.size()==1&&headers.getFirst().equals(expectedHeader),"Successful cache publication did not store its exact header");
                require(after.get("coverageCount").equals(expectedCoverage.get("count"))&&after.get("coverageContentSha256").equals(expectedCoverage.get("sha256")),"Successful cache publication did not store the fresh model's complete exact coverage");
                report.put("persistedFreshCoverageExact",true);report.put("cachePersistenceAcceptance",true);
            }else{
                require(platform.cacheFailure(session).isPresent(),"Cache failure did not retain a structured reason");
                if(completion.metrics().commitOutcome()==MetadataRepository.CommitOutcome.NOT_ATTEMPTED){require(after.equals(diskBefore),"An uncommitted cache attempt changed its prior exact atomic generation");report.put("priorCacheTransactionPreserved",true);}
                else{
                    @SuppressWarnings("unchecked") var headers=(List<Map<String,Object>>)after.get("headers");
                    boolean exactNew=headers.size()==1&&headers.getFirst().equals(expectedHeader)&&after.get("coverageCount").equals(expectedCoverage.get("count"))&&after.get("coverageContentSha256").equals(expectedCoverage.get("sha256"));
                    require(after.equals(diskBefore)||exactNew,"A terminal failure exposed neither the exact old nor exact new atomic cache generation");report.put("terminalFailureAtomicGeneration",exactNew?"EXACT_NEW":"EXACT_OLD");report.put("priorCacheTransactionPreserved",after.equals(diskBefore));
                }
            }
            warm(value,profile,session,jdbc,connections,report);
        }
    }
    public static void main(String[] args)throws Exception {
        Path root=Path.of(args[0]);String mode=args[1];require(Set.of("seed","restart").contains(mode),"Unknown cache workload");
        var report=new LinkedHashMap<String,Object>();report.put("mode",mode);report.put("scope","Synthetic catalog; real normalized SQLite, production Platform/MetadataRpc and genuine PostgreSQL physical owner; not native catalog or desktop acceptance");report.put("nativeCatalogAcceptance",false);report.put("fixtureObjects",OBJECTS);report.put("relations",10000);report.put("columns",100000);report.put("constraints",3000);report.put("foreignKeys",2000);report.put("routineSignatures",3000);report.put("java",System.getProperty("java.runtime.version"));report.put("vmArguments",ManagementFactory.getRuntimeMXBean().getInputArguments());report.put("os",System.getProperty("os.name")+" "+System.getProperty("os.version")+" "+System.getProperty("os.arch"));report.put("processors",Runtime.getRuntime().availableProcessors());report.put("maxHeapBytes",Runtime.getRuntime().maxMemory());
        var peak=new AtomicLong();var sampler=Executors.newSingleThreadScheduledExecutor();sampler.scheduleAtFixedRate(()->peak.accumulateAndGet(ManagementFactory.getMemoryMXBean().getHeapMemoryUsage().getUsed(),Math::max),0,10,TimeUnit.MILLISECONDS);Throwable failure=null;
        try{Path profileFile=root.resolve("profile.pb");require(Files.size(profileFile)<=65536,"Oversized test profile");var profile=Profile.parseFrom(Files.readAllBytes(profileFile));require(profile.getEngine()==Engine.POSTGRESQL,"Wrong physical test owner");if(mode.equals("seed"))seed(root,profile,report);else restart(root,profile,report);report.put("status","passed");}
        catch(Throwable problem){failure=problem;report.put("status","failed");report.put("failureType",problem.getClass().getName());report.put("failureFrames",Arrays.stream(problem.getStackTrace()).limit(16).map(frame->Map.of("class",frame.getClassName(),"method",frame.getMethodName(),"line",frame.getLineNumber())).toList());}
        finally{sampler.shutdownNow();report.put("peakUsedHeapBytes",peak.get());report.put("heapPoolPeakUsageSumBytes",ManagementFactory.getMemoryPoolMXBeans().stream().filter(value->value.getType()==MemoryType.HEAP).mapToLong(value->value.getPeakUsage().getUsed()).sum());if(Files.isRegularFile(Path.of("/proc/self/status")))for(String line:Files.readAllLines(Path.of("/proc/self/status")))if(line.startsWith("VmHWM:"))report.put("peakRssKiB",Long.parseLong(line.replaceAll("[^0-9]","")));Files.writeString(root.resolve(mode+".json"),new com.google.gson.GsonBuilder().setPrettyPrinting().create().toJson(report)+"\n");}
        if(failure!=null){failure.printStackTrace();System.exit(1);}
    }
}
