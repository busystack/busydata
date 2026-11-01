package io.busystack.busydata;

import io.busystack.busydata.rpc.RequestLimits;
import io.grpc.*;
import java.io.*;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class RequestLimitsTest {
 private static class Sized extends ByteArrayInputStream implements KnownLength {Sized(int size){super(new byte[size]);}}
 private MethodDescriptor<byte[],byte[]> descriptor(String method,AtomicInteger decode){
  var marshaller=new MethodDescriptor.Marshaller<byte[]>(){
   public InputStream stream(byte[] value){return new ByteArrayInputStream(value);}
   public byte[] parse(InputStream input){decode.incrementAndGet();try{return input.readAllBytes();}catch(IOException error){throw Status.RESOURCE_EXHAUSTED.withDescription("Bounded input").asRuntimeException();}}
  };
  return MethodDescriptor.<byte[],byte[]>newBuilder().setType(MethodDescriptor.MethodType.UNARY).setFullMethodName("busydata.v1.Workbench/"+method).setRequestMarshaller(marshaller).setResponseMarshaller(marshaller).build();
 }
 @SuppressWarnings("unchecked") private MethodDescriptor<byte[],byte[]> limited(String name,AtomicInteger count){
  var original=ServerServiceDefinition.builder("busydata.v1.Workbench").addMethod(descriptor(name,count),(call,headers)->new ServerCall.Listener<byte[]>(){}).build();
  return (MethodDescriptor<byte[],byte[]>)RequestLimits.bind(original).getMethods().iterator().next().getMethodDescriptor();
 }
 @Test void knownOversizedControlRequestsNeverReachTheDecoder(){
  var count=new AtomicInteger();var method=limited("Cancel",count);
  var error=assertThrows(StatusRuntimeException.class,()->method.getRequestMarshaller().parse(new Sized(65537)));
  assertEquals(Status.Code.RESOURCE_EXHAUSTED,error.getStatus().getCode());assertEquals(0,count.get());
  assertEquals(65536,method.getRequestMarshaller().parse(new Sized(65536)).length);
 }
 @Test void untrustedUnknownLengthInputCannotAllocateAnUnboundedDecodedPayload(){
  var count=new AtomicInteger();var method=limited("Profiles",count);var read=new AtomicInteger();
  var input=new InputStream(){public int read(){read.incrementAndGet();return 1;}};
  assertThrows(StatusRuntimeException.class,()->method.getRequestMarshaller().parse(input));assertTrue(read.get()<=65537);
 }
 @Test void credentialAndOrdinaryRequestsDoNotInheritSqlDocumentLimits(){
  assertThrows(StatusRuntimeException.class,()->limited("Authentication",new AtomicInteger()).getRequestMarshaller().parse(new Sized(65537)));
  assertEquals(100000,limited("Execute",new AtomicInteger()).getRequestMarshaller().parse(new Sized(100000)).length);
  assertThrows(StatusRuntimeException.class,()->limited("Execute",new AtomicInteger()).getRequestMarshaller().parse(new Sized(16*1024*1024+1)));
 }
 @Test void newWorkbenchContractsRetainBoundedControlAdmission(){
  for(String method:java.util.List.of("Explore","ReviewBrowse","Browse","CreateResultView","DisposeResultView","AssessEditability","ResultAggregate","RelatedRows","CloneRow")) {
   var count=new AtomicInteger();var bounded=limited(method,count);
   assertThrows(StatusRuntimeException.class,()->bounded.getRequestMarshaller().parse(new Sized(65537)));
   assertEquals(0,count.get());assertEquals(65536,bounded.getRequestMarshaller().parse(new Sized(65536)).length);
  }
 }
 @Test void metadataSettingsHasItsOwnBoundAndOldAnalysisDoesNotInheritSqlLimits(){
  assertEquals(131072,limited("MetadataSettings",new AtomicInteger()).getRequestMarshaller().parse(new Sized(131072)).length);
  assertThrows(StatusRuntimeException.class,()->limited("MetadataSettings",new AtomicInteger()).getRequestMarshaller().parse(new Sized(131073)));
  assertFalse(RequestLimits.LARGE.contains("Analyze"));
  for(String method:java.util.List.of("CompleteSql","DiagnoseSql","SqlParameterInformation","FormatSql","ResolveSqlSymbol","SqlDdlImpact")){
   assertTrue(RequestLimits.LANGUAGE.contains(method));assertFalse(RequestLimits.LARGE.contains(method));
   var count=new AtomicInteger();var request=limited(method,count);
   assertThrows(StatusRuntimeException.class,()->request.getRequestMarshaller().parse(new Sized(1048577)));assertEquals(0,count.get());
   assertEquals(1048576,request.getRequestMarshaller().parse(new Sized(1048576)).length);
  }
 }
 @Test void maximumSupportedUnicodeLanguageDocumentFitsItsDedicatedWireBudget(){
  var request=io.busystack.busydata.protocol.AnalysisRequest.newBuilder().setDocumentId("document").setEngine(io.busystack.busydata.protocol.Engine.POSTGRESQL).setOperation(io.busystack.busydata.protocol.AnalysisOperation.COMPLETION).setSql("\u0800".repeat(io.busystack.busydata.analysis.language.AnalysisBudget.MAX_DOCUMENT_UNITS)).putSnippets("template","a".repeat(4096)).build();
  assertTrue(request.getSerializedSize()<1048576);
  assertEquals(request.getSerializedSize(),limited("CompleteSql",new AtomicInteger()).getRequestMarshaller().parse(new ByteArrayInputStream(request.toByteArray())).length);
 }
 @Test void routineSearchContinuationFitsExistingControlLimitWithoutBroadeningIt() {
  var request=io.busystack.busydata.protocol.ExploreRequest.newBuilder().setContinuation("a".repeat(24576)).setSearch("s".repeat(256)).build();
  assertTrue(request.getSerializedSize()<65536);
  assertEquals(request.getSerializedSize(),limited("Explore",new AtomicInteger()).getRequestMarshaller().parse(new ByteArrayInputStream(request.toByteArray())).length);
  assertEquals(15,io.busystack.busydata.protocol.ProtocolVersion.BUSYDATA_PROTOCOL_VERSION.getNumber());
 }

}
