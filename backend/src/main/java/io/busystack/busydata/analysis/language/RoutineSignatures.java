package io.busystack.busydata.analysis.language;

import io.busystack.busydata.protocol.*;
import java.util.*;

/** Signature metadata is captured with the central snapshot; no name-only JDBC discovery. */
public final class RoutineSignatures {
    public record Parameter(String name,String mode,SqlTypes.Type type,boolean optional,boolean variadic,String defaultExpression){}
    public record Signature(String identity,String name,String catalog,String schema,String display,List<Parameter> parameters,SqlTypes.Type returns,boolean complete) {
        public Signature {parameters=List.copyOf(parameters);}
        public int minimumArguments(){return (int)parameters.stream().filter(p->!Set.of("OUT","TABLE","RETURN").contains(p.mode())&&!p.optional()&&!p.variadic()).count();}
        public int maximumArguments(){return parameters.stream().anyMatch(Parameter::variadic)?Integer.MAX_VALUE:(int)parameters.stream().filter(p->!Set.of("OUT","TABLE","RETURN").contains(p.mode())).count();}
        public boolean accepts(int count){return !complete||count>=minimumArguments()&&count<=maximumArguments();}
        public RoutineSignature protocol(){var out=RoutineSignature.newBuilder().setIdentity(identity).setName(name).setSignature(display).setReturnType(returns.nativeName());for(var p:parameters)out.addParameters(RoutineParameter.newBuilder().setName(p.name()).setMode(p.mode()).setNativeType(p.type().nativeName()).setOptional(p.optional()).setVariadic(p.variadic()).setDefaultExpression(p.defaultExpression()));return out.build();}
    }
    private RoutineSignatures(){}
    public static Signature from(SchemaObject object,Engine engine){
        var p=object.getPropertiesMap();int count=SqlTypes.integer(p.get("parameterCount"),-1);var parameters=new ArrayList<Parameter>();
        for(int i=0;i<Math.min(1024,Math.max(0,count));i++){String prefix="parameter."+i+".";parameters.add(new Parameter(p.getOrDefault(prefix+"name",""),p.getOrDefault(prefix+"mode","IN"),SqlTypes.nativeType(p.getOrDefault(prefix+"type","unknown"),engine),p.containsKey(prefix+"default")||Boolean.parseBoolean(p.getOrDefault(prefix+"optional","false")),Boolean.parseBoolean(p.getOrDefault(prefix+"variadic","false")),p.getOrDefault(prefix+"default","")));}
        String signature=p.getOrDefault("signature",object.getName()+"("+String.join(", ",parameters.stream().map(v->v.type().nativeName()).toList())+")");
        String identity=object.getStableIdentity().isEmpty()?object.getIdentifier():object.getStableIdentity();
        return new Signature(identity,object.getName(),object.getCatalog(),object.getSchema(),signature,parameters,SqlTypes.nativeType(p.getOrDefault("returnType","unknown"),engine),count>=0&&p.getOrDefault("signatureAvailability","available").equalsIgnoreCase("available"));
    }
    /** Small specified core; all server/user overloads come from metadata. */
    public static List<Signature> builtins(Engine engine){
        var result=new ArrayList<Signature>();
        result.add(builtin("count","bigint",List.of(parameter("expression","unknown",false,false,engine)),engine));
        for(String name:List.of("min","max","sum","avg","abs"))result.add(builtin(name,"unknown",List.of(parameter("expression","unknown",false,false,engine)),engine));
        for(String name:List.of("lower","upper","length"))result.add(builtin(name,name.equals("length")?"integer":"text",List.of(parameter("text","text",false,false,engine)),engine));
        result.add(builtin("coalesce","unknown",List.of(parameter("value","unknown",false,false,engine),parameter("values","unknown",false,true,engine)),engine));
        result.add(builtin("nullif","unknown",List.of(parameter("value1","unknown",false,false,engine),parameter("value2","unknown",false,false,engine)),engine));
        for(String name:List.of("row_number","rank","dense_rank"))result.add(builtin(name,"bigint",List.of(),engine));
        if(engine==Engine.POSTGRESQL){
            result.add(builtin("date_trunc","timestamp",List.of(parameter("field","text",false,false,engine),parameter("source","timestamp",false,false,engine)),engine));
            result.add(builtin("date_trunc","timestamptz",List.of(parameter("field","text",false,false,engine),parameter("source","timestamptz",false,false,engine)),engine));
            result.add(builtin("date_trunc","interval",List.of(parameter("field","text",false,false,engine),parameter("source","interval",false,false,engine)),engine));
            result.add(builtin("date_trunc","timestamptz",List.of(parameter("field","text",false,false,engine),parameter("source","timestamptz",false,false,engine),parameter("timezone","text",false,false,engine)),engine));
            for(String name:List.of("json_build_object","jsonb_build_object"))result.add(builtin(name,name.startsWith("jsonb")?"jsonb":"json",List.of(parameter("pairs","unknown",false,true,engine)),engine));
        }
        else {result.add(builtin("date_format","text",List.of(parameter("date","datetime",false,false,engine),parameter("format","text",false,false,engine)),engine));result.add(builtin("json_object","json",List.of(parameter("pairs","unknown",false,true,engine)),engine));}
        return List.copyOf(result);
    }
    private static Parameter parameter(String name,String type,boolean optional,boolean variadic,Engine engine){return new Parameter(name,"IN",SqlTypes.nativeType(type,engine),optional,variadic,"");}
    private static Signature builtin(String name,String result,List<Parameter> parameters,Engine engine){return new Signature("builtin:"+engine.name()+":"+name+"("+String.join(",",parameters.stream().map(p->p.type().nativeName()).toList())+")",name,"","",name+"("+String.join(", ",parameters.stream().map(p->p.name()+" "+p.type().nativeName()+(p.variadic()?"...":"")).toList())+")",parameters,SqlTypes.nativeType(result,engine),true);}
}
