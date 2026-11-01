package io.busystack.busydata;

import io.busystack.busydata.analysis.language.*;
import io.busystack.busydata.metadata.IntrospectionLevel;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.Explorer;
import java.lang.reflect.Proxy;
import java.nio.file.Path;
import java.sql.Connection;
import java.util.*;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

/** Compare semantic joined outputs with the actual pinned servers and warmed metadata. */
class SemanticJoinScopeIT {
    @TempDir Path root;
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void joinedOutputAndCorrelatedBindingAgreeWithTheNativeEngine(String engine)throws Exception {
        var jdbc=new AtomicInteger();Thread analysisThread=Thread.currentThread();
        try(var fixture=new EngineFixture(root,engine,(adapter,request,port)->{
            var connection=adapter.connect(request,port);
            return (Connection)Proxy.newProxyInstance(Connection.class.getClassLoader(),new Class[]{Connection.class},(proxy,method,args)->{
                if(Thread.currentThread()==analysisThread&&Set.of("prepareStatement","createStatement","getMetaData").contains(method.getName()))jdbc.incrementAndGet();
                try{return method.invoke(connection,args);}catch(java.lang.reflect.InvocationTargetException error){throw error.getCause();}
            });
        })){
            var session=fixture.open();fixture.introspectionLevel(session,IntrospectionLevel.STRUCTURE);
            String a=session.adapter.table(session.context.catalog(),fixture.schema(),"join_a"),b=session.adapter.table(session.context.catalog(),fixture.schema(),"join_b");
            fixture.execute(session,"CREATE TABLE "+a+"(id BIGINT NOT NULL,left_value VARCHAR(20),tenant INTEGER NOT NULL); CREATE TABLE "+b+"(tenant BIGINT NOT NULL,id BIGINT NOT NULL,right_value VARCHAR(20)); INSERT INTO "+a+" VALUES(1,'left',10); INSERT INTO "+b+" VALUES(10,1,'matched'),(20,2,'right')");
            String q=session.adapter.table(session.context.catalog(),fixture.schema(),"join_q");
            fixture.execute(session,"CREATE TABLE "+q+"("+session.adapter.quote("ID")+" BIGINT NOT NULL); INSERT INTO "+q+" VALUES(1)");
            var explorer=new Explorer(fixture.metadata);explorer.refreshContext(session);var snapshot=explorer.metadata().capture(session);
            var context=new ResolutionContext(session.context.catalog(),session.context.schema(),session.context.searchPath(),true,snapshot.revision(),snapshot.configurationRevision(),snapshot.rules(),snapshot,session.context.temporarySchema());
            var queries=new ArrayList<String>(List.of("SELECT * FROM "+a+" a JOIN "+b+" b USING(tenant,id)","SELECT * FROM "+a+" a NATURAL JOIN "+b+" b","SELECT * FROM "+a+" a NATURAL RIGHT JOIN "+b+" b","SELECT a.*,b.* FROM "+a+" a LEFT JOIN "+b+" b USING(id)","SELECT d.id,d.left_value,d.right_value FROM (SELECT * FROM "+a+" a JOIN "+b+" b USING(id,tenant)) d"));
            queries.add("SELECT * FROM "+a+" a RIGHT JOIN "+b+" b USING(id,tenant)");
            queries.add("SELECT a.*,b.* FROM "+a+" a NATURAL RIGHT JOIN "+b+" b");
            queries.add("SELECT * FROM "+q+" q NATURAL RIGHT JOIN "+b+" b");
            if(fixture.engine==Engine.POSTGRESQL)queries.add("SELECT * FROM "+a+" a FULL JOIN "+b+" b USING(id,tenant)");
            for(String sql:queries){
                jdbc.set(0);var budget=new AnalysisBudget(1500,()->false);var dialect=new Dialect(fixture.engine,session.context.lexical());var tree=SyntaxParser.parse(LosslessLexer.scan(sql,dialect,budget),budget);
                var binder=new SemanticBinder(tree,new SemanticCatalog(dialect,context,budget),budget);var projected=binder.project(tree.queries().getFirst());
                assertFalse(projected.isEmpty());assertTrue(binder.diagnostics().stream().noneMatch(issue->issue.code().startsWith("binding.")),()->binder.diagnostics().toString());
                assertEquals(0,jdbc.get(),"Joined binding must only read the captured central snapshot");
                var result=fixture.results.get(fixture.execute(session,sql).info().getResults(0).getResultId());
                assertEquals(result.columns.stream().map(Column::getName).toList(),projected.stream().map(SemanticBinder.ColumnSymbol::name).toList(),sql);
            }
            String correlated="SELECT (SELECT id FROM "+b+" i WHERE i.id=o.id) AS local_id FROM "+a+" o";
            var diagnostics=fixture.analysis.analyze(AnalysisRequest.newBuilder().setEngine(fixture.engine).setOperation(AnalysisOperation.DIAGNOSTICS).setSql(correlated).build(),session.context.lexical(),context);
            assertTrue(diagnostics.getDiagnosticsList().stream().noneMatch(issue->issue.getCode().startsWith("binding.")),diagnostics.toString());
            var row=fixture.results.get(fixture.execute(session,correlated).info().getResults(0).getResultId()).read(0);assertEquals("1",row.getValues(0).getSignedInteger());
            String marked="SELECT i| FROM "+a+" a JOIN "+b+" b USING(id,tenant)";int caret=marked.indexOf('|');
            var completion=fixture.analysis.analyze(AnalysisRequest.newBuilder().setEngine(fixture.engine).setOperation(AnalysisOperation.COMPLETION).setSql(marked.replace("|","")).setCaretUtf16(caret).build(),session.context.lexical(),context);
            assertEquals(1,completion.getCompletionsList().stream().filter(item->item.getKind().equals("column")&&item.getInsertText().equals("id")&&!item.getQualificationRequired()).count(),completion.toString());
        }
    }
}
