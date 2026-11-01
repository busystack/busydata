package io.busystack.busydata;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.analysis.language.*;
import io.busystack.busydata.schema.Explorer;
import java.lang.reflect.Proxy;
import java.sql.Connection;
import java.nio.file.Path;
import java.util.Set;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;
class FunctionCatalogIT {
 @TempDir Path root;
 @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
 void signaturesCompletionAndParameterInformationUseOneExplicitlyWarmedSnapshot(String engine)throws Exception{
  var jdbcCalls=new AtomicInteger();Thread analysisOwner=Thread.currentThread();
  try(var f=new EngineFixture(root,engine,(adapter,request,port)->{
   var physical=adapter.connect(request,port);
   return (Connection)Proxy.newProxyInstance(Connection.class.getClassLoader(),new Class[]{Connection.class},(proxy,method,args)->{
    if(Thread.currentThread()==analysisOwner&&Set.of("prepareStatement","createStatement","getMetaData").contains(method.getName()))jdbcCalls.incrementAndGet();
    try{return method.invoke(physical,args);}catch(java.lang.reflect.InvocationTargetException error){throw error.getCause();}
   });
  })){
   var session=f.open();var explorer=new Explorer(f.metadata);var cold=explorer.metadata().capture(session);
   String prefix="SELECT busy_custom";var completion=AnalysisRequest.newBuilder().setEngine(f.engine).setDocumentId("function-signatures").setDocumentVersion(1).setSql(prefix).setCaretUtf16(prefix.length()).setOperation(AnalysisOperation.COMPLETION);
   assertTrue(f.analysis.analyze(completion.build(),session.context.lexical(),ResolutionContext.UNAVAILABLE).getCompletionsList().stream().noneMatch(item->item.getLabel().startsWith("busy_custom")));
   f.execute(session,f.engine==Engine.POSTGRESQL?
     "CREATE FUNCTION busy_custom_func(amount numeric, factor integer DEFAULT 2) RETURNS numeric LANGUAGE sql AS 'SELECT amount*factor'; CREATE FUNCTION busy_custom_func(amount integer) RETURNS integer LANGUAGE sql AS 'SELECT amount'":
     "CREATE FUNCTION busy_custom_func(amount DECIMAL(30,9), factor INTEGER) RETURNS DECIMAL(30,9) DETERMINISTIC RETURN amount*factor");
   explorer.refreshContext(session);var snapshot=explorer.metadata().capture(session);long contextRevision=session.contextRevision;
   var context=new ResolutionContext(session.context.catalog(),session.context.schema(),session.context.searchPath(),true,snapshot.revision(),snapshot.configurationRevision(),snapshot.rules(),snapshot);
   jdbcCalls.set(0);
   var catalog=new SemanticCatalog(new Dialect(f.engine,session.context.lexical()),context,AnalysisBudget.interactive());
   // PostgreSQL17 typeconv-func: qualification restricts candidates to this
   // schema. Its implicit earlier pg_catalog remains deliberately unrequested.
   // https://www.postgresql.org/docs/17/typeconv-func.html
   if(f.engine==Engine.POSTGRESQL){var unqualified=catalog.routines("busy_custom_func");assertEquals(2,unqualified.size());assertTrue(unqualified.stream().noneMatch(RoutineSignatures.Signature::complete),"Unrequested earlier pg_catalog cannot prove unqualified overload completeness");}
   String qualified=session.adapter.quote(session.context.schema())+"."+session.adapter.quote("busy_custom_func");
   var qualifiedName=new SyntaxTree.Name(LosslessLexer.scan(qualified,new Dialect(f.engine,session.context.lexical()),AnalysisBudget.interactive()).significant().stream().filter(LosslessLexer.Token::name).toList());
   var signatures=catalog.routines(qualifiedName);assertEquals(f.engine==Engine.POSTGRESQL?2:1,signatures.size());assertTrue(signatures.stream().allMatch(signature->signature.complete()&&!signature.display().isEmpty()&&!signature.returns().nativeName().isEmpty()));
   var visible=f.analysis.analyze(completion.build(),session.context.lexical(),context);assertEquals(signatures.size(),visible.getCompletionsList().stream().filter(item->item.getLabel().equals("busy_custom_func()")&&!item.getDetail().isEmpty()&&!item.getTargetIdentity().isEmpty()&&item.getQualificationRequired()).count());
   String call="SELECT "+qualified+"(1, ";var parameters=f.analysis.analyze(completion.clone().setOperation(AnalysisOperation.PARAMETER_INFORMATION).setSql(call).setCaretUtf16(call.length()).build(),session.context.lexical(),context).getParameterInformation();assertEquals("available",parameters.getAvailability());assertEquals(1,parameters.getActiveArgument());assertEquals(signatures.size(),parameters.getOverloadsCount());assertTrue(parameters.getOverloadsList().stream().anyMatch(signature->signature.getParametersCount()==2&&signature.getParameters(0).getName().equalsIgnoreCase("amount")&&signature.getParameters(1).getMode().equals("IN")));
   if(f.engine==Engine.POSTGRESQL){
    assertTrue(parameters.getOverloadsList().stream().anyMatch(signature->signature.getParametersCount()==2&&signature.getParameters(1).getOptional()));
    String unqualified="SELECT busy_custom_func(1, ";var partial=f.analysis.analyze(completion.clone().setOperation(AnalysisOperation.PARAMETER_INFORMATION).setSql(unqualified).setCaretUtf16(unqualified.length()).build(),session.context.lexical(),context).getParameterInformation();assertEquals("partial-signatures",partial.getAvailability());assertEquals(2,partial.getOverloadsCount());
   }
   assertEquals(0,jdbcCalls.get(),"Warm completion/signature services must perform no JDBC work");assertEquals(contextRevision,session.contextRevision);assertEquals(TransactionState.IDLE,session.adapter.transaction(session.connection));
   assertTrue(cold.objects().stream().noneMatch(object->object.getKind()==ObjectKind.ROUTINE&&object.getName().equals("busy_custom_func")),"Readers keep their immutable captured snapshot");
  }
 }
 @ParameterizedTest @ValueSource(strings={"MYSQL","MARIADB"})
 void nativeFunctionsStoredFunctionsAndProceduresUseTheServerResolutionRulesAfterOpaqueCalls(String engine)throws Exception{
  var jdbcCalls=new AtomicInteger();Thread analysisOwner=Thread.currentThread();
  try(var f=new EngineFixture(root,engine,(adapter,request,port)->{
   var physical=adapter.connect(request,port);
   return (Connection)Proxy.newProxyInstance(Connection.class.getClassLoader(),new Class[]{Connection.class},(proxy,method,args)->{
    if(Thread.currentThread()==analysisOwner&&Set.of("prepareStatement","createStatement","getMetaData").contains(method.getName()))jdbcCalls.incrementAndGet();
    try{return method.invoke(physical,args);}catch(java.lang.reflect.InvocationTargetException error){throw error.getCause();}
   });
  })){
   var session=f.open();String database=session.adapter.quote(session.context.catalog()),qualified=database+"."+session.adapter.quote("abs");
   f.execute(session,"CREATE FUNCTION "+qualified+"(amount INTEGER,factor INTEGER) RETURNS INTEGER DETERMINISTIC RETURN amount*factor; CREATE PROCEDURE "+qualified+"(IN amount INTEGER,IN factor INTEGER,IN extra INTEGER) SELECT amount*factor+extra AS procedure_value");
   var oracle=f.execute(session,"SELECT abs(-3),`ABS`(-3),"+qualified+"(-3,7)");
   var row=f.results.get(oracle.info().getResults(0).getResultId()).read(0);assertEquals("3",io.busystack.busydata.results.Values.text(row.getValues(0)));assertEquals("3",io.busystack.busydata.results.Values.text(row.getValues(1)));assertEquals("-21",io.busystack.busydata.results.Values.text(row.getValues(2)));
   var call=f.execute(session,"CALL "+qualified+"(-3,7,1)");
   var returned=call.info().getResultsList().stream().filter(result->!result.getResultId().isEmpty()).findFirst().orElseThrow();assertEquals("-20",io.busystack.busydata.results.Values.text(f.results.get(returned.getResultId()).read(0).getValues(0)));
   var explorer=new Explorer(f.metadata);explorer.refreshContext(session);var snapshot=explorer.metadata().capture(session);
   assertEquals(io.busystack.busydata.metadata.MetadataState.UNKNOWN,snapshot.sessionResolution().state(),"A durable refresh cannot certify the whole session-local table inventory");
   var context=new ResolutionContext(session.context.catalog(),session.context.schema(),session.context.searchPath(),true,snapshot.revision(),snapshot.configurationRevision(),snapshot.rules(),snapshot);
   var nativeRoutines=snapshot.resolve(session.context.catalog(),session.context.schema(),ObjectKind.ROUTINE,"","abs",true);
   var nativeFunction=nativeRoutines.stream().filter(object->object.identity().subtype()==ObjectSubtype.FUNCTION).findFirst().orElseThrow();
   var nativeProcedure=nativeRoutines.stream().filter(object->object.identity().subtype()==ObjectSubtype.PROCEDURE).findFirst().orElseThrow();
   String functionIdentity=nativeFunction.identity().key(),procedureIdentity=nativeProcedure.identity().key();
   assertNotEquals(functionIdentity,procedureIdentity);
   assertEquals("2",nativeFunction.properties().get("parameterCount"));assertEquals("3",nativeProcedure.properties().get("parameterCount"));
   assertFalse(nativeFunction.properties().getOrDefault("returnType","").isEmpty(),"Only the function has its native position-zero return descriptor");assertTrue(nativeProcedure.properties().getOrDefault("returnType","").isEmpty());
   for(int index=0;index<3;index++){
    String expected=java.util.List.of("amount","factor","extra").get(index);
    assertEquals(expected,nativeProcedure.properties().get("parameter."+index+".name"));assertEquals("IN",nativeProcedure.properties().get("parameter."+index+".mode"));
    if(index<2){assertEquals(expected,nativeFunction.properties().get("parameter."+index+".name"));assertEquals("IN",nativeFunction.properties().get("parameter."+index+".mode"));}
   }
   int beforeUnknownKind=jdbcCalls.get();
   var unsupported=assertThrows(java.sql.SQLFeatureNotSupportedException.class,()->io.busystack.busydata.metadata.RoutineMetadataReader.enrich(session,snapshot.projection(nativeFunction).toBuilder().clearSubtype().build()));
   assertEquals("0A000",unsupported.getSQLState());assertEquals(beforeUnknownKind,jdbcCalls.get(),"An unverified kind must not issue a name-only parameter query");
   jdbcCalls.set(0);
   for(String nativeName:java.util.List.of("abs","`ABS`")){
    String sql="SELECT "+nativeName+"(";var parameters=f.analysis.analyze(AnalysisRequest.newBuilder().setEngine(f.engine).setOperation(AnalysisOperation.PARAMETER_INFORMATION).setSql(sql).setCaretUtf16(sql.length()).build(),session.context.lexical(),context).getParameterInformation();
    assertEquals("available",parameters.getAvailability());assertEquals(1,parameters.getOverloadsCount());assertTrue(parameters.getOverloads(0).getIdentity().startsWith("builtin:"));assertEquals(1,parameters.getOverloads(0).getParametersCount());
   }
   String functionSql="SELECT "+qualified+"(1,";var function=f.analysis.analyze(AnalysisRequest.newBuilder().setEngine(f.engine).setOperation(AnalysisOperation.PARAMETER_INFORMATION).setSql(functionSql).setCaretUtf16(functionSql.length()).build(),session.context.lexical(),context).getParameterInformation();assertEquals("available",function.getAvailability());assertEquals(1,function.getOverloadsCount());assertEquals(functionIdentity,function.getOverloads(0).getIdentity());assertEquals(2,function.getOverloads(0).getParametersCount());
   String procedureSql="CALL "+qualified+"(1,2,";var procedure=f.analysis.analyze(AnalysisRequest.newBuilder().setEngine(f.engine).setOperation(AnalysisOperation.PARAMETER_INFORMATION).setSql(procedureSql).setCaretUtf16(procedureSql.length()).build(),session.context.lexical(),context).getParameterInformation();assertEquals("available",procedure.getAvailability());assertEquals(1,procedure.getOverloadsCount());assertEquals(procedureIdentity,procedure.getOverloads(0).getIdentity());assertEquals(3,procedure.getOverloads(0).getParametersCount());
   String completionSql="CALL ab";var completion=f.analysis.analyze(AnalysisRequest.newBuilder().setEngine(f.engine).setOperation(AnalysisOperation.COMPLETION).setSql(completionSql).setCaretUtf16(completionSql.length()).build(),session.context.lexical(),context).getCompletionsList();assertEquals(1,completion.size());assertEquals("procedure",completion.getFirst().getKind());assertEquals(procedureIdentity,completion.getFirst().getTargetIdentity());
   var diagnostics=f.analysis.analyze(AnalysisRequest.newBuilder().setEngine(f.engine).setOperation(AnalysisOperation.DIAGNOSTICS).setSql("SELECT "+qualified+"(1,2,3)").build(),session.context.lexical(),context).getDiagnosticsList();assertTrue(diagnostics.stream().anyMatch(item->item.getCode().equals("routine.argument-count")),"Fresh qualified routine coverage remains authoritative while only table resolution is unknown");
   assertEquals(0,jdbcCalls.get(),"All semantic requests read the one captured snapshot");
   for(String name:java.util.List.of("COUNT","MIN","MAX","SUM"))f.execute(session,"CREATE FUNCTION "+database+"."+session.adapter.quote(name)+" (amount INTEGER) RETURNS INTEGER DETERMINISTIC RETURN amount+100");
   for(String mode:java.util.List.of("","IGNORE_SPACE")){
    f.execute(session,"SET SESSION sql_mode='"+mode+"'");explorer.refreshContext(session);var modeSnapshot=explorer.metadata().capture(session);var modeLexical=session.context.lexical();assertEquals(!mode.isEmpty(),modeLexical.ignoreSpace());var modeContext=new ResolutionContext(session.context.catalog(),session.context.schema(),session.context.searchPath(),true,modeSnapshot.revision(),modeSnapshot.configurationRevision(),modeSnapshot.rules(),modeSnapshot);
    for(String name:java.util.List.of("COUNT","MIN","MAX","SUM")){
     String storedIdentity=modeSnapshot.resolve(session.context.catalog(),session.context.schema(),ObjectKind.ROUTINE,"",name,true).stream().filter(object->object.identity().subtype()==ObjectSubtype.FUNCTION).findFirst().orElseThrow().identity().key();
     var expressions=new java.util.LinkedHashMap<String,Boolean>();expressions.put(name+"(1)",true);expressions.put(name+" (1)",!mode.isEmpty());expressions.put(name+"\t(1)",!mode.isEmpty());expressions.put(name+"/*c*/(1)",false);expressions.put(name+" /*c*/ (1)",false);expressions.put("`"+name+"`(1)",false);expressions.put(database+".`"+name+"` (1)",false);
     for(var entry:expressions.entrySet()){
      String sql="SELECT "+entry.getKey();var actual=f.execute(session,sql);String expected=entry.getValue()?"1":"101";assertEquals(expected,io.busystack.busydata.results.Values.text(f.results.get(actual.info().getResults(0).getResultId()).read(0).getValues(0)),mode+":"+sql);
      jdbcCalls.set(0);var information=f.analysis.analyze(AnalysisRequest.newBuilder().setEngine(f.engine).setOperation(AnalysisOperation.PARAMETER_INFORMATION).setSql(sql).setCaretUtf16(sql.length()-1).build(),modeLexical,modeContext).getParameterInformation();assertEquals("available",information.getAvailability(),mode+":"+sql);assertEquals(1,information.getOverloadsCount());assertEquals(entry.getValue(),information.getOverloads(0).getIdentity().startsWith("builtin:"),mode+":"+sql);if(!entry.getValue())assertEquals(storedIdentity,information.getOverloads(0).getIdentity());
      var formatted=f.analysis.analyze(AnalysisRequest.newBuilder().setEngine(f.engine).setOperation(AnalysisOperation.FORMAT).setSql(sql).build(),modeLexical,modeContext);assertEquals("available",formatted.getAvailability());assertEquals(sql,formatted.getFormattedSql());assertEquals(0,jdbcCalls.get(),"Semantic name recognition and formatting must not execute catalog SQL");
     }
    }
   }

  }
 }

}
