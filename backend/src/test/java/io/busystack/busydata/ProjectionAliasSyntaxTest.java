package io.busystack.busydata;

import io.busystack.busydata.analysis.*;
import io.busystack.busydata.analysis.language.*;
import io.busystack.busydata.protocol.Engine;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import static org.junit.jupiter.api.Assertions.*;

class ProjectionAliasSyntaxTest {
    private static SyntaxTree.Projection projection(String expression,Engine engine){return new SemanticDocument("SELECT "+expression,engine,LexicalSettings.DEFAULT,new AnalysisBudget(1500,()->false)).syntax().queries().getFirst().projections().getFirst();}
    private static List<String> expressions(){return List.of("flag","id+amount","(id+1>4) AND flag","id AND flag","NOT flag","id BETWEEN 1 AND amount","id NOT IN(id+1,amount)","CAST(id AS DECIMAL(18,4))","CASE WHEN flag THEN id ELSE amount END","coalesce(id+amount,0)");}
    private static String source(String sql,SyntaxTree.Projection projection){return ("SELECT "+sql).substring(projection.expression().getFirst().start(),projection.expression().getLast().end());}
    @ParameterizedTest @EnumSource(value=Engine.class,names={"POSTGRESQL","MYSQL","MARIADB"}) void completeExpressionsKeepTheirFinalOperand(Engine engine){
        for(String expression:expressions()){
            var projection=projection(expression,engine);assertNull(projection.alias(),expression);assertEquals(expression,source(expression,projection));
            var parsed=ExpressionParser.prefix(new Dialect(engine,LexicalSettings.DEFAULT),new AnalysisBudget(1500,()->false),projection.expression());assertTrue(parsed.complete(),expression);assertEquals(projection.expression().size(),parsed.consumed(),expression);
        }
    }
    @ParameterizedTest @EnumSource(value=Engine.class,names={"POSTGRESQL","MYSQL","MARIADB"}) void implicitAliasFollowsACompleteConsumedExpression(Engine engine){
        for(String expression:expressions()){
            String sql=expression+" total";var projection=projection(sql,engine);assertNotNull(projection.alias(),sql);assertEquals("total",projection.alias().identifier());assertEquals(expression,source(sql,projection));
            String explicit=expression+" AS total";var named=projection(explicit,engine);assertEquals("total",named.alias().identifier());assertEquals(expression,source(explicit,named));
        }
    }
    @ParameterizedTest @EnumSource(value=Engine.class,names={"POSTGRESQL","MYSQL","MARIADB"}) void quotedAliasesAndTriviaKeepTheirExactSpans(Engine engine){
        String alias=engine==Engine.POSTGRESQL?"\"SELECT\"":"`SELECT`",sql="coalesce(id+1,0) /* retained */ "+alias;var projection=projection(sql,engine);
        assertEquals("SELECT",projection.alias().identifier());assertTrue(projection.alias().quoted());assertEquals("coalesce(id+1,0)",source(sql,projection));assertEquals(7+sql.indexOf(alias),projection.alias().start());
    }
    @Test void castsWindowsAndIncompleteOperatorsUseGrammarConsumption(){
        for(String expression:List.of("id::numeric(18,4)","sum(id) OVER (PARTITION BY amount ORDER BY id)","CASE WHEN flag THEN id ELSE amount END")){
            var bare=projection(expression,Engine.POSTGRESQL);assertNull(bare.alias(),expression);assertEquals(expression,source(expression,bare));
            var named=projection(expression+" total",Engine.POSTGRESQL);assertEquals("total",named.alias().identifier(),expression);assertEquals(expression,source(expression+" total",named));
        }
        for(String expression:List.of("id AND","id+","coalesce(id,) total","CASE WHEN flag THEN id"))assertNull(projection(expression,Engine.POSTGRESQL).alias(),expression);
        assertEquals("total",projection("coalesce(id,) AS total",Engine.POSTGRESQL).alias().identifier());
    }
}
