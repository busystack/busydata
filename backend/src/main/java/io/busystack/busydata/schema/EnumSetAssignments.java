package io.busystack.busydata.schema;

import io.busystack.busydata.metadata.NativeEnumSet;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.rpc.WorkbenchFailure;
import java.math.BigInteger;
import java.util.*;

/** Exact native ENUM/SET assignment transport; reviewed values remain labels.
 * Pinned MySQL/MariaDB store numeric ENUM ordinals and SET bit masks directly.
 * Binding strings instead can silently select a different collated member.
 */
final class EnumSetAssignments {
    private EnumSetAssignments(){}
    private static NativeEnumSet.Declaration declaration(SchemaObject column,Engine engine){
        if(engine!=Engine.MYSQL&&engine!=Engine.MARIADB)return null;
        String kind=column.getPropertiesOrDefault("nativeTypeKind","");
        if(!kind.equals("enum")&&!kind.equals("set"))return null;
        if(!column.getPropertiesOrDefault("nativeTypeAvailability","").equals("AVAILABLE"))throw new WorkbenchFailure(WorkbenchFailure.Reason.INCOMPLETE_METADATA);
        var result=NativeEnumSet.decode(column.getPropertiesOrDefault("type",""),engine);
        if(!result.available()||(result.kind()==NativeEnumSet.Kind.ENUM)!=kind.equals("enum"))throw new WorkbenchFailure(WorkbenchFailure.Reason.UNSUPPORTED);
        return result;
    }
    static void verifyRetainedIdentity(SchemaObject column,Engine engine){
        var declaration=declaration(column,engine);if(declaration==null)return;
        var seen=new HashSet<String>();
        // The retained JDBC label cannot distinguish the error ordinal from a
        // declared empty member, or two physically distinct identical labels.
        for(String member:declaration.members())if(member.isEmpty()||!seen.add(member)||declaration.kind()==NativeEnumSet.Kind.SET&&member.contains(","))throw new WorkbenchFailure(WorkbenchFailure.Reason.UNSUPPORTED);
    }
    static Value bound(Value value,SchemaObject column,Engine engine){
        var declaration=declaration(column,engine);if(declaration==null||value.hasNullValue())return value;
        verifyRetainedIdentity(column,engine);
        if(!value.hasText())throw new WorkbenchFailure(WorkbenchFailure.Reason.MALFORMED_REQUEST);
        if(declaration.kind()==NativeEnumSet.Kind.ENUM){
            int index=declaration.members().indexOf(value.getText());
            if(index<0)throw new WorkbenchFailure(WorkbenchFailure.Reason.UNSUPPORTED);
            return Value.newBuilder().setSignedInteger(Integer.toString(index+1)).build();
        }
        BigInteger mask=BigInteger.ZERO;int previous=-1;
        if(!value.getText().isEmpty())for(String member:value.getText().split(",",-1)){
            int index=declaration.members().indexOf(member);
            if(index<0||index<=previous)throw new WorkbenchFailure(WorkbenchFailure.Reason.MALFORMED_REQUEST);
            mask=mask.setBit(index);previous=index;
        }
        return Value.newBuilder().setUnsignedInteger(mask.toString()).build();
    }
}
