package io.busystack.busydata;

import io.busystack.busydata.analysis.language.*;
import io.busystack.busydata.analysis.language.SqlTypes.*;
import io.busystack.busydata.metadata.IntrospectionLevel;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.results.Values;
import io.busystack.busydata.schema.Explorer;
import io.busystack.busydata.sessions.SessionRegistry;
import java.lang.reflect.Proxy;
import java.nio.file.Path;
import java.sql.Connection;
import java.util.*;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

/** Native result metadata is the independent oracle, not the inferred descriptors.
 * PostgreSQL17: functions-math.html, typeconv-union-case.html, typeconv-func.html.
 * MySQL8.4: arithmetic-functions.html, flow-control-functions.html, with.html.
 * MariaDB11.8: CAST/CASE/NULLIF and recursive-CTE official reference pages.
 * EngineFixture supplies exactly the repository's pinned releases and drivers. */
class ExpressionTypingIT {
    @TempDir Path root;
    private record Probe(String name,String sql) {}
    private record Inference(List<SemanticBinder.ColumnSymbol> columns,List<LanguageIssue> diagnostics) {}
    private static final Set<String> JDBC_METHODS=Set.of("prepareStatement","prepareCall","createStatement","getMetaData");

    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void coreTypesAndQueryOutputsMatchRetainedNativeMetadataWithoutAnalysisJdbc(String engine)throws Exception {
        var jdbc=new AtomicInteger();Thread owner=Thread.currentThread();
        try(var fixture=fixture(engine,jdbc,owner)){
            var session=fixture.open();fixture.introspectionLevel(session,IntrospectionLevel.STRUCTURE);
            String table=session.adapter.table(session.context.catalog(),fixture.schema(),"expression_input");
            fixture.execute(session,"CREATE TABLE "+table+"(id INTEGER NOT NULL,amount DECIMAL(18,4),flag BOOLEAN,wide BIGINT NOT NULL,short_text VARCHAR(10),long_text VARCHAR(20)); INSERT INTO "+table+" VALUES(2,12.3400,TRUE,3,'a','a')");
            String routine=session.adapter.table(session.context.catalog(),fixture.schema(),"expression_return");
            fixture.execute(session,fixture.engine==Engine.POSTGRESQL?
                "CREATE FUNCTION "+routine+"(amount numeric) RETURNS numeric LANGUAGE sql AS 'SELECT amount'; CREATE FUNCTION "+routine+"(amount integer) RETURNS bigint LANGUAGE sql AS 'SELECT amount::bigint'; CREATE FUNCTION "+routine+"(value varchar) RETURNS date LANGUAGE sql AS 'SELECT CURRENT_DATE'; CREATE FUNCTION "+routine+"(value text) RETURNS timestamp LANGUAGE sql AS 'SELECT LOCALTIMESTAMP'":
                "CREATE FUNCTION "+routine+"(amount DECIMAL(18,4)) RETURNS DECIMAL(18,4) DETERMINISTIC RETURN amount");
            var context=capture(fixture,session);String source=" FROM "+table+" t";
            var probes=new ArrayList<Probe>(List.of(
                new Probe("literal arithmetic","SELECT 1+2 AS value"),
                new Probe("bound arithmetic","SELECT t.id+2*3 AS value"+source),
                new Probe("mixed integer widths","SELECT t.id+t.wide AS value"+source),
                new Probe("exact arithmetic","SELECT t.amount*(t.id+1) AS value"+source),
                new Probe("decimal cast","SELECT CAST(t.id+1 AS DECIMAL(18,4)) AS value"+source),
                new Probe("searched CASE","SELECT CASE WHEN t.id>1 THEN t.amount+t.wide ELSE 0 END AS value"+source),
                new Probe("simple CASE","SELECT CASE t.id WHEN 2 THEN t.amount ELSE 0 END AS value"+source),
                new Probe("Boolean arithmetic predicate","SELECT (t.id+1>2) AND t.flag AS value"+source),
                new Probe("Boolean IN predicate","SELECT t.id IN(1,2,3) AS value"+source),
                new Probe("Boolean BETWEEN predicate","SELECT t.id BETWEEN 1 AND 3 AS value"+source),
                new Probe("Boolean NULL predicate","SELECT t.amount IS NULL AS value"+source),
                new Probe("COALESCE argument result","SELECT coalesce(NULL,t.amount,1) AS value"+source),
                new Probe("NULLIF first argument result","SELECT nullif(t.amount,0) AS value"+source),
                new Probe("NULLIF mixed integer widths","SELECT nullif(t.id,t.wide) AS value"+source),
                new Probe("CASE same varchar kind different typmods","SELECT CASE WHEN t.flag THEN t.short_text ELSE t.long_text END AS value"+source),
                new Probe("COALESCE same varchar kind different typmods","SELECT coalesce(t.short_text,t.long_text) AS value"+source),
                new Probe("derived CASE varchar result","SELECT d.n AS value FROM(SELECT CASE WHEN t.flag THEN t.short_text ELSE t.long_text END AS n"+source+")d"),
                new Probe("USING same varchar kind different typmods","SELECT k AS value FROM(SELECT short_text AS k FROM "+table+")a JOIN(SELECT long_text AS k FROM "+table+")b USING(k)"),
                new Probe("NULLIF result selects enclosing overload","SELECT "+routine+"(nullif(t.id,t.wide)) AS value"+source),
                new Probe("routine argument-dependent result","SELECT "+routine+"(t.id) AS value"+source),
                new Probe("routine decimal result","SELECT "+routine+"(t.amount) AS value"+source),
                new Probe("derived expression type","SELECT d.total AS value FROM (SELECT t.amount+t.id AS total"+source+") d"),
                new Probe("CTE positional alias type","WITH c(n) AS(SELECT t.amount+t.id"+source+") SELECT n AS value FROM c"),
                new Probe("constant CTE positional type","WITH c(n) AS(SELECT 1+2) SELECT n AS value FROM c"),
                new Probe("recursive anchor type","WITH RECURSIVE r(n) AS(SELECT 1 UNION ALL SELECT n+1 FROM r WHERE n<3) SELECT n AS value FROM r"),
                new Probe("set operation common type","SELECT 1 AS value UNION ALL SELECT 2.5"),
                new Probe("derived set common type","SELECT d.n AS value FROM (SELECT t.id AS n"+source+" UNION ALL SELECT 2.5) d"),
                new Probe("nullable scalar query","SELECT (SELECT 1 WHERE FALSE) AS value")
            ));
            if(fixture.engine==Engine.POSTGRESQL){
                probes.add(new Probe("exponent operator native double","SELECT 2^3 AS value"));
                probes.add(new Probe("exponent literal remains exact numeric","SELECT 1e2 AS value"));
                probes.add(new Probe("PostgreSQL cast operator","SELECT (t.id+1)::numeric(18,4) AS value"+source));
                probes.add(new Probe("NULLIF integer and numeric promotion","SELECT nullif(1,2.2) AS value"));
                probes.add(new Probe("NULLIF integer and real equality promotion","SELECT nullif(1,CAST(2 AS real)) AS value"));
                probes.add(new Probe("NULLIF real and integer equality promotion","SELECT nullif(CAST(1 AS real),2) AS value"));
                probes.add(new Probe("NULLIF exact cross float equality","SELECT nullif(CAST(1 AS real),CAST(2 AS double precision)) AS value"));
                probes.add(new Probe("NULLIF unknown operand exact equality","SELECT nullif(NULL,CAST(2 AS real)) AS value"));
                probes.add(new Probe("NULLIF varchar equality operand","SELECT nullif(CAST('a' AS varchar(10)),CAST('b' AS varchar(20))) AS value"));
                probes.add(new Probe("CASE character different typmods","SELECT CASE WHEN t.flag THEN CAST('a' AS char(10)) ELSE CAST('b' AS char(20)) END AS value"+source));
                probes.add(new Probe("COALESCE numeric different typmods","SELECT coalesce(CAST(t.id AS numeric(10,2)),CAST(t.wide AS numeric(12,3))) AS value"+source));
                probes.add(new Probe("CASE time different typmods","SELECT CASE WHEN t.flag THEN CAST('12:00:00' AS time(2)) ELSE CAST('12:00:00' AS time(4)) END AS value"+source));
                probes.add(new Probe("CASE varchar selects enclosing overload","SELECT "+routine+"(CASE WHEN t.flag THEN t.short_text ELSE t.long_text END) AS value"+source));
                probes.add(new Probe("COALESCE varchar selects enclosing overload","SELECT "+routine+"(coalesce(t.short_text,t.long_text)) AS value"+source));
            }else{
                probes.add(new Probe("integer division","SELECT t.id DIV 2 AS value"+source));
                probes.add(new Probe("decimal division","SELECT t.id/2 AS value"+source));
                probes.add(new Probe("unsigned cast","SELECT CAST(3 AS UNSIGNED) AS value"));
            }
            assertAll(engine+" native expression corpus",probes.stream().map(probe->(org.junit.jupiter.api.function.Executable)()->verify(fixture,session,context,jdbc,probe)));
            if(fixture.engine==Engine.POSTGRESQL){
                String incompatible="SELECT NULL AS n UNION SELECT NULL UNION SELECT 1";
                var inference=infer(fixture,session,context,jdbc,incompatible);
                assertTrue(inference.diagnostics().stream().anyMatch(issue->issue.source().equals("binder")&&issue.code().startsWith("type.")),inference.toString());
            }
        }
    }

    @ParameterizedTest @ValueSource(strings={"MYSQL","MARIADB"})
    void capturedSqlModesControlNativeResultTypesAndPrecedence(String engine)throws Exception {
        var jdbc=new AtomicInteger();Thread owner=Thread.currentThread();
        try(var fixture=fixture(engine,jdbc,owner)){
            var session=fixture.open();fixture.introspectionLevel(session,IntrospectionLevel.STRUCTURE);
            fixture.execute(session,"SET SESSION sql_mode=''");var ordinary=capture(fixture,session);
            assertFalse(session.context.lexical().pipesAsConcat());assertFalse(session.context.lexical().noUnsignedSubtraction());
            verify(fixture,session,ordinary,jdbc,new Probe("default OR pipes","SELECT 1||0 AS value"));
            verify(fixture,session,ordinary,jdbc,new Probe("unsigned subtraction","SELECT CAST(3 AS UNSIGNED)-2 AS value"));
            var low=verify(fixture,session,ordinary,jdbc,new Probe("default NOT precedence","SELECT NOT 1 BETWEEN -5 AND 5 AS value"));assertEquals("0",Values.text(low.getValues(0)));
            fixture.execute(session,"SET SESSION sql_mode='PIPES_AS_CONCAT,HIGH_NOT_PRECEDENCE,NO_UNSIGNED_SUBTRACTION,ANSI_QUOTES'");
            var changed=capture(fixture,session);assertTrue(session.context.lexical().pipesAsConcat());assertTrue(session.context.lexical().highNotPrecedence());assertTrue(session.context.lexical().noUnsignedSubtraction());assertTrue(session.context.lexical().ansiQuotes());
            var concatenated=verify(fixture,session,changed,jdbc,new Probe("captured concatenation mode","SELECT 1||0 AS value"));assertEquals("10",Values.text(concatenated.getValues(0)));
            var signed=verify(fixture,session,changed,jdbc,new Probe("captured signed subtraction mode","SELECT CAST(1 AS UNSIGNED)-2 AS value"));assertEquals("-1",Values.text(signed.getValues(0)));
            var high=verify(fixture,session,changed,jdbc,new Probe("captured high NOT precedence","SELECT NOT 1 BETWEEN -5 AND 5 AS value"));assertEquals("1",Values.text(high.getValues(0)));
            verify(fixture,session,changed,jdbc,new Probe("captured ANSI quoted output","SELECT d.\"number\"+1 AS value FROM (SELECT 2 AS \"number\") d"));
        }
    }

    @ParameterizedTest @ValueSource(strings={"MYSQL","MARIADB"})
    void unsignedDecimalsAndMaterializedFieldsMatchIndependentNativeDescriptors(String engine)throws Exception {
        var jdbc=new AtomicInteger();Thread owner=Thread.currentThread();
        try(var fixture=fixture(engine,jdbc,owner)){
            var session=fixture.open();fixture.introspectionLevel(session,IntrospectionLevel.STRUCTURE);
            String table=session.adapter.table(session.context.catalog(),fixture.schema(),"expression_decimal");
            fixture.execute(session,"CREATE TABLE "+table+"(u DECIMAL(10,2) UNSIGNED NOT NULL,v DECIMAL(12,3) UNSIGNED NOT NULL,s DECIMAL(10,2) NOT NULL); INSERT INTO "+table+" VALUES(12.50,1.125,2.25)");
            for(String mode:List.of("","NO_UNSIGNED_SUBTRACTION")){
                fixture.execute(session,"SET SESSION sql_mode='"+mode+"'");var context=capture(fixture,session);
                var probes=new ArrayList<Probe>();
                for(String expression:List.of("u+u","u+s","u-u","u-s","s-u","u*u","u*s","u/u","u/s","u%s","s%u","u DIV u","s DIV u","sum(u)","avg(u)","abs(u)","-u","CASE WHEN 1 THEN u ELSE u END","CASE WHEN 1 THEN u ELSE v END","CASE WHEN 1 THEN u ELSE s END","CASE WHEN 1 THEN u END","CASE WHEN 1 THEN u ELSE NULL END","coalesce(u,u)","coalesce(u,v)","coalesce(u,NULL)","nullif(u,s)"))
                    probes.add(new Probe("unsigned decimal "+expression+" mode="+mode,"SELECT "+expression+" AS value FROM "+table));
                probes.add(new Probe("unsigned decimal set same typemod","SELECT u AS value FROM "+table+" UNION ALL SELECT u FROM "+table));
                probes.add(new Probe("unsigned decimal set different typemods","SELECT u AS value FROM "+table+" UNION ALL SELECT v FROM "+table));
                probes.add(new Probe("unsigned decimal set mixed signs","SELECT u AS value FROM "+table+" UNION ALL SELECT s FROM "+table));
                probes.add(new Probe("derived native field range","SELECT d.n+1 AS value FROM(SELECT 2 AS n)d"));
                probes.add(new Probe("scalar expression narrow range","SELECT (SELECT 2)+1 AS value"));
                probes.add(new Probe("unary materialization boundary","WITH c(n)AS(SELECT -(1234567+1))SELECT n AS value FROM c"));
                assertAll(engine+" exact decimal and field corpus mode="+mode,probes.stream().map(probe->(org.junit.jupiter.api.function.Executable)()->verify(fixture,session,context,jdbc,probe)));
            }
        }
    }

    private EngineFixture fixture(String engine,AtomicInteger jdbc,Thread owner)throws Exception {
        return new EngineFixture(root,engine,(adapter,request,port)->{
            var connection=adapter.connect(request,port);
            return (Connection)Proxy.newProxyInstance(Connection.class.getClassLoader(),new Class[]{Connection.class},(proxy,method,args)->{
                if(Thread.currentThread()==owner&&JDBC_METHODS.contains(method.getName()))jdbc.incrementAndGet();
                try{return method.invoke(connection,args);}catch(java.lang.reflect.InvocationTargetException error){throw error.getCause();}
            });
        });
    }
    private static ResolutionContext capture(EngineFixture fixture,SessionRegistry.Session session)throws Exception {
        var explorer=new Explorer(fixture.metadata);explorer.refreshContext(session);var snapshot=explorer.metadata().capture(session);
        return new ResolutionContext(session.context.catalog(),session.context.schema(),session.context.searchPath(),true,snapshot.revision(),snapshot.configurationRevision(),snapshot.rules(),snapshot,session.context.temporarySchema());
    }
    private static Inference infer(EngineFixture fixture,SessionRegistry.Session session,ResolutionContext context,AtomicInteger jdbc,String sql){
        jdbc.set(0);var budget=new AnalysisBudget(1500,()->false);var document=new SemanticDocument(sql,fixture.engine,session.context.lexical(),budget);var binder=document.bind(context);
        var columns=binder.project(document.syntax().queries().getFirst());var diagnostics=binder.diagnostics();
        assertEquals(0,jdbc.get(),"Analysis must read only the captured immutable metadata snapshot");return new Inference(columns,diagnostics);
    }
    private static Row verify(EngineFixture fixture,SessionRegistry.Session session,ResolutionContext context,AtomicInteger jdbc,Probe probe)throws Exception {
        var inference=infer(fixture,session,context,jdbc,probe.sql());
        assertTrue(inference.diagnostics().stream().noneMatch(issue->issue.severity().equals("error")||issue.incomplete()),()->probe.name()+": "+inference.diagnostics());
        var result=fixture.results.get(fixture.execute(session,probe.sql()).info().getResults(0).getResultId());
        try{
            assertEquals(result.columns.size(),inference.columns().size(),probe.name()+": output shape");
            for(int index=0;index<result.columns.size();index++){
                var nativeColumn=result.columns.get(index);var inferred=inference.columns().get(index);Type actual=nativeType(nativeColumn,fixture.engine);
                String detail=fixture.engine+" "+probe.name()+" SQL="+probe.sql()+" native="+nativeColumn+" inferred="+inferred.type();
                assertAll(detail,()->assertTrue(inferred.type().known(),"Inference is unavailable"),()->assertEquals(nativeColumn.getName(),inferred.name(),"Output name"),
                    ()->assertEquals(actual.family(),inferred.type().family(),"Native family"),()->assertEquals(canonical(actual),canonical(inferred.type()),"Native type"));
                if(actual.numeric())assertEquals(!nativeColumn.getSigned(),inferred.type().unsigned(),detail+": signedness");
                if(inferred.type().precision()>0){assertEquals(nativeColumn.getPrecision(),inferred.type().precision(),detail+": known precision");assertEquals(nativeColumn.getScale(),inferred.type().scale(),detail+": known scale");}
                if(probe.name().equals("nullable scalar query"))assertTrue(inferred.type().nullable(),"A zero-row scalar subquery produces NULL");
            }
            assertTrue(result.rows()>0,probe.name()+": fixture must produce at least one retained row");return result.read(0);
        }finally{fixture.results.dispose(result.id);}
    }
    private static Type nativeType(Column column,Engine engine){
        var metadata=SchemaObject.newBuilder().setKind(ObjectKind.COLUMN).putProperties("nativeType",column.getTypeName()).putProperties("jdbcType",Integer.toString(column.getJdbcType())).putProperties("precision",Integer.toString(column.getPrecision())).putProperties("scale",Integer.toString(column.getScale())).putProperties("nullable",Boolean.toString(column.getNullable()));
        var type=SqlTypes.nativeType(column.getTypeName(),engine);if(type.numeric())metadata.putProperties("unsigned",Boolean.toString(!column.getSigned()));
        return SqlTypes.column(metadata.build(),engine);
    }
    /** Only declared native synonyms are normalized; widths, families and signedness
     * remain distinct and cannot be normalized away to make the oracle pass. */
    private static String canonical(Type type){
        String base=type.nativeName().toLowerCase(Locale.ROOT).replaceAll("\\([^)]*\\)","").replace(" unsigned","").trim().replaceAll("\\s+"," ");
        return switch(base){case "int","int4","integer"->"integer";case "int2","smallint"->"smallint";case "int8","bigint"->"bigint";case "numeric","decimal","dec"->"decimal";case "float4","real"->"real";case "float8","double precision","double"->"double";case "bool","boolean"->"boolean";case "character varying","varchar"->"varchar";case "character","char","bpchar"->"char";default->base;};
    }
}
