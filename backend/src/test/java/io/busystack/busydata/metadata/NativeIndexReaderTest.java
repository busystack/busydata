package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.*;
import java.lang.reflect.Proxy;
import java.sql.*;
import java.util.*;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class NativeIndexReaderTest {
    private static Map<String,Object> row(String name,int ordinal,String column){
        var row=new HashMap<String,Object>();row.put("name",name);row.put("ordinal",ordinal);row.put("column_name",column);row.put("expression",column);row.put("expression_bytes",column==null?0:column.length());
        row.put("included","false");row.put("expression_part","false");row.put("ordering","ASC");row.put("non_unique","false");row.put("method","btree");row.put("predicate",null);row.put("predicate_bytes",0);row.put("partial","false");
        row.put("key_count","1");row.put("total_count","1");row.put("nulls_not_distinct","false");row.put("primary_key","false");row.put("valid","true");row.put("ready","true");row.put("live","true");row.put("prefix_length",null);return row;
    }
    private static ResultSet rows(List<Map<String,Object>> values){
        var position=new AtomicInteger(-1);
        return (ResultSet)Proxy.newProxyInstance(ResultSet.class.getClassLoader(),new Class[]{ResultSet.class},(proxy,method,args)->{
            if(method.getName().equals("next"))return position.incrementAndGet()<values.size();if(method.getName().equals("close"))return null;
            if(!Set.of("getString","getInt","getLong").contains(method.getName()))throw new AssertionError("Unexpected row operation: "+method.getName());
            var row=values.get(position.get());var value=row.get((String)args[0]);if(!row.containsKey((String)args[0]))throw new AssertionError("Unknown row column: "+args[0]);
            return switch(method.getName()){case "getString"->value==null?null:value.toString();case "getInt"->value==null?0:((Number)value).intValue();case "getLong"->value==null?0L:((Number)value).longValue();default->throw new AssertionError();};
        });
    }
    private static List<SchemaObject> read(Engine engine,List<Map<String,Object>> values)throws Exception {try(var rows=rows(values)){return NativeIndexReader.components(engine,"db","schema","table",rows);}}
    @Test void postgresNullPolicyKeyCountAndIncludeAttributesStaySeparate()throws Exception {
        var key=row("unique_include",1,"key");var included=row("unique_include",2,"payload");included.put("included","true");
        for(var value:List.of(key,included)){value.put("total_count","2");value.put("nulls_not_distinct","true");}
        var actual=read(Engine.POSTGRESQL,List.of(key,included)).getFirst();
        assertEquals("NOT_DISTINCT",actual.getPropertiesOrThrow("uniqueNullsPolicy"));assertEquals("1",actual.getPropertiesOrThrow("keyColumnCount"));assertEquals("2",actual.getPropertiesOrThrow("columnCount"));
        assertEquals("false",actual.getPropertiesOrThrow("included.0"));assertEquals("true",actual.getPropertiesOrThrow("included.1"));assertEquals("AVAILABLE",actual.getPropertiesOrThrow("indexStateAvailability"));
    }
    @Test void mysqlAndMariaHaveDeclaredDistinctNullPolicyWithoutInventingPgState()throws Exception {
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB)){
            var first=row("unique",1,"first");var second=row("unique",2,"second");
            for(var value:List.of(first,second)){value.put("key_count",null);value.put("total_count",null);value.put("non_unique","0");value.put("valid",null);value.put("ready",null);value.put("live",null);value.put("expression",null);value.put("expression_bytes",0);}
            var actual=read(engine,List.of(first,second)).getFirst();
            assertEquals("DISTINCT",actual.getPropertiesOrThrow("uniqueNullsPolicy"));assertEquals("2",actual.getPropertiesOrThrow("keyColumnCount"));assertEquals("NOT_EXPOSED",actual.getPropertiesOrThrow("indexStateAvailability"));
            assertFalse(actual.containsProperties("valid"));assertFalse(actual.containsProperties("ready"));assertFalse(actual.containsProperties("live"));
        }
    }
    @Test void truncatedPredicateKeepsNativePartialFlagAndAvailability()throws Exception {
        var value=row("partial",1,"code");value.put("partial","true");value.put("predicate_bytes",8193);value.put("predicate",null);
        var actual=read(Engine.POSTGRESQL,List.of(value)).getFirst();assertEquals("true",actual.getPropertiesOrThrow("partial"));assertEquals("LIMITED",actual.getPropertiesOrThrow("predicateAvailability"));assertEquals("",actual.getPropertiesOrThrow("predicate"));
    }
    @Test void unavailableExpressionCannotBecomeAPlainColumn()throws Exception {
        var value=row("expression",1,null);value.put("expression_part","true");value.put("expression_bytes",8193);
        var actual=read(Engine.POSTGRESQL,List.of(value)).getFirst();assertEquals("EXPRESSION",actual.getPropertiesOrThrow("keyKind.0"));assertEquals("LIMITED",actual.getPropertiesOrThrow("expressionAvailability.0"));assertFalse(actual.containsProperties("column.0"));
    }
    @Test void unavailableNativeBodiesAreDistinctFromAbsentProperties()throws Exception {
        var predicate=row("partial",1,"code");predicate.put("partial","true");
        assertEquals("UNAVAILABLE",read(Engine.POSTGRESQL,List.of(predicate)).getFirst().getPropertiesOrThrow("predicateAvailability"));
        var expression=row("expression",1,null);expression.put("expression_part","true");
        assertEquals("UNAVAILABLE",read(Engine.POSTGRESQL,List.of(expression)).getFirst().getPropertiesOrThrow("expressionAvailability.0"));
    }
    @Test void missingOrRepeatedOrdinalsAndChangingIndexFactsAreRejected()throws Exception {
        var first=row("unique",1,"first");first.put("total_count","2");first.put("key_count","2");
        assertThrows(SQLException.class,()->read(Engine.POSTGRESQL,List.of(first)));
        assertThrows(SQLException.class,()->read(Engine.POSTGRESQL,List.of(first,new HashMap<>(first))));
        var second=row("unique",2,"second");second.put("total_count","2");second.put("key_count","2");second.put("nulls_not_distinct","true");
        assertThrows(SQLException.class,()->read(Engine.POSTGRESQL,List.of(first,second)));
    }
    @Test void unknownNativeBooleanOrMissingColumnDoesNotProduceCompleteMetadata()throws Exception {
        var unknown=row("unique",1,"code");unknown.put("nulls_not_distinct",null);assertThrows(SQLException.class,()->read(Engine.POSTGRESQL,List.of(unknown)));
        assertThrows(SQLException.class,()->read(Engine.POSTGRESQL,List.of(row("missing",1,null))));
    }
    @Test void nativeNullAndIncludeChangesAlterObjectFingerprint()throws Exception {
        var distinct=row("unique",1,"code");var notDistinct=new HashMap<>(distinct);notDistinct.put("nulls_not_distinct","true");
        assertNotEquals(MetadataFingerprint.objects(read(Engine.POSTGRESQL,List.of(distinct))),MetadataFingerprint.objects(read(Engine.POSTGRESQL,List.of(notDistinct))));
    }
}
