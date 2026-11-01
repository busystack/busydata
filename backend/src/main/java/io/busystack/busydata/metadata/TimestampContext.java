package io.busystack.busydata.metadata;

import io.busystack.busydata.adapters.JdbcAdapter.LiveContext;
import java.util.regex.Pattern;

/** Proof for MySQL/MariaDB TIMESTAMP wall-clock transport, never a timezone database. */
public final class TimestampContext {
    private static final Pattern OFFSET=Pattern.compile("[+-][0-9]{2}:[0-9]{2}");
    private TimestampContext(){}
    public static String key(LiveContext context){return context==null?"":key(context.timeZone(),context.systemTimeZone());}
    public static String key(String sessionZone,String systemZone){
        if("SYSTEM".equalsIgnoreCase(sessionZone))return "UTC".equalsIgnoreCase(systemZone)?"timestamp-offset:+00:00":"";
        if(sessionZone==null||!OFFSET.matcher(sessionZone).matches())return "";
        int hour=Integer.parseInt(sessionZone.substring(1,3)),minute=Integer.parseInt(sessionZone.substring(4,6));boolean negative=sessionZone.charAt(0)=='-';
        if(minute>59||hour>14||hour==14&&(negative||minute!=0))return "";
        return "timestamp-offset:"+(hour==0&&minute==0?"+00:00":sessionZone);
    }
}
