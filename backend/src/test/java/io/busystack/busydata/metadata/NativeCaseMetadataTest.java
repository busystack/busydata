package io.busystack.busydata.metadata;

import io.busystack.busydata.NativeCaseFixtures;
import io.busystack.busydata.protocol.*;
import java.util.*;
import java.util.concurrent.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

/** Synthetic declared maps exercise publication/ownership, not a live dialect oracle. */
class NativeCaseMetadataTest {
    private static final MetadataScope COLUMNS=new MetadataScope("db","db","t",ObjectKind.COLUMN);
    private static MetadataCoverage available(MetadataScope scope){return new MetadataCoverage(scope,IntrospectionLevel.STRUCTURE,MetadataState.AVAILABLE,true,"fixture",1,1,1,"");}
    private static MetadataObject object(IdentifierRules rules,String parent,String name,ObjectKind kind,String owner,Map<String,String> properties){return MetadataObject.from("source","profile",owner,rules,SchemaObject.newBuilder().setCatalog("db").setSchema("db").setTable(parent).setName(name).setKind(kind).putAllProperties(properties).build(),IntrospectionLevel.STRUCTURE,1,1);}
    private static MetadataSnapshot snapshot(IdentifierRules rules,long revision,Collection<MetadataObject> objects,Map<MetadataScope,MetadataCoverage> coverage){return new MetadataSnapshot("source","profile",revision,1,1,rules,objects,coverage);}
    private static IdentifierRules changed(String version){
        var lower=new char[65536];var dictionary=new char[65536];
        for(int c=1;c<65536;c++)if(c<0xd800||c>0xdfff){lower[c]=(char)c;dictionary[c]=(char)c;}
        for(char c='A';c<='Z';c++){lower[c]=(char)(c+32);dictionary[c+32]=c;}
        lower['Σ']='σ';dictionary['é']='E';
        var lowerString=new String(lower);return IdentifierRules.nativeRules(Engine.MYSQL,1,version,lowerString,lowerString,new String(dictionary),null,false);
    }
    @Test void provisionalNamesRemainInspectableWithoutCompletenessOrExecutionProof(){
        var rules=new IdentifierRules(Engine.MYSQL,0);var column=object(rules,"t","Mixed",ObjectKind.COLUMN,"",Map.of());
        var tables=new MetadataScope("db","db","",ObjectKind.TABLE);var model=snapshot(rules,1,List.of(column),Map.of(COLUMNS,available(COLUMNS),tables,available(tables)));
        assertFalse(rules.complete());assertEquals(1,model.resolve("db","db",ObjectKind.COLUMN,"t","Mixed",true).size());
        assertFalse(model.complete(COLUMNS,IntrospectionLevel.NAMES));assertEquals(MetadataState.UNAVAILABLE,model.coverage(COLUMNS).orElseThrow().state());
        assertEquals("UNAVAILABLE",model.projection(column).getMetadataState());
        assertFalse(model.incomingComplete());
        var evidence=ExecutionMetadata.prepare(model,Profile.newBuilder().setEngine(Engine.MYSQL).build(),"session","SELECT Mixed FROM db.t",null);
        assertEquals(MetadataState.UNAVAILABLE,evidence.proof(List.of()).state());
    }
    @Test void changedRulesRekeyRetainedObjectsAndOnlyFreshScopesRegainCompleteness(){
        var oldRules=NativeCaseFixtures.rules(Engine.MYSQL,1);var newRules=changed("changed");var other=new MetadataScope("db","db","other",ObjectKind.COLUMN);
        var column=object(oldRules,"t","Σ",ObjectKind.COLUMN,"",Map.of("remarks","retained"));var untouched=object(oldRules,"other","id",ObjectKind.COLUMN,"",Map.of());
        var before=snapshot(oldRules,1,List.of(column,untouched),Map.of(COLUMNS,available(COLUMNS),other,available(other)));
        var coverage=MetadataPlatform.ruleCoverage(before,newRules);coverage.put(COLUMNS,available(COLUMNS));
        var after=snapshot(newRules,2,before.identities().values(),coverage);var acquired=after.resolve("db","db",ObjectKind.COLUMN,"t","σ",true).getFirst();
        assertEquals(column.identity(),acquired.identity());assertNotSame(column,acquired);assertSame(column.properties(),acquired.properties());
        assertTrue(after.complete(COLUMNS,IntrospectionLevel.STRUCTURE));assertEquals(MetadataState.STALE,after.coverage(other).orElseThrow().state());assertFalse(after.complete(other,IntrospectionLevel.NAMES));
        assertEquals("Σ",column.lookupKey());assertTrue(before.resolve("db","db",ObjectKind.COLUMN,"t","σ",true).isEmpty());assertTrue(before.complete(other,IntrospectionLevel.STRUCTURE));
    }
    @Test void coverageAndSessionViewsShareDenseEvidenceAndIndexes(){
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB)){
            var rules=NativeCaseFixtures.rules(engine,1);var model=snapshot(rules,1,List.of(object(rules,"t","id",ObjectKind.COLUMN,"",Map.of())),Map.of(COLUMNS,available(COLUMNS)));
            var view=model.withCoverage(2,model.catalogCoverage()).withSessionResolution(3,MetadataSnapshot.SessionResolution.available());
            assertSame(rules,view.rules());assertSame(model.identities(),view.identities());assertEquals(model.estimatedBytes(),view.estimatedBytes());assertTrue(model.estimatedBytes()>=rules.estimatedBytes());assertTrue(rules.estimatedBytes()>=262144);
        }
    }
    @Test void unavailablePhysicalAffinitySharesTheModelAndSurvivesOtherViews(){
        var rules=NativeCaseFixtures.rules(Engine.MARIADB,1);var column=object(rules,"t","Mixed",ObjectKind.COLUMN,"",Map.of());
        var before=snapshot(rules,1,List.of(column),Map.of(COLUMNS,available(COLUMNS)));var view=before.withIdentifierAvailability(false);
        assertTrue(rules.complete());assertFalse(view.identifierRulesAvailable());assertSame(rules,view.rules());assertSame(before.identities(),view.identities());assertSame(before.catalogCoverage(),view.catalogCoverage());assertEquals(before.estimatedBytes(),view.estimatedBytes());
        assertFalse(view.complete(COLUMNS,IntrospectionLevel.NAMES));assertEquals(MetadataState.UNAVAILABLE,view.coverage(COLUMNS).orElseThrow().state());assertEquals("UNAVAILABLE",view.projection(column).getMetadataState());
        assertFalse(view.coverage().get(COLUMNS).complete());assertEquals(MetadataState.UNAVAILABLE,view.coverage().get(COLUMNS).state());
        assertFalse(view.withCoverage(2,view.catalogCoverage()).withSessionResolution(3,MetadataSnapshot.SessionResolution.available()).identifierRulesAvailable());assertTrue(before.complete(COLUMNS,IntrospectionLevel.STRUCTURE));
        var evidence=ExecutionMetadata.prepare(view,Profile.newBuilder().setEngine(Engine.MARIADB).build(),"session","SELECT Mixed FROM db.t",null);assertEquals(MetadataState.UNAVAILABLE,evidence.proof(List.of()).state());
    }
    @Test void mariaCaseInsensitiveFilesystemOnlyWithholdsTriggerResolution(){
        var rules=NativeCaseFixtures.rules(Engine.MARIADB,1,"filesystem-fixture",true);var triggers=new MetadataScope("db","db","t",ObjectKind.TRIGGER);
        var trigger=object(rules,"t","ExactTrigger",ObjectKind.TRIGGER,"",Map.of());var column=object(rules,"t","id",ObjectKind.COLUMN,"",Map.of());
        var model=snapshot(rules,1,List.of(trigger,column),Map.of(triggers,available(triggers),COLUMNS,available(COLUMNS)));
        assertTrue(model.identifierRulesAvailable());assertFalse(model.complete(triggers,IntrospectionLevel.NAMES));assertEquals(MetadataState.UNSUPPORTED,model.coverage(triggers).orElseThrow().state());assertEquals(MetadataState.UNSUPPORTED,model.coverage().get(triggers).state());
        assertEquals("UNSUPPORTED",model.projection(trigger).getMetadataState());assertEquals(List.of(trigger),model.resolve("db","db",ObjectKind.TRIGGER,"t","ExactTrigger",true));assertTrue(model.complete(COLUMNS,IntrospectionLevel.STRUCTURE));assertEquals("AVAILABLE",model.projection(column).getMetadataState());
        var supported=NativeCaseFixtures.rules(Engine.MARIADB,1,"filesystem-fixture",false);var ordinary=snapshot(supported,2,List.of(trigger),Map.of(triggers,available(triggers)));assertTrue(ordinary.complete(triggers,IntrospectionLevel.NAMES));
    }
    @Test void actualConstraintTypeSeparatesIdentityAndComparisonDomains(){
        var rules=changed("constraint-domains");var entries=new ArrayList<MetadataObject>();
        for(String type:List.of("CHECK","FOREIGN KEY","UNIQUE"))entries.add(object(rules,"t","é",ObjectKind.CONSTRAINT,"",Map.of("type",type)));
        var model=snapshot(rules,1,entries,Map.of());assertEquals(3,model.identities().size());
        assertEquals(3,model.resolve("db","db",ObjectKind.CONSTRAINT,"t","é",true).size());
        var folded=model.resolve("db","db",ObjectKind.CONSTRAINT,"t","e",true);assertEquals(1,folded.size());assertEquals("FOREIGN KEY",folded.getFirst().properties().get("type"));
        var all=new ArrayList<MetadataObject>();model.resolveName(ObjectKind.CONSTRAINT,"e",true).forEach(all::add);assertEquals(folded,all);
        assertEquals(Set.of("CHECK","FOREIGN KEY","UNIQUE"),entries.stream().map(entry->entry.identity().signature()).collect(java.util.stream.Collectors.toSet()));assertTrue(entries.stream().allMatch(entry->entry.identity().nativeKey().isEmpty()));assertEquals(3,entries.stream().map(entry->entry.identity().key()).distinct().count());
        for(var entry:entries)assertEquals(entry.properties().get("type"),model.projection(entry).getIdentifier());
    }
    @Test void anOldDisjointAcquisitionCannotReplaceNewerGlobalRules()throws Exception{
        var oldRules=NativeCaseFixtures.rules(Engine.MYSQL,1);var nextRules=changed("new-version");
        var before=snapshot(oldRules,1,List.of(object(oldRules,"t","Σ",ObjectKind.COLUMN,"",Map.of())),Map.of(COLUMNS,available(COLUMNS)));var owner=new MetadataPlatform.Source(before);
        long oldTicket=owner.tickets.incrementAndGet();var acquired=new CountDownLatch(1);var release=new CountDownLatch(1);
        try(var worker=Executors.newSingleThreadExecutor()){
            var old=worker.submit(()->{acquired.countDown();assertTrue(release.await(5,TimeUnit.SECONDS));synchronized(owner){MetadataPlatform.commitSnapshot(owner,oldTicket,before);}return null;});
            assertTrue(acquired.await(5,TimeUnit.SECONDS));long newer=owner.tickets.incrementAndGet();var after=snapshot(nextRules,2,before.identities().values(),MetadataPlatform.ruleCoverage(before,nextRules));
            synchronized(owner){assertTrue(MetadataPlatform.commitSnapshot(owner,newer,after));}release.countDown();
            var failure=assertThrows(ExecutionException.class,()->old.get(5,TimeUnit.SECONDS));assertInstanceOf(MetadataPlatform.SupersededRefresh.class,failure.getCause());assertSame(after,owner.snapshot.get());assertSame(oldRules,before.rules());
        }finally{release.countDown();}
    }
    @Test void ownedPublicationCannotDowngradeOrReplaceCurrentDurableRules(){
        var rules=NativeCaseFixtures.rules(Engine.MYSQL,1);var owner=new MetadataPlatform.Source(snapshot(rules,1,List.of(),Map.of()));
        assertThrows(MetadataPlatform.SupersededRefresh.class,()->MetadataPlatform.checkRulesPublication(owner,100,changed("other"),true));
        assertThrows(MetadataPlatform.SupersededRefresh.class,()->MetadataPlatform.checkRulesPublication(owner,100,new IdentifierRules(Engine.MYSQL,1),false));
        assertDoesNotThrow(()->MetadataPlatform.checkRulesPublication(owner,1,rules,true));assertSame(rules,owner.snapshot.get().rules());
    }
    @Test void rekeyedOverlayRetainsExactTemporaryAndPendingIdentitiesAsStale(){
        var oldRules=NativeCaseFixtures.rules(Engine.MYSQL,1);var nextRules=changed("overlay-new");
        var temp=object(oldRules,"","Σ",ObjectKind.TABLE,"session",Map.of("temporary","true"));var pending=object(oldRules,"","pending",ObjectKind.TABLE,"",Map.of());
        var scope=new MetadataScope("db","db","",ObjectKind.TABLE);MetadataSnapshot old;try{old=MetadataSnapshot.compose(snapshot(oldRules,1,List.of(),Map.of()),List.of(temp,pending),Set.of(scope),Map.of(scope,available(scope)),Set.of(),1,1,1,Long.MAX_VALUE);}catch(java.util.concurrent.TimeoutException impossible){throw new AssertionError(impossible);}
        var current=snapshot(nextRules,2,List.of(),Map.of());var rebased=MetadataPlatform.rebaseOverlay(current,old,Set.of(scope),"session");
        var retained=rebased.identity(temp.identity().key()).orElseThrow();assertEquals(temp.identity(),retained.identity());assertSame(temp.properties(),retained.properties());assertEquals("σ",retained.lookupKey());
        assertTrue(rebased.identity(pending.identity().key()).isPresent());assertEquals(MetadataState.STALE,rebased.coverage(scope).orElseThrow().state());assertEquals(MetadataState.AVAILABLE,old.coverage(scope).orElseThrow().state());
    }
    @Test void normalizedPhysicalFactsCannotCrossARuleFingerprint(){
        var old=NativeCaseFixtures.rules(Engine.MYSQL,1);var next=changed("facts-new");var name=new MetadataSnapshot.RelationName("db","db","Σ");
        var temp=object(old,"","Σ",ObjectKind.TABLE,"session",Map.of("temporary","true"));var names=new MetadataScope("db","db","",ObjectKind.TABLE,"Σ",true,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED);
        var owned=new MetadataSnapshot.OwnedRelationEvidence(temp,names,available(names),null,null);
        var facts=new MetadataSnapshot.SessionResolution(MetadataState.UNKNOWN,"session",7,"opaque",Map.of(name,MetadataSnapshot.PhysicalRelationKind.TEMPORARY,new MetadataSnapshot.RelationName("db","db","persistent"),MetadataSnapshot.PhysicalRelationKind.PERSISTENT),Map.of(name,owned));
        assertSame(facts,MetadataPlatform.ruleResolution("session",facts,old.fingerprint(),old));
        var retired=MetadataPlatform.ruleResolution("session",facts,old.fingerprint(),next);assertEquals(MetadataState.UNKNOWN,retired.state());assertTrue(retired.verified().isEmpty());assertTrue(retired.owned().isEmpty());assertEquals(2,facts.verified().size());assertEquals(1,facts.owned().size());
    }
    @Test void provisionalEvidenceCannotAdmitAvailableOrRollbackRecoverableProof(){
        var owner=new MetadataPlatform.Source(snapshot(new IdentifierRules(Engine.MYSQL,0),1,List.of(),Map.of()));
        var proof=new RetainedMetadataProof("source",1,1,"db","db","t","table","generation",Map.of(1,new RetainedMetadataProof.ColumnProof("column","","INT","shape")),MetadataState.AVAILABLE,"");
        var fence=new MetadataPlatform.ProofFence("source",owner.owner,owner.proofEpoch);
        for(var candidate:List.of(proof,proof.invalidate("Recoverable console rollback"))){
            var denied=MetadataPlatform.admitProof(owner,fence,candidate);assertEquals(MetadataState.UNAVAILABLE,denied.state());assertFalse(denied.available());assertFalse(denied.capturedStructure());
        }
        assertTrue(proof.available());assertTrue(proof.capturedStructure());
    }
}
