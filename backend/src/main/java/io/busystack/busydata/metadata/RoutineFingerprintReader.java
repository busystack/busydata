package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.sessions.SessionRegistry;
import java.sql.*;
import java.nio.charset.StandardCharsets;
import java.security.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.function.Predicate;

/** Bounded native routine identity/content evidence, separate from detail acquisition. */
public final class RoutineFingerprintReader {
    private RoutineFingerprintReader(){}
    private static final ExecutorService cancellation=Executors.newVirtualThreadPerTaskExecutor();
    private static final String[][] PARAMETER_FIELDS={
        {"ORDINAL_POSITION","position"},{"PARAMETER_NAME","parameter_name"},{"PARAMETER_MODE","parameter_mode"},{"DTD_IDENTIFIER","native_type"},
        {"DATA_TYPE","data_type"},{"CHARACTER_MAXIMUM_LENGTH","character_maximum_length"},{"CHARACTER_OCTET_LENGTH","character_octet_length"},
        {"NUMERIC_PRECISION","numeric_precision"},{"NUMERIC_SCALE","numeric_scale"},{"DATETIME_PRECISION","datetime_precision"},
        {"CHARACTER_SET_NAME","character_set_name"},{"COLLATION_NAME","collation_name"}};
    /** Length-tagged SQL values distinguish NULL, empty and concatenation
     * boundaries. Only a fixed native SHA-256 reaches the scanner. */
    private static String nativeHash(List<String> fields){return "SHA2(CONCAT("+String.join(",",fields.stream().map(field->"IF("+field+" IS NULL,'N',CONCAT('V',OCTET_LENGTH(CAST("+field+" AS BINARY)),':',SHA2(CAST("+field+" AS BINARY),256)))").toList())+"),256)";}
    public static String nativeVersionSql(){
        return nativeHash(List.of("ROUTINE_DEFINITION","ROUTINE_BODY","ROUTINE_TYPE","DTD_IDENTIFIER","IS_DETERMINISTIC","SQL_DATA_ACCESS","SECURITY_TYPE","CREATED","LAST_ALTERED","SQL_MODE","ROUTINE_COMMENT","DEFINER","CHARACTER_SET_CLIENT","COLLATION_CONNECTION","DATABASE_COLLATION"));
    }
    static String parameterProjection(){return String.join(",",Arrays.stream(PARAMETER_FIELDS).map(field->field[0]+" "+field[1]).toList())+",'' type_oid";}
    public record Evidence(SchemaObject identity,String fingerprint,MetadataState state){
        public String limitation(){return state==MetadataState.AVAILABLE?"":"Native routine fingerprint is "+state.name().toLowerCase(Locale.ROOT);}
    }
    public record Scan(List<Evidence> evidence,String fingerprint,long count,long nativeSourceReads,long sourceBytes){public Scan{evidence=List.copyOf(evidence);}}
    /** Visible catalog proof only, used inside detail acquisition. The owning
     * coordinator fences it with full scans including unavailable native defaults. */
    public static String fingerprint(SessionRegistry.Session session,String routinesSql,List<String> parameters)throws SQLException {
        return scan(session,routinesSql,parameters,IntrospectionLevel.STRUCTURE,System.nanoTime()+TimeUnit.SECONDS.toNanos(10),false,ignored->true).fingerprint();
    }
    public static Scan scan(SessionRegistry.Session session,String routinesSql,List<String> parameters,IntrospectionLevel level,long deadline,Predicate<SchemaObject> admitted)throws SQLException {
        return scan(session,routinesSql,parameters,level,deadline,true,Objects.requireNonNull(admitted));
    }
    private static Scan scan(SessionRegistry.Session session,String routinesSql,List<String> parameters,IntrospectionLevel level,long deadline,boolean includeSource,Predicate<SchemaObject> admitted)throws SQLException {
        boolean pg=session.profile.getEngine()==Engine.POSTGRESQL;
        String nativeId=pg?"r.\"nativeId\"":"r.nativeId";
        String sourceMissing=!pg&&includeSource&&level!=IntrospectionLevel.NAMES?"r._sourceMissing":"FALSE";
        String select="SELECT r.c,r.s,r.n,r.i,r.k,"+nativeId+",r.specificName,r._version,"+sourceMissing+",";
        String sql=select+(pg?"NULL,'' FROM ("+routinesSql+") r ORDER BY r.c COLLATE \"C\",r.s COLLATE \"C\",r.n COLLATE \"C\",r.i COLLATE \"C\"":
            "p.ORDINAL_POSITION,"+nativeHash(Arrays.stream(PARAMETER_FIELDS).map(field->"p."+field[0]).toList())+" FROM ("+routinesSql+") r LEFT JOIN information_schema.PARAMETERS p ON BINARY p.SPECIFIC_SCHEMA=BINARY r.s AND BINARY p.SPECIFIC_NAME=BINARY r.specificName AND BINARY p.ROUTINE_TYPE=BINARY r.k ORDER BY BINARY r.c,BINARY r.s,BINARY r.n,BINARY r.i,p.ORDINAL_POSITION");
        var context=io.grpc.Context.current();var result=new ArrayList<Evidence>();MessageDigest routineDigest=null;SchemaObject identity=null;MetadataState routineState=MetadataState.AVAILABLE;
        int rowsSeen=0,perRoutine=0,previousOrdinal=-1;long bytes=0;String previous="",previousHeader="";
        try(var query=session.adapter.catalogStatement(session.connection,sql)){
            query.setMaxRows(10001);if(!pg)query.setFetchSize(session.profile.getEngine()==Engine.MYSQL?Integer.MIN_VALUE:256);
            for(int i=0;i<parameters.size();i++)query.setString(i+1,parameters.get(i));
            io.grpc.Context.CancellationListener listener=ignored->{try{query.cancel();}catch(SQLException ignoredFailure){}};context.addListener(listener,cancellation);
            try{
                check(context,deadline);
                try(var rows=query.executeQuery()){
                    while(rows.next()){
                        check(context,deadline);if(++rowsSeen>10000)throw new IllegalArgumentException("Routine fingerprint row budget exceeded; narrow the scope");
                        var header=new String[8];for(int i=0;i<header.length;i++){header[i]=rows.getString(i+1);if(header[i]==null||header[i].getBytes(StandardCharsets.UTF_8).length>8192)throw new SQLException("Routine fingerprint identity unavailable");}
                        String current=MetadataIdentity.digest(Arrays.copyOf(header,7));
                        if(!current.equals(previous)){
                            if(identity!=null)result.add(new Evidence(identity,HexFormat.of().formatHex(routineDigest.digest()),routineState));
                            previous=current;previousHeader=MetadataIdentity.digest(header);perRoutine=0;previousOrdinal=-1;routineDigest=sha256();
                            ObjectSubtype subtype=switch(header[4]){case "FUNCTION"->ObjectSubtype.FUNCTION;case "PROCEDURE"->ObjectSubtype.PROCEDURE;default->throw new SQLException("Native routine kind unavailable");};
                            var object=SchemaObject.newBuilder().setCatalog(header[0]).setSchema(header[1]).setName(header[2]).setIdentifier(header[3]).setKind(ObjectKind.ROUTINE).setSubtype(subtype).putProperties("type",header[4]).putProperties("specificName",header[6]).putProperties("_version",header[7]);
                            if(pg){if(header[5].isEmpty())throw new SQLException("Native PostgreSQL routine identity unavailable");object.putProperties("nativeId",header[5]);}
                            identity=object.build();for(String value:header)bytes+=update(routineDigest,value);
                            routineState=!pg&&level==IntrospectionLevel.SOURCE&&rows.getBoolean(9)?MetadataState.UNAVAILABLE:MetadataState.AVAILABLE;
                        }
                        if(!previousHeader.equals(MetadataIdentity.digest(header)))throw new SQLException("Native routine changed during fingerprint acquisition","55000");
                        String parameterHash=rows.getString(11);int ordinal=rows.getInt(10);boolean absent=rows.wasNull();
                        if(!pg){
                            if(!header[7].matches("[0-9a-fA-F]{64}")||parameterHash==null||!parameterHash.matches("[0-9a-fA-F]{64}"))throw new SQLException("Routine fingerprint evidence unavailable");
                            if(!absent){if(ordinal<0||ordinal>1024||ordinal<=previousOrdinal||++perRoutine>1025)throw new SQLException("Routine parameter identity/order unavailable");previousOrdinal=ordinal;}
                            bytes+=update(routineDigest,absent?"NO_PARAMETER":Integer.toString(ordinal));bytes+=update(routineDigest,parameterHash);
                        }
                        if(bytes>8_388_608)throw new IllegalArgumentException("Routine fingerprint byte budget exceeded; narrow the scope");
                    }
                }
                if(identity!=null)result.add(new Evidence(identity,HexFormat.of().formatHex(routineDigest.digest()),routineState));
            }finally{context.removeListener(listener);}
        }
        return completeEvidence(session.profile.getEngine(),level,result,deadline,includeSource,admitted,(object,until)->NativeRoutineSource.read(session,object,until));
    }
    @FunctionalInterface interface SourceRead {NativeRoutineSource read(SchemaObject object,long deadline)throws SQLException;}
    static Scan completeEvidence(Engine engine,IntrospectionLevel level,List<Evidence> visible,long deadline,boolean includeSource,Predicate<SchemaObject> admitted,SourceRead read)throws SQLException {
        long sourceReads=0,sourceBytes=0;var finalEvidence=new ArrayList<Evidence>();var branchDigest=sha256();var context=io.grpc.Context.current();
        for(var evidence:visible){
            check(context,deadline);var object=evidence.identity();if(!admitted.test(object))continue;
            MetadataState state=evidence.state();String fingerprint=evidence.fingerprint();
            if(includeSource&&engine==Engine.MARIADB&&level.includes(IntrospectionLevel.STRUCTURE)){
                sourceReads++;var source=read.read(object,deadline);sourceBytes+=source.bytesRead();
                if(sourceBytes>8_388_608)throw new IllegalArgumentException("Routine source fingerprint byte budget exceeded; narrow the scope");
                state=source.state()==MetadataState.AVAILABLE&&!source.available()?MetadataState.UNAVAILABLE:source.state();fingerprint=MetadataIdentity.digest(fingerprint,source.fingerprint());
            }
            var current=new Evidence(object,fingerprint,state);finalEvidence.add(current);
            for(String value:List.of(object.getCatalog(),object.getSchema(),object.getName(),object.getIdentifier(),object.getPropertiesOrThrow("type"),object.getPropertiesOrDefault("nativeId",""),fingerprint,state.name()))update(branchDigest,value);
        }
        return new Scan(finalEvidence,HexFormat.of().formatHex(branchDigest.digest()),finalEvidence.size(),sourceReads,sourceBytes);
    }
    private static void check(io.grpc.Context context,long deadline)throws SQLTimeoutException {
        if(context.isCancelled()||Thread.currentThread().isInterrupted())throw new CancellationException("Routine fingerprint cancelled");
        if(System.nanoTime()>deadline)throw new SQLTimeoutException("Routine fingerprint deadline exceeded");
    }
    private static MessageDigest sha256(){try{return MessageDigest.getInstance("SHA-256");}catch(NoSuchAlgorithmException impossible){throw new AssertionError(impossible);}}
    private static long update(MessageDigest digest,String value){byte[] bytes=value.getBytes(StandardCharsets.UTF_8);int n=bytes.length;digest.update((byte)(n>>>24));digest.update((byte)(n>>>16));digest.update((byte)(n>>>8));digest.update((byte)n);digest.update(bytes);return n+4L;}
}
