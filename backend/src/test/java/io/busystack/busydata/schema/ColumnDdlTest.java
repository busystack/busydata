package io.busystack.busydata.schema;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class ColumnDdlTest {
    @Test void explicitCharacterSetsAlwaysRetainTheActualCapturedCollation(){
        String actual=ColumnDdl.canonicalProperties("`text` text DEFAULT NULL","utf8mb4","utf8mb4_unicode_ci");
        assertEquals("`text` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL",actual);
        assertEquals(actual,ColumnDdl.canonicalProperties(actual,"utf8mb4","utf8mb4_unicode_ci"));
        assertEquals(actual,ColumnDdl.canonicalProperties("`text` text COLLATE utf8mb4_unicode_ci DEFAULT NULL","utf8mb4","utf8mb4_unicode_ci"));
    }
    @Test void redundantExplicitCharacterSetIsCanonicalButDifferentSetsRemainDifferent(){
        String implicit="`t` varchar(300) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'CHARACTER SET literal'";
        String explicit="`t` varchar(300) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'CHARACTER SET literal'";
        assertEquals(ColumnDdl.canonicalCharacterSet(implicit,"utf8mb4"),ColumnDdl.canonicalCharacterSet(explicit,"utf8mb4"));
        assertNotEquals(ColumnDdl.canonicalCharacterSet(implicit,"utf8mb4"),ColumnDdl.canonicalCharacterSet(implicit,"latin1"));
    }
    @Test void targetedChangesRetainNativeAttributesAndExpressionQuoting(){
        String definition="`漢``x` varchar(40) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL DEFAULT 'DEFAULT;comma,quote''s' COMMENT 'retain' INVISIBLE";
        var changed=ColumnDdl.change(definition,"type","varchar(80)");
        assertTrue(changed.contains("CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL DEFAULT 'DEFAULT;comma,quote''s' COMMENT 'retain' INVISIBLE"));
        changed=ColumnDdl.change(changed,"default","concat('a,b', 'NOT NULL')");
        assertTrue(changed.contains("DEFAULT concat('a,b', 'NOT NULL') COMMENT 'retain' INVISIBLE"));
        changed=ColumnDdl.change(changed,"nullable","true");assertFalse(changed.contains(" NOT NULL DEFAULT"));assertTrue(changed.endsWith("COMMENT 'retain' INVISIBLE"));
    }
    @Test void generatedAndIdentityAreChangedWithoutDroppingOtherClauses(){
        assertEquals("`g` int GENERATED ALWAYS AS (n+2) STORED NOT NULL COMMENT 'x'",ColumnDdl.change("`g` int GENERATED ALWAYS AS ((n + 1)) STORED NOT NULL COMMENT 'x'","generated","n+2"));
        assertEquals("`id` bigint NOT NULL  COMMENT 'x'",ColumnDdl.change("`id` bigint NOT NULL AUTO_INCREMENT COMMENT 'x'","identity","none"));
    }
}
