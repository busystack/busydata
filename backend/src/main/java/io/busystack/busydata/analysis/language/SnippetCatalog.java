package io.busystack.busydata.analysis.language;

import java.nio.charset.StandardCharsets;
import java.util.Map;

/** Request-owned user templates. Validation never parses or executes their SQL. */
public final class SnippetCatalog {
    private SnippetCatalog(){}
    public static void validate(Map<String,String> snippets){
        if(snippets.size()>32)throw new IllegalArgumentException("SQL snippet count exceeds 32");
        int bytes=0;
        for(var snippet:snippets.entrySet()){
            String name=snippet.getKey(),text=snippet.getValue();
            if(name==null||text==null||name.isEmpty()||name.length()>64||text.length()>4096||name.indexOf('\0')>=0||text.indexOf('\0')>=0)throw new IllegalArgumentException("Invalid SQL snippet name or text");
            bytes+=name.getBytes(StandardCharsets.UTF_8).length+text.getBytes(StandardCharsets.UTF_8).length;
            if(bytes>32768)throw new IllegalArgumentException("SQL snippets exceed 32KiB");
        }
    }
}
