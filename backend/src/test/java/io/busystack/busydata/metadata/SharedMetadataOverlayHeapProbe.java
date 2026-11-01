package io.busystack.busydata.metadata;

import io.busystack.busydata.ProductionMetadataHeapProbe;
import io.busystack.busydata.analysis.*;
import io.busystack.busydata.analysis.language.ResolutionContext;
import io.busystack.busydata.protocol.*;
import java.lang.management.ManagementFactory;
import java.lang.ref.WeakReference;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;

/** No JDBC: eight physical-owner views share one 118k-object catalog under the
 * shipped heap. Generation retirement is separate from retained 32MiB pressure. */
public final class SharedMetadataOverlayHeapProbe {
    private static final int OWNERS=8,WARMUP=5,MEASURED=20,MAX_CALL_RECORDS=OWNERS*(WARMUP+MEASURED);
    private SharedMetadataOverlayHeapProbe(){}
    private record Owned(List<MetadataObject> facts,Set<MetadataScope> scopes,Map<MetadataScope,MetadataCoverage> coverage,String schema,String table,String owner){}
    private static MetadataCoverage covered(MetadataScope scope,long generation){return new MetadataCoverage(scope,IntrospectionLevel.STRUCTURE,MetadataState.AVAILABLE,true,"owned-fixture",generation,1,1,"");}
    private static Owned owned(MetadataSnapshot base,int index){
        String owner="physical-owner-"+index;boolean temporary=index<4;String schema=temporary?"pg_temp_"+(100+index):"namespace_0",table=temporary?"temporary_rows":"table_"+(index-4);var facts=new ArrayList<MetadataObject>();
        var tableScope=new MetadataScope("fixture",schema,"",ObjectKind.TABLE,table,true,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED);
        // The established fixture uses catalog=profile="fixture".
        var columns=new MetadataScope("fixture",schema,table,ObjectKind.COLUMN);var coverage=new HashMap<MetadataScope,MetadataCoverage>();coverage.put(tableScope,covered(tableScope,1));coverage.put(columns,covered(columns,1));
        var parent=SchemaObject.newBuilder().setCatalog("fixture").setSchema(schema).setName(table).setKind(ObjectKind.TABLE).putProperties("remarks","owned view "+index);if(temporary)parent.putProperties("temporary","true");facts.add(MetadataObject.from(base.source(),base.profileId(),temporary?owner:"",base.rules(),parent.build(),IntrospectionLevel.STRUCTURE,1,1));
        for(int column=0;column<10;column++){var value=SchemaObject.newBuilder().setCatalog("fixture").setSchema(schema).setTable(table).setName("column_"+column).setKind(ObjectKind.COLUMN).putProperties("type",column==9?"numeric":"int8").putProperties("nativeType",column==9?"numeric(38,12)":"bigint").putProperties("jdbcType",column==9?"2":"-5").putProperties("nativeTypeId",column==9?"1700":"20").putProperties("nullable","1").putProperties("ordinal",Integer.toString(column+1)).putProperties("autoIncrement","NO").putProperties("generated","NO");if(temporary)value.putProperties("temporary","true");facts.add(MetadataObject.from(base.source(),base.profileId(),temporary?owner:"",base.rules(),value.build(),IntrospectionLevel.STRUCTURE,1,1));}
        return new Owned(List.copyOf(facts),Set.of(tableScope,columns),Map.copyOf(coverage),schema,table,owner);
    }
    public static void main(String[] args)throws Exception{
        Path evidence=Path.of(args[0]);var report=new LinkedHashMap<String,Object>();report.put("java",System.getProperty("java.runtime.version"));report.put("vmArguments",ManagementFactory.getRuntimeMXBean().getInputArguments());report.put("processors",Runtime.getRuntime().availableProcessors());report.put("maxHeapBytes",Runtime.getRuntime().maxMemory());report.put("fixtureObjects",118000);report.put("physicalOwnerViews",8);report.put("nativeCatalogAcceptance",false);report.put("jdbcWork",false);Throwable failure=null;var peak=new java.util.concurrent.atomic.AtomicLong();var sampler=Executors.newSingleThreadScheduledExecutor();sampler.scheduleAtFixedRate(()->peak.accumulateAndGet(ManagementFactory.getMemoryMXBean().getHeapMemoryUsage().getUsed(),Math::max),0,10,TimeUnit.MILLISECONDS);
        try{
            var current=ProductionMetadataHeapProbe.fixture();var inputs=new ArrayList<Owned>();var views=new ArrayList<MetadataSnapshot>();long incremental=0;for(int owner=0;owner<8;owner++){var input=owned(current,owner);inputs.add(input);var view=MetadataSnapshot.compose(current,input.facts(),input.scopes(),input.coverage(),Set.of(),2,1,2,System.nanoTime()+TimeUnit.SECONDS.toNanos(30));views.add(view);incremental+=view.estimatedBytes();}
            report.put("durableSemanticBytes",current.estimatedBytes());report.put("allIncrementalResidentBytes",incremental);if(incremental>8L*1024*1024)throw new IllegalStateException("Eight small owned views duplicated catalog-sized indexes");
            for(int owner=0;owner<8;owner++){var input=inputs.get(owner);var view=views.get(owner);if(view.localIdentities().size()!=11)throw new IllegalStateException("Unexpected local fact count");if(owner<4){if(view.resolve("fixture",input.schema(),ObjectKind.TABLE,"",input.table(),true).getFirst().identity().sessionOwner().equals(input.owner())==false)throw new IllegalStateException("Wrong physical temporary owner");if(!current.resolve("fixture",input.schema(),ObjectKind.TABLE,"",input.table(),true).isEmpty())throw new IllegalStateException("Temporary objects escaped into durable metadata");for(int other=0;other<4;other++)if(other!=owner&&!views.get(other).resolve("fixture",input.schema(),ObjectKind.TABLE,"",input.table(),true).isEmpty())throw new IllegalStateException("Temporary metadata leaked across physical owners");}}
            var retired=new ArrayList<WeakReference<MetadataSnapshot>>();for(int generation=2;generation<=5;generation++){var previous=current;retired.add(new WeakReference<>(previous));current=new MetadataSnapshot(previous.source(),previous.profileId(),generation,1,generation,previous.rules(),previous.identities().values(),previous.catalogCoverage());for(int owner=0;owner<views.size();owner++)views.set(owner,views.get(owner).rebaseComposed(current,generation+1,1,generation,System.nanoTime()+TimeUnit.SECONDS.toNanos(30)));previous=null;System.gc();}
            for(int attempt=0;attempt<10&&retired.stream().anyMatch(ref->ref.get()!=null);attempt++){System.gc();Thread.sleep(20);}long collected=retired.stream().filter(ref->ref.get()==null).count();report.put("retiredDurableGenerations",retired.size());report.put("collectedDurableGenerations",collected);if(collected!=retired.size())throw new IllegalStateException("An owned rebase retained an obsolete durable snapshot generation");
            byte[] pressure=new byte[32*1024*1024];Arrays.fill(pressure,(byte)17);report.put("retainedAllocationPressureBytes",pressure.length);var service=new SqlAnalysis();var timings=new ArrayList<Map<String,Object>>();var calls=new ArrayList<Map<String,Object>>();report.put("analysisCalls",calls);report.put("completion",timings);report.put("warmupIterationsPerOwner",WARMUP);report.put("measuredIterationsPerOwner",MEASURED);report.put("warmupExcludedFromAcceptance",true);
            for(int owner=0;owner<8;owner++){var input=inputs.get(owner);var view=views.get(owner);String sql="SELECT t.column_0, t.column_9 FROM "+input.schema()+"."+input.table()+" t WHERE t.column_0 > 1";var context=new ResolutionContext("fixture","namespace_0",List.of("namespace_0"),true,view.revision(),view.configurationRevision(),view.rules(),view);var request=AnalysisRequest.newBuilder().setEngine(Engine.POSTGRESQL).setDocumentId("shared-owned-heap-"+owner).setDocumentVersion(1).setOperation(AnalysisOperation.COMPLETION).setSql(sql).setCaretUtf16(sql.indexOf("column_9")+6).build();for(int warm=0;warm<WARMUP;warm++)analyzeChecked(service,request,context,report,calls,true,owner,warm);var samples=new ArrayList<Long>();for(int measure=0;measure<MEASURED;measure++){long start=System.nanoTime();analyzeChecked(service,request,context,report,calls,false,owner,measure);samples.add(System.nanoTime()-start);}Collections.sort(samples);double p95=samples.get(18)/1_000_000.0;timings.add(Map.of("owner",owner,"documentUtf16Units",sql.length(),"warmupIterations",WARMUP,"measuredIterations",MEASURED,"completionP95Ms",p95,"incrementalResidentBytes",view.estimatedBytes()));if(p95>250)throw new IllegalStateException("Shared owned completion exceeded250ms: "+p95);}
            if(pressure[pressure.length-1]!=17)throw new IllegalStateException("Allocation pressure was not retained");report.put("completion",timings);report.put("status","passed");
        }catch(Throwable problem){failure=problem;report.put("status","failed");report.put("failure",problem.getClass().getName());report.put("failureMessage",Objects.toString(problem.getMessage(),""));}finally{sampler.shutdownNow();report.put("usedHeapBytes",Runtime.getRuntime().totalMemory()-Runtime.getRuntime().freeMemory());report.put("peakHeapBytes",peak.get());report.put("heapPoolPeakUsageSumBytes",ManagementFactory.getMemoryPoolMXBeans().stream().filter(p->p.getType()==java.lang.management.MemoryType.HEAP).mapToLong(p->p.getPeakUsage().getUsed()).sum());Files.createDirectories(evidence.toAbsolutePath().getParent());Files.writeString(evidence,new com.google.gson.GsonBuilder().setPrettyPrinting().create().toJson(report));}if(failure!=null){failure.printStackTrace();System.exit(1);}
    }
    /** Five unmeasured calls exercise the same deadline without certifying
     * availability. Every measured call requires the full verified completion. */
    private static void analyzeChecked(SqlAnalysis service,AnalysisRequest request,ResolutionContext context,
            Map<String,Object> report,List<Map<String,Object>> calls,boolean warmup,int owner,int iteration){
        if(calls.size()>=MAX_CALL_RECORDS)throw new IllegalStateException("Owned completion evidence exceeded its call budget");
        var call=new LinkedHashMap<String,Object>();call.put("phase",warmup?"warmup":"measurement");call.put("owner",owner);call.put("iteration",iteration);call.put("documentUtf16Units",request.getSql().length());
        call.put("validation","failed");report.put("activeAnalysis",call);long began=System.nanoTime();
        try{
            var analysis=service.analyze(request,LexicalSettings.DEFAULT,context);
            call.put("elapsedMs",(System.nanoTime()-began)/1_000_000.0);call.put("availability",analysis.getAvailability());call.put("completionCount",analysis.getCompletionsCount());
            call.put("verifiedFieldPresent",analysis.getCompletionsList().stream().anyMatch(value->value.getLabel().equals("column_9")));
            call.put("diagnostics",analysis.getDiagnosticsList().stream().map(issue->Map.of("code",issue.getCode(),"source",issue.getSource(),"severity",issue.getSeverity(),"message",issue.getMessage(),"incomplete",issue.getIncomplete())).toList());
            if(warmup&&deadlineLimited(analysis)){call.put("validation","unmeasured-deadline-limit");return;}
            validate(analysis);call.put("validation",warmup?"unmeasured-available":"measured-available");
        }finally{call.putIfAbsent("elapsedMs",(System.nanoTime()-began)/1_000_000.0);calls.add(call);}
    }
    private static boolean deadlineLimited(Analysis analysis){
        if(!analysis.getAvailability().equals("limited")||analysis.getCompletionsCount()!=0||analysis.getDiagnosticsCount()!=1)return false;
        var issue=analysis.getDiagnostics(0);return issue.getCode().equals("analysis.limit")&&issue.getSource().equals("availability")&&issue.getMessage().equals("SQL analysis deadline exceeded")&&issue.getIncomplete();
    }
    private static void validate(Analysis analysis){if(!analysis.getAvailability().equals("available")||analysis.getCompletionsList().stream().noneMatch(value->value.getLabel().equals("column_9")))throw new IllegalStateException("Owned completion lost verified field or availability: "+analysis.getAvailability()+" "+analysis.getDiagnosticsList().stream().map(Diagnostic::getCode).toList());}
}
