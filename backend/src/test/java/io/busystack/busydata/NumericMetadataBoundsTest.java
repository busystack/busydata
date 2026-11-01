package io.busystack.busydata;

import io.busystack.busydata.analysis.*;
import io.busystack.busydata.analysis.language.*;
import io.busystack.busydata.analysis.language.SqlTypes.*;
import io.busystack.busydata.protocol.*;
import java.math.BigInteger;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import static org.junit.jupiter.api.Assertions.*;

/** Malformed metadata and invalid/overflowing SQL remain bounded editor inputs;
 * these checks never execute SQL or assert successful server evaluation. */
class NumericMetadataBoundsTest {
    private static SchemaObject table(){return SchemaObject.newBuilder().setKind(ObjectKind.TABLE).setCatalog("db").setSchema("db").setName("t").build();}
    private static SchemaObject decimal(String scale){return SchemaObject.newBuilder().setKind(ObjectKind.COLUMN).setCatalog("db").setSchema("db").setTable("t").setName("amount").putProperties("nativeType","decimal").putProperties("precision","1").putProperties("scale",scale).putProperties("nullable","NO").build();}
    private static SemanticBinder bind(String sql,Engine engine,List<SchemaObject> objects){
        var context=SemanticFixtures.context(engine,objects,new ResolutionContext("db","db",List.of("db"),true,1,1));
        return new SemanticDocument(sql,engine,LexicalSettings.DEFAULT,new AnalysisBudget(1500,()->false)).bind(context);
    }
    private static Type output(SemanticBinder binder){return binder.project(binder.tree().queries().getFirst()).getFirst().type();}
    @ParameterizedTest @EnumSource(value=Engine.class,names={"MYSQL","MARIADB"})
    void malformedDecimalScaleKeepsExactMetadataWithoutInferringAnOverflowingShape(Engine engine){
        for(String scale:List.of(Integer.toString(Integer.MIN_VALUE),Integer.toString(Integer.MIN_VALUE+2),"-1","2",Integer.toString(Integer.MAX_VALUE))){
            var column=decimal(scale);Type type=assertDoesNotThrow(()->SqlTypes.column(column,engine),scale);
            assertEquals(Family.DECIMAL,type.family());assertEquals(1,type.precision());assertEquals(Integer.parseInt(scale),type.scale());assertFalse(type.numericShape().known());
            var binder=assertDoesNotThrow(()->bind("SELECT amount FROM t",engine,List.of(table(),column)),scale);
            Type projected=assertDoesNotThrow(()->output(binder),scale);assertEquals(type.precision(),projected.precision());assertEquals(type.scale(),projected.scale());assertDoesNotThrow(binder::diagnostics,scale);
        }
    }
    @Test void malformedMariaDecimalShapeStaysUnknownThroughCastsAndScalarOrDerivedFields(){
        for(String scale:List.of(Integer.toString(Integer.MIN_VALUE),Integer.toString(Integer.MIN_VALUE+2)))for(String sql:List.of(
            "SELECT (SELECT CAST(amount AS SIGNED)) AS value FROM t",
            "SELECT d.value FROM(SELECT CAST(amount AS SIGNED) AS value FROM t)d")){
            var binder=assertDoesNotThrow(()->bind(sql,Engine.MARIADB,List.of(table(),decimal(scale))));Type type=assertDoesNotThrow(()->output(binder));
            assertEquals(Family.INTEGER,type.family());assertFalse(type.nativeKnown());assertFalse(type.numericShape().known());assertTrue(assertDoesNotThrow(binder::diagnostics).stream().anyMatch(LanguageIssue::incomplete));
        }
    }
    @ParameterizedTest @EnumSource(value=Engine.class,names={"MYSQL","MARIADB"})
    void validDecimalAndLongTextDescriptorsRetainTheirFullPrecision(Engine engine){
        var column=decimal("30").toBuilder().putProperties("precision","65").build();Type type=assertDoesNotThrow(()->SqlTypes.column(column,engine));
        assertEquals(65,type.precision());assertEquals(30,type.scale());assertEquals(35,type.numericShape().integerDigits());assertEquals(67,type.numericShape().characters());
        var text=column.toBuilder().putProperties("nativeType","longtext").putProperties("precision",Integer.toString(Integer.MAX_VALUE)).putProperties("scale","0").build();Type large=assertDoesNotThrow(()->SqlTypes.column(text,engine));
        assertEquals(Family.TEXT,large.family());assertEquals(Integer.MAX_VALUE,large.precision());assertEquals(Integer.MAX_VALUE,large.numericShape().characters());
    }
    @ParameterizedTest @EnumSource(value=Engine.class,names={"MYSQL","MARIADB"})
    void absoluteDropsAnUnrepresentableConstantFactInsteadOfThrowing(Engine engine){
        String sql="SELECT ABS((0 - 18446744073709551615 - 18446744073709551615) - 2) AS value";
        var binder=assertDoesNotThrow(()->bind(sql,engine,List.of()));Type type=assertDoesNotThrow(()->output(binder));
        assertEquals(Family.INTEGER,type.family());assertNull(type.numericShape().exact());assertDoesNotThrow(binder::diagnostics);
        var ordinary=bind("SELECT ABS(-7) AS value",engine,List.of());assertEquals(BigInteger.valueOf(7),output(ordinary).numericShape().exact());
    }
    @ParameterizedTest @EnumSource(value=Engine.class,names={"MYSQL","MARIADB"})
    void leadingZeroSourceWidthCanExceedTheConstantFactBitBudget(Engine engine){
        String literal="0".repeat(96)+"1";var binder=assertDoesNotThrow(()->bind("SELECT "+literal+" AS value",engine,List.of()));Type type=assertDoesNotThrow(()->output(binder));
        assertEquals(Family.INTEGER,type.family());assertTrue(type.nativeKnown());assertEquals(literal.length(),type.numericShape().integerDigits());assertEquals(BigInteger.ONE,type.numericShape().exact());assertDoesNotThrow(binder::diagnostics);
    }
    @Test void excessiveNativeArrayNestingBecomesExplicitlyUnknownWithoutTruncatingItsName(){
        for(String name:List.of("integer"+"[]".repeat(30000),"integer"+"[] ".repeat(20000))){
            assertTrue(name.length()<=65536);Type type=assertDoesNotThrow(()->SqlTypes.nativeType(name,Engine.POSTGRESQL));assertEquals(Family.UNKNOWN,type.family());assertFalse(type.nativeKnown());assertEquals(name,type.nativeName());
            var column=SchemaObject.newBuilder().setKind(ObjectKind.COLUMN).setCatalog("db").setSchema("public").setTable("t").setName("value").putProperties("nativeType",name).build();
            Type descriptor=assertDoesNotThrow(()->SqlTypes.column(column,Engine.POSTGRESQL));assertEquals(Family.UNKNOWN,descriptor.family());assertEquals(name,descriptor.nativeName());
        }
    }
    @Test void interiorWhitespaceBeforeAnArraySuffixDoesNotTriggerQuadraticTypeScanning(){
        String spaces=" ".repeat(60000),array="integer"+spaces+"[]";
        assertTimeout(java.time.Duration.ofSeconds(2),()->{
            Type type=assertDoesNotThrow(()->SqlTypes.nativeType(array,Engine.POSTGRESQL));assertEquals(Family.ARRAY,type.family());assertEquals(array,type.nativeName());assertEquals(32,type.element().integerBits());assertEquals(0,type.integerBits());
            Type integer=assertDoesNotThrow(()->SqlTypes.nativeType("integer"+spaces+" unsigned",Engine.MYSQL));assertEquals(Family.INTEGER,integer.family());assertTrue(integer.unsigned());assertEquals(32,integer.integerBits());
        });
    }
    @ParameterizedTest @EnumSource(value=Engine.class,names={"MYSQL","MARIADB"})
    void commonDecimalTypeDoesNotRescanUnboundedWhitespaceForSignedness(Engine engine){
        String spaces=" ".repeat(60000);
        assertTimeout(java.time.Duration.ofSeconds(2),()->{
            for(boolean unsigned:List.of(false,true)){
                String exactName="decimal"+spaces+(unsigned?" unsigned":"");
                var column=decimal("2").toBuilder().putProperties("nativeType",exactName).putProperties("precision","10").build();
                Type input=SqlTypes.column(column,engine),result=SqlTypes.common(List.of(input,input),engine);
                assertEquals(exactName,input.nativeName());assertEquals(Family.DECIMAL,result.family());assertEquals(10,result.precision());assertEquals(2,result.scale());
                assertEquals(engine==Engine.MARIADB&&unsigned,result.unsigned());assertEquals("decimal"+(result.unsigned()?" unsigned":""),result.nativeName());
            }
        });
    }
    @Test void nativeArraysWithinTheNestingBoundaryRemainAvailableIncludingTrailingWhitespace(){
        for(String suffix:List.of(""," ".repeat(60000))){
            String name="integer"+"[]".repeat(AnalysisBudget.MAX_DEPTH)+suffix;Type type=assertDoesNotThrow(()->SqlTypes.nativeType(name,Engine.POSTGRESQL));assertEquals(name,type.nativeName());
            for(int depth=0;depth<AnalysisBudget.MAX_DEPTH;depth++){assertEquals(Family.ARRAY,type.family());assertTrue(type.nativeKnown());assertNotNull(type.element());type=type.element();}
            assertEquals(Family.INTEGER,type.family());assertEquals(32,type.integerBits());
        }
    }
}
