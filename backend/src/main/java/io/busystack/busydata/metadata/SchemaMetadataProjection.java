package io.busystack.busydata.metadata;

import com.google.gson.*;
import io.busystack.busydata.adapters.JdbcAdapter;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.rpc.WorkbenchFailure;
import io.busystack.busydata.schema.*;
import io.busystack.busydata.sessions.SessionRegistry;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.concurrent.*;

/** Schema comparison/design artifacts are projections of centrally acquired structure/source. */
public final class SchemaMetadataProjection {
    private SchemaMetadataProjection(){}
    /** The borrowed metadata view remains open for the complete inspection,
     * including native validation performed after the single artifact capture. */
    @FunctionalInterface public interface InspectionAction<T> {
        T run(SessionRegistry.Session view,Capture capture)throws Exception;
    }
    /** A single-use acquisition capability cannot escape its callback lifetime,
     * change its original owner, or reserve again after a stale response. */
    public static final class Capture {
        private final MetadataPlatform platform;
        private final MetadataPlatform.RefreshReservation reservation;
        private final JdbcAdapter.LiveContext context;
        private final long deadline;
        private final boolean sessionOwned;
        private MetadataReadScope reads;
        private SessionRegistry.Session owner,view;
        private Thread thread=Thread.currentThread();
        private boolean used;
        private Capture(MetadataPlatform platform,SessionRegistry.Session owner,SessionRegistry.Session view,MetadataPlatform.RefreshReservation reservation,JdbcAdapter.LiveContext context,long deadline,boolean sessionOwned,MetadataReadScope reads) {
            this.platform=platform;this.owner=owner;this.view=view;this.reservation=reservation;this.context=context;this.deadline=deadline;this.sessionOwned=sessionOwned;this.reads=reads;
        }
        private void check()throws Exception {
            if(owner==null||thread!=Thread.currentThread())throw new WorkbenchFailure(WorkbenchFailure.Reason.INVALID_OWNER);
            checkDeadline(deadline);if(reads!=null)reads.check();
            platform.checkSchemaCaptureOwner(owner,reservation);
            if(!context.equals(owner.context))throw new WorkbenchFailure(WorkbenchFailure.Reason.STALE);
        }
        public JsonObject capture(String requested,String tableFilter)throws Exception {
            check();if(used)throw new WorkbenchFailure(WorkbenchFailure.Reason.INVALID_OWNER);used=true;
            try{return captureOnce(this,Objects.requireNonNull(requested),tableFilter);}
            catch(Exception failure){check();throw failure;}
        }
        private void retire(){owner=null;view=null;thread=null;reads=null;}
    }
    static <T>T inspect(MetadataPlatform platform,SessionRegistry.Session owner,String catalog,InspectionAction<T> action)throws Exception {
        return inspect(platform,owner,catalog,action,System.nanoTime()+TimeUnit.SECONDS.toNanos(30));
    }
    private static <T>T inspect(MetadataPlatform platform,SessionRegistry.Session owner,String catalog,InspectionAction<T> action,long deadline)throws Exception {
        if(owner.lock.isHeldByCurrentThread())throw new WorkbenchFailure(WorkbenchFailure.Reason.UNAVAILABLE);
        Objects.requireNonNull(action);
        checkDeadline(deadline);var context=owner.context;var reservation=platform.reserveRefresh(owner);
        checkOwner(platform,owner,reservation,context,deadline);
        return owner.metadata(catalog,view->{
            checkOwner(platform,owner,reservation,context,deadline);
            if(view==owner||!view.isIndependentMetadataView()||!view.context.catalog().equals(catalog)||!view.profile.getId().equals(owner.profile.getId())||view.profile.getEngine()!=owner.profile.getEngine()||view.contextRevision!=reservation.contextRevision())throw new WorkbenchFailure(WorkbenchFailure.Reason.INVALID_OWNER);
            try(var reads=new MetadataReadScope(view.connection,deadline)) {
                var capture=new Capture(platform,owner,view,reservation,context,deadline,false,reads);
                try{capture.check();T result=action.run(view,capture);capture.check();return result;}
                catch(Exception failure){capture.check();throw failure;}
                finally{capture.retire();}
            }
        });
    }
    static JsonObject capture(MetadataPlatform platform,SessionRegistry.Session owner,String requested,String tableFilter)throws Exception {
        long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(30);checkDeadline(deadline);
        // Catalog SELECTs could start a transaction on a manual idle session.
        // Refuse before any JDBC or lease change instead of creating that state.
        if(!owner.autoCommit&&owner.state==TransactionState.IDLE)throw new WorkbenchFailure(WorkbenchFailure.Reason.UNAVAILABLE);
        if(owner.autoCommit&&owner.state==TransactionState.IDLE)return inspect(platform,owner,owner.context.catalog(),(view,capture)->capture.capture(requested,tableFilter),deadline);
        boolean acquired=false;
        if(!owner.lock.isHeldByCurrentThread()) {
            if(!owner.lock.tryLock())throw new WorkbenchFailure(WorkbenchFailure.Reason.SESSION_BUSY);acquired=true;
        }
        try {
            if(owner.autoCommit&&owner.state==TransactionState.IDLE)throw new WorkbenchFailure(WorkbenchFailure.Reason.STALE);
            if(owner.state!=TransactionState.ACTIVE)throw new WorkbenchFailure(WorkbenchFailure.Reason.UNAVAILABLE);
            checkDeadline(deadline);
            var context=owner.context;var reservation=platform.reserveRefresh(owner);
            var capture=new Capture(platform,owner,owner,reservation,context,deadline,true,null);
            try{return capture.capture(requested,tableFilter);}finally{capture.retire();}
        }finally{if(acquired)owner.lock.unlock();}
    }
    private static void checkDeadline(long deadline)throws TimeoutException {
        if(io.grpc.Context.current().isCancelled()||Thread.currentThread().isInterrupted())throw new CancellationException("Schema metadata acquisition cancelled");
        if(System.nanoTime()>=deadline)throw new TimeoutException("Schema metadata acquisition deadline exceeded");
    }
    private static void checkOwner(MetadataPlatform platform,SessionRegistry.Session owner,MetadataPlatform.RefreshReservation reservation,JdbcAdapter.LiveContext context,long deadline)throws Exception {
        checkDeadline(deadline);platform.checkSchemaCaptureOwner(owner,reservation);
        if(!context.equals(owner.context))throw new WorkbenchFailure(WorkbenchFailure.Reason.STALE);
    }
    private static JsonObject captureOnce(Capture capture,String requested,String tableFilter)throws Exception {
        capture.check();var platform=capture.platform;var owner=capture.owner;var view=capture.view;long deadline=capture.deadline;
        String schema=requested.isBlank()?view.context.schema():requested,catalog=view.context.catalog();
        var previous=platform.capture(owner).rules();var rules=view.isIndependentMetadataView()?NativeStructureReader.rules(view,previous,deadline):previous;
        var artifact=SchemaSnapshotReader.read(view,schema,tableFilter);var adapter=new Explorer(platform);var branches=new LinkedHashMap<MetadataScope,MetadataPlatform.Branch>();
        for(var entry:artifact.getAsJsonObject("tables").entrySet()) {
            capture.check();
            String table=entry.getKey();var nativeTable=entry.getValue().getAsJsonObject();var structure=NativeStructureReader.inspect(view,catalog,schema,table,false);
            var relation=SchemaObject.newBuilder().setCatalog(catalog).setSchema(schema).setName(table).setKind(ObjectKind.TABLE).setSubtype(subtype(nativeTable))
                .putProperties("editabilitySignature",structure.signature()).putProperties("baseTableVerified","true").putProperties("nativeGeneration",structure.nativeGeneration()).putProperties("nativeGenerationAvailability",structure.nativeGenerationAvailability()).putProperties("nativeId",structure.columns().isEmpty()?"":structure.columns().getFirst().getPropertiesOrDefault("parentNativeId",""));
            if(nativeTable.has("properties"))for(var property:nativeTable.getAsJsonObject("properties").entrySet())if(property.getValue().isJsonPrimitive())relation.putProperties(property.getKey(),property.getValue().getAsString());
            var relationSource=withSource(relation.build(),text(nativeTable,"create"),"native schema structure; generated PostgreSQL source remains partial");
            if(owner.profile.getEngine()==Engine.POSTGRESQL&&!relationSource.getDefinition().isEmpty())relationSource=relationSource.toBuilder().putProperties("sourceAvailability","PARTIAL").build();
            put(branches,new MetadataScope(catalog,schema,"",ObjectKind.TABLE,table,true,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED),List.of(relationSource),capture.reservation);
            put(branches,new MetadataScope(catalog,schema,table,ObjectKind.COLUMN),structure.columns().stream().map(column->{var fields=nativeTable.getAsJsonObject("columns").getAsJsonObject(column.getName());return withSource(column,fields==null?"":text(fields,"definition"),"native column definition");}).toList(),capture.reservation);
            put(branches,new MetadataScope(catalog,schema,table,ObjectKind.FOREIGN_KEY),structure.relationships(),capture.reservation);
            for(ObjectKind kind:List.of(ObjectKind.CONSTRAINT,ObjectKind.INDEX,ObjectKind.TRIGGER)) {
                capture.check();
                var scope=new MetadataScope(catalog,schema,table,kind);var request=ExploreRequest.newBuilder().setCatalog(catalog).setSchema(schema).setTable(table).setKind(kind).setIntrospectionLevel(2).setLimit(500).build();
                String property=switch(kind){case CONSTRAINT->"constraints";case INDEX->"indexes";default->"triggers";};var definitions=nativeTable.getAsJsonObject(property);
                var values=adapter.fetchBranch(view,request,deadline).stream().map(object->withSource(object,kind==ObjectKind.CONSTRAINT?SchemaConstraints.definition(nativeTable,object.getName(),object.getPropertiesOrDefault("type",object.getIdentifier())):definitions!=null&&definitions.has(object.getName())&&!definitions.get(object.getName()).isJsonNull()?definitions.get(object.getName()).getAsString():"","native "+property+" definition")).toList();
                put(branches,scope,values,capture.reservation);
            }
        }
        if(tableFilter==null) {
            var scope=new MetadataScope(catalog,schema,"",ObjectKind.TABLE);var relations=branches.values().stream().flatMap(b->b.objects().stream()).filter(o->o.getKind()==ObjectKind.TABLE).toList();put(branches,scope,relations,capture.reservation);
            for(ObjectKind kind:List.of(ObjectKind.VIEW,ObjectKind.ROUTINE)) {
                capture.check();
                var request=ExploreRequest.newBuilder().setCatalog(catalog).setSchema(schema).setKind(kind).setIntrospectionLevel(2).setLimit(500).build();var values=adapter.fetchBranch(view,request,deadline);var enriched=new ArrayList<SchemaObject>();
                for(var object:values) {
                    capture.check();
                    String source="";
                    if(kind==ObjectKind.VIEW&&artifact.getAsJsonObject("views").has(object.getName()))source=text(artifact.getAsJsonObject("views"),object.getName());
                    if(kind==ObjectKind.ROUTINE&&artifact.getAsJsonObject("routines").has(object.getIdentifier()))source=text(artifact.getAsJsonObject("routines").getAsJsonObject(object.getIdentifier()),"definition");
                    var value=withSource(object,source,kind==ObjectKind.VIEW?"native view SELECT definition; security/owner properties retained in schema artifact":"native routine definition");
                    if(kind==ObjectKind.VIEW&&!source.isEmpty())value=value.toBuilder().putProperties("sourceAvailability","PARTIAL").build();enriched.add(value);
                    if(kind==ObjectKind.VIEW) {
                        var columns=adapter.fetchBranch(view,request.toBuilder().setKind(ObjectKind.COLUMN).setTable(object.getName()).build(),deadline);
                        put(branches,new MetadataScope(catalog,schema,object.getName(),ObjectKind.COLUMN),columns,capture.reservation);
                    }
                }
                put(branches,new MetadataScope(catalog,schema,"",kind),enriched,capture.reservation);
            }
        }
        capture.check();
        platform.publishSchemaCapture(owner,capture.reservation,rules,branches,capture.sessionOwned,deadline);
        capture.check();return artifact;
    }
    private static ObjectSubtype subtype(JsonObject table) {
        if(!table.has("properties"))return ObjectSubtype.ORDINARY_TABLE;
        return switch(text(table.getAsJsonObject("properties"),"kind")){case "p"->ObjectSubtype.PARTITIONED_TABLE;case "f"->ObjectSubtype.FOREIGN_TABLE;default->ObjectSubtype.ORDINARY_TABLE;};
    }
    private static String text(JsonObject object,String property){return object.has(property)&&!object.get(property).isJsonNull()?object.get(property).getAsString():"";}
    private static SchemaObject withSource(SchemaObject object,String source,String provenance) {
        boolean limited=source.getBytes(StandardCharsets.UTF_8).length>65536;
        return object.toBuilder().setDefinition(limited?"":source).putProperties("sourceAvailability",limited?"LIMITED":source.isEmpty()?"NOT_EXPOSED":"AVAILABLE")
            .putProperties("sourceProvenance",provenance).build();
    }
    private static void put(Map<MetadataScope,MetadataPlatform.Branch> branches,MetadataScope scope,List<SchemaObject> objects,MetadataPlatform.RefreshReservation reservation) {
        branches.put(scope,new MetadataPlatform.Branch(objects,new MetadataCoverage(scope,IntrospectionLevel.SOURCE,MetadataState.AVAILABLE,true,MetadataIdentity.digest(objects.toString()),reservation.revision(),reservation.contextRevision(),System.currentTimeMillis(),"")));
    }
}
