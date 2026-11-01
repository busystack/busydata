package io.busystack.busydata;

import io.busystack.busydata.analysis.language.ResolutionContext;
import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.Explorer;
import io.busystack.busydata.sessions.SessionRegistry;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Proxy;
import java.nio.file.Path;
import java.nio.file.Files;
import java.sql.Connection;
import java.sql.SQLException;
import java.util.*;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.stream.Stream;
import org.junit.jupiter.api.function.Executable;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;
import static org.junit.jupiter.api.Assertions.*;

/** Native comparisons are the oracle; neither Java case conversion nor a
 * string collation query is assumed to implement an identifier namespace. */
class NativeIdentifierCaseRulesIT {
    @TempDir Path root;
    private record Corpus(String tag,String original,List<String> spellings){}
    private static final List<Corpus> CORPUS=List.of(
        new Corpus("sigma","ΟΣ",List.of("ΟΣ","οσ","ος")),
        new Corpus("dotted_i","İ",List.of("İ","i","I","i\u0307")),
        new Corpus("sharp_s","ẞ",List.of("ẞ","ß","SS")),
        new Corpus("accent","Ñ",List.of("Ñ","ñ","N")),
        new Corpus("ascii","Aa",List.of("Aa","aa","AA")));
    private enum Missing { COLUMN, TABLE, ALIAS, FUNCTION }
    private record Outcome(boolean accepted,String sqlState,int nativeCode) {
        String diagnostic(){return "accepted="+accepted+",sqlState="+sqlState+",nativeCode="+nativeCode;}
    }
    private record NameProbe(String tag,ObjectKind kind,String parent,String actualName,
                             String spelling,Outcome oracle){}
    private record AliasProbe(String tag,String declared,String spelling,Outcome oracle){}
    private record ProofProbe(String tag,String table,String sql,String nativeColumn){}
    private record DuplicateProbe(String tag,ObjectKind kind,Outcome outcome){}
    private record TriggerLookup(String actualName,Outcome outcome){}
    private record ExactNamesProbe(String parent,Set<String> names,boolean dropUnambiguous){}

    static Stream<Arguments> enginesAndCaseModes(){
        return Stream.of(Arguments.of("POSTGRESQL",0),Arguments.of("MYSQL",0),
            Arguments.of("MYSQL",1),Arguments.of("MARIADB",0),Arguments.of("MARIADB",1));
    }

    @ParameterizedTest(name="{0}, lower_case_table_names={1}")
    @MethodSource("enginesAndCaseModes")
    void nativeUnicodeOraclesAgreeAcrossCapturedMetadata(String engine,int mode)throws Exception {
        var observing=new AtomicBoolean();var readerJdbc=new AtomicInteger();Thread reader=Thread.currentThread();
        try(var fixture=new EngineFixture(root,engine,(adapter,request,port)->{
            var physical=adapter.connect(request,port);
            return (Connection)Proxy.newProxyInstance(Connection.class.getClassLoader(),new Class[]{Connection.class},(proxy,method,args)->{
                if(observing.get()&&Thread.currentThread()==reader&&Set.of("createStatement","prepareStatement","getMetaData").contains(method.getName()))readerJdbc.incrementAndGet();
                try{return method.invoke(physical,args);}catch(InvocationTargetException failure){throw failure.getCause();}
            });
        },database->{
            if(!engine.equals("POSTGRESQL"))database.withCommand("--lower_case_table_names="+mode,
                "--character-set-server=utf8mb4","--collation-server=utf8mb4_unicode_ci");
        })){
            var session=fixture.open();fixture.introspectionLevel(session,IntrospectionLevel.STRUCTURE);
            if(fixture.engine==Engine.POSTGRESQL){
                try(var statement=session.connection.createStatement();var rows=statement.executeQuery("SHOW server_encoding")){
                    assertTrue(rows.next());assertEquals("UTF8",rows.getString(1));
                }
            }else{
                try(var statement=session.connection.createStatement();var rows=statement.executeQuery("SELECT @@lower_case_table_names,@@lower_case_file_system")){
                    assertTrue(rows.next());assertEquals(mode,rows.getInt(1));assertFalse(rows.wasNull());
                    assertEquals(0,rows.getInt(2),"Pinned native matrix requires a case-sensitive server filesystem");assertFalse(rows.wasNull());assertFalse(rows.next());
                }
                assertFalse(session.identifierContext.lowerCaseFileSystem());
            }
            var probes=new ArrayList<NameProbe>();var aliases=new ArrayList<AliasProbe>();var proofs=new ArrayList<ProofProbe>();
            var duplicates=new ArrayList<DuplicateProbe>();var exactForeignNames=new ArrayList<ExactNamesProbe>();var foreignUniqueness=new ArrayList<NameProbe>();
            execute(session,"CREATE TABLE "+table(session,fixture,"unicode_alias_source")+" (id INTEGER PRIMARY KEY)","alias-setup");
            execute(session,"INSERT INTO "+table(session,fixture,"unicode_alias_source")+" VALUES(1)","alias-row");
            execute(session,"CREATE TABLE "+table(session,fixture,"unicode_parent")+" (id INTEGER PRIMARY KEY)","parent-setup");
            // Calibrate the structured duplicate result using a known identical
            // ASCII identifier. No server message is parsed or retained.
            execute(session,"CREATE TABLE "+table(session,fixture,"unicode_duplicate_control")+" (id INTEGER PRIMARY KEY,parent_id INTEGER)","duplicate-setup");
            String control=table(session,fixture,"unicode_duplicate_control");
            String addControl="ALTER TABLE "+control+" ADD CONSTRAINT "+quote(session,"unicode_fk_control")+
                " FOREIGN KEY(parent_id) REFERENCES "+table(session,fixture,"unicode_parent")+"(id)";
            execute(session,addControl,"duplicate-fk-original");
            Outcome duplicateFk=duplicate(session,addControl,"duplicate-fk-control");
            assertFalse(duplicateFk.accepted(),duplicateFk.diagnostic());
            String controlIndex="CREATE INDEX "+quote(session,"unicode_ix_control")+" ON "+control+"(parent_id)";
            execute(session,controlIndex,"duplicate-index-original");
            Outcome duplicateIndex=duplicate(session,controlIndex,"duplicate-index-control");
            assertFalse(duplicateIndex.accepted(),duplicateIndex.diagnostic());
            String controlCheck="ALTER TABLE "+control+" ADD CONSTRAINT "+quote(session,"unicode_ck_control")+" CHECK(id>=0)";
            execute(session,controlCheck,"duplicate-check-original");
            Outcome duplicateCheck=duplicate(session,controlCheck,"duplicate-check-control");
            assertFalse(duplicateCheck.accepted(),duplicateCheck.diagnostic());
            // Public DROP lookup is an independent native contract. Dictionary
            // uniqueness can differ and must never stand in for name lookup.
            Outcome missingForeign=dropForeign(session,control,"unicode_fk_missing_control","missing-fk-control");
            assertFalse(missingForeign.accepted());assertTrue(missingForeign.sqlState().startsWith("42"),missingForeign.diagnostic());
            assertTrue(dropForeign(session,control,"unicode_fk_control","existing-fk-control").accepted());
            execute(session,addControl,"restore-fk-control");

            // Establish every native outcome before making any central-rule
            // assertion, so one RED mismatch cannot hide a later namespace.
            for(int caseIndex=0;caseIndex<CORPUS.size();caseIndex++){
                Corpus corpus=CORPUS.get(caseIndex);String columnTable="unicode_column_"+caseIndex;
                execute(session,"CREATE TABLE "+table(session,fixture,columnTable)+" (id INTEGER PRIMARY KEY,"+quote(session,corpus.original())+" INTEGER)",corpus.tag()+"-column-create");
                execute(session,"INSERT INTO "+table(session,fixture,columnTable)+" VALUES(1,17)",corpus.tag()+"-column-row");
                String physical="unicode_table_"+caseIndex+"_"+corpus.original();
                execute(session,"CREATE TABLE "+table(session,fixture,physical)+" (id INTEGER PRIMARY KEY)",corpus.tag()+"-table-create");
                execute(session,"INSERT INTO "+table(session,fixture,physical)+" VALUES(1)",corpus.tag()+"-table-row");
                String actualTable=nativeTable(session,"SELECT id FROM "+table(session,fixture,physical),corpus.tag());
                String declared="unicode_alias_"+corpus.original();
                String function="unicode_fn_"+caseIndex+"_"+corpus.original();
                String createFunction=fixture.engine==Engine.POSTGRESQL?
                    "CREATE FUNCTION "+routine(session,fixture,function)+"(amount INTEGER) RETURNS INTEGER LANGUAGE sql AS 'SELECT amount+23'":
                    "CREATE FUNCTION "+routine(session,fixture,function)+"(amount INTEGER) RETURNS INTEGER DETERMINISTIC RETURN amount+23";
                execute(session,createFunction,corpus.tag()+"-function-create");
                String trigger="unicode_tg_"+caseIndex+"_"+corpus.original();
                String actualTrigger="";
                if(fixture.engine!=Engine.POSTGRESQL){
                    execute(session,"CREATE TRIGGER "+routine(session,fixture,trigger)+" BEFORE INSERT ON "+table(session,fixture,columnTable)+
                        " FOR EACH ROW SET NEW.id=NEW.id",corpus.tag()+"-trigger-create");
                    var originalTrigger=trigger(session,fixture,trigger,corpus.tag()+"-trigger-original");
                    assertTrue(originalTrigger.outcome().accepted(),originalTrigger.outcome().diagnostic());actualTrigger=originalTrigger.actualName();
                }
                boolean selectedProof=false;
                for(int variant=0;variant<corpus.spellings().size();variant++){
                    String spelling=corpus.spellings().get(variant),tag=corpus.tag()+"-"+variant;
                    String columnSql="SELECT "+quote(session,spelling)+" FROM "+table(session,fixture,columnTable);
                    Outcome column=select(session,columnSql,17,Missing.COLUMN,tag);
                    probes.add(new NameProbe(tag,ObjectKind.COLUMN,columnTable,corpus.original(),spelling,column));
                    if(column.accepted()&&(!spelling.equals(corpus.original())||!selectedProof)){
                        if(selectedProof)proofs.removeLast();
                        proofs.add(new ProofProbe(tag,columnTable,columnSql,corpus.original()));selectedProof=true;
                    }
                    String duplicateTable="unicode_dup_"+caseIndex+"_"+variant;
                    String paired="CREATE TABLE "+table(session,fixture,duplicateTable)+" ("+
                        quote(session,corpus.original())+" INTEGER,"+quote(session,spelling)+" INTEGER)";
                    Outcome columnDuplicate=duplicate(session,paired,tag+"-column-duplicate");
                    duplicates.add(new DuplicateProbe(tag,ObjectKind.COLUMN,columnDuplicate));
                    assertEquals(!column.accepted(),columnDuplicate.accepted(),tag+" native column SELECT/duplicate disagreement: "+column.diagnostic()+" / "+columnDuplicate.diagnostic());
                    String tableSpelling="unicode_table_"+caseIndex+"_"+spelling;
                    probes.add(new NameProbe(tag,ObjectKind.TABLE,"",actualTable,tableSpelling,
                        select(session,"SELECT id FROM "+table(session,fixture,tableSpelling),1,Missing.TABLE,tag)));
                    String aliasSpelling="unicode_alias_"+spelling;
                    aliases.add(new AliasProbe(tag,declared,aliasSpelling,select(session,"SELECT "+quote(session,aliasSpelling)+".id FROM "+
                        table(session,fixture,"unicode_alias_source")+" AS "+quote(session,declared),1,Missing.ALIAS,tag)));
                    String functionSpelling="unicode_fn_"+caseIndex+"_"+spelling;
                    probes.add(new NameProbe(tag,ObjectKind.ROUTINE,"",function,functionSpelling,
                        select(session,"SELECT "+routine(session,fixture,functionSpelling)+"(7)",30,Missing.FUNCTION,tag)));
                    if(fixture.engine!=Engine.POSTGRESQL){
                        String triggerSpelling="unicode_tg_"+caseIndex+"_"+spelling;
                        var triggerLookup=trigger(session,fixture,triggerSpelling,tag+"-trigger-lookup");
                        if(triggerLookup.outcome().accepted())assertEquals(actualTrigger,triggerLookup.actualName(),tag+" native trigger owner differs");
                        probes.add(new NameProbe(tag,ObjectKind.TRIGGER,columnTable,actualTrigger,triggerSpelling,triggerLookup.outcome()));
                    }

                    String indexTable="unicode_index_"+caseIndex+"_"+variant;
                    execute(session,"CREATE TABLE "+table(session,fixture,indexTable)+" (id INTEGER PRIMARY KEY,parent_id INTEGER)",tag+"-index-table");
                    String index="unicode_ix_"+caseIndex+"_"+variant+"_"+corpus.original();
                    String indexSpelling="unicode_ix_"+caseIndex+"_"+variant+"_"+spelling;
                    execute(session,"CREATE INDEX "+quote(session,index)+" ON "+table(session,fixture,indexTable)+"(parent_id)",tag+"-index-create");
                    Outcome indexDuplicate=duplicate(session,"CREATE INDEX "+quote(session,indexSpelling)+" ON "+table(session,fixture,indexTable)+"(id)",tag+"-index-duplicate");
                    duplicates.add(new DuplicateProbe(tag,ObjectKind.INDEX,indexDuplicate));
                    sameDuplicateSignature(indexDuplicate,duplicateIndex,tag+"-index");
                    probes.add(new NameProbe(tag,ObjectKind.INDEX,indexTable,indexDuplicate.accepted()?indexSpelling:index,indexSpelling,new Outcome(true,"",0)));

                    String check="unicode_ck_"+caseIndex+"_"+variant+"_"+corpus.original();
                    String checkSpelling="unicode_ck_"+caseIndex+"_"+variant+"_"+spelling;
                    execute(session,"ALTER TABLE "+table(session,fixture,indexTable)+" ADD CONSTRAINT "+quote(session,check)+" CHECK(id>=0)",tag+"-check-create");
                    Outcome checkDuplicate=duplicate(session,"ALTER TABLE "+table(session,fixture,indexTable)+" ADD CONSTRAINT "+quote(session,checkSpelling)+" CHECK(id>=0)",tag+"-check-duplicate");
                    duplicates.add(new DuplicateProbe(tag,ObjectKind.CONSTRAINT,checkDuplicate));
                    sameDuplicateSignature(checkDuplicate,duplicateCheck,tag+"-check");
                    probes.add(new NameProbe(tag,ObjectKind.CONSTRAINT,indexTable,checkDuplicate.accepted()?checkSpelling:check,checkSpelling,new Outcome(true,"",0)));

                    String child="unicode_child_"+caseIndex+"_"+variant;
                    execute(session,"CREATE TABLE "+table(session,fixture,child)+" (id INTEGER PRIMARY KEY,parent_id INTEGER)",tag+"-child-table");
                    String foreign="unicode_fk_"+caseIndex+"_"+variant+"_"+corpus.original();
                    String foreignSpelling="unicode_fk_"+caseIndex+"_"+variant+"_"+spelling;
                    String foreignTail=" FOREIGN KEY(parent_id) REFERENCES "+table(session,fixture,"unicode_parent")+"(id)";
                    execute(session,"ALTER TABLE "+table(session,fixture,child)+" ADD CONSTRAINT "+quote(session,foreign)+foreignTail,tag+"-fk-create");
                    Outcome foreignDuplicate=duplicate(session,"ALTER TABLE "+table(session,fixture,child)+" ADD CONSTRAINT "+quote(session,foreignSpelling)+foreignTail,tag+"-fk-duplicate");
                    duplicates.add(new DuplicateProbe(tag,ObjectKind.FOREIGN_KEY,foreignDuplicate));
                    sameDuplicateSignature(foreignDuplicate,duplicateFk,tag+"-fk");
                    foreignUniqueness.add(new NameProbe(tag,ObjectKind.FOREIGN_KEY,child,foreignDuplicate.accepted()?foreignSpelling:foreign,foreignSpelling,new Outcome(true,"",0)));

                    String lookupTable="unicode_fk_lookup_"+caseIndex+"_"+variant;
                    execute(session,"CREATE TABLE "+table(session,fixture,lookupTable)+" (id INTEGER PRIMARY KEY,parent_id INTEGER)",tag+"-fk-lookup-table");
                    String lookup="unicode_fk_lookup_"+caseIndex+"_"+variant+"_"+corpus.original();
                    String lookupSpelling="unicode_fk_lookup_"+caseIndex+"_"+variant+"_"+spelling;
                    String lookupCreate="ALTER TABLE "+table(session,fixture,lookupTable)+" ADD CONSTRAINT "+quote(session,lookup)+foreignTail;
                    execute(session,lookupCreate,tag+"-fk-lookup-original");
                    Outcome lookupOutcome=dropForeign(session,table(session,fixture,lookupTable),lookupSpelling,tag+"-fk-lookup");
                    if(!lookupOutcome.accepted())assertEquals(missingForeign,lookupOutcome,tag+" FK lookup differs from missing ASCII control");
                    else execute(session,lookupCreate,tag+"-fk-lookup-fixture-restore");
                    probes.add(new NameProbe(tag,ObjectKind.FOREIGN_KEY,lookupTable,lookup,lookupSpelling,lookupOutcome));
                    exactForeignNames.add(new ExactNamesProbe(child,foreignDuplicate.accepted()?Set.of(foreign,foreignSpelling):Set.of(foreign),!foreignDuplicate.accepted()||!lookupOutcome.accepted()));
                }
            }
            var nativeReport=new LinkedHashMap<String,Object>();nativeReport.put("engine",engine);nativeReport.put("lowerCaseTableNames",mode);
            nativeReport.put("lowerCaseFileSystem",session.identifierContext.lowerCaseFileSystem());
            nativeReport.put("scope","Native fixture identifier outcomes collected before central assertions; no central passing claim");
            nativeReport.put("serverVersion",session.connection.getMetaData().getDatabaseProductVersion());
            nativeReport.put("lookups",probes);nativeReport.put("aliases",aliases);nativeReport.put("duplicates",duplicates);
            nativeReport.put("foreignDuplicateControl",duplicateFk);nativeReport.put("indexDuplicateControl",duplicateIndex);nativeReport.put("checkDuplicateControl",duplicateCheck);
            nativeReport.put("foreignMissingLookupControl",missingForeign);nativeReport.put("foreignExactNames",exactForeignNames);nativeReport.put("foreignUniqueness",foreignUniqueness);
            Path nativeOutput=Path.of("target/p0-identifier-case-oracle-"+engine+"-"+mode+".json");Files.createDirectories(nativeOutput.getParent());
            Files.writeString(nativeOutput,new com.google.gson.GsonBuilder().setPrettyPrinting().create().toJson(nativeReport));
            var explorer=new Explorer(fixture.metadata);explorer.refreshContext(session);
            for(var proof:proofs)fixture.warm(session,proof.table());
            var snapshot=explorer.metadata().capture(session);
            var context=new ResolutionContext(session.context.catalog(),session.context.schema(),session.context.searchPath(),true,
                snapshot.revision(),snapshot.configurationRevision(),snapshot.rules(),snapshot);
            var checks=new ArrayList<Executable>();
            for(var probe:probes)checks.add(()->{
                observing.set(true);
                try{
                    String catalog=session.context.catalog(),schema=fixture.schema();
                    var expected=snapshot.namespace(catalog,schema,probe.kind(),probe.parent()).stream()
                        .filter(object->object.identity().name().equals(probe.actualName())).toList();
                    assertEquals(1,expected.size(),label(engine,mode,probe)+" native original missing from captured namespace");
                    List<MetadataObject> matches;
                    if(probe.kind()==ObjectKind.FOREIGN_KEY){
                        assertTrue(snapshot.identifierRulesAvailable());
                        assertTrue(snapshot.complete(new MetadataScope(catalog,schema,probe.parent(),ObjectKind.FOREIGN_KEY),IntrospectionLevel.STRUCTURE),label(engine,mode,probe)+" FK scope incomplete");
                        String key=snapshot.rules().constraintDropKey("FOREIGN KEY",probe.spelling());
                        matches=snapshot.namespace(catalog,schema,ObjectKind.FOREIGN_KEY,probe.parent()).stream().filter(object->snapshot.rules().constraintDropKey("FOREIGN KEY",object.identity().name()).equals(key)).toList();
                    }else matches=snapshot.resolve(catalog,schema,probe.kind(),probe.parent(),probe.spelling(),true);
                    assertEquals(probe.oracle().accepted()?Set.of(expected.getFirst().identity().key()):Set.of(),
                        new HashSet<>(matches.stream().map(object->object.identity().key()).toList()),label(engine,mode,probe));
                    if(probe.oracle().accepted()&&(probe.kind()==ObjectKind.COLUMN||probe.kind()==ObjectKind.TABLE||probe.kind()==ObjectKind.ROUTINE)){
                        var completions=completion(fixture,session,context,probe);
                        assertTrue(completions.stream().anyMatch(item->item.getTargetIdentity().equals(expected.getFirst().identity().key())),
                            label(engine,mode,probe)+" completion omitted native target");
                    }
                }finally{observing.set(false);}
            });
            for(var alias:aliases)checks.add(()->{
                observing.set(true);
                try{
                    String prefix="SELECT "+quote(session,alias.spelling())+".";
                    String sql=prefix+" FROM "+table(session,fixture,"unicode_alias_source")+" AS "+quote(session,alias.declared());
                    var result=fixture.analysis.analyze(AnalysisRequest.newBuilder().setEngine(fixture.engine).setOperation(AnalysisOperation.COMPLETION)
                        .setSql(sql).setCaretUtf16(prefix.length()).build(),session.context.lexical(),context);
                    assertEquals(alias.oracle().accepted(),result.getCompletionsList().stream().anyMatch(item->item.getLabel().equals("id")),
                        engine+"/"+mode+"/alias/"+alias.tag()+" "+alias.oracle().diagnostic());
                }finally{observing.set(false);}
            });
            for(var uniqueness:foreignUniqueness)checks.add(()->{
                var matches=snapshot.resolve(session.context.catalog(),fixture.schema(),ObjectKind.FOREIGN_KEY,uniqueness.parent(),uniqueness.spelling(),true);
                assertEquals(Set.of(uniqueness.actualName()),new HashSet<>(matches.stream().map(object->object.identity().name()).toList()),engine+"/"+mode+" FK CREATE uniqueness mismatch "+uniqueness.tag());
            });
            for(var exact:exactForeignNames)checks.add(()->{
                assertTrue(snapshot.identifierRulesAvailable());
                assertTrue(snapshot.complete(new MetadataScope(session.context.catalog(),fixture.schema(),exact.parent(),ObjectKind.FOREIGN_KEY),IntrospectionLevel.STRUCTURE));
                var names=new HashSet<>(snapshot.namespace(session.context.catalog(),fixture.schema(),ObjectKind.FOREIGN_KEY,exact.parent()).stream().map(object->object.identity().name()).toList());
                assertEquals(exact.names(),names,engine+"/"+mode+" native exact FK identities were collapsed");
                var artifactTable=new com.google.gson.JsonObject();var constraints=new com.google.gson.JsonObject();artifactTable.add("constraints",constraints);
                for(String name:names)io.busystack.busydata.schema.SchemaConstraints.put(constraints,name,"FOREIGN KEY","FOREIGN KEY(parent_id) REFERENCES unicode_parent(id)");
                assertEquals(exact.dropUnambiguous(),io.busystack.busydata.schema.SchemaConstraints.foreignKeyDropsUnambiguous(artifactTable,snapshot),engine+"/"+mode+" multiple native DROP matches must remain conservative");
            });
            for(var proof:proofs)checks.add(()->{
                var job=fixture.submit(session,proof.sql());EditingIT.await(job);
                assertEquals(JobState.COMPLETED,job.state,engine+"/"+mode+"/proof/"+proof.tag()+" code="+job.info().getErrorCode());
                var retained=fixture.results.get(job.info().getResults(0).getResultId());
                assertEquals(1,retained.rows());assertEquals("17",io.busystack.busydata.results.Values.text(retained.read(0).getValues(0)));
                assertTrue(retained.metadataProof().available(),engine+"/"+mode+"/proof/"+proof.tag()+" state="+
                    retained.metadataProof().state()+" availability="+retained.metadataProof().availability());
                var retainedColumn=retained.columns.getFirst();assertTrue(retainedColumn.getProvenanceKnown());
                assertEquals(proof.nativeColumn(),retainedColumn.getBaseColumn());assertEquals(proof.table(),retainedColumn.getTable());
                var column=snapshot.namespace(session.context.catalog(),fixture.schema(),ObjectKind.COLUMN,proof.table()).stream()
                    .filter(object->object.identity().name().equals(proof.nativeColumn())).findFirst().orElseThrow();
                var selected=retained.metadataProof().columns().get(retainedColumn.getOrdinal());assertNotNull(selected);
                assertEquals(RetainedMetadataProof.columnFingerprint(column),selected.fingerprint());
                assertEquals(column.properties().getOrDefault("nativeTypeId",""),selected.nativeTypeId());
                assertEquals(column.properties().getOrDefault("jdbcNativeType",column.properties().getOrDefault("type","")),selected.jdbcNativeType());
                var table=snapshot.namespace(session.context.catalog(),fixture.schema(),ObjectKind.TABLE,"").stream().filter(object->object.identity().name().equals(proof.table())).findFirst().orElseThrow();
                assertEquals(table.properties().get("nativeGeneration"),retained.metadataProof().nativeGeneration());
                if(fixture.engine==Engine.POSTGRESQL)assertEquals(column.identity().key(),selected.identity());
                else if(fixture.engine==Engine.MYSQL)assertFalse(selected.identity().isEmpty(),"Native MySQL table/column-generation digest remains required for the ASCII physical fixture");
                else assertEquals("",selected.identity(),"MariaDB does not fabricate a stable column identifier");
            });
            checks.add(()->assertEquals(0,readerJdbc.get(),"Captured lookup/completion must not perform JDBC work"));
            // Unicode physical names intentionally have no editability assertion:
            // the existing filename/native-generation limitation is preserved.
            assertAll(engine+"/lower_case_table_names="+mode,checks);
        }
    }

    private static String label(String engine,int mode,NameProbe probe){
        return engine+"/"+mode+"/"+probe.kind()+"/"+probe.tag()+" "+probe.oracle().diagnostic();
    }
    private static String quote(SessionRegistry.Session session,String name){return session.adapter.quote(name);}
    private static String table(SessionRegistry.Session session,EngineFixture fixture,String name){
        return session.adapter.table(session.context.catalog(),fixture.schema(),name);
    }
    private static String routine(SessionRegistry.Session session,EngineFixture fixture,String name){
        return quote(session,fixture.schema())+"."+quote(session,name);
    }
    private static void execute(SessionRegistry.Session session,String sql,String phase)throws SQLException {
        try(var statement=session.connection.createStatement()){
            statement.setQueryTimeout(5);statement.execute(sql);
        }catch(SQLException error){throw new AssertionError(phase+" sqlState="+Objects.toString(error.getSQLState(),"")+",nativeCode="+error.getErrorCode());}
    }
    private static Outcome duplicate(SessionRegistry.Session session,String sql,String phase)throws SQLException {
        try(var statement=session.connection.createStatement()){
            statement.setQueryTimeout(5);statement.execute(sql);return new Outcome(true,"",0);
        }catch(SQLException error){
            String state=Objects.toString(error.getSQLState(),"");int code=error.getErrorCode();
            boolean known=session.profile.getEngine()==Engine.POSTGRESQL?Set.of("42701","42710","42P07").contains(state):
                Set.of(1005,1022,1060,1061,1826,3822).contains(code)&&Set.of("HY000","42000","42S21").contains(state);
            if(!known)throw new AssertionError(phase+" unexpected native result sqlState="+state+",nativeCode="+code);
            return new Outcome(false,state,code);
        }
    }
    private static void sameDuplicateSignature(Outcome actual,Outcome control,String phase){
        if(!actual.accepted())assertEquals(control,actual,phase+" duplicate result differs from native ASCII control");
    }
    private static Outcome dropForeign(SessionRegistry.Session session,String table,String name,String phase)throws SQLException {
        String keyword=session.profile.getEngine()==Engine.POSTGRESQL?"CONSTRAINT":"FOREIGN KEY";
        try(var statement=session.connection.createStatement()){
            statement.setQueryTimeout(5);statement.execute("ALTER TABLE "+table+" DROP "+keyword+" "+quote(session,name));
            return new Outcome(true,"",0);
        }catch(SQLException error){
            String state=Objects.toString(error.getSQLState(),"");int code=error.getErrorCode();
            if(!state.startsWith("42"))throw new AssertionError(phase+" unexpected native lookup sqlState="+state+",nativeCode="+code);
            return new Outcome(false,state,code);
        }
    }
    private static Outcome select(SessionRegistry.Session session,String sql,int value,Missing missing,String phase)throws SQLException {
        try(var statement=session.connection.createStatement()){
            statement.setQueryTimeout(5);
            try(var rows=statement.executeQuery(sql)){
                assertTrue(rows.next(),phase+" native row missing");assertEquals(value,rows.getInt(1),phase+" native target differs");assertFalse(rows.next());
                return new Outcome(true,"",0);
            }
        }catch(SQLException error){
            String state=Objects.toString(error.getSQLState(),"");int code=error.getErrorCode();
            boolean known=session.profile.getEngine()==Engine.POSTGRESQL?switch(missing){
                case COLUMN->state.equals("42703");case TABLE,ALIAS->state.equals("42P01");case FUNCTION->state.equals("42883");
            }:switch(missing){
                case COLUMN,ALIAS->state.equals("42S22")&&code==1054;case TABLE->state.equals("42S02")&&code==1146;
                case FUNCTION->state.equals("42000")&&code==1305;
            };
            if(!known)throw new AssertionError(phase+" unexpected native lookup sqlState="+state+",nativeCode="+code);
            return new Outcome(false,state,code);
        }
    }
    private static String nativeTable(SessionRegistry.Session session,String sql,String phase)throws SQLException {
        try(var statement=session.connection.createStatement()){
            statement.setQueryTimeout(5);
            try(var rows=statement.executeQuery(sql)){
                assertTrue(rows.next());String name=rows.getMetaData().getTableName(1);assertFalse(name.isEmpty(),phase+" native table identity missing");return name;
            }
        }catch(SQLException error){throw new AssertionError(phase+" table identity sqlState="+Objects.toString(error.getSQLState(),"")+",nativeCode="+error.getErrorCode());}
    }
    private static TriggerLookup trigger(SessionRegistry.Session session,EngineFixture fixture,String name,String phase)throws SQLException {
        try(var statement=session.connection.createStatement()){
            statement.setQueryTimeout(5);
            try(var rows=statement.executeQuery("SHOW CREATE TRIGGER "+routine(session,fixture,name))){
                assertTrue(rows.next(),phase+" native trigger row missing");String actual=rows.getString(1);
                assertNotNull(actual);assertFalse(actual.isEmpty());assertFalse(rows.next());
                return new TriggerLookup(actual,new Outcome(true,"",0));
            }
        }catch(SQLException error){
            String state=Objects.toString(error.getSQLState(),"");int code=error.getErrorCode();
            if(!state.equals("HY000")||code!=1360)throw new AssertionError(phase+" unexpected trigger result sqlState="+state+",nativeCode="+code);
            return new TriggerLookup("",new Outcome(false,state,code));
        }
    }
    private static List<Completion> completion(EngineFixture fixture,SessionRegistry.Session session,ResolutionContext context,NameProbe probe){
        String prefix,sql;
        if(probe.kind()==ObjectKind.COLUMN){
            prefix="SELECT q."+probe.spelling();sql=prefix+" FROM "+table(session,fixture,probe.parent())+" AS q";
        }else if(probe.kind()==ObjectKind.TABLE){
            prefix="SELECT * FROM "+quote(session,fixture.schema())+"."+probe.spelling();sql=prefix;
        }else{
            prefix="SELECT "+quote(session,fixture.schema())+"."+probe.spelling();sql=prefix;
        }
        return fixture.analysis.analyze(AnalysisRequest.newBuilder().setEngine(fixture.engine).setOperation(AnalysisOperation.COMPLETION)
            .setSql(sql).setCaretUtf16(prefix.length()).build(),session.context.lexical(),context).getCompletionsList();
    }
}
