package io.busystack.busydata.schema;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.rpc.WorkbenchFailure;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class EnumSetAssignmentsTest {
    private static SchemaObject column(String declaration){return SchemaObject.newBuilder().putProperties("nativeTypeKind",declaration.startsWith("enum")?"enum":"set").putProperties("nativeTypeAvailability","AVAILABLE").putProperties("type",declaration).build();}
    private static Value text(String value){return Value.newBuilder().setText(value).build();}
    @Test void collatedAndNumericLabelsBindTheirDeclaredNativeOrdinals(){
        for(var engine:new Engine[]{Engine.MYSQL,Engine.MARIADB}){
            assertEquals("2",EnumSetAssignments.bound(text("A"),column("enum('a','A','2')"),engine).getSignedInteger());
            assertEquals("3",EnumSetAssignments.bound(text("2"),column("enum('a','A','2')"),engine).getSignedInteger());
            assertEquals("3",EnumSetAssignments.bound(text("a,A"),column("set('a','A')"),engine).getUnsignedInteger());
            assertEquals("0",EnumSetAssignments.bound(text(""),column("set('a','A')"),engine).getUnsignedInteger());
            var reviewed=text("A");EnumSetAssignments.bound(reviewed,column("enum('a','A')"),engine);assertEquals("A",reviewed.getText());
        }
    }
    @Test void setUsesAllSixtyFourBitsWithoutSignedOrFloatingPointConversion(){
        String declaration="set("+java.util.stream.IntStream.range(0,64).mapToObj(index->"'m"+index+"'").collect(java.util.stream.Collectors.joining(","))+")";
        assertEquals("9223372036854775808",EnumSetAssignments.bound(text("m63"),column(declaration),Engine.MYSQL).getUnsignedInteger());
        assertEquals("9223372036854775809",EnumSetAssignments.bound(text("m0,m63"),column(declaration),Engine.MARIADB).getUnsignedInteger());
    }
    @Test void ambiguousOrUnavailableDeclarationsNeverAuthorizeRetainedEditing(){
        for(String declaration:new String[]{"enum('a','a')","enum('','a')","set('a','a')","set('','a')","set('a,b','c')"})assertEquals(WorkbenchFailure.Reason.UNSUPPORTED,assertThrows(WorkbenchFailure.class,()->EnumSetAssignments.verifyRetainedIdentity(column(declaration),Engine.MYSQL)).reason());
        var unavailable=column("enum('a')").toBuilder().putProperties("nativeTypeAvailability","DENIED").build();
        assertEquals(WorkbenchFailure.Reason.INCOMPLETE_METADATA,assertThrows(WorkbenchFailure.class,()->EnumSetAssignments.verifyRetainedIdentity(unavailable,Engine.MARIADB)).reason());
        assertThrows(WorkbenchFailure.class,()->EnumSetAssignments.bound(text("b,a"),column("set('a','b')"),Engine.MYSQL));
    }
}
