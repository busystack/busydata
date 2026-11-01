package io.busystack.busydata;

import io.busystack.busydata.analysis.*;
import io.busystack.busydata.analysis.language.*;
import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import static org.junit.jupiter.api.Assertions.*;

/** No connection or mutable session is available to these semantic readers. */
class SessionResolutionTest {
    private static String schema(Engine engine){return engine==Engine.POSTGRESQL?"public":"db";}
    private static MetadataSnapshot base(Engine engine){
        var rules=io.busystack.busydata.NativeCaseFixtures.rules(engine,0);String schema=schema(engine);var objects=new ArrayList<MetadataObject>();var coverage=new HashMap<MetadataScope,MetadataCoverage>();
        for(String table:List.of("t","u")){
            objects.add(object(rules,schema,"",table,ObjectKind.TABLE,Map.of()));
            objects.add(object(rules,schema,table,"id",ObjectKind.COLUMN,Map.of("nativeType","integer","jdbcType","4")));
            objects.add(object(rules,schema,table,"persistent_only",ObjectKind.COLUMN,Map.of("nativeType","text","jdbcType","12")));
            for(var kind:List.of(ObjectKind.COLUMN,ObjectKind.FOREIGN_KEY))put(coverage,new MetadataScope("db",schema,table,kind));
        }
        objects.add(object(rules,schema,"t","t_u",ObjectKind.FOREIGN_KEY,Map.of("relationshipVerified","true","columnCount","1","column.0","id","referencedColumn.0","id","referencedCatalog","db","referencedSchema",schema,"referencedTable","u")));
        objects.add(object(rules,schema,"","work",ObjectKind.ROUTINE,Map.of("signature","work(integer)","parameterCount","1","parameter.0.name","value","parameter.0.type","integer","parameter.0.nativeTypeId","23","returnType","integer","signatureAvailability","AVAILABLE")));
        for(String namespace:engine==Engine.POSTGRESQL?List.of("pg_catalog",schema):List.of(schema))for(var kind:List.of(ObjectKind.TABLE,ObjectKind.VIEW,ObjectKind.SEQUENCE,ObjectKind.ROUTINE))put(coverage,new MetadataScope("db",namespace,"",kind));
        return new MetadataSnapshot("source","profile",7,2,123,rules,objects,coverage);
    }
    private static MetadataObject object(IdentifierRules rules,String schema,String parent,String name,ObjectKind kind,Map<String,String> properties){return MetadataObject.from("source","profile","",rules,SchemaObject.newBuilder().setCatalog("db").setSchema(schema).setTable(parent).setName(name).setKind(kind).putAllProperties(properties).build(),IntrospectionLevel.STRUCTURE,3,4);}
    private static void put(Map<MetadataScope,MetadataCoverage> coverage,MetadataScope scope){coverage.put(scope,new MetadataCoverage(scope,IntrospectionLevel.STRUCTURE,MetadataState.AVAILABLE,true,"shape",3,4,123,""));}
    private static MetadataSnapshot unknown(MetadataSnapshot base,Map<MetadataSnapshot.RelationName,MetadataSnapshot.PhysicalRelationKind> verified){return base.withSessionResolution(20,new MetadataSnapshot.SessionResolution(MetadataState.UNKNOWN,"physical",11,"Opaque execution needs an owned-session check",verified));}
    private static ResolutionContext context(MetadataSnapshot snapshot){return new ResolutionContext("db",schema(snapshot.rules().engine()),List.of(schema(snapshot.rules().engine())),true,snapshot.revision(),snapshot.configurationRevision(),snapshot.rules(),snapshot,"");}
    private static Analysis analyze(MetadataSnapshot snapshot,String marked,AnalysisOperation operation){int caret=marked.indexOf('|');String sql=marked.replace("|","");if(caret<0)caret=sql.length();return new SqlAnalysis().analyze(AnalysisRequest.newBuilder().setEngine(snapshot.rules().engine()).setDocumentId("doc").setDocumentVersion(1).setSql(sql).setCaretUtf16(caret).setOperation(operation).build(),LexicalSettings.DEFAULT,context(snapshot));}

    @ParameterizedTest @EnumSource(value=Engine.class,names={"POSTGRESQL","MYSQL","MARIADB"})
    void immutableSessionViewsShareEveryCatalogIndexAndProjectTheirOwnRevision(Engine engine){
        var base=base(engine);var captured=unknown(base,Map.of());
        assertSame(base.identities(),captured.identities());assertSame(base.catalogCoverage(),captured.catalogCoverage());
        assertSame(base.namespace("db",schema(engine),ObjectKind.COLUMN,"t"),captured.namespace("db",schema(engine),ObjectKind.COLUMN,"t"));
        assertEquals(20,captured.objects().getFirst().getMetadataSnapshotRevision());assertEquals(7,base.objects().getFirst().getMetadataSnapshotRevision());
        assertEquals(MetadataState.AVAILABLE,base.sessionResolution().state());assertEquals(MetadataState.UNKNOWN,captured.sessionResolution().state());
        assertThrows(UnsupportedOperationException.class,()->captured.coverage().clear());assertThrows(UnsupportedOperationException.class,()->captured.sessionResolution().verified().clear());
        var changed=new HashMap<>(base.catalogCoverage());var scope=new MetadataScope("db",schema(engine),"t",ObjectKind.COLUMN);changed.put(scope,changed.get(scope).stale("External change"));var stale=base.withCoverage(8,changed);
        assertSame(base.identities(),stale.identities());assertTrue(base.complete(scope,IntrospectionLevel.STRUCTURE));assertFalse(stale.complete(scope,IntrospectionLevel.STRUCTURE));
    }

    @ParameterizedTest @EnumSource(value=Engine.class,names={"MYSQL","MARIADB"})
    void qualifiedDatabaseNamesDoNotBypassUnknownTemporaryShadowing(Engine engine){
        var base=base(engine);var captured=unknown(base,Map.of());var columns=new MetadataScope("db","db","t",ObjectKind.COLUMN);
        assertFalse(captured.relationLookupAvailable("db","db","t",true));assertFalse(captured.relationResolutionAvailable("db","db","t","physical"));
        assertFalse(captured.complete(columns,IntrospectionLevel.STRUCTURE));assertEquals(MetadataState.UNKNOWN,captured.coverage(columns).orElseThrow().state());assertEquals(MetadataState.UNKNOWN,captured.coverage().get(columns).state());
        var table=captured.resolve("db","db",ObjectKind.TABLE,"","t",true).getFirst();assertEquals("UNKNOWN",captured.projection(table).getMetadataState());assertEquals("AVAILABLE",base.projection(table).getMetadataState());
        var completion=analyze(captured,"SELECT t.per| FROM db.t t",AnalysisOperation.COMPLETION);assertEquals("incomplete-metadata",completion.getAvailability());assertFalse(completion.getCompletionsList().stream().anyMatch(item->item.getKind().equals("column")));
        var diagnostics=analyze(captured,"SELECT t.missing FROM db.t t",AnalysisOperation.DIAGNOSTICS).getDiagnosticsList();assertTrue(diagnostics.stream().anyMatch(Diagnostic::getIncomplete));assertFalse(diagnostics.stream().anyMatch(item->item.getCode().equals("binding.unresolved-column")));
    }

    @Test void postgresPersistentQualificationRemainsDistinctFromUnqualifiedTempResolution(){
        var captured=unknown(base(Engine.POSTGRESQL),Map.of());assertTrue(captured.relationLookupAvailable("db","public","t",true));assertFalse(captured.relationLookupAvailable("db","public","t",false));assertFalse(captured.relationLookupAvailable("db","pg_temp_7","t",true));
        assertTrue(analyze(captured,"SELECT t.per| FROM public.t t",AnalysisOperation.COMPLETION).getCompletionsList().stream().anyMatch(item->item.getLabel().equals("persistent_only")));
        assertFalse(analyze(captured,"SELECT t.per| FROM t t",AnalysisOperation.COMPLETION).getCompletionsList().stream().anyMatch(item->item.getKind().equals("column")));
    }

    @ParameterizedTest @EnumSource(value=Engine.class,names={"MYSQL","MARIADB"})
    void exactNativeFactsNeverUpgradeAnUnverifiedTargetOrWholeInventory(Engine engine){
        var base=base(engine);var first=unknown(base,Map.of());var own=new MetadataSnapshot.RelationName("db","db","t");var other=new MetadataSnapshot.RelationName("db","db","u");
        var one=unknown(base,Map.of(own,MetadataSnapshot.PhysicalRelationKind.PERSISTENT));
        assertTrue(one.relationResolutionAvailable("db","db","t","physical"));assertFalse(one.relationResolutionAvailable("db","db","t","forged"));assertFalse(one.relationResolutionAvailable("db","db","u","physical"));assertFalse(first.relationResolutionAvailable("db","db","t","physical"));
        assertEquals(MetadataState.UNKNOWN,one.sessionResolution().state());assertFalse(one.incomingComplete());
        assertTrue(analyze(one,"SELECT t.per| FROM db.t t",AnalysisOperation.COMPLETION).getCompletionsList().stream().anyMatch(item->item.getLabel().equals("persistent_only")));
        var relationship=base.outgoing("db","db","t").getFirst();assertTrue(base.relationshipComplete(relationship));assertFalse(one.relationshipComplete(relationship));
        var both=unknown(base,Map.of(own,MetadataSnapshot.PhysicalRelationKind.PERSISTENT,other,MetadataSnapshot.PhysicalRelationKind.PERSISTENT));assertTrue(both.relationshipComplete(relationship));
        for(var kind:List.of(MetadataSnapshot.PhysicalRelationKind.TEMPORARY,MetadataSnapshot.PhysicalRelationKind.ABSENT)){var observed=unknown(base,Map.of(own,kind));assertFalse(observed.relationResolutionAvailable("db","db","t","physical"));assertFalse(observed.relationMatchesResolution("db","db","t",""));assertFalse(observed.complete(new MetadataScope("db","db","t",ObjectKind.COLUMN),IntrospectionLevel.STRUCTURE));}
    }

    @ParameterizedTest @EnumSource(value=Engine.class,names={"POSTGRESQL","MYSQL","MARIADB"})
    void routineObjectFieldsCannotOverrideStaleCoverageIncludingUnknownSession(Engine engine){
        var base=base(engine);String qualified=schema(engine)+".work";var document=LosslessLexer.scan("SELECT "+qualified+"(",new Dialect(engine,LexicalSettings.DEFAULT),AnalysisBudget.interactive());
        var complete=new SemanticCatalog(document.dialect(),context(base),AnalysisBudget.interactive());assertTrue(complete.routines(qualifiedName(qualified,engine)).getFirst().complete());
        assertTrue(analyze(base,"SELECT "+qualified+"(1,2)",AnalysisOperation.DIAGNOSTICS).getDiagnosticsList().stream().anyMatch(d->d.getCode().equals("routine.argument-count")),"The complete baseline must actually inspect this call");
        var scope=new MetadataScope("db",schema(engine),"",ObjectKind.ROUTINE);var staleCoverage=new HashMap<>(base.catalogCoverage());staleCoverage.put(scope,staleCoverage.get(scope).stale("Opaque routine changed structure"));var stale=base.withCoverage(8,staleCoverage);
        for(var snapshot:List.of(stale,unknown(stale,Map.of()))){
            var catalog=new SemanticCatalog(document.dialect(),context(snapshot),AnalysisBudget.interactive());assertFalse(catalog.routines(qualifiedName(qualified,engine)).getFirst().complete());
            var information=ParameterService.information(document,catalog,document.source().length(),AnalysisBudget.interactive());assertEquals(1,information.getOverloadsCount());assertEquals("partial-signatures",information.getAvailability());
            assertFalse(analyze(snapshot,"SELECT "+qualified+"(1,2)",AnalysisOperation.DIAGNOSTICS).getDiagnosticsList().stream().anyMatch(d->d.getCode().equals("routine.argument-count")));
        }
    }
    @ParameterizedTest @EnumSource(value=Engine.class,names={"POSTGRESQL","MYSQL","MARIADB"})
    void freshExactRoutineCoverageRecoversWithoutCertifyingUnknownRelationNames(Engine engine){
        var snapshot=unknown(base(engine),Map.of());String qualified=schema(engine)+".work";
        assertEquals(MetadataState.UNKNOWN,snapshot.sessionResolution().state());
        if(engine!=Engine.POSTGRESQL)assertFalse(snapshot.complete(new MetadataScope("db",schema(engine),"",ObjectKind.TABLE),IntrospectionLevel.NAMES));
        if(engine==Engine.POSTGRESQL)assertFalse(snapshot.relationLookupAvailable("db",schema(engine),"t",false));
        else assertFalse(snapshot.relationLookupAvailable("db",schema(engine),"t",true));
        var parameters=analyze(snapshot,"SELECT "+qualified+"(|",AnalysisOperation.PARAMETER_INFORMATION).getParameterInformation();
        assertEquals("available",parameters.getAvailability());assertEquals(1,parameters.getOverloadsCount());
        assertTrue(analyze(snapshot,"SELECT "+qualified+"(1,2)",AnalysisOperation.DIAGNOSTICS).getDiagnosticsList().stream().anyMatch(d->d.getCode().equals("routine.argument-count")),"Fresh routine coverage independently proves this qualified signature");
        assertTrue(analyze(snapshot,"SELECT "+schema(engine)+".missing(1)",AnalysisOperation.DIAGNOSTICS).getDiagnosticsList().stream().anyMatch(d->d.getCode().equals("routine.unknown")));
        assertEquals(MetadataState.UNKNOWN,snapshot.sessionResolution().state());
    }
    private static SyntaxTree.Name qualifiedName(String text,Engine engine){return new SyntaxTree.Name(LosslessLexer.scan(text,new Dialect(engine,LexicalSettings.DEFAULT),AnalysisBudget.interactive()).significant().stream().filter(LosslessLexer.Token::name).toList());}

    @ParameterizedTest @EnumSource(value=Engine.class,names={"MYSQL","MARIADB"})
    void temporaryNamesAndShapesRequireFreshSameEpochOwnedPublication(Engine engine){
        var old=temp(base(engine),"old_field",IntrospectionLevel.STRUCTURE);var key=new MetadataSnapshot.RelationName("db","db","t");var kind=Map.of(key,MetadataSnapshot.PhysicalRelationKind.TEMPORARY);var captured=unknown(old,kind);
        var tableScope=new MetadataScope("db","db","",ObjectKind.TABLE,"t",true,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED);var columnScope=new MetadataScope("db","db","t",ObjectKind.COLUMN);
        assertFalse(captured.complete(columnScope,IntrospectionLevel.STRUCTURE),"A native kind probe alone cannot verify an old temporary shape");
        assertFalse(analyze(captured,"SELECT t.old| FROM db.t t",AnalysisOperation.COMPLETION).getCompletionsList().stream().anyMatch(item->item.getKind().equals("column")));
        var names=temp(old,"old_field",IntrospectionLevel.NAMES);var namesObject=names.resolve("db","db",ObjectKind.TABLE,"","t",true).getFirst();
        var nameEvidence=new MetadataSnapshot.OwnedRelationEvidence(namesObject,tableScope,names.catalogCoverage().get(tableScope),columnScope,null);
        var namesView=names.withSessionResolution(21,new MetadataSnapshot.SessionResolution(MetadataState.UNKNOWN,"physical",11,"Unknown inventory",kind,Map.of(key,nameEvidence)));
        assertTrue(namesView.complete(tableScope,IntrospectionLevel.NAMES));assertFalse(namesView.complete(columnScope,IntrospectionLevel.STRUCTURE));assertEquals("AVAILABLE",namesView.projection(namesObject).getMetadataState());
        assertFalse(analyze(namesView,"SELECT t.old| FROM db.t t",AnalysisOperation.COMPLETION).getCompletionsList().stream().anyMatch(item->item.getKind().equals("column")),"Fresh Level1 names must not expose old Level2 columns");
        var fresh=temp(names,"new_field",IntrospectionLevel.STRUCTURE);var freshObject=fresh.resolve("db","db",ObjectKind.TABLE,"","t",true).getFirst();
        var evidence=new MetadataSnapshot.OwnedRelationEvidence(freshObject,tableScope,fresh.catalogCoverage().get(tableScope),columnScope,fresh.catalogCoverage().get(columnScope));
        var state=new MetadataSnapshot.SessionResolution(MetadataState.UNKNOWN,"physical",11,"Unknown inventory",kind,Map.of(key,evidence));var freshView=fresh.withSessionResolution(22,state);
        assertTrue(freshView.complete(columnScope,IntrospectionLevel.STRUCTURE));assertFalse(freshView.relationResolutionAvailable("db","db","t","physical"),"Temporary results remain ineligible for persistent mutation planning");
        assertTrue(analyze(freshView,"SELECT t.new| FROM db.t t",AnalysisOperation.COMPLETION).getCompletionsList().stream().anyMatch(item->item.getLabel().equals("new_field")));
        assertFalse(old.withSessionResolution(23,state).complete(columnScope,IntrospectionLevel.STRUCTURE),"A reader captured before publication cannot combine fresh evidence with an old catalog");
        assertFalse(captured.complete(columnScope,IntrospectionLevel.STRUCTURE));assertFalse(namesView.complete(columnScope,IntrospectionLevel.STRUCTURE));
        var nextEpoch=fresh.withSessionResolution(24,new MetadataSnapshot.SessionResolution(MetadataState.UNKNOWN,"physical",12,"Another opaque execution",kind));assertFalse(nextEpoch.complete(columnScope,IntrospectionLevel.STRUCTURE));
    }
    private static MetadataSnapshot temp(MetadataSnapshot base,String field,IntrospectionLevel level){
        var entries=new ArrayList<>(base.identities().values().stream().filter(o->!o.identity().name().equals("t")&&!o.identity().parent().equals("t")).toList());
        var table=SchemaObject.newBuilder().setCatalog("db").setSchema("db").setName("t").setKind(ObjectKind.TABLE).putProperties("temporary","true").build();
        entries.add(MetadataObject.from("source","profile","physical",base.rules(),table,level,3,4));
        entries.add(MetadataObject.from("source","profile","physical",base.rules(),table.toBuilder().setTable("t").setName(field).setKind(ObjectKind.COLUMN).putProperties("nativeType","integer").putProperties("jdbcType","4").build(),IntrospectionLevel.STRUCTURE,3,4));
        var coverage=new HashMap<>(base.catalogCoverage());var namesScope=new MetadataScope("db","db","",ObjectKind.TABLE,"t",true,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED);
        coverage.put(namesScope,new MetadataCoverage(namesScope,level,MetadataState.AVAILABLE,true,"fresh-name-"+field,3,4,124,""));if(level.includes(IntrospectionLevel.STRUCTURE))put(coverage,new MetadataScope("db","db","t",ObjectKind.COLUMN));
        return new MetadataSnapshot("source","profile",base.revision()+1,base.configurationRevision(),124,base.rules(),entries,coverage);
    }

    @Test void exactFactByteAndCountBudgetsRejectRatherThanCompletingAnUnknownInventory(){
        var names=new HashMap<MetadataSnapshot.RelationName,MetadataSnapshot.PhysicalRelationKind>();for(int index=0;index<2049;index++)names.put(new MetadataSnapshot.RelationName("db","db","t"+index),MetadataSnapshot.PhysicalRelationKind.PERSISTENT);
        assertThrows(IllegalArgumentException.class,()->new MetadataSnapshot.SessionResolution(MetadataState.UNKNOWN,"physical",1,"Unknown",names));
        names.clear();for(int index=0;index<400;index++)names.put(new MetadataSnapshot.RelationName("c".repeat(256),"s".repeat(256),Integer.toString(index)+"n".repeat(250)),MetadataSnapshot.PhysicalRelationKind.PERSISTENT);
        assertThrows(IllegalArgumentException.class,()->new MetadataSnapshot.SessionResolution(MetadataState.UNKNOWN,"physical",1,"Unknown",names));
        assertThrows(IllegalArgumentException.class,()->new MetadataSnapshot.RelationName("db","db","bad\0name"));
        assertThrows(IllegalArgumentException.class,()->new MetadataSnapshot.SessionResolution(MetadataState.UNKNOWN,"",0,"Unknown",Map.of()));
    }

    @ParameterizedTest @EnumSource(value=Engine.class,names={"POSTGRESQL","MYSQL","MARIADB"})
    void opaqueExecutionAlwaysProducesBothPersistentAndSessionConservativeImpact(Engine engine){
        for(String sql:List.of("CALL db.change_structure()","DO 'opaque body'","EXECUTE prepared_operation")){
            var effects=DdlImpact.analyze(sql,engine,LexicalSettings.DEFAULT,context(base(engine)));assertEquals(1,effects.size());var effect=effects.getFirst();assertTrue(effect.getConservative());assertFalse(effect.getTemporary(),"Opaque execution may also change durable objects");assertEquals(ObjectKind.SCHEMA,effect.getKind());assertTrue(DdlImpact.opaqueOperation(effect.getOperation()));
        }
        assertTrue(DdlImpact.analyze("SELECT 1",engine,LexicalSettings.DEFAULT,context(base(engine))).isEmpty());
    }
}
