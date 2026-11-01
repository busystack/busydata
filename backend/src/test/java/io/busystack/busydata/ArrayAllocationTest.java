package io.busystack.busydata;
import io.busystack.busydata.results.Values;
import io.busystack.busydata.protocol.*;
import java.sql.*;
import java.lang.reflect.Proxy;
import java.io.StringReader;
import java.util.concurrent.atomic.AtomicBoolean;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
class ArrayAllocationTest {
 private static ResultSet array(String raw,Object values,AtomicBoolean allocated) {
  var array=(java.sql.Array)Proxy.newProxyInstance(ArrayAllocationTest.class.getClassLoader(),new Class[]{java.sql.Array.class},(p,m,args)->{if(m.getName().equals("getArray")){allocated.set(true);return values;}if(m.getName().equals("free"))return null;throw new UnsupportedOperationException(m.getName());});
  return (ResultSet)Proxy.newProxyInstance(ArrayAllocationTest.class.getClassLoader(),new Class[]{ResultSet.class},(p,m,args)->switch(m.getName()){case "getCharacterStream"->new StringReader(raw);case "getObject"->array;default->throw new UnsupportedOperationException(m.getName());});
 }
 @Test void oversizedArraysAreRejectedBeforeTheDriverExpandsEveryElement() {
  var allocated=new AtomicBoolean();var column=Column.newBuilder().setJdbcType(Types.ARRAY).setTypeName("_int4").build();
  assertThrows(SQLException.class,()->Values.value(array("{"+"1,".repeat(20000)+"1}",new int[]{1},allocated),1,column));assertFalse(allocated.get());
  assertThrows(SQLException.class,()->Values.value(array("{".repeat(17)+"1"+"}".repeat(17),new int[]{1},allocated),1,column));assertFalse(allocated.get());
 }
 @Test void ordinaryArraysRetainExactTypedValuesWithinTheBudget()throws Exception {
  var allocated=new AtomicBoolean();var actual=Values.value(array("{1,2}",new Long[]{1L,2L},allocated),1,Column.newBuilder().setJdbcType(Types.ARRAY).setTypeName("_int8").build());
  assertTrue(allocated.get());assertTrue(actual.hasArray());assertEquals("1",actual.getArray().getValues(0).getSignedInteger());assertEquals("2",actual.getArray().getValues(1).getSignedInteger());assertFalse(actual.getTruncated());
 }
}
