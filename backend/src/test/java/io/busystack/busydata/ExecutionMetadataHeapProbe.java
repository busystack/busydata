package io.busystack.busydata;

import io.busystack.busydata.adapters.JdbcAdapter;
import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import java.lang.management.ManagementFactory;
import java.lang.ref.WeakReference;
import java.nio.file.*;
import java.util.*;

/** Test-only GC/pressure experiment. Production code never requests collection. */
public final class ExecutionMetadataHeapProbe {
    private static final String SQL="SELECT column_0, column_9 FROM namespace_0.table_0";
    private static List<Column> columns(Engine engine){return List.of(column(engine,"column_0",1),column(engine,"column_9",2));}
    private static Column column(Engine engine,String name,int ordinal){return Column.newBuilder().setCatalog(engine==Engine.POSTGRESQL?"fixture":"namespace_0").setSchema("namespace_0").setTable("table_0").setBaseColumn(name).setOrdinal(ordinal).setProvenanceKnown(true).build();}
    private record NativeModel(String source,String profile,IdentifierRules rules,List<MetadataObject> objects,Map<MetadataScope,MetadataCoverage> coverage){}
    private static NativeModel model(Engine engine){
        var snapshot=engine==Engine.POSTGRESQL?ProductionMetadataHeapProbe.fixture():ProductionMetadataHeapProbe.fixture(NativeCaseFixtures.rules(engine,0));var objects=new ArrayList<>(snapshot.identities().values());
        for(int i=0;i<objects.size();i++){var value=objects.get(i);var id=value.identity();if(id.kind()==ObjectKind.TABLE&&id.schema().equals("namespace_0")&&id.name().equals("table_0")){
            var properties=new HashMap<>(value.properties());properties.put("nativeGenerationAvailability","AVAILABLE");
            objects.set(i,new MetadataObject(id,value.displayName(),value.quotedIdentifier(),value.lookupKey(),properties,value.source(),value.level(),value.state(),value.sourceRevision(),value.contextRevision()));break;
        }}
        return new NativeModel(snapshot.source(),snapshot.profileId(),snapshot.rules(),List.copyOf(objects),snapshot.catalogCoverage());
    }
    private static MetadataSnapshot generation(NativeModel model,long revision){return new MetadataSnapshot(model.source(),model.profile(),revision,1,1,model.rules(),model.objects(),model.coverage());}
    private static long used(){return ManagementFactory.getMemoryMXBean().getHeapMemoryUsage().getUsed();}
    private static int collected(List<WeakReference<MetadataSnapshot>> old){return (int)old.stream().filter(ref->ref.get()==null).count();}
    private static void collectOld(List<WeakReference<MetadataSnapshot>> old){for(int i=0;i<8&&collected(old)!=old.size();i++){System.gc();Thread.yield();}}
    public static void main(String[] args)throws Exception{
        Path output=Path.of(args[0]);String mode=args[1];if(!Set.of("compact","full-snapshot-control").contains(mode))throw new IllegalArgumentException("Unknown evidence mode");
        Engine engine=args.length>2?Engine.valueOf(args[2]):Engine.POSTGRESQL;
        if(engine!=Engine.POSTGRESQL&&engine!=Engine.MYSQL&&engine!=Engine.MARIADB)throw new IllegalArgumentException("Unknown fixture engine");
        var report=new LinkedHashMap<String,Object>();report.put("mode",mode);report.put("fixtureEngine",engine.name());report.put("syntheticNativeAsciiMaps",engine!=Engine.POSTGRESQL);report.put("java",System.getProperty("java.runtime.version"));report.put("vmArguments",ManagementFactory.getRuntimeMXBean().getInputArguments());report.put("maxHeapBytes",Runtime.getRuntime().maxMemory());report.put("os",System.getProperty("os.name")+" "+System.getProperty("os.arch"));report.put("testOnlyExplicitGc",true);
        var compact=new ArrayList<ExecutionMetadata>();var oldSnapshots=new ArrayList<MetadataSnapshot>();var weak=new ArrayList<WeakReference<MetadataSnapshot>>();byte[] pressure=null;MetadataSnapshot current=null;NativeModel model=null;String phase="118000-object-fixture";Throwable failure=null;
        try{
            model=model(engine);System.gc();report.put("fixtureObjects",model.objects().size());current=generation(model,1);report.put("snapshotEstimatedBytes",current.estimatedBytes());
            String catalog=engine==Engine.POSTGRESQL?"fixture":"namespace_0";
            var profile=Profile.newBuilder().setId(model.profile()).setDatabase(catalog).setEngine(engine).build();var context=new JdbcAdapter.LiveContext(catalog,"namespace_0",List.of("namespace_0"),"");var columns=columns(engine);
            report.put("nativeRuleEstimatedBytes",model.rules().estimatedBytes());
            for(int i=1;i<=7;i++){
                phase="hold-execution-generation-"+i;weak.add(new WeakReference<>(current));
                if(mode.equals("compact")){var candidate=ExecutionMetadata.prepare(current,profile,"session-"+i,SQL,context);if(candidate.columnCount()!=10||candidate.estimatedBytes()>ExecutionMetadata.MAX_BYTES)throw new IllegalStateException("Compact evidence budget or complete table columns changed");if(current.rules()!=model.rules())throw new IllegalStateException("Snapshot copied its immutable native rules");var ruleField=ExecutionMetadata.class.getDeclaredField("rules");ruleField.setAccessible(true);if(ruleField.get(candidate)!=model.rules())throw new IllegalStateException("Compact execution candidate copied native rule evidence");if(candidate.estimatedBytes()<model.rules().estimatedBytes())throw new IllegalStateException("Compact execution evidence did not charge native rules");compact.add(candidate);}else oldSnapshots.add(current);
                phase="publish-generation-"+(i+1);current=generation(model,i+1);report.put("publishedGenerations",i+1);
                if(mode.equals("compact"))collectOld(weak);
            }
            phase="old-generation-collection";if(mode.equals("compact")){collectOld(weak);if(collected(weak)!=7)throw new IllegalStateException("A blocked compact candidate still pins an old full snapshot");}
            report.put("heldExecutionCandidates",mode.equals("compact")?compact.size():oldSnapshots.size());report.put("oldGenerationWeakRefsCollected",collected(weak));report.put("heapBeforePressureBytes",used());
            phase="32MiB-retained-allocation-pressure";pressure=new byte[32*1024*1024];Arrays.fill(pressure,(byte)29);report.put("retainedAllocationPressureBytes",pressure.length);
            phase="finalize-seven-selected-projections";int finalized=0;
            for(int i=0;i<7;i++){
                var proof=mode.equals("compact")?compact.get(i).proof(columns):RetainedMetadataProof.captureExecution(oldSnapshots.get(i),columns,profile,"session-"+(i+1),SQL,context);
                if(!proof.available()||proof.snapshotRevision()!=i+1||!proof.columns().keySet().equals(Set.of(1,2)))throw new IllegalStateException("A captured execution proof did not finalize exactly");finalized++;
            }
            report.put("exactFinalizedProofs",finalized);report.put("compactCandidateEstimatedBytes",compact.stream().mapToLong(ExecutionMetadata::estimatedBytes).sum());report.put("heapWithPressureBytes",used());
            if(pressure[pressure.length-1]!=29||current.revision()!=8||current.identities().size()!=118000)throw new IllegalStateException("Pressure/current-generation ownership was not retained");report.put("status","passed");
        }catch(Throwable problem){failure=problem;report.put("status","failed");report.put("failurePhase",phase);report.put("failure",problem.getClass().getName());}
        finally{report.put("peakHeapPoolUsageSumBytes",ManagementFactory.getMemoryPoolMXBeans().stream().filter(pool->pool.getType()==java.lang.management.MemoryType.HEAP).mapToLong(pool->pool.getPeakUsage().getUsed()).sum());report.put("oldGenerationWeakRefsCollectedAtEnd",collected(weak));oldSnapshots.clear();compact.clear();current=null;model=null;pressure=null;System.gc();}
        Files.createDirectories(output.toAbsolutePath().getParent());Files.writeString(output,new com.google.gson.GsonBuilder().setPrettyPrinting().create().toJson(report));System.out.println(report.get("status"));if(failure!=null){System.err.println(failure.getClass().getName()+" during "+phase);System.exit(1);}
    }
}
