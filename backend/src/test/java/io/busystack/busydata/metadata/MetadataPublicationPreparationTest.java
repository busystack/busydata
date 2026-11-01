package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

/** Publication command guards; large/concurrent public-path coverage is separate. */
class MetadataPublicationPreparationTest {
    private static final IdentifierRules RULES=new IdentifierRules(Engine.POSTGRESQL,0);
    private static MetadataObject routine(String name,IntrospectionLevel level){return MetadataObject.from("source","profile","",RULES,SchemaObject.newBuilder().setCatalog("db").setSchema("app").setKind(ObjectKind.ROUTINE).setSubtype(ObjectSubtype.FUNCTION).setName(name).setIdentifier(name+"(integer)").putProperties("nativeId",name).build(),level,1,1);}
    private static MetadataScope point(MetadataObject object){var i=object.identity();return new MetadataScope(i.catalog(),i.schema(),"",ObjectKind.ROUTINE,i.name(),true,i.signature(),i.subtype());}
    private static MetadataCoverage available(MetadataScope scope,IntrospectionLevel level){return new MetadataCoverage(scope,level,MetadataState.AVAILABLE,true,"fingerprint",1,1,123,"");}
    private static MetadataPlatform.Branch branch(MetadataScope scope,MetadataObject object){return new MetadataPlatform.Branch(List.of(),available(scope,IntrospectionLevel.SOURCE),List.of(object),false);}
    private static Set<MetadataObject> admitted(MetadataObject... values){Set<MetadataObject> set=Collections.newSetFromMap(new IdentityHashMap<>());Collections.addAll(set,values);return set;}
    private static boolean certifies(MetadataScope scope,MetadataPlatform.Branch branch,MetadataObject resident,Set<MetadataObject> admitted){return MetadataPlatform.freshRoutinePoint(scope,branch.coverage(),branch,Map.of(resident.identity().key(),resident),admitted,RULES);}
    @Test void onlyTheSameParentAdmittedImmutableReferenceCanCertifyAnExactPoint(){
        var object=routine("f",IntrospectionLevel.SOURCE);var scope=point(object);var command=branch(scope,object);assertTrue(certifies(scope,command,object,admitted(object)));
        var equal=routine("f",IntrospectionLevel.SOURCE);assertEquals(object,equal);assertNotSame(object,equal);
        assertFalse(certifies(scope,command,object,admitted(equal)),"An equal historical object is not this publication's parent admission");
        assertFalse(certifies(scope,command,equal,admitted(object)),"A displaced exact identity is not the admitted reference");
        assertFalse(certifies(scope,command,object,admitted()),"A resident point without a replacing parent must use generic reconciliation");
    }
    @Test void broadWrongKindAndWrongOverloadScopesCannotUsePointCertification(){
        var object=routine("f",IntrospectionLevel.SOURCE);var id=object.identity();var candidates=List.of(new MetadataScope("db","app","",ObjectKind.ROUTINE),new MetadataScope("db","app","",ObjectKind.ROUTINE,"f",true,"",ObjectSubtype.FUNCTION),new MetadataScope("db","app","",ObjectKind.ROUTINE,"f",true,id.signature(),ObjectSubtype.PROCEDURE),new MetadataScope("db","app","",ObjectKind.ROUTINE,"f",true,"f(text)",ObjectSubtype.FUNCTION),new MetadataScope("db","other","",ObjectKind.ROUTINE,"f",true,id.signature(),ObjectSubtype.FUNCTION),new MetadataScope("db","app","",ObjectKind.TABLE,"f",true,id.signature(),ObjectSubtype.FUNCTION));
        for(var scope:candidates)assertFalse(certifies(scope,branch(scope,object),object,admitted(object)),scope.toString());
        var wrongIdentity=new MetadataIdentity(id.source(),id.profileId(),id.catalog(),id.schema(),ObjectKind.TABLE,id.subtype(),"",id.name(),id.signature(),"",id.nativeKey());
        var wrong=new MetadataObject(wrongIdentity,object.displayName(),object.quotedIdentifier(),object.lookupKey(),object.properties(),object.source(),object.level(),object.state(),1,1);
        assertFalse(certifies(point(object),branch(point(object),wrong),wrong,admitted(wrong)));
    }
    @Test void reusedRawIncompleteAndUnsupportedPointsRemainOnTheGenericPath(){
        var object=routine("f",IntrospectionLevel.SOURCE);var scope=point(object);var full=available(scope,IntrospectionLevel.SOURCE);
        assertFalse(certifies(scope,MetadataPlatform.Branch.reused(full),object,admitted(object)));
        assertFalse(certifies(scope,new MetadataPlatform.Branch(List.of(object.projection(1,1)),full),object,admitted(object)));
        assertFalse(certifies(scope,new MetadataPlatform.Branch(List.of(),full.stale("Changed"),List.of(object),false),object,admitted(object)));
        var shallow=routine("f",IntrospectionLevel.STRUCTURE);assertFalse(certifies(scope,branch(scope,shallow),shallow,admitted(shallow)));
        var stale=new MetadataObject(object.identity(),object.displayName(),object.quotedIdentifier(),object.lookupKey(),object.properties(),object.source(),object.level(),MetadataState.STALE,1,1);assertFalse(certifies(scope,branch(scope,stale),stale,admitted(stale)));
    }
    @Test void configurationDropsExcludedNamesAndPreservesUnrelatedExactFacts()throws Exception{
        var kept=routine("keep",IntrospectionLevel.SOURCE);var removed=routine("blocked",IntrospectionLevel.SOURCE);var parent=new MetadataScope("db","app","",ObjectKind.ROUTINE);
        var before=new MetadataSnapshot("source","profile",3,1,1,RULES,List.of(kept,removed),Map.of(parent,available(parent,IntrospectionLevel.SOURCE),point(kept),available(point(kept),IntrospectionLevel.SOURCE),point(removed),available(point(removed),IntrospectionLevel.SOURCE)));
        var defaults=MetadataConfiguration.defaults();var policy=new MetadataConfiguration(2,defaults.includedCatalogs(),defaults.excludedCatalogs(),defaults.includedSchemas(),defaults.excludedSchemas(),defaults.systemObjects(),defaults.kinds(),List.of(),List.of("blocked"),defaults.defaultLevel(),defaults.scopeLevels());
        var prepared=MetadataPlatform.configuredSnapshot(before,defaults,policy);assertEquals(2,prepared.configurationRevision());assertEquals(List.of(kept),prepared.identities().values().stream().toList());assertSame(kept,prepared.identity(kept.identity().key()).orElseThrow());
        assertFalse(prepared.catalogCoverage().containsKey(point(removed)));assertSame(before.catalogCoverage().get(point(kept)),prepared.catalogCoverage().get(point(kept)));assertEquals(MetadataState.STALE,prepared.catalogCoverage().get(parent).state());assertFalse(prepared.catalogCoverage().get(parent).complete());assertTrue(before.complete(parent,IntrospectionLevel.SOURCE));assertEquals(2,before.identities().size());
        var rebased=prepared.withPublicationRevision(15);assertEquals(15,rebased.revision());assertSame(prepared.identities(),rebased.identities());assertSame(prepared.catalogCoverage(),rebased.catalogCoverage());assertEquals(2,rebased.configurationRevision());
    }
    @Test void expiredOrCancelledPreparationCannotReachThePreferenceWrite()throws Exception{
        var before=MetadataSnapshot.empty("source","profile",RULES);assertThrows(java.util.concurrent.TimeoutException.class,()->MetadataPlatform.configuredSnapshot(before,MetadataConfiguration.defaults(),MetadataConfiguration.defaults(),System.nanoTime()-1));
        var context=io.grpc.Context.current().withCancellation();context.cancel(null);context.run(()->assertThrows(java.util.concurrent.CancellationException.class,()->MetadataPlatform.configuredSnapshot(before,MetadataConfiguration.defaults(),MetadataConfiguration.defaults())));
        assertEquals(0,before.revision());assertTrue(before.identities().isEmpty());
    }
    @Test void aConcurrentOwnerRetirementOrEqualReplacementCannotBeOverwritten(){
        java.util.concurrent.ConcurrentMap<String,String> owners=new java.util.concurrent.ConcurrentHashMap<>();String captured=new String("same owner");owners.put("session",captured);
        String newer=new String("same owner");assertEquals(captured,newer);assertNotSame(captured,newer);owners.put("session",newer);
        assertFalse(MetadataPlatform.replaceCaptured(owners,"session",captured,"prepared"));assertSame(newer,owners.get("session"));
        owners.remove("session");assertFalse(MetadataPlatform.replaceCaptured(owners,"session",captured,"prepared"));assertFalse(owners.containsKey("session"),"A retired physical owner must never be resurrected by a prebuilt overlay");
        owners.put("session",captured);assertTrue(MetadataPlatform.replaceCaptured(owners,"session",captured,"prepared"));assertEquals("prepared",owners.get("session"));
    }
    private static MetadataConfiguration revision(MetadataConfiguration b,long revision){return new MetadataConfiguration(revision,b.includedCatalogs(),b.excludedCatalogs(),b.includedSchemas(),b.excludedSchemas(),b.systemObjects(),b.kinds(),b.includePatterns(),b.excludePatterns(),b.defaultLevel(),b.scopeLevels());}
    private static MetadataConfiguration names(MetadataConfiguration b,List<String> include,List<String> exclude){return new MetadataConfiguration(b.revision()+1,b.includedCatalogs(),b.excludedCatalogs(),b.includedSchemas(),b.excludedSchemas(),b.systemObjects(),b.kinds(),include,exclude,b.defaultLevel(),b.scopeLevels());}
    private static MetadataConfiguration levels(MetadataConfiguration b,IntrospectionLevel level,Map<String,IntrospectionLevel> overrides){return new MetadataConfiguration(b.revision()+1,b.includedCatalogs(),b.excludedCatalogs(),b.includedSchemas(),b.excludedSchemas(),b.systemObjects(),b.kinds(),b.includePatterns(),b.excludePatterns(),level,overrides);}
    private static MetadataConfiguration selectors(MetadataConfiguration b,Set<String> catalogs,Set<String> excludedCatalogs,Set<String> schemas,Set<String> excludedSchemas,boolean system,Set<ObjectKind> kinds){return new MetadataConfiguration(b.revision()+1,catalogs,excludedCatalogs,schemas,excludedSchemas,system,kinds,b.includePatterns(),b.excludePatterns(),b.defaultLevel(),b.scopeLevels());}
    private static MetadataScope table(String schema,String name){return new MetadataScope("db",schema,"",ObjectKind.TABLE,name,true,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED);}
    private static MetadataSnapshot policySnapshot(MetadataConfiguration policy,Map<MetadataScope,MetadataCoverage> coverage){return new MetadataSnapshot("source","profile",1,policy.revision(),1,RULES,List.of(),coverage);}
    @Test void revisionOnlyAndEquivalentPatternSetsPreserveExactEvidenceIncludingFailures()throws Exception{
        var defaults=MetadataConfiguration.defaults();var current=names(defaults,List.of("keep*","other*","keep*"),List.of("blocked","blocked"));var next=names(current,List.of("other*","keep*"),List.of("blocked"));
        var parent=new MetadataScope("db","app","",ObjectKind.TABLE);var exact=table("app","keep");var denied=new MetadataCoverage(exact,IntrospectionLevel.SOURCE,MetadataState.DENIED,false,"denied",1,1,123,"Native permission denied");
        var before=policySnapshot(current,Map.of(parent,available(parent,IntrospectionLevel.STRUCTURE),exact,denied));var changed=MetadataPlatform.configuredSnapshot(before,current,next);assertSame(before.catalogCoverage().get(parent),changed.catalogCoverage().get(parent));assertSame(denied,changed.catalogCoverage().get(exact));
        var same=MetadataPlatform.configuredSnapshot(changed,next,revision(next,next.revision()+1));assertSame(denied,same.catalogCoverage().get(exact));assertSame(changed.catalogCoverage().get(parent),same.catalogCoverage().get(parent));
        var all=names(defaults,List.of("**","keep*"),List.of());var equivalent=names(all,List.of(),List.of());var allBefore=policySnapshot(all,Map.of(parent,available(parent,IntrospectionLevel.NAMES)));assertSame(allBefore.catalogCoverage().get(parent),MetadataPlatform.configuredSnapshot(allBefore,all,equivalent).catalogCoverage().get(parent));
    }
    @Test void effectiveNamespaceLevelsPreserveOverridesAndUnrelatedScopes()throws Exception{
        var current=levels(MetadataConfiguration.defaults(),IntrospectionLevel.STRUCTURE,Map.of(MetadataConfiguration.scopeKey("db","app"),IntrospectionLevel.SOURCE));var app=table("app","keep");var other=table("other","keep");var catalogs=new MetadataScope("","","",ObjectKind.CATALOG);var schemas=new MetadataScope("db","","",ObjectKind.TABLE);var before=policySnapshot(current,Map.of(app,available(app,IntrospectionLevel.SOURCE),other,available(other,IntrospectionLevel.STRUCTURE),catalogs,available(catalogs,IntrospectionLevel.NAMES),schemas,available(schemas,IntrospectionLevel.NAMES)));
        var next=levels(current,IntrospectionLevel.NAMES,current.scopeLevels());var after=MetadataPlatform.configuredSnapshot(before,current,next);assertSame(before.catalogCoverage().get(app),after.catalogCoverage().get(app));assertEquals(MetadataState.STALE,after.catalogCoverage().get(other).state());
        var scoped=levels(current,current.defaultLevel(),Map.of(MetadataConfiguration.scopeKey("db","app"),IntrospectionLevel.STRUCTURE));var scopedAfter=MetadataPlatform.configuredSnapshot(before,current,scoped);assertSame(before.catalogCoverage().get(other),scopedAfter.catalogCoverage().get(other));assertEquals(MetadataState.STALE,scopedAfter.catalogCoverage().get(app).state());assertSame(before.catalogCoverage().get(catalogs),scopedAfter.catalogCoverage().get(catalogs));assertSame(before.catalogCoverage().get(schemas),scopedAfter.catalogCoverage().get(schemas));
    }
    @Test void newlyEnabledUnseenNamesInvalidateEnumerationButNotFixedParentStructure()throws Exception{
        var current=names(MetadataConfiguration.defaults(),List.of("keep"),List.of());var next=names(current,List.of("keep","not-yet-seen"),List.of());var parent=new MetadataScope("db","app","",ObjectKind.TABLE);var exact=table("app","keep");var columns=new MetadataScope("db","app","keep",ObjectKind.COLUMN);var filtered=new MetadataScope("db","app","",ObjectKind.TABLE,"keep",false,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED);
        var before=policySnapshot(current,Map.of(parent,available(parent,IntrospectionLevel.NAMES),filtered,available(filtered,IntrospectionLevel.NAMES),exact,available(exact,IntrospectionLevel.SOURCE),columns,available(columns,IntrospectionLevel.STRUCTURE)));var after=MetadataPlatform.configuredSnapshot(before,current,next);
        assertEquals(MetadataState.STALE,after.catalogCoverage().get(parent).state());assertEquals(MetadataState.STALE,after.catalogCoverage().get(filtered).state());assertSame(before.catalogCoverage().get(exact),after.catalogCoverage().get(exact));assertSame(before.catalogCoverage().get(columns),after.catalogCoverage().get(columns));assertFalse(after.catalogCoverage().containsKey(table("app","not-yet-seen")),"Enabling unseen names does not fabricate empty exact coverage");
    }
    @Test void catalogSchemaAndSystemSelectorsAffectOnlyTheirActualNamespaceOrAggregate()throws Exception{
        var current=MetadataConfiguration.defaults();var app=table("app","keep");var other=table("other","keep");var allSchemas=new MetadataScope("db","","",ObjectKind.TABLE);var allCatalogs=new MetadataScope("","","",ObjectKind.CATALOG);var catalog=new MetadataScope("db","","",ObjectKind.CATALOG);
        var before=policySnapshot(current,Map.of(app,available(app,IntrospectionLevel.STRUCTURE),other,available(other,IntrospectionLevel.STRUCTURE),allSchemas,available(allSchemas,IntrospectionLevel.NAMES),allCatalogs,available(allCatalogs,IntrospectionLevel.NAMES),catalog,available(catalog,IntrospectionLevel.NAMES)));
        var next=selectors(current,Set.of("db"),Set.of(),Set.of("app"),Set.of(),false,current.kinds());var after=MetadataPlatform.configuredSnapshot(before,current,next);assertSame(before.catalogCoverage().get(app),after.catalogCoverage().get(app));assertFalse(after.catalogCoverage().containsKey(other));assertEquals(MetadataState.STALE,after.catalogCoverage().get(allSchemas).state());assertEquals(MetadataState.STALE,after.catalogCoverage().get(allCatalogs).state());assertSame(before.catalogCoverage().get(catalog),after.catalogCoverage().get(catalog));
        var system=selectors(current,Set.of(),Set.of(),Set.of(),Set.of(),true,current.kinds());var systemAfter=MetadataPlatform.configuredSnapshot(before,current,system);assertSame(before.catalogCoverage().get(app),systemAfter.catalogCoverage().get(app));assertEquals(MetadataState.STALE,systemAfter.catalogCoverage().get(allSchemas).state());assertSame(before.catalogCoverage().get(allCatalogs),systemAfter.catalogCoverage().get(allCatalogs));
        var excluded=selectors(current,Set.of(),Set.of("unrelated"),Set.of(),Set.of("other"),false,current.kinds());var excludedAfter=MetadataPlatform.configuredSnapshot(before,current,excluded);assertSame(before.catalogCoverage().get(app),excludedAfter.catalogCoverage().get(app));assertFalse(excludedAfter.catalogCoverage().containsKey(other));assertEquals(MetadataState.STALE,excludedAfter.catalogCoverage().get(allCatalogs).state());
    }
    @Test void kindChangesNeverPromoteOldStaleFactsOrInvalidateAnUnchangedKind()throws Exception{
        var current=MetadataConfiguration.defaults();var table=table("app","keep");var routine=point(routine("keep",IntrospectionLevel.SOURCE));var oldStale=available(routine,IntrospectionLevel.SOURCE).stale("Old native source unavailable");var before=policySnapshot(current,Map.of(table,available(table,IntrospectionLevel.STRUCTURE),routine,oldStale));
        var next=selectors(current,Set.of(),Set.of(),Set.of(),Set.of(),false,Set.of(ObjectKind.TABLE));var after=MetadataPlatform.configuredSnapshot(before,current,next);assertSame(before.catalogCoverage().get(table),after.catalogCoverage().get(table));assertFalse(after.catalogCoverage().containsKey(routine));
        var unchanged=MetadataPlatform.configuredSnapshot(before,current,revision(current,2));assertSame(oldStale,unchanged.catalogCoverage().get(routine));assertFalse(unchanged.catalogCoverage().get(routine).complete());
        var reenabled=MetadataPlatform.configuredSnapshot(after,next,revision(current,3));assertFalse(reenabled.catalogCoverage().containsKey(routine));
    }
    @Test void inlineInvalidationDuringPreferenceCasSurvivesPolicyPublicationAndExcludedKeysStayAbsent()throws Exception{
        var current=MetadataConfiguration.defaults();var keep=table("app","keep");var stale=table("app","stale");var drop=table("app","drop");var denied=new MetadataCoverage(keep,IntrospectionLevel.STRUCTURE,MetadataState.DENIED,false,"native",1,1,1,"Permission revoked during preference write");
        var before=policySnapshot(current,Map.of(keep,available(keep,IntrospectionLevel.STRUCTURE),stale,available(stale,IntrospectionLevel.SOURCE),drop,available(drop,IntrospectionLevel.STRUCTURE)));var next=names(current,List.of(),List.of("drop"));var prepared=MetadataPlatform.configuredSnapshot(before,current,next);
        var latestStates=new HashMap<>(before.catalogCoverage());var staleState=latestStates.get(stale).stale("Concurrent acknowledged DDL");latestStates.put(stale,staleState);latestStates.put(keep,denied);var latest=before.withCoverage(2,latestStates);var committed=prepared.withConfigurationPublication(3,before,latest);
        assertSame(staleState,committed.catalogCoverage().get(stale));assertSame(denied,committed.catalogCoverage().get(keep));assertFalse(committed.catalogCoverage().containsKey(drop));assertEquals(2,committed.catalogCoverage().size());assertSame(prepared.identities(),committed.identities());assertTrue(before.catalogCoverage().get(stale).complete());assertThrows(UnsupportedOperationException.class,()->committed.catalogCoverage().put(drop,latestStates.get(drop)));
        var captured=committed;var policy=next;
        for(int i=0;i<64;i++){var following=revision(policy,policy.revision()+1);var materialized=MetadataPlatform.configuredSnapshot(captured,policy,following);assertNotSame(captured.catalogCoverage(),materialized.catalogCoverage());var changed=new HashMap<>(captured.catalogCoverage());var newer=changed.get(stale).stale("Next inline invalidation");changed.put(stale,newer);var inline=captured.withCoverage(captured.revision()+1,changed);captured=materialized.withConfigurationPublication(inline.revision()+1,captured,inline);assertSame(newer,captured.catalogCoverage().get(stale));assertFalse(captured.catalogCoverage().containsKey(drop));policy=following;}
    }
    @Test void configurationTransitionRefusesProofAdmissionWithoutCatalogOrDiskWork(){
        var owner=new MetadataPlatform.Source(MetadataSnapshot.empty("source","profile",RULES));var fence=new MetadataPlatform.ProofFence("source",owner.owner,owner.proofEpoch);assertEquals(MetadataState.AVAILABLE,MetadataPlatform.proofAdmissionState(owner,fence));
        owner.configurationPending=true;assertEquals(MetadataState.STALE,MetadataPlatform.proofAdmissionState(owner,fence));owner.configurationPending=false;owner.proofEpoch++;
        assertEquals(MetadataState.STALE,MetadataPlatform.proofAdmissionState(owner,fence),"A failed or completed transition cannot revive an already retired proof owner");assertEquals(MetadataState.AVAILABLE,MetadataPlatform.proofAdmissionState(owner,new MetadataPlatform.ProofFence("source",owner.owner,owner.proofEpoch)));
    }
}
