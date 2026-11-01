package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.*;
import java.lang.reflect.Proxy;
import java.sql.*;
import java.util.*;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

/** Component assembly only; real-engine gates exercise the catalog joins. */
class StructuralDetailsTest {
    private static SchemaObject constraint(String name,String type){return SchemaObject.newBuilder().setKind(ObjectKind.CONSTRAINT).setName(name).setCatalog("db").setSchema("schema").setTable("table").putProperties("type",type).build();}
    private static Map<String,Object> row(String name,String type,int ordinal,String column,String expression,long bytes){
        var row=new HashMap<String,Object>();row.put("name",name);row.put("type",type);row.put("native_id","");row.put("ordinal",ordinal);row.put("column_name",column);row.put("expression",expression);row.put("expression_bytes",bytes);row.put("deferrable","false");row.put("initially_deferred","false");row.put("validated","true");return row;
    }
    private static ResultSet rows(List<Map<String,Object>> values){
        var cursor=new AtomicInteger(-1);
        return (ResultSet)Proxy.newProxyInstance(ResultSet.class.getClassLoader(),new Class[]{ResultSet.class},(proxy,method,args)->{
            if(method.getName().equals("next"))return cursor.incrementAndGet()<values.size();
            if(method.getName().equals("close"))return null;
            if(!Set.of("getString","getInt","getLong").contains(method.getName()))throw new AssertionError("Unexpected JDBC row operation: "+method.getName());
            var row=values.get(cursor.get());String field=(String)args[0];if(!row.containsKey(field))throw new AssertionError("Unknown fixture column: "+field);var value=row.get(field);
            return switch(method.getName()){case "getString"->value==null?null:value.toString();case "getInt"->value==null?0:((Number)value).intValue();case "getLong"->value==null?0L:((Number)value).longValue();default->throw new AssertionError();};
        });
    }
    @Test void sameNamedCheckForeignAndUniqueComponentsStayInTheirActualNamespaces()throws Exception {
        var objects=List.of(constraint("shared","CHECK"),constraint("shared","FOREIGN KEY"),constraint("shared","UNIQUE"));
        try(var rows=rows(List.of(row("shared","FOREIGN KEY",1,"parent_id",null,0),row("shared","UNIQUE",1,"code",null,0),row("shared","CHECK",0,null,"(`amount` > 0)",14)))){
            var actual=StructuralDetails.constraintComponents(objects,rows);assertEquals(3,actual.size());
            assertEquals("CHECK",actual.get(0).getPropertiesOrThrow("type"));assertEquals("(`amount` > 0)",actual.get(0).getPropertiesOrThrow("expression"));assertFalse(actual.get(0).containsProperties("columnCount"));
            assertEquals("FOREIGN KEY",actual.get(1).getPropertiesOrThrow("type"));assertEquals("parent_id",actual.get(1).getPropertiesOrThrow("column.0"));assertFalse(actual.get(1).containsProperties("expression"));
            assertEquals("UNIQUE",actual.get(2).getPropertiesOrThrow("type"));assertEquals("code",actual.get(2).getPropertiesOrThrow("column.0"));assertFalse(actual.get(2).containsProperties("expression"));
        }
    }
    @Test void postgresNativeIdentityTypeAndDefinitionRemainUnchanged()throws Exception {
        var object=constraint("native_fk","f").toBuilder().setIdentifier("retained-signature").setStableIdentity("retained-identity").putProperties("nativeId","4321").build();
        var row=row("native_fk","f",1,"parent_id","FOREIGN KEY (parent_id) REFERENCES parent(id)",47);row.put("deferrable","true");row.put("initially_deferred","true");row.put("validated","false");row.put("native_id","4321");
        try(var rows=rows(List.of(row))){
            var actual=StructuralDetails.constraintComponents(List.of(object),rows).getFirst();
            assertEquals(object.getIdentifier(),actual.getIdentifier());assertEquals(object.getStableIdentity(),actual.getStableIdentity());assertEquals("4321",actual.getPropertiesOrThrow("nativeId"));assertEquals("f",actual.getPropertiesOrThrow("type"));
            assertEquals(row.get("expression"),actual.getPropertiesOrThrow("expression"));assertEquals("true",actual.getPropertiesOrThrow("deferrable"));assertEquals("true",actual.getPropertiesOrThrow("initially_deferred"));assertEquals("false",actual.getPropertiesOrThrow("validated"));
        }
    }
    @Test void aMatchingNameCannotSupplyAnotherOrMissingConstraintType()throws Exception {
        for(var object:List.of(constraint("same","FOREIGN KEY"),constraint("same","")))try(var rows=rows(List.of(row("same","CHECK",0,null,"(n > 0)",7)))){
            assertThrows(SQLException.class,()->StructuralDetails.constraintComponents(List.of(object),rows));
        }
        try(var rows=rows(List.of(row("same",null,0,null,null,0)))){assertThrows(SQLException.class,()->StructuralDetails.constraintComponents(List.of(constraint("same","CHECK")),rows));}
        var changed=row("native","p",1,"id","PRIMARY KEY (id)",16);changed.put("native_id","4322");
        try(var rows=rows(List.of(changed))){assertThrows(SQLException.class,()->StructuralDetails.constraintComponents(List.of(constraint("native","p").toBuilder().putProperties("nativeId","4321").build()),rows));}
    }
    @Test void compositeOrdinalsAndLimitedCheckEvidenceRetainTheirAvailability()throws Exception {
        var objects=List.of(constraint("key","UNIQUE"),constraint("check","CHECK"));
        try(var rows=rows(List.of(row("key","UNIQUE",2,"second",null,0),row("check","CHECK",0,null,null,65537),row("key","UNIQUE",1,"first",null,0)))){
            var actual=StructuralDetails.constraintComponents(objects,rows);
            assertEquals("2",actual.get(0).getPropertiesOrThrow("columnCount"));assertEquals("first",actual.get(0).getPropertiesOrThrow("column.0"));assertEquals("second",actual.get(0).getPropertiesOrThrow("column.1"));assertEquals("NOT_APPLICABLE",actual.get(0).getPropertiesOrThrow("expressionAvailability"));
            assertEquals("LIMITED",actual.get(1).getPropertiesOrThrow("expressionAvailability"));assertFalse(actual.get(1).containsProperties("expression"));assertFalse(actual.get(1).containsProperties("columnCount"));
        }
    }
}
