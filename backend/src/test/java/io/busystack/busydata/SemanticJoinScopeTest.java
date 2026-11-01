package io.busystack.busydata;

import io.busystack.busydata.analysis.*;
import io.busystack.busydata.analysis.language.*;
import io.busystack.busydata.analysis.language.SyntaxTree.*;
import io.busystack.busydata.protocol.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import static org.junit.jupiter.api.Assertions.*;

class SemanticJoinScopeTest {
    private static final ResolutionContext COMPLETE=new ResolutionContext("db","public",List.of("public"),true,7,3);
    private static SchemaObject table(String name){return SchemaObject.newBuilder().setKind(ObjectKind.TABLE).setCatalog("db").setSchema("public").setName(name).build();}
    private static SchemaObject column(String table,String name,String type,int ordinal){return SchemaObject.newBuilder().setKind(ObjectKind.COLUMN).setCatalog("db").setSchema("public").setTable(table).setName(name).putProperties("nativeType",type).putProperties("ordinal",Integer.toString(ordinal)).putProperties("nullable","false").build();}
    private static final List<SchemaObject> OBJECTS=List.of(table("a"),column("a","id","bigint",1),column("a","left_value","text",2),column("a","tenant","integer",3),table("b"),column("b","tenant","bigint",1),column("b","id","bigint",2),column("b","right_value","text",3),table("c"),column("c","id","bigint",1),column("c","third_value","text",2));
    private static SemanticBinder bind(String sql,Engine engine){return bind(sql,engine,OBJECTS);}
    private static SemanticBinder bind(String sql,Engine engine,List<SchemaObject> objects){
        var budget=new AnalysisBudget(1500,()->false);var dialect=new Dialect(engine,LexicalSettings.DEFAULT);
        var tree=SyntaxParser.parse(LosslessLexer.scan(sql,dialect,budget),budget);
        return new SemanticBinder(tree,new SemanticCatalog(dialect,SemanticFixtures.context(engine,objects,COMPLETE),budget),budget);
    }
    private static LosslessLexer.Token name(String value,Engine engine){return LosslessLexer.scan(value,new Dialect(engine,LexicalSettings.DEFAULT),AnalysisBudget.interactive()).significant().getFirst();}
    private static List<String> names(List<SemanticBinder.ColumnSymbol> columns){return columns.stream().map(SemanticBinder.ColumnSymbol::name).toList();}
    private static Query root(SemanticBinder binder){return binder.tree().queries().getFirst();}
    private static Query inner(SemanticBinder binder){return binder.tree().queries().stream().filter(q->q.parent()!=null&&q.relations().stream().anyMatch(r->r.name()!=null&&r.name().last().is("b"))).findFirst().orElseThrow();}
    private static void noBindingErrors(SemanticBinder binder){assertTrue(binder.diagnostics().stream().noneMatch(issue->issue.code().startsWith("binding.")),()->binder.diagnostics().toString());}

    @ParameterizedTest @EnumSource(value=Engine.class,names={"POSTGRESQL","MYSQL","MARIADB"})
    void usingHasOneUnqualifiedKeyAndPreservesBothQualifiedOperands(Engine engine){
        var binder=bind("SELECT id, a.id, b.id FROM a JOIN b USING (id)",engine);var query=root(binder);
        var merged=binder.lookupColumns(query,null,name("id",engine));assertTrue(merged.complete());assertEquals(1,merged.candidates().size());assertTrue(merged.candidates().getFirst().identity().startsWith("join:"));
        assertEquals("a",binder.columns(query,name("a",engine),name("id",engine)).getFirst().object().getTable());
        assertEquals("b",binder.columns(query,name("b",engine),name("id",engine)).getFirst().object().getTable());noBindingErrors(binder);
        var completion=new CompletionService(binder,AnalysisBudget.interactive()).complete("SELECT id".length()).stream().filter(item->item.getKind().equals("column")&&item.getLabel().equals("id")).toList();
        assertEquals(Set.of("id","a.id","b.id"),new HashSet<>(completion.stream().map(Completion::getInsertText).toList()));
        assertFalse(completion.stream().filter(item->item.getInsertText().equals("id")).findFirst().orElseThrow().getQualificationRequired());
    }
    @ParameterizedTest @EnumSource(value=Engine.class,names={"POSTGRESQL","MYSQL","MARIADB"})
    void wildcardOrderingFollowsEachNativeJoinOutput(Engine engine){
        var using=bind("SELECT * FROM a JOIN b USING (tenant,id)",engine);
        assertEquals(engine==Engine.POSTGRESQL?List.of("tenant","id","left_value","right_value"):List.of("id","tenant","left_value","right_value"),names(using.project(root(using))));
        var natural=bind("SELECT * FROM a NATURAL JOIN b",engine);assertEquals(List.of("id","tenant","left_value","right_value"),names(natural.project(root(natural))));
        var right=bind("SELECT * FROM a NATURAL RIGHT JOIN b",engine);
        assertEquals(engine==Engine.POSTGRESQL?List.of("id","tenant","left_value","right_value"):List.of("tenant","id","right_value","left_value"),names(right.project(root(right))));
        var explicitRight=bind("SELECT * FROM a RIGHT JOIN b USING(id,tenant)",engine);
        assertEquals(engine==Engine.POSTGRESQL?List.of("id","tenant","left_value","right_value"):List.of("tenant","id","right_value","left_value"),names(explicitRight.project(root(explicitRight))));
    }
    @ParameterizedTest @EnumSource(value=Engine.class,names={"POSTGRESQL","MYSQL","MARIADB"})
    void qualifiedWildcardsPreserveEachOperandOrderAcrossMergedJoinOrientations(Engine engine){
        for(String join:List.of("JOIN b USING(id)","NATURAL JOIN b","NATURAL RIGHT JOIN b","RIGHT JOIN b USING(id,tenant)")){
            var qualified=bind("SELECT a.*, b.* FROM a "+join,engine);
            assertEquals(List.of("id","left_value","tenant","tenant","id","right_value"),names(qualified.project(root(qualified))),join);
        }
    }
    @ParameterizedTest @EnumSource(value=Engine.class,names={"POSTGRESQL","MYSQL","MARIADB"})
    void derivedAndCteOutputsInheritTheMergedNamespace(Engine engine){
        for(String sql:List.of("SELECT d.id,d.left_value,d.right_value FROM (SELECT * FROM a JOIN b USING(id,tenant)) d","WITH d AS (SELECT * FROM a NATURAL JOIN b) SELECT d.id,d.left_value,d.right_value FROM d")){
            var binder=bind(sql,engine);assertEquals(List.of("id","left_value","right_value"),names(binder.project(root(binder))));noBindingErrors(binder);
        }
    }
    @ParameterizedTest @EnumSource(value=Engine.class,names={"POSTGRESQL","MYSQL","MARIADB"})
    void outerJoinsExtendOperandNullabilityWithoutLosingTheMergedKey(Engine engine){
        var left=bind("SELECT id,a.id,b.id FROM a LEFT JOIN b USING(id)",engine);var query=root(left);
        assertFalse(left.columns(query,null,name("id",engine)).getFirst().type().nullable());
        assertFalse(left.columns(query,name("a",engine),name("id",engine)).getFirst().type().nullable());
        assertTrue(left.columns(query,name("b",engine),name("id",engine)).getFirst().type().nullable());noBindingErrors(left);
        var right=bind("SELECT id,a.id,b.id FROM a RIGHT JOIN b USING(id)",engine);query=root(right);
        assertFalse(right.columns(query,null,name("id",engine)).getFirst().type().nullable());assertTrue(right.columns(query,name("a",engine),name("id",engine)).getFirst().type().nullable());noBindingErrors(right);
        var full=bind("SELECT id FROM a FULL JOIN b USING(id)",engine);
        if(engine==Engine.POSTGRESQL){assertEquals(1,full.columns(root(full),null,name("id",engine)).size());noBindingErrors(full);}
        else assertTrue(full.diagnostics().stream().anyMatch(issue->issue.code().equals("dialect.full-join")));
    }
    @ParameterizedTest @EnumSource(value=Engine.class,names={"POSTGRESQL","MYSQL","MARIADB"})
    void nearestLocalMatchStopsBeforeOuterRelationsButMissingLocalNameCanCorrelate(Engine engine){
        var binder=bind("SELECT (SELECT id FROM b i WHERE left_value = i.right_value) FROM a o",engine);var query=inner(binder);
        var local=binder.lookupColumns(query,null,name("id",engine));assertTrue(local.complete());assertEquals(1,local.candidates().size());assertEquals("b",local.candidates().getFirst().object().getTable());
        var outer=binder.lookupColumns(query,null,name("left_value",engine));assertTrue(outer.complete());assertEquals("a",outer.candidates().getFirst().object().getTable());noBindingErrors(binder);
        var ambiguous=bind("SELECT (SELECT id FROM b i JOIN c j ON true) FROM a o",engine);
        assertEquals(2,ambiguous.columns(inner(ambiguous),null,name("id",engine)).size());
        assertEquals(1,ambiguous.diagnostics().stream().filter(issue->issue.code().equals("binding.ambiguous-column")).count());
    }
    @ParameterizedTest @EnumSource(value=Engine.class,names={"POSTGRESQL","MYSQL","MARIADB"})
    void nearestAliasBlocksOuterAliasEvenWhenTheLocalColumnDoesNotExist(Engine engine){
        var binder=bind("SELECT (SELECT x.left_value FROM b x) FROM a x",engine);var lookup=binder.lookupColumns(inner(binder),name("x",engine),name("left_value",engine));
        assertTrue(lookup.complete());assertTrue(lookup.candidates().isEmpty());assertTrue(binder.diagnostics().stream().anyMatch(issue->issue.code().equals("binding.invalid-derived-reference")));
    }
    @ParameterizedTest @EnumSource(value=Engine.class,names={"POSTGRESQL","MYSQL","MARIADB"})
    void incompleteLocalSourcesDoNotBindOuterNamesOrInventNaturalMerges(Engine engine){
        var partial=new ArrayList<>(OBJECTS.stream().filter(object->!object.getTable().equals("b")).toList());
        partial.replaceAll(object->object.getKind()==ObjectKind.TABLE&&object.getName().equals("b")?object.toBuilder().setIntrospectionLevel(1).build():object);
        var binder=bind("SELECT (SELECT id FROM b i) FROM a o",engine,partial);var lookup=binder.lookupColumns(inner(binder),null,name("id",engine));
        assertFalse(lookup.complete());assertTrue(lookup.candidates().isEmpty());
        assertTrue(binder.diagnostics().stream().noneMatch(issue->Set.of("binding.unresolved-column","binding.ambiguous-column").contains(issue.code())));
        var natural=bind("SELECT id FROM a NATURAL JOIN b",engine,partial);assertFalse(natural.lookupColumns(root(natural),null,name("id",engine)).complete());
    }
    @ParameterizedTest @EnumSource(value=Engine.class,names={"POSTGRESQL","MYSQL","MARIADB"})
    void joinPrecedenceLimitsOnNamesToItsOperands(Engine engine){
        var invalid=bind("SELECT * FROM a, b JOIN c ON a.id=c.id",engine);assertTrue(invalid.diagnostics().stream().anyMatch(issue->issue.code().equals("binding.invalid-derived-reference")));
        var valid=bind("SELECT * FROM (a,b) JOIN c ON a.id=c.id",engine);noBindingErrors(valid);
        var chain=bind("SELECT id FROM a JOIN b USING(id) JOIN c USING(id)",engine);assertEquals(1,chain.columns(root(chain),null,name("id",engine)).size());noBindingErrors(chain);
    }
    @Test void postgresGroupedJoinAliasHidesTheInnerRelationNames(){
        var valid=bind("SELECT j.id,j.left_value FROM (a JOIN b USING(id,tenant)) AS j",Engine.POSTGRESQL);assertEquals(List.of("j"),valid.own(root(valid)).stream().map(SemanticBinder.RelationSymbol::alias).toList());noBindingErrors(valid);
        var invalid=bind("SELECT a.id FROM (a JOIN b USING(id)) j",Engine.POSTGRESQL);assertTrue(invalid.diagnostics().stream().anyMatch(issue->issue.code().equals("binding.invalid-derived-reference")));
        var inside=bind("SELECT j.id FROM (a JOIN b ON a.id=b.id) j",Engine.POSTGRESQL);assertEquals(1,inside.diagnostics().stream().filter(issue->issue.code().equals("binding.ambiguous-column")).count());
    }
    @ParameterizedTest @EnumSource(value=Engine.class,names={"POSTGRESQL","MYSQL","MARIADB"})
    void invalidUsingNamesHaveOneLocalizedCauseAndNoAmbiguityCascade(Engine engine){
        var duplicate=bind("SELECT id FROM a JOIN b USING(id,id)",engine);assertEquals(1,duplicate.diagnostics().stream().filter(issue->issue.code().equals("binding.duplicate-using-column")).count());assertTrue(duplicate.diagnostics().stream().noneMatch(issue->issue.code().equals("binding.ambiguous-column")));
        var missing=bind("SELECT id FROM a JOIN b USING(missing)",engine);assertEquals(1,missing.diagnostics().stream().filter(issue->issue.code().equals("binding.unresolved-using-column")).count());
    }
    @ParameterizedTest @EnumSource(value=Engine.class,names={"POSTGRESQL","MYSQL","MARIADB"})
    void naturalComparisonUsesNativeQuotedIdentifierRules(Engine engine){
        var objects=new ArrayList<>(OBJECTS);objects.add(table("q"));objects.add(column("q","ID","bigint",1));
        var binder=bind("SELECT * FROM q NATURAL JOIN b",engine,objects);var projected=names(binder.project(root(binder)));
        assertEquals(engine==Engine.POSTGRESQL?List.of("ID","tenant","id","right_value"):List.of("ID","tenant","right_value"),projected);noBindingErrors(binder);
        var right=bind("SELECT * FROM q NATURAL RIGHT JOIN b",engine,objects);
        assertEquals(engine==Engine.POSTGRESQL?List.of("ID","tenant","id","right_value"):List.of("id","tenant","right_value"),names(right.project(root(right))));
        String quoted=engine==Engine.POSTGRESQL?"\"ID\"":"`ID`";
        var using=bind("SELECT * FROM q JOIN b USING("+quoted+")",engine,objects);
        assertEquals(engine==Engine.POSTGRESQL,using.diagnostics().stream().anyMatch(issue->issue.code().equals("binding.unresolved-using-column")));
    }
    @ParameterizedTest @EnumSource(value=Engine.class,names={"POSTGRESQL","MYSQL","MARIADB"})
    void correlatedCompletionKeepsTheLocalNameAndQualifiedOuterAlternative(Engine engine){
        String sql="SELECT (SELECT i FROM b i) FROM a o";var binder=bind(sql,engine);
        var completion=new CompletionService(binder,AnalysisBudget.interactive()).complete(sql.indexOf("i FROM")+1).stream().filter(item->item.getKind().equals("column")&&item.getLabel().equals("id")).toList();
        assertEquals(Set.of("id","o.id"),new HashSet<>(completion.stream().map(Completion::getInsertText).toList()));assertTrue(completion.stream().anyMatch(item->item.getInsertText().equals("id")&&!item.getQualificationRequired()));
    }
    @Test void postgresUsingKeepsVarcharKindAcrossDifferentOperandTypmods(){
        var objects=List.of(table("l"),column("l","k","varchar(10)",1).toBuilder().putProperties("precision","10").build(),table("r"),column("r","k","varchar(20)",1).toBuilder().putProperties("precision","20").build());
        for(String join:List.of("JOIN","LEFT JOIN","RIGHT JOIN","FULL JOIN"))for(String sql:List.of("SELECT k FROM l "+join+" r USING(k)","SELECT d.k FROM (SELECT * FROM l "+join+" r USING(k)) d")){
            var binder=bind(sql,Engine.POSTGRESQL,objects);var type=binder.project(root(binder)).getFirst().type();assertTrue(SqlTypes.sameNative(SqlTypes.nativeType("varchar",Engine.POSTGRESQL),type,Engine.POSTGRESQL),sql);assertEquals(0,type.precision(),sql);assertTrue(binder.diagnostics().isEmpty(),()->sql+": "+binder.diagnostics());
        }
    }
    @Test void tableSourceDepthIsBoundedBeforeRecursiveBinding(){
        String sql="SELECT * FROM a"+" JOIN b ON true".repeat(80);
        assertThrows(AnalysisBudget.Limit.class,()->bind(sql,Engine.POSTGRESQL));
    }
}
