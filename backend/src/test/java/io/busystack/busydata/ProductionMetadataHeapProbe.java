package io.busystack.busydata;

import io.busystack.busydata.analysis.*;
import io.busystack.busydata.analysis.language.*;
import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import java.lang.management.ManagementFactory;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;

/** Child-process gate using the shipped client compiler, heap and collector, without JDBC. */
public final class ProductionMetadataHeapProbe {
    private static final String SOURCE="production-heap-fixture",PROFILE="fixture",CATALOG="fixture";
    private static final IdentifierRules RULES=new IdentifierRules(Engine.POSTGRESQL,0);
    private static final String SQL="SELECT t.column_0, t.column_9 FROM namespace_0.table_0 t WHERE t.column_0 > :minimum ORDER BY t.column_9 LIMIT 100 OFFSET 5";
    private static final int WARMUP=5,MEASURED=20;
    private ProductionMetadataHeapProbe(){}
    public static void main(String[] args)throws Exception {
        Path evidence=Path.of(args[0]);String workload=args.length>1?args[1]:"language";var report=new LinkedHashMap<String,Object>();
        if(!Set.of("language","atomic-publication","allocation-pressure").contains(workload))throw new IllegalArgumentException("Unknown heap workload");report.put("workload",workload);
        report.put("java",System.getProperty("java.runtime.version"));report.put("vm",System.getProperty("java.vm.name"));
        report.put("vmArguments",ManagementFactory.getRuntimeMXBean().getInputArguments());
        var vm=ManagementFactory.getPlatformMXBean(com.sun.management.HotSpotDiagnosticMXBean.class);
        var compilerPolicy=new LinkedHashMap<String,String>();
        for(String option:List.of("NeverActAsServerClassMachine","CICompilerCount","ReservedCodeCacheSize"))compilerPolicy.put(option,vm.getVMOption(option).getValue());
        report.put("compilerPolicy",compilerPolicy);
        if(!compilerPolicy.equals(Map.of("NeverActAsServerClassMachine","true","CICompilerCount","1","ReservedCodeCacheSize","33554432")))throw new IllegalStateException("Heap probe did not use the shipped client compiler policy");
        report.put("os",System.getProperty("os.name")+" "+System.getProperty("os.version")+" "+System.getProperty("os.arch"));
        report.put("processors",Runtime.getRuntime().availableProcessors());report.put("maxHeapBytes",Runtime.getRuntime().maxMemory());
        report.put("documentUtf16Units",SQL.length());report.put("relations",10000);report.put("columns",100000);report.put("constraints",3000);report.put("foreignKeys",2000);report.put("routineSignatures",3000);
        report.put("warmupIterations",WARMUP);report.put("measuredIterations",MEASURED);report.put("concurrentOperations",4);
        var heapPeak=new java.util.concurrent.atomic.AtomicLong();var sampler=Executors.newSingleThreadScheduledExecutor();sampler.scheduleAtFixedRate(()->heapPeak.accumulateAndGet(ManagementFactory.getMemoryMXBean().getHeapMemoryUsage().getUsed(),Math::max),0,10,TimeUnit.MILLISECONDS);
        String phase="normalized-snapshot-construction";Throwable failure=null;
        try {
            System.out.println(phase);var snapshot=fixture();report.put("snapshotEstimatedBytes",snapshot.estimatedBytes());report.put("snapshotObjects",snapshot.identities().size());
            report.put("heapAfterSnapshotBytes",usedHeap());
            phase="retained-allocation-pressure";byte[] pressure=workload.equals("allocation-pressure")?new byte[32*1024*1024]:null;if(pressure!=null){Arrays.fill(pressure,(byte)17);report.put("retainedAllocationPressureBytes",pressure.length);}
            phase="warm-analysis";System.out.println(phase);var context=new ResolutionContext(CATALOG,"namespace_0",List.of("namespace_0"),true,snapshot.revision(),snapshot.configurationRevision(),RULES,snapshot);
            var service=new SqlAnalysis();var base=AnalysisRequest.newBuilder().setEngine(Engine.POSTGRESQL).setDocumentId("production-heap").setDocumentVersion(1).setSql(SQL).setCaretUtf16(SQL.indexOf("column_9")+6).build();
            var requests=List.of(base.toBuilder().setOperation(AnalysisOperation.COMPLETION).build(),base.toBuilder().setOperation(AnalysisOperation.DIAGNOSTICS).build(),base.toBuilder().setOperation(AnalysisOperation.PARAMETER_INFORMATION).setSql("SELECT routine_0(1, 2)").setCaretUtf16(21).build(),base.toBuilder().setOperation(AnalysisOperation.FORMAT).build());
            var warmup=new ArrayList<Map<String,Object>>();report.put("warmup",warmup);
            for(int i=0;i<WARMUP;i++)for(var request:requests){long began=System.nanoTime();var result=service.analyze(request,LexicalSettings.DEFAULT,context);warmup.add(Map.of("iteration",i,"operation",request.getOperation().name(),"elapsedMs",(System.nanoTime()-began)/1_000_000.0,"availability",result.getAvailability(),"diagnostics",result.getDiagnosticsList().stream().map(Diagnostic::getCode).toList()));if(i==WARMUP-1)validate(result,request.getOperation(),System.nanoTime()-began);}
            phase=workload.equals("atomic-publication")?"atomic-publication-with-four-readers":"four-concurrent-operations";System.out.println(phase);var samples=new ConcurrentHashMap<AnalysisOperation,List<Long>>();var afterPublication=new ConcurrentHashMap<AnalysisOperation,Double>();var publicationDone=new CountDownLatch(workload.equals("atomic-publication")?1:0);MetadataSnapshot next=null;
            try(var workers=Executors.newFixedThreadPool(4)){
                var ready=new CountDownLatch(4);var begin=new CountDownLatch(1);var tasks=new ArrayList<Future<?>>();
                for(var request:requests)tasks.add(workers.submit(()->{ready.countDown();begin.await();var times=new ArrayList<Long>();for(int i=0;i<MEASURED;i++){long start=System.nanoTime();var result=service.analyze(request,LexicalSettings.DEFAULT,context);times.add(System.nanoTime()-start);validate(result,request.getOperation(),System.nanoTime()-start);}samples.put(request.getOperation(),times);if(!publicationDone.await(60,TimeUnit.SECONDS))throw new IllegalStateException("Snapshot publication exceeded60s");if(workload.equals("atomic-publication")){long began=System.nanoTime();var result=service.analyze(request,LexicalSettings.DEFAULT,context);validate(result,request.getOperation(),System.nanoTime()-began);if(result.getMetadataSnapshotRevision()!=snapshot.revision())throw new IllegalStateException("A reader observed a mixed snapshot revision");afterPublication.put(request.getOperation(),(System.nanoTime()-began)/1_000_000.0);}return null;}));
                if(!ready.await(5,TimeUnit.SECONDS))throw new IllegalStateException("Analysis workers did not become ready");report.put("measurementStartedJvmUptimeMs",ManagementFactory.getRuntimeMXBean().getUptime());begin.countDown();
                try{if(workload.equals("atomic-publication")){report.put("publicationStartedJvmUptimeMs",ManagementFactory.getRuntimeMXBean().getUptime());long began=System.nanoTime();next=new MetadataSnapshot(SOURCE,PROFILE,2,1,System.currentTimeMillis(),RULES,snapshot.identities().values(),snapshot.coverage());report.put("publicationBuildMs",(System.nanoTime()-began)/1_000_000.0);report.put("nextSnapshotObjects",next.identities().size());report.put("heapWithBothSnapshotsBytes",usedHeap());report.put("publicationFinishedJvmUptimeMs",ManagementFactory.getRuntimeMXBean().getUptime());}}finally{publicationDone.countDown();}
                for(var task:tasks)task.get(60,TimeUnit.SECONDS);report.put("measurementFinishedJvmUptimeMs",ManagementFactory.getRuntimeMXBean().getUptime());
            }
            for(var entry:samples.entrySet()){double p95=p95(entry.getValue());report.put(entry.getKey().name().toLowerCase(Locale.ROOT)+"P95Ms",p95);report.put(entry.getKey().name().toLowerCase(Locale.ROOT)+"MaximumMs",Collections.max(entry.getValue())/1_000_000.0);report.put(entry.getKey().name().toLowerCase(Locale.ROOT)+"Nanos",entry.getValue());if(p95>(entry.getKey()==AnalysisOperation.COMPLETION||entry.getKey()==AnalysisOperation.PARAMETER_INFORMATION?250:750))throw new IllegalStateException(entry.getKey()+" latency budget exceeded: "+p95+"ms");}
            for(var entry:afterPublication.entrySet()){report.put(entry.getKey().name().toLowerCase(Locale.ROOT)+"AfterPublicationMs",entry.getValue());if(entry.getValue()>(entry.getKey()==AnalysisOperation.COMPLETION||entry.getKey()==AnalysisOperation.PARAMETER_INFORMATION?250:750))throw new IllegalStateException(entry.getKey()+" post-publication latency budget exceeded");}
            if(next!=null&&next.revision()<=snapshot.revision())throw new IllegalStateException("Publication did not preserve old and new immutable revisions");if(pressure!=null&&pressure[pressure.length-1]!=17)throw new IllegalStateException("Allocation pressure was not retained");report.put("status","passed");
        }catch(Throwable problem){failure=problem;report.put("status","failed");report.put("failurePhase",phase);report.put("failure",problem.getClass().getName());report.put("failureMessage",Objects.toString(problem.getMessage(),""));}
        sampler.shutdownNow();report.put("usedHeapBytes",usedHeap());report.put("peakHeapBytes",heapPeak.get());report.put("heapPoolPeakUsageSumBytes",ManagementFactory.getMemoryPoolMXBeans().stream().filter(p->p.getType()==java.lang.management.MemoryType.HEAP).mapToLong(p->p.getPeakUsage().getUsed()).sum());
        if(Files.isRegularFile(Path.of("/proc/self/status")))for(String line:Files.readAllLines(Path.of("/proc/self/status")))if(line.startsWith("VmHWM:"))report.put("peakRssKiB",Long.parseLong(line.replaceAll("[^0-9]","")));
        Files.createDirectories(evidence.toAbsolutePath().getParent());Files.writeString(evidence,new com.google.gson.GsonBuilder().setPrettyPrinting().create().toJson(report));
        System.out.println(report.get("status"));if(failure!=null){failure.printStackTrace();System.exit(1);}
    }
    private static void validate(Analysis result,AnalysisOperation operation,long elapsedNanos){
        if(!result.getAvailability().equals("available"))throw new IllegalStateException(operation+" availability "+result.getAvailability()+" elapsedMs="+elapsedNanos/1_000_000.0+" diagnostics="+result.getDiagnosticsList().stream().map(issue->issue.getCode()+":"+issue.getSource()+":"+issue.getMessage()).toList());
        if(operation==AnalysisOperation.COMPLETION&&result.getCompletionsList().stream().noneMatch(c->c.getLabel().equals("column_9")))throw new IllegalStateException("Completion omitted a verified field");
        if(operation==AnalysisOperation.PARAMETER_INFORMATION&&result.getParameterInformation().getOverloadsCount()!=30)throw new IllegalStateException("Parameter information omitted overloads");
        if(operation==AnalysisOperation.FORMAT&&result.getFormattedSql().isEmpty())throw new IllegalStateException("Formatting returned no proven output");
    }
    private static long usedHeap(){return Runtime.getRuntime().totalMemory()-Runtime.getRuntime().freeMemory();}
    private static double p95(List<Long> values){var sorted=new ArrayList<>(values);Collections.sort(sorted);return sorted.get((int)Math.ceil(sorted.size()*.95)-1)/1_000_000.0;}
    private static String catalog(IdentifierRules rules,String schema){return rules.engine()==Engine.POSTGRESQL?CATALOG:schema;}
    private static MetadataObject object(IdentifierRules rules,ObjectKind kind,String schema,String parent,String name,String signature,Map<String,String> properties){
        if(rules.engine()!=Engine.POSTGRESQL){
            var nativeProperties=new HashMap<>(properties);String id=nativeProperties.remove("nativeId");nativeProperties.remove("nativeTypeId");
            if(kind==ObjectKind.TABLE){String generation="innodb:"+id+":"+(rules.engine()==Engine.MYSQL?"rows:0:":"")+"a".repeat(64);nativeProperties.put("nativeGeneration",generation);nativeProperties.put("nativeGenerationAvailability","AVAILABLE");nativeProperties.put("nativeTableId",id);if(rules.engine()==Engine.MYSQL)nativeProperties.put("nativeColumnEpoch","0");}
            if(kind==ObjectKind.COLUMN){String type=nativeProperties.get("jdbcType").equals("2")?"DECIMAL(38,12)":"BIGINT";nativeProperties.put("type",type);nativeProperties.put("nativeType",type);nativeProperties.put("jdbcNativeType",type);}
            if(nativeProperties.containsKey("referencedSchema"))nativeProperties.put("referencedCatalog",nativeProperties.get("referencedSchema"));
            properties=nativeProperties;
        }
        return MetadataObject.from(SOURCE,PROFILE,"",rules,SchemaObject.newBuilder().setKind(kind).setCatalog(catalog(rules,schema)).setSchema(schema).setTable(parent).setName(name).setIdentifier(signature).putAllProperties(properties).build(),IntrospectionLevel.STRUCTURE,1,1);
    }
    public static MetadataSnapshot fixture(){return fixture(RULES);}
    /** Additional synthetic dense-map ownership guard; original PG workload is unchanged. */
    public static MetadataSnapshot fixture(IdentifierRules rules){
        var entries=new ArrayList<MetadataObject>(118000);var coverage=new HashMap<MetadataScope,MetadataCoverage>();
        for(var kind:List.of(ObjectKind.TABLE,ObjectKind.VIEW,ObjectKind.SEQUENCE,ObjectKind.ROUTINE)){var scope=new MetadataScope(catalog(rules,"pg_catalog"),"pg_catalog","",kind);coverage.put(scope,new MetadataCoverage(scope,IntrospectionLevel.STRUCTURE,MetadataState.AVAILABLE,true,"fixture-complete-empty",1,1,1,""));}
        for(int schema=0;schema<10;schema++)for(var kind:List.of(ObjectKind.TABLE,ObjectKind.VIEW,ObjectKind.ROUTINE)){var scope=new MetadataScope(catalog(rules,"namespace_"+schema),"namespace_"+schema,"",kind);coverage.put(scope,new MetadataCoverage(scope,IntrospectionLevel.STRUCTURE,MetadataState.AVAILABLE,true,"fixture",1,1,1,""));}
        for(int relation=0;relation<10000;relation++){
            String schema="namespace_"+(relation/1000),table="table_"+(relation%1000);entries.add(object(rules,ObjectKind.TABLE,schema,"",table,"",Map.of("nativeId",Integer.toString(relation+1),"nativeGeneration",Integer.toString(relation+1))));
            var scope=new MetadataScope(catalog(rules,schema),schema,table,ObjectKind.COLUMN);coverage.put(scope,new MetadataCoverage(scope,IntrospectionLevel.STRUCTURE,MetadataState.AVAILABLE,true,"fixture",1,1,1,""));
            for(int column=0;column<10;column++)entries.add(object(rules,ObjectKind.COLUMN,schema,table,"column_"+column,"",Map.of("nativeType",column==9?"numeric(38,12)":"bigint","type",column==9?"numeric":"int8","jdbcType",column==9?"2":"-5","nativeTypeId",column==9?"1700":"20","ordinal",Integer.toString(column+1),"nullable","1","autoIncrement","NO","generated","NO")));
        }
        for(int i=0;i<3000;i++)entries.add(object(rules,ObjectKind.CONSTRAINT,"namespace_"+(i/1000),"table_"+(i%1000),"pk_"+i,"",Map.of("type","PRIMARY KEY","column.0","column_0","columnCount","1")));
        for(int i=0;i<2000;i++)entries.add(object(rules,ObjectKind.FOREIGN_KEY,"namespace_"+(i/1000),"table_"+(i%1000),"fk_"+i,"",Map.of("relationshipVerified","true","columnCount","1","column.0","column_0","referencedColumn.0","column_0","referencedCatalog",CATALOG,"referencedSchema","namespace_"+(i/1000),"referencedTable","table_"+((i+1)%1000))));
        for(int i=0;i<3000;i++)entries.add(object(rules,ObjectKind.ROUTINE,"namespace_0","","routine_"+(i%100),"signature_"+i,Map.of("signature","routine_"+(i%100)+"(numeric, integer)","parameterCount","2","parameter.0.type","numeric","parameter.1.type","integer","returnType","numeric","parameter.0.nativeTypeId",Integer.toString(20000+i/100),"parameter.1.nativeTypeId","23")));
        return new MetadataSnapshot(SOURCE,PROFILE,1,1,System.currentTimeMillis(),rules,entries,coverage);
    }
}
