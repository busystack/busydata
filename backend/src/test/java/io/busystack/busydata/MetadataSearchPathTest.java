package io.busystack.busydata;

import io.busystack.busydata.metadata.MetadataSearchPath;
import java.util.List;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class MetadataSearchPathTest {
    @Test void implicitTemporaryAndCatalogPrecedeTheExplicitPath(){assertEquals(List.of("pg_temp_7","pg_catalog","public"),MetadataSearchPath.postgres(List.of("public"),"pg_temp_7",true));}
    @Test void explicitTemporaryAndCatalogPositionsAreRespected(){
        assertEquals(List.of("pg_catalog","public","pg_temp_7"),MetadataSearchPath.postgres(List.of("public","pg_temp"),"pg_temp_7",true));
        assertEquals(List.of("public","pg_catalog","pg_temp_7"),MetadataSearchPath.postgres(List.of("public","pg_catalog","pg_temp_7"),"pg_temp_7",true));
        assertEquals(List.of("pg_temp_7","public","pg_catalog"),MetadataSearchPath.postgres(List.of("pg_temp","public","pg_catalog"),"pg_temp_7",true));
    }
    @Test void unqualifiedRoutineAndOperatorPathsNeverContainTemporarySchemas(){assertEquals(List.of("public","pg_catalog"),MetadataSearchPath.postgres(List.of("pg_temp","public","pg_catalog","pg_temp_8"),"pg_temp_7",false));}
    @Test void absentTemporaryNamespaceDoesNotInventASchemaAndDuplicateScopesAreStable(){assertEquals(List.of("pg_catalog","public"),MetadataSearchPath.postgres(List.of("pg_temp","public","public"),"",true));}
}
