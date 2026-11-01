package io.busystack.busydata;
import io.busystack.busydata.schema.DdlParts;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
class DdlPartsTest {
 @Test void nativeColumnAndConstraintFragmentsRetainQuotedCommaAndGeneratedExpressions(){
  String sql="CREATE TABLE `漢``name` (\n `a` varchar(20) DEFAULT 'a,b)',\n `n` int GENERATED ALWAYS AS ((1+2)*3) STORED,\n KEY `a_idx` (`a`),\n CONSTRAINT `fk` FOREIGN KEY (`n`) REFERENCES `other` (`id`)\n) ENGINE=InnoDB COLLATE=utf8mb4_bin";
  var parts=DdlParts.table(sql);assertEquals(4,parts.parts().size());assertEquals("a",DdlParts.leadingIdentifier(parts.parts().get(0)));assertEquals("漢`name",DdlParts.leadingIdentifier("`漢``name` varchar(8)"));
  assertEquals("`a` varchar(20) DEFAULT 'a,b)'",parts.parts().get(0));assertTrue(parts.render(parts.parts().subList(0,3)).endsWith("ENGINE=InnoDB COLLATE=utf8mb4_bin"));assertFalse(parts.render(parts.parts().subList(0,3)).contains("FOREIGN KEY"));
 }
 @Test void malformedAndDeepDefinitionsFailBeforeUnboundedParsing(){assertThrows(IllegalArgumentException.class,()->DdlParts.table("CREATE TABLE x (n int"));assertThrows(IllegalArgumentException.class,()->DdlParts.table("CREATE TABLE x ("+"(".repeat(65)+"n"+")".repeat(65)+")"));}
}
