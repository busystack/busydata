package io.busystack.busydata;

import io.busystack.busydata.analysis.*;
import io.busystack.busydata.analysis.language.*;
import io.busystack.busydata.analysis.language.SqlTypes.*;
import io.busystack.busydata.protocol.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import static org.junit.jupiter.api.Assertions.*;

class QueryOutputTypingTest {
    private static SemanticBinder bind(String sql,Engine engine){return bind(sql,engine,List.of());}
    private static SemanticBinder bind(String sql,Engine engine,List<SchemaObject> objects){
        String schema=engine==Engine.POSTGRESQL?"public":"db";var context=SemanticFixtures.context(engine,objects,new ResolutionContext("db",schema,List.of(schema),true,7,3));
        return new SemanticDocument(sql,engine,LexicalSettings.DEFAULT,new AnalysisBudget(1500,()->false)).bind(context);
    }
    private static List<SemanticBinder.ColumnSymbol> output(SemanticBinder binder){return binder.project(binder.tree().queries().getFirst());}
    private static SchemaObject table(String name){return SchemaObject.newBuilder().setKind(ObjectKind.TABLE).setCatalog("db").setSchema("public").setName(name).build();}
    private static SchemaObject column(String table,String name,String type){return SchemaObject.newBuilder().setKind(ObjectKind.COLUMN).setCatalog("db").setSchema("public").setTable(table).setName(name).putProperties("nativeType",type).putProperties("nullable","NO").build();}
    @ParameterizedTest @EnumSource(value=Engine.class,names={"POSTGRESQL","MYSQL","MARIADB"}) void explicitCteNamesKeepPositionalComputedTypes(Engine engine){
        var binder=bind("WITH c(n,m) AS (SELECT 1+2, CAST(2 AS DECIMAL(18,4))) SELECT n,m FROM c",engine);var output=output(binder);
        assertEquals(List.of("n","m"),output.stream().map(SemanticBinder.ColumnSymbol::name).toList());assertEquals(Family.INTEGER,output.get(0).type().family());assertEquals(Family.DECIMAL,output.get(1).type().family());assertEquals(18,output.get(1).type().precision());assertEquals(4,output.get(1).type().scale());assertTrue(binder.diagnostics().isEmpty(),()->binder.diagnostics().toString());
    }
    @ParameterizedTest @EnumSource(value=Engine.class,names={"POSTGRESQL","MYSQL","MARIADB"}) void recursiveColumnsBindToTheNonrecursiveAnchor(Engine engine){
        var binder=bind("WITH RECURSIVE r(n) AS (SELECT 1 UNION ALL SELECT n+1 FROM r WHERE n<3) SELECT n FROM r",engine);var output=output(binder);
        assertEquals(engine==Engine.MYSQL?"bigint":"integer",output.getFirst().type().nativeName());assertTrue(output.getFirst().type().nullable());assertTrue(binder.diagnostics().isEmpty(),()->binder.diagnostics().toString());
        var ordinary=bind("WITH RECURSIVE c(n) AS (SELECT 1 UNION ALL SELECT 2.5) SELECT n FROM c",engine);assertEquals(Family.DECIMAL,output(ordinary).getFirst().type().family());assertTrue(ordinary.diagnostics().isEmpty(),()->ordinary.diagnostics().toString());
    }
    @Test void postgresRecursiveOverallTypeCannotWidenItsAnchor(){
        var invalid=bind("WITH RECURSIVE r(n) AS (SELECT 1 UNION ALL SELECT n+0.5 FROM r) SELECT n FROM r",Engine.POSTGRESQL);assertTrue(invalid.diagnostics().stream().anyMatch(i->i.code().equals("type.recursive-cte-mismatch")),()->invalid.diagnostics().toString());
        var narrowed=bind("WITH RECURSIVE r(n) AS (SELECT CAST(1 AS bigint) UNION ALL SELECT CAST(n AS integer) FROM r) SELECT n FROM r",Engine.POSTGRESQL);assertEquals("bigint",output(narrowed).getFirst().type().nativeName());assertTrue(narrowed.diagnostics().isEmpty(),()->narrowed.diagnostics().toString());
        var cast=bind("WITH RECURSIVE r(n) AS (SELECT CAST(1 AS numeric(12,3)) UNION ALL SELECT CAST(n+1 AS numeric(12,3)) FROM r) SELECT n FROM r",Engine.POSTGRESQL);assertTrue(cast.diagnostics().isEmpty(),()->cast.diagnostics().toString());
    }
    @ParameterizedTest @EnumSource(value=Engine.class,names={"POSTGRESQL","MYSQL","MARIADB"}) void setNamesComeFromFirstInputWhileTypesUseAllInputs(Engine engine){
        var binder=bind("SELECT 1 AS first_name UNION ALL SELECT 2.5 AS other_name",engine);var output=output(binder);assertEquals("first_name",output.getFirst().name());assertEquals(Family.DECIMAL,output.getFirst().type().family());assertTrue(binder.diagnostics().isEmpty(),()->binder.diagnostics().toString());
        var derived=bind("SELECT d.n FROM (SELECT 1 AS n UNION SELECT 2.5) d",engine);assertEquals(Family.DECIMAL,output(derived).getFirst().type().family());
        assertTrue(bind("SELECT 1 AS n UNION SELECT 1,2",engine).diagnostics().stream().anyMatch(i->i.code().equals("type.set-column-count")));
    }
    @Test void postgresSetTypeResolutionIsPairwiseAndPreservesUnknownLiteralsUntilResolution(){
        var typed=bind("SELECT NULL AS n UNION SELECT 1",Engine.POSTGRESQL);assertEquals("integer",output(typed).getFirst().type().nativeName());assertTrue(typed.diagnostics().isEmpty(),()->typed.diagnostics().toString());
        var string=bind("SELECT '1' AS n UNION SELECT 2",Engine.POSTGRESQL);assertEquals("integer",output(string).getFirst().type().nativeName());assertTrue(string.diagnostics().isEmpty(),()->string.diagnostics().toString());
        var failed=bind("SELECT NULL AS n UNION SELECT NULL UNION SELECT 1",Engine.POSTGRESQL);assertTrue(failed.diagnostics().stream().anyMatch(i->i.code().equals("type.incompatible-set")),()->failed.diagnostics().toString());
        var grouped=bind("SELECT NULL AS n UNION (SELECT NULL UNION SELECT 1)",Engine.POSTGRESQL);assertEquals("integer",output(grouped).getFirst().type().nativeName());assertTrue(grouped.diagnostics().isEmpty(),()->grouped.diagnostics().toString());
        var precedence=bind("SELECT NULL AS n UNION SELECT NULL INTERSECT SELECT 1",Engine.POSTGRESQL);assertEquals("integer",output(precedence).getFirst().type().nativeName());
    }
    @Test void positionalAliasCountFollowsEngineRules(){
        var partial=bind("WITH c(x) AS (SELECT 1 AS a, 2 AS b) SELECT x,b FROM c",Engine.POSTGRESQL);assertEquals(List.of("x","b"),output(partial).stream().map(SemanticBinder.ColumnSymbol::name).toList());assertTrue(partial.diagnostics().isEmpty(),()->partial.diagnostics().toString());
        for(var engine:List.of(Engine.POSTGRESQL,Engine.MYSQL,Engine.MARIADB))assertTrue(bind("WITH c(x,y) AS (SELECT 1 AS a) SELECT x FROM c",engine).diagnostics().stream().anyMatch(i->i.code().equals("binding.output-column-count")),engine.toString());
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB))assertTrue(bind("WITH c(x) AS (SELECT 1 AS a, 2 AS b) SELECT x FROM c",engine).diagnostics().stream().anyMatch(i->i.code().equals("binding.output-column-count")),engine.toString());
    }
    @ParameterizedTest @EnumSource(value=Engine.class,names={"POSTGRESQL","MYSQL","MARIADB"}) void scalarSubqueriesKeepTheirTypeAndAreNullable(Engine engine){
        var binder=bind("SELECT (SELECT 1 WHERE FALSE) AS n",engine);var value=output(binder).getFirst().type();assertEquals(Family.INTEGER,value.family());assertTrue(value.nullable());assertTrue(binder.diagnostics().isEmpty(),()->binder.diagnostics().toString());
        var set=bind("SELECT (SELECT 1 UNION SELECT 2.5) AS n",engine);assertEquals(Family.DECIMAL,output(set).getFirst().type().family());assertTrue(output(set).getFirst().type().nullable());
    }
    @Test void computedOutputNamesNeverBorrowTheFinalReferencedIdentifier(){
        var objects=List.of(table("t"),column("t","id","integer"),column("t","amount","numeric(18,4)"));
        var unknown=bind("SELECT d.id FROM (SELECT id+amount FROM t) d",Engine.POSTGRESQL,objects);assertFalse(unknown.visible(unknown.tree().queries().getFirst()).getFirst().complete());assertTrue(unknown.diagnostics().stream().anyMatch(LanguageIssue::incomplete));assertFalse(unknown.diagnostics().stream().anyMatch(i->i.code().equals("binding.unresolved-column")));
        var renamed=bind("SELECT d.x,d.y FROM (SELECT id+amount, id+1 FROM t) d(x,y)",Engine.POSTGRESQL,objects);assertEquals(List.of(Family.DECIMAL,Family.INTEGER),output(renamed).stream().map(c->c.type().family()).toList());assertTrue(renamed.diagnostics().isEmpty(),()->renamed.diagnostics().toString());
    }
    @Test void groupAndHavingResolveInputAmbiguityBeforeOutputAliases(){
        var objects=List.of(table("a"),table("b"),column("a","id","integer"),column("b","id","integer"));
        var group=bind("SELECT a.id AS id FROM a JOIN b ON true GROUP BY id",Engine.POSTGRESQL,objects);assertTrue(group.diagnostics().stream().anyMatch(i->i.code().equals("binding.ambiguous-column")),()->group.diagnostics().toString());
        var order=bind("SELECT a.id AS id FROM a JOIN b ON true ORDER BY id",Engine.POSTGRESQL,objects);assertFalse(order.diagnostics().stream().anyMatch(i->i.code().equals("binding.ambiguous-column")),()->order.diagnostics().toString());
    }
    @Test void postgresValuesUseAllRowsAndSupplyDocumentedDefaultNames(){
        var value=bind("WITH c(n) AS (VALUES (1),(2)) SELECT n FROM c",Engine.POSTGRESQL);assertEquals("integer",output(value).getFirst().type().nativeName());
        var mixed=bind("SELECT d.column1 FROM (VALUES (NULL),(NULL),(1)) d",Engine.POSTGRESQL);assertEquals("integer",output(mixed).getFirst().type().nativeName());
        var recursive=bind("WITH RECURSIVE r(n) AS (VALUES (1) UNION ALL SELECT n+1 FROM r WHERE n<3) SELECT n FROM r",Engine.POSTGRESQL);assertEquals("integer",output(recursive).getFirst().type().nativeName());assertTrue(recursive.diagnostics().isEmpty(),()->recursive.diagnostics().toString());
    }
    @Test void postgresDerivedAndCteOutputsKeepSameNativeTypesAcrossTypmods(){
        for(String sql:List.of("SELECT d.n FROM (SELECT CASE WHEN TRUE THEN CAST('a' AS varchar(10)) ELSE CAST('b' AS varchar(20)) END AS n) d","WITH c(n) AS (SELECT coalesce(CAST('a' AS varchar(10)),CAST('b' AS varchar(20)))) SELECT n FROM c")){
            var binder=bind(sql,Engine.POSTGRESQL);var type=output(binder).getFirst().type();assertTrue(SqlTypes.sameNative(SqlTypes.nativeType("varchar",Engine.POSTGRESQL),type,Engine.POSTGRESQL));assertEquals(0,type.precision());assertTrue(binder.diagnostics().isEmpty(),()->sql+": "+binder.diagnostics());
        }
        var nullif=bind("SELECT d.n FROM (SELECT nullif(1,CAST(2 AS bigint)) AS n) d",Engine.POSTGRESQL);assertEquals("integer",output(nullif).getFirst().type().nativeName());assertTrue(nullif.diagnostics().isEmpty(),()->nullif.diagnostics().toString());
    }
    @Test void postgresValuesNeverTreatOrderByArgumentsAsAdditionalRows(){
        for(String order:List.of("abs(1)","CAST(1 AS integer)")){
            var binder=bind("VALUES (1,2),(3,4) ORDER BY "+order,Engine.POSTGRESQL);var columns=output(binder);
            assertEquals(List.of("column1","column2"),columns.stream().map(SemanticBinder.ColumnSymbol::name).toList());
            assertTrue(columns.stream().allMatch(column->column.type().family()==Family.INTEGER));
            assertTrue(binder.diagnostics().isEmpty(),()->binder.diagnostics().toString());
        }
    }
}
