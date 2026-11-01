package io.busystack.busydata;

import io.busystack.busydata.analysis.*;
import io.busystack.busydata.analysis.language.*;
import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import java.nio.file.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.postgresql.core.Oid;
import static org.junit.jupiter.api.Assertions.*;

/** Compiled backend CPU gate over the same indexed model as connected analysis.
 * Fixture construction is outside every measured operation. No JDBC object,
 * connection factory, mock or server is present. The separate child-JVM gate
 * validates the shipped heap, four concurrent operations and publication. */
class LanguagePerformanceTest {
    private static final String SOURCE="language-performance",PROFILE="fixture",CATALOG="fixture";
    private static final IdentifierRules RULES=new IdentifierRules(Engine.POSTGRESQL,0);
    private static final String SQL="SELECT t.column_0, t.column_9 FROM namespace_0.table_0 t WHERE t.column_0 > :minimum ORDER BY t.column_9 LIMIT 100 OFFSET 5";
    private record NativeType(String name,int oid){}
    // Public constants from the pinned pgJDBC Oid catalog. Each input signature
    // is distinct; names alone never fabricate ten copies of one overload.
    private static final List<NativeType> ARGUMENTS=List.of(new NativeType("numeric",Oid.NUMERIC),new NativeType("integer",Oid.INT4),new NativeType("bigint",Oid.INT8),new NativeType("text",Oid.TEXT),new NativeType("date",Oid.DATE),new NativeType("timestamp",Oid.TIMESTAMP),new NativeType("boolean",Oid.BOOL),new NativeType("jsonb",Oid.JSONB),new NativeType("uuid",Oid.UUID),new NativeType("bytea",Oid.BYTEA));
    private static MetadataObject object(ObjectKind kind,String schema,String parent,String name,String signature,Map<String,String> properties){return MetadataObject.from(SOURCE,PROFILE,"",RULES,SchemaObject.newBuilder().setKind(kind).setCatalog(CATALOG).setSchema(schema).setTable(parent).setName(name).setIdentifier(signature).putAllProperties(properties).build(),IntrospectionLevel.STRUCTURE,100,4);}
    private static void complete(Map<MetadataScope,MetadataCoverage> coverage,MetadataScope scope){coverage.put(scope,new MetadataCoverage(scope,IntrospectionLevel.STRUCTURE,MetadataState.AVAILABLE,true,"explicit-complete-fixture",100,4,0,""));}
    private static MetadataSnapshot fixture(){
        var objects=new ArrayList<MetadataObject>(112000);var coverage=new HashMap<MetadataScope,MetadataCoverage>();
        for(int relation=0;relation<10000;relation++){
            String schema="namespace_"+(relation/1000),table="table_"+(relation%1000);
            objects.add(object(ObjectKind.TABLE,schema,"",table,"",Map.of()));
            for(int column=0;column<10;column++)objects.add(object(ObjectKind.COLUMN,schema,table,"column_"+column,"",Map.of("nativeType",column==9?"numeric(38,12)":"bigint")));
            complete(coverage,new MetadataScope(CATALOG,schema,table,ObjectKind.COLUMN));complete(coverage,new MetadataScope(CATALOG,schema,table,ObjectKind.FOREIGN_KEY));
        }
        for(int i=0;i<1000;i++){
            objects.add(object(ObjectKind.FOREIGN_KEY,"namespace_0","table_"+i,"fk_"+i,"",Map.of("relationshipVerified","true","columnCount","1","column.0","column_0","referencedColumn.0","column_0","referencedCatalog",CATALOG,"referencedSchema","namespace_0","referencedTable","table_"+((i+1)%1000))));
            var type=ARGUMENTS.get(i/100);String name="routine_"+(i%100),signature=name+"("+type.name()+", integer)";
            objects.add(object(ObjectKind.ROUTINE,"namespace_0","",name,signature,Map.ofEntries(Map.entry("signature",signature),Map.entry("signatureAvailability","AVAILABLE"),Map.entry("parameterCount","2"),Map.entry("parameter.0.name","value"),Map.entry("parameter.0.mode","IN"),Map.entry("parameter.0.type",type.name()),Map.entry("parameter.0.nativeTypeId",Integer.toString(type.oid())),Map.entry("parameter.1.name","amount"),Map.entry("parameter.1.mode","IN"),Map.entry("parameter.1.type","integer"),Map.entry("parameter.1.nativeTypeId",Integer.toString(Oid.INT4)),Map.entry("returnType","numeric"))));
        }
        for(String schema:java.util.stream.IntStream.range(0,10).mapToObj(i->"namespace_"+i).toList())for(var kind:List.of(ObjectKind.TABLE,ObjectKind.VIEW,ObjectKind.SEQUENCE,ObjectKind.ROUTINE))complete(coverage,new MetadataScope(CATALOG,schema,"",kind));
        for(var kind:List.of(ObjectKind.TABLE,ObjectKind.VIEW,ObjectKind.SEQUENCE,ObjectKind.ROUTINE))complete(coverage,new MetadataScope(CATALOG,"pg_catalog","",kind));
        return new MetadataSnapshot(SOURCE,PROFILE,100,4,0,RULES,objects,coverage);
    }
    @Test void cachedLargeCatalogCompletionParametersAndDiagnosticsHaveBoundedP95()throws Exception {
        var snapshot=fixture();assertEquals(112000,snapshot.identities().size());
        var counts=new EnumMap<ObjectKind,Long>(ObjectKind.class);for(var object:snapshot.identities().values())counts.merge(object.identity().kind(),1L,Long::sum);
        assertEquals(Map.of(ObjectKind.TABLE,10000L,ObjectKind.COLUMN,100000L,ObjectKind.FOREIGN_KEY,1000L,ObjectKind.ROUTINE,1000L),counts);assertEquals(123,SQL.length());
        var overloads=snapshot.resolve(CATALOG,"namespace_0",ObjectKind.ROUTINE,"","routine_0",false);assertEquals(10,overloads.size());assertEquals(10,overloads.stream().map(o->o.identity().signature()).distinct().count());assertEquals(10,overloads.stream().map(o->o.properties().get("parameter.0.nativeTypeId")).distinct().count());
        var context=new ResolutionContext(CATALOG,"namespace_0",List.of("namespace_0"),true,100,4,RULES,snapshot);var service=new SqlAnalysis();
        var request=AnalysisRequest.newBuilder().setEngine(Engine.POSTGRESQL).setDocumentId("performance").setDocumentVersion(1).setSql(SQL).setCaretUtf16(SQL.indexOf("column_9")+6).build();
        String call="SELECT routine_0(1, 2)";var parameterRequest=request.toBuilder().setOperation(AnalysisOperation.PARAMETER_INFORMATION).setSql(call).setCaretUtf16(call.length()-1).build();
        var completion=new ArrayList<Long>();var diagnostics=new ArrayList<Long>();var parameters=new ArrayList<Long>();
        for(int run=0;run<25;run++){
            long began=System.nanoTime();var result=service.analyze(request,LexicalSettings.DEFAULT,context);long elapsed=System.nanoTime()-began;
            assertEquals("available",result.getAvailability());assertTrue(result.getCompletionsList().stream().anyMatch(c->c.getLabel().equals("column_9")));if(run>=5)completion.add(elapsed);
            began=System.nanoTime();result=service.analyze(request.toBuilder().setOperation(AnalysisOperation.DIAGNOSTICS).build(),LexicalSettings.DEFAULT,context);elapsed=System.nanoTime()-began;assertEquals("available",result.getAvailability());if(run>=5)diagnostics.add(elapsed);
            began=System.nanoTime();result=service.analyze(parameterRequest,LexicalSettings.DEFAULT,context);elapsed=System.nanoTime()-began;assertEquals("available",result.getParameterInformation().getAvailability());assertEquals(10,result.getParameterInformation().getOverloadsCount());assertEquals(10,result.getParameterInformation().getOverloadsList().stream().map(RoutineSignature::getIdentity).distinct().count());assertEquals(10,result.getParameterInformation().getOverloadsList().stream().map(RoutineSignature::getSignature).distinct().count());assertTrue(result.getParameterInformation().getOverloadsList().stream().allMatch(s->s.getParametersCount()==2&&s.getParameters(0).getMode().equals("IN")&&!s.getIdentity().isEmpty()));if(run>=5)parameters.add(elapsed);
        }
        double completionP95=p95(completion),diagnosticP95=p95(diagnostics),parameterP95=p95(parameters);
        var evidence=new LinkedHashMap<String,Object>();evidence.put("fixtureModel","central-normalized-immutable-snapshot");evidence.put("java",System.getProperty("java.runtime.version"));evidence.put("vm",System.getProperty("java.vm.name"));evidence.put("os",System.getProperty("os.name")+" "+System.getProperty("os.version")+" "+System.getProperty("os.arch"));evidence.put("processors",Runtime.getRuntime().availableProcessors());evidence.put("maxHeapBytes",Runtime.getRuntime().maxMemory());evidence.put("documentUtf16Units",SQL.length());evidence.put("snapshotObjects",snapshot.identities().size());evidence.put("snapshotEstimatedBytes",snapshot.estimatedBytes());evidence.put("relations",counts.get(ObjectKind.TABLE));evidence.put("columns",counts.get(ObjectKind.COLUMN));evidence.put("foreignKeys",counts.get(ObjectKind.FOREIGN_KEY));evidence.put("routineSignatures",counts.get(ObjectKind.ROUTINE));evidence.put("warmupIterations",5);evidence.put("measuredIterations",20);evidence.put("completionP95Ms",completionP95);evidence.put("diagnosticsP95Ms",diagnosticP95);evidence.put("parametersP95Ms",parameterP95);evidence.put("completionNanos",completion);evidence.put("diagnosticsNanos",diagnostics);evidence.put("parametersNanos",parameters);
        Path target=Path.of("target/p0-language-performance.json");Files.createDirectories(target.getParent());Files.writeString(target,new com.google.gson.GsonBuilder().setPrettyPrinting().create().toJson(evidence));
        assertTrue(completionP95<=250,"Warm completion p95 "+completionP95+"ms");assertTrue(parameterP95<=250,"Warm parameters p95 "+parameterP95+"ms");assertTrue(diagnosticP95<=750,"Full diagnostics p95 "+diagnosticP95+"ms");
    }
    private static double p95(List<Long> samples){var sorted=new ArrayList<>(samples);Collections.sort(sorted);return sorted.get((int)Math.ceil(sorted.size()*.95)-1)/1_000_000.0;}
}
