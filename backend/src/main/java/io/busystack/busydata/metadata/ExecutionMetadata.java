package io.busystack.busydata.metadata;

import io.busystack.busydata.adapters.JdbcAdapter.LiveContext;
import io.busystack.busydata.protocol.*;
import java.util.*;

/** Bounded pre-execution evidence. It owns no catalog, native metadata object,
 * projection, syntax tree, session, connection or catalog index. */
public final class ExecutionMetadata {
    public static final int MAX_COLUMNS=2048;
    public static final long MAX_BYTES=1_048_576;
    private static final Value ARRAY_TEXT_CONTEXT=Value.newBuilder().setArray(ArrayValue.newBuilder().setNativeLiteral("{}")).build();
    private record ColumnEvidence(RetainedMetadataProof.ColumnProof proof,boolean array,String element,RetainedMetadataProof failure){
        long estimatedBytes(){return 128L+2L*element.length()+(proof==null?0:96L+2L*(proof.identity().length()+proof.nativeTypeId().length()+proof.jdbcNativeType().length()+proof.fingerprint().length()))+(failure==null?0:failure.estimatedBytes()+2L*failure.availability().length());}
    }
    /** Lookup is separated from evidence/finalization; both captured and fresh
     * native facts use precisely the same identity, type and context rules. */
    private interface ColumnSource {
        boolean complete();MetadataState state();List<MetadataObject> all();List<MetadataObject> named(String name);
    }
    private record SnapshotColumns(MetadataSnapshot snapshot,MetadataIdentity relation) implements ColumnSource {
        private MetadataScope scope(){return new MetadataScope(relation.catalog(),relation.schema(),relation.name(),ObjectKind.COLUMN);}
        public boolean complete(){return snapshot.complete(scope(),IntrospectionLevel.STRUCTURE);}
        public MetadataState state(){return snapshot.coverage(scope()).map(MetadataCoverage::state).filter(value->value!=MetadataState.AVAILABLE).orElse(MetadataState.PARTIAL);}
        public List<MetadataObject> all(){return snapshot.namespace(relation.catalog(),relation.schema(),ObjectKind.COLUMN,relation.name());}
        public List<MetadataObject> named(String name){return snapshot.resolve(relation.catalog(),relation.schema(),ObjectKind.COLUMN,relation.name(),name,true);}
    }
    private static final class NativeColumns implements ColumnSource {
        private final MetadataSnapshot snapshot;private final String owner;private final List<SchemaObject> columns;
        private final long revision,context;private final MetadataPlatform.AcquisitionAdmission admission;private final Runnable guard;
        private final Map<String,List<SchemaObject>> names=new HashMap<>();
        NativeColumns(MetadataSnapshot snapshot,String owner,List<SchemaObject> columns,long revision,long context,MetadataPlatform.AcquisitionAdmission admission,Runnable guard){
            this.snapshot=snapshot;this.owner=owner;this.columns=columns;this.revision=revision;this.context=context;this.admission=admission;this.guard=guard;
            long indexBytes=1024L+320L*columns.size();for(var column:columns)indexBytes+=8L*column.getName().length();admission.reserveAdditional(indexBytes);
            for(var column:columns){guard.run();names.computeIfAbsent(snapshot.rules().lookup(ObjectKind.COLUMN,column.getName(),true),ignored->new ArrayList<>()).add(column);}
        }
        private MetadataObject normalize(SchemaObject column){guard.run();var result=MetadataObject.from(snapshot.source(),snapshot.profileId(),owner,snapshot.rules(),column,IntrospectionLevel.STRUCTURE,revision,context);admission.reserveOwnedObject(result);guard.run();return result;}
        public boolean complete(){return true;}
        public MetadataState state(){return MetadataState.AVAILABLE;}
        public List<MetadataObject> all(){return columns.stream().map(this::normalize).toList();}
        public List<MetadataObject> named(String name){return names.getOrDefault(snapshot.rules().lookup(ObjectKind.COLUMN,name,true),List.of()).stream().map(this::normalize).toList();}
    }
    /** Fresh evidence is compacted immediately by proof(); this helper never
     * retains a snapshot beyond the caller's bounded extraction phase. */
    static ExecutionMetadata inspected(MetadataSnapshot snapshot,SchemaObject relation,TableStructure table,List<Column> selected,
            Profile target,String sessionId,LiveContext context,MetadataConfiguration configuration,long revision,long contextRevision,
            MetadataPlatform.AcquisitionAdmission admission,Runnable guard){
        guard.run();if(snapshot==null||!snapshot.identifierRulesAvailable())return unavailable("Native identifier comparison evidence is unavailable");
        if(selected.isEmpty()||selected.size()>MAX_COLUMNS||table.columns().size()>MAX_COLUMNS)return limited();
        if(!MetadataPlatform.permitsInspection(configuration,target.getEngine(),context,relation.getCatalog(),relation.getSchema(),relation.getName(),ObjectKind.TABLE)
            ||!MetadataPlatform.permitsInspection(configuration,target.getEngine(),context,relation.getCatalog(),relation.getSchema(),relation.getName(),ObjectKind.COLUMN))
            return new ExecutionMetadata(RetainedMetadataProof.unavailable(MetadataState.NOT_REQUESTED,"The inspected relation or columns are excluded by metadata configuration"));
        for(var column:table.columns())if(column.getKind()!=ObjectKind.COLUMN
            ||!snapshot.rules().lookup(ObjectKind.CATALOG,column.getCatalog(),true).equals(snapshot.rules().lookup(ObjectKind.CATALOG,relation.getCatalog(),true))
            ||!snapshot.rules().lookup(ObjectKind.SCHEMA,column.getSchema(),true).equals(snapshot.rules().lookup(ObjectKind.SCHEMA,relation.getSchema(),true))
            ||!snapshot.rules().lookup(ObjectKind.TABLE,column.getTable(),true).equals(snapshot.rules().lookup(ObjectKind.TABLE,relation.getName(),true)))
            return unavailable("Native inspected column belongs to a different physical relation");
        String owner=relation.getSchema().startsWith("pg_temp_")||"true".equals(relation.getPropertiesOrDefault("temporary",""))?sessionId:"";
        var normalized=MetadataObject.from(snapshot.source(),snapshot.profileId(),owner,snapshot.rules(),relation,IntrospectionLevel.STRUCTURE,revision,contextRevision);admission.reserveOwnedObject(normalized);
        return collect(snapshot,normalized,target,sessionId,context,selected,new NativeColumns(snapshot,owner,table.columns(),revision,contextRevision,admission,guard));
    }
    private final Engine engine;private final String source,catalog,schema,table,identity,generation,fallbackCatalog;
    private final long snapshotRevision,configurationRevision,estimatedBytes;
    private final IdentifierRules rules;private final LiveContext context;
    private final Map<String,ColumnEvidence> columns;
    private final RetainedMetadataProof failure;
    private ExecutionMetadata(RetainedMetadataProof failure){this.engine=Engine.ENGINE_UNSPECIFIED;source=catalog=schema=table=identity=generation=fallbackCatalog="";snapshotRevision=configurationRevision=0;rules=null;context=null;columns=Map.of();this.failure=Objects.requireNonNull(failure);estimatedBytes=256L+failure.estimatedBytes()+2L*failure.availability().length();}
    private ExecutionMetadata(MetadataSnapshot snapshot,MetadataObject relation,Profile target,LiveContext context,Map<String,ColumnEvidence> columns,long bytes){
        engine=target.getEngine();source=snapshot.source();snapshotRevision=snapshot.revision();configurationRevision=snapshot.configurationRevision();
        var id=relation.identity();catalog=id.catalog();schema=id.schema();table=id.name();identity=id.key();generation=relation.properties().getOrDefault("nativeGeneration","");fallbackCatalog=target.getDatabase();rules=snapshot.rules();this.context=context;this.columns=Map.copyOf(columns);failure=null;estimatedBytes=bytes;
    }
    private static ExecutionMetadata unavailable(String reason){return new ExecutionMetadata(RetainedMetadataProof.unavailable(reason));}
    private static ExecutionMetadata limited(){return new ExecutionMetadata(RetainedMetadataProof.unavailable(MetadataState.LIMITED,"Pre-execution metadata evidence exceeds its 2048-column or 1MiB budget"));}
    public long estimatedBytes(){return estimatedBytes;}
    public int columnCount(){return columns.size();}
    public static ExecutionMetadata prepare(MetadataSnapshot snapshot,Profile target,String sessionId,String sql,LiveContext context){
        if(snapshot!=null&&!snapshot.identifierRulesAvailable())return new ExecutionMetadata(RetainedMetadataProof.unavailable(MetadataState.UNAVAILABLE,"Native identifier comparison evidence is unavailable"));
        var binding=RetainedMetadataProof.executionSource(snapshot,target,sessionId,sql,context);
        if(binding.failure()!=null)return new ExecutionMetadata(binding.failure());
        return collect(snapshot,binding.relation(),target,sessionId,context,null);
    }
    /** The fresh/recovery path shares the identical evidence extraction and
     * selected-column finalization, without imposing execution-source syntax. */
    static ExecutionMetadata selected(MetadataSnapshot snapshot,List<Column> resultColumns,Profile target,String sessionId,LiveContext context){
        if(snapshot==null||resultColumns.isEmpty()||resultColumns.size()>MAX_COLUMNS)return unavailable("UNAVAILABLE: cached execution metadata was not captured");
        if(!snapshot.identifierRulesAvailable())return new ExecutionMetadata(RetainedMetadataProof.unavailable(MetadataState.UNAVAILABLE,"Native identifier comparison evidence is unavailable"));
        var first=resultColumns.getFirst();
        if(!first.getProvenanceKnown()||first.getBaseColumn().isEmpty()||first.getTable().isEmpty())return unavailable("UNAVAILABLE: retained projection has no verified base identity");
        String catalog=first.getCatalog().isEmpty()&&target.getEngine()==Engine.POSTGRESQL?target.getDatabase():first.getCatalog();
        String schema=target.getEngine()==Engine.POSTGRESQL?first.getSchema():catalog;
        if(catalog.isEmpty()||schema.isEmpty())return unavailable("UNAVAILABLE: retained namespace is incomplete");
        var found=RetainedMetadataProof.sourceRelations(snapshot,catalog,schema,first.getTable(),true);
        if(found.size()!=1)return unavailable("UNAVAILABLE: exact cached relation identity was not captured before execution");
        return collect(snapshot,found.getFirst(),target,sessionId,context,resultColumns);
    }
    private static ExecutionMetadata collect(MetadataSnapshot snapshot,MetadataObject relation,Profile target,String sessionId,LiveContext context,List<Column> selected){
        return collect(snapshot,relation,target,sessionId,context,selected,new SnapshotColumns(snapshot,relation.identity()));
    }
    private static ExecutionMetadata collect(MetadataSnapshot snapshot,MetadataObject relation,Profile target,String sessionId,LiveContext context,List<Column> selected,ColumnSource columns){
        var id=relation.identity();
        if(!id.sessionOwner().isEmpty()&&!id.sessionOwner().equals(sessionId))return unavailable("INVALID_OWNER: cached relation belongs to another physical session");
        if(relation.state()!=MetadataState.AVAILABLE||!relation.level().includes(IntrospectionLevel.STRUCTURE))return new ExecutionMetadata(RetainedMetadataProof.unavailable(relation.state()==MetadataState.AVAILABLE?MetadataState.NOT_REQUESTED:relation.state(),"INCOMPLETE_METADATA: cached source relation structure is unavailable"));
        if(target.getEngine()!=Engine.POSTGRESQL&&(!id.sessionOwner().isEmpty()||"true".equals(relation.properties().get("temporary"))))return new ExecutionMetadata(RetainedMetadataProof.unavailable(MetadataState.UNSUPPORTED,"Temporary MySQL/MariaDB physical generation cannot be proven by durable InnoDB metadata"));
        if(!snapshot.relationResolutionAvailable(id.catalog(),id.schema(),id.name(),sessionId))return new ExecutionMetadata(RetainedMetadataProof.unavailable(MetadataState.UNKNOWN,"The owning physical session has not verified persistent relation resolution"));
        String generation=relation.properties().getOrDefault("nativeGeneration",""),state=relation.properties().getOrDefault("nativeGenerationAvailability","UNAVAILABLE");
        if(generation.isEmpty()||!state.equals("AVAILABLE"))return new ExecutionMetadata(RetainedMetadataProof.unavailable(switch(state){case "DENIED"->MetadataState.DENIED;case "LIMITED"->MetadataState.LIMITED;case "UNSUPPORTED_IDENTIFIER_MAPPING"->MetadataState.UNSUPPORTED;default->MetadataState.UNAVAILABLE;},"Physical relation generation is not available in cached metadata"));
        if(!columns.complete())return new ExecutionMetadata(RetainedMetadataProof.unavailable(columns.state(),"INCOMPLETE_METADATA: structural columns were not captured before execution"));
        var fields=new LinkedHashMap<String,ColumnEvidence>();long bytes=512L+snapshot.rules().estimatedBytes()+2L*(snapshot.source().length()+id.catalog().length()+id.schema().length()+id.name().length()+id.key().length()+generation.length()+target.getDatabase().length());
        if(context!=null){bytes+=256L+2L*(context.catalog().length()+context.schema().length()+context.sqlMode().length()+context.temporarySchema().length()+context.dateStyle().length()+context.timeZone().length()+context.systemTimeZone().length());for(String path:context.searchPath())bytes+=32L+2L*path.length();}
        if(bytes>MAX_BYTES)return limited();
        if(selected==null){
            var actual=columns.all();if(actual.size()>MAX_COLUMNS)return limited();
            for(var field:actual){String key=snapshot.rules().lookup(ObjectKind.COLUMN,field.identity().name(),true);var evidence=evidence(snapshot,field,target.getEngine(),generation);
                if(fields.containsKey(key))evidence=missing();long next=bytes+64L+2L*key.length()+evidence.estimatedBytes();if(next>MAX_BYTES)return limited();bytes=next;fields.put(key,evidence);}
        }else for(var column:selected){
            String key=snapshot.rules().lookup(ObjectKind.COLUMN,column.getBaseColumn(),true);if(fields.containsKey(key))continue;
            var found=columns.named(column.getBaseColumn());var evidence=found.size()==1?evidence(snapshot,found.getFirst(),target.getEngine(),generation):missing();
            long next=bytes+64L+2L*key.length()+evidence.estimatedBytes();if(next>MAX_BYTES||fields.size()>=MAX_COLUMNS)return limited();bytes=next;fields.put(key,evidence);
        }
        return new ExecutionMetadata(snapshot,relation,target,context,fields,bytes);
    }
    private static ColumnEvidence missing(){return new ColumnEvidence(null,false,"",RetainedMetadataProof.unavailable("UNAVAILABLE: exact cached base column was not captured before execution"));}
    private static ColumnEvidence evidence(MetadataSnapshot snapshot,MetadataObject base,Engine engine,String generation){
        if(base.state()!=MetadataState.AVAILABLE||!base.level().includes(IntrospectionLevel.STRUCTURE))return new ColumnEvidence(null,false,"",RetainedMetadataProof.unavailable(base.state()==MetadataState.AVAILABLE?MetadataState.NOT_REQUESTED:base.state(),"INCOMPLETE_METADATA: cached column structure is unavailable"));
        String identity=engine==Engine.POSTGRESQL?base.identity().key():"";
        if(engine==Engine.MYSQL){var nativeIdentity=NativeRelationReader.identityProperties(generation);String ordinal=base.properties().getOrDefault("ordinal","");if(!nativeIdentity.isEmpty()&&ordinal.matches("[1-9][0-9]{0,3}"))identity=MetadataIdentity.digest(snapshot.source(),"mysql-column",nativeIdentity.get("nativeTableId"),nativeIdentity.get("nativeColumnEpoch"),ordinal);}
        var proof=new RetainedMetadataProof.ColumnProof(identity,base.properties().getOrDefault("nativeTypeId",""),base.properties().getOrDefault("jdbcNativeType",base.properties().getOrDefault("type","")),RetainedMetadataProof.columnFingerprint(base));
        String element=base.properties().getOrDefault("arrayElementType","");if(base.properties().getOrDefault("arrayElementKind","").equals("d"))element=base.properties().getOrDefault("arrayElementBaseName","");
        return new ColumnEvidence(proof,base.properties().getOrDefault("jdbcType","").equals(Integer.toString(java.sql.Types.ARRAY)),element,null);
    }
    public RetainedMetadataProof proof(List<Column> resultColumns){
        if(failure!=null)return failure;
        if(resultColumns.isEmpty()||resultColumns.size()>MAX_COLUMNS)return RetainedMetadataProof.unavailable("UNAVAILABLE: cached execution metadata was not captured");
        var result=new LinkedHashMap<Integer,RetainedMetadataProof.ColumnProof>();boolean arrays=false;
        for(var column:resultColumns){
            if(column.getOrdinal()<1||column.getOrdinal()>MAX_COLUMNS||result.containsKey(column.getOrdinal()))return RetainedMetadataProof.unavailable("UNAVAILABLE: retained column ordinal is invalid or duplicated");
            if(!column.getProvenanceKnown()||column.getBaseColumn().isEmpty()||column.getTable().isEmpty())return RetainedMetadataProof.unavailable("UNAVAILABLE: retained projection has no verified base identity");
            String actualCatalog=column.getCatalog().isEmpty()&&engine==Engine.POSTGRESQL?fallbackCatalog:column.getCatalog(),actualSchema=engine==Engine.POSTGRESQL?column.getSchema():actualCatalog;
            if(actualCatalog.isEmpty()||actualSchema.isEmpty())return RetainedMetadataProof.unavailable("UNAVAILABLE: retained namespace is incomplete");
            if(!rules.lookup(ObjectKind.CATALOG,catalog,true).equals(rules.lookup(ObjectKind.CATALOG,actualCatalog,true))||!rules.lookup(ObjectKind.SCHEMA,schema,true).equals(rules.lookup(ObjectKind.SCHEMA,actualSchema,true))||!rules.lookup(ObjectKind.TABLE,table,true).equals(rules.lookup(ObjectKind.TABLE,column.getTable(),true)))return RetainedMetadataProof.unavailable("UNAVAILABLE: retained projection contains another physical relation");
            var evidence=columns.get(rules.lookup(ObjectKind.COLUMN,column.getBaseColumn(),true));if(evidence==null)return missing().failure();if(evidence.failure()!=null)return evidence.failure();
            if(engine==Engine.POSTGRESQL&&(column.getJdbcType()==java.sql.Types.ARRAY||evidence.array())){
                if(evidence.element().isEmpty())return RetainedMetadataProof.unavailable(MetadataState.UNSUPPORTED,"Retained array input context has no verified element identity");
                try{io.busystack.busydata.results.ArrayParameters.requireContext(ARRAY_TEXT_CONTEXT,context,evidence.element());}catch(java.sql.SQLException unsupported){return RetainedMetadataProof.unavailable(MetadataState.UNSUPPORTED,"Retained array text cannot be rebound safely in the captured input context");}arrays=true;
            }
            result.put(column.getOrdinal(),evidence.proof());
        }
        String temporal=arrays?"postgresql-array-text-context-v1":"";
        if(engine!=Engine.POSTGRESQL&&result.values().stream().anyMatch(column->column.jdbcNativeType().equalsIgnoreCase("TIMESTAMP")||column.jdbcNativeType().toUpperCase(Locale.ROOT).startsWith("TIMESTAMP("))){temporal=TimestampContext.key(context);if(temporal.isEmpty())return RetainedMetadataProof.unavailable(MetadataState.UNSUPPORTED,"UNSUPPORTED: retained TIMESTAMP interpretation has no proven fixed session offset");}
        var proof=new RetainedMetadataProof(source,snapshotRevision,configurationRevision,catalog,schema,table,identity,generation,result,MetadataState.AVAILABLE,"AVAILABLE",temporal);
        return proof.estimatedBytes()>MAX_BYTES?RetainedMetadataProof.unavailable(MetadataState.LIMITED,"Retained metadata identity proof exceeds 1MiB"):proof;
    }
}
