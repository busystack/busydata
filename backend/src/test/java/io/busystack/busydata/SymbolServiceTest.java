package io.busystack.busydata;

import io.busystack.busydata.analysis.LexicalSettings;
import io.busystack.busydata.analysis.language.*;
import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import java.util.*;
import java.util.concurrent.CancellationException;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class SymbolServiceTest {
    private static SchemaObject object(String catalog,String schema,String name,ObjectKind kind){return SchemaObject.newBuilder().setCatalog(catalog).setSchema(schema).setName(name).setKind(kind).setDefinition("private object source").putProperties("comment","private object detail").build();}
    private static MetadataSnapshot snapshot(Engine engine,int casePolicy,List<SchemaObject> objects,boolean complete){
        var rules=NativeCaseFixtures.rules(engine,casePolicy);var entries=new ArrayList<MetadataObject>();var coverage=new HashMap<MetadataScope,MetadataCoverage>();
        for(var object:objects){entries.add(MetadataObject.from("source","profile",object.getPropertiesOrDefault("sessionOwner",""),rules,object,IntrospectionLevel.STRUCTURE,3,4));if(complete)for(var kind:List.of(ObjectKind.TABLE,ObjectKind.VIEW,ObjectKind.SEQUENCE)){var scope=new MetadataScope(object.getCatalog(),object.getSchema(),"",kind);coverage.put(scope,new MetadataCoverage(scope,IntrospectionLevel.NAMES,MetadataState.AVAILABLE,true,"names",3,4,1,""));}}
        if(complete)for(var kind:List.of(ObjectKind.TABLE,ObjectKind.VIEW,ObjectKind.SEQUENCE)){var scope=new MetadataScope("db",engine==Engine.POSTGRESQL?"public":"db","",kind);coverage.put(scope,new MetadataCoverage(scope,IntrospectionLevel.NAMES,MetadataState.AVAILABLE,true,"names",3,4,1,""));}
        if(complete&&engine==Engine.POSTGRESQL)for(var kind:List.of(ObjectKind.TABLE,ObjectKind.VIEW,ObjectKind.SEQUENCE)){var scope=new MetadataScope("db","pg_catalog","",kind);coverage.put(scope,new MetadataCoverage(scope,IntrospectionLevel.NAMES,MetadataState.AVAILABLE,true,"names",3,4,1,""));}
        return new MetadataSnapshot("source","profile",7,2,1,rules,entries,coverage);
    }
    private static ResolvedSymbol resolve(String marked,Engine engine,int policy,List<SchemaObject> objects,boolean complete,List<String> path){
        int caret=marked.indexOf('|');assertTrue(caret>=0);String sql=marked.substring(0,caret)+marked.substring(caret+1);
        var snapshot=snapshot(engine,policy,objects,complete);String temporary=objects.stream().filter(o->!o.getPropertiesOrDefault("sessionOwner","").isEmpty()&&o.getSchema().startsWith("pg_temp_")).map(SchemaObject::getSchema).findFirst().orElse("");var context=new ResolutionContext("db",engine==Engine.POSTGRESQL?"public":"db",path,complete,7,2,snapshot.rules(),snapshot,temporary);
        return SymbolService.resolve(AnalysisRequest.newBuilder().setSql(sql).setCaretUtf16(caret).setEngine(engine).build(),"profile",LexicalSettings.DEFAULT,context,()->false);
    }
    @Test void postgresPreservesQuotedTokensAndFoldsOnlyUnquotedIdentifiers(){
        var objects=List.of(object("db","public","Orders",ObjectKind.TABLE),object("db","public","orders",ObjectKind.TABLE),object("db","Audit","Customers",ObjectKind.VIEW));
        assertEquals("Orders",resolve("SELECT * FROM \"Ord|ers\"",Engine.POSTGRESQL,0,objects,true,List.of("public")).getCandidates(0).getName());
        assertEquals("orders",resolve("SELECT * FROM ORD|ERS",Engine.POSTGRESQL,0,objects,true,List.of("public")).getCandidates(0).getName());
        var quoted=resolve("SELECT * FROM \"Audit\".\"Custo|mers\"",Engine.POSTGRESQL,0,objects,true,List.of("public"));assertEquals("exact",quoted.getAvailability());assertEquals("Audit",quoted.getSchema());assertEquals(ObjectKind.VIEW,quoted.getCandidates(0).getKind());
        assertEquals(0,resolve("SELECT * FROM Audit.Custo|mers",Engine.POSTGRESQL,0,objects,true,List.of("public")).getCandidatesCount());
    }
    @Test void mysqlAndMariaUseCapturedTableCasePolicyEvenWhenQuoted(){
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB)){
            var objects=List.of(object("db","db","Orders",ObjectKind.TABLE));
            assertEquals("exact",resolve("SELECT * FROM `Ord|ers`",engine,0,objects,true,List.of("db")).getAvailability());
            var sensitive=resolve("SELECT * FROM ord|ers",engine,0,objects,true,List.of("db"));assertEquals("choose-native-case",sensitive.getAvailability());assertEquals("Orders",sensitive.getCandidates(0).getName());
            assertEquals("exact",resolve("SELECT * FROM `ord|ers`",engine,1,objects,true,List.of("db")).getAvailability());
            assertEquals("DB",resolve("SELECT * FROM ord|ers",engine,2,List.of(object("DB","DB","Orders",ObjectKind.TABLE)),true,List.of("db")).getCatalog());
        }
    }
    @Test void temporaryOverlayShadowsOnlyTheUnqualifiedPersistentName(){
        var temporary=object("db","pg_temp_7","orders",ObjectKind.TABLE).toBuilder().putProperties("sessionOwner","physical-session").putProperties("temporary","true").build();
        var objects=List.of(object("db","public","orders",ObjectKind.TABLE),temporary);
        assertEquals("pg_temp_7",resolve("SELECT * FROM ord|ers",Engine.POSTGRESQL,0,objects,true,List.of("public")).getSchema());
        assertEquals("public",resolve("SELECT * FROM public.ord|ers",Engine.POSTGRESQL,0,objects,true,List.of("public")).getSchema());
        assertEquals("public",resolve("SELECT * FROM ord|ers",Engine.POSTGRESQL,0,objects,true,List.of("public","pg_temp_7")).getSchema());
        var cached=snapshot(Engine.POSTGRESQL,0,objects,true);var context=new ResolutionContext("db","public",List.of("public"),true,7,2,cached.rules(),cached,"pg_temp_7");
        String sql="SELECT * FROM pg_temp.orders";var request=AnalysisRequest.newBuilder().setSql(sql).setCaretUtf16(sql.indexOf("orders")+3).setEngine(Engine.POSTGRESQL).build();
        assertEquals("pg_temp_7",SymbolService.resolve(request,"profile",LexicalSettings.DEFAULT,context,()->false).getSchema());
    }
    @Test void capturedSearchPathDoesNotBindAnUnrelatedNamespace(){
        var objects=List.of(object("db","audit","orders",ObjectKind.TABLE));
        var missing=resolve("SELECT * FROM ord|ers",Engine.POSTGRESQL,0,objects,true,List.of("public"));assertEquals("not-found",missing.getAvailability());assertEquals(0,missing.getCandidatesCount());
        assertEquals("audit",resolve("SELECT * FROM audit.ord|ers",Engine.POSTGRESQL,0,objects,true,List.of("public")).getSchema());
        assertEquals("incomplete-metadata",resolve("SELECT * FROM ord|ers",Engine.POSTGRESQL,0,objects,false,List.of("public")).getAvailability());
    }
    @Test void duplicateAliasesAreAmbiguousWhileCorrelatedAndShadowedAliasesResolve(){
        var objects=List.of(object("db","public","orders",ObjectKind.TABLE),object("db","audit","customers",ObjectKind.TABLE));
        var ambiguous=resolve("SELECT x|.id FROM public.orders x JOIN audit.customers x ON true",Engine.POSTGRESQL,0,objects,true,List.of("public"));assertEquals("ambiguous",ambiguous.getAvailability());assertEquals(0,ambiguous.getCandidatesCount());
        assertEquals("orders",resolve("SELECT (SELECT o|.id FROM audit.customers c) FROM public.orders o",Engine.POSTGRESQL,0,objects,true,List.of("public")).getCandidates(0).getName());
        assertEquals("customers",resolve("SELECT (SELECT o|.id FROM audit.customers o) FROM public.orders o",Engine.POSTGRESQL,0,objects,true,List.of("public")).getCandidates(0).getName());
    }
    @Test void priorUnexecutedContextChangesRemainAmbiguousWithoutChangingTheCapturedContext(){
        var objects=List.of(object("db","public","orders",ObjectKind.TABLE),object("db","audit","orders",ObjectKind.TABLE));
        assertEquals("ambiguous",resolve("SET search_path=audit; SELECT * FROM ord|ers",Engine.POSTGRESQL,0,objects,true,List.of("public")).getAvailability());
        assertEquals("public",resolve("SET search_path=audit; SELECT * FROM public.ord|ers",Engine.POSTGRESQL,0,objects,true,List.of("public")).getSchema());
        assertEquals("public",resolve("SELECT 'SET search_path=audit'; SELECT * FROM ord|ers",Engine.POSTGRESQL,0,objects,true,List.of("public")).getSchema());
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB))assertEquals("ambiguous",resolve("USE audit; SELECT * FROM ord|ers",engine,0,List.of(object("db","db","orders",ObjectKind.TABLE)),true,List.of("db")).getAvailability());
    }
    @Test void literalsCommentsAndCtesDoNotBecomeDatabaseObjects(){
        var objects=List.of(object("db","public","orders",ObjectKind.TABLE));
        for(String marked:List.of("SELECT 'ord|ers'","SELECT 1 /* ord|ers */","WITH c AS (SELECT 1) SELECT * FROM c|")){
            var result=resolve(marked,Engine.POSTGRESQL,0,objects,true,List.of("public"));assertEquals("not-an-object-reference",result.getAvailability());assertEquals(0,result.getCandidatesCount());
        }
    }
    @Test void sequencesAndOriginalUtf16SpansRemainAvailableWithoutObjectDetails(){
        String marked="-- 漢😀\r\nSELECT 1;\r\nSELECT * FROM public.seq|uence_name";int caret=marked.indexOf('|');
        var result=resolve(marked,Engine.POSTGRESQL,0,List.of(object("db","public","sequence_name",ObjectKind.SEQUENCE)),true,List.of("public"));
        assertEquals("exact",result.getAvailability());assertEquals(ObjectKind.SEQUENCE,result.getCandidates(0).getKind());assertTrue(result.getSpan().getStartUtf16()<=caret);assertTrue(result.getSpan().getEndUtf16()>=caret);assertEquals(marked.replace("|","").indexOf("sequence_name"),result.getSpan().getStartUtf16());assertEquals("profile",result.getProfileId());assertTrue(result.getCandidates(0).getPropertiesMap().isEmpty());assertEquals("",result.getCandidates(0).getDefinition());
    }
    @Test void requestsAreBoundedAndCancellableWithoutAnySessionOrJdbcDependency(){
        var snapshot=snapshot(Engine.POSTGRESQL,0,List.of(object("db","public","orders",ObjectKind.TABLE)),true);
        var context=new ResolutionContext("db","public",List.of("public"),true,7,2,snapshot.rules(),snapshot);
        var request=AnalysisRequest.newBuilder().setSql("SELECT * FROM orders").setEngine(Engine.POSTGRESQL).setCaretUtf16(16).build();
        assertThrows(CancellationException.class,()->SymbolService.resolve(request,"profile",LexicalSettings.DEFAULT,context,()->true));
        assertEquals("session-required",SymbolService.resolve(request,"profile",LexicalSettings.DEFAULT,ResolutionContext.UNAVAILABLE,()->false).getAvailability());
        assertThrows(IllegalArgumentException.class,()->SymbolService.resolve(request.toBuilder().setCaretUtf16(1000).build(),"profile",LexicalSettings.DEFAULT,ResolutionContext.UNAVAILABLE,()->false));
        var unknownNamespace=new ResolutionContext("db","",List.of(),false,7,2,snapshot.rules(),snapshot);
        assertEquals("incomplete-metadata",SymbolService.resolve(request,"profile",LexicalSettings.DEFAULT,unknownNamespace,()->false).getAvailability());
        var oversized=request.toBuilder().setSql("x".repeat(AnalysisBudget.MAX_DOCUMENT_UNITS+1)).build();assertEquals("limited",SymbolService.resolve(oversized,"profile",LexicalSettings.DEFAULT,context,()->false).getAvailability());
        var alternatives=new ArrayList<SchemaObject>();
        for(int mask=1;mask<64;mask++){var name=new StringBuilder("orders");for(int bit=0;bit<6;bit++)if((mask&(1<<bit))!=0)name.setCharAt(bit,Character.toUpperCase(name.charAt(bit)));alternatives.add(object("db","db",name.toString(),ObjectKind.TABLE));}
        assertEquals("limited",resolve("SELECT * FROM ord|ers",Engine.MYSQL,0,alternatives,true,List.of("db")).getAvailability());
        var unrelated=new ArrayList<SchemaObject>();unrelated.add(object("db","public","orders",ObjectKind.TABLE));for(int index=0;index<500;index++)unrelated.add(object("db","unrelated_"+index,"orders",ObjectKind.TABLE));
        assertEquals("public",resolve("SELECT * FROM ord|ers",Engine.POSTGRESQL,0,unrelated,true,List.of("public")).getSchema());
        var widePath=new ArrayList<String>();for(int i=0;i<33;i++)widePath.add("schema_"+i);
        assertEquals("limited",resolve("SELECT * FROM ord|ers",Engine.POSTGRESQL,0,List.of(object("db","public","orders",ObjectKind.TABLE)),true,widePath).getAvailability());
    }
}
