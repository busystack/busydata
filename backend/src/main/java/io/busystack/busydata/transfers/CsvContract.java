package io.busystack.busydata.transfers;

import io.busystack.busydata.protocol.ToolRequest;
import org.apache.commons.csv.*;

/** Unquoted marker is NULL; all non-NULL exported fields are quoted. */
public final class CsvContract {
    private CsvContract() {}
    public static char delimiter(ToolRequest request) {
        if(!request.getDelimiter().isEmpty()){
            String delimiter=request.getDelimiter();if(delimiter.length()!=1||delimiter.charAt(0)=='"'||delimiter.charAt(0)=='\r'||delimiter.charAt(0)=='\n'||delimiter.charAt(0)=='\0'||Character.isSurrogate(delimiter.charAt(0)))throw new IllegalArgumentException("Delimiter must be one character other than a quote, line break, NUL, or surrogate");return delimiter.charAt(0);
        }
        return request.getFormat().equals("tsv") ? '\t' : ',';
    }
    public static String marker(ToolRequest request) {
        String marker=request.getNullMarker().isEmpty()?"\\N":request.getNullMarker();
        if(marker.length()>64||marker.indexOf(delimiter(request))>=0||marker.indexOf('"')>=0||marker.indexOf('\r')>=0||marker.indexOf('\n')>=0||marker.indexOf('\0')>=0||!marker.equals(marker.strip()))
            throw new IllegalArgumentException("NULL marker must be 1–64 characters without whitespace at its ends, quotes, delimiters, or line breaks");
        return marker;
    }
    public static CSVFormat input(ToolRequest request) {
        // ALL_NON_NULL makes Commons CSV preserve a quoted marker as literal
        // text. Merely comparing the decoded token would lose that information.
        return CSVFormat.DEFAULT.builder().setDelimiter(delimiter(request))
            .setNullString(marker(request)).setQuoteMode(QuoteMode.ALL_NON_NULL)
            .setHeader().setSkipHeaderRecord(true).get();
    }
}
