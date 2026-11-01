package io.busystack.busydata;

import io.busystack.busydata.analysis.LexicalSettings;
import io.busystack.busydata.analysis.language.*;
import io.busystack.busydata.analysis.language.SyntaxTree.Name;
import io.busystack.busydata.protocol.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import static org.junit.jupiter.api.Assertions.*;

/** Every namespace component survives parsing or the whole reference is rejected.
 * https://www.postgresql.org/docs/17/ddl-schemas.html
 * https://dev.mysql.com/doc/refman/8.4/en/identifier-qualifiers.html
 * https://mariadb.com/docs/server/reference/sql-structure/sql-language-structure/identifier-qualifiers.md
 */
class QualifiedObjectNameTest {
    private static ResolutionContext context(Engine engine){
        String schema=engine==Engine.POSTGRESQL?"public":"db";
        var objects=List.of(SchemaObject.newBuilder().setKind(ObjectKind.TABLE).setCatalog("db").setSchema(schema).setName("customers").build(),
            SchemaObject.newBuilder().setKind(ObjectKind.COLUMN).setCatalog("db").setSchema(schema).setTable("customers").setName("id").putProperties("nativeType","bigint").build(),
            SchemaObject.newBuilder().setKind(ObjectKind.ROUTINE).setCatalog("db").setSchema(schema).setName("f").setIdentifier("f()").putProperties("parameterCount","0").putProperties("signature","f()").putProperties("returnType","bigint").build());
        return SemanticFixtures.context(engine,objects,new ResolutionContext("db",schema,List.of(schema),true,7,3));
    }
    private static Name name(String source,Engine engine){
        var tokens=LosslessLexer.scan(source,new Dialect(engine,LexicalSettings.DEFAULT),AnalysisBudget.interactive()).significant();
        return new Name(tokens.stream().filter(LosslessLexer.Token::name).toList());
    }
    private static String valid(Engine engine){return engine==Engine.POSTGRESQL?"db.public.customers":"db.customers";}
    private static String invalid(Engine engine){return engine==Engine.POSTGRESQL?"db.forged.public.customers":"db.db.customers";}
    private static SemanticDocument.SymbolReference symbol(String marked,Engine engine,ResolutionContext context){int caret=marked.indexOf('|');return new SemanticDocument(marked.replace("|",""),engine).referenceAt(caret,context);}
    @ParameterizedTest @EnumSource(value=Engine.class,names={"POSTGRESQL","MYSQL","MARIADB"})
    void objectMappingPreservesExactlyThePermittedNativeComponents(Engine engine){
        var captured=context(engine);String source=valid(engine);var reference=symbol("SELECT * FROM "+source+"|",engine,captured);
        assertNotNull(reference);assertEquals(engine==Engine.POSTGRESQL?3:2,reference.name().parts().size());
        assertEquals(engine==Engine.POSTGRESQL?new SemanticDocument.TableReference("db","public","customers"):new SemanticDocument.TableReference("","db","customers"),reference.table());
        var document=new SemanticDocument("SELECT "+source+".id FROM "+source,engine);var binder=document.bind(captured);var query=document.syntax().queries().getFirst();
        assertEquals(SqlTypes.Family.INTEGER,binder.type(query,query.projections().getFirst().expression()).family(),"A valid column adds one component to the valid relation name");
    }
    @ParameterizedTest @EnumSource(value=Engine.class,names={"POSTGRESQL","MYSQL","MARIADB"})
    void forgedPrefixesAreRejectedForEveryObjectComponentAndAlias(Engine engine){
        var captured=context(engine);String source=invalid(engine);
        for(int offset:new int[]{0,source.indexOf('.')+1,source.lastIndexOf('.')+1,source.length()}){
            String marked="SELECT * FROM "+source.substring(0,offset)+"|"+source.substring(offset);
            assertNull(symbol(marked,engine,captured),marked);
        }
        assertNull(symbol("SELECT x|.id FROM "+source+" x",engine,captured));
        assertTrue(new SemanticDocument("SELECT * FROM "+source,engine).references().isEmpty());
        var result=SymbolService.resolve(AnalysisRequest.newBuilder().setEngine(engine).setSql("SELECT * FROM "+source).setCaretUtf16(14+source.length()).build(),"profile",LexicalSettings.DEFAULT,captured,()->false);
        assertEquals(0,result.getCandidatesCount());assertNotEquals("exact",result.getAvailability());
    }
    @ParameterizedTest @EnumSource(value=Engine.class,names={"POSTGRESQL","MYSQL","MARIADB"})
    void catalogEntryPointsRejectIgnoredMiddleComponentsAndIncompleteNames(Engine engine){
        var captured=context(engine);var catalog=new SemanticCatalog(new Dialect(engine,LexicalSettings.DEFAULT),captured,AnalysisBudget.interactive());
        var accepted=catalog.resolve(name(valid(engine),engine));assertEquals(1,accepted.size());
        for(Name forged:List.of(name(invalid(engine),engine),name("extra.".repeat(1000)+valid(engine),engine),new Name(List.of()))){
            assertTrue(catalog.resolve(forged).isEmpty());assertTrue(catalog.resolveSymbols(forged).objects().isEmpty());assertFalse(catalog.namespaceComplete(forged));assertFalse(catalog.lookupComplete(forged,accepted.getFirst()));
        }
        String routine=engine==Engine.POSTGRESQL?"db.public.f":"db.f",forged=engine==Engine.POSTGRESQL?"db.forged.public.f":"db.db.f";
        assertEquals(1,catalog.routines(name(routine,engine)).size());assertTrue(catalog.routines(name(forged,engine)).isEmpty());assertFalse(catalog.routineNamespaceComplete(name(forged,engine)));
    }
    @ParameterizedTest @EnumSource(value=Engine.class,names={"POSTGRESQL","MYSQL","MARIADB"})
    void aliasNavigationDoesNotDiscardAnExpressionQualifier(Engine engine){
        var captured=context(engine);String source=valid(engine);
        assertNull(symbol("SELECT forged.x|.id FROM "+source+" x",engine,captured));
        assertNull(symbol("SELECT x|.forged.id FROM "+source+" x",engine,captured));
        assertNull(symbol("SELECT x|..id FROM "+source+" x",engine,captured));
        assertNull(symbol("SELECT * FROM "+source+"|.",engine,captured));
        assertNotNull(symbol("SELECT x|.id FROM "+source+" x",engine,captured));
    }
    @Test void quotedDotsStayInsideOneComponentAndCrossDatabasePostgresIsRejected(){
        var captured=context(Engine.POSTGRESQL);var reference=symbol("SELECT * FROM db.\"odd.schema\".\"odd.table|\"",Engine.POSTGRESQL,captured);
        assertNotNull(reference);assertEquals(new SemanticDocument.TableReference("db","odd.schema","odd.table"),reference.table());assertEquals(3,reference.name().parts().size());
        var catalog=new SemanticCatalog(new Dialect(Engine.POSTGRESQL,LexicalSettings.DEFAULT),captured,AnalysisBudget.interactive());
        assertTrue(catalog.resolve(name("other.public.customers",Engine.POSTGRESQL)).isEmpty());assertFalse(catalog.namespaceComplete(name("other.public.customers",Engine.POSTGRESQL)));
        var request=AnalysisRequest.newBuilder().setEngine(Engine.POSTGRESQL).setSql("SELECT * FROM other.public.customers").setCaretUtf16(33).build();
        assertEquals("unsupported-qualification",SymbolService.resolve(request,"profile",LexicalSettings.DEFAULT,captured,()->false).getAvailability());
    }
}
