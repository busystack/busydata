package io.busystack.busydata.schema;

import com.google.gson.JsonObject;
import io.busystack.busydata.NativeCaseFixtures;
import io.busystack.busydata.metadata.MetadataSnapshot;
import io.busystack.busydata.protocol.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class SchemaDiffCapabilityTest {
    private static MetadataSnapshot evidence(Engine engine,boolean caseInsensitiveFileSystem){return MetadataSnapshot.empty("unit-source","unit-profile",NativeCaseFixtures.rules(engine,0,"unit-capability",caseInsensitiveFileSystem));}
    private static JsonObject triggers(String source){var values=new JsonObject();values.addProperty("named",source);return values;}
    @Test void unsupportedMariaTriggerScopeRejectsAddDropAndChangeButAllowsUnchangedEvidence(){
        var evidence=evidence(Engine.MARIADB,true);assertTrue(evidence.identifierRulesAvailable());assertTrue(evidence.rules().kindAvailable(ObjectKind.COLUMN));assertTrue(evidence.rules().kindAvailable(ObjectKind.CONSTRAINT));assertFalse(evidence.rules().kindAvailable(ObjectKind.TRIGGER));
        var empty=new JsonObject();var before=triggers("CREATE TRIGGER exact_before");var after=triggers("CREATE TRIGGER exact_after");
        assertFalse(SchemaDiff.triggerLookupAvailable(evidence));assertFalse(SchemaDiff.triggerChangesAvailable(empty,before,evidence));assertFalse(SchemaDiff.triggerChangesAvailable(before,empty,evidence));assertFalse(SchemaDiff.triggerChangesAvailable(before,after,evidence));
        assertTrue(SchemaDiff.triggerChangesAvailable(before,before.deepCopy(),evidence));assertTrue(SchemaDiff.triggerChangesAvailable(empty,empty.deepCopy(),evidence));
    }
    @Test void supportedEnginesRetainTriggerGenerationWhileFalsePhysicalAffinityStillDeniesIt(){
        var empty=new JsonObject();var changed=triggers("CREATE TRIGGER exact_target");
        for(Engine engine:new Engine[]{Engine.POSTGRESQL,Engine.MYSQL,Engine.MARIADB}){
            var evidence=evidence(engine,false);assertTrue(SchemaDiff.triggerLookupAvailable(evidence));assertTrue(SchemaDiff.triggerChangesAvailable(empty,changed,evidence));assertTrue(SchemaDiff.triggerChangesAvailable(changed,empty,evidence));
            assertFalse(SchemaDiff.triggerChangesAvailable(empty,changed,evidence.withIdentifierAvailability(false)));
        }
        assertTrue(SchemaDiff.triggerLookupAvailable(evidence(Engine.MYSQL,true)),"The unsupported capability belongs specifically to MariaDB trigger lookup");
    }
}
