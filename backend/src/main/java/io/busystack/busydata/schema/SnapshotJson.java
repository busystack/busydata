package io.busystack.busydata.schema;

import com.google.gson.*;
import com.google.gson.stream.*;
import java.io.*;
import java.util.HashSet;

public final class SnapshotJson {
    private SnapshotJson(){}
    public static long encodedBytes(JsonElement value) {
        if(value.isJsonNull())return 4;
        if(value.isJsonPrimitive()){var primitive=value.getAsJsonPrimitive();return primitive.isString()?stringBytes(primitive.getAsString()):primitive.toString().length();}
        long size=2;
        if(value.isJsonArray())for(var entry:value.getAsJsonArray())size+=encodedBytes(entry)+1;
        else for(var entry:value.getAsJsonObject().entrySet())size+=stringBytes(entry.getKey())+encodedBytes(entry.getValue())+2;
        return size;
    }
    private static long stringBytes(String value) {
        long size=2;for(int i=0;i<value.length();i++){char c=value.charAt(i);if(c<32||c=='"'||c=='\\')size+=6;else if(c<128)size++;else if(c<2048)size+=2;else if(Character.isHighSurrogate(c)&&i+1<value.length()&&Character.isLowSurrogate(value.charAt(i+1))){size+=4;i++;}else size+=3;}return size;
    }
    public static JsonObject read(String text) {
        if(text.length()>8_388_608)throw new IllegalArgumentException("Snapshot exceeds 8Mi UTF-16 units");
        unicode(text);
        // Retain the existing raw quoted-string admission limit, including
        // escapes. Streaming decoding must not expand that limit implicitly.
        boolean quoted=false,escaped=false;int string=0;
        for(int i=0;i<text.length();i++) {
            char c=text.charAt(i);
            if(quoted){if(++string>1_048_576)throw new IllegalArgumentException("Snapshot string exceeds 1Mi UTF-16 units");if(escaped)escaped=false;else if(c=='\\')escaped=true;else if(c=='"')quoted=false;}
            else if(c=='"'){quoted=true;string=0;}
        }
        if(quoted)throw new IllegalArgumentException("Malformed snapshot");
        try(var reader=strict(text)){
            if(reader.peek()!=JsonToken.BEGIN_OBJECT)throw new IllegalArgumentException("Snapshot root must be an object");
            preflight(reader,new Nodes(),0);
            if(reader.peek()!=JsonToken.END_DOCUMENT)throw new IllegalArgumentException("Snapshot has trailing data");
        }catch(IOException|IllegalStateException malformed){throw new IllegalArgumentException("Malformed snapshot");}
        // Gson still owns the JSON value model and lazy numeric lexemes. No
        // source value is converted to double/long by the security preflight.
        try(var reader=strict(text)){return JsonParser.parseReader(reader).getAsJsonObject();}
        catch(IOException|JsonParseException|IllegalStateException malformed){throw new IllegalArgumentException("Malformed snapshot");}
    }
    private static JsonReader strict(String text){var reader=new JsonReader(new StringReader(text));reader.setStrictness(Strictness.STRICT);reader.setNestingLimit(32);return reader;}
    private static final class Nodes {private int count;void next(){if(++count>100_000)throw new IllegalArgumentException("Snapshot token budget exceeded");}}
    private static void preflight(JsonReader reader,Nodes nodes,int depth)throws IOException {
        nodes.next();
        switch(reader.peek()){
            case BEGIN_OBJECT->{
                if(depth>=32)throw new IllegalArgumentException("Snapshot nesting exceeds 32");reader.beginObject();var names=new HashSet<String>();
                while(reader.hasNext()){
                    nodes.next();String name=reader.nextName();string(name);
                    if(!names.add(name))throw new IllegalArgumentException("Snapshot contains duplicate object keys");
                    preflight(reader,nodes,depth+1);
                }reader.endObject();
            }
            case BEGIN_ARRAY->{if(depth>=32)throw new IllegalArgumentException("Snapshot nesting exceeds 32");reader.beginArray();while(reader.hasNext())preflight(reader,nodes,depth+1);reader.endArray();}
            case STRING->string(reader.nextString());
            case NUMBER->reader.nextString();
            case BOOLEAN->reader.nextBoolean();
            case NULL->reader.nextNull();
            default->throw new IllegalArgumentException("Malformed snapshot");
        }
    }
    private static void string(String value){if(value.length()>1_048_576)throw new IllegalArgumentException("Snapshot string exceeds 1Mi UTF-16 units");unicode(value);}
    private static void unicode(String value){
        for(int i=0;i<value.length();i++){
            char c=value.charAt(i);
            if(Character.isHighSurrogate(c)){if(++i>=value.length()||!Character.isLowSurrogate(value.charAt(i)))throw new IllegalArgumentException("Snapshot contains invalid Unicode");}
            else if(Character.isLowSurrogate(c))throw new IllegalArgumentException("Snapshot contains invalid Unicode");
        }
    }
}
