package io.busystack.busydata;

import io.busystack.busydata.schema.SnapshotJson;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class SnapshotJsonTest {
    private static String escape(String hex){return "\\"+"u"+hex;}
    private static String array(String value,int count){return "{\"values\":["+String.join(",",Collections.nCopies(count,value))+"]}";}
    @Test void strictTreeRetainsExactLazyNumberLexemesAndOrdinaryJsonValues(){
        String integer="1234567890123456789012345678901234567890",decimal="1.2345678901234567890123456789e+1234";
        var object=SnapshotJson.read("{\"integer\":"+integer+",\"decimal\":"+decimal+",\"negativeZero\":-0,\"nested\":[true,false,null,{\"s\":\"literal\"}]}");
        assertTrue(object.get("integer").getAsJsonPrimitive().isNumber());assertEquals(integer,object.get("integer").getAsString());assertEquals(decimal,object.get("decimal").getAsNumber().toString());assertEquals("-0",object.get("negativeZero").getAsString());
        var nested=object.getAsJsonArray("nested");assertTrue(nested.get(0).getAsBoolean());assertFalse(nested.get(1).getAsBoolean());assertTrue(nested.get(2).isJsonNull());assertEquals("literal",nested.get(3).getAsJsonObject().get("s").getAsString());
    }
    @Test void duplicateDecodedKeysAreRejectedAtEveryObjectButIndependentObjectsRemainValid(){
        for(String json:List.of("{\"a\":1,\"a\":2}","{\"a\":1,\""+escape("0061")+"\":2}","{\"outer\":{\"x\":1,\"x\":2}}","{\"a\\\\b\":1,\"a"+escape("005c")+"b\":2}"))assertThrows(IllegalArgumentException.class,()->SnapshotJson.read(json));
        assertEquals(2,SnapshotJson.read("{\"left\":{\"same\":1},\"right\":{\"same\":2}}").size());
        assertEquals(2,SnapshotJson.read("{\"é\":1,\"e"+escape("0301")+"\":2}").size(),"Decoded key equality does not invent Unicode normalization");
    }
    @Test void numericBooleanAndNullArraysCannotBypassTheAllNodeBudget(){
        // Root object + name + array consume three of the 100000 nodes.
        assertEquals(99_997,SnapshotJson.read(array("0",99_997)).getAsJsonArray("values").size());
        for(String value:List.of("0","false","null"))assertThrows(IllegalArgumentException.class,()->SnapshotJson.read(array(value,99_998)));
    }
    @Test void objectNamesValuesAndEmptyContainersAllConsumeTheNodeBudget(){
        var object=new StringBuilder("{");for(int i=0;i<50_000;i++){if(i>0)object.append(',');object.append('"').append(i).append("\":0");}object.append('}');
        assertThrows(IllegalArgumentException.class,()->SnapshotJson.read(object.toString()));
        assertThrows(IllegalArgumentException.class,()->SnapshotJson.read(array("{}",99_998)));
    }
    @Test void commentsUnquotedKeysOtherLenientSyntaxAndTrailingRootsAreRejected(){
        for(String json:List.of("{/* comment */\"a\":1}","{\"a\":1}// comment","{a:1}","{'a':1}","{\"a\":NaN}","{\"a\":Infinity}","{\"a\":01}","{\"a\":1,}","{\"a\":[1,]}","{} {}","{} null","{} true"))assertThrows(IllegalArgumentException.class,()->SnapshotJson.read(json),json);
        for(String root:List.of("[]","null","true","1","\"text\"",""))assertThrows(IllegalArgumentException.class,()->SnapshotJson.read(root));
    }
    @Test void literalAndEscapedUtf16MustFormCompleteScalarPairsInNamesAndValues(){
        String pair=escape("d83d")+escape("de00");var valid=SnapshotJson.read("{\""+pair+"\":\""+pair+"\",\"literal\":\"😀\"}");assertEquals("😀",valid.get("😀").getAsString());assertEquals("😀",valid.get("literal").getAsString());
        for(String broken:List.of(escape("d800"),escape("dc00"),escape("d800")+"x"+escape("dc00"),escape("d800")+escape("d801"),String.valueOf((char)0xd800),String.valueOf((char)0xdc00))){
            assertThrows(IllegalArgumentException.class,()->SnapshotJson.read("{\"value\":\""+broken+"\"}"));assertThrows(IllegalArgumentException.class,()->SnapshotJson.read("{\""+broken+"\":0}"));
        }
        assertThrows(IllegalArgumentException.class,()->SnapshotJson.read("{\"value\":\""+(char)0x1f+"\"}"));assertEquals("\n",SnapshotJson.read("{\"value\":\"\\n\"}").get("value").getAsString());
    }
    @Test void existingInputRawStringAndNestingCapsRemainEnforced(){
        assertThrows(IllegalArgumentException.class,()->SnapshotJson.read(" ".repeat(8_388_609)));
        String atLimit="x".repeat(1_048_575);assertEquals(atLimit,SnapshotJson.read("{\"s\":\""+atLimit+"\"}").get("s").getAsString());assertThrows(IllegalArgumentException.class,()->SnapshotJson.read("{\"s\":\""+atLimit+"x\"}"));
        assertThrows(IllegalArgumentException.class,()->SnapshotJson.read("{\"s\":\""+escape("0061").repeat(174_763)+"\"}"),"Escaped strings retain the original raw-source limit");
        assertDoesNotThrow(()->SnapshotJson.read("{\"n\":"+"[".repeat(31)+"0"+"]".repeat(31)+"}"));assertThrows(IllegalArgumentException.class,()->SnapshotJson.read("{\"n\":"+"[".repeat(32)+"0"+"]".repeat(32)+"}"));
    }
    @Test void failuresDoNotIncludeArtifactNamesOrPayloads(){
        String secret="private_definition_payload";var duplicate=assertThrows(IllegalArgumentException.class,()->SnapshotJson.read("{\""+secret+"\":1,\""+secret+"\":2}"));assertFalse(duplicate.getMessage().contains(secret));
        var malformed=assertThrows(IllegalArgumentException.class,()->SnapshotJson.read("{\""+secret+"\":unquoted_private_value}"));assertFalse(malformed.getMessage().contains(secret));assertFalse(malformed.getMessage().contains("unquoted_private_value"));
    }
}
