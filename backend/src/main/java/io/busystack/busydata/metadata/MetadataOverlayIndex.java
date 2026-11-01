package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.*;
import java.util.*;
import java.util.function.*;

/** Immutable composition indexes. Only the owned delta and visibility/rank masks
 * are allocated; durable identity/name/namespace indexes remain shared. */
final class MetadataOverlayIndex {
    private MetadataOverlayIndex(){}
    private static final Comparator<MetadataObject> ORDER=Comparator.comparing((MetadataObject o)->o.identity().name()).thenComparing(o->o.identity().parent()).thenComparing(o->o.identity().signature());
    record Prepared(MetadataSnapshot.Indexes indexes,long indexCharge){}

    /** Eight exact/prefix bucket probes, independent of durable catalog size.
     * The supplied MetadataScope owns matching policy; no dialect rules live here. */
    static final class ScopeMask {
        private final MetadataScope[] exact,ranged;private final Set<ObjectKind> kinds;private final long deadline;
        ScopeMask(Collection<MetadataScope> values){this(values,Long.MAX_VALUE);}
        ScopeMask(Collection<MetadataScope> values,long deadline){this.deadline=deadline;var kinds=EnumSet.noneOf(ObjectKind.class);int count=0;for(var scope:values){kinds.add(scope.kind());if(scope.exactName())count++;}exact=new MetadataScope[count];ranged=new MetadataScope[values.size()-count];int a=0,b=0;for(var scope:values)if(scope.exactName())exact[a++]=scope;else ranged[b++]=scope;Arrays.sort(exact,(one,two)->compare(one,two.kind(),two.catalog(),two.schema(),two.parent(),two.search(),two.signature(),two.subtype()));Arrays.sort(ranged,(one,two)->compare(one,two.kind(),two.catalog(),two.schema(),two.parent(),"",two.signature(),two.subtype()));this.kinds=Set.copyOf(kinds);}
        boolean hasKind(ObjectKind kind){return kinds.contains(kind);}
        private void poll(long queryDeadline){if(io.grpc.Context.current().isCancelled()||Thread.currentThread().isInterrupted())throw new java.util.concurrent.CancellationException("Metadata scope composition cancelled");MetadataSnapshot.checkBuild(queryDeadline);}
        private static int compare(MetadataScope scope,ObjectKind kind,String catalog,String schema,String parent,String name,String signature,ObjectSubtype subtype){int c=Integer.compare(scope.kind().getNumber(),kind.getNumber());if(c==0)c=scope.catalog().compareTo(catalog);if(c==0)c=scope.schema().compareTo(schema);if(c==0)c=scope.parent().compareTo(parent);if(c==0&&scope.exactName())c=scope.search().compareTo(name);if(c==0)c=scope.signature().compareTo(signature);if(c==0)c=Integer.compare(scope.subtype().getNumber(),subtype.getNumber());return c;}
        private int lower(MetadataScope[] values,ObjectKind kind,String catalog,String schema,String parent,String name,String signature,ObjectSubtype subtype){int lo=0,hi=values.length;while(lo<hi){int mid=(lo+hi)>>>1;if(compare(values[mid],kind,catalog,schema,parent,name,signature,subtype)<0)lo=mid+1;else hi=mid;}return lo;}
        private boolean bucket(MetadataObject object,String catalog,String schema,String parent,String signature,ObjectSubtype subtype,long queryDeadline){poll(queryDeadline);var i=object.identity();if(exact.length>0){int at=lower(exact,i.kind(),catalog,schema,parent,i.name(),signature,subtype);if(at<exact.length&&compare(exact[at],i.kind(),catalog,schema,parent,i.name(),signature,subtype)==0&&exact[at].contains(object))return true;}for(int at=lower(ranged,i.kind(),catalog,schema,parent,"",signature,subtype),seen=0;at<ranged.length&&compare(ranged[at],i.kind(),catalog,schema,parent,"",signature,subtype)==0;at++){if((seen++&63)==0)poll(queryDeadline);if(ranged[at].contains(object))return true;}return false;}
        boolean contains(MetadataObject object){return contains(object,Long.MAX_VALUE);}
        boolean contains(MetadataObject object,long queryDeadline){var i=object.identity();return hasKind(i.kind())&&probeCatalog(object,i.catalog(),Math.min(deadline,queryDeadline));}
        private boolean probeCatalog(MetadataObject object,String catalog,long deadline){return probeSchema(object,catalog,object.identity().schema(),deadline)||!catalog.isEmpty()&&probeSchema(object,"",object.identity().schema(),deadline);}
        private boolean probeSchema(MetadataObject object,String catalog,String schema,long deadline){return prefix(object.identity().kind(),catalog,schema)&&probeParent(object,catalog,schema,deadline)||!schema.isEmpty()&&prefix(object.identity().kind(),catalog,"")&&probeParent(object,catalog,"",deadline);}
        private boolean prefix(ObjectKind kind,String catalog,String schema){return prefix(exact,kind,catalog,schema)||prefix(ranged,kind,catalog,schema);}
        private boolean prefix(MetadataScope[] values,ObjectKind kind,String catalog,String schema){int at=lower(values,kind,catalog,schema,"","","",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED);return at<values.length&&values[at].kind()==kind&&values[at].catalog().equals(catalog)&&values[at].schema().equals(schema);}
        private boolean probeParent(MetadataObject object,String catalog,String schema,long deadline){String parent=object.identity().parent();return probeSignature(object,catalog,schema,parent,deadline)||!parent.isEmpty()&&probeSignature(object,catalog,schema,"",deadline);}
        private boolean probeSignature(MetadataObject object,String catalog,String schema,String parent,long deadline){String signature=object.identity().signature();return probeSubtype(object,catalog,schema,parent,signature,deadline)||!signature.isEmpty()&&probeSubtype(object,catalog,schema,parent,"",deadline);}
        private boolean probeSubtype(MetadataObject object,String catalog,String schema,String parent,String signature,long deadline){var subtype=object.identity().subtype();return bucket(object,catalog,schema,parent,signature,subtype,deadline)||subtype!=ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED&&bucket(object,catalog,schema,parent,signature,ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED,deadline);}
        boolean potential(MetadataSnapshot.Namespace namespace){return hasKind(namespace.kind())&&(potential(namespace,namespace.catalog(),namespace.schema())||!namespace.catalog().isEmpty()&&potential(namespace,"",namespace.schema())||!namespace.schema().isEmpty()&&potential(namespace,namespace.catalog(),"")||!namespace.catalog().isEmpty()&&!namespace.schema().isEmpty()&&potential(namespace,"",""));}
        private boolean potential(MetadataSnapshot.Namespace ns,String catalog,String schema){return prefix(exact,ns,catalog,schema,ns.parent())||prefix(ranged,ns,catalog,schema,ns.parent())||!ns.parent().isEmpty()&&(prefix(exact,ns,catalog,schema,"")||prefix(ranged,ns,catalog,schema,""));}
        private boolean prefix(MetadataScope[] values,MetadataSnapshot.Namespace ns,String catalog,String schema,String parent){int at=lower(values,ns.kind(),catalog,schema,parent,"","",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED);if(at>=values.length)return false;var scope=values[at];return scope.kind()==ns.kind()&&scope.catalog().equals(catalog)&&scope.schema().equals(schema)&&(ns.parent().isEmpty()||scope.parent().equals(parent));}
    }

    /** Sorted durable identity array is shared. A packed bit says only whether
     * that durable identity is hidden by an owned replacement. */
    private static final class Hidden {
        final MetadataObject[] lookup;final long[] words;private final Set<ObjectKind> kinds;private int count;
        Hidden(MetadataObject[] lookup,ScopeMask mask,Map<String,MetadataObject> delta,long deadline){this.lookup=lookup;words=new long[(lookup.length+63)>>>6];var hiddenKinds=EnumSet.noneOf(ObjectKind.class);for(int at=0;at<lookup.length;at++){if((at&255)==0)MetadataSnapshot.checkBuild(deadline);var object=lookup[at];if(mask.contains(object)||delta.containsKey(object.identity().key())){words[at>>>6]|=1L<<(at&63);hiddenKinds.add(object.identity().kind());count++;}}kinds=Set.copyOf(hiddenKinds);}
        boolean hasKind(ObjectKind kind){return kinds.contains(kind);}
        boolean contains(String key){if(count==0)return false;int lo=0,hi=lookup.length-1;while(lo<=hi){int mid=(lo+hi)>>>1;int c=lookup[mid].identity().key().compareTo(key);if(c<0)lo=mid+1;else if(c>0)hi=mid-1;else return (words[mid>>>6]&(1L<<(mid&63)))!=0;}return false;}
        boolean contains(MetadataObject object){return contains(object.identity().key());}
    }

    /** Random access over a shared list uses rank blocks and packed exclusions;
     * no full array of retained indexes or copied MetadataObject references. */
    private static final class RankedList extends AbstractList<MetadataObject> implements RandomAccess {
        private final List<MetadataObject> base;private final long[] excluded;private final int[] prefix;private final int size;
        private RankedList(List<MetadataObject> base,long[] excluded,int count){this.base=base;this.excluded=excluded;size=base.size()-count;int blocks=(base.size()+255)>>>8;prefix=new int[blocks+1];for(int block=0;block<blocks;block++){int visible=0;for(int word=block*4;word<Math.min(block*4+4,excluded.length);word++){int valid=Math.min(64,base.size()-(word<<6));visible+=valid-Long.bitCount(excluded[word]);}prefix[block+1]=prefix[block]+visible;}}
        static List<MetadataObject> filter(List<MetadataObject> base,Predicate<MetadataObject> predicate,long deadline){long[] bits=null;int count=0;for(int at=0;at<base.size();at++){if((at&255)==0)MetadataSnapshot.checkBuild(deadline);if(predicate.test(base.get(at))){if(bits==null)bits=new long[(base.size()+63)>>>6];bits[at>>>6]|=1L<<(at&63);count++;}}return count==0?base:count==base.size()?List.of():Collections.unmodifiableList(new RankedList(base,bits,count));}
        @Override public int size(){return size;}
        @Override public MetadataObject get(int index){Objects.checkIndex(index,size);int lo=0,hi=prefix.length-2;while(lo<hi){int mid=(lo+hi+1)>>>1;if(prefix[mid]<=index)lo=mid;else hi=mid-1;}int rank=index-prefix[lo];for(int word=lo*4;word<Math.min(lo*4+4,excluded.length);word++){int valid=Math.min(64,base.size()-(word<<6));long visible=~excluded[word]&(valid==64?-1L:(1L<<valid)-1);int found=Long.bitCount(visible);if(rank>=found){rank-=found;continue;}while(rank-->0)visible&=visible-1;return base.get((word<<6)+Long.numberOfTrailingZeros(visible));}throw new AssertionError("Invalid immutable rank index");}
        @Override public Iterator<MetadataObject> iterator(){return new Iterator<>(){int at;MetadataObject next;public boolean hasNext(){while(next==null&&at<base.size()){int i=at++;if((excluded[i>>>6]&(1L<<(i&63)))==0)next=base.get(i);}return next!=null;}public MetadataObject next(){if(!hasNext())throw new NoSuchElementException();var result=next;next=null;return result;}};}
    }
    private static final class ConcatList extends AbstractList<MetadataObject> implements RandomAccess {
        final List<MetadataObject> first,second;ConcatList(List<MetadataObject> first,List<MetadataObject> second){this.first=first;this.second=second;}@Override public int size(){return first.size()+second.size();}@Override public MetadataObject get(int at){Objects.checkIndex(at,size());return at<first.size()?first.get(at):second.get(at-first.size());}
    }
    private static List<MetadataObject> concat(List<MetadataObject> one,List<MetadataObject> two){return one.isEmpty()?two:two.isEmpty()?one:Collections.unmodifiableList(new ConcatList(one,two));}
    /** The kth element of two sorted shared lists needs logarithmic partition
     * probes; iteration is a simple merge and never materializes the namespace. */
    private static final class MergedList extends AbstractList<MetadataObject> implements RandomAccess {
        final List<MetadataObject> first,second;MergedList(List<MetadataObject> first,List<MetadataObject> second){this.first=first;this.second=second;}@Override public int size(){return first.size()+second.size();}
        @Override public MetadataObject get(int index){Objects.checkIndex(index,size());int count=index+1,lo=Math.max(0,count-second.size()),hi=Math.min(count,first.size());while(lo<=hi){int a=(lo+hi)>>>1,b=count-a;if(a>0&&b<second.size()&&ORDER.compare(first.get(a-1),second.get(b))>0){hi=a-1;continue;}if(b>0&&a<first.size()&&ORDER.compare(second.get(b-1),first.get(a))>=0){lo=a+1;continue;}if(a==0)return second.get(b-1);if(b==0)return first.get(a-1);return ORDER.compare(first.get(a-1),second.get(b-1))>0?first.get(a-1):second.get(b-1);}throw new AssertionError("Invalid immutable merge index");}
        @Override public Iterator<MetadataObject> iterator(){return new Iterator<>(){int a,b;public boolean hasNext(){return a<first.size()||b<second.size();}public MetadataObject next(){if(!hasNext())throw new NoSuchElementException();if(a==first.size())return second.get(b++);if(b==second.size()||ORDER.compare(first.get(a),second.get(b))<=0)return first.get(a++);return second.get(b++);}};}
    }
    private static List<MetadataObject> merge(List<MetadataObject> one,List<MetadataObject> two){return one.isEmpty()?two:two.isEmpty()?one:Collections.unmodifiableList(new MergedList(one,two));}

    /** Sparse immutable map overlay. Base keys retain their encounter position,
     * replacements are looked up directly, and no base key set is copied. */
    static final class Overrides<K,V> extends AbstractMap<K,V> {
        final Map<K,V> base,local;final Set<K> removed;final int size;
        Overrides(Map<K,V> base,Map<K,V> local,Set<K> removed){this.base=base;this.local=Map.copyOf(local);this.removed=Set.copyOf(removed);int n=base.size();for(K key:removed)if(base.containsKey(key)&&!local.containsKey(key))n--;for(K key:local.keySet())if(!base.containsKey(key))n++;size=n;}
        @Override public int size(){return size;}
        @Override public V get(Object key){V own=local.get(key);return own!=null?own:removed.contains(key)?null:base.get(key);}
        @Override public boolean containsKey(Object key){return get(key)!=null;}
        @Override public Set<Entry<K,V>> entrySet(){return new AbstractSet<>(){@Override public int size(){return size;}@Override public Iterator<Entry<K,V>> iterator(){return new Iterator<>(){final Iterator<K> parents=base.keySet().iterator(),added=local.keySet().iterator();Entry<K,V> next;public boolean hasNext(){while(next==null&&parents.hasNext()){K key=parents.next();V value=get(key);if(value!=null)next=Map.entry(key,value);}while(next==null&&added.hasNext()){K key=added.next();if(!base.containsKey(key))next=Map.entry(key,local.get(key));}return next!=null;}public Entry<K,V> next(){if(!hasNext())throw new NoSuchElementException();var value=next;next=null;return value;}};}};}
    }
    private static final class Identities extends AbstractMap<String,MetadataObject> {
        final Map<String,MetadataObject> base,local;final Hidden hidden;final List<MetadataObject> values;
        Identities(Map<String,MetadataObject> base,Map<String,MetadataObject> local,Hidden hidden,List<MetadataObject> values){this.base=base;this.local=local;this.hidden=hidden;this.values=values;}
        @Override public int size(){return values.size();}@Override public MetadataObject get(Object key){if(!(key instanceof String id))return null;var own=local.get(id);return own!=null?own:hidden.contains(id)?null:base.get(id);}@Override public boolean containsKey(Object key){return get(key)!=null;}@Override public Collection<MetadataObject> values(){return values;}
        @Override public Set<Entry<String,MetadataObject>> entrySet(){return new AbstractSet<>(){@Override public int size(){return values.size();}@Override public Iterator<Entry<String,MetadataObject>> iterator(){var iterator=values.iterator();return new Iterator<>(){public boolean hasNext(){return iterator.hasNext();}public Entry<String,MetadataObject> next(){var value=iterator.next();return Map.entry(value.identity().key(),value);}};}};}
    }
    /** Parent identity masks are queried lazily against the packed hidden index;
     * broad table replacements never allocate a catalog-sized removed-key set. */
    private static final class ParentMap extends AbstractMap<MetadataSnapshot.Relation,String> {
        final Map<MetadataSnapshot.Relation,String> base,local;final Hidden hidden;final int size;
        ParentMap(Map<MetadataSnapshot.Relation,String> base,Map<MetadataSnapshot.Relation,String> local,Hidden hidden,long deadline){this.base=base;this.local=local;this.hidden=hidden;int n=base.size(),seen=0;for(var entry:base.entrySet()){if((seen++&255)==0)MetadataSnapshot.checkBuild(deadline);if(hidden.contains(entry.getValue())&&!local.containsKey(entry.getKey()))n--;}for(var key:local.keySet())if(!base.containsKey(key))n++;size=n;}
        @Override public int size(){return size;}@Override public String get(Object key){var own=local.get(key);if(own!=null)return own;var inherited=base.get(key);return inherited==null||hidden.contains(inherited)?null:inherited;}@Override public boolean containsKey(Object key){return get(key)!=null;}
        @Override public Set<Entry<MetadataSnapshot.Relation,String>> entrySet(){return new AbstractSet<>(){@Override public int size(){return size;}@Override public Iterator<Entry<MetadataSnapshot.Relation,String>> iterator(){return new Iterator<>(){final Iterator<MetadataSnapshot.Relation> first=base.keySet().iterator(),second=local.keySet().iterator();Entry<MetadataSnapshot.Relation,String> next;public boolean hasNext(){while(next==null&&first.hasNext()){var key=first.next();var value=get(key);if(value!=null)next=Map.entry(key,value);}while(next==null&&second.hasNext()){var key=second.next();if(!base.containsKey(key))next=Map.entry(key,local.get(key));}return next!=null;}public Entry<MetadataSnapshot.Relation,String> next(){if(!hasNext())throw new NoSuchElementException();var result=next;next=null;return result;}};}};}
    }
    private static List<MetadataObject> list(Object value){return value==null?List.of():value instanceof MetadataObject object?List.of(object):cast(value);}
    @SuppressWarnings("unchecked") private static List<MetadataObject> cast(Object value){return (List<MetadataObject>)value;}
    private static Object nameValue(List<MetadataObject> values){return values.isEmpty()?null:values.size()==1?values.getFirst():values;}
    /** Only an already indexed same-name candidate list is filtered on lookup;
     * the cost depends on that overload/output-name group, never the catalog. */
    private static final class NameMap extends AbstractMap<String,Object> {
        final Map<String,Object> base,local;final Hidden hidden;
        NameMap(Map<String,Object> base,Map<String,Object> local,Hidden hidden){this.base=base;this.local=local;this.hidden=hidden;}
        @Override public Object get(Object key){var known=list(base.get(key));List<MetadataObject> kept;if(known.size()==1)kept=hidden.contains(known.getFirst())?List.of():known;else kept=RankedList.filter(known,hidden::contains,Long.MAX_VALUE);return nameValue(concat(kept,list(local.get(key))));}
        @Override public boolean containsKey(Object key){return get(key)!=null;}
        @Override public int size(){int size=0;for(var ignored:entrySet())size++;return size;}
        @Override public Set<Entry<String,Object>> entrySet(){return new AbstractSet<>(){@Override public int size(){return NameMap.this.size();}@Override public Iterator<Entry<String,Object>> iterator(){return new Iterator<>(){final Iterator<String> first=base.keySet().iterator(),second=local.keySet().iterator();Entry<String,Object> next;public boolean hasNext(){while(next==null&&first.hasNext()){String key=first.next();Object value=get(key);if(value!=null)next=Map.entry(key,value);}while(next==null&&second.hasNext()){String key=second.next();if(!base.containsKey(key))next=Map.entry(key,local.get(key));}return next!=null;}public Entry<String,Object> next(){if(!hasNext())throw new NoSuchElementException();var result=next;next=null;return result;}};}};}
    }

    static Prepared prepare(MetadataSnapshot base,MetadataSnapshot delta,Set<MetadataScope> scopes,Map<MetadataScope,MetadataCoverage> coverage,Set<MetadataScope> removed,long deadline){
        var b=base.indexes();var d=delta.indexes();
        if(d.identities().isEmpty()&&scopes.isEmpty()){
            var states=Collections.unmodifiableMap(new Overrides<>(base.catalogCoverage(),coverage,removed));
            return new Prepared(new MetadataSnapshot.Indexes(b.identities(),b.ordered(),null,b.namespaces(),b.names(),b.kinds(),b.incoming(),b.parents(),states,List.of()),indexCharge(base,0,scopes,coverage.size(),removed.size()));
        }
        var mask=new ScopeMask(scopes,deadline);var hidden=new Hidden(b.lookup(),mask,d.identities(),deadline);
        var ordered=concat(RankedList.filter(b.ordered(),hidden::contains,deadline),d.ordered());
        if(ordered.size()>MetadataSnapshot.MAX_OBJECTS)throw new IllegalArgumentException("Composed metadata object budget exceeded");
        var identities=hidden.count==0&&d.identities().isEmpty()?b.identities():Collections.unmodifiableMap(new Identities(b.identities(),d.identities(),hidden,ordered));
        var namespaceOverrides=new HashMap<MetadataSnapshot.Namespace,List<MetadataObject>>();var nameOverrides=new HashMap<MetadataSnapshot.Namespace,Map<String,Object>>();
        for(var branch:b.namespaces().entrySet()){
            MetadataSnapshot.checkBuild(deadline);var key=branch.getKey();var own=d.namespaces().getOrDefault(key,List.of());if(own.isEmpty()&&!mask.potential(key))continue;
            var visible=RankedList.filter(branch.getValue(),hidden::contains,deadline);if(visible==branch.getValue()&&own.isEmpty())continue;namespaceOverrides.put(key,merge(visible,own));nameOverrides.put(key,Collections.unmodifiableMap(new NameMap(b.names().getOrDefault(key,Map.of()),d.names().getOrDefault(key,Map.of()),hidden)));
        }
        for(var branch:d.namespaces().entrySet())if(!b.namespaces().containsKey(branch.getKey())){namespaceOverrides.put(branch.getKey(),branch.getValue());nameOverrides.put(branch.getKey(),d.names().get(branch.getKey()));}
        var namespaces=Collections.unmodifiableMap(new Overrides<>(b.namespaces(),namespaceOverrides,Set.of()));var names=Collections.unmodifiableMap(new Overrides<>(b.names(),nameOverrides,Set.of()));
        var kinds=new EnumMap<ObjectKind,List<List<MetadataObject>>>(ObjectKind.class);kinds.putAll(b.kinds());var changedKinds=EnumSet.noneOf(ObjectKind.class);for(var key:namespaceOverrides.keySet())if(key.parent().isEmpty())changedKinds.add(key.kind());for(var kind:changedKinds){var branches=new ArrayList<List<MetadataObject>>();int seen=0;for(var branch:namespaces.entrySet()){if((seen++&255)==0)MetadataSnapshot.checkBuild(deadline);if(branch.getKey().kind()==kind&&branch.getKey().parent().isEmpty()&&!branch.getValue().isEmpty())branches.add(branch.getValue());}kinds.put(kind,List.copyOf(branches));}
        var parents=!hidden.hasKind(ObjectKind.TABLE)&&!hidden.hasKind(ObjectKind.VIEW)&&d.parents().isEmpty()?b.parents():Collections.unmodifiableMap(new ParentMap(b.parents(),d.parents(),hidden,deadline));
        Map<MetadataSnapshot.Relation,List<MetadataObject>> incoming;
        if(!hidden.hasKind(ObjectKind.FOREIGN_KEY)&&d.incoming().isEmpty())incoming=b.incoming();
        else{var incomingOverrides=new HashMap<MetadataSnapshot.Relation,List<MetadataObject>>();for(var entry:b.incoming().entrySet()){MetadataSnapshot.checkBuild(deadline);var own=d.incoming().getOrDefault(entry.getKey(),List.of());var kept=RankedList.filter(entry.getValue(),hidden::contains,deadline);if(kept!=entry.getValue()||!own.isEmpty())incomingOverrides.put(entry.getKey(),concat(kept,own));}for(var entry:d.incoming().entrySet())if(!b.incoming().containsKey(entry.getKey()))incomingOverrides.put(entry.getKey(),entry.getValue());incoming=Collections.unmodifiableMap(new Overrides<>(b.incoming(),incomingOverrides,Set.of()));}
        var states=Collections.unmodifiableMap(new Overrides<>(base.catalogCoverage(),coverage,removed));
        var indexes=new MetadataSnapshot.Indexes(identities,ordered,null,namespaces,names,Map.copyOf(kinds),incoming,parents,states,List.of());
        return new Prepared(indexes,indexCharge(base,delta.identities().size(),scopes,coverage.size(),removed.size()));
    }
    static long indexCharge(MetadataSnapshot base,int facts,Set<MetadataScope> scopes,int coverage,int removed){
        long bytes=4096L+512L*facts+768L*scopes.size()+384L*coverage+128L*removed;if(facts==0&&scopes.isEmpty())return bytes;
        var index=base.indexes();var mask=new ScopeMask(scopes);
        bytes+=16L*((index.lookup().length+63L)/64)+4L*((index.ordered().size()+255L)/256+1);
        for(var branch:index.namespaces().entrySet()){if(mask.potential(branch.getKey()))bytes+=512L+8L*((branch.getValue().size()+63L)/64)+4L*((branch.getValue().size()+255L)/256+1);if(branch.getKey().parent().isEmpty()&&mask.hasKind(branch.getKey().kind()))bytes+=16;}
        if(mask.hasKind(ObjectKind.FOREIGN_KEY))for(var edges:index.incoming().values())bytes+=384L+8L*((edges.size()+63L)/64)+4L*((edges.size()+255L)/256+1);
        return bytes;
    }
}
