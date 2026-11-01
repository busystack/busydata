package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.*;
import java.util.*;

/** Coverage scope. A filtered enumeration cannot establish absence outside its filter. */
public record MetadataScope(String catalog,String schema,String parent,ObjectKind kind,
        String search,boolean exactName,String signature,ObjectSubtype subtype) {
    public MetadataScope {
        for(String value:List.of(catalog,schema,parent,search))if(value.length()>256||value.indexOf('\0')>=0)throw new IllegalArgumentException("Invalid metadata scope");
        if(signature.length()>8192||signature.indexOf('\0')>=0)throw new IllegalArgumentException("Invalid metadata signature");
    }
    public MetadataScope(String catalog,String schema,String parent,ObjectKind kind){this(catalog,schema,parent,kind,"",false,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED);}
    public String key(){return MetadataIdentity.digest(catalog,schema,parent,kind.name(),search,Boolean.toString(exactName),signature,subtype.name());}
    public boolean contains(MetadataObject object) {
        var i=object.identity();
        return i.kind()==kind&&(catalog.isEmpty()||catalog.equals(i.catalog()))&&(schema.isEmpty()||schema.equals(i.schema()))
            &&(parent.isEmpty()||parent.equals(i.parent()))&&(signature.isEmpty()||signature.equals(i.signature()))
            &&(subtype==ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED||subtype==i.subtype())
            &&(exactName?search.equals(i.name()):i.name().toLowerCase(Locale.ROOT).contains(search.toLowerCase(Locale.ROOT)));
    }
    public boolean broad(){return search.isEmpty()&&signature.isEmpty()&&subtype==ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED;}
    public boolean overlaps(MetadataScope other) {
        if(kind!=other.kind||!compatible(catalog,other.catalog)||!compatible(schema,other.schema)||!compatible(parent,other.parent))return false;
        if(!signature.isEmpty()&&!other.signature.isEmpty()&&!signature.equals(other.signature))return false;
        if(subtype!=ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED&&other.subtype!=ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED&&subtype!=other.subtype)return false;
        if(exactName&&other.exactName)return search.equals(other.search);
        if(exactName)return search.toLowerCase(Locale.ROOT).contains(other.search.toLowerCase(Locale.ROOT));
        if(other.exactName)return other.search.toLowerCase(Locale.ROOT).contains(search.toLowerCase(Locale.ROOT));
        return true;
    }
    public boolean encloses(MetadataScope other) {
        if(kind!=other.kind||!encloses(catalog,other.catalog)||!encloses(schema,other.schema)||!encloses(parent,other.parent))return false;
        if(!signature.isEmpty()&&!signature.equals(other.signature))return false;
        if(subtype!=ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED&&other.subtype!=ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED&&subtype!=other.subtype)return false;
        if(exactName)return other.exactName&&search.equals(other.search);
        return other.search.toLowerCase(Locale.ROOT).contains(search.toLowerCase(Locale.ROOT));
    }
    private static boolean compatible(String one,String two){return one.isEmpty()||two.isEmpty()||one.equals(two);}
    private static boolean encloses(String one,String two){return one.isEmpty()||one.equals(two);}
}
