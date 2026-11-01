package io.busystack.busydata;

import io.busystack.busydata.analysis.*;
import io.busystack.busydata.analysis.language.*;
import io.busystack.busydata.analysis.language.SqlTypes.*;
import io.busystack.busydata.analysis.language.SyntaxTree.*;
import io.busystack.busydata.analysis.language.RoutineSignatures.*;
import io.busystack.busydata.protocol.*;
import java.util.*;
import java.util.concurrent.CancellationException;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import static org.junit.jupiter.api.Assertions.*;

class ExpressionTypingTest {
    private static ExpressionAnalyzer.Result expression(String sql,Engine engine){return expression(sql,engine,LexicalSettings.DEFAULT,Map.of());}
    private static ExpressionAnalyzer.Result expression(String sql,Engine engine,LexicalSettings settings,Map<String,List<Signature>> custom){
        var dialect=new Dialect(engine,settings);var budget=new AnalysisBudget(1500,()->false);var document=new SemanticDocument("SELECT "+sql,engine,settings,budget);
        return new ExpressionAnalyzer(dialect,budget,new ExpressionAnalyzer.Resolver(){
            public Type reference(Name name){return switch(name.last().identifier()){case "id"->SqlTypes.nativeType("bigint",engine);case "amount"->SqlTypes.nativeType("numeric(30,9)",engine);case "name"->SqlTypes.nativeType("text",engine);case "flag"->SqlTypes.nativeType("boolean",engine);case "u"->SqlTypes.nullable(SqlTypes.nativeType("decimal(10,2) unsigned",engine),false);case "v"->SqlTypes.nullable(SqlTypes.nativeType("decimal(12,3) unsigned",engine),false);case "s"->SqlTypes.nullable(SqlTypes.nativeType("decimal(10,2)",engine),false);case "domain_value"->new Type(Family.DOMAIN,"example.amount",java.sql.Types.OTHER,0,0,false,true,SqlTypes.nativeType("integer",engine),false);case "custom_value"->new Type(Family.USER,"example.custom",java.sql.Types.OTHER,0,0,false,true,null,false);default->SqlTypes.UNKNOWN;};}
            public ExpressionAnalyzer.CallCandidates routines(Name name,Group arguments,int count){String key=name.last().identifier().toLowerCase(Locale.ROOT);return new ExpressionAnalyzer.CallCandidates(custom.getOrDefault(key,RoutineSignatures.builtins(engine).stream().filter(s->s.name().equals(key)).toList()),true);}
        }).analyze(document.syntax().queries().getFirst().projections().getFirst().expression());
    }
    private static void type(String sql,Engine engine,Family family,String nativeName){var result=expression(sql,engine);assertEquals(family,result.type().family(),()->sql+": "+result.issues());assertEquals(nativeName,result.type().nativeName(),sql);assertTrue(result.issues().isEmpty(),()->result.issues().toString());}
    private static Signature signature(String identity,String input,String output){return new Signature(identity,"f","db","public","f("+input+")",List.of(new Parameter("value","IN",SqlTypes.nativeType(input,Engine.POSTGRESQL),false,false,"")),SqlTypes.nativeType(output,Engine.POSTGRESQL),true);}
    @Test void postgresNumericLiteralTypesAndArithmeticPropagateWithoutFloatingPoint(){
        type("1 + 2 * 3",Engine.POSTGRESQL,Family.INTEGER,"integer");type("2147483648 + 1",Engine.POSTGRESQL,Family.INTEGER,"bigint");
        type("9223372036854775808",Engine.POSTGRESQL,Family.DECIMAL,"numeric");type("9e-4 + 1",Engine.POSTGRESQL,Family.DECIMAL,"numeric");
        type("CAST(1 AS real) + 2",Engine.POSTGRESQL,Family.REAL,"real");type("CAST(1 AS double precision) + 2",Engine.POSTGRESQL,Family.REAL,"double precision");
        type("amount * (id + 1)",Engine.POSTGRESQL,Family.DECIMAL,"numeric");type("5 / 2",Engine.POSTGRESQL,Family.INTEGER,"integer");
        assertEquals(0,expression("amount / 2",Engine.POSTGRESQL).type().precision());
    }
    @ParameterizedTest @EnumSource(value=Engine.class,names={"MYSQL","MARIADB"}) void exactAndApproximateArithmeticAndUnsignedMode(Engine engine){
        type("1+2*3",engine,Family.INTEGER,engine==Engine.MARIADB?"integer":"bigint");type("9e-4 + 1",engine,Family.REAL,"double");type("1.25 + 2",engine,Family.DECIMAL,"decimal");
        type("'1.25' + 2",engine,Family.REAL,"double");type("1 / 2",engine,Family.DECIMAL,"decimal");type("5 DIV 2",engine,Family.INTEGER,engine==Engine.MARIADB?"integer":"bigint");
        var division=expression("amount / 2",engine);assertEquals(0,division.type().precision());assertEquals(0,division.type().scale());
        assertTrue(expression("CAST(1 AS UNSIGNED) - 2",engine).type().unsigned());
        assertFalse(expression("CAST(1 AS UNSIGNED) - 2",engine,LexicalSettings.mysql("NO_UNSIGNED_SUBTRACTION"),Map.of()).type().unsigned());
        type("CAST('1' AS SIGNED INTEGER)",engine,Family.INTEGER,engine==Engine.MARIADB?"integer":"bigint");
    }
    @ParameterizedTest @EnumSource(value=Engine.class,names={"MYSQL","MARIADB"}) void unsignedDecimalOperatorsFollowNativeSignaturesRatherThanIntegerOrCommonRules(Engine engine){
        for(String sql:List.of("u+u","u-u","u*u","u/u","u%s","u DIV s")){
            var result=expression(sql,engine);assertTrue(result.type().unsigned(),sql);assertTrue(result.issues().isEmpty(),()->sql+": "+result.issues());
        }
        for(String sql:List.of("u+s","u-s","s-u","u*s","u/s","s%u","-u","sum(u)","avg(u)"))assertFalse(expression(sql,engine).type().unsigned(),sql);
        assertTrue(expression("abs(u)",engine).type().unsigned());assertTrue(expression("nullif(u,s)",engine).type().unsigned());
        for(String sql:List.of("u/u","u%u","u DIV u"))assertTrue(expression(sql,engine).type().nullable(),sql);
        assertFalse(expression("u-u",engine,LexicalSettings.mysql("NO_UNSIGNED_SUBTRACTION"),Map.of()).type().unsigned());
        var division=expression("u DIV s",engine);assertEquals(engine==Engine.MARIADB?32:64,division.type().integerBits());
    }
    @ParameterizedTest @EnumSource(value=Engine.class,names={"MYSQL","MARIADB"}) void decimalCommonResultsDistinguishEnginesAndExplicitNullFromAbsentElse(Engine engine){
        for(String sql:List.of("CASE WHEN 1 THEN u ELSE u END","CASE WHEN 1 THEN u ELSE v END","coalesce(u,u)","coalesce(u,v)")){
            var result=expression(sql,engine);assertEquals(engine==Engine.MARIADB,result.type().unsigned(),sql);assertFalse(result.type().nullable(),sql);assertTrue(result.issues().isEmpty(),()->result.issues().toString());
        }
        for(String sql:List.of("CASE WHEN 1 THEN u ELSE s END","CASE WHEN 1 THEN u ELSE NULL END","coalesce(u,NULL)","coalesce(NULL,u)"))assertFalse(expression(sql,engine).type().unsigned(),sql);
        var omitted=expression("CASE WHEN 1 THEN u END",engine).type();assertEquals(engine==Engine.MARIADB,omitted.unsigned());assertTrue(omitted.nullable());
        assertFalse(expression("coalesce(u,NULL)",engine).type().nullable());assertFalse(expression("coalesce(NULL,u)",engine).type().nullable());
        assertTrue(expression("coalesce(NULL,NULL)",engine).type().nullable());
    }
    @Test void standardAndPostgresCastsPreserveNativeTypeDetails(){
        type("CAST(id + 1 AS numeric(18, 4))",Engine.POSTGRESQL,Family.DECIMAL,"numeric(18, 4)");
        var decimal=expression("CAST(id AS numeric(18, 4))",Engine.POSTGRESQL).type();assertEquals(18,decimal.precision());assertEquals(4,decimal.scale());
        type("(id + 1)::numeric(20, 6)",Engine.POSTGRESQL,Family.DECIMAL,"numeric(20, 6)");
        assertTrue(expression("CAST('2026-01-01' AS timestamp with time zone)",Engine.POSTGRESQL).type().timezone());
        assertEquals(Family.UNKNOWN,expression("CAST(id AS absent_type)",Engine.POSTGRESQL).type().family());
        assertTrue(expression("CAST(id AS absent_type)",Engine.POSTGRESQL).issues().stream().allMatch(LanguageIssue::incomplete));
    }
    @ParameterizedTest @EnumSource(value=Engine.class,names={"POSTGRESQL","MYSQL","MARIADB"}) void caseAndCoalesceCarryBranchTypes(Engine engine){
        assertEquals(Family.DECIMAL,expression("CASE WHEN flag THEN amount ELSE 1 END",engine).type().family());
        assertEquals(Family.DECIMAL,expression("CASE id WHEN 1 THEN amount WHEN 2 THEN 4.5 ELSE 0 END",engine).type().family());
        assertEquals(Family.DECIMAL,expression("coalesce(NULL, amount, 1)",engine).type().family());
        assertEquals(Family.TEXT,expression("CASE WHEN flag THEN 'a' ELSE 'b' END",engine).type().family());
        Family truth=engine==Engine.POSTGRESQL?Family.BOOLEAN:Family.INTEGER;
        assertEquals(truth,expression("(id+1 > 4) AND flag",engine).type().family());
        assertEquals(truth,expression("id BETWEEN 1 AND 10",engine).type().family());
        assertEquals(truth,expression("id IN (1, 2, 3)",engine).type().family());
    }
    @Test void incompatibleCoreExpressionsHaveExactSpansAndDoNotFabricateTypes(){
        for(String source:List.of("name + 1","flag * id","CASE WHEN flag THEN 1 ELSE FALSE END","amount % CAST(1 AS real)"))assertFalse(expression(source,Engine.POSTGRESQL).issues().isEmpty(),source);
        assertTrue(expression("id AND flag",Engine.POSTGRESQL).issues().stream().anyMatch(i->i.code().equals("type.invalid-boolean")));
        assertTrue(expression("CASE WHEN id THEN 1 ELSE 2 END",Engine.POSTGRESQL).issues().stream().anyMatch(i->i.code().equals("type.invalid-case-condition")));
        String source="CAST('😀' AS text) + 1";var issue=expression(source,Engine.POSTGRESQL).issues().getFirst();assertEquals(7,issue.start());assertEquals(7+source.length(),issue.end());assertFalse(issue.incomplete());
    }
    @Test void unavailableReferencesRemainUnavailableAcrossOperatorsCaseAndCalls(){
        for(String source:List.of("missing + 1","CASE WHEN flag THEN missing ELSE 1 END","abs(missing)","missing = TRUE")){
            var result=expression(source,Engine.POSTGRESQL);assertEquals(Family.UNKNOWN,result.type().family(),source);assertFalse(result.complete());assertEquals(1,result.issues().size());assertTrue(result.issues().getFirst().incomplete());
            assertFalse(result.issues().stream().anyMatch(i->i.code().equals("routine.no-matching-overload")));
        }
    }
    @Test void overloadsUseExactArgumentsImplicitDirectionsDefaultsAndVariadics(){
        var overloads=Map.of("f",List.of(signature("int","integer","date"),signature("wide","bigint","timestamp"),signature("text","text","text")));
        assertEquals(Family.DATE,expression("f(1+2)",Engine.POSTGRESQL,LexicalSettings.DEFAULT,overloads).type().family());
        assertEquals(Family.TIMESTAMP,expression("f(id)",Engine.POSTGRESQL,LexicalSettings.DEFAULT,overloads).type().family());
        assertEquals(Family.TEXT,expression("f('a')",Engine.POSTGRESQL,LexicalSettings.DEFAULT,overloads).type().family());
        var invalid=expression("f(TRUE)",Engine.POSTGRESQL,LexicalSettings.DEFAULT,overloads);assertTrue(invalid.issues().stream().anyMatch(i->i.code().equals("routine.no-matching-overload")));
        var narrowed=Map.of("f",List.of(signature("integer-only","integer","date")));assertTrue(expression("f(id)",Engine.POSTGRESQL,LexicalSettings.DEFAULT,narrowed).issues().stream().anyMatch(i->i.code().equals("routine.no-matching-overload")));
        var ambiguous=Map.of("f",List.of(signature("big","bigint","date"),signature("numeric","numeric","timestamp")));assertTrue(expression("f(1)",Engine.POSTGRESQL,LexicalSettings.DEFAULT,ambiguous).issues().stream().anyMatch(i->i.code().equals("routine.ambiguous-overload")));
        var variadic=new Signature("variadic","f","db","public","f(integer[])",List.of(new Parameter("items","IN",SqlTypes.nativeType("integer[]",Engine.POSTGRESQL),false,true,"")),SqlTypes.nativeType("integer",Engine.POSTGRESQL),true);
        assertEquals(Family.INTEGER,expression("f(1,2,3)",Engine.POSTGRESQL,LexicalSettings.DEFAULT,Map.of("f",List.of(variadic))).type().family());
        var defaulted=new Signature("defaulted","f","db","public","f(integer, integer DEFAULT 0)",List.of(new Parameter("value","IN",SqlTypes.nativeType("integer",Engine.POSTGRESQL),false,false,""),new Parameter("extra","IN",SqlTypes.nativeType("integer",Engine.POSTGRESQL),true,false,"0")),SqlTypes.nativeType("date",Engine.POSTGRESQL),true);
        assertEquals(Family.DATE,expression("f(1)",Engine.POSTGRESQL,LexicalSettings.DEFAULT,Map.of("f",List.of(defaulted))).type().family());
    }
    @Test void partialSignaturesCannotSelectKnownReturnTypes(){
        var original=signature("partial","integer","date");var partial=new Signature(original.identity(),original.name(),original.catalog(),original.schema(),original.display(),original.parameters(),original.returns(),false);
        var result=expression("f(1)",Engine.POSTGRESQL,LexicalSettings.DEFAULT,Map.of("f",List.of(partial)));assertEquals(Family.UNKNOWN,result.type().family());assertTrue(result.issues().getFirst().incomplete());
    }
    @Test void aggregateAndPolymorphicBuiltinResultsDependOnArguments(){
        type("abs(1 + 2)",Engine.POSTGRESQL,Family.INTEGER,"integer");type("sum(id)",Engine.POSTGRESQL,Family.DECIMAL,"numeric");type("sum(CAST(1 AS integer))",Engine.POSTGRESQL,Family.INTEGER,"bigint");
        type("avg(id)",Engine.POSTGRESQL,Family.DECIMAL,"numeric");type("avg(CAST(1 AS real))",Engine.POSTGRESQL,Family.REAL,"double precision");
        type("nullif(1, 2.2)",Engine.POSTGRESQL,Family.DECIMAL,"numeric");type("count(*)",Engine.POSTGRESQL,Family.INTEGER,"bigint");assertFalse(expression("count(*)",Engine.POSTGRESQL).type().nullable());
        type("date_trunc('day', CAST('2026-01-01' AS timestamptz))",Engine.POSTGRESQL,Family.TIMESTAMP,"timestamptz");
        type("sum(id) OVER (PARTITION BY name ORDER BY amount DESC)",Engine.POSTGRESQL,Family.DECIMAL,"numeric");
        type("sum(id) FILTER (WHERE flag)",Engine.POSTGRESQL,Family.DECIMAL,"numeric");
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB)){type("sum(id)",engine,Family.DECIMAL,"decimal");type("avg(CAST(1 AS double))",engine,Family.REAL,"double");}
    }
    @Test void postgresNullIfUsesTheSelectedEqualityLeftOperand(){
        type("nullif(1,CAST(2 AS bigint))",Engine.POSTGRESQL,Family.INTEGER,"integer");
        type("nullif(CAST(1 AS smallint),CAST(2 AS bigint))",Engine.POSTGRESQL,Family.INTEGER,"smallint");
        type("nullif(CAST(1 AS bigint),CAST(2 AS smallint))",Engine.POSTGRESQL,Family.INTEGER,"bigint");
        type("nullif(1,CAST(2 AS real))",Engine.POSTGRESQL,Family.REAL,"double precision");
        type("nullif(CAST(1 AS real),2)",Engine.POSTGRESQL,Family.REAL,"real");
        type("nullif(CAST(1 AS real),CAST(2 AS double precision))",Engine.POSTGRESQL,Family.REAL,"real");
        type("nullif(CAST(1 AS double precision),CAST(2 AS real))",Engine.POSTGRESQL,Family.REAL,"double precision");
        type("nullif(NULL,CAST(2 AS real))",Engine.POSTGRESQL,Family.REAL,"real");
        type("nullif(NULL,NULL)",Engine.POSTGRESQL,Family.TEXT,"text");
        type("nullif(CAST('a' AS varchar(10)),CAST('b' AS varchar(20)))",Engine.POSTGRESQL,Family.TEXT,"text");
        var numeric=expression("nullif(CAST(1 AS numeric(10,2)),2)",Engine.POSTGRESQL);assertEquals(10,numeric.type().precision());assertEquals(2,numeric.type().scale());assertTrue(numeric.issues().isEmpty(),()->numeric.issues().toString());
        var character=expression("nullif(CAST('a' AS char(10)),CAST('b' AS char(20)))",Engine.POSTGRESQL);assertTrue(SqlTypes.sameNative(SqlTypes.nativeType("char",Engine.POSTGRESQL),character.type(),Engine.POSTGRESQL));assertEquals(10,character.type().precision());assertTrue(character.issues().isEmpty(),()->character.issues().toString());
        var overloads=Map.of("f",List.of(signature("int","integer","date"),signature("wide","bigint","timestamp")));
        assertEquals(Family.DATE,expression("f(nullif(1,CAST(2 AS bigint)))",Engine.POSTGRESQL,LexicalSettings.DEFAULT,overloads).type().family());
        for(String sql:List.of("nullif(domain_value,1)","nullif(custom_value,custom_value)")){
            var unavailable=expression(sql,Engine.POSTGRESQL);assertEquals(Family.UNKNOWN,unavailable.type().family(),sql);assertFalse(unavailable.complete());assertTrue(unavailable.issues().stream().anyMatch(LanguageIssue::incomplete),sql);
        }
    }
    @Test void postgresCommonTypesRetainNativeKindWhenOnlyTypmodsDiffer(){
        String[][] cases={{"varchar(10)","varchar(20)","'a'","varchar"},{"char(10)","char(20)","'a'","char"},{"numeric(10,2)","numeric(12,3)","1","numeric"},{"time(2)","time(4)","'12:00:00'","time"},{"timestamp(2) with time zone","timestamp(4) with time zone","'2026-01-01 00:00:00+00'","timestamp with time zone"}};
        for(var entry:cases){
            String left="CAST("+entry[2]+" AS "+entry[0]+")",right="CAST("+entry[2]+" AS "+entry[1]+")";
            for(String sql:List.of("CASE WHEN flag THEN "+left+" ELSE "+right+" END","coalesce("+left+","+right+")")){
                var result=expression(sql,Engine.POSTGRESQL);assertTrue(SqlTypes.sameNative(SqlTypes.nativeType(entry[3],Engine.POSTGRESQL),result.type(),Engine.POSTGRESQL),sql);assertEquals(0,result.type().precision(),sql);assertEquals(0,result.type().scale(),sql);assertTrue(result.issues().isEmpty(),()->sql+": "+result.issues());
            }
            for(String sql:List.of("CASE WHEN flag THEN "+left+" ELSE "+left+" END","coalesce("+left+","+left+")")){
                var result=expression(sql,Engine.POSTGRESQL);var declared=SqlTypes.nativeType(entry[0],Engine.POSTGRESQL);assertTrue(SqlTypes.sameNative(declared,result.type(),Engine.POSTGRESQL),sql);assertEquals(declared.precision(),result.type().precision(),sql);assertEquals(declared.scale(),result.type().scale(),sql);assertTrue(result.issues().isEmpty(),()->sql+": "+result.issues());
            }
        }
        for(String sql:List.of("CASE WHEN flag THEN CAST('a' AS varchar(10)) END","coalesce(CAST('a' AS varchar(10)),NULL)","coalesce(CAST('a' AS varchar(10)),'b')")){
            var result=expression(sql,Engine.POSTGRESQL);assertTrue(SqlTypes.sameNative(SqlTypes.nativeType("varchar",Engine.POSTGRESQL),result.type(),Engine.POSTGRESQL));assertEquals(0,result.type().precision(),sql);assertTrue(result.issues().isEmpty(),()->result.issues().toString());
        }
        var overloads=Map.of("f",List.of(signature("varchar","varchar","date"),signature("text","text","timestamp")));
        for(String sql:List.of("f(CASE WHEN flag THEN CAST('a' AS varchar(10)) ELSE CAST('b' AS varchar(20)) END)","f(coalesce(CAST('a' AS varchar(10)),CAST('b' AS varchar(20))))"))assertEquals(Family.DATE,expression(sql,Engine.POSTGRESQL,LexicalSettings.DEFAULT,overloads).type().family(),sql);
    }
    @Test void aSameNameUserRoutineNeverAcquiresBuiltinPolymorphism(){
        var custom=new Signature("metadata:abs","abs","db","public","abs(integer)",List.of(new Parameter("n","IN",SqlTypes.nativeType("integer",Engine.POSTGRESQL),false,false,"")),SqlTypes.nativeType("date",Engine.POSTGRESQL),true);
        assertEquals(Family.DATE,expression("abs(1)",Engine.POSTGRESQL,LexicalSettings.DEFAULT,Map.of("abs",List.of(custom))).type().family());
    }
    @Test void postgresTemporalArrayAndJsonOperatorsRetainNativeFamilies(){
        type("DATE '2026-01-01' + 1",Engine.POSTGRESQL,Family.DATE,"date");type("DATE '2026-01-02' - DATE '2026-01-01'",Engine.POSTGRESQL,Family.INTEGER,"integer");
        type("ARRAY[1,2,3][1]",Engine.POSTGRESQL,Family.INTEGER,"integer");
        type("CAST('{}' AS jsonb)->'field'",Engine.POSTGRESQL,Family.JSONB,"jsonb");type("CAST('{}' AS jsonb)->>'field'",Engine.POSTGRESQL,Family.TEXT,"text");
    }
    @ParameterizedTest @EnumSource(value=Engine.class,names={"MYSQL","MARIADB"}) void activeModesChangeGrammarAndRetainUnknownServerModes(Engine engine){
        var settings=LexicalSettings.mysql(" HIGH_NOT_PRECEDENCE,PIPES_AS_CONCAT,REAL_AS_FLOAT,NO_UNSIGNED_SUBTRACTION,STRICT_TRANS_TABLES,PIPES_AS_CONCAT ");
        assertEquals("HIGH_NOT_PRECEDENCE,NO_UNSIGNED_SUBTRACTION,PIPES_AS_CONCAT,REAL_AS_FLOAT,STRICT_TRANS_TABLES",settings.sqlMode());assertTrue(settings.realAsFloat());
        assertEquals(engine==Engine.MYSQL?"bigint":"integer",expression("1||0",engine).type().nativeName());assertEquals(Family.TEXT,expression("1||0",engine,settings,Map.of()).type().family());
        assertInstanceOf(ExpressionSyntax.Unary.class,expression("NOT id BETWEEN 1 AND 2",engine).syntax());
        var high=expression("NOT id BETWEEN 1 AND 2",engine,settings,Map.of()).syntax();assertInstanceOf(ExpressionSyntax.Predicate.class,high);assertInstanceOf(ExpressionSyntax.Unary.class,((ExpressionSyntax.Predicate)high).values().getFirst());
        assertEquals("float",expression("CAST(1 AS REAL)",engine,settings,Map.of()).type().nativeName());
    }
    @Test void malformedAndUnsupportedRegionsHaveOneControlledAvailabilityDiagnostic(){
        for(String source:List.of("1 +","CASE WHEN flag THEN 1","id OPERATOR(public.custom) 1")){
            var result=expression(source,Engine.POSTGRESQL);assertEquals(Family.UNKNOWN,result.type().family(),source);assertEquals(1,result.issues().size(),source);assertTrue(result.issues().getFirst().incomplete(),source);
        }
    }
    @Test void longFlatExpressionsAndCancellationRemainBounded(){
        String sql="1"+"+1".repeat(2000);assertEquals(Family.INTEGER,expression(sql,Engine.POSTGRESQL).type().family());
        var budget=new AnalysisBudget(1500,()->true);assertThrows(CancellationException.class,()->ExpressionParser.parse(new Dialect(Engine.POSTGRESQL,LexicalSettings.DEFAULT),budget,List.of()));
        assertThrows(AnalysisBudget.Limit.class,()->expression("NOT ".repeat(70)+"TRUE",Engine.POSTGRESQL));
    }
    @Test void binderAndDerivedOutputUseCapturedCentralMetadataTypes(){
        var objects=List.of(SchemaObject.newBuilder().setKind(ObjectKind.TABLE).setCatalog("db").setSchema("public").setName("t").build(),
            SchemaObject.newBuilder().setKind(ObjectKind.COLUMN).setCatalog("db").setSchema("public").setTable("t").setName("id").putProperties("nativeType","bigint").build(),
            SchemaObject.newBuilder().setKind(ObjectKind.COLUMN).setCatalog("db").setSchema("public").setTable("t").setName("amount").putProperties("nativeType","numeric(30,9)").build(),
            SchemaObject.newBuilder().setKind(ObjectKind.COLUMN).setCatalog("db").setSchema("public").setTable("t").setName("flag").putProperties("nativeType","boolean").build());
        var context=SemanticFixtures.context(Engine.POSTGRESQL,objects,new ResolutionContext("db","public",List.of("public"),true,7,3));
        var document=new SemanticDocument("SELECT d.total FROM (SELECT CASE WHEN flag THEN amount + id ELSE 0 END AS total FROM t) d",Engine.POSTGRESQL);
        var binder=document.bind(context);assertEquals(Family.DECIMAL,binder.type(document.syntax().queries().getFirst(),document.syntax().queries().getFirst().projections().getFirst().expression()).family());
        assertTrue(binder.diagnostics().isEmpty(),()->binder.diagnostics().toString());
        var unresolved=new SemanticDocument("SELECT missing + 1 FROM t",Engine.POSTGRESQL).bind(context).diagnostics();
        assertTrue(unresolved.stream().anyMatch(i->i.code().equals("binding.unresolved-column")));assertFalse(unresolved.stream().anyMatch(LanguageIssue::incomplete));
        var partial=SemanticFixtures.context(Engine.POSTGRESQL,objects.stream().map(o->o.toBuilder().setMetadataState("STALE").build()).toList(),new ResolutionContext("db","public",List.of("public"),false,7,3));
        var unavailable=new SemanticDocument("SELECT amount + 1 FROM t",Engine.POSTGRESQL).bind(partial).diagnostics();assertTrue(unavailable.stream().anyMatch(LanguageIssue::incomplete));assertFalse(unavailable.stream().anyMatch(i->i.code().equals("binding.unresolved-column")));
    }
    @Test void liveContextPreservesEveryCapturedModeFlagAndUnknownModeName(){
        String modes="ANSI_QUOTES,IGNORE_SPACE,PIPES_AS_CONCAT,HIGH_NOT_PRECEDENCE,NO_UNSIGNED_SUBTRACTION,REAL_AS_FLOAT,STRICT_TRANS_TABLES";
        var context=new io.busystack.busydata.adapters.JdbcAdapter.LiveContext("db","db",List.of("db"),"",modes,true);var lexical=context.lexical();
        assertTrue(lexical.ansiQuotes());assertTrue(lexical.ignoreSpace());assertTrue(lexical.pipesAsConcat());assertTrue(lexical.highNotPrecedence());assertTrue(lexical.noUnsignedSubtraction());assertTrue(lexical.realAsFloat());assertEquals(LexicalSettings.mysql(modes),lexical);
    }
    @ParameterizedTest @EnumSource(value=Engine.class,names={"POSTGRESQL","MYSQL","MARIADB"}) void unknownRoutineSpansOnlyTheExactCallee(Engine engine){
        String expression="known.missing(1)";var unknown=expression(expression,engine).issues().stream().filter(issue->issue.code().equals("routine.unknown")).findFirst().orElseThrow();
        assertEquals("known.missing",("SELECT "+expression).substring(unknown.start(),unknown.end()));
        String counted="abs(1,2)";var arity=expression(counted,engine).issues().stream().filter(issue->issue.code().equals("routine.argument-count")).findFirst().orElseThrow();assertEquals(counted,("SELECT "+counted).substring(arity.start(),arity.end()));
    }
}
