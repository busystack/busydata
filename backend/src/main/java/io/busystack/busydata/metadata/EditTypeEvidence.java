package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.*;

/** Request-local type evidence from the published type object; never a second catalog. */
public final class EditTypeEvidence {
    private EditTypeEvidence(){}
    public static SchemaObject forColumn(MetadataSnapshot snapshot,SchemaObject column){return forColumn(snapshot,column,ignored->{});}
    /** The reviewed-operation caller admits bounded enrichment before it is allocated. */
    static SchemaObject forColumn(MetadataSnapshot snapshot,SchemaObject column,java.util.function.LongConsumer reserve){
        if(snapshot!=null&&(snapshot.rules().engine()==Engine.MYSQL||snapshot.rules().engine()==Engine.MARIADB)){
            String kind=column.getPropertiesOrDefault("nativeTypeKind","");if(!kind.equals("enum")&&!kind.equals("set"))return column;
            if(!column.getPropertiesOrDefault("nativeTypeAvailability","").equals("AVAILABLE"))return column;
            reserve.accept(4096L+16L*column.getPropertiesOrDefault("type","").length());
            var declaration=NativeEnumSet.decode(column.getPropertiesOrDefault("type",""),snapshot.rules().engine());var result=column.toBuilder();String prefix=kind.equals("enum")?"enumLabel":"setMember";
            result.putProperties(prefix+"sAvailability",declaration.availability().name());
            if(declaration.available()&&(declaration.kind()==NativeEnumSet.Kind.ENUM)==kind.equals("enum")){result.putProperties(prefix+"Count",Integer.toString(declaration.members().size()));for(int index=0;index<declaration.members().size();index++)result.putProperties(prefix+"."+index,declaration.members().get(index));}
            return result.build();
        }
        if(snapshot==null||!column.getPropertiesOrDefault("nativeTypeKind","").equals("e"))return column;
        String nativeId=column.getPropertiesOrDefault("nativeTypeId","");if(nativeId.isEmpty())return column;
        MetadataObject found=null;
        for(var type:snapshot.kind(ObjectKind.TYPE))if(type.identity().catalog().equals(column.getCatalog())&&type.properties().getOrDefault("nativeId","").equals(nativeId)){
            if(found!=null)return column;found=type;
        }
        if(found==null||found.state()!=MetadataState.AVAILABLE||!found.level().includes(IntrospectionLevel.STRUCTURE))return column;
        long bytes=4096L+256L*found.properties().size();for(var property:found.properties().entrySet())bytes+=8L*(property.getKey().length()+property.getValue().length());reserve.accept(bytes);
        var result=column.toBuilder();
        for(var property:found.properties().entrySet())if(property.getKey().equals("enumLabelCount")||property.getKey().equals("enumLabelsAvailability")||property.getKey().startsWith("enumLabel."))result.putProperties(property.getKey(),property.getValue());
        return result.build();
    }
}
