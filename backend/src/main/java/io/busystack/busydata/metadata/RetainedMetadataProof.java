package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.*;
import java.util.*;
import java.util.concurrent.*;

/** Compact immutable evidence captured before SQL; retaining a result never pins a catalog. */
public record RetainedMetadataProof(String sourceKey,long snapshotRevision,long configurationRevision,
        String catalog,String schema,String table,String tableIdentity,String nativeGeneration,
        Map<Integer,ColumnProof> columns,MetadataState state,String availability,String temporalContext) {
    public RetainedMetadataProof(String sourceKey,long snapshotRevision,long configurationRevision,String catalog,String schema,String table,String tableIdentity,String nativeGeneration,Map<Integer,ColumnProof> columns,MetadataState state,String availability){this(sourceKey,snapshotRevision,configurationRevision,catalog,schema,table,tableIdentity,nativeGeneration,columns,state,availability,"");}
    public record ColumnProof(String identity,String nativeTypeId,String jdbcNativeType,String fingerprint){}
    public RetainedMetadataProof{columns=Map.copyOf(columns);Objects.requireNonNull(state);Objects.requireNonNull(temporalContext);}
    public boolean available(){return state==MetadataState.AVAILABLE;}
    public boolean capturedStructure(){return (state==MetadataState.AVAILABLE||state==MetadataState.STALE)&&!tableIdentity.isEmpty()&&!nativeGeneration.isEmpty()&&!columns.isEmpty();}
    public static RetainedMetadataProof unavailable(String reason){return new RetainedMetadataProof("",0,0,"","","","","",Map.of(),MetadataState.UNAVAILABLE,reason);}
    public static RetainedMetadataProof unavailable(MetadataState state,String reason){if(state==MetadataState.AVAILABLE)throw new IllegalArgumentException("Unavailable retained proof cannot be AVAILABLE");return new RetainedMetadataProof("",0,0,"","","","","",Map.of(),state,reason);}
    public RetainedMetadataProof invalidate(String reason){return new RetainedMetadataProof(sourceKey,snapshotRevision,configurationRevision,catalog,schema,table,tableIdentity,nativeGeneration,columns,capturedStructure()?MetadataState.STALE:state,reason,temporalContext);}
    /** External native commits cannot be undone by the console transaction.
     * Preserve provenance while permanently retiring recoverable edit evidence. */
    public RetainedMetadataProof invalidateExternal(String reason){return new RetainedMetadataProof(sourceKey,snapshotRevision,configurationRevision,catalog,schema,table,"","",Map.of(),MetadataState.STALE,reason,temporalContext);}
    /** A stale but originally proven source may be revalidated after rollback. */
    public boolean samePhysicalStructure(RetainedMetadataProof other){return capturedStructure()&&other.available()&&sourceKey.equals(other.sourceKey)&&tableIdentity.equals(other.tableIdentity)&&nativeGeneration.equals(other.nativeGeneration)&&columns.equals(other.columns)&&temporalContext.equals(other.temporalContext);}
    public long estimatedBytes(){return 384L+2L*temporalContext.length()+columns.values().stream().mapToLong(c->96L+2L*(c.identity().length()+c.nativeTypeId().length()+c.jdbcNativeType().length()+c.fingerprint().length())).sum();}
    private static final List<String> COLUMN_PROPERTIES=List.of("type","jdbcType","jdbcNativeType","nativeId","parentNativeId","nativeTypeId","nativeTypeKind","nativeTypeAvailability","generationExpressionAvailability","precision","scale","nullable","default","defaultAvailability","ordinal","generated","autoIncrement","generatedKind","identityKind","generationExpression","collation","unsigned","dimensions","domainBaseType","arrayElementSchema","arrayElementType","arrayElementTypeId","arrayElementDelimiter","arrayElementKind","arrayElementCategory","arrayElementBaseType","arrayElementBaseSchema","arrayElementBaseName");
    public static String columnFingerprint(SchemaObject column) {
        var properties=new TreeMap<String,String>();
        for(String name:COLUMN_PROPERTIES)properties.put(name,column.getPropertiesOrDefault(name,""));
        return MetadataFingerprint.objects(List.of(column.toBuilder().clearProperties().clearDefinition().putAllProperties(properties).build()));
    }
    /** Decode only proof-relevant fields, not a full enum/source projection. */
    public static String columnFingerprint(MetadataObject column){
        var id=column.identity();var selected=SchemaObject.newBuilder().setKind(id.kind()).setSubtype(id.subtype()).setCatalog(id.catalog()).setSchema(id.schema()).setTable(id.parent()).setName(column.displayName()).setIdentifier(id.signature());
        for(String name:COLUMN_PROPERTIES)selected.putProperties(name,column.properties().getOrDefault(name,""));
        return MetadataFingerprint.objects(List.of(selected.build()));
    }
    public static RetainedMetadataProof capture(MetadataSnapshot snapshot,List<Column> resultColumns,Profile target,String sessionId) {return capture(snapshot,resultColumns,target,sessionId,null);}
    public static RetainedMetadataProof capture(MetadataSnapshot snapshot,List<Column> resultColumns,Profile target,String sessionId,io.busystack.busydata.adapters.JdbcAdapter.LiveContext context) {
        return ExecutionMetadata.selected(snapshot,resultColumns,target,sessionId,context).proof(resultColumns);
    }
    public static RetainedMetadataProof captureExecution(MetadataSnapshot snapshot,List<Column> columns,Profile profile,String sessionId,String sql,io.busystack.busydata.adapters.JdbcAdapter.LiveContext context) {
        return ExecutionMetadata.prepare(snapshot,profile,sessionId,sql,context).proof(columns);
    }
    /** A short-lived pure binding result. It is consumed during preparation and
     * must never become a JDBC job field or retained result owner. */
    record ExecutionSource(MetadataObject relation,RetainedMetadataProof failure){}
    private static ExecutionSource sourceUnavailable(String reason){return new ExecutionSource(null,unavailable(reason));}
    private static ExecutionSource sourceUnsupported(String reason){return new ExecutionSource(null,unavailable(MetadataState.UNSUPPORTED,reason));}
    private static ExecutionSource sourceFailure(Exception failure){
        MetadataState state=MetadataState.UNAVAILABLE;
        Throwable cause=failure;
        for(int depth=0;cause!=null&&depth<16;depth++,cause=cause.getCause()){
            if(cause instanceof InterruptedException)Thread.currentThread().interrupt();
            if(state==MetadataState.UNAVAILABLE){
                if(cause instanceof TimeoutException)state=MetadataState.TIMED_OUT;
                else if(cause instanceof RejectedExecutionException)state=MetadataState.LIMITED;
                else if(cause instanceof CancellationException||cause instanceof InterruptedException)state=MetadataState.CANCELLED;
            }
        }
        String reason=switch(state){
            case TIMED_OUT->"TIMED_OUT: source binding parser deadline was reached";
            case LIMITED->"LIMITED: source binding parser admission budget was reached";
            case CANCELLED->"CANCELLED: source binding parser was cancelled";
            default->"UNAVAILABLE: source selection could not be bound safely";
        };
        return new ExecutionSource(null,unavailable(state,reason));
    }
    static ExecutionSource executionSource(MetadataSnapshot snapshot,Profile profile,String sessionId,String sql,io.busystack.busydata.adapters.JdbcAdapter.LiveContext context){
        if(snapshot==null)return sourceUnavailable("UNAVAILABLE: cached execution metadata was not captured");
        if(context==null)return sourceUnavailable("UNAVAILABLE: execution resolution context was not captured");
        try{
            var parsed=io.busystack.busydata.analysis.SqlParsing.parse(sql,profile.getEngine(),context.lexical());
            if(!(parsed instanceof net.sf.jsqlparser.statement.select.PlainSelect body))return sourceUnsupported("UNSUPPORTED: source is not a direct table selection");
            if(!(body.getFromItem() instanceof net.sf.jsqlparser.schema.Table from)||body.getDistinct()!=null||body.getGroupBy()!=null||body.getHaving()!=null||body.getJoins()!=null&&!body.getJoins().isEmpty()||body.getWithItemsList()!=null&&!body.getWithItemsList().isEmpty())return sourceUnsupported("UNSUPPORTED: source is not a direct table selection");
            var name=identifier(from.getName());String schema=from.getSchemaName();String catalog=from.getDatabase()==null?"":Objects.toString(from.getDatabase().getDatabaseName(),"");
            String requestedCatalog=catalog.isEmpty()?context.catalog():identifier(catalog).name();
            if(profile.getEngine()==Engine.POSTGRESQL&&!catalog.isEmpty()){var requested=identifier(catalog);requestedCatalog=snapshot.rules().lookup(ObjectKind.CATALOG,requested.name(),requested.quoted());}
            if(profile.getEngine()!=Engine.POSTGRESQL){
                String database=schema==null||schema.isEmpty()?requestedCatalog:identifier(schema).name();
                var relations=sourceRelations(snapshot,database,database,name.name(),name.quoted());
                return relations.size()==1?new ExecutionSource(relations.getFirst(),null):sourceUnavailable("UNAVAILABLE: exact SQL source table identity is unavailable");
            }
            if(schema!=null&&!schema.isEmpty()){
                var namespace=identifier(schema);String folded=snapshot.rules().lookup(ObjectKind.SCHEMA,namespace.name(),namespace.quoted());
                String exact=folded.equals("pg_temp")?context.temporarySchema():folded;
                var relations=snapshot.resolve(requestedCatalog,exact,ObjectKind.TABLE,"",name.name(),name.quoted());
                return relations.size()==1?new ExecutionSource(relations.getFirst(),null):sourceUnavailable("UNAVAILABLE: exact SQL source table identity is unavailable");
            }
            var path=MetadataSearchPath.postgres(context.searchPath(),context.temporarySchema(),true);
            for(String namespace:new LinkedHashSet<>(path)){
                var tables=snapshot.resolve(requestedCatalog,namespace,ObjectKind.TABLE,"",name.name(),name.quoted());
                var views=snapshot.resolve(requestedCatalog,namespace,ObjectKind.VIEW,"",name.name(),name.quoted());
                if(!views.isEmpty())return sourceUnsupported("UNSUPPORTED: SQL source resolves to a view; view writes require a separate safety model");
                if(!tables.isEmpty())return tables.size()==1?new ExecutionSource(tables.getFirst(),null):sourceUnavailable("UNAVAILABLE: SQL source table is ambiguous");
                if(!nameAbsent(snapshot,requestedCatalog,namespace,ObjectKind.TABLE,name.name())||!nameAbsent(snapshot,requestedCatalog,namespace,ObjectKind.VIEW,name.name()))return new ExecutionSource(null,unavailable(MetadataState.PARTIAL,"INCOMPLETE_METADATA: earlier SQL source namespace was not captured"));
            }
            return sourceUnavailable("UNAVAILABLE: SQL source table could not be bound in captured context");
        }catch(Exception unsupported){return sourceFailure(unsupported);}
    }
    private record Identifier(String name,boolean quoted){}
    /** Namespace indexes use canonical exact names. Only the captured MySQL
     * database case policy permits a bounded lazy canonical-name lookup. */
    static List<MetadataObject> sourceRelations(MetadataSnapshot snapshot,String catalog,String schema,String name,boolean quoted){
        var direct=snapshot.resolve(catalog,schema,ObjectKind.TABLE,"",name,quoted);var rules=snapshot.rules();
        if(!direct.isEmpty()||rules.engine()==Engine.POSTGRESQL||rules.lowerCaseTableNames()==0)return direct;
        String catalogKey=rules.lookup(ObjectKind.CATALOG,catalog,true),schemaKey=rules.lookup(ObjectKind.SCHEMA,schema,true);var matches=new ArrayList<MetadataObject>(2);
        for(var relation:snapshot.resolveName(ObjectKind.TABLE,name,quoted)){var identity=relation.identity();
            if(rules.lookup(ObjectKind.CATALOG,identity.catalog(),true).equals(catalogKey)&&rules.lookup(ObjectKind.SCHEMA,identity.schema(),true).equals(schemaKey)){matches.add(relation);if(matches.size()==2)break;}
        }
        return List.copyOf(matches);
    }
    /** Cached direct-table binding used before owned physical classification and the native observer. */
    public static Optional<MetadataObject> sourceTable(MetadataSnapshot snapshot,Profile profile,String session,String sql,io.busystack.busydata.adapters.JdbcAdapter.LiveContext context){
        return sourceRelation(snapshot,profile,session,sql,context).filter(object->object.identity().sessionOwner().isEmpty()&&!"true".equals(object.properties().get("temporary"))&&snapshot.relationResolutionAvailable(object.identity().catalog(),object.identity().schema(),object.identity().name(),session));
    }
    /** A bounded syntactic name, NOT a verified metadata identity. Its sole
     * consumer may quote it for native pre-stream physical classification. */
    public record ParsedReference(String database,String name,boolean quoted){}
    public static Optional<ParsedReference> parsedReference(Profile profile,String sql,io.busystack.busydata.adapters.JdbcAdapter.LiveContext context){
        if(context==null||profile.getEngine()==Engine.POSTGRESQL)return Optional.empty();
        try{
            var parsed=io.busystack.busydata.analysis.SqlParsing.parse(sql,profile.getEngine(),context.lexical());
            if(!(parsed instanceof net.sf.jsqlparser.statement.select.PlainSelect body)||!(body.getFromItem() instanceof net.sf.jsqlparser.schema.Table table)||body.getDistinct()!=null||body.getGroupBy()!=null||body.getHaving()!=null||body.getJoins()!=null&&!body.getJoins().isEmpty()||body.getWithItemsList()!=null&&!body.getWithItemsList().isEmpty())return Optional.empty();
            // Supported MySQL/MariaDB sources have at most database.table.
            // Never silently discard a parsed third namespace component.
            if(table.getDatabase()!=null&&!Objects.toString(table.getDatabase().getDatabaseName(),"").isEmpty())return Optional.empty();
            var database=table.getSchemaName()==null||table.getSchemaName().isEmpty()?new Identifier(context.catalog(),true):identifier(table.getSchemaName());var name=identifier(table.getName());
            for(String value:List.of(database.name(),name.name()))if(value.isEmpty()||value.length()>256||value.indexOf(0)>=0)return Optional.empty();
            return Optional.of(new ParsedReference(database.name(),name.name(),name.quoted()));
        }catch(Exception unsupported){return Optional.empty();}
    }
    /** Exact cached identity for pre-execution physical classification, including owned temporary names. */
    public static Optional<MetadataObject> sourceRelation(MetadataSnapshot snapshot,Profile profile,String session,String sql,io.busystack.busydata.adapters.JdbcAdapter.LiveContext context){
        if(snapshot==null||context==null||profile.getEngine()==Engine.POSTGRESQL)return Optional.empty();
        try{var candidate=parsedReference(profile,sql,context);if(candidate.isEmpty())return Optional.empty();var reference=candidate.get();var found=sourceRelations(snapshot,reference.database(),reference.database(),reference.name(),reference.quoted());if(found.size()!=1)return Optional.empty();var object=found.getFirst();if(!object.identity().sessionOwner().isEmpty()&&!object.identity().sessionOwner().equals(session)||object.state()!=MetadataState.AVAILABLE||!object.level().includes(IntrospectionLevel.STRUCTURE))return Optional.empty();return Optional.of(object);
        }catch(Exception unsupported){return Optional.empty();}
    }
    private static Identifier identifier(String text){if(text!=null&&text.length()>=2&&(text.charAt(0)=='\"'||text.charAt(0)=='`')&&text.charAt(text.length()-1)==text.charAt(0)){String mark=text.substring(0,1);return new Identifier(text.substring(1,text.length()-1).replace(mark+mark,mark),true);}return new Identifier(Objects.toString(text,""),false);}
    private static boolean nameAbsent(MetadataSnapshot snapshot,String catalog,String schema,ObjectKind kind,String name){for(var coverage:snapshot.coverage().values())if(coverage.scope().catalog().equals(catalog)&&coverage.scope().schema().equals(schema)&&coverage.scope().kind()==kind&&coverage.scope().parent().isEmpty()&&(coverage.scope().broad()||coverage.scope().exactName()&&coverage.scope().search().equals(name))&&coverage.complete()&&coverage.level().includes(IntrospectionLevel.NAMES))return true;return false;}
}
