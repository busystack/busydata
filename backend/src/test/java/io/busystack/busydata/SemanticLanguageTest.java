package io.busystack.busydata;

import io.busystack.busydata.analysis.*;
import io.busystack.busydata.analysis.language.*;
import io.busystack.busydata.protocol.*;
import java.util.*;
import java.util.concurrent.CancellationException;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import static org.junit.jupiter.api.Assertions.*;

class SemanticLanguageTest {
    private static final ResolutionContext COMPLETE=new ResolutionContext("db","public",List.of("public","audit"),true,7,3);
    private static SchemaObject relation(String schema,String name){return SchemaObject.newBuilder().setKind(ObjectKind.TABLE).setCatalog("db").setSchema(schema).setName(name).build();}
    private static SchemaObject column(String schema,String table,String name,String type){return SchemaObject.newBuilder().setKind(ObjectKind.COLUMN).setCatalog("db").setSchema(schema).setTable(table).setName(name).putProperties("nativeType",type).build();}
    private static String identity(List<SchemaObject> objects,ObjectKind kind,String schema,String parent,String name){return SemanticFixtures.context(Engine.POSTGRESQL,objects,COMPLETE).snapshot().resolve("db",schema,kind,parent,name,true).getFirst().identity().key();}
    private static final List<SchemaObject> OBJECTS=List.of(relation("public","orders"),column("public","orders","id","bigint"),column("public","orders","amount","numeric(30,9)"),column("public","orders","name","text"),relation("public","customers"),column("public","customers","id","bigint"),column("public","customers","customer_name","text"),relation("audit","orders"),column("audit","orders","audit_value","jsonb"));
    private static Analysis request(String sql,int caret,Engine engine,AnalysisOperation operation,List<SchemaObject> metadata,ResolutionContext context){return SemanticFixtures.analyze(new SqlAnalysis(),AnalysisRequest.newBuilder().setDocumentId("doc").setDocumentVersion(19).setSql(sql).setCaretUtf16(caret).setEngine(engine).setOperation(operation).build(),metadata,LexicalSettings.DEFAULT,context);}
    private static List<Completion> complete(String marked,Engine engine,List<SchemaObject> metadata){int caret=marked.indexOf('|');return request(marked.replace("|",""),caret,engine,AnalysisOperation.COMPLETION,metadata,COMPLETE).getCompletionsList();}
    @ParameterizedTest @EnumSource(value=Engine.class,names={"POSTGRESQL","MYSQL","MARIADB"})
    void lexerOwnsEveryOriginalUtf16UnitAndModeDependentQuotedForms(Engine engine){
        String sql="-- 😀 note\r\nSELECT \"odd\", `quoted`, 'a\\b', 12.300e-4, :parameter, ? /* keep */";
        var document=LosslessLexer.scan(sql,new Dialect(engine,LexicalSettings.DEFAULT),AnalysisBudget.interactive());
        assertEquals(sql,String.join("",document.tokens().stream().map(LosslessLexer.Token::text).toList()));int offset=0;
        for(var token:document.tokens()){assertEquals(offset,token.start());assertEquals(token.text(),sql.substring(token.start(),token.end()));offset=token.end();}assertEquals(sql.length(),offset);
        var ansi=LosslessLexer.scan("SELECT \"Odd\\漢\"",new Dialect(engine,new LexicalSettings(true,true,true)),AnalysisBudget.interactive());assertEquals(LosslessLexer.Kind.IDENTIFIER,ansi.significant().get(1).kind());
    }
    @ParameterizedTest @EnumSource(value=Engine.class,names={"POSTGRESQL","MYSQL","MARIADB"})
    void nativeIdentifierCharactersNeverBecomeUnicodeWhitespace(Engine engine){
        for(String identifier:List.of("a\u2002b","a\u00a0b","a\u2028b","a\u0085b","٠name")){
            String sql="SELECT "+identifier+" FROM t";var document=LosslessLexer.scan(sql,new Dialect(engine,LexicalSettings.DEFAULT),AnalysisBudget.interactive());
            var token=document.significant().get(1);assertEquals(LosslessLexer.Kind.WORD,token.kind());assertEquals(identifier,token.text());assertEquals(7,token.start());assertEquals(7+identifier.length(),token.end());
            var formatted=request(sql,sql.length(),engine,AnalysisOperation.FORMAT,List.of(),COMPLETE);assertTrue(formatted.getFormattedSql().contains(identifier));assertEquals(formatted.getFormattedSql(),request(formatted.getFormattedSql(),0,engine,AnalysisOperation.FORMAT,List.of(),COMPLETE).getFormattedSql());
        }
        String supplementary="SELECT a😀b FROM t";var nativeTokens=LosslessLexer.scan(supplementary,new Dialect(engine,LexicalSettings.DEFAULT),AnalysisBudget.interactive());
        assertEquals(engine==Engine.POSTGRESQL,nativeTokens.significant().stream().anyMatch(t->t.kind()==LosslessLexer.Kind.WORD&&t.text().equals("a😀b")));assertEquals(engine!=Engine.POSTGRESQL,nativeTokens.tokens().stream().anyMatch(t->t.kind()==LosslessLexer.Kind.ERROR));
        if(engine!=Engine.POSTGRESQL){var diagnostics=request(supplementary,0,engine,AnalysisOperation.DIAGNOSTICS,OBJECTS,COMPLETE).getDiagnosticsList();assertEquals(1,diagnostics.size());assertEquals("analysis.unavailable",diagnostics.getFirst().getCode());assertTrue(diagnostics.getFirst().getIncomplete());}
        var comment=LosslessLexer.scan("SELECT 1--\u2002name",new Dialect(engine,LexicalSettings.DEFAULT),AnalysisBudget.interactive());assertEquals(engine==Engine.POSTGRESQL,comment.tokens().stream().anyMatch(t->t.kind()==LosslessLexer.Kind.COMMENT));
        if(engine!=Engine.POSTGRESQL)for(String name:List.of("1foo","123abc","9e")){var numericName=LosslessLexer.scan("SELECT "+name,new Dialect(engine,LexicalSettings.DEFAULT),AnalysisBudget.interactive());assertEquals(name,numericName.significant().get(1).text());assertEquals(LosslessLexer.Kind.WORD,numericName.significant().get(1).kind());}
        assertEquals(LosslessLexer.Kind.NUMBER,LosslessLexer.scan("SELECT 5e6",new Dialect(engine,LexicalSettings.DEFAULT),AnalysisBudget.interactive()).significant().get(1).kind());
    }
    @Test void unicodeEscapeSyntaxHasOneLocalizedAvailabilityInsteadOfInventedBindings(){
        for(String escaped:List.of("U&\"a\\0062\"","U&'a\\0062'")){
            String sql="SELECT "+escaped+" FROM orders";var diagnostics=request(sql,0,Engine.POSTGRESQL,AnalysisOperation.DIAGNOSTICS,OBJECTS,COMPLETE).getDiagnosticsList();assertEquals(1,diagnostics.size());assertEquals("analysis.unavailable",diagnostics.getFirst().getCode());assertTrue(diagnostics.getFirst().getIncomplete());assertEquals(escaped,sql.substring(diagnostics.getFirst().getStartUtf16(),diagnostics.getFirst().getEndUtf16()));
            assertTrue(request(sql,0,Engine.POSTGRESQL,AnalysisOperation.FORMAT,OBJECTS,COMPLETE).getFormattedSql().isEmpty());
        }
    }
    @Test void postgresDollarTagsUseNativeIdentifierBytesAndPreserveSupplementaryOffsets(){
        String literal="$😀\u2002tag$body; -- ' 😀$😀\u2002tag$",sql="SELECT "+literal+";";var document=LosslessLexer.scan(sql,new Dialect(Engine.POSTGRESQL,LexicalSettings.DEFAULT),AnalysisBudget.interactive());
        var token=document.significant().get(1);assertEquals(LosslessLexer.Kind.STRING,token.kind());assertEquals(literal,token.text());assertTrue(token.complete());assertEquals(7+literal.length(),token.end());
        for(int value:new int[]{' ','\t','\r','\n','\f',11})assertTrue(SqlLexicalCharacters.isSpace(value));for(int value:new int[]{0x85,0xa0,0x2002,0x2028,0x1f600})assertFalse(SqlLexicalCharacters.isSpace(value));
        assertTrue(SqlLexicalCharacters.identifierStart(0x1f600,Engine.POSTGRESQL));assertFalse(SqlLexicalCharacters.identifierStart(0x1f600,Engine.MYSQL));assertFalse(SqlLexicalCharacters.dollarTagPart('$'));
    }
    @Test void aProvenTrueWhereDoesNotSilenceTheUnrestrictedMutationInspection(){
        for(var engine:List.of(Engine.POSTGRESQL,Engine.MYSQL,Engine.MARIADB)){
            for(String predicate:List.of("TRUE","(1=1)","NOT FALSE"))assertTrue(request("DELETE FROM orders WHERE "+predicate,0,engine,AnalysisOperation.DIAGNOSTICS,OBJECTS,COMPLETE).getDiagnosticsList().stream().anyMatch(d->d.getCode().equals("inspection.unrestricted-delete")),predicate);
            for(String predicate:List.of("FALSE","id=1"))assertFalse(request("DELETE FROM orders WHERE "+predicate,0,engine,AnalysisOperation.DIAGNOSTICS,OBJECTS,COMPLETE).getDiagnosticsList().stream().anyMatch(d->d.getCode().equals("inspection.unrestricted-delete")),predicate);
        }
    }
    @Test void postgresUtf8IdentifierFoldingUsesTheNativeAsciiRule(){
        var rules=new io.busystack.busydata.metadata.IdentifierRules(Engine.POSTGRESQL,0);
        assertEquals("Äcase",rules.lookup(ObjectKind.TABLE,"ÄCASE",false));
        assertEquals("ÄCASE",rules.lookup(ObjectKind.TABLE,"ÄCASE",true));
        assertEquals("iİ",rules.lookup(ObjectKind.TABLE,"Iİ",false));
    }
    @Test void dialectOperatorsNumericAndParameterBoundariesAreDistinct(){
        var doc=LosslessLexer.scan("SELECT $1::numeric, payload->>'field', a #>> '{x}', .5, 9e-4, :p",new Dialect(Engine.POSTGRESQL,LexicalSettings.DEFAULT),AnalysisBudget.interactive());
        assertTrue(doc.significant().stream().anyMatch(t->t.kind()==LosslessLexer.Kind.PARAMETER&&t.text().equals("$1")));
        for(String operator:List.of("::","->>","#>>"))assertTrue(doc.significant().stream().anyMatch(t->t.text().equals(operator)),operator);
        assertTrue(doc.significant().stream().anyMatch(t->t.kind()==LosslessLexer.Kind.NUMBER&&t.text().equals("9e-4")));
    }
    @Test void statementScopesNeverLeakAliasesIntoAnotherStatement(){
        assertTrue(complete("SELECT x.id FROM orders x; SELECT x.| FROM customers c",Engine.POSTGRESQL,OBJECTS).isEmpty());
        assertTrue(complete("SELECT o.am| FROM orders o",Engine.POSTGRESQL,OBJECTS).stream().anyMatch(c->c.getLabel().equals("amount")&&c.getDetail().contains("numeric(30,9)")&&c.getTargetIdentity().equals(identity(OBJECTS,ObjectKind.COLUMN,"public","orders","amount"))));
    }
    @Test void duplicateNamesPreserveNamespaceChoicesAndAmbiguousColumnsQualify(){
        var names=complete("SELECT * FROM ord|",Engine.POSTGRESQL,OBJECTS);var choices=names.stream().filter(c->c.getLabel().equals("orders")).toList();assertEquals(2,choices.size());assertTrue(choices.stream().allMatch(Completion::getQualificationRequired));assertEquals(Set.of("public.orders","audit.orders"),new HashSet<>(choices.stream().map(Completion::getInsertText).toList()));
        var columns=complete("SELECT i| FROM orders o JOIN customers c ON true",Engine.POSTGRESQL,OBJECTS).stream().filter(c->c.getLabel().equals("id")).toList();assertEquals(Set.of("o.id","c.id"),new HashSet<>(columns.stream().map(Completion::getInsertText).toList()));
    }
    @Test void derivedTablesWithoutLateralCannotCaptureSiblingRelations(){
        assertFalse(complete("SELECT * FROM orders o, (SELECT o.am|) d",Engine.POSTGRESQL,OBJECTS).stream().anyMatch(c->c.getLabel().equals("amount")));
        assertTrue(complete("SELECT * FROM orders o, LATERAL (SELECT o.am|) d",Engine.POSTGRESQL,OBJECTS).stream().anyMatch(c->c.getLabel().equals("amount")));
    }
    @Test void cteDeclarationOrderRecursiveVisibilityAndSetOutputsAreBounded(){
        var cte=complete("WITH first AS (SELECT name FROM orders), second AS (SELECT first.* FROM first) SELECT s.na| FROM second s",Engine.POSTGRESQL,OBJECTS);assertTrue(cte.stream().anyMatch(c->c.getLabel().equals("name")));
        assertTrue(complete("WITH RECURSIVE r(n) AS (SELECT 1 UNION ALL SELECT n+1 FROM r) SELECT r.n| FROM r",Engine.POSTGRESQL,OBJECTS).stream().anyMatch(c->c.getLabel().equals("n")));
        assertTrue(complete("SELECT d.na| FROM (SELECT name FROM orders UNION ALL SELECT customer_name FROM customers) d",Engine.POSTGRESQL,OBJECTS).stream().anyMatch(c->c.getLabel().equals("name")));
    }
    @Test void insertAndUpdateCompletionUseTheActualTargetColumns(){
        assertTrue(complete("INSERT INTO orders (am|) VALUES (1)",Engine.POSTGRESQL,OBJECTS).stream().anyMatch(c->c.getLabel().equals("amount")));
        assertTrue(complete("INSERT INTO orders (|) VALUES (1)",Engine.POSTGRESQL,OBJECTS).stream().anyMatch(c->c.getLabel().equals("id")));
        assertTrue(complete("UPDATE orders SET am|",Engine.POSTGRESQL,OBJECTS).stream().anyMatch(c->c.getLabel().equals("amount")));
    }
    @Test void verifiedCompositeRelationshipsProduceEveryQuotedPredicateAndStableIdentity(){
        var objects=new ArrayList<>(OBJECTS);objects.add(column("public","orders","customer id","integer"));objects.add(column("public","orders","tenant","integer"));objects.add(column("public","customers","tenant","integer"));
        objects.add(SchemaObject.newBuilder().setKind(ObjectKind.FOREIGN_KEY).setCatalog("db").setSchema("public").setTable("orders").setName("orders_customer").putProperties("relationshipVerified","true").putProperties("columnCount","2").putProperties("column.0","customer id").putProperties("referencedColumn.0","id").putProperties("column.1","tenant").putProperties("referencedColumn.1","tenant").putProperties("referencedCatalog","db").putProperties("referencedSchema","public").putProperties("referencedTable","customers").build());
        var joins=complete("SELECT * FROM orders o JOIN customers c ON |",Engine.POSTGRESQL,objects).stream().filter(c->c.getKind().equals("join")).toList();assertEquals(1,joins.size());assertEquals("o.\"customer id\" = c.id AND o.tenant = c.tenant",joins.getFirst().getInsertText());assertEquals(identity(objects,ObjectKind.FOREIGN_KEY,"public","orders","orders_customer"),joins.getFirst().getTargetIdentity());
        var unverified=objects.stream().map(o->o.getKind()==ObjectKind.FOREIGN_KEY?o.toBuilder().removeProperties("relationshipVerified").build():o).toList();assertFalse(complete("SELECT * FROM orders o JOIN customers c ON |",Engine.POSTGRESQL,unverified).stream().anyMatch(c->c.getKind().equals("join")));
    }
    @Test void diagnosticsHaveStableCodesSpansAndMechanicalQualificationFixes(){
        String sql="SELECT id, missing FROM orders o JOIN customers c ON true";var diagnostics=request(sql,0,Engine.POSTGRESQL,AnalysisOperation.DIAGNOSTICS,OBJECTS,COMPLETE).getDiagnosticsList();
        var ambiguous=diagnostics.stream().filter(d->d.getCode().equals("binding.ambiguous-column")).findFirst().orElseThrow();assertEquals("id",sql.substring(ambiguous.getStartUtf16(),ambiguous.getEndUtf16()));assertEquals(2,ambiguous.getFixesCount());assertEquals(Set.of("o.id","c.id"),new HashSet<>(ambiguous.getFixesList().stream().map(QuickFix::getReplacement).toList()));
        assertTrue(diagnostics.stream().anyMatch(d->d.getCode().equals("binding.unresolved-column")));
        assertTrue(request(sql,0,Engine.POSTGRESQL,AnalysisOperation.DIAGNOSTICS,List.of(),ResolutionContext.UNAVAILABLE).getDiagnosticsList().stream().noneMatch(d->d.getCode().equals("binding.unresolved-column")));
    }
    @Test void duplicateAliasesCtesAndInsertColumnsHaveSeparateCodes(){
        for(var pair:Map.of("SELECT * FROM orders o JOIN customers o ON true","binding.duplicate-alias","WITH x AS (SELECT 1), x AS (SELECT 2) SELECT * FROM x","binding.duplicate-cte","INSERT INTO orders(id,id) VALUES (1,2)","binding.duplicate-insert-column").entrySet())assertTrue(request(pair.getKey(),0,Engine.POSTGRESQL,AnalysisOperation.DIAGNOSTICS,OBJECTS,COMPLETE).getDiagnosticsList().stream().anyMatch(d->d.getCode().equals(pair.getValue())),pair.toString());
    }
    @ParameterizedTest @EnumSource(value=Engine.class,names={"POSTGRESQL","MYSQL","MARIADB"})
    void destructiveInspectionsAreConfigurableAndDialectReturningIsExact(Engine engine){
        var service=new SqlAnalysis();var base=AnalysisRequest.newBuilder().setEngine(engine).setOperation(AnalysisOperation.DIAGNOSTICS).setSql("UPDATE orders SET amount=1");
        assertTrue(SemanticFixtures.analyze(service,base.build(),OBJECTS,LexicalSettings.DEFAULT,COMPLETE).getDiagnosticsList().stream().anyMatch(d->d.getCode().equals("inspection.unrestricted-update")));
        base.addInspections(InspectionSetting.newBuilder().setCode("inspection.unrestricted-update").setEnabled(false));assertFalse(SemanticFixtures.analyze(service,base.build(),OBJECTS,LexicalSettings.DEFAULT,COMPLETE).getDiagnosticsList().stream().anyMatch(d->d.getCode().equals("inspection.unrestricted-update")));
        var result=request("UPDATE orders SET amount=1 RETURNING id",0,engine,AnalysisOperation.DIAGNOSTICS,OBJECTS,COMPLETE);assertEquals(engine!=Engine.POSTGRESQL,result.getDiagnosticsList().stream().anyMatch(d->d.getCode().equals("dialect.returning")));
    }
    private static SchemaObject routine(String schema,String signature,String type){return SchemaObject.newBuilder().setKind(ObjectKind.ROUTINE).setCatalog("db").setSchema(schema).setName("calculate").setIdentifier(signature).putProperties("signature",signature).putProperties("parameterCount","2").putProperties("parameter.0.name","amount").putProperties("parameter.0.type",type).putProperties("parameter.0.mode","IN").putProperties("parameter.1.name","scale").putProperties("parameter.1.type","integer").putProperties("parameter.1.default","2").putProperties("returnType","numeric").build();}
    @Test void parameterInformationCarriesAllOverloadsModesDefaultsAndTheInnermostArgument(){
        var routines=List.of(routine("public","calculate(numeric,integer)","numeric"),routine("public","calculate(integer,integer)","integer"));String sql="SELECT calculate(abs(1), 'a,b')";
        var info=request(sql,sql.indexOf("a,b")+2,Engine.POSTGRESQL,AnalysisOperation.PARAMETER_INFORMATION,routines,COMPLETE).getParameterInformation();assertEquals(1,info.getActiveArgument());assertEquals(2,info.getOverloadsCount());assertEquals("IN",info.getOverloads(0).getParameters(0).getMode());assertTrue(info.getOverloads(0).getParameters(1).getOptional());assertEquals("2",info.getOverloads(0).getParameters(1).getDefaultExpression());assertEquals(sql.indexOf("calculate"),info.getStartUtf16());assertEquals(sql.length(),info.getEndUtf16());
        var nested=request(sql,sql.indexOf("1")+1,Engine.POSTGRESQL,AnalysisOperation.PARAMETER_INFORMATION,routines,COMPLETE).getParameterInformation();assertEquals("abs",nested.getOverloads(0).getName());
    }
    @Test void operationsRemainIndependentAndEchoTheCapturedRevision(){
        for(var operation:List.of(AnalysisOperation.COMPLETION,AnalysisOperation.DIAGNOSTICS,AnalysisOperation.PARAMETER_INFORMATION,AnalysisOperation.FORMAT,AnalysisOperation.DDL_IMPACT)){
            var response=request("SELECT o.id FROM orders o",9,Engine.POSTGRESQL,operation,OBJECTS,COMPLETE);assertEquals(operation,response.getOperation());assertEquals(7,response.getMetadataSnapshotRevision());assertEquals(3,response.getMetadataConfigurationRevision());assertEquals(19,response.getDocumentVersion());
            if(operation!=AnalysisOperation.FORMAT){assertTrue(response.getFormattedSql().isEmpty());assertEquals(0,response.getFormatTokensCount());}
            if(operation!=AnalysisOperation.COMPLETION)assertEquals(0,response.getCompletionsCount());
        }
    }
    @Test void formattingGoldenIdempotenceLexicalProofLineEndingsAndDisabledRegions(){
        assertEquals(0,SqlFormatter.Options.from(FormatSettings.newBuilder().setContinuationIndent(0).build()).continuation());
        String sql="SELECT  id,name FROM orders WHERE id=1;\r\n";String expected="SELECT id, name\r\nFROM orders\r\nWHERE id = 1;\r\n";
        var first=request(sql,0,Engine.POSTGRESQL,AnalysisOperation.FORMAT,OBJECTS,COMPLETE);assertEquals(expected,first.getFormattedSql());assertEquals(expected,request(expected,0,Engine.POSTGRESQL,AnalysisOperation.FORMAT,OBJECTS,COMPLETE).getFormattedSql());
        for(var token:first.getFormatTokensList())assertEquals(sql.substring(token.getSourceStartUtf16(),token.getSourceEndUtf16()),first.getFormattedSql().substring(token.getFormattedStartUtf16(),token.getFormattedStartUtf16()+token.getSourceEndUtf16()-token.getSourceStartUtf16()));
        String disabled="SELECT 1;\n-- busydata-format:off\nSELECT     'x  y' FROM    odd;\n-- busydata-format:on\nSELECT  2;";assertTrue(request(disabled,0,Engine.POSTGRESQL,AnalysisOperation.FORMAT,OBJECTS,COMPLETE).getFormattedSql().contains("-- busydata-format:off\nSELECT     'x  y' FROM    odd;\n-- busydata-format:on"));
    }
    @Test void malformedFormattingAndSelectionInsideTokensNeverModifySource(){
        for(String sql:List.of("SELECT 'unfinished","SELECT (1","SELECT 1)","SELECT 1 +","UPDATE orders"))assertEquals("",request(sql,0,Engine.POSTGRESQL,AnalysisOperation.FORMAT,OBJECTS,COMPLETE).getFormattedSql());
        var req=AnalysisRequest.newBuilder().setEngine(Engine.POSTGRESQL).setOperation(AnalysisOperation.FORMAT).setSql("SELECT 'a b'").setFormatSettings(FormatSettings.newBuilder().setStartUtf16(9).setEndUtf16(10)).build();assertEquals("selection-splits-token",new SqlAnalysis().analyze(req).getAvailability());
    }
    @ParameterizedTest @EnumSource(value=Engine.class,names={"MYSQL","MARIADB"})
    void formattingPreservesNativeDdlIdentifiersEvenWhenTheySpellNonreservedKeywords(Engine engine){
        for(String sql:List.of("create table comment(id integer)","rename table comment to view","alter table comment add column note varchar(20)")){
            var formatted=request(sql,0,engine,AnalysisOperation.FORMAT,List.of(),COMPLETE).getFormattedSql();assertFalse(formatted.isEmpty());assertTrue(formatted.contains("comment"),formatted);assertFalse(formatted.contains("COMMENT"),formatted);assertEquals(formatted,request(formatted,0,engine,AnalysisOperation.FORMAT,List.of(),COMPLETE).getFormattedSql());
        }
    }
    @Test void currentStatementFormattingSharesIndependentDelimiterAndWhitespaceSelection(){
        var service=new SqlAnalysis();String sql="SELECT  1;\r\n\r\nSELECT  id,name FROM orders WHERE id=1;\r\n";
        var request=AnalysisRequest.newBuilder().setEngine(Engine.POSTGRESQL).setOperation(AnalysisOperation.FORMAT).setSql(sql).setCaretUtf16(sql.indexOf("id")+1).setFormatCurrentStatement(true).build();
        var result=SemanticFixtures.analyze(service,request,OBJECTS,LexicalSettings.DEFAULT,COMPLETE);assertEquals("SELECT  1;\r\n\r\nSELECT id, name\r\nFROM orders\r\nWHERE id = 1;\r\n",result.getFormattedSql());
        for(var token:result.getFormatTokensList())assertEquals(sql.substring(token.getSourceStartUtf16(),token.getSourceEndUtf16()),result.getFormattedSql().substring(token.getFormattedStartUtf16(),token.getFormattedStartUtf16()+token.getSourceEndUtf16()-token.getSourceStartUtf16()));
        // The caret after a delimiter and in its following whitespace selects the previous statement.
        for(int caret:new int[]{sql.indexOf(';')+1,sql.indexOf(';')+2}){
            var execution=service.execution(ExecuteRequest.newBuilder().setSql(sql).setCaretUtf16(caret).setMode(ExecutionMode.CURRENT_STATEMENT).build(),Engine.POSTGRESQL,LexicalSettings.DEFAULT).getFirst();assertEquals("SELECT  1",execution.text());
            var formatted=SemanticFixtures.analyze(service,request.toBuilder().setCaretUtf16(caret).build(),OBJECTS,LexicalSettings.DEFAULT,COMPLETE).getFormattedSql();assertTrue(formatted.startsWith("SELECT 1;\r\n\r\nSELECT  id,name"),formatted);
        }
        assertEquals("no-active-statement",SemanticFixtures.analyze(service,request.toBuilder().setSql(" \r\n ").setCaretUtf16(2).build(),List.of(),LexicalSettings.DEFAULT,COMPLETE).getAvailability());
        assertThrows(IllegalArgumentException.class,()->SemanticFixtures.analyze(service,request.toBuilder().setOperation(AnalysisOperation.COMPLETION).build(),OBJECTS,LexicalSettings.DEFAULT,COMPLETE));
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB)){
            String script="DELIMITER //\nSELECT  1//\nDELIMITER ;\nSELECT  2;";
            var formatted=SemanticFixtures.analyze(service,request.toBuilder().setEngine(engine).setSql(script).setCaretUtf16(script.indexOf('1')).build(),List.of(),LexicalSettings.DEFAULT,COMPLETE);assertEquals("DELIMITER //\nSELECT 1//\nDELIMITER ;\nSELECT  2;",formatted.getFormattedSql());
        }
    }
    @Test void postgresAdjacentStringNewlinesAndMysqlFunctionTriviaRemainExact(){
        for(String expression:List.of("'a'\n'b'","'a' \r\n  'b'","'a'\n/* keep */ 'b'","'a' /* keep */\n'b'","E'a'\n'b'","'a'\nE'b'")){
            String sql="SELECT "+expression+";";var result=request(sql,0,Engine.POSTGRESQL,AnalysisOperation.FORMAT,List.of(),COMPLETE);assertTrue(result.getFormattedSql().contains(expression),result.getFormattedSql());assertEquals(result.getFormattedSql(),request(result.getFormattedSql(),0,Engine.POSTGRESQL,AnalysisOperation.FORMAT,List.of(),COMPLETE).getFormattedSql());
        }
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB))for(String gap:List.of(""," ","   ","\n\t"," /* keep */\n ")){
            String expression="count"+gap+"(1)";var result=request("SELECT "+expression+";",0,engine,AnalysisOperation.FORMAT,List.of(),COMPLETE);assertTrue(result.getFormattedSql().contains(expression),result.getFormattedSql());
        }
    }
    @ParameterizedTest @EnumSource(value=Engine.class,names={"POSTGRESQL","MYSQL","MARIADB"})
    void formattedCoreStatementsHaveEquivalentIndependentParserTrees(Engine engine)throws Exception{
        for(String sql:List.of("SELECT id,name FROM orders WHERE id=1 ORDER BY name", "SELECT o.id,c.customer_name FROM orders o JOIN customers c ON o.id=c.id WHERE o.id>2", "WITH x AS (SELECT id,name FROM orders) SELECT id FROM x WHERE name='a b'", "INSERT INTO orders(id,name) VALUES(1,'a'),(2,'b')", "UPDATE orders SET name='changed' WHERE id=1", "DELETE FROM orders WHERE id=1")){
            String formatted=request(sql,0,engine,AnalysisOperation.FORMAT,OBJECTS,COMPLETE).getFormattedSql();assertFalse(formatted.isEmpty(),sql);assertEquals(SqlParsing.parse(sql,engine).toString(),SqlParsing.parse(formatted,engine).toString(),formatted);assertEquals(formatted,request(formatted,0,engine,AnalysisOperation.FORMAT,OBJECTS,COMPLETE).getFormattedSql());
        }
    }
    @Test void versionedExecutableCommentsProduceOneLocalizedAvailabilityDiagnostic(){
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB))for(String comment:List.of("/*!80000 SQL_NO_CACHE */","/*M!100100 SQL_NO_CACHE */")){
            String sql="SELECT "+comment+" o.id FROM orders o";var response=request(sql,0,engine,AnalysisOperation.DIAGNOSTICS,OBJECTS,COMPLETE);assertEquals(1,response.getDiagnosticsCount());assertEquals("analysis.unavailable",response.getDiagnostics(0).getCode());assertEquals(comment,sql.substring(response.getDiagnostics(0).getStartUtf16(),response.getDiagnostics(0).getEndUtf16()));assertFalse(response.getStatements(0).getSupported());assertTrue(request(sql,0,engine,AnalysisOperation.COMPLETION,OBJECTS,COMPLETE).getCompletionsList().isEmpty());
        }
    }
    @ParameterizedTest @EnumSource(value=Engine.class,names={"POSTGRESQL","MYSQL","MARIADB"})
    void incompleteCorpusRecoversAtEveryTokenBoundaryWithoutCascading(Engine engine){
        var corpus=List.of("SELECT o.id, count(*) OVER (PARTITION BY o.name ORDER BY o.id) FROM orders o WHERE o.id > :id GROUP BY o.id HAVING count(*) > 1 ORDER BY o.id LIMIT 10 OFFSET 2", "WITH RECURSIVE r(n) AS (SELECT 1 UNION ALL SELECT n+1 FROM r WHERE n<4) SELECT * FROM r", "INSERT INTO orders(id,name) VALUES (1,'a'),(2,'b')", "UPDATE orders SET name=(SELECT customer_name FROM customers c WHERE c.id=orders.id) WHERE id=1", "DELETE FROM orders WHERE id IN (SELECT id FROM customers)");
        for(String sql:corpus){var lexer=LosslessLexer.scan(sql,new Dialect(engine,LexicalSettings.DEFAULT),AnalysisBudget.interactive());for(var token:lexer.significant()){
            String incomplete=sql.substring(0,token.end());var document=new SemanticDocument(incomplete,engine);assertTrue(document.syntax().issues().size()<=64);assertDoesNotThrow(()->document.complete(incomplete.length(),SemanticFixtures.context(engine,OBJECTS,COMPLETE)),incomplete);
        }}
    }
    @Test void resourceLimitsCancellationAndStaleMetadataAreExplicit(){
        assertThrows(AnalysisBudget.Limit.class,()->new SemanticDocument("(".repeat(65),Engine.POSTGRESQL));
        assertThrows(CancellationException.class,()->SemanticFixtures.analyze(new SqlAnalysis(),AnalysisRequest.newBuilder().setEngine(Engine.POSTGRESQL).setSql("SELECT 1").build(),List.of(),LexicalSettings.DEFAULT,COMPLETE,()->true));
        assertThrows(IllegalStateException.class,()->SemanticFixtures.analyze(new SqlAnalysis(),AnalysisRequest.newBuilder().setEngine(Engine.POSTGRESQL).setSql("SELECT 1").setMetadataSnapshotRevision(6).build(),List.of(),LexicalSettings.DEFAULT,COMPLETE));
        var limited=request("SELECT '"+"x".repeat(262144)+"'",0,Engine.POSTGRESQL,AnalysisOperation.DIAGNOSTICS,List.of(),COMPLETE);assertEquals("limited",limited.getAvailability());assertEquals("analysis.limit",limited.getDiagnostics(0).getCode());assertFalse(limited.getStatements(0).getSupported());
    }
    @Test void ddlEffectsKeepQuotedIdentityAndConservativeRefreshScopes(){
        var effects=DdlImpact.analyze("ALTER TABLE \"audit\".\"Odd Table\" ADD COLUMN x integer; CREATE TEMPORARY TABLE scratch(id int); USE other",Engine.POSTGRESQL,LexicalSettings.DEFAULT,COMPLETE);
        assertEquals(3,effects.size());assertEquals("Odd Table",effects.get(0).getName());assertEquals("audit",effects.get(0).getSchema());assertTrue(effects.get(1).getTemporary());assertEquals("CONTEXT",effects.get(2).getOperation());
        assertTrue(DdlImpact.analyze("DROP INDEX idx",Engine.POSTGRESQL,LexicalSettings.DEFAULT,COMPLETE).getFirst().getConservative());
        for(String ddl:List.of("CREATE TYPE pg_temp.state AS ENUM ('ready')","CREATE DOMAIN pg_temp_7.amount AS numeric","ALTER FUNCTION pg_temp.calculate() IMMUTABLE","CREATE SEQUENCE pg_temp.seq")){var effect=DdlImpact.analyze(ddl,Engine.POSTGRESQL,LexicalSettings.DEFAULT,COMPLETE).getFirst();assertTrue(effect.getTemporary(),ddl);if(ddl.contains(" TYPE ")||ddl.contains(" DOMAIN "))assertEquals(ObjectKind.TYPE,effect.getKind());assertTrue(effect.getSchema().startsWith("pg_temp"));}
    }
    @Test void exactNativeTypesPreserveRangesDomainsArraysAndTimezone(){
        assertTrue(SqlTypes.sameBuiltinTypeName("bit","bit(1)",Engine.POSTGRESQL));assertTrue(SqlTypes.sameBuiltinTypeName("varbit","bit varying(128)",Engine.POSTGRESQL));
        var unsigned=SqlTypes.nativeType("BIGINT UNSIGNED",Engine.MYSQL);assertEquals("18446744073709551615",unsigned.maximumInteger().toString());assertEquals("0",unsigned.minimumInteger().toString());
        assertEquals(SqlTypes.Family.ARRAY,SqlTypes.nativeType("numeric[]",Engine.POSTGRESQL).family());assertTrue(SqlTypes.nativeType("timestamp with time zone",Engine.POSTGRESQL).timezone());assertEquals(SqlTypes.Family.JSONB,SqlTypes.nativeType("jsonb",Engine.POSTGRESQL).family());assertEquals("numeric(30,9)",SqlTypes.column(OBJECTS.get(2),Engine.POSTGRESQL).nativeName());
    }
    @Test void completionCountAndByteLimitsAreExplicitAndKeepDeterministicItems(){
        var metadata=new ArrayList<SchemaObject>();metadata.add(relation("public","wide"));for(int i=0;i<300;i++)metadata.add(column("public","wide",String.format(Locale.ROOT,"field_%03d",i),"integer"));
        String sql="SELECT w. FROM wide w";int caret=sql.indexOf('.')+1;
        var response=request(sql,caret,Engine.POSTGRESQL,AnalysisOperation.COMPLETION,metadata,COMPLETE);assertEquals(200,response.getCompletionsCount());assertTrue(response.getCompletionLimited());assertEquals("limited",response.getAvailability());assertEquals("field_000",response.getCompletions(0).getLabel());assertEquals("field_199",response.getCompletions(199).getLabel());assertEquals(response.getCompletionsList(),request(sql,caret,Engine.POSTGRESQL,AnalysisOperation.COMPLETION,metadata,COMPLETE).getCompletionsList());
        var reversed=new ArrayList<>(metadata);Collections.reverse(reversed);assertEquals(response.getCompletionsList(),request(sql,caret,Engine.POSTGRESQL,AnalysisOperation.COMPLETION,reversed,COMPLETE).getCompletionsList(),"The bounded collector must preserve the same best200 regardless of acquisition order");
        var exact=request(sql,caret,Engine.POSTGRESQL,AnalysisOperation.COMPLETION,metadata.subList(0,201),COMPLETE);assertEquals(200,exact.getCompletionsCount());assertFalse(exact.getCompletionLimited());
        var large=metadata.stream().map(o->o.getKind()==ObjectKind.COLUMN?o.toBuilder().putProperties("nativeType","opaque_"+"x".repeat(4096)).build():o).toList();var bytes=request(sql,caret,Engine.POSTGRESQL,AnalysisOperation.COMPLETION,large,COMPLETE);assertTrue(bytes.getCompletionLimited());assertTrue(bytes.getCompletionsCount()<200);assertTrue(bytes.getCompletionsList().stream().mapToInt(Completion::getSerializedSize).sum()<=262144);assertTrue(bytes.getCompletions(0).getDetail().endsWith("x".repeat(4096)));
    }
    @ParameterizedTest @EnumSource(value=Engine.class,names={"POSTGRESQL","MYSQL","MARIADB"})
    void quotedCompletionPrefixesDecodeOnlyTheRawTextBeforeTheCaret(Engine engine){
        char quote=engine==Engine.POSTGRESQL?'"':'`';String label="a"+quote+"c",identifier=""+quote+"a"+quote+quote+"b"+quote,sql="SELECT o."+identifier+" FROM orders o";var metadata=List.of(relation("public","orders"),column("public","orders",label,"integer"));int start=sql.indexOf(identifier),caret=start+4;
        var result=request(sql,caret,engine,AnalysisOperation.COMPLETION,metadata,COMPLETE);var item=result.getCompletionsList().stream().filter(c->c.getLabel().equals(label)).findFirst().orElseThrow();assertEquals(start,item.getStartUtf16());assertEquals(start+identifier.length(),item.getEndUtf16());assertEquals(""+quote+"a"+quote+quote+"c"+quote,item.getInsertText());
        if(engine!=Engine.POSTGRESQL){String ansi="SELECT o.\"a\"\"b\" FROM orders o";var response=SemanticFixtures.analyze(new SqlAnalysis(),AnalysisRequest.newBuilder().setEngine(engine).setOperation(AnalysisOperation.COMPLETION).setSql(ansi).setCaretUtf16(ansi.indexOf("\"a")+4).build(),List.of(relation("public","orders"),column("public","orders","a\"c","integer")),new LexicalSettings(true,true,true),COMPLETE);assertTrue(response.getCompletionsList().stream().anyMatch(c->c.getLabel().equals("a\"c")));}
    }
    @ParameterizedTest @EnumSource(value=Engine.class,names={"POSTGRESQL","MYSQL","MARIADB"})
    void qualifiedRoutineCallsUseTheirExactNamespaceAndUnknownRequiresCoverage(Engine engine){
        var rules=NativeCaseFixtures.rules(engine,0);String routineCatalog=engine==Engine.POSTGRESQL?"db":"known";
        var objects=new ArrayList<>(OBJECTS);objects.add(routine("known","calculate(numeric,integer)","numeric").toBuilder().setCatalog(routineCatalog).build());objects.add(routine("other","calculate()","integer").toBuilder().putProperties("parameterCount","0").build());
        var entries=objects.stream().map(o->io.busystack.busydata.metadata.MetadataObject.from("source","profile","",rules,o,io.busystack.busydata.metadata.IntrospectionLevel.STRUCTURE,1,1)).toList();
        var routineScope=new io.busystack.busydata.metadata.MetadataScope(routineCatalog,"known","",ObjectKind.ROUTINE);var columnScope=new io.busystack.busydata.metadata.MetadataScope("db","public","orders",ObjectKind.COLUMN);
        var coverage=Map.of(routineScope,new io.busystack.busydata.metadata.MetadataCoverage(routineScope,io.busystack.busydata.metadata.IntrospectionLevel.STRUCTURE,io.busystack.busydata.metadata.MetadataState.AVAILABLE,true,"",1,1,1,""),columnScope,new io.busystack.busydata.metadata.MetadataCoverage(columnScope,io.busystack.busydata.metadata.IntrospectionLevel.STRUCTURE,io.busystack.busydata.metadata.MetadataState.AVAILABLE,true,"",1,1,1,""));
        var snapshot=new io.busystack.busydata.metadata.MetadataSnapshot("source","profile",7,3,1,rules,entries,coverage);var context=new ResolutionContext("db","public",List.of("public"),true,7,3,rules,snapshot);
        String sql="SELECT known.calculate(1,2) FROM orders";var valid=request(sql,0,engine,AnalysisOperation.DIAGNOSTICS,snapshot.objects(),context).getDiagnosticsList();assertTrue(valid.stream().noneMatch(d->d.getCode().startsWith("binding.")||d.getCode().startsWith("routine.")),valid.toString());
        var arity=request("SELECT known.calculate() FROM orders",0,engine,AnalysisOperation.DIAGNOSTICS,snapshot.objects(),context).getDiagnosticsList();assertTrue(arity.stream().anyMatch(d->d.getCode().equals("routine.argument-count")),"An overload in another namespace cannot satisfy this call");
        String unknown="SELECT known.missing(1) FROM orders";var diagnosed=request(unknown,0,engine,AnalysisOperation.DIAGNOSTICS,snapshot.objects(),context).getDiagnosticsList().stream().filter(d->d.getCode().equals("routine.unknown")).findFirst().orElseThrow();assertEquals("known.missing",unknown.substring(diagnosed.getStartUtf16(),diagnosed.getEndUtf16()));
        for(String unavailable:List.of("SELECT outside.missing(1) FROM orders","SELECT server_builtin(1) FROM orders")){var diagnostics=request(unavailable,0,engine,AnalysisOperation.DIAGNOSTICS,snapshot.objects(),context).getDiagnosticsList();assertTrue(diagnostics.stream().noneMatch(d->d.getCode().equals("routine.unknown")||d.getCode().startsWith("binding.")));assertTrue(diagnostics.stream().anyMatch(d->d.getIncomplete()));}
    }
    @Test void configuredSnippetsUseTheSemanticCompletionPipelineOnlyAtStatementStarts(){
        var service=new SqlAnalysis();var templates=Map.of("Select recent","SELECT * FROM orders ORDER BY id DESC LIMIT 100;","Transaction","BEGIN;\nROLLBACK;");
        String sql="-- lead\r\nselSuffix";var base=AnalysisRequest.newBuilder().setEngine(Engine.POSTGRESQL).setOperation(AnalysisOperation.COMPLETION).setSql(sql).setCaretUtf16(sql.indexOf("sel")+3).putAllSnippets(templates);
        var response=SemanticFixtures.analyze(service,base.build(),OBJECTS,LexicalSettings.DEFAULT,COMPLETE);var snippet=response.getCompletionsList().stream().filter(c->c.getKind().equals("snippet")).findFirst().orElseThrow();assertEquals("Select recent",snippet.getLabel());assertEquals(templates.get("Select recent"),snippet.getInsertText());assertEquals(sql.indexOf("sel"),snippet.getStartUtf16());assertEquals(sql.length(),snippet.getEndUtf16());assertEquals("snippet:Select recent",snippet.getTargetIdentity());
        for(String marked:List.of("SELECT sel|","SELECT o.sel| FROM orders o","SELECT 'sel|","-- sel|","/* sel|","SELECT (sel|)","SELECT 1 WHERE sel|","SELECT \"sel|\"")){
            int caret=marked.indexOf('|');var request=base.clone().setSql(marked.replace("|","")).setCaretUtf16(caret).build();assertFalse(SemanticFixtures.analyze(service,request,OBJECTS,LexicalSettings.DEFAULT,COMPLETE).getCompletionsList().stream().anyMatch(c->c.getKind().equals("snippet")),marked);
        }
        String next="SELECT id FROM orders;\nsel";assertTrue(SemanticFixtures.analyze(service,base.clone().setSql(next).setCaretUtf16(next.length()).build(),OBJECTS,LexicalSettings.DEFAULT,COMPLETE).getCompletionsList().stream().anyMatch(c->c.getKind().equals("snippet")));
    }
    @Test void oversizedOrMalformedSnippetMapsAreRejectedRatherThanTruncated(){
        var service=new SqlAnalysis();var base=AnalysisRequest.newBuilder().setEngine(Engine.POSTGRESQL).setSql("sel").setCaretUtf16(3);
        var many=new LinkedHashMap<String,String>();for(int i=0;i<33;i++)many.put("snippet"+i,"SELECT 1");
        for(var map:List.of(Map.of("x".repeat(65),"SELECT 1"),Map.of("valid","x".repeat(4097)),Map.of("nul\0name","SELECT 1"),Map.of("valid","SELECT '\0'"),many))assertThrows(IllegalArgumentException.class,()->service.analyze(base.clone().putAllSnippets(map).build()));
        var bytes=new LinkedHashMap<String,String>();for(int i=0;i<8;i++)bytes.put("snippet"+i,"x".repeat(4096));assertThrows(IllegalArgumentException.class,()->service.analyze(base.clone().putAllSnippets(bytes).build()));
    }
    @Test void parameterOverloadAndResponseByteCapsAreExplicit(){
        var overloads=new ArrayList<SchemaObject>();for(int i=0;i<80;i++)overloads.add(routine("public",String.format(Locale.ROOT,"calculate(type_%03d,integer)",i),"integer"));String sql="SELECT calculate(1, 2)";
        var response=request(sql,sql.indexOf('2'),Engine.POSTGRESQL,AnalysisOperation.PARAMETER_INFORMATION,overloads,COMPLETE);assertEquals(64,response.getParameterInformation().getOverloadsCount());assertEquals("limited",response.getParameterInformation().getAvailability());assertEquals("limited",response.getAvailability());assertEquals("calculate(type_000,integer)",response.getParameterInformation().getOverloads(0).getSignature());
        var rules=new io.busystack.busydata.metadata.IdentifierRules(Engine.POSTGRESQL,0);var entries=overloads.stream().map(o->io.busystack.busydata.metadata.MetadataObject.from("source","profile","",rules,o,io.busystack.busydata.metadata.IntrospectionLevel.STRUCTURE,1,1)).toList();var snapshot=new io.busystack.busydata.metadata.MetadataSnapshot("source","profile",7,3,1,rules,entries,Map.of());var context=new ResolutionContext("db","public",List.of("public"),true,7,3,rules,snapshot);
        var nativeResponse=request(sql,sql.indexOf('2'),Engine.POSTGRESQL,AnalysisOperation.PARAMETER_INFORMATION,snapshot.objects(),context);assertEquals("limited",nativeResponse.getParameterInformation().getAvailability());assertEquals(response.getParameterInformation().getOverloadsList().stream().map(RoutineSignature::getSignature).toList(),nativeResponse.getParameterInformation().getOverloadsList().stream().map(RoutineSignature::getSignature).toList());
        var partial=request("SELECT public.calculate(true,2)",0,Engine.POSTGRESQL,AnalysisOperation.DIAGNOSTICS,snapshot.objects(),context).getDiagnosticsList();assertTrue(partial.stream().anyMatch(Diagnostic::getIncomplete));assertTrue(partial.stream().noneMatch(d->d.getCode().equals("routine.no-matching-overload")));
        var exact=request(sql,sql.indexOf('2'),Engine.POSTGRESQL,AnalysisOperation.PARAMETER_INFORMATION,overloads.subList(0,64),COMPLETE);assertEquals("available",exact.getParameterInformation().getAvailability());
        var large=overloads.stream().map(o->o.toBuilder().putProperties("parameter.0.type","opaque_"+"x".repeat(4096)).build()).toList();var bytes=request(sql,sql.indexOf('2'),Engine.POSTGRESQL,AnalysisOperation.PARAMETER_INFORMATION,large,COMPLETE);assertEquals("limited",bytes.getParameterInformation().getAvailability());assertTrue(bytes.getParameterInformation().getOverloadsCount()<64);assertTrue(bytes.getParameterInformation().getOverloadsList().stream().mapToInt(RoutineSignature::getSerializedSize).sum()<=65536);
    }
    private static io.busystack.busydata.metadata.MetadataSnapshot coverageSnapshot(boolean columnsComplete){
        var rules=new io.busystack.busydata.metadata.IdentifierRules(Engine.POSTGRESQL,0);var entries=new ArrayList<io.busystack.busydata.metadata.MetadataObject>();for(var object:List.of(relation("public","orders"),column("public","orders","id","integer")))entries.add(io.busystack.busydata.metadata.MetadataObject.from("source","profile","",rules,object,io.busystack.busydata.metadata.IntrospectionLevel.STRUCTURE,1,1));
        var coverage=new HashMap<io.busystack.busydata.metadata.MetadataScope,io.busystack.busydata.metadata.MetadataCoverage>();
        for(var kind:List.of(ObjectKind.TABLE,ObjectKind.VIEW,ObjectKind.SEQUENCE,ObjectKind.COLUMN)){var scope=new io.busystack.busydata.metadata.MetadataScope("db","public",kind==ObjectKind.COLUMN?"orders":"",kind);boolean complete=kind!=ObjectKind.COLUMN||columnsComplete;coverage.put(scope,new io.busystack.busydata.metadata.MetadataCoverage(scope,io.busystack.busydata.metadata.IntrospectionLevel.STRUCTURE,complete?io.busystack.busydata.metadata.MetadataState.AVAILABLE:io.busystack.busydata.metadata.MetadataState.PARTIAL,complete,"fingerprint",1,1,1,""));}
        for(var kind:List.of(ObjectKind.TABLE,ObjectKind.VIEW,ObjectKind.SEQUENCE)){var scope=new io.busystack.busydata.metadata.MetadataScope("db","pg_catalog","",kind);coverage.put(scope,new io.busystack.busydata.metadata.MetadataCoverage(scope,io.busystack.busydata.metadata.IntrospectionLevel.NAMES,io.busystack.busydata.metadata.MetadataState.AVAILABLE,true,"names",1,1,1,""));}
        return new io.busystack.busydata.metadata.MetadataSnapshot("source","profile",7,3,1,rules,entries,coverage);
    }
    @Test void uninspectedQualifiedNamespacesReportAvailabilityInsteadOfFalseAbsence(){
        var snapshot=coverageSnapshot(true);var context=new ResolutionContext("db","public",List.of("public"),true,7,3,snapshot.rules(),snapshot);String sql="SELECT x.id FROM outside.orders x";
        var result=request(sql,0,Engine.POSTGRESQL,AnalysisOperation.DIAGNOSTICS,snapshot.objects(),context);assertFalse(result.getDiagnosticsList().stream().anyMatch(d->d.getCode().equals("binding.unresolved-relation")));var availability=result.getDiagnosticsList().stream().filter(d->d.getCode().equals("metadata.incomplete")).findFirst().orElseThrow();assertTrue(availability.getIncomplete());assertTrue(sql.substring(availability.getStartUtf16(),availability.getEndUtf16()).contains("outside.orders"));
        var missing=request("SELECT * FROM public.missing",0,Engine.POSTGRESQL,AnalysisOperation.DIAGNOSTICS,snapshot.objects(),context);assertTrue(missing.getDiagnosticsList().stream().anyMatch(d->d.getCode().equals("binding.unresolved-relation")));
    }
    @Test void partialColumnScopesNeverClaimCompleteFieldsTypesOrDerivedOutputs(){
        var snapshot=coverageSnapshot(false);var context=new ResolutionContext("db","public",List.of("public"),true,7,3,snapshot.rules(),snapshot);
        for(String sql:List.of("SELECT missing FROM orders", "SELECT d.missing FROM (SELECT o.* FROM orders o) d", "SELECT id FROM orders a JOIN orders b ON true", "SELECT * FROM orders WHERE id=true")){
            var diagnostics=request(sql,0,Engine.POSTGRESQL,AnalysisOperation.DIAGNOSTICS,snapshot.objects(),context).getDiagnosticsList();assertTrue(diagnostics.stream().anyMatch(d->d.getCode().equals("metadata.incomplete")),sql);assertFalse(diagnostics.stream().anyMatch(d->Set.of("binding.unresolved-column","binding.invalid-derived-reference","binding.ambiguous-column","type.incompatible-comparison").contains(d.getCode())),sql);
        }
        String sql="SELECT  FROM orders o";var completion=request(sql,7,Engine.POSTGRESQL,AnalysisOperation.COMPLETION,snapshot.objects(),context);assertTrue(completion.getCompletionsList().stream().anyMatch(c->c.getLabel().equals("id")));assertFalse(completion.getCompletionsList().stream().anyMatch(c->c.getKind().equals("field-list")));
    }
    @Test void exactCompleteColumnEvidenceWorksDespiteAnUnrelatedIncompleteScope(){
        var snapshot=coverageSnapshot(true);var context=new ResolutionContext("db","public",List.of("public"),false,7,3,snapshot.rules(),snapshot);
        var diagnostics=request("SELECT missing FROM public.orders",0,Engine.POSTGRESQL,AnalysisOperation.DIAGNOSTICS,snapshot.objects(),context).getDiagnosticsList();assertTrue(diagnostics.stream().anyMatch(d->d.getCode().equals("binding.unresolved-column")));
        var completion=request("SELECT  FROM public.orders o",7,Engine.POSTGRESQL,AnalysisOperation.COMPLETION,snapshot.objects(),context);assertTrue(completion.getCompletionsList().stream().anyMatch(c->c.getKind().equals("field-list")));
        var named=request("SELECT d.other FROM (SELECT 1 AS known) d",0,Engine.POSTGRESQL,AnalysisOperation.DIAGNOSTICS,snapshot.objects(),context);assertTrue(named.getDiagnosticsList().stream().anyMatch(d->d.getCode().equals("binding.invalid-derived-reference")));
    }
    @Test void unknownEarlierPostgresNamespaceCannotProveLaterColumnAbsenceOrTypes(){
        var complete=coverageSnapshot(true);var coverage=new HashMap<>(complete.coverage());coverage.keySet().removeIf(scope->scope.schema().equals("pg_catalog"));
        var snapshot=new io.busystack.busydata.metadata.MetadataSnapshot("source","profile",7,3,1,complete.rules(),complete.identities().values(),coverage);var context=new ResolutionContext("db","public",List.of("public"),true,7,3,snapshot.rules(),snapshot);
        for(String sql:List.of("SELECT missing FROM orders","SELECT * FROM orders WHERE id=true")){
            var result=request(sql,0,Engine.POSTGRESQL,AnalysisOperation.DIAGNOSTICS,snapshot.objects(),context);assertTrue(result.getDiagnosticsList().stream().anyMatch(d->d.getCode().equals("metadata.incomplete")));assertFalse(result.getDiagnosticsList().stream().anyMatch(d->Set.of("binding.unresolved-column","type.incompatible-comparison").contains(d.getCode())));
        }
        var completion=request("SELECT  FROM orders o",7,Engine.POSTGRESQL,AnalysisOperation.COMPLETION,snapshot.objects(),context);assertEquals("incomplete-metadata",completion.getAvailability());assertTrue(completion.getCompletionsList().stream().anyMatch(c->c.getLabel().equals("id")));assertFalse(completion.getCompletionsList().stream().anyMatch(c->c.getKind().equals("field-list")));
        var qualified=request("SELECT missing FROM public.orders",0,Engine.POSTGRESQL,AnalysisOperation.DIAGNOSTICS,snapshot.objects(),context);assertTrue(qualified.getDiagnosticsList().stream().anyMatch(d->d.getCode().equals("binding.unresolved-column")),"An explicit namespace does not depend on the unknown earlier namespace");
    }
    @Test void centralSnapshotProjectionAndServerCaseRulesAreConsumedWithoutInferringIdentities(){
        var rules=NativeCaseFixtures.rules(Engine.MYSQL,1);
        var source=SchemaObject.newBuilder().setKind(ObjectKind.TABLE).setCatalog("db").setSchema("public").setName("MixedOrders").build();
        var field=column("public","MixedOrders","ExactColumn","numeric(40,12)");
        var entries=List.of(io.busystack.busydata.metadata.MetadataObject.from("source","profile","",rules,source,io.busystack.busydata.metadata.IntrospectionLevel.STRUCTURE,1,1),io.busystack.busydata.metadata.MetadataObject.from("source","profile","",rules,field,io.busystack.busydata.metadata.IntrospectionLevel.STRUCTURE,1,1));
        var snapshot=new io.busystack.busydata.metadata.MetadataSnapshot("source","profile",5,2,1,rules,entries,Map.of());
        var context=new ResolutionContext("db","public",List.of("public"),true,5,2,snapshot.rules());String sql="SELECT o.Ex FROM mixedorders O";
        var completions=request(sql,sql.indexOf("Ex")+2,Engine.MYSQL,AnalysisOperation.COMPLETION,snapshot.objects(),context).getCompletionsList();assertTrue(completions.stream().anyMatch(c->c.getLabel().equals("ExactColumn")&&!c.getTargetIdentity().isEmpty()));
        var captured=new ResolutionContext("db","public",List.of("public"),true,5,2,snapshot.rules(),snapshot);
        List<SchemaObject> forbiddenFullProjection=new AbstractList<>(){public SchemaObject get(int index){throw new AssertionError("A semantic request must not materialize the full metadata wire projection");}public int size(){return 118000;}};
        var nativeCompletions=request(sql,sql.indexOf("Ex")+2,Engine.MYSQL,AnalysisOperation.COMPLETION,forbiddenFullProjection,captured).getCompletionsList();assertTrue(nativeCompletions.stream().anyMatch(c->c.getLabel().equals("ExactColumn")&&!c.getTargetIdentity().isEmpty()));
        assertTrue(request(sql,sql.indexOf("Ex")+2,Engine.MYSQL,AnalysisOperation.COMPLETION,List.of(field),context).getCompletionsList().isEmpty());
        var signature=RoutineSignatures.from(routine("public","calculate(numeric,integer)","numeric").toBuilder().putProperties("signatureAvailability","AVAILABLE").build(),Engine.POSTGRESQL);assertTrue(signature.complete());
        var tableOutput=RoutineSignatures.from(routine("public","calculate(numeric)","numeric").toBuilder().putProperties("parameter.1.mode","TABLE").removeProperties("parameter.1.default").build(),Engine.POSTGRESQL);assertEquals(1,tableOutput.minimumArguments());assertEquals(1,tableOutput.maximumArguments());
    }
    @Test void capturedPostgresTemporaryAliasResolvesRelationsButNeverUnqualifiedRoutines(){
        var rules=new io.busystack.busydata.metadata.IdentifierRules(Engine.POSTGRESQL,0);var entries=new ArrayList<io.busystack.busydata.metadata.MetadataObject>();
        var objects=List.of(relation("public","scratch"),column("public","scratch","durable_id","integer"),relation("pg_temp_7","scratch"),column("pg_temp_7","scratch","temp_id","integer"),routine("public","calculate(numeric,integer)","numeric"),routine("pg_temp_7","calculate()","integer").toBuilder().putProperties("parameterCount","0").putProperties("returnType","boolean").build());
        for(var object:objects)entries.add(io.busystack.busydata.metadata.MetadataObject.from("source","profile",object.getSchema().startsWith("pg_temp_")?"physical-session":"",rules,object,io.busystack.busydata.metadata.IntrospectionLevel.STRUCTURE,1,1));
        var coverage=new HashMap<io.busystack.busydata.metadata.MetadataScope,io.busystack.busydata.metadata.MetadataCoverage>();for(String schema:List.of("public","pg_temp_7"))for(var kind:List.of(ObjectKind.TABLE,ObjectKind.VIEW,ObjectKind.SEQUENCE,ObjectKind.COLUMN,ObjectKind.ROUTINE)){var scope=new io.busystack.busydata.metadata.MetadataScope("db",schema,kind==ObjectKind.COLUMN?"scratch":"",kind);coverage.put(scope,new io.busystack.busydata.metadata.MetadataCoverage(scope,io.busystack.busydata.metadata.IntrospectionLevel.STRUCTURE,io.busystack.busydata.metadata.MetadataState.AVAILABLE,true,"",1,1,1,""));}
        var snapshot=new io.busystack.busydata.metadata.MetadataSnapshot("source","profile",7,3,1,rules,entries,coverage);var context=new ResolutionContext("db","public",List.of("pg_temp","public"),true,7,3,rules,snapshot,"pg_temp_7");
        for(String sql:List.of("SELECT x. FROM pg_temp.scratch x","SELECT x. FROM scratch x")){var items=request(sql,sql.indexOf('.')+1,Engine.POSTGRESQL,AnalysisOperation.COMPLETION,snapshot.objects(),context).getCompletionsList();assertTrue(items.stream().anyMatch(c->c.getLabel().equals("temp_id")));assertFalse(items.stream().anyMatch(c->c.getLabel().equals("durable_id")));}
        var explicitLateTemporary=new ResolutionContext("db","public",List.of("public","pg_temp"),true,7,3,rules,snapshot,"pg_temp_7");String select="SELECT x. FROM scratch x";var lateItems=request(select,select.indexOf('.')+1,Engine.POSTGRESQL,AnalysisOperation.COMPLETION,snapshot.objects(),explicitLateTemporary).getCompletionsList();assertTrue(lateItems.stream().anyMatch(c->c.getLabel().equals("durable_id")));assertFalse(lateItems.stream().anyMatch(c->c.getLabel().equals("temp_id")));
        String qualified="SELECT pg_temp.calculate()",ordinary="SELECT calculate(1,2)";var own=request(qualified,qualified.length()-1,Engine.POSTGRESQL,AnalysisOperation.PARAMETER_INFORMATION,snapshot.objects(),context).getParameterInformation();assertEquals(0,own.getOverloads(0).getParametersCount());assertEquals("boolean",own.getOverloads(0).getReturnType());
        var persistent=request(ordinary,ordinary.length()-1,Engine.POSTGRESQL,AnalysisOperation.PARAMETER_INFORMATION,snapshot.objects(),context).getParameterInformation();assertEquals(2,persistent.getOverloads(0).getParametersCount());assertEquals("numeric",persistent.getOverloads(0).getReturnType());
        var navigation=SymbolService.resolve(AnalysisRequest.newBuilder().setEngine(Engine.POSTGRESQL).setSql("SELECT * FROM pg_temp.scratch").setCaretUtf16(25).build(),"profile",LexicalSettings.DEFAULT,context,()->false);assertEquals("pg_temp_7",navigation.getSchema());assertEquals("exact",navigation.getAvailability());
    }
    @Test void typeAndOverloadInspectionsReportOnlyProvenIncompatibilities(){
        var metadata=new ArrayList<>(OBJECTS);metadata.add(column("public","orders","active","boolean"));metadata.add(routine("public","calculate(numeric,integer)","numeric"));
        for(var pair:Map.of("SELECT * FROM orders WHERE active=12","type.incompatible-comparison","UPDATE orders SET active=12 WHERE id=1","type.incompatible-assignment","UPDATE orders SET nonexistent=1 WHERE id=1","binding.unknown-update-column","SELECT calculate(true,2)","routine.no-matching-overload").entrySet())assertTrue(request(pair.getKey(),0,Engine.POSTGRESQL,AnalysisOperation.DIAGNOSTICS,metadata,COMPLETE).getDiagnosticsList().stream().anyMatch(d->d.getCode().equals(pair.getValue())),pair.toString());
        assertFalse(request("UPDATE orders SET active='true' WHERE id=1",0,Engine.POSTGRESQL,AnalysisOperation.DIAGNOSTICS,metadata,COMPLETE).getDiagnosticsList().stream().anyMatch(d->d.getCode().equals("type.incompatible-assignment")));
        assertTrue(SqlTypes.compatible(SqlTypes.nativeType("integer",Engine.MYSQL),SqlTypes.nativeType("boolean",Engine.MYSQL),Engine.MYSQL));
        // PostgreSQL17 functions-datetime: two timestamp forms, interval,
        // and the explicit timezone form are distinct native signatures.
        String call="SELECT date_trunc('day', now(), 'UTC')";
        var information=request(call,call.indexOf("UTC"),Engine.POSTGRESQL,AnalysisOperation.PARAMETER_INFORMATION,List.of(),COMPLETE).getParameterInformation();
        var signatures=information.getOverloadsList().stream().map(overload->String.join(",",overload.getParametersList().stream().map(RoutineParameter::getNativeType).toList())+"->"+overload.getReturnType()).toList();
        assertEquals(Set.of("text,timestamp->timestamp","text,timestamptz->timestamptz","text,interval->interval","text,timestamptz,text->timestamptz"),new HashSet<>(signatures));
        assertEquals(4,signatures.size(),"Every native overload appears exactly once");assertEquals(2,information.getActiveArgument());assertEquals("available",information.getAvailability());
    }
    @Test void postgresSearchPathCombinesDistinctNativeOverloadsAndShadowsOnlyIdenticalInputs(){
        var rules=new io.busystack.busydata.metadata.IdentifierRules(Engine.POSTGRESQL,0);
        var first=routine("public","calculate(numeric,integer)","numeric").toBuilder().putProperties("parameter.0.nativeTypeId","1700").putProperties("parameter.1.nativeTypeId","23").build();
        var shadowed=routine("audit","calculate(numeric,integer)","numeric").toBuilder().putProperties("parameter.0.nativeTypeId","1700").putProperties("parameter.1.nativeTypeId","23").putProperties("returnType","boolean").putProperties("parameterCount","3").putProperties("parameter.2.mode","OUT").putProperties("parameter.2.type","boolean").putProperties("parameter.2.nativeTypeId","16").build();
        var later=routine("audit","calculate(text,integer)","text").toBuilder().putProperties("parameter.0.nativeTypeId","25").putProperties("parameter.1.nativeTypeId","23").putProperties("returnType","text").build();
        var entries=List.of(first,shadowed,later).stream().map(object->io.busystack.busydata.metadata.MetadataObject.from("source","profile","",rules,object,io.busystack.busydata.metadata.IntrospectionLevel.STRUCTURE,1,1)).toList();var coverage=new HashMap<io.busystack.busydata.metadata.MetadataScope,io.busystack.busydata.metadata.MetadataCoverage>();
        for(String schema:List.of("pg_catalog","public","audit")){var scope=new io.busystack.busydata.metadata.MetadataScope("db",schema,"",ObjectKind.ROUTINE);coverage.put(scope,new io.busystack.busydata.metadata.MetadataCoverage(scope,io.busystack.busydata.metadata.IntrospectionLevel.STRUCTURE,io.busystack.busydata.metadata.MetadataState.AVAILABLE,true,"",1,1,1,""));}
        var snapshot=new io.busystack.busydata.metadata.MetadataSnapshot("source","profile",7,3,1,rules,entries,coverage);var context=new ResolutionContext("db","public",List.of("public","audit"),true,7,3,rules,snapshot);String call="SELECT calculate(1,2)";
        var visible=request(call,call.length()-1,Engine.POSTGRESQL,AnalysisOperation.PARAMETER_INFORMATION,snapshot.objects(),context).getParameterInformation();assertEquals("available",visible.getAvailability());assertEquals(2,visible.getOverloadsCount());assertEquals(Set.of("numeric","text"),visible.getOverloadsList().stream().map(RoutineSignature::getReturnType).collect(java.util.stream.Collectors.toSet()));
        String qualified="SELECT audit.calculate(1,2)";assertEquals(2,request(qualified,qualified.length()-1,Engine.POSTGRESQL,AnalysisOperation.PARAMETER_INFORMATION,snapshot.objects(),context).getParameterInformation().getOverloadsCount());
        coverage.keySet().removeIf(scope->scope.schema().equals("pg_catalog"));var incomplete=new io.busystack.busydata.metadata.MetadataSnapshot("source","profile",7,3,1,rules,entries,coverage);var incompleteContext=new ResolutionContext("db","public",List.of("public","audit"),true,7,3,rules,incomplete);assertEquals("partial-signatures",request(call,call.length()-1,Engine.POSTGRESQL,AnalysisOperation.PARAMETER_INFORMATION,incomplete.objects(),incompleteContext).getParameterInformation().getAvailability());
    }
    @Test void literalTimestampContextChangesDoNotInvalidateUnchangedCatalogStructure(){
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB))for(String sql:List.of("SET time_zone='+00:00'","SET SESSION time_zone='+01:00'","SET LOCAL time_zone=DEFAULT"))assertTrue(DdlImpact.analyze(sql,engine,LexicalSettings.DEFAULT,COMPLETE).isEmpty(),sql);
        assertFalse(DdlImpact.analyze("SET search_path=public",Engine.POSTGRESQL,LexicalSettings.DEFAULT,COMPLETE).isEmpty());assertFalse(DdlImpact.analyze("SET time_zone='+00:00',sql_mode=''",Engine.MYSQL,LexicalSettings.DEFAULT,COMPLETE).isEmpty());
        assertTrue(DdlImpact.analyze("SET array_nulls TO OFF",Engine.POSTGRESQL,LexicalSettings.DEFAULT,COMPLETE).isEmpty());assertTrue(DdlImpact.analyze("SET LOCAL array_nulls='on'",Engine.POSTGRESQL,LexicalSettings.DEFAULT,COMPLETE).isEmpty());
    }
    @Test void noSessionAnalysisRetainsBuiltinsLocalScopesAndAvailabilityWithoutServerObjects(){
        var service=new SqlAnalysis();String local="WITH c AS (SELECT 1 AS local_name) SELECT c.lo FROM c";
        var request=AnalysisRequest.newBuilder().setEngine(Engine.POSTGRESQL).setSql(local).setCaretUtf16(local.indexOf("c.lo")+4).build();
        var completion=service.analyze(request);assertEquals("incomplete-metadata",completion.getAvailability());assertTrue(completion.getCompletionsList().stream().anyMatch(item->item.getLabel().equals("local_name")));
        String call="SELECT lower(";var parameters=service.analyze(request.toBuilder().setOperation(AnalysisOperation.PARAMETER_INFORMATION).setSql(call).setCaretUtf16(call.length()).build());assertEquals("available",parameters.getParameterInformation().getAvailability());assertEquals(1,parameters.getParameterInformation().getOverloadsCount());
        String missing="SELECT * FROM public.server_object";var diagnostic=service.analyze(request.toBuilder().setOperation(AnalysisOperation.DIAGNOSTICS).setSql(missing).setCaretUtf16(0).build());assertTrue(diagnostic.getDiagnosticsList().stream().anyMatch(Diagnostic::getIncomplete));assertFalse(diagnostic.getDiagnosticsList().stream().anyMatch(item->item.getCode().equals("binding.unresolved-relation")));
        assertTrue(service.analyze(request.toBuilder().setSql("sel").setCaretUtf16(3).putSnippets("Select local","SELECT 1").build()).getCompletionsList().stream().anyMatch(item->item.getKind().equals("snippet")));
    }
    @Test void runtimeSemanticApisCannotAcceptASecondWireMetadataModel(){
        for(var method:SqlAnalysis.class.getDeclaredMethods())if(method.getName().equals("analyze"))assertTrue(Arrays.stream(method.getParameterTypes()).noneMatch(type->List.class.isAssignableFrom(type)));
        for(var constructor:SemanticCatalog.class.getDeclaredConstructors())assertTrue(Arrays.stream(constructor.getParameterTypes()).noneMatch(type->List.class.isAssignableFrom(type)));
        for(var method:SemanticDocument.class.getDeclaredMethods())if(Set.of("bind","complete","completeBatch").contains(method.getName()))assertTrue(Arrays.stream(method.getParameterTypes()).noneMatch(type->List.class.isAssignableFrom(type)));
    }

}
