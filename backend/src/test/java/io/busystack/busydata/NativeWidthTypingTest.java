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

/** Native width facts are independently checked by ExpressionTypingIT. */
class NativeWidthTypingTest {
    private static SemanticBinder bind(String sql,Engine engine,List<SchemaObject> objects){String schema=engine==Engine.POSTGRESQL?"public":"db";var context=SemanticFixtures.context(engine,objects,new ResolutionContext("db",schema,List.of(schema),true,1,1));return new SemanticDocument(sql,engine,LexicalSettings.DEFAULT,new AnalysisBudget(1500,()->false)).bind(context);}
    private static Type type(String expression,Engine engine){var binder=bind("SELECT "+expression+" AS v",engine,List.of());return binder.project(binder.tree().queries().getFirst()).getFirst().type();}
    private static Type output(String sql,Engine engine){var binder=bind(sql,engine,List.of());return binder.project(binder.tree().queries().getFirst()).getFirst().type();}
    private static SchemaObject table(){return SchemaObject.newBuilder().setKind(ObjectKind.TABLE).setCatalog("db").setSchema("db").setName("t").build();}
    private static SchemaObject column(String name,String nativeType,String precision){return SchemaObject.newBuilder().setKind(ObjectKind.COLUMN).setCatalog("db").setSchema("db").setTable("t").setName(name).putProperties("nativeType",nativeType).putProperties("precision",precision).putProperties("nullable","NO").build();}
    @Test void mariaLiteralWidthsUseSourceCharactersRatherThanTheValueRange(){
        for(String expression:List.of("1","000000001","123456789","-1"))assertEquals(32,type(expression,Engine.MARIADB).integerBits(),expression);
        for(String expression:List.of("0000000001","1000000000","-123456789"))assertEquals(64,type(expression,Engine.MARIADB).integerBits(),expression);
        assertEquals(9,type("000000001",Engine.MARIADB).numericShape().characters());assertEquals(10,type("0000000001",Engine.MARIADB).numericShape().characters());
        assertEquals(64,type("1",Engine.MYSQL).integerBits());
    }
    @Test void mariaArithmeticAndCastsFollowTheirDistinctNativeWidthThresholds(){
        for(String expression:List.of("1+2","1234567+1","1234*1234","5 DIV 2","5%2","-CAST(1 AS UNSIGNED)"))assertEquals(32,type(expression,Engine.MARIADB).integerBits(),expression);
        for(String expression:List.of("12345678+1","12345*12345"))assertEquals(64,type(expression,Engine.MARIADB).integerBits(),expression);
        for(String expression:List.of("CAST(3 AS UNSIGNED)","CAST(123456789 AS UNSIGNED)","CAST(1234567890 AS UNSIGNED)","CAST('3' AS UNSIGNED)")){
            var value=type(expression,Engine.MARIADB);assertEquals(32,value.integerBits(),expression);assertTrue(value.unsigned(),expression);
        }
        var negative=type("CAST(-1 AS UNSIGNED)",Engine.MARIADB);assertEquals(64,negative.integerBits());assertTrue(negative.unsigned());
        assertEquals(2,type("CAST(3 AS UNSIGNED)-2",Engine.MARIADB).numericShape().characters());
        assertEquals(Family.DECIMAL,type("-1.25",Engine.MARIADB).family());assertEquals(Family.REAL,type("-1e2",Engine.MARIADB).family());
    }
    @Test void mysqlConstantMaterializationNarrowsWhileTypeHoldersPreserveTheirWidth(){
        assertEquals(64,type("1+2",Engine.MYSQL).integerBits());
        for(String sql:List.of("WITH c(n) AS(SELECT 1+2)SELECT n FROM c","SELECT d.n FROM(SELECT 1+2 AS n)d","SELECT d.n FROM(SELECT (SELECT 1)AS n)d"))assertEquals(32,output(sql,Engine.MYSQL).integerBits(),sql);
        for(String sql:List.of("WITH c(n) AS(SELECT CAST(1 AS UNSIGNED))SELECT n FROM c","WITH c(n) AS(SELECT 1 UNION SELECT 2)SELECT n FROM c","WITH RECURSIVE r(n)AS(SELECT 1 UNION ALL SELECT n+1 FROM r WHERE n<2)SELECT n FROM r"))assertEquals(64,output(sql,Engine.MYSQL).integerBits(),sql);
    }
    @Test void mariaDerivedFieldArithmeticReservesTheCompleteNativeRangeButScalarQueriesDoNot(){
        for(String sql:List.of("SELECT d.n+1 AS v FROM(SELECT 2 AS n)d","WITH c(n)AS(SELECT 2)SELECT n+1 AS v FROM c")){
            var result=output(sql,Engine.MARIADB);assertEquals(64,result.integerBits(),sql);assertEquals(12,result.numericShape().characters(),sql);
        }
        var unsigned=output("SELECT d.n+1 AS v FROM(SELECT CAST(3 AS UNSIGNED)AS n)d",Engine.MARIADB);assertEquals(64,unsigned.integerBits());assertTrue(unsigned.unsigned());assertEquals(11,unsigned.numericShape().characters());
        var scalar=output("SELECT (SELECT 2)+1 AS v",Engine.MARIADB);assertEquals(32,scalar.integerBits());assertEquals(3,scalar.numericShape().characters());
        assertEquals(32,output("SELECT d.n AS v FROM(SELECT 2 AS n)d",Engine.MARIADB).integerBits());
    }
    @Test void genericUnaryMinusUsesEachEnginesDisplayWidthRulesAtMaterializationBoundary(){
        assertEquals(32,output("WITH c(n)AS(SELECT -(1234567+1))SELECT n FROM c",Engine.MYSQL).integerBits());
        assertEquals(64,output("WITH c(n)AS(SELECT -(1234567+1))SELECT n FROM c",Engine.MARIADB).integerBits());
        assertEquals(32,output("WITH c(n)AS(SELECT -(123456+1))SELECT n FROM c",Engine.MARIADB).integerBits());
        assertEquals(64,type("-(1234567+1)",Engine.MYSQL).integerBits());
    }
    @Test void optimizerDependentIntegerWidthsRemainExplicitlyUnavailable(){
        var objects=List.of(table(),column("tiny","tinyint","3"));var binder=bind("SELECT d.n FROM(SELECT tiny+1 AS n FROM t)d",Engine.MYSQL,objects);var type=binder.project(binder.tree().queries().getFirst()).getFirst().type();
        assertEquals(Family.INTEGER,type.family());assertFalse(type.nativeKnown());assertEquals(0,type.integerBits());assertTrue(binder.diagnostics().stream().anyMatch(LanguageIssue::incomplete));assertFalse(binder.diagnostics().stream().anyMatch(issue->issue.code().startsWith("binding.")));
        var limited=bind("SELECT d.n FROM(SELECT tiny+1 AS n FROM t LIMIT 1)d",Engine.MYSQL,objects);assertEquals(32,limited.project(limited.tree().queries().getFirst()).getFirst().type().integerBits());
    }
    @ParameterizedTest @EnumSource(value=Engine.class,names={"MYSQL","MARIADB"}) void largeTextMetadataNeverBecomesAnAllocationOrLosesItsDeclaredPrecision(Engine engine){
        var column=column("payload","longtext",Integer.toString(Integer.MAX_VALUE));Type type=assertDoesNotThrow(()->SqlTypes.column(column,engine));assertEquals(Family.TEXT,type.family());assertEquals(Integer.MAX_VALUE,type.precision());assertEquals(Integer.MAX_VALUE,type.numericShape().characters());
        var binder=bind("SELECT payload FROM t",engine,List.of(table(),column));var output=binder.project(binder.tree().queries().getFirst()).getFirst().type();assertEquals(Family.TEXT,output.family());assertTrue(output.nativeKnown());assertTrue(binder.diagnostics().isEmpty(),()->binder.diagnostics().toString());
    }
    @ParameterizedTest @EnumSource(value=Engine.class,names={"POSTGRESQL","MYSQL","MARIADB"}) void oversizedCastModifiersRemainBoundedAndExplicitlyUnavailable(Engine engine){
        var binder=assertDoesNotThrow(()->bind("SELECT CAST(1 AS DECIMAL(999999999,4)) AS v",engine,List.of()));var type=assertDoesNotThrow(()->binder.project(binder.tree().queries().getFirst()).getFirst().type());assertEquals(Family.DECIMAL,type.family());assertEquals(999999999,type.precision());assertTrue(binder.diagnostics().stream().anyMatch(LanguageIssue::incomplete));
    }
}
