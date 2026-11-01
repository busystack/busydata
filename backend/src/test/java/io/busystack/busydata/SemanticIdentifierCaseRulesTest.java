package io.busystack.busydata;

import io.busystack.busydata.analysis.*;
import io.busystack.busydata.analysis.language.*;
import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

/** Small synthetic equivalence fixtures exercise consumers, not native rule
 * acquisition. The independent native corpus is the server-behaviour oracle. */
class SemanticIdentifierCaseRulesTest {
    private static IdentifierRules rules(Engine engine,int mode){
        if(engine==Engine.POSTGRESQL)return NativeCaseFixtures.rules(engine,mode);
        var lower=identity();var comparison=identity();var dictionary=identity();
        for(char upper='A';upper<='Z';upper++){
            char low=(char)(upper+32);lower[upper]=low;dictionary[upper]=low;
            if(engine==Engine.MARIADB)comparison[low]=upper;else comparison[upper]=low;
        }
        lower['Ο']='ο';lower['Σ']='σ';lower['İ']='i';lower['Ñ']='ñ';
        if(engine==Engine.MARIADB){comparison['ο']='Ο';comparison['σ']='Σ';comparison['ς']='Σ';comparison['ñ']='Ñ';}
        else {comparison['Ο']='ο';comparison['Σ']='σ';comparison['İ']='i';comparison['Ñ']='ñ';}
        dictionary['Ο']='ο';dictionary['Σ']='σ';dictionary['ς']='σ';dictionary['İ']='i';
        dictionary['Ñ']='n';dictionary['ñ']='n';
        return IdentifierRules.nativeRules(engine,mode,"synthetic-semantic-corpus-v1",new String(lower),new String(comparison),new String(dictionary),engine==Engine.MARIADB?byteMap():null,false);
    }
    private static String byteMap(){var map=new char[256];for(int value=0;value<256;value++)map[value]=(char)(value+1);for(char upper='A';upper<='Z';upper++)map[upper]=(char)(upper+33);return new String(map);}
    private static char[] identity(){var map=new char[65536];for(int c=1;c<map.length;c++)if(c<0xd800||c>0xdfff)map[c]=(char)c;return map;}
    private static SchemaObject table(String name){return SchemaObject.newBuilder().setKind(ObjectKind.TABLE).setCatalog("db").setSchema("db").setName(name).build();}
    private static SchemaObject column(String table,String name){return SchemaObject.newBuilder().setKind(ObjectKind.COLUMN).setCatalog("db").setSchema("db").setTable(table).setName(name).putProperties("nativeType","integer").build();}
    private static SchemaObject routine(String name){return SchemaObject.newBuilder().setKind(ObjectKind.ROUTINE).setCatalog("db").setSchema("db").setName(name).setIdentifier(name+"(integer)").putProperties("parameterCount","1").putProperties("parameter.0.name","amount").putProperties("parameter.0.type","integer").putProperties("returnType","integer").build();}
    private static ResolutionContext context(Engine engine,IdentifierRules rules,List<SchemaObject> objects){
        return SemanticFixtures.context(engine,objects,new ResolutionContext("db","db",List.of("db"),true,7,3,rules));
    }
    private static Analysis analyze(String sql,int caret,Engine engine,AnalysisOperation operation,ResolutionContext context){
        return new SqlAnalysis().analyze(AnalysisRequest.newBuilder().setSql(sql).setCaretUtf16(caret).setEngine(engine).setOperation(operation).build(),LexicalSettings.DEFAULT,context);
    }
    private static List<Completion> complete(String marked,Engine engine,ResolutionContext context){int caret=marked.indexOf('|');assertTrue(caret>=0);return analyze(marked.replace("|",""),caret,engine,AnalysisOperation.COMPLETION,context).getCompletionsList();}
    private static Set<String> codes(String sql,Engine engine,ResolutionContext context){return new HashSet<>(analyze(sql,0,engine,AnalysisOperation.DIAGNOSTICS,context).getDiagnosticsList().stream().map(Diagnostic::getCode).toList());}
    private static ResolvedSymbol symbol(String marked,Engine engine,ResolutionContext context){int caret=marked.indexOf('|');return SymbolService.resolve(AnalysisRequest.newBuilder().setSql(marked.replace("|","")).setCaretUtf16(caret).setEngine(engine).build(),"profile",LexicalSettings.DEFAULT,context,()->false);}

    @Test void columnBindingAndCompletionUseScalarMapsWithoutJavaContextOrExpansion(){
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB)){
            var context=context(engine,rules(engine,0),List.of(table("t"),column("t","ΟΣ"),column("t","İ"),column("t","ẞ")));
            assertTrue(complete("SELECT t.οσ| FROM t",engine,context).stream().anyMatch(c->c.getLabel().equals("ΟΣ")),engine.toString());
            assertEquals(engine==Engine.MARIADB,complete("SELECT t.ος| FROM t",engine,context).stream().anyMatch(c->c.getLabel().equals("ΟΣ")),engine.toString());
            assertEquals(engine==Engine.MYSQL,complete("SELECT t.i| FROM t",engine,context).stream().anyMatch(c->c.getLabel().equals("İ")),engine.toString());
            assertFalse(complete("SELECT t.i̇| FROM t",engine,context).stream().anyMatch(c->c.getLabel().equals("İ")));
            assertFalse(complete("SELECT t.ß| FROM t",engine,context).stream().anyMatch(c->c.getLabel().equals("ẞ")));
            assertFalse(codes("SELECT οσ FROM t",engine,context).contains("binding.unresolved-column"));
            assertEquals(engine==Engine.MYSQL,codes("SELECT ος FROM t",engine,context).contains("binding.unresolved-column"));
        }
    }
    @Test void insertDuplicateDetectionUsesColumnComparisonAndKeepsNativeDistinctions(){
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB)){
            var context=context(engine,rules(engine,0),List.of(table("t"),column("t","ΟΣ"),column("t","İ"),column("t","ẞ"),column("t","ß")));
            assertTrue(codes("INSERT INTO t (`ΟΣ`,`οσ`) VALUES (1,2)",engine,context).contains("binding.duplicate-insert-column"));
            assertEquals(engine==Engine.MARIADB,codes("INSERT INTO t (`ΟΣ`,`ος`) VALUES (1,2)",engine,context).contains("binding.duplicate-insert-column"));
            assertEquals(engine==Engine.MYSQL,codes("INSERT INTO t (`İ`,`i`) VALUES (1,2)",engine,context).contains("binding.duplicate-insert-column"));
            assertFalse(codes("INSERT INTO t (`ẞ`,`ß`) VALUES (1,2)",engine,context).contains("binding.duplicate-insert-column"));
        }
    }
    @Test void tableAliasPolicyIsSeparateFromPhysicalTableAndColumnPolicy(){
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB))for(int mode:List.of(0,1)){
            var context=context(engine,rules(engine,mode),List.of(table("t"),column("t","id")));
            boolean match=mode==1&&engine==Engine.MARIADB;
            assertEquals(match,complete("SELECT `ος`.| FROM t AS `ΟΣ`",engine,context).stream().anyMatch(c->c.getLabel().equals("id")),engine+"/"+mode);
            assertEquals(mode==1,complete("SELECT `οσ`.| FROM t AS `ΟΣ`",engine,context).stream().anyMatch(c->c.getLabel().equals("id")),engine+"/"+mode);
            var result=symbol("SELECT `ος|`.id FROM t AS `ΟΣ`",engine,context);
            assertEquals(match?"exact":"not-an-object-reference",result.getAvailability(),engine+"/"+mode);
        }
    }
    @Test void ctesUseTheirNativeNamespaceIndependentOfOutputAndDerivedColumnAliases(){
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB))for(int mode:List.of(0,1)){
            var context=context(engine,rules(engine,mode),List.of(table("t"),column("t","id")));
            boolean cteMatch=engine==Engine.MARIADB;
            assertEquals(cteMatch,complete("WITH `ΟΣ` AS (SELECT id FROM t) SELECT id| FROM `ος`",engine,context).stream().anyMatch(c->c.getKind().equals("column")&&c.getLabel().equals("id")),engine+"/"+mode);
            assertEquals(engine==Engine.MARIADB,complete("SELECT d.`ος`| FROM (SELECT id AS `ΟΣ` FROM t) d",engine,context).stream().anyMatch(c->c.getLabel().equals("ΟΣ")),engine+"/"+mode);
            assertEquals(engine==Engine.MARIADB,complete("SELECT id AS `ΟΣ` FROM t ORDER BY `ος`|",engine,context).stream().anyMatch(c->c.getLabel().equals("ΟΣ")),engine+"/"+mode);
            assertEquals(engine==Engine.MARIADB,codes("WITH `ΟΣ` AS (SELECT 1), `ος` AS (SELECT 2) SELECT 1",engine,context).contains("binding.duplicate-cte"),engine+"/"+mode);
        }
    }
    @Test void dictionaryRoutineBindingAndPrefixCompletionDoNotRefilterWithJavaCaseRules(){
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB)){
            var context=context(engine,rules(engine,0),List.of(routine("Ñ_fn"),routine("ΟΣ_fn"),routine("İ_fn"),routine("ẞ_fn")));
            for(var pair:Map.of("n_fn","Ñ_fn","ος_fn","ΟΣ_fn","i_fn","İ_fn").entrySet()){
                assertTrue(complete("SELECT db."+pair.getKey()+"|",engine,context).stream().anyMatch(c->c.getLabel().equals(pair.getValue()+"()")),engine+"/"+pair);
                String sql="SELECT db."+pair.getKey()+"(1)";
                assertEquals(pair.getValue(),analyze(sql,sql.length()-1,engine,AnalysisOperation.PARAMETER_INFORMATION,context).getParameterInformation().getOverloads(0).getName());
                assertFalse(codes(sql,engine,context).contains("routine.unknown"));
            }
            assertFalse(complete("SELECT db.ß_fn|",engine,context).stream().anyMatch(c->c.getLabel().equals("ẞ_fn()")));
            assertTrue(codes("SELECT db.ß_fn(1)",engine,context).contains("routine.unknown"));
        }
    }
    @Test void symbolExactnessFollowsPhysicalLowerRatherThanJavaCaseOrDictionaryAccent(){
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB)){
            var insensitive=context(engine,rules(engine,1),List.of(table("ΟΣ"),table("Ñ")));
            assertEquals("exact",symbol("SELECT * FROM `οσ|`",engine,insensitive).getAvailability());
            assertNotEquals("exact",symbol("SELECT * FROM `ος|`",engine,insensitive).getAvailability());
            assertEquals("not-found",symbol("SELECT * FROM `N|`",engine,insensitive).getAvailability());
            var sensitive=context(engine,rules(engine,0),List.of(table("ΟΣ")));
            assertEquals("choose-native-case",symbol("SELECT * FROM `οσ|`",engine,sensitive).getAvailability());
        }
    }
    @Test void unavailableNativeEvidenceNeverCertifiesResolutionOrUndefinedNames(){
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB)){
            var context=context(engine,new IdentifierRules(engine,1),List.of(table("Orders"),column("Orders","id"),routine("calculate")));
            assertFalse(context.complete());
            var exactCandidate=symbol("SELECT * FROM ord|ers",engine,context);assertFalse(exactCandidate.getComplete());assertEquals("incomplete-metadata",exactCandidate.getAvailability());
            var missing=symbol("SELECT * FROM miss|ing",engine,context);assertFalse(missing.getComplete());assertEquals("incomplete-metadata",missing.getAvailability());
            var diagnostics=analyze("SELECT missing FROM orders",0,engine,AnalysisOperation.DIAGNOSTICS,context).getDiagnosticsList();
            assertTrue(diagnostics.stream().anyMatch(Diagnostic::getIncomplete));
            assertFalse(diagnostics.stream().anyMatch(d->Set.of("binding.unresolved-column","binding.unresolved-relation","routine.unknown").contains(d.getCode())));
            assertFalse(codes("INSERT INTO orders(id,id) VALUES(1,2)",engine,context).contains("binding.duplicate-insert-column"));
            assertFalse(codes("WITH x AS (SELECT 1), X AS (SELECT 2) SELECT 1",engine,context).contains("binding.duplicate-cte"));
        }
    }
    @Test void postgresQuotedAndUtf8AliasesKeepAsciiOnlyUnquotedFolding(){
        var context=context(Engine.POSTGRESQL,rules(Engine.POSTGRESQL,0),List.of(table("t"),column("t","ΟΣ")));
        assertTrue(complete("SELECT t.\"ΟΣ\"| FROM t",Engine.POSTGRESQL,context).stream().anyMatch(c->c.getLabel().equals("ΟΣ")));
        assertFalse(complete("SELECT t.οσ| FROM t",Engine.POSTGRESQL,context).stream().anyMatch(c->c.getLabel().equals("ΟΣ")));
        assertFalse(codes("SELECT \"ΟΣ\" FROM t",Engine.POSTGRESQL,context).contains("binding.unresolved-column"));
        assertTrue(codes("SELECT οσ FROM t",Engine.POSTGRESQL,context).contains("binding.unresolved-column"));
    }
    @Test void completeCachedMapsForAnotherPhysicalHeaderNeverCertifyCurrentSemantics(){
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB)){
            var captured=context(engine,rules(engine,1),List.of(table("t"),column("t","id")));
            var unavailable=captured.snapshot().withIdentifierAvailability(false);
            assertSame(captured.snapshot().rules(),unavailable.rules());assertTrue(unavailable.rules().complete());
            var context=new ResolutionContext("db","db",List.of("db"),true,7,3,unavailable.rules(),unavailable);
            assertFalse(context.complete());assertEquals("incomplete-metadata",symbol("SELECT * FROM t|",engine,context).getAvailability());
            assertEquals("incomplete-metadata",symbol("SELECT x|.id FROM t y",engine,context).getAvailability());
            var result=analyze("SELECT missing FROM t",0,engine,AnalysisOperation.DIAGNOSTICS,context);
            assertTrue(result.getDiagnosticsList().stream().anyMatch(Diagnostic::getIncomplete));
            assertFalse(result.getDiagnosticsList().stream().anyMatch(d->d.getCode().equals("binding.unresolved-column")));
            assertFalse(codes("INSERT INTO t(id,id) VALUES(1,2)",engine,context).contains("binding.duplicate-insert-column"));
            assertFalse(codes("WITH x AS (SELECT 1), X AS (SELECT 2) SELECT 1",engine,context).contains("binding.duplicate-cte"));
            String sql="SELECT t.i FROM t";assertEquals("incomplete-metadata",analyze(sql,sql.indexOf("i")+1,engine,AnalysisOperation.COMPLETION,context).getAvailability());
        }
    }
    private static ResolutionContext reconciledNames(Engine engine,MetadataState nameState){
        var base=context(engine,rules(engine,0),List.of(table("ΟΣ"),column("ΟΣ","old_text"),table("healthy"),column("healthy","id")));
        var entries=new ArrayList<MetadataObject>();
        for(var object:base.snapshot().identities().values()){
            if(object.identity().name().equals("ΟΣ")||object.identity().parent().equals("ΟΣ")){
                var properties=new HashMap<>(object.properties());
                if(object.identity().kind()==ObjectKind.TABLE)properties.put("nativeGenerationAvailability","UNSUPPORTED_IDENTIFIER_MAPPING");
                entries.add(new MetadataObject(object.identity(),object.displayName(),object.quotedIdentifier(),object.lookupKey(),properties,"retained stale source",object.level(),MetadataState.STALE,object.sourceRevision(),object.contextRevision()));
            }else entries.add(object);
        }
        var coverage=new HashMap<>(base.snapshot().catalogCoverage());
        var names=new MetadataScope("db","db","",ObjectKind.TABLE);
        coverage.put(names,new MetadataCoverage(names,IntrospectionLevel.NAMES,nameState,nameState==MetadataState.AVAILABLE,"observed-names",7,3,1,""));
        var columns=new MetadataScope("db","db","ΟΣ",ObjectKind.COLUMN);coverage.computeIfPresent(columns,(scope,old)->old.stale("Name acquisition did not verify retained structure"));
        var snapshot=new MetadataSnapshot(base.snapshot().source(),base.snapshot().profileId(),8,3,1,base.snapshot().rules(),entries,coverage);
        return new ResolutionContext("db","db",List.of("db"),true,8,3,snapshot.rules(),snapshot);
    }
    @Test void freshNativeNamesSurviveRetiredStructureWithoutAcquiringItsAuthority(){
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB)){
            var context=reconciledNames(engine,MetadataState.AVAILABLE);var snapshot=context.snapshot();
            var original=snapshot.namespace("db","db",ObjectKind.TABLE,"").stream().filter(o->o.identity().name().equals("ΟΣ")).findFirst().orElseThrow();
            var offered=analyze("SELECT Ο",8,engine,AnalysisOperation.COMPLETION,context);
            assertEquals("incomplete-metadata",offered.getAvailability());
            assertTrue(offered.getCompletionsList().stream().anyMatch(c->c.getLabel().equals("ΟΣ")&&c.getTargetIdentity().equals(original.identity().key())));
            assertTrue(complete("SELECT * FROM db.`ΟΣ`|",engine,context).stream().anyMatch(c->c.getTargetIdentity().equals(original.identity().key())));
            assertTrue(complete("SELECT q.| FROM db.`ΟΣ` q",engine,context).isEmpty(),"Fresh names do not expose stale columns or field-list expansion");
            var navigation=symbol("SELECT * FROM db.`ΟΣ|`",engine,context);
            assertEquals(1,navigation.getCandidatesCount());assertFalse(navigation.getComplete());assertEquals("incomplete-metadata",navigation.getAvailability());
            String sql="SELECT q.old_text FROM db.`ΟΣ` q";var document=new SemanticDocument(sql,engine);var query=document.syntax().queries().getFirst();
            assertFalse(document.bind(context).type(query,query.projections().getFirst().expression()).known());
            var selected=Column.newBuilder().setCatalog("db").setSchema("db").setTable("ΟΣ").setBaseColumn("old_text").setOrdinal(1).setProvenanceKnown(true).build();
            var proof=RetainedMetadataProof.capture(snapshot,List.of(selected),Profile.newBuilder().setEngine(engine).setDatabase("db").build(),"session");
            assertFalse(proof.available());assertEquals(MetadataState.STALE,proof.state());
            assertFalse(snapshot.complete(new MetadataScope("db","db","ΟΣ",ObjectKind.COLUMN),IntrospectionLevel.STRUCTURE));
        }
    }
    @Test void failedNameEvidenceAndForeignHeaderCannotResurrectStaleCandidates(){
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB)){
            for(var state:List.of(MetadataState.STALE,MetadataState.PARTIAL,MetadataState.DENIED,MetadataState.UNKNOWN)){
                var context=reconciledNames(engine,state);
                assertFalse(complete("SELECT Ο|",engine,context).stream().anyMatch(c->c.getLabel().equals("ΟΣ")),engine+"/"+state);
                assertEquals("incomplete-metadata",symbol("SELECT * FROM db.`ΟΣ|`",engine,context).getAvailability());
            }
            var before=reconciledNames(engine,MetadataState.AVAILABLE);var unavailable=before.snapshot().withIdentifierAvailability(false);
            var context=new ResolutionContext("db","db",List.of("db"),true,8,3,unavailable.rules(),unavailable);
            assertFalse(complete("SELECT Ο|",engine,context).stream().anyMatch(c->c.getLabel().equals("ΟΣ")));
            var unknown=before.snapshot().withSessionResolution(9,new MetadataSnapshot.SessionResolution(MetadataState.UNKNOWN,"session",1,"Unverified temporary visibility",Map.of()));
            var unknownContext=new ResolutionContext("db","db",List.of("db"),true,9,3,unknown.rules(),unknown);
            assertTrue(complete("SELECT Ο|",engine,unknownContext).stream().anyMatch(c->c.getLabel().equals("ΟΣ")),"Observed durable name remains a candidate despite unverified session shadowing");
            assertEquals("incomplete-metadata",symbol("SELECT * FROM db.`ΟΣ|`",engine,unknownContext).getAvailability());
        }
    }
    @Test void unrelatedRetiredNamesDoNotPoisonCurrentColumnCompletion(){
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB)){
            var context=reconciledNames(engine,MetadataState.AVAILABLE);String sql="SELECT h.i FROM healthy h";
            var result=analyze(sql,sql.indexOf("i")+1,engine,AnalysisOperation.COMPLETION,context);
            assertEquals("available",result.getAvailability());assertTrue(result.getCompletionsList().stream().anyMatch(c->c.getLabel().equals("id")));
        }
    }
}
