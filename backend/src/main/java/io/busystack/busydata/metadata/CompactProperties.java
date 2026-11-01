package io.busystack.busydata.metadata;

import java.nio.charset.StandardCharsets;
import java.util.*;

/** Lossless immutable native attributes; common key layouts are shared, values stay encoded. */
public final class CompactProperties extends AbstractMap<String,String> {
    private static final int MAX_LAYOUTS=128,MAX_LAYOUT_BYTES=1_048_576,MAX_VALUE_BYTES=1_048_576;
    private static final LinkedHashMap<List<String>,Layout> LAYOUTS=new LinkedHashMap<>(16,.75f,true);
    private static int layoutBytes;
    private record Layout(String[] keys,int bytes){}
    private final Layout layout;
    private final byte[] data;
    private final int[] offsets;
    private final String[] exceptional;
    private final int hash;
    private CompactProperties(Map<String,String> source) {
        if(source.size()>4096)throw new IllegalArgumentException("Metadata attribute count exceeds its budget");
        var keys=source.keySet().toArray(String[]::new);Arrays.sort(keys);layout=layout(keys);
        var encoded=new byte[keys.length][];String[] unusual=null;int bytes=0,calculatedHash=0;
        for(int index=0;index<keys.length;index++) {
            String value=Objects.requireNonNull(source.get(keys[index]));var utf8=value.getBytes(StandardCharsets.UTF_8);
            if((bytes+=utf8.length)>MAX_VALUE_BYTES)throw new IllegalArgumentException("Metadata encoded attributes exceed their byte budget");
            // JDBC/protobuf native strings are normally Unicode scalar text.
            // A synthetic malformed UTF-16 value still must not be transformed.
            if(hasUnpairedSurrogate(value)){if(unusual==null)unusual=new String[keys.length];unusual[index]=value;encoded[index]=new byte[0];bytes-=utf8.length;}
            else encoded[index]=utf8;
            calculatedHash+=keys[index].hashCode()^value.hashCode();
        }
        data=new byte[bytes];offsets=new int[keys.length+1];exceptional=unusual;hash=calculatedHash;int cursor=0;
        for(int index=0;index<keys.length;index++){offsets[index]=cursor;System.arraycopy(encoded[index],0,data,cursor,encoded[index].length);cursor+=encoded[index].length;}offsets[keys.length]=cursor;
    }
    public static Map<String,String> copyOf(Map<String,String> source){if(source instanceof CompactProperties||source.isEmpty())return source.isEmpty()?Map.of():source;return new CompactProperties(source);}
    private static Layout layout(String[] keys) {
        var key=List.of(keys);synchronized(LAYOUTS){var known=LAYOUTS.get(key);if(known!=null)return known;
            int bytes=32+8*keys.length;for(String value:keys)bytes+=40+2*value.length();var layout=new Layout(keys,bytes);
            if(bytes<=MAX_LAYOUT_BYTES){while(!LAYOUTS.isEmpty()&&(LAYOUTS.size()>=MAX_LAYOUTS||layoutBytes+bytes>MAX_LAYOUT_BYTES)){var oldest=LAYOUTS.entrySet().iterator();var removed=oldest.next();layoutBytes-=removed.getValue().bytes();oldest.remove();}LAYOUTS.put(key,layout);layoutBytes+=bytes;}
            return layout;
        }
    }
    private static boolean hasUnpairedSurrogate(String value){for(int index=0;index<value.length();index++){char current=value.charAt(index);if(Character.isHighSurrogate(current)){if(index+1>=value.length()||!Character.isLowSurrogate(value.charAt(++index)))return true;}else if(Character.isLowSurrogate(current))return true;}return false;}
    private String value(int index){return exceptional!=null&&exceptional[index]!=null?exceptional[index]:new String(data,offsets[index],offsets[index+1]-offsets[index],StandardCharsets.UTF_8);}
    @Override public String get(Object key){if(!(key instanceof String name))return null;int index=Arrays.binarySearch(layout.keys(),name);return index<0?null:value(index);}
    @Override public boolean containsKey(Object key){return key instanceof String name&&Arrays.binarySearch(layout.keys(),name)>=0;}
    @Override public int size(){return layout.keys().length;}
    @Override public int hashCode(){return hash;}
    @Override public boolean equals(Object other){if(this==other)return true;if(other instanceof CompactProperties compact)return (layout==compact.layout||Arrays.equals(layout.keys(),compact.layout.keys()))&&Arrays.equals(offsets,compact.offsets)&&Arrays.equals(data,compact.data)&&Arrays.equals(exceptional,compact.exceptional);return super.equals(other);}
    @Override public Set<Entry<String,String>> entrySet(){return new AbstractSet<>(){@Override public int size(){return CompactProperties.this.size();}@Override public Iterator<Entry<String,String>> iterator(){return new Iterator<>(){int index;@Override public boolean hasNext(){return index<size();}@Override public Entry<String,String> next(){if(!hasNext())throw new NoSuchElementException();int at=index++;return Map.entry(layout.keys()[at],value(at));}};}};}
    @Override public String put(String key,String value){throw new UnsupportedOperationException("Immutable metadata attributes");}
    @Override public String remove(Object key){throw new UnsupportedOperationException("Immutable metadata attributes");}
    @Override public void putAll(Map<? extends String,? extends String> values){throw new UnsupportedOperationException("Immutable metadata attributes");}
    @Override public void clear(){throw new UnsupportedOperationException("Immutable metadata attributes");}
    /** Includes a conservative share of the bounded shared layout. */
    public long estimatedBytes(){long bytes=80L+4L*offsets.length+data.length+8L*layout.keys().length;if(exceptional!=null){bytes+=16L+8L*exceptional.length;for(String value:exceptional)if(value!=null)bytes+=40L+2L*value.length();}return bytes;}
    Object layoutIdentity(){return layout;}
    long layoutBytes(){return layout.bytes();}
}
