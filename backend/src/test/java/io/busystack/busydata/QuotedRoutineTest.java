package io.busystack.busydata;

import io.busystack.busydata.analysis.*;
import io.busystack.busydata.analysis.language.*;
import io.busystack.busydata.protocol.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

/** PostgreSQL17 lexical§4.1.1 preserves quoted case; typeconv-func resolves
 * routine names before selecting input signatures. No JDBC is used here.
 * https://www.postgresql.org/docs/17/sql-syntax-lexical.html#SQL-SYNTAX-IDENTIFIERS
 * https://www.postgresql.org/docs/17/typeconv-func.html */
class QuotedRoutineTest {
    private static final ResolutionContext COMPLETE=new ResolutionContext("db","public",List.of("public"),true,8,2);
    private static Analysis analyze(String sql,AnalysisOperation operation,List<SchemaObject> objects){
        return SemanticFixtures.analyze(new SqlAnalysis(),AnalysisRequest.newBuilder().setEngine(Engine.POSTGRESQL).setDocumentId("quoted-routines").setDocumentVersion(1).setOperation(operation).setSql(sql).setCaretUtf16(sql.length()).build(),objects,LexicalSettings.DEFAULT,COMPLETE);
    }
    private static SchemaObject quotedCustom(){return SchemaObject.newBuilder().setKind(ObjectKind.ROUTINE).setCatalog("db").setSchema("public").setName("ABS").setIdentifier("ABS(integer,integer)").putProperties("signature","ABS(integer,integer)").putProperties("signatureAvailability","AVAILABLE").putProperties("parameterCount","2").putProperties("parameter.0.name","first").putProperties("parameter.0.mode","IN").putProperties("parameter.0.type","integer").putProperties("parameter.0.nativeTypeId","23").putProperties("parameter.1.name","second").putProperties("parameter.1.mode","IN").putProperties("parameter.1.type","integer").putProperties("parameter.1.nativeTypeId","23").putProperties("returnType","integer").build();}

    @Test void quotedUppercaseCannotResolveTheLowercasePostgresBuiltin(){
        for(String name:List.of("ABS","abs","\"abs\"")){
            var parameters=analyze("SELECT "+name+"(",AnalysisOperation.PARAMETER_INFORMATION,List.of()).getParameterInformation();
            assertEquals("available",parameters.getAvailability(),name);assertEquals(1,parameters.getOverloadsCount(),name);assertEquals("abs",parameters.getOverloads(0).getName());assertTrue(parameters.getOverloads(0).getIdentity().startsWith("builtin:"));
        }
        for(String name:List.of("\"ABS\"","\"Abs\"")){
            var parameters=analyze("SELECT "+name+"(",AnalysisOperation.PARAMETER_INFORMATION,List.of()).getParameterInformation();
            assertEquals("unavailable-signature",parameters.getAvailability(),name);assertEquals(0,parameters.getOverloadsCount(),name);
        }
    }

    @Test void quotedCustomRoutineUsesItsExactCentralIdentityAndDoesNotBecomeBuiltinAbs(){
        var objects=List.of(quotedCustom());var context=SemanticFixtures.context(Engine.POSTGRESQL,objects,COMPLETE);
        String identity=context.snapshot().resolve("db","public",ObjectKind.ROUTINE,"","ABS",true).getFirst().identity().key();
        var custom=analyze("SELECT \"ABS\"(1, ",AnalysisOperation.PARAMETER_INFORMATION,objects).getParameterInformation();
        assertEquals("available",custom.getAvailability());assertEquals(1,custom.getOverloadsCount());assertEquals("ABS",custom.getOverloads(0).getName());assertEquals(2,custom.getOverloads(0).getParametersCount());assertEquals(identity,custom.getOverloads(0).getIdentity());assertEquals(1,custom.getActiveArgument());
        for(String name:List.of("ABS","\"abs\"")){
            var builtin=analyze("SELECT "+name+"(",AnalysisOperation.PARAMETER_INFORMATION,objects).getParameterInformation();
            assertEquals(1,builtin.getOverloadsCount(),name);assertEquals("abs",builtin.getOverloads(0).getName());assertTrue(builtin.getOverloads(0).getIdentity().startsWith("builtin:"));
        }
    }

    @Test void uppercaseQuotedCustomCompletionDoesNotHideTheLowercaseBuiltin(){
        var objects=List.of(quotedCustom());var items=analyze("SELECT a",AnalysisOperation.COMPLETION,objects).getCompletionsList();
        assertTrue(items.stream().anyMatch(item->item.getLabel().equals("abs()")&&item.getTargetIdentity().startsWith("builtin:")&&item.getInsertText().equals("abs()")));
        assertTrue(items.stream().anyMatch(item->item.getLabel().equals("ABS()")&&!item.getTargetIdentity().startsWith("builtin:")&&item.getInsertText().equals("public.\"ABS\"()")));
        var uppercase=analyze("SELECT \"A",AnalysisOperation.COMPLETION,objects).getCompletionsList();assertTrue(uppercase.stream().anyMatch(item->item.getLabel().equals("ABS()")));assertFalse(uppercase.stream().anyMatch(item->item.getLabel().equals("abs()")));
        var lowercase=analyze("SELECT \"a",AnalysisOperation.COMPLETION,objects).getCompletionsList();assertTrue(lowercase.stream().anyMatch(item->item.getLabel().equals("abs()")));assertFalse(lowercase.stream().anyMatch(item->item.getLabel().equals("ABS()")));
    }

    @Test void mysqlAndMariaQuotedBuiltinNamesKeepTheirCaseInsensitiveLookup(){
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB)){
            String sql="SELECT `ABS`(";var response=SemanticFixtures.analyze(new SqlAnalysis(),AnalysisRequest.newBuilder().setEngine(engine).setOperation(AnalysisOperation.PARAMETER_INFORMATION).setSql(sql).setCaretUtf16(sql.length()).build(),List.of(),LexicalSettings.DEFAULT,new ResolutionContext("db","db",List.of("db"),true,8,2));
            assertEquals("available",response.getParameterInformation().getAvailability(),engine.name());assertEquals(1,response.getParameterInformation().getOverloadsCount());assertEquals("abs",response.getParameterInformation().getOverloads(0).getName());
        }
    }
}
