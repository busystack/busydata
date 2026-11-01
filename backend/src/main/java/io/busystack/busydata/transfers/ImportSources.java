package io.busystack.busydata.transfers;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.results.Values;
import io.busystack.busydata.results.ResultStore;
import java.io.*;
import java.nio.charset.*;
import java.nio.file.*;
import java.security.*;
import java.util.*;
import org.apache.commons.csv.*;
import com.google.gson.*;
import com.google.gson.stream.JsonReader;

public final class ImportSources {
    public static final long SOURCE_LIMIT=8L*1024*1024*1024;
    public record Snapshot(ResultStore.Temporary temporary, ToolRequest request) implements AutoCloseable {
        public void close()throws Exception { temporary.close(); }
    }
    public static Snapshot snapshot(ToolRequest request, ResultStore store)throws Exception {
        return snapshot(request,store,()->{});
    }
    @FunctionalInterface public interface Cancellation {void check()throws Exception;}
    public static Snapshot snapshot(ToolRequest request, ResultStore store,Cancellation cancellation)throws Exception {
        Path source=selected(request);String expected=request.getSourceSha256().isEmpty()?hash(source):request.getSourceSha256();
        var temporary=store.temporary();var digest=MessageDigest.getInstance("SHA-256");
        try {
            try(var input=Files.newInputStream(source);var output=temporary.output()) {
                byte[] buffer=new byte[65536];long size=0;int length;
                while((length=input.read(buffer))!=-1){cancellation.check();size+=length;if(size>SOURCE_LIMIT)throw new IOException("Import source exceeds the reviewed 8GiB per-source policy");if(Thread.currentThread().isInterrupted())throw new InterruptedIOException("Import snapshot cancelled");digest.update(buffer,0,length);output.write(buffer,0,length);}
            }
            String actual=HexFormat.of().formatHex(digest.digest());if(!actual.equals(expected))throw new IllegalStateException("Import source changed after review");
            return new Snapshot(temporary,request.toBuilder().setPath(temporary.path.toString()).setSourceSha256(actual).build());
        }catch(Exception error){try{temporary.close();}catch(Exception cleanup){error.addSuppressed(cleanup);}throw error;}
    }
    public static Path selected(ToolRequest request) throws IOException {
        Path file = Path.of(request.getPath());
        if (!file.isAbsolute() || Files.isSymbolicLink(file)||!Files.isRegularFile(file,LinkOption.NOFOLLOW_LINKS) || Files.size(file) > SOURCE_LIMIT)
            throw new IllegalArgumentException("Import requires a selected regular file at most 8GiB; symlinks are not accepted");
        return file;
    }
    public static String hash(Path file) throws Exception {
        var context=io.grpc.Context.current();
        return hash(file,context::isCancelled);
    }
    /** Cancellation is checked before opening and between each 64KiB read. */
    public static String hash(Path file,java.util.function.BooleanSupplier cancelled) throws Exception {
        Objects.requireNonNull(cancelled);
        checkHashCancellation(cancelled);
        selected(ToolRequest.newBuilder().setPath(file.toString()).build());
        var before=Files.readAttributes(file,java.nio.file.attribute.BasicFileAttributes.class,LinkOption.NOFOLLOW_LINKS);
        var hash=MessageDigest.getInstance("SHA-256");long total=0;
        try(var input=Files.newInputStream(file,LinkOption.NOFOLLOW_LINKS)){
            byte[] buffer=new byte[65536];
            while(true){
                checkHashCancellation(cancelled);
                int length=input.read(buffer);if(length==-1)break;
                total+=length;if(total>SOURCE_LIMIT)throw new IOException("Source exceeds the 8GiB reviewed source policy");hash.update(buffer,0,length);
            }
        }
        checkHashCancellation(cancelled);
        var after=Files.readAttributes(file,java.nio.file.attribute.BasicFileAttributes.class,LinkOption.NOFOLLOW_LINKS);
        if(!Objects.equals(before.fileKey(),after.fileKey())||before.size()!=after.size()||!before.lastModifiedTime().equals(after.lastModifiedTime())||total!=after.size())throw new IOException("Source changed during review");
        checkHashCancellation(cancelled);
        return HexFormat.of().formatHex(hash.digest());
    }
    private static void checkHashCancellation(java.util.function.BooleanSupplier cancelled) {
        if(Thread.currentThread().isInterrupted()||cancelled.getAsBoolean())throw new java.util.concurrent.CancellationException("Source review cancelled");
    }
    public static Reader reader(ToolRequest request) throws IOException {
        String encoding = request.getEncoding().isBlank() ? "UTF-8" : request.getEncoding();
        if (!Set.of("UTF-8", "UTF-16LE", "UTF-16BE", "windows-1252", "ISO-8859-1").contains(encoding))
            throw new IllegalArgumentException("Choose a supported import encoding");
        Reader source = new BufferedReader(new InputStreamReader(Files.newInputStream(selected(request)),Charset.forName(encoding).newDecoder().onMalformedInput(CodingErrorAction.REPORT).onUnmappableCharacter(CodingErrorAction.REPORT)));
        return new BoundedReader(source, request.getKind() == ToolKind.IMPORT_CSV, !request.getFormat().equals("ndjson"));
    }
    /** Bound allocation before CSV/Gson can accumulate an oversized record. */
    private static final class BoundedReader extends FilterReader {
        private final boolean csv;
        private final boolean array;
        private boolean quoted, escaped;
        private int count, depth;
        BoundedReader(Reader input, boolean csv, boolean array) { super(input); this.csv = csv; this.array = array; }
        @Override public int read() throws IOException {
            int value = super.read(); if (value == -1) return -1;
            if (++count > 262_144) throw new IOException("Import record exceeds 256Ki UTF-16 units before parser allocation");
            char character = (char) value;
            if (csv) {
                if (character == '"') quoted = !quoted;
                if ((character == '\n' || character == '\r') && !quoted) count = 0;
            } else if (quoted) {
                if (escaped) escaped = false;
                else if (character == '\\') escaped = true;
                else if (character == '"') quoted = false;
            } else {
                if (character == '"') quoted = true;
                else if (character == '{' || character == '[') {if(++depth>32)throw new IOException("Import JSON nesting exceeds 32");}
                else if (character == '}' || character == ']') { depth--; if (depth == (array ? 1 : 0)) count = 0; }
                else if (character == '\n' && depth == 0) count = 0;
            }
            return value;
        }
        @Override public int read(char[] buffer, int offset, int length) throws IOException {
            if (length == 0) return 0; int read = 0;
            while (read < length) { int value = read(); if (value == -1) break; buffer[offset + read++] = (char) value; }
            return read == 0 ? -1 : read;
        }
    }
    private static Value value(String text) {
        if (text == null) return Values.nil();
        if (text.length() <= 1024) return Value.newBuilder().setText(text).build();
        int end = Character.isHighSurrogate(text.charAt(1023)) ? 1023 : 1024;
        return Value.newBuilder().setText(text.substring(0, end)).setTruncated(true).setOriginalBytes(text.getBytes(StandardCharsets.UTF_8).length).build();
    }
    public static ImportPreview preview(ToolRequest request) throws Exception {
        if (!Set.of(ToolKind.IMPORT_CSV, ToolKind.IMPORT_JSON).contains(request.getKind())) throw new IllegalArgumentException("Choose an import format");
        Path path = selected(request); String hash = hash(path), marker = request.getNullMarker().isEmpty() ? "\\N" : request.getNullMarker();
        var result = ImportPreview.newBuilder().setEncoding(request.getEncoding().isEmpty() ? "UTF-8" : request.getEncoding()).setNullMarker(marker).setSourceSha256(hash)
            .addWarnings("Preview reads source values; execution uses the same mapping, delimiter, encoding and NULL contract. Source limit: 8GiB; immutable snapshot quota: 16GiB shared; decoded record: 256Ki UTF-16 units. Policy: "+request.getImportPolicy()+". No rows have been imported.");
        try (var input = reader(request)) {
            if (request.getKind() == ToolKind.IMPORT_CSV) {
                try (var csv = CsvContract.input(request).parse(input)) {
                    result.addAllSourceColumns(csv.getHeaderNames());
                    if (result.getSourceColumnsCount() > 2048) throw new IllegalArgumentException("Import column limit is 2048");
                    if(new HashSet<>(csv.getHeaderNames()).size()!=csv.getHeaderNames().size())throw new IllegalArgumentException("Duplicate CSV headers are ambiguous");
                    if(result.build().getSerializedSize()>65536)throw new IllegalArgumentException("Preview headers exceed 64KiB");
                    for (var record : csv) {
                        if (result.getRowsCount() == 20) { result.setLimited(true); break; }
                        var row = Row.newBuilder(); for (String header : result.getSourceColumnsList()) row.addValues(value(record.get(header)));if(result.build().getSerializedSize()+row.build().getSerializedSize()>262144){result.setLimited(true);break;} result.addRows(row);
                    }
                }
            } else if (request.getFormat().equals("ndjson")) {
                var lines = new BufferedReader(input); String line;
                while ((line = lines.readLine()) != null) {
                    if (line.isBlank()) continue;
                    if (result.getRowsCount() == 20) { result.setLimited(true); break; }
                    addObject(result, JsonParser.parseString(line).getAsJsonObject());if(result.getLimited())break;
                }
            } else {
                try (var json = new JsonReader(input)) {
                    json.beginArray(); while (json.hasNext()) {
                        if (result.getRowsCount() == 20) { result.setLimited(true); break; }
                        addObject(result, JsonParser.parseReader(json).getAsJsonObject());if(result.getLimited())break;
                    }
                }
            }
        }
        if (!hash.equals(hash(path))) throw new IllegalStateException("Import source changed during preview");
        return result.build();
    }
    private static void addObject(ImportPreview.Builder result, JsonObject object) {
        if (object.size() > 2048) throw new IllegalArgumentException("Import column limit is 2048");
        if (result.getRowsCount() == 0) result.addAllSourceColumns(object.keySet());
        if(result.build().getSerializedSize()>65536&&result.getRowsCount()==0)throw new IllegalArgumentException("Preview keys exceed 64KiB");
        var row = Row.newBuilder();
        for (String key : result.getSourceColumnsList()) {
            var entry = object.get(key);
            row.addValues(value(entry == null || entry.isJsonNull() ? null : entry.isJsonPrimitive() ? entry.getAsString() : entry.toString()));
        }
        if(result.build().getSerializedSize()+row.build().getSerializedSize()>262144)result.setLimited(true);else result.addRows(row);
    }
    public static String sourceColumn(ToolRequest request, String target) { return request.getColumnMappingMap().getOrDefault(target, target); }
}
