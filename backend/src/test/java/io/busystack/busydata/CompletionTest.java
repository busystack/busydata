package io.busystack.busydata;
import io.busystack.busydata.analysis.*;
import io.busystack.busydata.analysis.language.SemanticDocument;
import io.busystack.busydata.analysis.language.ResolutionContext;
import io.busystack.busydata.protocol.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
class CompletionTest {
 private SemanticDocument.SymbolReference symbol(String marked,Engine engine) {
  int caret=marked.indexOf('|');return new SemanticDocument(marked.replace("|",""),engine).referenceAt(caret);
 }
 @Test void symbolsUseParsedQualifiedRelationsAndCorrelatedAliasScopes() {
  var relation=symbol("SELECT * FROM \"public\".\"Ord|ers\"",Engine.POSTGRESQL);
  assertEquals(new SemanticDocument.TableReference("","public","Orders"),relation.table());
  assertEquals("audit",symbol("SELECT (SELECT x|.id FROM audit.customers x) FROM public.customers x",Engine.POSTGRESQL).table().schema());
  assertEquals("public",symbol("SELECT x|.id, (SELECT id FROM audit.customers x) FROM public.customers x",Engine.POSTGRESQL).table().schema());
  assertEquals(new SemanticDocument.TableReference("","Audit","Customers"),symbol("SELECT * FROM Audit.Cus|tomers",Engine.MYSQL).table());
 }
 @Test void symbolsNeverResolveLiteralsCommentsCtesOrInvalidQualification() {
  for(String sql:List.of("SELECT 'FROM cust|omers' FROM customers", "SELECT $$FROM cust|omers$$ FROM customers",
    "SELECT * FROM customers /* cust|omers */", "SELECT * FROM customers|/*comment*/", "WITH c AS (SELECT * FROM customers) SELECT * FROM c|"))assertNull(symbol(sql,Engine.POSTGRESQL),sql);
  assertNull(symbol("SELECT * FROM wrong.busydata.public.cust|omers",Engine.POSTGRESQL));
  assertNull(symbol("SELECT * FROM wrong.busydata.cust|omers",Engine.MYSQL));
  assertThrows(SemanticDocument.AmbiguousReference.class,()->symbol("SELECT x|.id FROM customers x JOIN invoices x ON true",Engine.POSTGRESQL));
 }
 private final List<SchemaObject> metadata=List.of(
  SchemaObject.newBuilder().setKind(ObjectKind.TABLE).setName("orders").setSchema("public").build(),
  SchemaObject.newBuilder().setKind(ObjectKind.TABLE).setName("customers").setSchema("public").build(),
  SchemaObject.newBuilder().setKind(ObjectKind.TABLE).setName("Orders").setSchema("public").build(),
  column("orders","id"),column("orders","name"),column("customers","customer_name"),column("Orders","CamelCase"));
 private static SchemaObject column(String table,String name){return SchemaObject.newBuilder().setKind(ObjectKind.COLUMN).setSchema("public").setTable(table).setName(name).build();}
 private List<Completion> complete(String source){int caret=source.indexOf('|');String sql=source.replace("|","");return new SemanticDocument(sql,Engine.POSTGRESQL).complete(caret,SemanticFixtures.context(Engine.POSTGRESQL,metadata,new ResolutionContext("fixture","public",List.of("public"),true,1,1)));}
 @Test void resolvesAliasesDeclaredAfterCaretAndUsesReplacementOffsets(){String sql="SELECT o.na| FROM public.orders AS o";var completion=complete(sql).stream().filter(c->c.getLabel().equals("name")).findFirst().orElseThrow();assertEquals("name",completion.getInsertText());assertEquals(sql.indexOf("na|"),completion.getStartUtf16());assertEquals(sql.indexOf('|'),completion.getEndUtf16());assertFalse(complete(sql).stream().anyMatch(c->c.getLabel().equals("customer_name")));}
 @Test void nestedScopeShadowsOuterAliasAndDoesNotLeakAClosedScope(){var inner=complete("SELECT (SELECT o.cu| FROM customers o) FROM orders o");assertTrue(inner.stream().anyMatch(c->c.getLabel().equals("customer_name")));assertFalse(inner.stream().anyMatch(c->c.getLabel().equals("id")));var outer=complete("SELECT o.na|, (SELECT o.customer_name FROM customers o) FROM orders o");assertTrue(outer.stream().anyMatch(c->c.getLabel().equals("name")));}
 @Test void quotedIdentifiersAndCommentsDoNotInventRelations(){var completion=complete("SELECT o.\"Ca|\" FROM \"public\".\"Orders\" AS o /* JOIN fake f */").getFirst();assertEquals("CamelCase",completion.getLabel());assertEquals("\"CamelCase\"",completion.getInsertText());assertEquals(1,new SemanticDocument("SELECT 'FROM wrong w', $$ JOIN false f $$ FROM orders o",Engine.POSTGRESQL).references().size());}
 @Test void cteAndDerivedQueriesExposeActualProjectionNames(){assertTrue(complete("WITH c AS (SELECT id, name AS title FROM orders) SELECT c.ti| FROM c").stream().anyMatch(c->c.getLabel().equals("title")));assertTrue(complete("WITH c(identifier,label) AS (SELECT id,name FROM orders) SELECT c.la| FROM c").stream().anyMatch(c->c.getLabel().equals("label")));assertTrue(complete("SELECT d.ti| FROM (SELECT name AS title FROM orders) d").stream().anyMatch(c->c.getLabel().equals("title")));}
 @Test void escapesRemainWithinTheOriginalPostgresStatement(){var fragments=new SqlAnalysis().split("SELECT E'a\\'b\\'c;z'; SELECT 2;",Engine.POSTGRESQL);assertEquals(2,fragments.size());assertEquals("SELECT 2",fragments.get(1).text());}
 @Test void chainedCtesAndQualifiedWildcardsResolveOnlyTheirActualSource(){
  assertTrue(complete("WITH a AS (SELECT * FROM orders), b AS (SELECT a.* FROM a) SELECT b.na| FROM b").stream().anyMatch(c->c.getLabel().equals("name")));
  var selected=complete("WITH unused AS (SELECT customer_name FROM customers) SELECT d.| FROM (SELECT o.* FROM orders o JOIN customers c ON true) d");
  assertTrue(selected.stream().anyMatch(c->c.getLabel().equals("id")));assertFalse(selected.stream().anyMatch(c->c.getLabel().equals("customer_name")));
  assertTrue(complete("WITH \"Case\"(\"Named\") AS (SELECT id FROM orders) SELECT c.\"Na|\" FROM \"Case\" c").stream().anyMatch(c->c.getInsertText().equals("\"Named\"")));
 }
 @Test void correlatedAliasesResolveButInnerCteShadowsItsOuterDefinition(){
  assertTrue(complete("SELECT (SELECT o.na|) FROM orders o").stream().anyMatch(c->c.getLabel().equals("name")));
  var labels=complete("WITH x AS (SELECT name FROM orders) SELECT (WITH x AS (SELECT customer_name FROM customers) SELECT x.cu| FROM x) FROM x");
  assertTrue(labels.stream().anyMatch(c->c.getLabel().equals("customer_name")));assertFalse(labels.stream().anyMatch(c->c.getLabel().equals("name")));
 }
 @Test void recursiveAndExcessiveScopesAreBounded(){
  assertDoesNotThrow(()->complete("WITH RECURSIVE r AS (SELECT * FROM r) SELECT r.| FROM r"));
  assertThrows(IllegalArgumentException.class,()->new SemanticDocument("(".repeat(65)+"SELECT id FROM orders",Engine.POSTGRESQL));
  assertThrows(IllegalArgumentException.class,()->new SemanticDocument("x".repeat(262145),Engine.POSTGRESQL));
 }
}
