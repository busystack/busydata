package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.sessions.SessionRegistry;
import java.sql.*;
import java.util.*;
import java.util.concurrent.TimeUnit;

/** Signature-aware native routine metadata, never name-only function discovery. */
public final class RoutineMetadataReader {
    private RoutineMetadataReader(){}
    public record Enriched(SchemaObject object,NativeRoutineSource source){}
    public static SchemaObject enrich(SessionRegistry.Session session,SchemaObject routine)throws SQLException {
        return enrichWithSource(session,routine,null,System.nanoTime()+TimeUnit.SECONDS.toNanos(10)).object();
    }
    /** The optional source belongs only to this exact acquisition. Callers may
     * reuse it for SOURCE projection, never retain an all-routine body cache. */
    public static Enriched enrichWithSource(SessionRegistry.Session session,SchemaObject routine,NativeRoutineSource source,long deadline)throws SQLException {
        boolean pg=session.profile.getEngine()==Engine.POSTGRESQL;
        String routineType=pg?"":switch(routine.getSubtype()){
            case FUNCTION->"FUNCTION";case PROCEDURE->"PROCEDURE";
            default->throw new SQLFeatureNotSupportedException("Exact routine kind is unavailable for parameter introspection","0A000");
        };
        String defaults="pg_get_expr(p.proargdefaults,0)";
        String sql=pg?"SELECT p.oid::text native_id,pg_get_function_identity_arguments(p.oid) signature,pg_get_function_result(p.oid) return_type,p.pronargs,p.pronargdefaults,p.provariadic::text variadic,CASE WHEN OCTET_LENGTH(pg_get_function_arguments(p.oid))<=65536 THEN pg_get_function_arguments(p.oid) ELSE NULL END argument_declarations,CASE WHEN OCTET_LENGTH("+defaults+")<=65536 THEN "+defaults+" ELSE NULL END default_expressions,OCTET_LENGTH("+defaults+") default_expression_bytes FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname=? AND p.proname=? AND p.proname||'('||pg_get_function_identity_arguments(p.oid)||')'=?":
            "SELECT ROUTINE_NAME native_id,ROUTINE_TYPE routine_type,'' signature,DTD_IDENTIFIER return_type,0 pronargs,0 pronargdefaults,'' variadic,'' argument_declarations FROM information_schema.ROUTINES WHERE BINARY ROUTINE_SCHEMA=BINARY ? AND BINARY ROUTINE_NAME=BINARY ? AND BINARY CONCAT(ROUTINE_TYPE,':',ROUTINE_NAME)=BINARY ?";
        var out=routine.toBuilder().clearDefinition();
        for(String key:List.copyOf(out.getPropertiesMap().keySet()))if(key.startsWith("parameter."))out.removeProperties(key);
        String nativeId="",defaultExpressions=null;int argumentCount=0,defaultCount=0;long defaultBytes=0;
        check(deadline);
        try(var statement=session.adapter.catalogStatement(session.connection,sql)) {
            statement.setMaxRows(2);statement.setString(1,routine.getSchema());statement.setString(2,routine.getName());statement.setString(3,routine.getIdentifier());
            try(var rows=statement.executeQuery()) {
                if(!rows.next())throw new SQLException("Routine overload identity changed during introspection","55000");
                if(!pg&&!routineType.equals(rows.getString("routine_type")))throw new SQLException("Routine kind changed during introspection","55000");
                nativeId=Objects.toString(rows.getString("native_id"),"");argumentCount=rows.getInt("pronargs");defaultCount=rows.getInt("pronargdefaults");
                out.putProperties("nativeId",nativeId).putProperties("returnType",Objects.toString(rows.getString("return_type"),""))
                    .putProperties("signature",routine.getName()+"("+Objects.toString(rows.getString("signature"),"")+")")
                    .putProperties("argumentDeclarations",Objects.toString(rows.getString("argument_declarations"),""));
                if(pg){defaultExpressions=rows.getString("default_expressions");defaultBytes=rows.getLong("default_expression_bytes");if(rows.wasNull())defaultBytes=0;}
                if(rows.next())throw new SQLException("Routine overload identity is ambiguous","55000");warnings(statement,session.connection,rows);
            }
        }
        // PARAMETERS includes ROUTINE_TYPE; ordinal zero is a function return,
        // never a procedure argument or a second same-named routine's parameter.
        String parameters=pg?"SELECT a.position,COALESCE(p.proargnames[a.position], '') parameter_name,COALESCE(p.proargmodes[a.position]::text,'i') parameter_mode,format_type(a.type_oid,NULL) native_type,a.type_oid::text type_oid FROM pg_catalog.pg_proc p CROSS JOIN LATERAL unnest(COALESCE(p.proallargtypes,p.proargtypes::oid[])) WITH ORDINALITY a(type_oid,position) WHERE p.oid=?::oid ORDER BY a.position":
            "SELECT "+RoutineFingerprintReader.parameterProjection()+" FROM information_schema.PARAMETERS WHERE BINARY SPECIFIC_SCHEMA=BINARY ? AND BINARY SPECIFIC_NAME=BINARY ? AND BINARY ROUTINE_TYPE=BINARY ? ORDER BY ORDINAL_POSITION";
        int position=0,inputPosition=0;boolean returnSeen=false;var declarations=new ArrayList<RoutineDefaults.Parameter>();
        try(var statement=session.adapter.catalogStatement(session.connection,parameters)) {
            if(pg)statement.setString(1,nativeId);else{statement.setString(1,routine.getSchema());statement.setString(2,routine.getPropertiesOrDefault("specificName",routine.getName()));statement.setString(3,routineType);}
            try(var rows=statement.executeQuery()) {
                while(rows.next()) {
                    check(deadline);if(position>=1024)throw new IllegalArgumentException("Routine parameter budget exceeded");
                    int ordinal=rows.getInt("position");if(rows.wasNull()||ordinal<0)throw new SQLException("Routine parameter ordinal is unavailable","HY000");
                    if(ordinal==0){if(pg||!routineType.equals("FUNCTION")||position!=0||returnSeen)throw new SQLException("Routine return ordinal is contradictory","HY000");returnSeen=true;out.putProperties("returnType",Objects.toString(rows.getString("native_type"),""));continue;}
                    if(ordinal!=position+1)throw new SQLException("Routine parameter ordinals are incomplete","HY000");
                    String mode=Objects.toString(rows.getString("parameter_mode"),"");mode=switch(mode){case "i"->"IN";case "o"->"OUT";case "b"->"INOUT";case "v"->"VARIADIC";case "t"->"TABLE";default->mode;};
                    if(!Set.of("IN","OUT","INOUT","VARIADIC","TABLE").contains(mode))throw new SQLException("Routine parameter mode is unavailable","HY000");
                    String name=Objects.toString(rows.getString("parameter_name"),"");declarations.add(new RoutineDefaults.Parameter(ordinal,name,mode));
                    boolean input=mode.equals("IN")||mode.equals("INOUT")||mode.equals("VARIADIC");if(input)inputPosition++;
                    String prefix="parameter."+position++;
                    out.putProperties(prefix+".name",name).putProperties(prefix+".type",Objects.toString(rows.getString("native_type"),""))
                        .putProperties(prefix+".nativeTypeId",Objects.toString(rows.getString("type_oid"),""))
                        .putProperties(prefix+".mode",mode).putProperties(prefix+".optional",Boolean.toString(pg&&input&&inputPosition>argumentCount-defaultCount))
                        .putProperties(prefix+".variadic",Boolean.toString(mode.equals("VARIADIC")))
                        .putProperties(prefix+".defaultAvailability","UNAVAILABLE");
                }
                warnings(statement,session.connection,rows);
            }
        }
        RoutineDefaults.Parsed parsed;
        if(pg){
            parsed=defaultBytes>NativeRoutineSource.MAX_BYTES?new RoutineDefaults.Parsed(List.of(),MetadataState.LIMITED):RoutineDefaults.postgres(defaultExpressions,argumentCount,defaultCount,declarations,session.context.lexical());
            out.putProperties("parameterDefaultsSource","pg_get_expr");
        }else if(session.profile.getEngine()==Engine.MARIADB){
            if(source==null)source=NativeRoutineSource.read(session,routine,deadline);
            parsed=RoutineDefaults.maria(source,routine,declarations);
            out.putProperties("parameterDefaultsSource","native SHOW CREATE header").putProperties("parameterDefaultsSqlMode",source.sqlMode());
        }else{
            parsed=new RoutineDefaults.Parsed(Collections.nCopies(position,new RoutineDefaults.Value(false,"")),MetadataState.AVAILABLE);
            out.putProperties("parameterDefaultsSource","native grammar without parameter defaults");
        }
        if(!pg){var types=new ArrayList<String>();for(int i=0;i<position;i++)types.add(out.getPropertiesOrDefault("parameter."+i+".type",""));out.putProperties("signature",routine.getName()+"("+String.join(", ",types)+")");}
        if(parsed.available())for(int index=0;index<position;index++){
            var value=parsed.values().get(index);String prefix="parameter."+index;
            out.putProperties(prefix+".optional",Boolean.toString(value.declared())).putProperties(prefix+".defaultAvailability",value.declared()?"AVAILABLE":"ABSENT");
            if(value.declared())out.putProperties(prefix+".default",value.expression());
        }
        check(deadline);return new Enriched(out.putProperties("parameterCount",Integer.toString(position)).putProperties("parameterDefaultsAvailability",parsed.state().name()).putProperties("signatureAvailability",parsed.state().name()).build(),source);
    }
    private static void check(long deadline)throws SQLTimeoutException{if(io.grpc.Context.current().isCancelled()||Thread.currentThread().isInterrupted())throw new java.util.concurrent.CancellationException("Routine metadata cancelled");if(System.nanoTime()>deadline)throw new SQLTimeoutException("Routine metadata deadline exceeded");}
    private static void warnings(Statement statement,Connection connection,ResultSet rows)throws SQLException{if(rows.getWarnings()!=null||statement.getWarnings()!=null||connection.getWarnings()!=null)throw new SQLException("Routine metadata returned a conversion warning","01000");}
}
