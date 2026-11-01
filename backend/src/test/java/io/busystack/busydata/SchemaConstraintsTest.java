package io.busystack.busydata;

import com.google.gson.*;
import io.busystack.busydata.schema.*;
import io.busystack.busydata.metadata.IdentifierRules;
import io.busystack.busydata.metadata.MetadataSnapshot;
import io.busystack.busydata.protocol.Engine;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class SchemaConstraintsTest {
    private static MetadataSnapshot evidence(IdentifierRules rules){return MetadataSnapshot.empty("unit-source","unit-profile",rules);}
    private static JsonObject snapshot(String engine,int version,JsonObject table){var root=new JsonObject();root.addProperty("version",version);root.addProperty("engine",engine);root.addProperty("schema","fixture");var tables=new JsonObject();tables.add("child",table);root.add("tables",tables);return root;}
    private static JsonObject legacy(String kind){
        String unique="UNIQUE KEY `shared` (`unique_value`)",index="KEY `support` (`parent_id`)",foreign="CONSTRAINT `shared` FOREIGN KEY (`parent_id`) REFERENCES `parent` (`id`)",check="CONSTRAINT `shared` CHECK ((`check_value` > 0))";
        var parts=new DdlParts("CREATE TABLE `child` ",List.of("`unique_value` int","`parent_id` int","`check_value` int",unique,index,foreign,check)," ENGINE=InnoDB");
        var table=new JsonObject();table.addProperty("create",parts.render(parts.parts()));
        var base=kind.equals("f")?parts.parts().subList(0,5):parts.parts();table.addProperty("createBase",new DdlParts("CREATE TABLE `fixture`.`child` ",parts.parts(),parts.suffix()).render(base));
        var constraints=new JsonObject();constraints.addProperty("shared",check);table.add("constraints",constraints);var kinds=new JsonObject();kinds.addProperty("shared",kind);table.add("constraintKinds",kinds);
        var indexes=new JsonObject();indexes.addProperty("shared",unique);indexes.addProperty("support",index);table.add("indexes",indexes);return table;
    }
    @Test void legacyNativeCreateRecoversAllThreeTypedSiblingsAndCorrectBaseWithoutChangingOriginalSource(){
        for(String kind:List.of("c","f")){
            var table=legacy(kind);String original=table.get("create").getAsString(),input=snapshot("MYSQL",1,table).toString();
            var upgraded=SchemaConstraints.importSnapshot(SnapshotJson.read(input));var actual=upgraded.getAsJsonObject("tables").getAsJsonObject("child");
            assertEquals(2,upgraded.get("version").getAsInt());assertFalse(actual.has("constraintKinds"));assertEquals(3,actual.getAsJsonObject("constraints").size());
            assertEquals(original,actual.get("create").getAsString());assertFalse(actual.get("createBase").getAsString().contains("FOREIGN KEY"));assertTrue(actual.get("createBase").getAsString().contains("CHECK"));
            assertTrue(actual.getAsJsonObject("indexes").has("support"));assertFalse(actual.getAsJsonObject("indexes").has("shared"));
            for(String type:List.of("UNIQUE","FOREIGN KEY","CHECK")){var record=SchemaConstraints.find(actual,"shared",type);assertEquals(type,record.get("type").getAsString());assertEquals("shared",record.get("name").getAsString());}
            assertThrows(IllegalArgumentException.class,()->SchemaConstraints.find(actual,"shared",""));assertEquals(upgraded,SchemaConstraints.importSnapshot(SnapshotJson.read(upgraded.toString())));
            assertEquals(1,SnapshotJson.read(input).get("version").getAsInt(),"Import never rewrites the original artifact bytes");
        }
    }
    @Test void contradictoryLegacyDefinitionTypeIndexOrBaseCannotAuthorizeReconstructedSql(){
        for(String changed:List.of("definition","type","index","base","missingCreate")){
            var table=legacy("c");switch(changed){
                case "definition"->table.getAsJsonObject("constraints").addProperty("shared","CONSTRAINT `shared` CHECK (1)");
                case "type"->table.getAsJsonObject("constraintKinds").addProperty("shared","x");
                case "index"->table.getAsJsonObject("indexes").remove("support");
                case "base"->table.addProperty("createBase",table.get("createBase").getAsString().replace("`check_value` int","`check_value` text"));
                case "missingCreate"->table.remove("create");
            }
            assertThrows(IllegalArgumentException.class,()->SchemaConstraints.importSnapshot(snapshot("MARIADB",1,table)),changed);
        }
    }
    @Test void postgresLegacyRetainsExactNativeTypesAndForeignDefinitionAbsentFromGeneratedCreate(){
        var table=new JsonObject();var constraints=new JsonObject();var kinds=new JsonObject();
        constraints.addProperty("quoted\"name","CONSTRAINT \"quoted\"\"name\" FOREIGN KEY (parent_id) REFERENCES parent (id)");kinds.addProperty("quoted\"name","f");
        constraints.addProperty("excluded","CONSTRAINT \"excluded\" EXCLUDE USING gist (span WITH &&)");kinds.addProperty("excluded","x");table.add("constraints",constraints);table.add("constraintKinds",kinds);table.addProperty("create","CREATE TABLE child (parent_id int)");
        var imported=SchemaConstraints.importSnapshot(snapshot("POSTGRESQL",1,table));var actual=imported.getAsJsonObject("tables").getAsJsonObject("child");
        assertEquals("f",SchemaConstraints.find(actual,"quoted\"name","f").get("type").getAsString());assertTrue(SchemaConstraints.definition(actual,"quoted\"name","f").contains("REFERENCES"));assertEquals("x",SchemaConstraints.find(actual,"excluded","x").get("type").getAsString());assertEquals("CREATE TABLE child (parent_id int)",actual.get("create").getAsString());
    }
    @Test void typedKeysAreExactAndRejectForgedRecordKeysWrongEngineAndLegacyDictionaries(){
        String name="漢\"\\Σ,[]";var table=new JsonObject();var constraints=new JsonObject();SchemaConstraints.put(constraints,name,"CHECK","CONSTRAINT `"+name+"` CHECK (1)");table.add("constraints",constraints);
        var valid=snapshot("MYSQL",2,table);assertNotNull(SchemaConstraints.find(SchemaConstraints.importSnapshot(valid).getAsJsonObject("tables").getAsJsonObject("child"),name,"CHECK"));
        var wrong=table.deepCopy();var record=wrong.getAsJsonObject("constraints").remove(SchemaConstraints.key(name,"CHECK"));wrong.getAsJsonObject("constraints").add("forged",record);assertThrows(IllegalArgumentException.class,()->SchemaConstraints.importSnapshot(snapshot("MYSQL",2,wrong)));
        assertThrows(IllegalArgumentException.class,()->SchemaConstraints.importSnapshot(snapshot("POSTGRESQL",2,table.deepCopy())));
        var dual=table.deepCopy();dual.add("constraintKinds",new JsonObject());assertThrows(IllegalArgumentException.class,()->SchemaConstraints.importSnapshot(snapshot("MYSQL",2,dual)));
        assertThrows(IllegalArgumentException.class,()->SchemaConstraints.put(constraints,name,"CHECK","duplicate"));assertNull(SchemaConstraints.find(table,name,"UNIQUE"));
    }
    @Test void nativeGrammarReadsOnlyExactLeadingIdentityAndNeverExpressionTokens(){
        for(var entry:Map.of("CONSTRAINT `a``b` CHECK ('FOREIGN KEY UNIQUE')","CHECK","UNIQUE KEY `a``b` (`n`)","UNIQUE","CONSTRAINT `a``b` FOREIGN KEY (`n`) REFERENCES `t` (`n`)","FOREIGN KEY").entrySet()){
            var parsed=DdlParts.constraint(entry.getKey());assertEquals("a`b",parsed.name());assertEquals(entry.getValue(),parsed.type());assertEquals(entry.getKey(),parsed.definition());
        }
        assertEquals("PRIMARY",DdlParts.constraint("PRIMARY KEY (`id`)").name());assertNull(DdlParts.constraint("`CHECK` varchar(40) DEFAULT 'FOREIGN KEY'"));assertNull(DdlParts.constraint("KEY `independent` (`n`)"));
        assertThrows(IllegalArgumentException.class,()->DdlParts.constraint("CONSTRAINT `x` CHECKISH (n)"));assertThrows(IllegalArgumentException.class,()->DdlParts.constraint("CONSTRAINT `x` UNIQUE KEY `other` (`n`)"));assertThrows(IllegalArgumentException.class,()->DdlParts.constraint("FOREIGN KEY (`n`) REFERENCES `t` (`n`)"));
    }
    @Test void definitionHeaderMustMatchExactQuotedNameAndActualTypeBeforeComparison(){
        for(String engine:List.of("POSTGRESQL","MYSQL","MARIADB")){
            boolean pg=engine.equals("POSTGRESQL");String quote=pg?"\"":"`",name="nested"+quote+"name",encoded=quote+name.replace(quote,quote+quote)+quote,type=pg?"c":"CHECK";
            var table=new JsonObject();var constraints=new JsonObject();table.add("constraints",constraints);SchemaConstraints.put(constraints,name,type,"CONSTRAINT "+encoded+" CHECK ('FOREIGN KEY' <> '')");
            assertDoesNotThrow(()->SchemaConstraints.importSnapshot(snapshot(engine,2,table.deepCopy())));
            for(String definition:List.of("CONSTRAINT "+quote+"other"+quote+" CHECK (1)","CONSTRAINT "+encoded+" FOREIGN KEY (n) REFERENCES parent (n)","CONSTRAINT "+quote+"unterminated CHECK (1)","CONSTRAINT "+encoded+" CHECKISH (1)")){
                var malformed=table.deepCopy();malformed.getAsJsonObject("constraints").getAsJsonObject(SchemaConstraints.key(name,type)).addProperty("definition",definition);
                assertThrows(IllegalArgumentException.class,()->SchemaConstraints.importSnapshot(snapshot(engine,2,malformed)),engine);
            }
        }
        var legacy=new JsonObject();var constraints=new JsonObject();var kinds=new JsonObject();legacy.add("constraints",constraints);legacy.add("constraintKinds",kinds);constraints.addProperty("expected","CONSTRAINT \"other\" CHECK (1)");kinds.addProperty("expected","c");
        assertThrows(IllegalArgumentException.class,()->SchemaConstraints.importSnapshot(snapshot("POSTGRESQL",1,legacy)));
    }
    @Test void unsupportedVersionMissingLegacyTypeAndConstraintBudgetsFailExplicitly(){
        var table=new JsonObject();table.add("constraints",new JsonObject());assertThrows(IllegalArgumentException.class,()->SchemaConstraints.importSnapshot(snapshot("MYSQL",3,table)));
        var old=new JsonObject();var values=new JsonObject();values.addProperty("named","CONSTRAINT named CHECK (1)");old.add("constraints",values);old.add("constraintKinds",new JsonObject());assertThrows(IllegalArgumentException.class,()->SchemaConstraints.importSnapshot(snapshot("POSTGRESQL",1,old)));
        assertThrows(IllegalArgumentException.class,()->SchemaConstraints.put(new JsonObject(),"n","CHECK","x".repeat(1_048_577)));
        var maximum=new JsonObject();for(int i=0;i<4096;i++)SchemaConstraints.put(maximum,"c"+i,"CHECK","CHECK (1)");assertThrows(IllegalArgumentException.class,()->SchemaConstraints.put(maximum,"too_many","CHECK","CHECK (1)"));
    }
    @Test void foreignKeyDropRequiresCompleteOperationEvidenceAndRejectsCaseCollisionsDespiteDistinctExactRecords(){
        for(Engine engine:List.of(Engine.MYSQL,Engine.MARIADB)){
            var table=new JsonObject();var constraints=new JsonObject();table.add("constraints",constraints);SchemaConstraints.put(constraints,"Target","FOREIGN KEY","CONSTRAINT `Target` FOREIGN KEY (n) REFERENCES t (n)");
            assertFalse(SchemaConstraints.foreignKeyDropsUnambiguous(table,evidence(new IdentifierRules(engine,0))));
            var rules=NativeCaseFixtures.rules(engine,0);assertTrue(SchemaConstraints.foreignKeyDropsUnambiguous(table,evidence(rules)));assertTrue(rules.complete());assertFalse(SchemaConstraints.foreignKeyDropsUnambiguous(table,evidence(rules).withIdentifierAvailability(false)),"Complete maps from another physical header cannot certify DROP");
            SchemaConstraints.put(constraints,"target","CHECK","CONSTRAINT `target` CHECK (n > 0)");assertTrue(SchemaConstraints.foreignKeyDropsUnambiguous(table,evidence(rules)),"Another native type does not share the FK DROP target");
            SchemaConstraints.put(constraints,"target","FOREIGN KEY","CONSTRAINT `target` FOREIGN KEY (other) REFERENCES t (n)");assertNotNull(SchemaConstraints.find(table,"Target","FOREIGN KEY"));assertNotNull(SchemaConstraints.find(table,"target","FOREIGN KEY"));assertFalse(SchemaConstraints.foreignKeyDropsUnambiguous(table,evidence(rules)));
        }
        var pg=new JsonObject();var constraints=new JsonObject();pg.add("constraints",constraints);SchemaConstraints.put(constraints,"Target","f","CONSTRAINT \"Target\" FOREIGN KEY (n) REFERENCES t (n)");SchemaConstraints.put(constraints,"target","f","CONSTRAINT \"target\" FOREIGN KEY (n) REFERENCES t (n)");assertTrue(SchemaConstraints.foreignKeyDropsUnambiguous(pg,evidence(new IdentifierRules(Engine.POSTGRESQL,0))));
    }
}
