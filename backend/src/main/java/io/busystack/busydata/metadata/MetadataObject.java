package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.*;
import java.util.*;

/** Immutable normalized semantic object. The protobuf is only a consumer projection. */
public record MetadataObject(MetadataIdentity identity,String displayName,String quotedIdentifier,String lookupKey,
        Map<String,String> properties,String source,IntrospectionLevel level,MetadataState state,long sourceRevision,long contextRevision) {
    public MetadataObject {
        Objects.requireNonNull(identity);Objects.requireNonNull(level);Objects.requireNonNull(state);
        // These adapter fields have a defined empty/not-applicable value. Do
        // not allocate their entries on every ordinary non-array column.
        // Presence-sensitive enum labels and explicit availability fields stay.
        if(properties.entrySet().stream().anyMatch(e->e.getValue().isEmpty()&&EMPTY_OPTIONAL.contains(e.getKey()))){var compact=new HashMap<>(properties);compact.entrySet().removeIf(e->e.getValue().isEmpty()&&EMPTY_OPTIONAL.contains(e.getKey()));properties=compact;}
        if(displayName.length()>8192||source.length()>65536||properties.size()>4096)throw new IllegalArgumentException("Metadata object exceeds its budget");
        for(var p:properties.entrySet())if(p.getKey().length()>256||p.getValue().length()>65536)throw new IllegalArgumentException("Metadata property exceeds its budget");
        properties=CompactProperties.copyOf(properties);
    }
    private static final Set<String> EMPTY_OPTIONAL=Set.of("nativeId","parentNativeId","nativeTypeId","domainBaseType","arrayElementSchema","arrayElementType","arrayElementKind","arrayElementCategory","arrayElementBaseType","arrayElementBaseSchema","arrayElementBaseName","generatedKind","identityKind","generationExpression","collation","remarks");
    public static MetadataObject from(String sourceKey,String profileId,String sessionOwner,IdentifierRules rules,
            SchemaObject object,IntrospectionLevel level,long sourceRevision,long contextRevision) {
        var identity=new MetadataIdentity(sourceKey,profileId,object.getCatalog(),object.getSchema(),object.getKind(),object.getSubtype(),object.getTable(),object.getName(),object.getIdentifier(),sessionOwner,rules.engine()==Engine.POSTGRESQL?object.getPropertiesOrDefault("nativeId",""):"");
        var properties=new HashMap<>(object.getPropertiesMap());
        if(!sessionOwner.isEmpty()){properties.put("sessionOwner",sessionOwner);if(object.getSchema().startsWith("pg_temp_"))properties.put("temporary","true");}
        String type=rules.engine()!=Engine.POSTGRESQL&&object.getKind()==ObjectKind.CONSTRAINT?properties.getOrDefault("type",""):"";
        return new MetadataObject(typedIdentity(identity,rules,type),object.getName(),rules.quote(object.getName()),rules.lookup(object.getKind(),object.getName(),true,type),properties,object.getDefinition(),level,MetadataState.AVAILABLE,sourceRevision,contextRevision);
    }
    /** Name indexes belong to one immutable rule generation. Exact names,
     * structural properties and wire identifiers are never rewritten. */
    public MetadataObject withRules(IdentifierRules rules) {
        String type=rules.engine()!=Engine.POSTGRESQL&&identity.kind()==ObjectKind.CONSTRAINT?properties.getOrDefault("type",""):"";
        String lookup=rules.lookup(identity.kind(),identity.name(),true,type);
        var normalized=typedIdentity(identity,rules,type);
        if(normalized==identity&&lookup.equals(lookupKey))return this;
        return new MetadataObject(normalized,displayName,quotedIdentifier,lookup,properties,source,level,state,sourceRevision,contextRevision);
    }
    private static MetadataIdentity typedIdentity(MetadataIdentity identity,IdentifierRules rules,String type){
        if(rules.engine()!=Engine.POSTGRESQL&&identity.kind()==ObjectKind.CONSTRAINT){
            // MySQL/MariaDB expose separate native constraint namespaces.
            // The actual TABLE_CONSTRAINTS type is both the discriminator
            // and the existing wire identifier for selecting that exact row.
            // No synthetic native ID or second identity mechanism is added.
            if(!type.equals(identity.signature())||!identity.nativeKey().isEmpty())return new MetadataIdentity(identity.source(),identity.profileId(),identity.catalog(),identity.schema(),identity.kind(),identity.subtype(),identity.parent(),identity.name(),type,identity.sessionOwner(),"");
        }
        return identity;
    }
    public SchemaObject projection(long snapshotRevision,long configurationRevision) {
        return projection(snapshotRevision,configurationRevision,"");
    }
    public SchemaObject projection(long snapshotRevision,long configurationRevision,String parentIdentity) {
        return SchemaObject.newBuilder().setName(displayName).setKind(identity.kind()).setSubtype(identity.subtype())
            .setCatalog(identity.catalog()).setSchema(identity.schema()).setTable(identity.parent()).setIdentifier(identity.signature())
            .setStableIdentity(identity.key()).setQuotedIdentifier(quotedIdentifier).setNormalizedIdentifier(lookupKey)
            .setMetadataSnapshotRevision(snapshotRevision).setIntrospectionLevel(level.number()).setMetadataState(state.name()).setSourceRevision(Long.toString(sourceRevision))
            .setParentIdentity(parentIdentity)
            .setDefinition(source).putAllProperties(properties).build();
    }
    public boolean sameContent(MetadataObject other){return identity.equals(other.identity)&&displayName.equals(other.displayName)&&quotedIdentifier.equals(other.quotedIdentifier)&&lookupKey.equals(other.lookupKey)&&properties.equals(other.properties)&&source.equals(other.source)&&level==other.level&&state==other.state;}
    public long estimatedBytes(){long bytes=384L+2L*(displayName.length()+quotedIdentifier.length()+lookupKey.length()+source.length()+identity.estimatedCharacters());if(properties instanceof CompactProperties compact)return bytes+compact.estimatedBytes();for(var property:properties.entrySet())bytes+=64L+2L*(property.getKey().length()+property.getValue().length());return bytes;}
}
