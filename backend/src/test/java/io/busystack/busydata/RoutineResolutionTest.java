package io.busystack.busydata;

import io.busystack.busydata.analysis.*;
import io.busystack.busydata.analysis.language.*;
import io.busystack.busydata.protocol.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import static org.junit.jupiter.api.Assertions.*;

/** Primary rules: MySQL8.4 function-resolution, MariaDB11.8 CREATE FUNCTION;
 * colliding stored functions require qualification, CALL invokes procedures.
 * https://dev.mysql.com/doc/refman/8.4/en/function-resolution.html
 * https://mariadb.com/docs/server/reference/sql-statements/data-definition/create/create-function
 * https://www.postgresql.org/docs/17/sql-call.html */
class RoutineResolutionTest {
    private static String schema(Engine engine){return engine==Engine.POSTGRESQL?"public":"db";}
    private static List<SchemaObject> objects(Engine engine){return List.of(routine(engine,ObjectSubtype.FUNCTION,2),routine(engine,ObjectSubtype.PROCEDURE,3));}
    private static SchemaObject routine(Engine engine,ObjectSubtype subtype,int count){
        String signature="abs("+String.join(",",Collections.nCopies(count,"integer"))+")";
        var object=SchemaObject.newBuilder().setKind(ObjectKind.ROUTINE).setSubtype(subtype).setCatalog("db").setSchema(schema(engine)).setName("abs").setIdentifier(signature).putProperties("signature",signature).putProperties("signatureAvailability","AVAILABLE").putProperties("parameterCount",Integer.toString(count)).putProperties("returnType",subtype==ObjectSubtype.FUNCTION?"integer":"void");
        for(int index=0;index<count;index++)object.putProperties("parameter."+index+".name","value"+index).putProperties("parameter."+index+".mode","IN").putProperties("parameter."+index+".type","integer").putProperties("parameter."+index+".nativeTypeId","23");
        return object.build();
    }
    private static ResolutionContext context(Engine engine){return SemanticFixtures.context(engine,objects(engine),new ResolutionContext("db",schema(engine),List.of(schema(engine)),true,9,2));}
    private static Analysis analyze(Engine engine,String marked,AnalysisOperation operation){
        int caret=marked.indexOf('|');String sql=marked.replace("|","");if(caret<0)caret=sql.length();
        return new SqlAnalysis().analyze(AnalysisRequest.newBuilder().setEngine(engine).setOperation(operation).setSql(sql).setCaretUtf16(caret).setDocumentId("routine-resolution").setDocumentVersion(1).build(),LexicalSettings.DEFAULT,context(engine));
    }
    private static String identity(Engine engine,ObjectSubtype subtype){return context(engine).snapshot().resolve("db",schema(engine),ObjectKind.ROUTINE,"","abs",true).stream().filter(object->object.identity().subtype()==subtype).findFirst().orElseThrow().identity().key();}

    @ParameterizedTest @EnumSource(value=Engine.class,names={"MYSQL","MARIADB"})
    void builtinFunctionWinsUnqualifiedWhileQualifiedStoredFunctionKeepsItsIdentity(Engine engine){
        for(String name:List.of("abs","ABS","`ABS`")){
            var information=analyze(engine,"SELECT "+name+"(|",AnalysisOperation.PARAMETER_INFORMATION).getParameterInformation();
            assertEquals("available",information.getAvailability());assertEquals(1,information.getOverloadsCount());assertTrue(information.getOverloads(0).getIdentity().startsWith("builtin:"));assertEquals(1,information.getOverloads(0).getParametersCount());
        }
        var stored=analyze(engine,"SELECT db.abs(1, |",AnalysisOperation.PARAMETER_INFORMATION).getParameterInformation();assertEquals("available",stored.getAvailability());assertEquals(1,stored.getOverloadsCount());assertEquals(identity(engine,ObjectSubtype.FUNCTION),stored.getOverloads(0).getIdentity());assertEquals(2,stored.getOverloads(0).getParametersCount());
        assertTrue(analyze(engine,"SELECT abs(1,2)",AnalysisOperation.DIAGNOSTICS).getDiagnosticsList().stream().anyMatch(item->item.getCode().equals("routine.argument-count")));
        assertFalse(analyze(engine,"SELECT db.abs(1,2)",AnalysisOperation.DIAGNOSTICS).getDiagnosticsList().stream().anyMatch(item->item.getCode().equals("routine.argument-count")));
        assertTrue(analyze(engine,"SELECT db.abs(1,2,3)",AnalysisOperation.DIAGNOSTICS).getDiagnosticsList().stream().anyMatch(item->item.getCode().equals("routine.argument-count")),"A same-name procedure cannot satisfy a function call");
    }

    @ParameterizedTest @EnumSource(value=Engine.class,names={"POSTGRESQL","MYSQL","MARIADB"})
    void callUsesOnlyProcedureSubtypeAndNestedArgumentsStillUseFunctions(Engine engine){
        for(String target:List.of("abs",schema(engine)+".abs")){
            var procedure=analyze(engine,"CALL "+target+"(1,2,|",AnalysisOperation.PARAMETER_INFORMATION).getParameterInformation();assertEquals("available",procedure.getAvailability());assertEquals(1,procedure.getOverloadsCount());assertEquals(identity(engine,ObjectSubtype.PROCEDURE),procedure.getOverloads(0).getIdentity());assertEquals(3,procedure.getOverloads(0).getParametersCount());assertEquals(2,procedure.getActiveArgument());
        }
        String nestedName=engine==Engine.POSTGRESQL?"lower":"abs";
        var nested=analyze(engine,"CALL "+schema(engine)+".abs("+nestedName+"(|",AnalysisOperation.PARAMETER_INFORMATION).getParameterInformation();assertEquals(1,nested.getOverloadsCount());assertTrue(nested.getOverloads(0).getIdentity().startsWith("builtin:"));
        var missing=analyze(engine,"CALL lower(|",AnalysisOperation.PARAMETER_INFORMATION).getParameterInformation();assertEquals(0,missing.getOverloadsCount());assertEquals("unavailable-signature",missing.getAvailability());
    }

    @ParameterizedTest @EnumSource(value=Engine.class,names={"MYSQL","MARIADB"})
    void functionAndProcedureCompletionUseTheirOwnInvocationContexts(Engine engine){
        var functions=analyze(engine,"SELECT ab|",AnalysisOperation.COMPLETION).getCompletionsList();
        assertTrue(functions.stream().anyMatch(item->item.getTargetIdentity().startsWith("builtin:")&&item.getInsertText().equals("abs()")));
        assertTrue(functions.stream().anyMatch(item->item.getTargetIdentity().equals(identity(engine,ObjectSubtype.FUNCTION))&&item.getInsertText().equals("db.abs()")));
        assertFalse(functions.stream().anyMatch(item->item.getTargetIdentity().equals(identity(engine,ObjectSubtype.PROCEDURE))));
        var procedures=analyze(engine,"CALL ab|",AnalysisOperation.COMPLETION).getCompletionsList();assertEquals(1,procedures.size());assertEquals("procedure",procedures.getFirst().getKind());assertEquals("db.abs()",procedures.getFirst().getInsertText());assertEquals(identity(engine,ObjectSubtype.PROCEDURE),procedures.getFirst().getTargetIdentity());assertEquals(5,procedures.getFirst().getStartUtf16());assertEquals(7,procedures.getFirst().getEndUtf16());
        var qualified=analyze(engine,"CALL db.ab|",AnalysisOperation.COMPLETION).getCompletionsList();assertEquals(1,qualified.size());assertEquals("abs()",qualified.getFirst().getInsertText());assertEquals(8,qualified.getFirst().getStartUtf16());assertEquals(10,qualified.getFirst().getEndUtf16());assertFalse(qualified.getFirst().getQualificationRequired());
        var nested=analyze(engine,"CALL db.abs(ab|",AnalysisOperation.COMPLETION).getCompletionsList();assertTrue(nested.stream().anyMatch(item->item.getKind().equals("function")&&item.getTargetIdentity().startsWith("builtin:")));assertFalse(nested.stream().anyMatch(item->item.getKind().equals("procedure")));
    }
    @Test void capturedServerModeKeepsIgnoreSpaceAndExistingLexicalFlags(){
        var context=new io.busystack.busydata.adapters.JdbcAdapter.LiveContext("db","db",List.of("db"),"","ANSI_QUOTES,IGNORE_SPACE,NO_BACKSLASH_ESCAPES",true);
        assertTrue(context.lexical().ignoreSpace());assertTrue(context.lexical().ansiQuotes());assertTrue(context.lexical().noBackslashEscapes());assertTrue(context.lexical().standardConformingStrings());
        assertFalse(LexicalSettings.mysql("").ignoreSpace());assertNotEquals(context.lexical(),new LexicalSettings(true,true,true));
    }

    @ParameterizedTest @EnumSource(value=Engine.class,names={"MYSQL","MARIADB"})
    void specialFunctionWhitespaceQuotesAndCommentsFollowTheCapturedNativeMode(Engine engine){
        var stored=new ArrayList<SchemaObject>();for(String name:List.of("COUNT","MIN","MAX","SUM"))stored.add(routine(engine,ObjectSubtype.FUNCTION,2).toBuilder().setName(name).setIdentifier(name+"(integer,integer)").putProperties("signature",name+"(integer,integer)").build());
        var context=SemanticFixtures.context(engine,stored,new ResolutionContext("db","db",List.of("db"),true,9,2));
        for(String mode:List.of("","IGNORE_SPACE"))for(String name:List.of("COUNT","MIN","MAX","SUM")){
            var cases=new LinkedHashMap<String,Boolean>();cases.put(name+"(",true);cases.put(name+" (",!mode.isEmpty());cases.put(name+"\t(",!mode.isEmpty());cases.put(name+"/*c*/(",false);cases.put(name+" /*c*/ (",false);cases.put("`"+name+"`(",false);cases.put("db.`"+name+"` (",false);
            for(var entry:cases.entrySet()){
                String sql="SELECT "+entry.getKey();var information=new SqlAnalysis().analyze(AnalysisRequest.newBuilder().setEngine(engine).setOperation(AnalysisOperation.PARAMETER_INFORMATION).setSql(sql).setCaretUtf16(sql.length()).build(),LexicalSettings.mysql(mode),context).getParameterInformation();
                assertEquals("available",information.getAvailability(),mode+":"+sql);assertEquals(1,information.getOverloadsCount());assertEquals(entry.getValue(),information.getOverloads(0).getIdentity().startsWith("builtin:"),mode+":"+sql);assertEquals(entry.getValue()?1:2,information.getOverloads(0).getParametersCount(),mode+":"+sql);
            }
            String sql="SELECT "+name+" (1,2)";var diagnostics=new SqlAnalysis().analyze(AnalysisRequest.newBuilder().setEngine(engine).setOperation(AnalysisOperation.DIAGNOSTICS).setSql(sql).build(),LexicalSettings.mysql(mode),context).getDiagnosticsList();assertEquals(!mode.isEmpty(),diagnostics.stream().anyMatch(item->item.getCode().equals("routine.argument-count")),mode+":"+sql);
        }
        String missing="SELECT COUNT (";var empty=SemanticFixtures.context(engine,List.of(),new ResolutionContext("db","db",List.of("db"),true,9,2));var unavailable=new SqlAnalysis().analyze(AnalysisRequest.newBuilder().setEngine(engine).setOperation(AnalysisOperation.PARAMETER_INFORMATION).setSql(missing).setCaretUtf16(missing.length()).build(),LexicalSettings.mysql(""),empty).getParameterInformation();assertEquals("unavailable-signature",unavailable.getAvailability());assertEquals(0,unavailable.getOverloadsCount(),"Stored-only syntax cannot fall back to the builtin");
    }

    @ParameterizedTest @EnumSource(value=Engine.class,names={"MYSQL","MARIADB"})
    void formattingPreservesTheNativeFunctionTriviaFromTheTwoEngineOracle(Engine engine){
        for(String mode:List.of("","IGNORE_SPACE"))for(String name:List.of("COUNT","MIN","MAX","SUM"))for(String expression:List.of(name+"(1)",name+" (1)",name+"\t(1)",name+"/*c*/(1)",name+" /*c*/ (1)","`"+name+"`(1)","db.`"+name+"` (1)")){
            String sql="SELECT "+expression;var dialect=new Dialect(engine,LexicalSettings.mysql(mode));var formatted=SqlFormatter.format(sql,dialect,SqlFormatter.Options.DEFAULT,0,sql.length(),AnalysisBudget.interactive());assertEquals("available",formatted.availability());assertEquals(sql,formatted.sql());assertEquals(sql,SqlFormatter.format(formatted.sql(),dialect,SqlFormatter.Options.DEFAULT,0,formatted.sql().length(),AnalysisBudget.interactive()).sql());
        }
    }

    @ParameterizedTest @EnumSource(value=Engine.class,names={"MYSQL","MARIADB"})
    void finiteBuiltinQuotedKeywordAndWhitespaceRulesMatchBothPinnedNativeOracles(Engine engine){
        var names=List.of("COUNT","MIN","MAX","SUM","AVG","ABS","LOWER","UPPER","LENGTH","COALESCE","NULLIF","ROW_NUMBER","RANK","DENSE_RANK","DATE_FORMAT","JSON_OBJECT");
        var stored=names.stream().map(name->routine(engine,ObjectSubtype.FUNCTION,2).toBuilder().setName(name).setIdentifier(name+"(integer,integer)").putProperties("signature",name+"(integer,integer)").build()).toList();
        var context=SemanticFixtures.context(engine,stored,new ResolutionContext("db","db",List.of("db"),true,9,2));
        var spaced=engine==Engine.MYSQL?Set.of("COUNT","MIN","MAX","SUM"):Set.of("COUNT","MIN","MAX","SUM","RANK","DENSE_RANK");
        var quoted=engine==Engine.MYSQL?Set.of("COUNT","MIN","MAX","SUM","AVG","COALESCE","ROW_NUMBER","RANK","DENSE_RANK"):Set.of("COUNT","MIN","MAX","SUM","AVG","ROW_NUMBER","RANK","DENSE_RANK");
        for(String mode:List.of("","IGNORE_SPACE"))for(String name:names){
            var cases=new LinkedHashMap<String,Boolean>();cases.put(name+"(",true);cases.put(name+" (",!spaced.contains(name)||!mode.isEmpty());cases.put(name+"/*c*/(",!spaced.contains(name));cases.put("`"+name+"`(",!quoted.contains(name));cases.put("db.`"+name+"`(",false);
            for(var entry:cases.entrySet()){
                String sql="SELECT "+entry.getKey();var information=new SqlAnalysis().analyze(AnalysisRequest.newBuilder().setEngine(engine).setOperation(AnalysisOperation.PARAMETER_INFORMATION).setSql(sql).setCaretUtf16(sql.length()).build(),LexicalSettings.mysql(mode),context).getParameterInformation();
                assertEquals("available",information.getAvailability(),mode+":"+sql);assertEquals(1,information.getOverloadsCount(),mode+":"+sql);assertEquals(entry.getValue(),information.getOverloads(0).getIdentity().startsWith("builtin:"),mode+":"+sql);
            }
        }
    }

    @Test void postgresWrongKindInEarlierSchemaStillBlocksAnIdenticalInputSignature(){
        var function=routine(Engine.POSTGRESQL,ObjectSubtype.FUNCTION,1).toBuilder().setName("work").setIdentifier("work(integer)").putProperties("signature","work(integer)").build();
        var procedure=routine(Engine.POSTGRESQL,ObjectSubtype.PROCEDURE,1).toBuilder().setName("work").setIdentifier("work(integer)").putProperties("signature","work(integer)").build();
        var declared=new ResolutionContext("db","public",List.of("public","audit"),true,9,2);
        for(boolean procedureFirst:List.of(false,true)){
            var first=(procedureFirst?procedure:function).toBuilder().setSchema("public").build();var later=(procedureFirst?function:procedure).toBuilder().setSchema("audit").build();var context=SemanticFixtures.context(Engine.POSTGRESQL,List.of(first,later),declared);
            String selected="SELECT work(",called="CALL work(";var service=new SqlAnalysis();
            for(String sql:List.of(selected,called)){
                var information=service.analyze(AnalysisRequest.newBuilder().setEngine(Engine.POSTGRESQL).setOperation(AnalysisOperation.PARAMETER_INFORMATION).setSql(sql).setCaretUtf16(sql.length()).build(),LexicalSettings.DEFAULT,context).getParameterInformation();
                boolean matching=sql.equals(called)==procedureFirst;assertEquals(matching?1:0,information.getOverloadsCount(),sql+":"+procedureFirst);assertEquals(matching?"available":"unavailable-signature",information.getAvailability(),sql+":"+procedureFirst);
            }
        }
    }

    private static ResolutionContext contextWith(Engine engine,List<SchemaObject> metadata){return SemanticFixtures.context(engine,metadata,new ResolutionContext("db",schema(engine),List.of(schema(engine)),true,9,2));}

    private static SchemaObject shared(ObjectSubtype kind,int count,int defaults){
        var value=routine(Engine.POSTGRESQL,kind,count).toBuilder().setName("shared").setIdentifier("shared("+String.join(",",Collections.nCopies(count,"integer"))+")").putProperties("signature","shared("+String.join(",",Collections.nCopies(count,"integer"))+")");
        for(int i=count-defaults;i<count;i++)value.putProperties("parameter."+i+".optional","true").putProperties("parameter."+i+".default","7");return value.build();
    }
    private static ParameterInformation information(String marked,List<SchemaObject> metadata){int caret=marked.indexOf('|');String sql=marked.replace("|","");return new SqlAnalysis().analyze(AnalysisRequest.newBuilder().setEngine(Engine.POSTGRESQL).setOperation(AnalysisOperation.PARAMETER_INFORMATION).setSql(sql).setCaretUtf16(caret).build(),LexicalSettings.DEFAULT,contextWith(Engine.POSTGRESQL,metadata)).getParameterInformation();}

    @Test void postgresDefaultExpansionConsidersTheOtherRoutineKindBeforeCallConfidence(){
        var metadata=List.of(shared(ObjectSubtype.FUNCTION,3,2),shared(ObjectSubtype.PROCEDURE,2,1));
        for(String sql:List.of("SELECT public.shared(1|)","CALL public.shared(1|)","CALL public.shared(1, |)")){
            var result=information(sql,metadata);assertEquals("partial-signatures",result.getAvailability(),sql);assertEquals(1,result.getOverloadsCount());assertTrue(result.getOverloads(0).getParameters(1).getOptional());assertEquals("7",result.getOverloads(0).getParameters(1).getDefaultExpression());
        }
        assertEquals("available",information("SELECT public.shared(1,2,3|)",metadata).getAvailability(),"The opposite-kind maximum is two, so full function arity has no mixed-kind candidate");
        var catalog=new SemanticCatalog(new Dialect(Engine.POSTGRESQL,LexicalSettings.DEFAULT),contextWith(Engine.POSTGRESQL,metadata),AnalysisBudget.interactive());
        assertTrue(catalog.routines("shared").getFirst().parameters().get(1).optional());
        assertTrue(RoutineSignatures.from(metadata.getFirst(),Engine.POSTGRESQL).complete(),"Call uncertainty must not mutate complete captured metadata");
    }

    @Test void postgresMixedKindCallCannotAcquireAConfidentReturnTypeOrArgumentValidation(){
        var metadata=List.of(shared(ObjectSubtype.FUNCTION,3,2),shared(ObjectSubtype.PROCEDURE,2,1));var context=contextWith(Engine.POSTGRESQL,metadata);
        var document=new SemanticDocument("SELECT public.shared(1) AS value",Engine.POSTGRESQL);var binder=document.bind(context);
        assertEquals(SqlTypes.Family.UNKNOWN,binder.project(document.syntax().queries().getFirst()).getFirst().type().family());
        var issues=binder.diagnostics();assertTrue(issues.stream().anyMatch(issue->issue.code().equals("analysis.unavailable")&&issue.incomplete()));
        assertFalse(issues.stream().anyMatch(issue->Set.of("routine.unknown","routine.argument-count","routine.no-matching-overload","routine.ambiguous").contains(issue.code())));
        var complete=new SemanticDocument("SELECT public.shared(1,2,3) AS value",Engine.POSTGRESQL);assertNotEquals(SqlTypes.Family.UNKNOWN,complete.bind(context).project(complete.syntax().queries().getFirst()).getFirst().type().family());
    }

    @Test void postgresAdditionalCandidateDoesNotTurnConservativeAvailabilityIntoAnAmbiguityClaim(){
        var metadata=new ArrayList<>(List.of(shared(ObjectSubtype.FUNCTION,3,2),shared(ObjectSubtype.PROCEDURE,2,1)));
        metadata.add(shared(ObjectSubtype.FUNCTION,1,0).toBuilder().setIdentifier("shared(text)").putProperties("signature","shared(text)").putProperties("parameter.0.type","text").putProperties("parameter.0.nativeTypeId","25").build());
        var result=information("SELECT public.shared('text'|)",metadata);assertEquals("partial-signatures",result.getAvailability());assertEquals(2,result.getOverloadsCount());
        var document=new SemanticDocument("SELECT public.shared('text')",Engine.POSTGRESQL);assertFalse(document.bind(contextWith(Engine.POSTGRESQL,metadata)).diagnostics().stream().anyMatch(issue->issue.code().equals("routine.ambiguous")),"Native coercion/preference may choose another candidate; this policy does not resolve it");
    }

    @Test void postgresEmptyAndNestedArgumentListsKeepTheirActualCallArity(){
        var zero=List.of(shared(ObjectSubtype.FUNCTION,0,0),shared(ObjectSubtype.PROCEDURE,1,0));
        for(String sql:List.of("SELECT public.shared(|)","SELECT public.shared( |"))assertEquals("available",information(sql,zero).getAvailability(),sql);
        assertEquals("partial-signatures",information("SELECT public.shared(|)",List.of(shared(ObjectSubtype.FUNCTION,0,0),shared(ObjectSubtype.PROCEDURE,1,1))).getAvailability());
        var distinct=List.of(shared(ObjectSubtype.FUNCTION,2,0),shared(ObjectSubtype.PROCEDURE,3,0));
        assertEquals("available",information("SELECT public.shared(1, ARRAY[1,2]|)",distinct).getAvailability());
        assertEquals("available",information("CALL public.shared(1,2,|)",distinct).getAvailability());
    }

    @Test void postgresOppositeKindContextUncertaintyDoesNotEraseCapturedArity(){
        var captured=context(Engine.POSTGRESQL);var catalog=new SemanticCatalog(new Dialect(Engine.POSTGRESQL,LexicalSettings.DEFAULT),captured,AnalysisBudget.interactive());
        assertTrue(catalog.routines("abs").stream().anyMatch(signature->!signature.complete()),"The stored two-input function has a preceding builtin/search-path caveat");
        var tokens=LosslessLexer.scan("abs",new Dialect(Engine.POSTGRESQL,LexicalSettings.DEFAULT),AnalysisBudget.interactive()).significant();var name=new SyntaxTree.Name(tokens);
        assertTrue(catalog.callSignatures(name,true,false,3).stream().allMatch(RoutineSignatures.Signature::complete),"Neither the one-input builtin nor the captured two-input function accepts the three-input procedure call");
        assertEquals("available",analyze(Engine.POSTGRESQL,"CALL abs(1,2,|",AnalysisOperation.PARAMETER_INFORMATION).getParameterInformation().getAvailability());
        var unknown=shared(ObjectSubtype.FUNCTION,2,0).toBuilder().putProperties("parameterCount","-1").putProperties("signatureAvailability","UNAVAILABLE").build();
        assertEquals("partial-signatures",information("CALL public.shared(1,2,3|)",List.of(unknown,shared(ObjectSubtype.PROCEDURE,3,0))).getAvailability(),"Missing native parameter/default evidence cannot be excluded by a context-wrapped signature's apparent bounds");
        assertEquals("available",information("CALL public.shared(1,2,3|)",List.of(shared(ObjectSubtype.FUNCTION,2,0),shared(ObjectSubtype.PROCEDURE,3,0))).getAvailability());
    }

    private static List<Completion> complete(Engine engine,String marked,List<SchemaObject> metadata){
        int caret=marked.indexOf('|');String sql=marked.replace("|","");
        var captured=contextWith(engine,metadata);
        return new SqlAnalysis().analyze(AnalysisRequest.newBuilder().setEngine(engine).setOperation(AnalysisOperation.COMPLETION).setSql(sql).setCaretUtf16(caret).build(),LexicalSettings.DEFAULT,captured).getCompletionsList();
    }

    @ParameterizedTest @EnumSource(value=Engine.class,names={"POSTGRESQL","MYSQL","MARIADB"})
    void qualifiedFunctionCompletionReplacesOnlyTheNameAndKeepsItsCentralIdentity(Engine engine){
        var metadata=new ArrayList<>(objects(engine));metadata.add(routine(engine,ObjectSubtype.FUNCTION,2).toBuilder().setCatalog(engine==Engine.POSTGRESQL?"db":"other").setSchema("other").build());
        if(engine==Engine.POSTGRESQL){metadata.add(routine(engine,ObjectSubtype.FUNCTION,2).toBuilder().setCatalog("other").build());metadata.add(routine(engine,ObjectSubtype.PROCEDURE,3).toBuilder().setCatalog("other").build());}
        String marked="SELECT "+schema(engine)+".a|b";var items=complete(engine,marked,metadata);
        assertEquals(1,items.size());var function=items.getFirst();assertEquals("function",function.getKind());assertEquals("abs()",function.getLabel());assertEquals("abs()",function.getInsertText());assertEquals(identity(engine,ObjectSubtype.FUNCTION),function.getTargetIdentity());assertEquals(schema(engine)+" · abs(integer,integer)",function.getDetail());assertEquals(25,function.getRank());assertFalse(function.getQualificationRequired());assertEquals(marked.indexOf(".a")+1,function.getStartUtf16());assertEquals(marked.length()-1,function.getEndUtf16());
        assertEquals(items,complete(engine,marked,metadata),"Captured namespace completion has deterministic ordering");
        if(engine==Engine.POSTGRESQL)for(String call:List.of("SELECT ab|","CALL ab|","CALL public.ab|"))assertTrue(complete(engine,call,metadata).stream().noneMatch(item->contextWith(engine,metadata).snapshot().resolve("other","public",ObjectKind.ROUTINE,"","abs",true).stream().anyMatch(object->object.identity().key().equals(item.getTargetIdentity()))),"A PostgreSQL session cannot invoke routines in another database");
    }

    @ParameterizedTest @EnumSource(value=Engine.class,names={"POSTGRESQL","MYSQL","MARIADB"})
    void quotedQualifiedFunctionCompletionUsesExactNativeNameAndWholeUtf16Replacement(Engine engine){
        String quote=engine==Engine.POSTGRESQL?"\"":"`",name="Mi"+quote+"xed",nativeName=quote+name.replace(quote,quote+quote)+quote;
        var function=routine(engine,ObjectSubtype.FUNCTION,2).toBuilder().setName(name).setIdentifier(name+"(integer,integer)").putProperties("signature",name+"(integer,integer)").build();
        String prefix="/* 😀 */ SELECT "+quote+schema(engine)+quote+".",marked=prefix+nativeName.substring(0,3)+"|"+nativeName.substring(3);
        var items=complete(engine,marked,List.of(function));assertEquals(1,items.size());var completion=items.getFirst();assertEquals(name+"()",completion.getLabel());assertEquals(nativeName+"()",completion.getInsertText());assertEquals("function",completion.getKind());assertTrue(completion.getQuoted());assertFalse(completion.getQualificationRequired());assertEquals(prefix.length(),completion.getStartUtf16());assertEquals(marked.length()-1,completion.getEndUtf16());
        var captured=SemanticFixtures.context(engine,List.of(function),new ResolutionContext("db",schema(engine),List.of(schema(engine)),true,9,2));assertEquals(captured.snapshot().resolve("db",schema(engine),ObjectKind.ROUTINE,"",name,true).getFirst().identity().key(),completion.getTargetIdentity());
    }

    @ParameterizedTest @EnumSource(value=Engine.class,names={"POSTGRESQL","MYSQL","MARIADB"})
    void visibleRelationAliasKeepsPriorityOverSameNamedFunctionNamespace(Engine engine){
        var metadata=new ArrayList<>(objects(engine));metadata.add(SchemaObject.newBuilder().setKind(ObjectKind.TABLE).setCatalog("db").setSchema(schema(engine)).setName("items").build());metadata.add(SchemaObject.newBuilder().setKind(ObjectKind.COLUMN).setCatalog("db").setSchema(schema(engine)).setTable("items").setName("abs_field").putProperties("type","integer").putProperties("jdbcType","4").build());
        String marked="SELECT "+schema(engine)+".ab| FROM "+schema(engine)+".items "+schema(engine);var items=complete(engine,marked,metadata);
        assertEquals(1,items.size());assertEquals("column",items.getFirst().getKind());assertEquals("abs_field",items.getFirst().getInsertText());assertFalse(items.stream().anyMatch(item->item.getKind().equals("function")||item.getKind().equals("procedure")));
    }

    @ParameterizedTest @EnumSource(value=Engine.class,names={"MYSQL","MARIADB"})
    void qualifiedFunctionInAnotherNativeDatabaseRemainsAvailable(Engine engine){
        var function=routine(engine,ObjectSubtype.FUNCTION,2).toBuilder().setCatalog("other").setSchema("other").build();var procedure=routine(engine,ObjectSubtype.PROCEDURE,3).toBuilder().setCatalog("other").setSchema("other").build();var metadata=List.of(function,procedure);
        var items=complete(engine,"SELECT other.a|b",metadata);assertEquals(1,items.size());var completion=items.getFirst();assertEquals("function",completion.getKind());assertEquals("abs()",completion.getLabel());assertEquals("abs()",completion.getInsertText());assertEquals("other · abs(integer,integer)",completion.getDetail());assertEquals(30,completion.getRank());assertEquals(13,completion.getStartUtf16());assertEquals(15,completion.getEndUtf16());assertFalse(completion.getQualificationRequired());assertEquals(contextWith(engine,metadata).snapshot().resolve("other","other",ObjectKind.ROUTINE,"","abs",true).stream().filter(object->object.identity().subtype()==ObjectSubtype.FUNCTION).findFirst().orElseThrow().identity().key(),completion.getTargetIdentity());
    }

}
