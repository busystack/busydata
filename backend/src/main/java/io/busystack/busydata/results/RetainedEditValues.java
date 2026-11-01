package io.busystack.busydata.results;

import com.google.protobuf.ByteString;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.rpc.WorkbenchFailure;
import java.io.*;
import java.nio.*;
import java.nio.charset.*;
import java.nio.file.*;

/** Bounded, Java-owned full originals for reviewed edits and durable recovery.
 * Expanding a value never changes the retained row or sends the whole result to
 * Flutter. Only the owning result may resolve its private cell identifiers. */
public final class RetainedEditValues {
    public static final int MAX_BYTES=1_048_576,MAX_TEXT_UNITS=262_144;
    private RetainedEditValues(){}
    public static final class Budget {
        private long bytes;
        public Budget(){this(0);}
        public Budget(long initialBytes){reserve(initialBytes);}
        public void reserve(long additional){if(additional<0||additional>MAX_BYTES-bytes)throw unavailable();bytes+=additional;}
        public long bytes(){return bytes;}
    }
    private static WorkbenchFailure unavailable(){return new WorkbenchFailure(WorkbenchFailure.Reason.VALUE_TRUNCATED);}
    private static void check(){if(io.grpc.Context.current().isCancelled()||Thread.currentThread().isInterrupted())throw new WorkbenchFailure(WorkbenchFailure.Reason.CANCELLED);}
    private static ResultStore.Result.Lease lease(ResultStore.Result result){
        try{return result.lease();}catch(IllegalStateException unavailable){throw new WorkbenchFailure(result.retained().getDisposalPending()?WorkbenchFailure.Reason.RESULT_DISPOSED:WorkbenchFailure.Reason.UNAVAILABLE);}
    }
    public static Value complete(ResultStore.Result result,Value preview,Budget budget)throws Exception {
        check();
        if(!preview.getTruncated()){
            if(!preview.getValueId().isEmpty())throw unavailable();
            budget.reserve(preview.getSerializedSize()+8L);return preview;
        }
        if(preview.getValueId().isEmpty())throw unavailable();
        if(!preview.hasText()&&!preview.hasJson()&&!preview.hasBinary())throw new WorkbenchFailure(WorkbenchFailure.Reason.UNSUPPORTED);
        try(var lease=lease(result)){
            final Path cell;
            try{cell=result.cell(preview.getValueId());}catch(IllegalArgumentException forged){throw new WorkbenchFailure(WorkbenchFailure.Reason.INVALID_OWNER);}
            if(!Files.isRegularFile(cell,LinkOption.NOFOLLOW_LINKS))throw unavailable();
            long size=Files.size(cell);if(size<0||size>MAX_BYTES||size!=preview.getOriginalBytes())throw unavailable();
            // Admission precedes allocation/decoding, including aggregate rows.
            budget.reserve(size+24L);
            check();byte[] raw=new byte[Math.toIntExact(size)];
            try(var input=Files.newInputStream(cell,LinkOption.NOFOLLOW_LINKS)){
                for(int offset=0;offset<raw.length;){check();int read=input.read(raw,offset,Math.min(65536,raw.length-offset));if(read<=0)throw unavailable();offset+=read;}
                check();if(input.read()!=-1)throw unavailable();
            }
            var full=preview.toBuilder().clearTruncated().clearValueId().clearOriginalBytes();
            if(preview.hasBinary()){
                var bytes=ByteString.copyFrom(raw);if(!bytes.startsWith(preview.getBinary()))throw unavailable();full.setBinary(bytes);
            }else{
                final String text;
                try{text=StandardCharsets.UTF_8.newDecoder().onMalformedInput(CodingErrorAction.REPORT).onUnmappableCharacter(CodingErrorAction.REPORT).decode(ByteBuffer.wrap(raw)).toString();}
                catch(CharacterCodingException corrupt){throw unavailable();}
                check();
                if(text.length()>MAX_TEXT_UNITS||!text.startsWith(preview.hasJson()?preview.getJson():preview.getText()))throw unavailable();
                if(preview.hasJson())full.setJson(text);else full.setText(text);
            }
            var value=full.build();if(value.getSerializedSize()>MAX_BYTES)throw unavailable();check();return value;
        }
    }
    public static Row row(ResultStore.Result result,long sourceRow,Budget budget)throws Exception {
        check();try(var lease=lease(result)){
            var stored=result.read(sourceRow);var full=Row.newBuilder();
            for(var value:stored.getValuesList())full.addValues(complete(result,value,budget));
            var row=full.build();if(row.getSerializedSize()>MAX_BYTES)throw unavailable();return row;
        }
    }
    /** Restored full originals regain private chunk ownership before spooling. */
    public static Row retainRow(ResultStore.Result result,Row row)throws Exception {
        check();if(row.getSerializedSize()>MAX_BYTES)throw unavailable();var retained=Row.newBuilder();
        for(var value:row.getValuesList()){
            check();
            if(value.getTruncated()||!value.getValueId().isEmpty())throw unavailable();
            var next=value.toBuilder();
            if(value.hasBinary()&&value.getBinary().size()>Values.CELL_PREVIEW){
                String id=result.storeBinary(new byte[0],value.getBinary().newInput());
                next.setBinary(value.getBinary().substring(0,Values.CELL_PREVIEW)).setTruncated(true).setValueId(id).setOriginalBytes(value.getBinary().size());
            }else if((value.hasText()||value.hasJson())&&(value.hasJson()?value.getJson():value.getText()).length()>Values.CELL_PREVIEW){
                String text=value.hasJson()?value.getJson():value.getText();if(text.length()>MAX_TEXT_UNITS)throw unavailable();
                for(int at=0;at<text.length();at++){char unit=text.charAt(at);if(Character.isHighSurrogate(unit)){if(++at==text.length()||!Character.isLowSurrogate(text.charAt(at)))throw unavailable();}else if(Character.isLowSurrogate(unit))throw unavailable();}
                int end=Values.CELL_PREVIEW;if(Character.isHighSurrogate(text.charAt(end-1)))end--;
                String id=result.storeText("",new StringReader(text));
                if(value.hasJson())next.setJson(text.substring(0,end));else next.setText(text.substring(0,end));
                next.setTruncated(true).setValueId(id).setOriginalBytes(Files.size(result.cell(id)));
            }
            retained.addValues(next);
        }
        return retained.build();
    }
}
