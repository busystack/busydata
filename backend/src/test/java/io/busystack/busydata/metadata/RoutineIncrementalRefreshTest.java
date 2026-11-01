package io.busystack.busydata.metadata;

import io.busystack.busydata.NativeCaseFixtures;
import io.busystack.busydata.protocol.*;
import java.sql.SQLException;
import java.util.*;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

/** Real coordinator staging with bounded synthetic native scan evidence. */
class RoutineIncrementalRefreshTest {
    private static final MetadataScope NAMESPACE=new MetadataScope("db","db","",ObjectKind.ROUTINE);
    private static RoutineFingerprintReader.Evidence evidence(String name,String version){return evidence(Engine.MYSQL,name,"FUNCTION:"+name,ObjectSubtype.FUNCTION,"",version,MetadataState.AVAILABLE);}
    private static RoutineFingerprintReader.Evidence evidence(Engine engine,String name,String signature,ObjectSubtype subtype,String nativeId,String version,MetadataState state){
        var identity=SchemaObject.newBuilder().setCatalog("db").setSchema("db").setKind(ObjectKind.ROUTINE).setName(name).setIdentifier(signature).setSubtype(subtype);
        if(engine==Engine.POSTGRESQL)identity.putProperties("nativeId",nativeId);
        return new RoutineFingerprintReader.Evidence(identity.build(),MetadataIdentity.digest("fixture-routine",version),state);
    }
    private static MetadataScope point(SchemaObject identity){return new MetadataScope(identity.getCatalog(),identity.getSchema(),"",ObjectKind.ROUTINE,identity.getName(),true,identity.getIdentifier(),identity.getSubtype());}
    private static MetadataCoverage coverage(MetadataScope scope,IntrospectionLevel level,String fingerprint){return new MetadataCoverage(scope,level,MetadataState.AVAILABLE,true,fingerprint,1,1,1,"");}
    private static MetadataObject details(IdentifierRules rules,RoutineFingerprintReader.Evidence item,IntrospectionLevel level){return MetadataObject.from("source","profile","",rules,item.identity().toBuilder().setDefinition(level==IntrospectionLevel.SOURCE?"captured-body:"+item.fingerprint():"").putProperties("parameterCount","1").putProperties("parameter.0.name","arg").putProperties("parameter.0.type","INTEGER").putProperties("signatureAvailability","AVAILABLE").putProperties("parameterDefaultsAvailability","AVAILABLE").putProperties("sourceAvailability",level==IntrospectionLevel.SOURCE?"AVAILABLE":"UNAVAILABLE").build(),level,1,1);}
    private static MetadataSnapshot before(IdentifierRules rules,List<RoutineFingerprintReader.Evidence> evidence,IntrospectionLevel level){
        var objects=new ArrayList<MetadataObject>();var coverage=new LinkedHashMap<MetadataScope,MetadataCoverage>();coverage.put(NAMESPACE,coverage(NAMESPACE,level,"namespace-before"));
        for(var item:evidence){objects.add(details(rules,item,level));var point=point(item.identity());coverage.put(point,coverage(point,level,item.fingerprint()));}
        return new MetadataSnapshot("source","profile",1,1,1,rules,objects,coverage);
    }
    private static MetadataRefresh.RoutineBranches stage(MetadataSnapshot before,IdentifierRules rules,MetadataScope scope,IntrospectionLevel level,List<RoutineFingerprintReader.Evidence> evidence,AtomicInteger fetches)throws Exception{
        return MetadataRefresh.routineBranches(before,rules,scope,level,MetadataPlatform.RefreshMode.INCREMENTAL,MetadataConfiguration.defaults(),evidence,"namespace-current",2,1,(item,point)->{fetches.incrementAndGet();assertEquals(point(item.identity()),point);return details(rules,item,level);});
    }
    @Test void unchangedRoutinesFetchNoDetailsAndShareEverySourceObject()throws Exception{
        var rules=NativeCaseFixtures.rules(Engine.MYSQL,0);var evidence=List.of(evidence("a","one"),evidence("b","two"));var before=before(rules,evidence,IntrospectionLevel.SOURCE);var fetches=new AtomicInteger();
        var staged=stage(before,rules,NAMESPACE,IntrospectionLevel.STRUCTURE,evidence,fetches);
        assertEquals(0,fetches.get());assertEquals(0,staged.fetchedScopes());assertEquals(0,staged.fetchedObjects());assertTrue(staged.parent().coverage().complete());
        for(int i=0;i<evidence.size();i++){assertSame(before.resolve("db","db",ObjectKind.ROUTINE,"",evidence.get(i).identity().getName(),true).getFirst(),staged.parent().normalized().get(i));assertEquals(IntrospectionLevel.SOURCE,staged.points().get(point(evidence.get(i).identity())).coverage().level());}
    }
    @Test void oneChangedRoutineFetchesExactlyOneAndKeepsItsNeighborByReference()throws Exception{
        var rules=NativeCaseFixtures.rules(Engine.MYSQL,0);var a=evidence("a","one");var b=evidence("b","two");var before=before(rules,List.of(a,b),IntrospectionLevel.STRUCTURE);var changed=evidence("a","changed-within-same-second");var fetches=new AtomicInteger();
        var staged=stage(before,rules,NAMESPACE,IntrospectionLevel.STRUCTURE,List.of(changed,b),fetches);
        assertEquals(1,fetches.get());assertEquals(1,staged.fetchedScopes());assertEquals(1,staged.fetchedObjects());assertNotSame(before.resolve("db","db",ObjectKind.ROUTINE,"","a",true).getFirst(),staged.parent().normalized().getFirst());assertSame(before.resolve("db","db",ObjectKind.ROUTINE,"","b",true).getFirst(),staged.parent().normalized().get(1));
        assertEquals(changed.fingerprint(),staged.points().get(point(a.identity())).coverage().fingerprint());
    }
    @Test void oneNewRoutineFetchesOneWhileDeletionFetchesNoneAndPublishesExactAbsence()throws Exception{
        var rules=NativeCaseFixtures.rules(Engine.MYSQL,0);var a=evidence("a","one");var b=evidence("b","two");var fetches=new AtomicInteger();
        var added=stage(before(rules,List.of(a),IntrospectionLevel.STRUCTURE),rules,NAMESPACE,IntrospectionLevel.STRUCTURE,List.of(a,b),fetches);assertEquals(1,fetches.get());assertEquals(1,added.fetchedScopes());assertEquals(2,added.parent().normalized().size());
        fetches.set(0);var removed=stage(before(rules,List.of(a,b),IntrospectionLevel.STRUCTURE),rules,NAMESPACE,IntrospectionLevel.STRUCTURE,List.of(a),fetches);
        assertEquals(0,fetches.get());assertEquals(0,removed.fetchedScopes());assertEquals(List.of("a"),removed.parent().normalized().stream().map(object->object.identity().name()).toList());
        var deleted=removed.points().get(point(b.identity()));assertFalse(deleted.reuse());assertTrue(deleted.coverage().complete());assertEquals(IntrospectionLevel.SOURCE,deleted.coverage().level());assertTrue(deleted.objects().isEmpty());assertTrue(deleted.normalized().isEmpty());
    }
    @Test void postgresOverloadsAndSameNamedFunctionProcedureKeepExactIndependentPoints()throws Exception{
        var rules=new IdentifierRules(Engine.POSTGRESQL,0);
        var integer=evidence(Engine.POSTGRESQL,"same","same(integer)",ObjectSubtype.FUNCTION,"101","integer",MetadataState.AVAILABLE);var text=evidence(Engine.POSTGRESQL,"same","same(text)",ObjectSubtype.FUNCTION,"102","text",MetadataState.AVAILABLE);var procedure=evidence(Engine.POSTGRESQL,"same","same(bigint)",ObjectSubtype.PROCEDURE,"103","procedure",MetadataState.AVAILABLE);
        var before=before(rules,List.of(integer,text,procedure),IntrospectionLevel.SOURCE);var fetches=new AtomicInteger();var staged=stage(before,rules,NAMESPACE,IntrospectionLevel.SOURCE,List.of(text,procedure),fetches);
        assertEquals(0,fetches.get());assertEquals(2,staged.parent().normalized().size());assertEquals(Set.of("102","103"),staged.parent().normalized().stream().map(object->object.identity().nativeKey()).collect(java.util.stream.Collectors.toSet()));assertFalse(staged.points().get(point(integer.identity())).reuse());assertTrue(staged.points().get(point(text.identity())).reuse());assertTrue(staged.points().get(point(procedure.identity())).reuse());
    }
    @Test void exactPointParentDoesNotGetOverwrittenByItsCoverageOnlyBranch()throws Exception{
        var rules=NativeCaseFixtures.rules(Engine.MYSQL,0);var old=evidence("a","old");var changed=evidence("a","new");var before=before(rules,List.of(old),IntrospectionLevel.SOURCE);var point=point(old.identity());var fetches=new AtomicInteger();
        var staged=stage(before,rules,point,IntrospectionLevel.STRUCTURE,List.of(changed),fetches);assertEquals(1,fetches.get());assertEquals(1,staged.parent().normalized().size());assertFalse(staged.parent().reuse());assertFalse(staged.points().containsKey(point));assertEquals(changed.fingerprint(),staged.parent().coverage().fingerprint());
        fetches.set(0);var unchanged=stage(before,rules,point,IntrospectionLevel.STRUCTURE,List.of(old),fetches);assertEquals(0,fetches.get());assertEquals(IntrospectionLevel.SOURCE,unchanged.parent().coverage().level());assertSame(before.resolve("db","db",ObjectKind.ROUTINE,"","a",true).getFirst(),unchanged.parent().normalized().getFirst());
    }
    @Test void changedStructureRetiresOldExactSourceWithoutInvalidatingUnchangedSource()throws Exception{
        var rules=NativeCaseFixtures.rules(Engine.MYSQL,0);var a=evidence("a","old");var b=evidence("b","unchanged");var before=before(rules,List.of(a,b),IntrospectionLevel.SOURCE);var changed=evidence("a","new");var fetches=new AtomicInteger();var staged=stage(before,rules,NAMESPACE,IntrospectionLevel.STRUCTURE,List.of(changed,b),fetches);
        var legacyA=new MetadataScope("db","db","",ObjectKind.ROUTINE,"a",true,a.identity().getIdentifier(),ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED);var legacyB=new MetadataScope("db","db","",ObjectKind.ROUTINE,"b",true,b.identity().getIdentifier(),ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED);var coverage=new HashMap<>(before.catalogCoverage());coverage.put(legacyA,coverage(legacyA,IntrospectionLevel.SOURCE,"legacy-a"));coverage.put(legacyB,coverage(legacyB,IntrospectionLevel.SOURCE,"legacy-b"));
        var functionGroup=new MetadataScope("db","db","",ObjectKind.ROUTINE,"a",true,"",ObjectSubtype.FUNCTION);coverage.put(functionGroup,coverage(functionGroup,IntrospectionLevel.SOURCE,"legacy-function-group"));
        var invalid=MetadataCoverageReconciliation.invalidated(coverage,NAMESPACE,new ArrayList<>(before.identities().values()),staged.parent().normalized());
        assertTrue(invalid.contains(legacyA));assertTrue(invalid.contains(functionGroup));assertFalse(invalid.contains(legacyB));assertEquals(IntrospectionLevel.STRUCTURE,staged.points().get(point(a.identity())).coverage().level());assertEquals(IntrospectionLevel.SOURCE,staged.points().get(point(b.identity())).coverage().level());assertEquals(1,fetches.get());
    }
    @Test void unavailableFingerprintRetainsHistoryAndRetiresEveryOverlappingExactAuthority()throws Exception{
        var rules=NativeCaseFixtures.rules(Engine.MYSQL,0);var a=evidence("a","one");var b=evidence("b","two");var before=before(rules,List.of(a,b),IntrospectionLevel.SOURCE);var denied=new RoutineFingerprintReader.Evidence(a.identity(),a.fingerprint(),MetadataState.DENIED);var fetches=new AtomicInteger();
        var staged=stage(before,rules,NAMESPACE,IntrospectionLevel.SOURCE,List.of(denied,b),fetches);assertEquals(0,fetches.get());assertFalse(staged.parent().reuse());assertFalse(staged.parent().coverage().complete());assertEquals(MetadataState.PARTIAL,staged.parent().coverage().state());
        assertEquals(MetadataState.DENIED,staged.points().get(point(a.identity())).coverage().state());assertEquals(MetadataState.PARTIAL,staged.points().get(point(b.identity())).coverage().state());assertTrue(staged.points().values().stream().noneMatch(branch->branch.coverage().complete()));assertTrue(before.identities().values().stream().allMatch(object->object.level()==IntrospectionLevel.SOURCE));
    }
    @Test void ruleGenerationChangeOrStalePointForcesExactReacquisition()throws Exception{
        var rules=NativeCaseFixtures.rules(Engine.MYSQL,0,"old-version");var current=NativeCaseFixtures.rules(Engine.MYSQL,0,"new-version");var a=evidence("a","unchanged");var before=before(rules,List.of(a),IntrospectionLevel.STRUCTURE);var fetches=new AtomicInteger();
        assertEquals(1,stage(before,current,NAMESPACE,IntrospectionLevel.STRUCTURE,List.of(a),fetches).fetchedScopes());assertEquals(1,fetches.get());
        var coverage=new HashMap<>(before.catalogCoverage());var point=point(a.identity());coverage.put(point,coverage.get(point).stale("Prior acquisition is stale"));var stale=new MetadataSnapshot("source","profile",2,1,2,rules,before.identities().values(),coverage);
        fetches.set(0);stage(stale,rules,NAMESPACE,IntrospectionLevel.STRUCTURE,List.of(a),fetches);assertEquals(1,fetches.get());
    }
    @Test void filteredScopesRejectUnrelatedKindsAndDuplicateExactIdentitiesBeforeDetails()throws Exception{
        var rules=NativeCaseFixtures.rules(Engine.MYSQL,0);var a=evidence("a","one");var b=evidence("b","two");var before=before(rules,List.of(a),IntrospectionLevel.STRUCTURE);var fetches=new AtomicInteger();
        assertThrows(SQLException.class,()->stage(before,rules,point(a.identity()),IntrospectionLevel.STRUCTURE,List.of(b),fetches));assertEquals(0,fetches.get());
        assertThrows(SQLException.class,()->stage(before,rules,NAMESPACE,IntrospectionLevel.STRUCTURE,List.of(a,a),fetches));assertEquals(0,fetches.get());
    }
    @Test void namesOnlyFingerprintCannotCertifyRetainedHigherSourceLevel()throws Exception{
        var rules=NativeCaseFixtures.rules(Engine.MARIADB,0);var a=evidence("a","unchanged-visible-catalog");var before=before(rules,List.of(a),IntrospectionLevel.SOURCE);var normalized=new AtomicInteger();
        var staged=MetadataRefresh.routineBranches(before,rules,NAMESPACE,IntrospectionLevel.NAMES,MetadataPlatform.RefreshMode.INCREMENTAL,MetadataConfiguration.defaults(),List.of(a),"names-only",2,1,(item,point)->{normalized.incrementAndGet();return MetadataObject.from("source","profile","",rules,item.identity(),IntrospectionLevel.NAMES,2,1);});
        assertEquals(1,normalized.get());assertEquals(0,staged.fetchedScopes());assertEquals(0,staged.fetchedObjects());assertEquals(IntrospectionLevel.NAMES,staged.parent().normalized().getFirst().level());assertTrue(staged.parent().normalized().getFirst().source().isEmpty());assertEquals(IntrospectionLevel.NAMES,staged.points().get(point(a.identity())).coverage().level());
        assertTrue(MetadataCoverageReconciliation.invalidated(before.catalogCoverage(),NAMESPACE,new ArrayList<>(before.identities().values()),staged.parent().normalized()).contains(point(a.identity())));
    }
    @Test void unavailableDefaultDetailsPublishKnownPartialFactsButOnlyNamesAreComplete()throws Exception{
        var rules=NativeCaseFixtures.rules(Engine.MARIADB,0);var a=evidence("a","current");var before=before(rules,List.of(),IntrospectionLevel.SOURCE);var fetched=new AtomicInteger();
        MetadataRefresh.RoutineFetch partial=(item,point)->{fetched.incrementAndGet();var value=details(rules,item,IntrospectionLevel.SOURCE);var properties=new HashMap<>(value.properties());properties.put("signatureAvailability","UNSUPPORTED");properties.put("parameterDefaultsAvailability","UNSUPPORTED");return new MetadataObject(value.identity(),value.displayName(),value.quotedIdentifier(),value.lookupKey(),properties,value.source(),value.level(),value.state(),1,1);};
        var staged=MetadataRefresh.routineBranches(before,rules,NAMESPACE,IntrospectionLevel.SOURCE,MetadataPlatform.RefreshMode.INCREMENTAL,MetadataConfiguration.defaults(),List.of(a),"current",2,1,partial);
        assertEquals(1,fetched.get());assertEquals(1,staged.fetchedObjects());assertEquals(IntrospectionLevel.NAMES,staged.parent().coverage().level());assertTrue(staged.parent().coverage().complete());
        var known=staged.parent().normalized().getFirst();assertEquals(MetadataState.PARTIAL,known.state());assertEquals(IntrospectionLevel.NAMES,known.level());assertEquals("arg",known.properties().get("parameter.0.name"));assertEquals("INTEGER",known.properties().get("parameter.0.type"));assertFalse(known.source().isEmpty());assertEquals(MetadataState.UNSUPPORTED,staged.points().get(point(a.identity())).coverage().state());assertFalse(staged.points().get(point(a.identity())).coverage().complete());
        fetched.set(0);var exact=MetadataRefresh.routineBranches(before,rules,point(a.identity()),IntrospectionLevel.SOURCE,MetadataPlatform.RefreshMode.INCREMENTAL,MetadataConfiguration.defaults(),List.of(a),"current",2,1,partial);
        assertEquals(1,fetched.get());assertFalse(exact.parent().reuse());assertEquals(MetadataState.UNSUPPORTED,exact.parent().coverage().state());assertFalse(exact.parent().coverage().complete());
        var names=new MetadataScope("db","db","",ObjectKind.ROUTINE,"a",true,a.identity().getIdentifier(),ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED);var candidates=exact.points().get(names);
        assertTrue(candidates.coverage().complete());assertEquals(IntrospectionLevel.NAMES,candidates.coverage().level());assertEquals(MetadataState.PARTIAL,candidates.normalized().getFirst().state());
    }
    @Test void limitedSourceRetainsCompleteSignatureWithoutClaimingSourceLevel()throws Exception{
        var rules=NativeCaseFixtures.rules(Engine.MYSQL,0);var a=evidence("a","current");var before=before(rules,List.of(),IntrospectionLevel.SOURCE);
        var staged=MetadataRefresh.routineBranches(before,rules,NAMESPACE,IntrospectionLevel.SOURCE,MetadataPlatform.RefreshMode.INCREMENTAL,MetadataConfiguration.defaults(),List.of(a),"current",2,1,(item,point)->{
            var value=details(rules,item,IntrospectionLevel.SOURCE);var properties=new HashMap<>(value.properties());properties.put("sourceAvailability","LIMITED");return new MetadataObject(value.identity(),value.displayName(),value.quotedIdentifier(),value.lookupKey(),properties,"",value.level(),value.state(),1,1);
        });
        assertEquals(IntrospectionLevel.STRUCTURE,staged.parent().coverage().level());assertTrue(staged.parent().coverage().complete());var object=staged.parent().normalized().getFirst();assertEquals(MetadataState.AVAILABLE,object.state());assertEquals(IntrospectionLevel.STRUCTURE,object.level());assertEquals("LIMITED",object.properties().get("sourceAvailability"));assertEquals(IntrospectionLevel.STRUCTURE,staged.points().get(point(a.identity())).coverage().level());
    }
    @Test void excludedDeniedRoutineCannotTriggerDetailsOrDegradeConfiguredNeighbors()throws Exception{
        var rules=NativeCaseFixtures.rules(Engine.MYSQL,0);var a=evidence("excluded","old");var b=evidence("included","current");var before=before(rules,List.of(a,b),IntrospectionLevel.SOURCE);var denied=new RoutineFingerprintReader.Evidence(a.identity(),a.fingerprint(),MetadataState.DENIED);var fetched=new AtomicInteger();
        var configuration=new MetadataConfiguration(1,Set.of("db"),Set.of(),Set.of("db"),Set.of(),false,Set.of(ObjectKind.ROUTINE),List.of(),List.of("excluded"),IntrospectionLevel.SOURCE,Map.of());
        var staged=MetadataRefresh.routineBranches(before,rules,NAMESPACE,IntrospectionLevel.SOURCE,MetadataPlatform.RefreshMode.INCREMENTAL,configuration,List.of(denied,b),"current",2,1,(item,point)->{fetched.incrementAndGet();throw new AssertionError("Configured unchanged routine must not fetch, excluded routine must not enter detail selection");});
        assertEquals(0,fetched.get());assertEquals(0,staged.fetchedObjects());assertTrue(staged.parent().coverage().complete());assertEquals(List.of("included"),staged.parent().normalized().stream().map(object->object.identity().name()).toList());assertSame(before.resolve("db","db",ObjectKind.ROUTINE,"","included",true).getFirst(),staged.parent().normalized().getFirst());
    }
    @Test void firstNativeRulesPublicationUsesFreshPointBranchesWithTheSameAdmittedFacts()throws Exception{
        var rules=NativeCaseFixtures.rules(Engine.MYSQL,0);var a=evidence("a","one");var b=evidence("b","two");var before=before(new IdentifierRules(Engine.MYSQL,0),List.of(),IntrospectionLevel.SOURCE);var fetched=new AtomicInteger();
        var staged=stage(before,rules,NAMESPACE,IntrospectionLevel.SOURCE,List.of(a,b),fetched);assertEquals(2,fetched.get());
        for(int i=0;i<2;i++){
            var item=List.of(a,b).get(i);var point=staged.points().get(point(item.identity()));assertFalse(point.reuse(),"Fresh point coverage must not be retired as legacy evidence when native rules first publish");assertTrue(point.coverage().complete());assertEquals(1,point.normalized().size());assertSame(staged.parent().normalized().get(i),point.normalized().getFirst(),"The acquired object is reused without another detail fetch or object admission");
        }
        assertFalse(before.rules().complete());assertTrue(rules.complete());
    }
}
