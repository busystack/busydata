package io.busystack.busydata.rpc;

import io.grpc.*;
import java.io.*;
import java.util.Set;

/** Admission before generated protobuf decoding, with method-specific byte limits.
 * This bounds payloads, not the JVM or driver as a whole; measured RSS is separate. */
public final class RequestLimits {
    public static final Set<String> LANGUAGE=Set.of("CompleteSql","DiagnoseSql","SqlParameterInformation","FormatSql","ResolveSqlSymbol","SqlDdlImpact");
    public static final Set<String> LARGE=Set.of("Execute","Review","SchemaTool","PreviewChanges","ReviewTool","Tool");
    private RequestLimits(){}
    public static ServerServiceDefinition bind(ServerServiceDefinition original){
        var result=ServerServiceDefinition.builder(original.getServiceDescriptor().getName());
        for(var method:original.getMethods())add(result,method);
        return result.build();
    }
    private static <Req,Resp> void add(ServerServiceDefinition.Builder output,ServerMethodDefinition<Req,Resp> original){
        var descriptor=original.getMethodDescriptor();var delegate=descriptor.getRequestMarshaller();
        int limit=LANGUAGE.contains(descriptor.getBareMethodName())?1048576:LARGE.contains(descriptor.getBareMethodName())?16*1024*1024:descriptor.getBareMethodName().equals("EditDraft")?1048576:descriptor.getBareMethodName().equals("MetadataSettings")?131072:65536;
        var bounded=new MethodDescriptor.Marshaller<Req>(){
            public InputStream stream(Req value){return delegate.stream(value);}
            public Req parse(InputStream source){
                try{if(source instanceof KnownLength&&source.available()>limit)throw Status.RESOURCE_EXHAUSTED.withDescription("Typed request byte budget exceeded").asRuntimeException();}
                catch(IOException error){throw Status.INVALID_ARGUMENT.withDescription("Request payload unavailable").asRuntimeException();}
                return delegate.parse(new FilterInputStream(source){
                    int remaining=limit;
                    @Override public int read()throws IOException{int value=super.read();if(value!=-1&&remaining--<=0)throw new IOException("Request byte budget exceeded");return value;}
                    @Override public int read(byte[] buffer,int offset,int length)throws IOException{if(remaining==0){int value=super.read();if(value==-1)return -1;throw new IOException("Request byte budget exceeded");}int count=super.read(buffer,offset,Math.min(length,remaining));if(count>0)remaining-=count;return count;}
                    @Override public long skip(long count)throws IOException{long skipped=super.skip(Math.min(count,remaining));remaining-=(int)skipped;return skipped;}
                });
            }
        };
        output.addMethod(descriptor.toBuilder(bounded,descriptor.getResponseMarshaller()).build(),original.getServerCallHandler());
    }
}
