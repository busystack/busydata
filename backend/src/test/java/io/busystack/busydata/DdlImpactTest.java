package io.busystack.busydata;

import io.busystack.busydata.analysis.LexicalSettings;
import io.busystack.busydata.analysis.language.*;
import io.busystack.busydata.protocol.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class DdlImpactTest {
    private static final ResolutionContext CONTEXT=new ResolutionContext("database","public",List.of("public"),true,1,1);
    private static DdlEffect effect(Engine engine,String sql){var effects=DdlImpact.analyze(sql,engine,LexicalSettings.DEFAULT,CONTEXT);assertEquals(1,effects.size(),sql);return effects.getFirst();}
    @Test void ordinaryColumnDefinitionsKeepOneExactOwnerAcrossSupportedDialects(){
        for(var engine:List.of(Engine.POSTGRESQL,Engine.MYSQL,Engine.MARIADB)){
            var effect=effect(engine,"CREATE TABLE created_rows(id integer,n integer)");assertEquals("created_rows",effect.getName());assertEquals(ObjectKind.TABLE,effect.getKind());assertFalse(effect.getConservative());
        }
    }
    @Test void compositeKeysAndReferentialActionsStayInsideTheTableDefinition(){
        for(var engine:List.of(Engine.POSTGRESQL,Engine.MYSQL,Engine.MARIADB)){
            var effect=effect(engine,"CREATE TABLE child(a integer,b integer,CONSTRAINT fk_pair FOREIGN KEY(a,b) REFERENCES parent(x,y) ON DELETE CASCADE)");
            assertEquals("child",effect.getName());assertFalse(effect.getConservative(),engine.name());
        }
    }
    @Test void quotedNamesAndLiteralCommasNeverBecomeObjectSeparators(){
        for(var engine:List.of(Engine.POSTGRESQL,Engine.MYSQL,Engine.MARIADB)){
            String quote=engine==Engine.POSTGRESQL?"\"":"`";
            var effect=effect(engine,"CREATE TABLE "+quote+"table,one"+quote+"("+quote+"column,one"+quote+" varchar(40) DEFAULT 'x,y)(',n integer)");
            assertEquals("table,one",effect.getName());assertFalse(effect.getConservative());
        }
    }
    @Test void topLevelDropListsAndMultipleAlterActionsRemainConservative(){
        for(var engine:List.of(Engine.POSTGRESQL,Engine.MYSQL,Engine.MARIADB))for(String sql:List.of("DROP TABLE first_table,second_table","ALTER TABLE first_table ADD COLUMN x integer,ADD COLUMN y integer","ALTER TABLE first_table RENAME TO second_table"))assertTrue(effect(engine,sql).getConservative(),engine+": "+sql);
    }
    @Test void createSelectAndNativeTableOptionCommasStillHaveOneCreatedOwner(){
        for(var engine:List.of(Engine.POSTGRESQL,Engine.MYSQL,Engine.MARIADB))assertFalse(effect(engine,"CREATE TABLE created_rows AS SELECT a,b FROM source_rows").getConservative());
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB))assertFalse(effect(engine,"CREATE TABLE created_rows(a integer,b integer) ENGINE=InnoDB, COMMENT='x,y'").getConservative());
    }
    @Test void cascadeAndUnmodeledPartitionDependenciesRetainConservativeScope(){
        for(String sql:List.of("DROP TABLE parent CASCADE","CREATE TABLE child(id integer) INHERITS(parent)","CREATE TABLE child PARTITION OF parent FOR VALUES IN (1,2)","ALTER TABLE parent ATTACH PARTITION child FOR VALUES IN(1,2)"))assertTrue(effect(Engine.POSTGRESQL,sql).getConservative(),sql);
    }
    @Test void malformedDelimitersCannotProveOneSafeDefinition(){
        for(String sql:List.of("CREATE TABLE uncertain_rows(a integer,b integer","CREATE TABLE uncertain_rows(a integer))","CREATE TABLE first_table,second_table"))assertTrue(effect(Engine.POSTGRESQL,sql).getConservative(),sql);
    }
}
