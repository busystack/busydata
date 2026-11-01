package io.busystack.busydata;

import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import java.nio.file.Path;
import java.util.*;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

class JdbcMetadataPatternsIT {
    @TempDir Path root;
    @ParameterizedTest @ValueSource(strings={"MYSQL","MARIADB"})
    void exactWildcardNamesInvisibleColumnsAndNativeDefaultsSurviveNoBackslashMode(String engine)throws Exception {
        try(var fixture=new EngineFixture(root,engine)){
            var session=fixture.open();fixture.execute(session,"SET SESSION sql_mode='ANSI_QUOTES,NO_BACKSLASH_ESCAPES'");String name="metadata_%_values",table=session.adapter.table(session.context.catalog(),fixture.schema(),name);
            fixture.execute(session,"CREATE TABLE "+table+"(id INTEGER PRIMARY KEY, visible INTEGER NOT NULL, hidden INTEGER INVISIBLE, amount DECIMAL(38,12) DEFAULT 1.230000000000, modified TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP(6), computed INTEGER GENERATED ALWAYS AS (visible+1) STORED)");
            fixture.execute(session,"CREATE TABLE metadata_other_values(decoy VARCHAR(40))");fixture.warm(session,name);
            var snapshot=fixture.metadata.metadataPlatform().capture(session);var columns=snapshot.namespace(session.context.catalog(),fixture.schema(),ObjectKind.COLUMN,name);assertEquals(6,columns.size());var byName=new HashMap<String,MetadataObject>();for(var column:columns)byName.put(column.identity().name(),column);
            assertTrue(byName.containsKey("hidden"),"The prepared metadata projection must include invisible columns");assertFalse(byName.containsKey("decoy"));assertEquals("38",byName.get("amount").properties().get("precision"));assertEquals("12",byName.get("amount").properties().get("scale"));assertEquals("AVAILABLE",byName.get("amount").properties().get("defaultAvailability"));assertEquals("YES",byName.get("computed").properties().get("generated"));assertEquals("NO",byName.get("modified").properties().get("generated"));assertEquals("6",byName.get("modified").properties().get("nativeTemporalPrecision"));
            try(var statement=session.connection.createStatement();var rows=statement.executeQuery("SELECT @@sql_mode")){assertTrue(rows.next());assertTrue(rows.getString(1).contains("NO_BACKSLASH_ESCAPES"));assertTrue(rows.getString(1).contains("ANSI_QUOTES"));}
        }
    }
}
