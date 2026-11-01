package io.busystack.busydata.transfers;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.Locale;
import java.util.regex.Pattern;

/** Retains bounded native stderr internally; exposes only recognized categories/codes.
 * Server text, SQL, paths, principal names, and credentials are never returned. */
final class NativeDiagnostics {
    private static final int LIMIT=16384;
    // Official mysql/mariadb batch clients prefix server errors with numeric
    // code and SQLSTATE. Match a complete prefix, never a number in server text.
    private static final Pattern SERVER_ERROR=Pattern.compile(
        "(?m)^ERROR ([0-9]{3,5}) \\(([0-9A-Z]{5})\\)(?: at line [0-9]+)?(?: in file: '[^\\r\\n]*')?: ");
    private static final Pattern LEGACY_CODE=Pattern.compile("(?:error|got error:)\\s+([0-9]{3,5})\\b");
    private final ByteArrayOutputStream prefix=new ByteArrayOutputStream();
    void drain(InputStream input)throws IOException {
        byte[] buffer=new byte[4096];int count;
        while((count=input.read(buffer))!=-1)if(prefix.size()<LIMIT)prefix.write(buffer,0,Math.min(count,LIMIT-prefix.size()));
    }
    NativeToolFailure failure(int exit) {
        String retained=prefix.toString(StandardCharsets.UTF_8),text=retained.toLowerCase(Locale.ROOT);
        Integer databaseCode=null;String sqlState=null;
        var code=SERVER_ERROR.matcher(retained);
        if(code.find()){
            databaseCode=Integer.valueOf(code.group(1));sqlState=code.group(2);
            // Multiple error headers are not one structured error.
            if(code.find()){databaseCode=null;sqlState=null;}
        }else{
            // Preserve the existing redacted numeric-code summary for older
            // client/dump formats; it cannot establish a structured SQLSTATE.
            var legacy=LEGACY_CODE.matcher(text);if(legacy.find())databaseCode=Integer.valueOf(legacy.group(1));
        }
        var category=databaseCode!=null&&databaseCode==1213&&"40001".equals(sqlState)?NativeToolFailure.Category.DEADLOCK:
            text.contains("error while loading shared libraries")?NativeToolFailure.Category.MISSING_LIBRARY:
            text.contains("unknown option")||text.contains("unknown variable")||text.contains("unrecognized option")?NativeToolFailure.Category.UNSUPPORTED_OPTION:
            text.contains("authentication")||text.contains("access denied")||text.contains("password authentication")?NativeToolFailure.Category.AUTHENTICATION:
            text.contains("certificate")||text.contains("ssl")||text.contains("tls")?NativeToolFailure.Category.TLS:
            text.contains("permission denied")||text.contains("must be owner")||text.contains("privilege")?NativeToolFailure.Category.PERMISSION:
            text.contains("could not translate host")||text.contains("unknown mysql server host")?NativeToolFailure.Category.HOSTNAME:
            text.contains("connection")||text.contains("connect")?NativeToolFailure.Category.CONNECTION:
            text.contains("query failed")||text.contains("syntax error")?NativeToolFailure.Category.SQL:
            text.contains("no space left")?NativeToolFailure.Category.DISK_FULL:NativeToolFailure.Category.UNCLASSIFIED;
        return new NativeToolFailure(exit,category,databaseCode,sqlState);
    }
    String summary(int exit){return failure(exit).getMessage();}
}
