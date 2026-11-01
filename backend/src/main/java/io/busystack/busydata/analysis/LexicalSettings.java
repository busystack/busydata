package io.busystack.busydata.analysis;

/** Server-owned lexical context. It is refreshed without committing or starting
 * the interactive transaction, and participates in the live context revision. */
public record LexicalSettings(boolean noBackslashEscapes,boolean ansiQuotes,boolean standardConformingStrings,boolean ignoreSpace,
                              boolean pipesAsConcat,boolean highNotPrecedence,boolean noUnsignedSubtraction,boolean realAsFloat,String sqlMode) {
    public LexicalSettings {java.util.Objects.requireNonNull(sqlMode);}
    public LexicalSettings(boolean noBackslashEscapes,boolean ansiQuotes,boolean standardConformingStrings,boolean ignoreSpace){
        this(noBackslashEscapes,ansiQuotes,standardConformingStrings,ignoreSpace,false,false,false,false,
            String.join(",",java.util.stream.Stream.of(noBackslashEscapes?"NO_BACKSLASH_ESCAPES":"",ansiQuotes?"ANSI_QUOTES":"",ignoreSpace?"IGNORE_SPACE":"").filter(v->!v.isEmpty()).sorted().toList()));
    }
    public LexicalSettings(boolean noBackslashEscapes,boolean ansiQuotes,boolean standardConformingStrings){this(noBackslashEscapes,ansiQuotes,standardConformingStrings,false);}
    public static final LexicalSettings DEFAULT=new LexicalSettings(false,false,true,false);
    public static LexicalSettings mysql(String mode){
        // Keep every server-captured mode, including modes not interpreted by the
        // language service. Recovery must restore the context, not a projection
        // of the flags currently understood by BusyData.
        java.util.Objects.requireNonNull(mode,"Server SQL mode is unavailable");
        var modes=new java.util.TreeSet<String>();
        for(String value:mode.toUpperCase(java.util.Locale.ROOT).split(","))if(!value.isBlank())modes.add(value.trim());
        return new LexicalSettings(modes.contains("NO_BACKSLASH_ESCAPES"),modes.contains("ANSI_QUOTES"),true,modes.contains("IGNORE_SPACE"),
            modes.contains("PIPES_AS_CONCAT"),modes.contains("HIGH_NOT_PRECEDENCE"),modes.contains("NO_UNSIGNED_SUBTRACTION"),modes.contains("REAL_AS_FLOAT"),String.join(",",modes));
    }
}
