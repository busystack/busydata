package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.Explorer;
import io.busystack.busydata.sessions.SessionRegistry;
import java.sql.*;
import java.util.*;
import java.util.concurrent.TimeUnit;

/** Physical-session temporary objects are never inspected through another connection. */
public final class SessionMetadataOverlay {
    private SessionMetadataOverlay(){}
    public static MetadataSnapshot refresh(Explorer explorer,SessionRegistry.Session session)throws Exception {
        if(!session.lock.isHeldByCurrentThread())throw new IllegalStateException("Temporary introspection requires physical-session ownership");
        if(session.profile.getEngine()==Engine.MARIADB)return refreshMariaInventory(explorer,session);
        if(session.profile.getEngine()!=Engine.POSTGRESQL)return explorer.metadata().capture(session);
        var rules=explorer.metadata().capture(session).rules();
        long epoch=explorer.metadata().sessionResolutionEpoch(session),ticket=explorer.metadata().beginRefresh(session);
        String schema=session.context.temporarySchema();if(schema.isEmpty()){explorer.metadata().clearTemporaryOverlay(session);explorer.metadata().reconcileSessionResolution(session,epoch);return explorer.metadata().capture(session);}
        String catalog=session.context.catalog();var branches=new LinkedHashMap<MetadataScope,MetadataPlatform.Branch>();long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(10);
        for(ObjectKind kind:List.of(ObjectKind.TABLE,ObjectKind.VIEW,ObjectKind.ROUTINE,ObjectKind.SEQUENCE,ObjectKind.TYPE)) {
            var scope=new MetadataScope(catalog,schema,"",kind);
            var request=ExploreRequest.newBuilder().setCatalog(catalog).setSchema(schema).setKind(kind).setIntrospectionLevel(2).setLimit(500).build();
            var relations=explorer.fetchBranch(session,request,deadline);put(branches,scope,relations,session);
            if(kind==ObjectKind.TABLE||kind==ObjectKind.VIEW)for(var relation:relations)for(ObjectKind child:List.of(ObjectKind.COLUMN,ObjectKind.INDEX,ObjectKind.CONSTRAINT,ObjectKind.FOREIGN_KEY,ObjectKind.TRIGGER)) {
                var childScope=new MetadataScope(catalog,schema,relation.getName(),child);
                put(branches,childScope,explorer.fetchBranch(session,request.toBuilder().setKind(child).setTable(relation.getName()).build(),deadline),session);
            }
        }
        explorer.metadata().publishTemporaryInventory(session,ticket,rules,branches);
        explorer.metadata().reconcileSessionResolution(session,epoch);return explorer.metadata().capture(session);
    }
    public static MetadataSnapshot refresh(Explorer explorer,SessionRegistry.Session session,String catalog,String schema,String table)throws Exception {
        return refresh(explorer,session,catalog,schema,table,null,System.nanoTime()+TimeUnit.SECONDS.toNanos(10),null);
    }
    /** A pre-stream observation can reuse its native TEMP marker while acquiring requested owned details. */
    public static MetadataSnapshot refresh(Explorer explorer,SessionRegistry.Session session,String catalog,String schema,String table,io.busystack.busydata.jobs.Jobs.Job job,long deadline,io.busystack.busydata.schema.OwnedTemporarySource.Classification verifiedTemporary)throws Exception {
        if(!session.lock.isHeldByCurrentThread())throw new IllegalStateException("Temporary introspection requires physical-session ownership");
        if(session.profile.getEngine()==Engine.POSTGRESQL)return refresh(explorer,session);
        catalog=catalog.isEmpty()?session.context.catalog():catalog;schema=catalog;
        for(String name:List.of(catalog,table))if(name.isEmpty()||name.length()>256||name.indexOf('\0')>=0)throw new IllegalArgumentException("Exact temporary-object identity required");
        var rules=explorer.metadata().ensureOwnedIdentifierRules(session,deadline);long ticket=explorer.metadata().beginRefresh(session);
        var classification=verifiedTemporary==null?io.busystack.busydata.schema.OwnedTemporarySource.verify(explorer.metadata(),session,catalog,schema,table,deadline,job):verifiedTemporary;
        if(!classification.available())classification.requirePersistent();
        if(classification.kind()!=MetadataSnapshot.PhysicalRelationKind.TEMPORARY){
            if(classification.available())explorer.metadata().removeTemporary(session,catalog,schema,table);
            throw new io.busystack.busydata.rpc.WorkbenchFailure(classification.state()==MetadataState.DENIED?io.busystack.busydata.rpc.WorkbenchFailure.Reason.DENIED:io.busystack.busydata.rpc.WorkbenchFailure.Reason.STALE);
        }
        // Only the native CREATE header can supply an exact name here. SHOW's
        // display field and a parsed reference are never identity substitutes.
        classification.requireNativeName();
        if(!rules.matches(ObjectKind.TABLE,classification.nativeName(),table,true))throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.STALE);
        table=classification.nativeName();
        catalog=rules.lookup(ObjectKind.CATALOG,catalog,true);schema=catalog;
        var config=explorer.metadata().configuration(session);
        if(!config.permits(catalog,schema,ObjectKind.TABLE,table))return explorer.metadata().capture(session);
        var branches=new LinkedHashMap<MetadataScope,MetadataPlatform.Branch>();
        classification.checkCurrent(explorer.metadata(),session,catalog,schema,table);
        temporaryBranches(branches,explorer,session,rules,catalog,table,config.level(catalog,schema),deadline,new long[]{0,0},job,classification.nativeNameProvenance(),classification.definition());
        classification.checkCurrent(explorer.metadata(),session,catalog,schema,table);
        if(config.revision()!=explorer.metadata().configuration(session).revision())throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.INVALID_REVISION);
        return explorer.metadata().publish(session,ticket,rules,branches,true);
    }
    /** MariaDB 11.8 exposes this physical session's local temporary TABLE rows.
     * Ordinary BASE TABLE and SYSTEM VIEW rows are never absence/ownership proof. */
    private static MetadataSnapshot refreshMariaInventory(Explorer explorer,SessionRegistry.Session session)throws Exception {
        var platform=explorer.metadata();long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(10);
        var rules=platform.ensureOwnedIdentifierRules(session,deadline);var config=platform.configuration(session);long configRevision=config.revision();
        long revision=session.revision,context=session.contextRevision;
        long ticket=platform.beginRefresh(session);
        long epoch=platform.sessionResolutionEpoch(session);if(epoch==0)epoch=platform.markSessionResolutionUnknown(session,"Owned temporary inventory requires exact physical resolution verification");
        var catalogs=new TreeSet<String>(config.includedCatalogs());if(catalogs.isEmpty()&&!session.context.catalog().isEmpty())catalogs.add(session.context.catalog());
        catalogs.removeIf(catalog->!config.permits(catalog,catalog,ObjectKind.TABLE,""));
        if(catalogs.size()>128)throw new IllegalArgumentException("Owned temporary inventory catalog budget exceeded");
        var found=new ArrayList<List<String>>();
        if(!catalogs.isEmpty()){
            String sql="SELECT TABLE_SCHEMA,TABLE_NAME FROM information_schema.TABLES WHERE TABLE_TYPE='TEMPORARY' AND TABLE_SCHEMA IN ("+String.join(",",Collections.nCopies(catalogs.size(),"?"))+") ORDER BY TABLE_SCHEMA,TABLE_NAME LIMIT 257";
            io.busystack.busydata.schema.OwnedTemporarySource.query(session,sql,deadline,null,(statement,check)->{
                int parameter=1;for(String catalog:catalogs)statement.setString(parameter++,catalog);statement.setMaxRows(257);
                try(var rows=statement.executeQuery()){
                    int scanned=0;
                    while(rows.next()){check.run();if(++scanned>256)throw new IllegalArgumentException("Owned temporary inventory relation budget exceeded");
                        String catalog=rows.getString(1),name=rows.getString(2);if(catalog==null||name==null||catalog.length()>256||name.length()>256)throw new SQLException("Invalid native temporary identity");
                        if(config.permits(catalog,catalog,ObjectKind.TABLE,name))found.add(List.of(catalog,name));
                    }
                }return null;
            });
        }
        var branches=new LinkedHashMap<MetadataScope,MetadataPlatform.Branch>();long[] budget={0,0};
        for(var relation:found){
            if(!platform.markSessionRelationVerified(session,epoch,relation.get(0),relation.get(0),relation.get(1),MetadataSnapshot.PhysicalRelationKind.TEMPORARY))throw new IllegalStateException("Temporary resolution epoch changed during inventory");
            temporaryBranches(branches,explorer,session,rules,relation.get(0),relation.get(1),config.level(relation.get(0),relation.get(0)),deadline,budget,null,"OWNED_NATIVE_TEMPORARY_INVENTORY",NativeDefinitionEvidence.unavailable());
        }
        if(revision!=session.revision||context!=session.contextRevision||configRevision!=platform.configuration(session).revision()||epoch!=platform.sessionResolutionEpoch(session))throw new IllegalStateException("Temporary inventory owner changed before publication");
        return platform.publishTemporaryInventory(session,ticket,rules,branches);
    }
    private static void temporaryBranches(Map<MetadataScope,MetadataPlatform.Branch> branches,Explorer explorer,SessionRegistry.Session session,IdentifierRules rules,String catalog,String table,IntrospectionLevel level,long deadline,long[] budget,io.busystack.busydata.jobs.Jobs.Job job,String nameProvenance,NativeDefinitionEvidence definition)throws Exception {
        var relation=SchemaObject.newBuilder().setCatalog(catalog).setSchema(catalog).setName(table).setKind(ObjectKind.TABLE).setSubtype(ObjectSubtype.ORDINARY_TABLE).putProperties("temporary","true").putProperties("nativeNameAvailability",MetadataState.AVAILABLE.name()).putProperties("nativeNameProvenance",nameProvenance).putAllProperties(definition.properties());
        var columns=new ArrayList<SchemaObject>();var config=explorer.metadata().configuration(session);
        if(level.includes(IntrospectionLevel.STRUCTURE)&&config.permits(catalog,catalog,ObjectKind.COLUMN,table)){
            // LIMIT 0 reads no user rows and obtains transport types on the owner.
            io.busystack.busydata.schema.OwnedTemporarySource.query(session,"SELECT * FROM "+session.adapter.table(catalog,catalog,table)+" LIMIT 0",deadline,job,(statement,check)->{
                try(var rows=statement.executeQuery()){
                    var metadata=rows.getMetaData();if(metadata.getColumnCount()>2048||budget[0]+metadata.getColumnCount()>8192)throw new IllegalArgumentException("Temporary column budget exceeded");budget[0]+=metadata.getColumnCount();
                    for(int index=1;index<=metadata.getColumnCount();index++){check.run();var column=SchemaObject.newBuilder().setCatalog(catalog).setSchema(catalog).setTable(table).setName(metadata.getColumnName(index)).setKind(ObjectKind.COLUMN)
                        .putProperties("type",metadata.getColumnTypeName(index)).putProperties("jdbcType",Integer.toString(metadata.getColumnType(index))).putProperties("precision",Integer.toString(metadata.getPrecision(index))).putProperties("scale",Integer.toString(metadata.getScale(index)))
                        .putProperties("signed",Boolean.toString(metadata.isSigned(index))).putProperties("nullable",metadata.isNullable(index)==ResultSetMetaData.columnNoNulls?"NO":metadata.isNullable(index)==ResultSetMetaData.columnNullable?"YES":"UNKNOWN")
                        .putProperties("ordinal",Integer.toString(index)).putProperties("temporary","true").putProperties("generatedAvailability","NOT_EXPOSED").build();admit(budget,column.getSerializedSize());columns.add(column);}
                }return null;
            });
            var details=new HashMap<String,Map<String,String>>();
            io.busystack.busydata.schema.OwnedTemporarySource.query(session,"SHOW FULL COLUMNS FROM "+session.adapter.table(catalog,catalog,table),deadline,job,(statement,check)->{
                try(var rows=statement.executeQuery()){
                    while(rows.next()){
                        check.run();if(details.size()>=2048)throw new IllegalArgumentException("Temporary structural metadata budget exceeded");
                        String extra=Objects.toString(rows.getString("Extra"),"");var value=new HashMap<String,String>();
                        property(value,"type",rows.getString("Type"));property(value,"default",rows.getString("Default"));value.putIfAbsent("defaultAvailability",rows.getString("Default")==null?"ABSENT":"AVAILABLE");property(value,"collation",rows.getString("Collation"));
                        value.put("generated",extra.toUpperCase(Locale.ROOT).contains("VIRTUAL GENERATED")||extra.toUpperCase(Locale.ROOT).contains("STORED GENERATED")?"YES":"NO");value.put("autoIncrement",extra.contains("auto_increment")?"YES":"NO");property(value,"remarks",rows.getString("Comment"));value.putIfAbsent("remarksAvailability",Objects.toString(rows.getString("Comment"),"").isEmpty()?"ABSENT":"AVAILABLE");
                        long bytes=64;for(var property:value.entrySet())bytes+=16L+utf8Bytes(property.getKey())+utf8Bytes(property.getValue());admit(budget,bytes);
                        details.put(rows.getString("Field"),Map.copyOf(value));
                    }
                }return null;
            });
            for(int index=0;index<columns.size();index++)columns.set(index,columns.get(index).toBuilder().putAllProperties(details.getOrDefault(columns.get(index).getName(),Map.of())).build());
            var columnScope=new MetadataScope(catalog,catalog,table,ObjectKind.COLUMN);
            if(details.size()!=columns.size())branches.put(columnScope,new MetadataPlatform.Branch(columns,new MetadataCoverage(columnScope,IntrospectionLevel.STRUCTURE,MetadataState.LIMITED,false,"",session.revision,session.contextRevision,0,"The native result descriptor does not expose every temporary column")));
            else put(branches,columnScope,columns,session,IntrospectionLevel.STRUCTURE);
        }
        if(level.includes(IntrospectionLevel.SOURCE)){
            var normalized=MetadataObject.from(session.metadataSourceIdentity,session.profile.getId(),session.id,rules,relation.build(),level,session.revision,session.contextRevision);
            var source=io.busystack.busydata.schema.OwnedTemporarySource.read(session,normalized,deadline,job);
            relation.setDefinition(source.text()).putProperties("sourceAvailability",source.availability()).putProperties("sourceSqlMode",source.sqlMode()).putProperties("sourceProvenance","native SHOW CREATE TABLE on the owning physical session");
        }
        var object=relation.build();admit(budget,object.getSerializedSize());
        put(branches,new MetadataScope(catalog,catalog,"",ObjectKind.TABLE,table,true,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED),List.of(object),session,level);
    }
    private static void property(Map<String,String> properties,String key,String value){
        value=Objects.toString(value,"");long bytes=utf8Bytes(value);
        if(bytes>8192){properties.put(key,"");properties.put(key+"Availability","LIMITED");properties.put(key+"Bytes",Long.toString(bytes));}
        else properties.put(key,value);
    }
    private static void admit(long[] budget,long bytes){
        if(bytes<0||bytes>8_388_608-budget[1])throw new IllegalArgumentException("Temporary inventory response budget exceeded");budget[1]+=bytes;
    }
    /** Count without allocating another native-sized encoded copy. */
    private static long utf8Bytes(String value){
        long bytes=0;for(int index=0;index<value.length();index++){char unit=value.charAt(index);if(Character.isHighSurrogate(unit)){if(index+1>=value.length()||!Character.isLowSurrogate(value.charAt(++index)))throw new IllegalArgumentException("Invalid native metadata encoding");bytes+=4;}else if(Character.isLowSurrogate(unit))throw new IllegalArgumentException("Invalid native metadata encoding");else bytes+=unit<128?1:unit<2048?2:3;}return bytes;
    }
    /** Derive filtered structure or retrieve source only from the verified owned overlay. */
    public static MetadataPlatform.Branch branch(Explorer explorer,SessionRegistry.Session session,MetadataObject temporary,MetadataScope scope,IntrospectionLevel level,long deadline)throws Exception {
        if(!session.lock.isHeldByCurrentThread()||!temporary.identity().sessionOwner().equals(session.id)||!"true".equals(temporary.properties().get("temporary")))throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.INVALID_OWNER);
        var snapshot=explorer.metadata().capture(session);var identity=temporary.identity();
        var current=snapshot.identity(identity.key()).orElseThrow(()->new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.STALE));
        if(!current.identity().equals(identity)||!current.identity().sessionOwner().equals(session.id))throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.STALE);
        long revision=session.revision,context=session.contextRevision;
        if(scope.kind()!=ObjectKind.TABLE&&scope.kind()!=ObjectKind.COLUMN)return new MetadataPlatform.Branch(List.of(),new MetadataCoverage(scope,level,MetadataState.UNSUPPORTED,false,"",revision,context,0,"This temporary child metadata is not exposed by the owned adapter"));
        var config=explorer.metadata().configuration(session);
        String name=scope.parent().isEmpty()?identity.name():scope.parent();
        if(!config.permits(scope.catalog(),scope.schema(),scope.kind(),name))return new MetadataPlatform.Branch(List.of(),new MetadataCoverage(scope,level,MetadataState.NOT_REQUESTED,false,"",revision,context,0,"This temporary scope is excluded by introspection policy"));
        var coverage=snapshot.catalogCoverage().get(scope);
        if(coverage==null||!coverage.complete()||!coverage.level().includes(level==IntrospectionLevel.SOURCE?IntrospectionLevel.STRUCTURE:level)||!snapshot.scopeResolutionAvailable(scope)){
            long ticket=explorer.metadata().beginRefresh(session);
            var physical=io.busystack.busydata.schema.OwnedTemporarySource.verify(explorer.metadata(),session,identity.catalog(),identity.schema(),identity.name(),deadline,null);
            if(!physical.available())physical.requirePersistent();
            if(physical.kind()!=MetadataSnapshot.PhysicalRelationKind.TEMPORARY){if(physical.available())explorer.metadata().removeTemporary(session,identity.catalog(),identity.schema(),identity.name());throw new io.busystack.busydata.rpc.WorkbenchFailure(physical.state()==MetadataState.DENIED?io.busystack.busydata.rpc.WorkbenchFailure.Reason.DENIED:io.busystack.busydata.rpc.WorkbenchFailure.Reason.STALE);}
            var branches=new LinkedHashMap<MetadataScope,MetadataPlatform.Branch>();
            physical.requireNativeName();
            if(!physical.nativeName().equals(identity.name()))throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.STALE);
            physical.checkCurrent(explorer.metadata(),session,identity.catalog(),identity.schema(),identity.name());
            temporaryBranches(branches,explorer,session,snapshot.rules(),identity.catalog(),identity.name(),level==IntrospectionLevel.SOURCE?IntrospectionLevel.STRUCTURE:level,deadline,new long[]{0,0},null,physical.nativeNameProvenance(),physical.definition());
            physical.checkCurrent(explorer.metadata(),session,identity.catalog(),identity.schema(),identity.name());
            if(config.revision()!=explorer.metadata().configuration(session).revision())throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.INVALID_REVISION);
            snapshot=explorer.metadata().publish(session,ticket,snapshot.rules(),branches,true);
            current=snapshot.identity(identity.key()).orElseThrow(()->new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.STALE));coverage=snapshot.catalogCoverage().get(scope);
        }
        if(coverage==null)return new MetadataPlatform.Branch(List.of(),new MetadataCoverage(scope,level,MetadataState.NOT_REQUESTED,false,"",revision,context,0,"The requested temporary details were not acquired"));
        if(!coverage.complete()||!coverage.level().includes(level==IntrospectionLevel.SOURCE?IntrospectionLevel.STRUCTURE:level))return MetadataPlatform.Branch.reused(coverage);
        var values=snapshot.select(scope);
        if(values.stream().anyMatch(object->!object.identity().sessionOwner().equals(session.id)))throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.INVALID_OWNER);
        if(!level.includes(IntrospectionLevel.SOURCE))return MetadataPlatform.Branch.reused(coverage);
        var sources=new ArrayList<SchemaObject>();
        if(scope.kind()==ObjectKind.TABLE) {
            var source=io.busystack.busydata.schema.OwnedTemporarySource.read(session,current,deadline);
            var projected=snapshot.projection(current).toBuilder().setDefinition(source.text()).putProperties("sourceAvailability",source.availability()).putProperties("sourceSqlMode",source.sqlMode()).putProperties("sourceProvenance","native SHOW CREATE TABLE on the owning physical session").build();
            if(projected.getSerializedSize()>65_536)projected=projected.toBuilder().clearDefinition().putProperties("sourceAvailability","LIMITED").build();
            sources.add(projected);
        }else for(var value:values)sources.add(snapshot.projection(value).toBuilder().clearDefinition().putProperties("sourceAvailability","UNSUPPORTED").putProperties("sourceProvenance","Individual temporary column source is unavailable; inspect the owning table source").build());
        return new MetadataPlatform.Branch(sources,new MetadataCoverage(scope,level,MetadataState.AVAILABLE,true,MetadataIdentity.digest(sources.toString()),revision,context,System.currentTimeMillis(),""));
    }
    private static void put(Map<MetadataScope,MetadataPlatform.Branch> branches,MetadataScope scope,List<SchemaObject> objects,SessionRegistry.Session session) {
        put(branches,scope,objects,session,IntrospectionLevel.STRUCTURE);
    }
    private static void put(Map<MetadataScope,MetadataPlatform.Branch> branches,MetadataScope scope,List<SchemaObject> objects,SessionRegistry.Session session,IntrospectionLevel level) {
        branches.put(scope,new MetadataPlatform.Branch(objects,new MetadataCoverage(scope,level,MetadataState.AVAILABLE,true,MetadataIdentity.digest(objects.toString()),session.revision,session.contextRevision,System.currentTimeMillis(),"")));
    }
}
