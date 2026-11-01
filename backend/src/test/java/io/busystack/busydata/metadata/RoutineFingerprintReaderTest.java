package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.*;
import java.sql.SQLTimeoutException;
import java.util.*;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

/** Pure source-admission boundary; actual SQL/driver behavior belongs to the native IT. */
class RoutineFingerprintReaderTest {
    private static RoutineFingerprintReader.Evidence evidence(String name){var object=SchemaObject.newBuilder().setCatalog("db").setSchema("db").setName(name).setIdentifier("FUNCTION:"+name).setKind(ObjectKind.ROUTINE).setSubtype(ObjectSubtype.FUNCTION).putProperties("type","FUNCTION").putProperties("specificName",name).build();return new RoutineFingerprintReader.Evidence(object,"f".repeat(64),MetadataState.AVAILABLE);}
    private static long deadline(){return System.nanoTime()+TimeUnit.SECONDS.toNanos(5);}
    @Test void capturedExclusionsAreAppliedBeforeAnyDeniedOrOversizedNativeSourceRead()throws Exception {
        var defaults=MetadataConfiguration.defaults();var ownerPolicy=new MetadataConfiguration(7,defaults.includedCatalogs(),defaults.excludedCatalogs(),defaults.includedSchemas(),defaults.excludedSchemas(),defaults.systemObjects(),defaults.kinds(),List.of(),List.of("excluded_*"),IntrospectionLevel.SOURCE,Map.of());var calls=new AtomicInteger();
        String ddl="CREATE FUNCTION admitted() RETURNS int RETURN 1";
        var scan=RoutineFingerprintReader.completeEvidence(Engine.MARIADB,IntrospectionLevel.SOURCE,List.of(evidence("excluded_oversized"),evidence("admitted"),evidence("excluded_denied")),deadline(),true,object->ownerPolicy.permits(object.getCatalog(),object.getSchema(),object.getKind(),object.getName()),(object,until)->{
            calls.incrementAndGet();assertEquals("admitted",object.getName(),"Excluded sources must not be opened before policy filtering");return new NativeRoutineSource(ddl,"",MetadataState.AVAILABLE);
        });
        assertEquals(1,calls.get());assertEquals(1,scan.nativeSourceReads());assertEquals(ddl.length(),scan.sourceBytes());assertEquals(1,scan.count());assertEquals("admitted",scan.evidence().getFirst().identity().getName());
    }
    @Test void namesAndOtherNativeDomainsDoNotAcquireMariaSourcesAndDenialCannotBecomeAvailable()throws Exception {
        for(var level:List.of(IntrospectionLevel.NAMES,IntrospectionLevel.STRUCTURE)){
            var engine=level==IntrospectionLevel.NAMES?Engine.MARIADB:Engine.MYSQL;
            var scan=RoutineFingerprintReader.completeEvidence(engine,level,List.of(evidence("known")),deadline(),true,ignored->true,(object,until)->{throw new AssertionError("Unexpected native source read");});assertEquals(0,scan.nativeSourceReads());assertEquals(1,scan.count());
        }
        var denied=RoutineFingerprintReader.completeEvidence(Engine.MARIADB,IntrospectionLevel.STRUCTURE,List.of(evidence("known")),deadline(),true,ignored->true,(object,until)->new NativeRoutineSource("","",MetadataState.DENIED));assertEquals(1,denied.nativeSourceReads());assertEquals(MetadataState.DENIED,denied.evidence().getFirst().state());assertFalse(denied.evidence().getFirst().limitation().isEmpty());
    }
    @Test void expiredDeadlineAndAggregateSourceLimitStopWorkWithoutRetainingBodies(){
        assertThrows(SQLTimeoutException.class,()->RoutineFingerprintReader.completeEvidence(Engine.MARIADB,IntrospectionLevel.SOURCE,List.of(evidence("known")),System.nanoTime()-1,true,ignored->true,(object,until)->{throw new AssertionError("Expired read must not execute");}));
        var values=new ArrayList<RoutineFingerprintReader.Evidence>();for(int i=0;i<129;i++)values.add(evidence("limited_"+i));var calls=new AtomicInteger();
        assertThrows(IllegalArgumentException.class,()->RoutineFingerprintReader.completeEvidence(Engine.MARIADB,IntrospectionLevel.SOURCE,values,deadline(),true,ignored->true,(object,until)->{calls.incrementAndGet();return new NativeRoutineSource("","",MetadataState.LIMITED,65_537);}));assertEquals(128,calls.get());
    }
}
