package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.analysis.*;
import io.busystack.busydata.analysis.language.ResolutionContext;
import java.lang.ref.WeakReference;
import java.util.*;
import java.util.concurrent.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class MetadataOwnedCompositionTest {
    private static final IdentifierRules PG=new IdentifierRules(Engine.POSTGRESQL,0);
    private static MetadataObject object(String schema,String parent,String name,ObjectKind kind,String owner,Map<String,String> properties){return MetadataObject.from("source","profile",owner,PG,SchemaObject.newBuilder().setCatalog("db").setSchema(schema).setTable(parent).setName(name).setKind(kind).putAllProperties(properties).build(),IntrospectionLevel.STRUCTURE,1,1);}
    private static MetadataObject table(String name){return object("public","",name,ObjectKind.TABLE,"",Map.of());}
    private static MetadataScope scope(ObjectKind kind,String parent){return new MetadataScope("db","public",parent,kind);}
    private static MetadataScope point(String name){return new MetadataScope("db","public","",ObjectKind.TABLE,name,true,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED);}
    private static MetadataCoverage coverage(MetadataScope scope){return new MetadataCoverage(scope,IntrospectionLevel.STRUCTURE,MetadataState.AVAILABLE,true,"verified",1,1,1,"");}
    private static MetadataSnapshot base(Collection<MetadataObject> objects,Map<MetadataScope,MetadataCoverage> coverage){return new MetadataSnapshot("source","profile",1,1,1,PG,objects,coverage);}
    private static MetadataSnapshot compose(MetadataSnapshot base,Collection<MetadataObject> objects,Set<MetadataScope> scopes,Map<MetadataScope,MetadataCoverage> coverage,Set<MetadataScope> removed)throws Exception{return MetadataSnapshot.compose(base,objects,scopes,coverage,removed,2,1,2,System.nanoTime()+TimeUnit.SECONDS.toNanos(10));}

    @Test void sharedNamespaceLookupSortProjectionAndImmutablePreviousViewAgree()throws Exception{
        var a=table("a");var old=table("middle");var z=table("z");var base=base(List.of(a,old,z),Map.of());
        var replacement=object("public","","middle",ObjectKind.TABLE,"",Map.of("remarks","uncommitted"));var b=table("b");var y=table("y");
        var view=compose(base,List.of(b,replacement,y),Set.of(point("b"),point("middle"),point("y")),Map.of(),Set.of());
        var names=view.namespace("db","public",ObjectKind.TABLE,"");assertEquals(List.of("a","b","middle","y","z"),names.stream().map(x->x.identity().name()).toList());
        for(int i=0;i<names.size();i++)assertEquals(List.of("a","b","middle","y","z").get(i),names.get(i).identity().name());
        assertSame(replacement,view.resolve("db","public",ObjectKind.TABLE,"","middle",true).getFirst());assertSame(old,base.identity(old.identity().key()).orElseThrow());assertSame(a,view.identity(a.identity().key()).orElseThrow());
        assertEquals(List.of("a","z","b","middle","y"),view.objects().stream().map(SchemaObject::getName).toList());
        assertThrows(UnsupportedOperationException.class,()->view.identities().clear());assertThrows(UnsupportedOperationException.class,()->names.clear());assertThrows(UnsupportedOperationException.class,()->view.catalogCoverage().clear());
    }

    @Test void rankedMaskedWideBranchesRetainIndexedQualifiedAndGlobalNameLookup()throws Exception{
        var objects=new ArrayList<MetadataObject>();for(int table=0;table<30;table++){String parent="t"+table;objects.add(table(parent));for(int col=0;col<100;col++)objects.add(object("public",parent,"f%03d".formatted(col),ObjectKind.COLUMN,"",Map.of("type","integer","jdbcType","4")));}
        var base=base(objects,Map.of());var replacement=object("public","t13","f150",ObjectKind.COLUMN,"",Map.of("type","text","jdbcType","12"));var mask=scope(ObjectKind.COLUMN,"t13");var view=compose(base,List.of(replacement),Set.of(mask),Map.of(mask,coverage(mask)),Set.of());
        var expected=objects.stream().filter(o->o.identity().kind()==ObjectKind.COLUMN&&!o.identity().parent().equals("t13")).collect(java.util.stream.Collectors.toCollection(ArrayList::new));expected.add(replacement);expected.sort(Comparator.comparing((MetadataObject o)->o.identity().name()).thenComparing(o->o.identity().parent()).thenComparing(o->o.identity().signature()));
        var aggregate=view.namespace("db","public",ObjectKind.COLUMN,"");assertEquals(expected.size(),aggregate.size());for(int i=0;i<expected.size();i++)assertSame(expected.get(i),aggregate.get(i));assertEquals(expected,new ArrayList<>(aggregate));
        assertSame(base.namespace("db","public",ObjectKind.COLUMN,"t12"),view.namespace("db","public",ObjectKind.COLUMN,"t12"));assertEquals(List.of(replacement),view.namespace("db","public",ObjectKind.COLUMN,"t13"));
        assertEquals(29,java.util.stream.StreamSupport.stream(view.resolveName(ObjectKind.COLUMN,"f010",true).spliterator(),false).count());assertEquals(2901,java.util.stream.StreamSupport.stream(view.kind(ObjectKind.COLUMN).spliterator(),false).count());
        assertEquals(base.resolve("db","public",ObjectKind.TABLE,"","t13",true).getFirst().identity().key(),view.projection(replacement).getParentIdentity());
    }

    @Test void packedRanksHandleEmptyBlocksAndPartialFinalWords()throws Exception{
        var objects=new ArrayList<MetadataObject>();for(int col=0;col<513;col++)objects.add(object("public","wide","c%03d".formatted(col),ObjectKind.COLUMN,"",Map.of()));var base=base(objects,Map.of());var masks=new HashSet<MetadataScope>();for(int col=0;col<256;col++)masks.add(new MetadataScope("db","public","wide",ObjectKind.COLUMN,"c%03d".formatted(col),true,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED));for(int col:List.of(511,512))masks.add(new MetadataScope("db","public","wide",ObjectKind.COLUMN,"c%03d".formatted(col),true,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED));var view=compose(base,List.of(),masks,Map.of(),Set.of());var values=view.namespace("db","public",ObjectKind.COLUMN,"wide");assertEquals(255,values.size());for(int at=0;at<values.size();at++)assertEquals("c%03d".formatted(at+256),values.get(at).identity().name());assertEquals(new ArrayList<>(values),values.stream().toList());
    }

    @Test void equalSortKeysRetainBaseBeforeOwnedEncounterOrder()throws Exception{
        var function=MetadataObject.from("source","profile","",PG,SchemaObject.newBuilder().setCatalog("db").setSchema("public").setKind(ObjectKind.ROUTINE).setSubtype(ObjectSubtype.FUNCTION).setName("same").setIdentifier("same(integer)").build(),IntrospectionLevel.STRUCTURE,1,1);var procedure=MetadataObject.from("source","profile","",PG,SchemaObject.newBuilder().setCatalog("db").setSchema("public").setKind(ObjectKind.ROUTINE).setSubtype(ObjectSubtype.PROCEDURE).setName("same").setIdentifier("same(integer)").build(),IntrospectionLevel.STRUCTURE,1,1);var base=base(List.of(function),Map.of());var scope=new MetadataScope("db","public","",ObjectKind.ROUTINE,"same",true,"same(integer)",ObjectSubtype.PROCEDURE);var view=compose(base,List.of(procedure),Set.of(scope),Map.of(scope,coverage(scope)),Set.of());var values=view.namespace("db","public",ObjectKind.ROUTINE,"");assertEquals(List.of(function,procedure),new ArrayList<>(values));assertSame(function,values.get(0));assertSame(procedure,values.get(1));
    }

    @Test void manyExactScopesUseIndexedMasksAndShareUntouchedNativeIndexes()throws Exception{
        var objects=new ArrayList<MetadataObject>();for(int row=0;row<4000;row++)objects.add(table("visible_"+row));var base=base(objects,Map.of());var masks=new HashSet<MetadataScope>();for(int row=0;row<100000;row++)masks.add(point("masked_"+row));var view=compose(base,List.of(),masks,Map.of(),Set.of());assertEquals(4000,view.identities().size());assertSame(base.indexes().identities(),view.indexes().identities());assertSame(base.namespace("db","public",ObjectKind.TABLE,""),view.namespace("db","public",ObjectKind.TABLE,""));assertSame(base.indexes().kinds().get(ObjectKind.TABLE),view.indexes().kinds().get(ObjectKind.TABLE));assertSame(base.indexes().parents(),view.indexes().parents());assertSame(base.indexes().incoming(),view.indexes().incoming());
    }

    @Test void pgPhysicalTemporaryNamespaceNeverHidesExplicitPersistentNamespace()throws Exception{
        var permanent=table("same");var base=base(List.of(permanent),Map.of());var temporary=object("pg_temp_42","","same",ObjectKind.TABLE,"physical-one",Map.of("temporary","true"));var mask=new MetadataScope("db","pg_temp_42","",ObjectKind.TABLE);
        var view=compose(base,List.of(temporary),Set.of(mask),Map.of(mask,coverage(mask)),Set.of());assertSame(permanent,view.resolve("db","public",ObjectKind.TABLE,"","same",true).getFirst());assertSame(temporary,view.resolve("db","pg_temp_42",ObjectKind.TABLE,"","same",true).getFirst());assertTrue(base.resolve("db","pg_temp_42",ObjectKind.TABLE,"","same",true).isEmpty());
    }

    @Test void ownedForeignKeyReplacementChangesIncomingAndOutgoingTogether()throws Exception{
        var old=object("public","source_table","old_fk",ObjectKind.FOREIGN_KEY,"",Map.of("relationshipVerified","true","referencedCatalog","db","referencedSchema","public","referencedTable","old_target"));
        var next=object("public","source_table","next_fk",ObjectKind.FOREIGN_KEY,"",Map.of("relationshipVerified","true","referencedCatalog","db","referencedSchema","public","referencedTable","new_target"));var base=base(List.of(table("source_table"),table("old_target"),table("new_target"),old),Map.of());var mask=scope(ObjectKind.FOREIGN_KEY,"source_table");
        var view=compose(base,List.of(next),Set.of(mask),Map.of(mask,coverage(mask)),Set.of());assertEquals(List.of(next),view.outgoing("db","public","source_table"));assertTrue(view.incoming("db","public","old_target").isEmpty());assertEquals(List.of(next),view.incoming("db","public","new_target"));assertEquals(List.of(old),base.incoming("db","public","old_target"));
    }

    @Test void sparseCoverageTombstonesAndRepeatedInvalidationNeverChangeCapturedFacts()throws Exception{
        var exact=point("one");var column=scope(ObjectKind.COLUMN,"one");var base=base(List.of(table("one")),Map.of(exact,coverage(exact),column,coverage(column)));var view=compose(base,List.of(),Set.of(column),Map.of(),Set.of(column));assertTrue(view.coverage(column).isEmpty());assertTrue(base.complete(column,IntrospectionLevel.STRUCTURE));
        var stale=coverage(exact).stale("owned invalidation");var changed=view.withCoverageOverrides(3,Map.of(exact,stale));assertFalse(changed.complete(exact,IntrospectionLevel.NAMES));assertTrue(view.complete(exact,IntrospectionLevel.NAMES));assertSame(view.indexes().namespaces(),changed.indexes().namespaces());assertSame(view.indexes().identities(),changed.indexes().identities());
        var twice=changed.withCoverageOverrides(4,Map.of(exact,stale));assertEquals(1,twice.localCoverage().size());assertTrue(twice.removedCoverageScopes().contains(column));assertThrows(IllegalArgumentException.class,()->base.withCoverageOverrides(3,Map.of()));
    }

    @Test void globalCoverageInvalidationRebasesWithoutRebuildingAnyCatalogIndex()throws Exception{
        var exact=point("one");var base=base(List.of(table("one")),Map.of(exact,coverage(exact)));var local=object("public","one","value",ObjectKind.COLUMN,"",Map.of());var mask=scope(ObjectKind.COLUMN,"one");var view=compose(base,List.of(local),Set.of(mask),Map.of(mask,coverage(mask)),Set.of());
        assertTrue(view.canRebaseCoverageOnto(base));assertFalse(base.canRebaseCoverageOnto(base));assertFalse(view.canRebaseCoverageOnto(view));
        var invalidated=base.withCoverage(4,Map.of(exact,coverage(exact).stale("external ddl")));assertTrue(view.canRebaseCoverageOnto(invalidated));var rebased=view.rebaseComposed(invalidated,5,1,5,System.nanoTime()+TimeUnit.SECONDS.toNanos(1));assertSame(view.indexes().identities(),rebased.indexes().identities());assertSame(view.indexes().namespaces(),rebased.indexes().namespaces());assertSame(local,rebased.identity(local.identity().key()).orElseThrow());assertFalse(rebased.complete(exact,IntrospectionLevel.NAMES));assertTrue(view.complete(exact,IntrospectionLevel.NAMES));
    }

    @Test void changedDurableGenerationIsRebasedOneHopAndKeepsPreviousReadersImmutable()throws Exception{
        var first=table("one");var base=base(List.of(first),Map.of());var own=object("public","one","local",ObjectKind.COLUMN,"",Map.of());var mask=scope(ObjectKind.COLUMN,"one");var old=compose(base,List.of(own),Set.of(mask),Map.of(mask,coverage(mask)),Set.of());var added=table("two");var next=new MetadataSnapshot("source","profile",4,1,4,PG,List.of(first,added),Map.of());assertFalse(old.canRebaseCoverageOnto(next));var rebased=old.rebaseComposed(next,5,1,5,System.nanoTime()+TimeUnit.SECONDS.toNanos(1));assertTrue(old.identity(added.identity().key()).isEmpty());assertSame(added,rebased.identity(added.identity().key()).orElseThrow());assertSame(own,rebased.identity(own.identity().key()).orElseThrow());assertThrows(IllegalArgumentException.class,()->compose(rebased,List.of(),Set.of(),Map.of(),Set.of()));
        var unknown=new MetadataSnapshot.SessionResolution(MetadataState.UNKNOWN,"physical-one",1,"opaque effects",Map.of());var captured=old.withSessionResolution(7,unknown).withIdentifierAvailability(false);var stillUnknown=captured.rebaseComposed(next,8,1,8,System.nanoTime()+TimeUnit.SECONDS.toNanos(1));assertSame(unknown,stillUnknown.sessionResolution());assertFalse(stillUnknown.identifierRulesAvailable());
    }

    @Test void compositionAdmissionDeduplicatesSharedObjectsButChargesEveryNewIndex()throws Exception{
        var global=table("one");var base=base(List.of(global),Map.of());var local=object("public","one","local",ObjectKind.COLUMN,"",Map.of("type","numeric(38,12)"));var scope=scope(ObjectKind.COLUMN,"one");var coverage=Map.of(scope,coverage(scope));var old=compose(base,List.of(local),Set.of(scope),coverage,Set.of());var shared=MetadataSnapshot.estimateComposition(base,old,List.of(local),Set.of(scope),coverage,Set.of());var fresh=MetadataSnapshot.estimateComposition(base,null,List.of(local),Set.of(scope),coverage,Set.of());assertTrue(shared.allocationBytes()>0);assertTrue(shared.allocationBytes()<shared.residentBytes());assertEquals(fresh.residentBytes(),shared.residentBytes());assertTrue(fresh.allocationBytes()>shared.allocationBytes());
    }

    @Test void pendingPersistentFactsCannotBePersistedAndEmptyInventoryReusesExactDurable()throws Exception{
        var global=table("one");var base=base(List.of(global),Map.of());assertSame(base,compose(base,List.of(),Set.of(),Map.of(),Set.of()));assertEquals(new MetadataSnapshot.CompositionCharge(0,0),MetadataSnapshot.estimateComposition(base,null,List.of(),Set.of(),Map.of(),Set.of()));var pending=object("public","","one",ObjectKind.TABLE,"",Map.of("remarks","pending"));var view=compose(base,List.of(pending),Set.of(point("one")),Map.of(),Set.of());assertTrue(pending.identity().sessionOwner().isEmpty());assertTrue(view.composed());assertThrows(IllegalStateException.class,view::persistenceObjects);
    }

    @Test void capturedLazyAllScopeStalenessDoesNotLeakToOtherPhysicalViewsOrBlockFreshLocalFacts()throws Exception{
        var table=table("one");var columns=scope(ObjectKind.COLUMN,"one");var tables=scope(ObjectKind.TABLE,"");var base=base(List.of(table),Map.of(tables,coverage(tables),columns,coverage(columns)));
        var stale=base.withAllCoverageStale(2,"uncommitted structure");assertTrue(stale.composed());assertTrue(stale.localIdentities().isEmpty());assertTrue(stale.localCoverage().isEmpty());assertTrue(stale.replacementScopes().isEmpty());assertSame(base.indexes().identities(),stale.indexes().identities());assertSame(base.indexes().namespaces(),stale.indexes().namespaces());assertFalse(stale.complete(columns,IntrospectionLevel.STRUCTURE));assertTrue(base.complete(columns,IntrospectionLevel.STRUCTURE));assertEquals(MetadataState.STALE,stale.coverage(columns).orElseThrow().state());
        var one=object("public","one","fresh",ObjectKind.COLUMN,"",Map.of());var fresh=compose(base,List.of(one),Set.of(columns),Map.of(columns,coverage(columns)),Set.of()).withInheritedCoverageStale(3,stale.allCoverageStaleReason());assertTrue(fresh.complete(columns,IntrospectionLevel.STRUCTURE));assertFalse(fresh.complete(tables,IntrospectionLevel.NAMES));assertEquals(1,fresh.localCoverage().size());assertFalse(stale.complete(columns,IntrospectionLevel.STRUCTURE));
        var again=fresh.withAllCoverageStale(4,"later statement");assertFalse(again.complete(columns,IntrospectionLevel.NAMES));assertTrue(fresh.complete(columns,IntrospectionLevel.STRUCTURE));assertEquals("later statement",again.allCoverageStaleReason());assertEquals(1,again.localCoverage().size());assertSame(fresh.indexes().identities(),again.indexes().identities());assertTrue(again.estimatedBytes()<64*1024);
    }

    @Test void qualifiedPostgresDiagnosticsWithholdOldColumnAuthorityDuringOwnedAllScopeStaleness()throws Exception{
        var table=table("one");var column=object("public","one","id",ObjectKind.COLUMN,"",Map.of("type","integer","nativeType","int4","jdbcType","4"));var states=new HashMap<MetadataScope,MetadataCoverage>();for(var kind:List.of(ObjectKind.TABLE,ObjectKind.VIEW,ObjectKind.SEQUENCE)){var scope=scope(kind,"");states.put(scope,coverage(scope));}var columns=scope(ObjectKind.COLUMN,"one");states.put(columns,coverage(columns));var base=base(List.of(table,column),states);var owner=base.withAllCoverageStale(2,"uncommitted structural change");String sql="SELECT missing FROM public.one";var request=AnalysisRequest.newBuilder().setEngine(Engine.POSTGRESQL).setDocumentId("owned-stale").setDocumentVersion(1).setOperation(AnalysisOperation.DIAGNOSTICS).setSql(sql).setCaretUtf16(sql.length()).build();var service=new SqlAnalysis();
        var freshContext=new ResolutionContext("db","public",List.of("public"),true,base.revision(),base.configurationRevision(),PG,base);var original=service.analyze(request,LexicalSettings.DEFAULT,freshContext);assertTrue(original.getDiagnosticsList().stream().anyMatch(d->d.getCode().equals("binding.unresolved-column")));
        var ownerContext=new ResolutionContext("db","public",List.of("public"),true,owner.revision(),owner.configurationRevision(),PG,owner);var unavailable=service.analyze(request,LexicalSettings.DEFAULT,ownerContext);assertTrue(unavailable.getDiagnosticsList().stream().anyMatch(d->d.getCode().equals("metadata.incomplete")&&d.getIncomplete()));assertFalse(unavailable.getDiagnosticsList().stream().anyMatch(d->d.getCode().equals("binding.unresolved-column")));assertTrue(base.complete(columns,IntrospectionLevel.STRUCTURE));assertFalse(owner.complete(columns,IntrospectionLevel.STRUCTURE));
    }

    @Test void changedNativeIdentifierAuthorityNeedsExplicitScopeReconciliation()throws Exception{
        var base=base(List.of(table("one")),Map.of());var scope=point("one");var view=compose(base,List.of(table("one")),Set.of(scope),Map.of(),Set.of());
        var changed=new MetadataSnapshot("source","profile",3,1,3,new IdentifierRules(Engine.MYSQL,0),List.of(),Map.of());assertFalse(view.canRebaseCoverageOnto(changed));assertThrows(IllegalArgumentException.class,()->view.rebaseComposed(changed,4,1,4,System.nanoTime()+TimeUnit.SECONDS.toNanos(1)));assertThrows(TimeoutException.class,()->view.rebaseComposed(base,4,1,4,System.nanoTime()-1));
    }

    @Test void malformedOwnedScopeAndCancelledExpiredPreparationAreRejected()throws Exception{
        var base=base(List.of(table("one")),Map.of());assertThrows(IllegalArgumentException.class,()->compose(base,List.of(table("outside")),Set.of(point("one")),Map.of(),Set.of()));var scope=point("one");try(var context=io.grpc.Context.current().withCancellation()){context.cancel(null);assertThrows(CancellationException.class,()->context.call(()->compose(base,List.of(),Set.of(scope),Map.of(),Set.of())));}assertThrows(TimeoutException.class,()->MetadataSnapshot.compose(base,List.of(),Set.of(scope),Map.of(),Set.of(),2,1,2,System.nanoTime()-1));
    }
}
