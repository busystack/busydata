package io.busystack.busydata.analysis.language;

/** Structured local diagnostic. The protocol mapper owns user-facing serialization. */
public record LanguageIssue(String code,String source,String severity,int start,int end,String message,boolean incomplete) {
    public static LanguageIssue syntax(String code,int start,int end,String message){return new LanguageIssue(code,"parser","error",start,end,message,false);}
    public static LanguageIssue semantic(String code,int start,int end,String message){return new LanguageIssue(code,"binder","error",start,end,message,false);}
    public static LanguageIssue unavailable(int start,int end,String message){return new LanguageIssue("analysis.unavailable","availability","hint",start,end,message,true);}
}
