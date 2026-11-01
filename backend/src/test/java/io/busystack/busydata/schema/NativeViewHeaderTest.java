package io.busystack.busydata.schema;

import io.busystack.busydata.analysis.LexicalSettings;
import io.busystack.busydata.metadata.MetadataSnapshot;
import io.busystack.busydata.metadata.MetadataState;
import io.busystack.busydata.protocol.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

/** Native fixed-SHOW prefix recognition, never general SQL or execution parsing. */
class NativeViewHeaderTest {
    private static NativeTableHeader.Header read(String text,Engine engine,String mode)throws Exception{return NativeTableHeader.parse(text,false,engine,LexicalSettings.mysql(mode));}
    @Test void actualNativeOptionsAndDefinersYieldOnlyAPersistentViewKind()throws Exception{
        for(var engine:new Engine[]{Engine.MYSQL,Engine.MARIADB}){
            var quoted=read("CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `db`.`quoted view` AS select 1",engine,"");
            assertEquals(MetadataSnapshot.PhysicalRelationKind.PERSISTENT,quoted.kind());assertEquals(ObjectKind.VIEW,quoted.objectKind());assertEquals("db",quoted.catalog());assertEquals("quoted view",quoted.name());assertEquals(MetadataState.AVAILABLE,quoted.nameAvailability());
            var plain=read("CREATE ALGORITHM=MERGE DEFINER=root@localhost SQL SECURITY INVOKER VIEW selected AS select 1",engine,"");assertEquals("selected",plain.name());assertEquals(ObjectKind.VIEW,plain.objectKind());
            var ansi=read("CREATE VIEW \"d\".\"v\" AS select 1",engine,"ANSI_QUOTES");assertEquals("d",ansi.catalog());assertEquals("v",ansi.name());assertEquals(ObjectKind.VIEW,ansi.objectKind());
        }
        assertEquals("v",read("CREATE ALGORITHM=UNDEFINED DEFINER=`role` SQL SECURITY DEFINER VIEW v AS select 1",Engine.MARIADB,"").name());
    }
    @Test void exactEscapesAndDerivedColumnListsDoNotBecomeCanonicalAliasAuthority()throws Exception{
        var view=read("CREATE ALGORITHM=TEMPTABLE DEFINER=`VIEW``user`@`AS``host` SQL SECURITY DEFINER VIEW `db``x`.`v``x` (`c``x`,`n`) AS SELECT 1,2",Engine.MYSQL,"");
        assertEquals("db`x",view.catalog());assertEquals("v`x",view.name());assertEquals(ObjectKind.VIEW,view.objectKind());
        var table=read("CREATE TEMPORARY TABLE `view` (`n` INTEGER)",Engine.MARIADB,"");assertEquals(ObjectKind.TABLE,table.objectKind());assertEquals(MetadataSnapshot.PhysicalRelationKind.TEMPORARY,table.kind());
    }
    @Test void incompleteOrOtherNativeObjectsCannotManufactureAnAvailableView()throws Exception{
        for(var text:new String[]{"CREATE ALGORITHM=UNKNOWN VIEW v AS select 1","CREATE DEFINER=`broken VIEW v AS select 1","CREATE SQL SECURITY UNKNOWN VIEW v AS select 1","CREATE VIEW v( AS select 1","CREATE TEMPORARY VIEW v AS select 1","/* VIEW */ CREATE VIEW v AS select 1","CREATE FUNCTION v() RETURNS INTEGER RETURN 1"}){
            var value=read(text,Engine.MYSQL,"");assertTrue(value.objectKind()!=ObjectKind.VIEW||value.nameAvailability()!=MetadataState.AVAILABLE,text);
        }
        var wrongQuotes=read("CREATE VIEW \"v\" AS select 1",Engine.MYSQL,"");assertNotEquals(MetadataState.AVAILABLE,wrongQuotes.nameAvailability());
    }
    @Test void aBoundedCompleteViewPrefixSurvivesAnOpaqueCutBody()throws Exception{
        String source="CREATE ALGORITHM=UNDEFINED DEFINER=root@localhost SQL SECURITY DEFINER VIEW v AS SELECT '"+"x".repeat(5000);
        var header=NativeTableHeader.parse(source.substring(0,NativeTableHeader.MAX_HEADER_UNITS),true,Engine.MYSQL,LexicalSettings.DEFAULT);assertEquals(ObjectKind.VIEW,header.objectKind());assertEquals("v",header.name());assertEquals(MetadataState.AVAILABLE,header.nameAvailability());
        var cut=NativeTableHeader.parse("CREATE VIEW `"+"x".repeat(NativeTableHeader.MAX_HEADER_UNITS-13),true,Engine.MYSQL,LexicalSettings.DEFAULT);assertEquals(ObjectKind.VIEW,cut.objectKind());assertEquals(MetadataState.LIMITED,cut.nameAvailability());assertTrue(cut.name().isEmpty());
    }
}
