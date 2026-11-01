package io.busystack.busydata.schema;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.sessions.SessionRegistry;
import java.sql.*;
import java.util.*;
import java.util.concurrent.*;

/** Server-filtered persistent-object search, independent of the bounded tree/cache. */
final class ObjectSearch {
    private static final Semaphore admission=new Semaphore(4);
    private static final ExecutorService cancellation=Executors.newVirtualThreadPerTaskExecutor();
    static SchemaObjects search(SessionRegistry.Session source,ExploreRequest request)throws Exception {
        if(!admission.tryAcquire())throw new IllegalStateException("Object search admission limit reached; retry after another search finishes");
        try {
            if(request.getSearch().length()>256||request.getContinuation().length()>RoutineIdentity.CONTINUATION_TEXT)throw new IllegalArgumentException("Search text or continuation exceeds its budget");
            long revision=source.contextRevision,metadataRevision=source.revision;
            String catalog=request.getCatalog().isEmpty()?(source.profile.getEngine()!=Engine.POSTGRESQL&&!request.getSchema().isEmpty()?request.getSchema():source.context.catalog()):request.getCatalog();
            String owner=source.id+":"+metadataRevision+":"+request.getCatalog()+":"+request.getSchema();
            var result=source.metadata(catalog,session->query(session,request,revision,owner));
            if(source.contextRevision!=revision||source.revision!=metadataRevision)throw new IllegalStateException("Search context changed; start a new search");
            return result.toBuilder().setProfileId(source.profile.getId()).setSessionId(source.id).setInstanceId(request.getContext().getInstanceId()).setCatalog(catalog).setSchema(request.getSchema()).setKind(request.getKind()).build();
        }finally{admission.release();}
    }
    private static SchemaObjects query(SessionRegistry.Session session,ExploreRequest request,long revision,String owner)throws Exception {
        boolean postgres=session.profile.getEngine()==Engine.POSTGRESQL;
        String tables=postgres?"SELECT n.nspname AS s,c.relname AS t,CASE WHEN c.relkind='S' THEN 10 WHEN c.relkind IN ('v','m') THEN 3 ELSE 2 END AS k,c.relname AS n,'' AS i,CASE c.relkind WHEN 'r' THEN 1 WHEN 'p' THEN 2 WHEN 'f' THEN 3 WHEN 'v' THEN 4 WHEN 'm' THEN 5 WHEN 'S' THEN 6 END AS y FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE c.relkind IN ('r','p','f','v','m','S')":
            "SELECT table_schema AS s,table_name AS t,CASE WHEN table_type='SEQUENCE' THEN 10 WHEN table_type IN ('VIEW','SYSTEM VIEW') THEN 3 ELSE 2 END AS k,table_name AS n,'' AS i,CASE WHEN table_type='SEQUENCE' THEN 6 WHEN table_type IN ('VIEW','SYSTEM VIEW') THEN 4 ELSE 1 END AS y FROM information_schema.tables";
        String columns="SELECT table_schema s,table_name t,4 k,column_name n,'' i,0 y FROM information_schema.columns";
        String routines=postgres?"SELECT n.nspname s,'' t,7 k,p.proname n,"+RoutineIdentity.POSTGRES_KEY+" i,CASE WHEN p.prokind='p' THEN 8 ELSE 7 END y FROM "+RoutineIdentity.POSTGRES_FROM+" WHERE "+RoutineIdentity.POSTGRES_VISIBLE:"SELECT routine_schema s,'' t,7 k,routine_name n,"+RoutineIdentity.MYSQL_KEY+" i,CASE WHEN routine_type='PROCEDURE' THEN 8 ELSE 7 END y FROM information_schema.routines";
        String triggers="SELECT trigger_schema s,event_object_table t,8 k,trigger_name n,'' i,0 y FROM information_schema.triggers";
        String constraints="SELECT constraint_schema s,table_name t,6 k,constraint_name n,"+(postgres?"''":"CONSTRAINT_TYPE")+" i,0 y FROM information_schema.table_constraints";
        String indexes=postgres?"SELECT schemaname s,tablename t,5 k,indexname n,'' i,0 y FROM pg_indexes":"SELECT "+binary("table_schema",false)+" s,"+binary("table_name",false)+" t,5 k,"+binary("index_name",false)+" n,'' i,0 y FROM information_schema.statistics GROUP BY 1,2,4";
        var branches=new ArrayList<>(List.of(tables,columns,routines,triggers,constraints,indexes));
        if(!postgres)branches.replaceAll(branch->"SELECT "+binary("s",false)+" s,"+binary("t",false)+" t,k,"+binary("n",false)+" n,"+binary("i",false)+" i,y FROM ("+branch+") native_objects");
        String pattern="%"+request.getSearch().toLowerCase(Locale.ROOT).replace("!","!!").replace("%","!%").replace("_","!_")+"%";
        SchemaObject after=SchemaObject.getDefaultInstance();
        if(!request.getContinuation().isEmpty()) {
            var raw=Base64.getUrlDecoder().decode(request.getContinuation());if(raw.length>RoutineIdentity.CONTINUATION_BYTES)throw new IllegalArgumentException("Invalid search continuation");
            after=SchemaObject.parseFrom(raw);
            if(!after.getPropertiesOrDefault("owner","").equals(owner)||!after.getPropertiesOrDefault("contextCatalog","").equals(session.context.catalog())||!after.getPropertiesOrDefault("contextRevision","").equals(Long.toString(revision))||!after.getPropertiesOrDefault("search","").equals(request.getSearch()))throw new IllegalArgumentException("Search continuation belongs to another query/context");
        }
        String filter=postgres?"s NOT IN ('pg_catalog','information_schema') AND s NOT LIKE 'pg_toast%'":"s NOT IN ('mysql','sys','performance_schema','information_schema')";
        String namespace=request.getSchema().isEmpty()?(postgres?"":request.getCatalog()):request.getSchema();
        if(!namespace.isEmpty())filter="1=1";
        if(postgres)filter+=" AND LEFT(s,8)<>'pg_temp_'";
        String schemaOrder=binary("s",postgres),parentOrder=binary("t",postgres),nameOrder=binary("n",postgres),identityOrder=binary("i",postgres);
        String sql="SELECT DISTINCT "+schemaOrder+" AS s,"+parentOrder+" AS t,k,"+nameOrder+" AS n,"+identityOrder+" AS i,y FROM ("+String.join(" UNION ALL ",branches)+") objects WHERE "+filter+" AND LOWER(n) LIKE ? ESCAPE '!'"+(namespace.isEmpty()?"":" AND "+schemaOrder+"=?")+(request.getContinuation().isEmpty()?"":" AND ("+schemaOrder+","+parentOrder+",k,"+nameOrder+","+identityOrder+")>(?,?,?,?,?)")+" ORDER BY s,t,k,n,i LIMIT ?";
        int limit=request.getLimit()==0?200:Math.min(request.getLimit(),500);if(limit<1)throw new IllegalArgumentException("Invalid search limit");
        var out=SchemaObjects.newBuilder().setContextRevision(revision).setAvailability("Persistent objects in the current database context; temporary/session-local objects remain in console navigation");
        var context=io.grpc.Context.current();
        try(var statement=session.adapter.catalogStatement(session.connection,sql)) {
            statement.setQueryTimeout(10);int parameter=1;statement.setString(parameter++,pattern);if(!namespace.isEmpty())statement.setString(parameter++,namespace);
            if(!request.getContinuation().isEmpty()){statement.setString(parameter++,after.getSchema());statement.setString(parameter++,after.getTable());statement.setInt(parameter++,after.getKindValue());statement.setString(parameter++,after.getName());statement.setString(parameter++,after.getIdentifier());}statement.setInt(parameter,limit+1);
            io.grpc.Context.CancellationListener listener=ignored->{try{statement.cancel();}catch(SQLException ignoredFailure){}};
            context.addListener(listener,cancellation);
            try {
                if(context.isCancelled())throw new CancellationException("Object search cancelled");
                int bytes=256;boolean more=false;
                try(var rows=statement.executeQuery()) {
                    while(rows.next()) {
                        if(context.isCancelled())throw new CancellationException("Object search cancelled");
                        var object=SchemaObject.newBuilder().setCatalog(postgres?session.context.catalog():rows.getString(1)).setSchema(rows.getString(1)).setTable(rows.getString(2)).setKindValue(rows.getInt(3)).setName(rows.getString(4)).setIdentifier(rows.getString(5)).setSubtypeValue(rows.getInt(6)).build();
                        if(object.getIdentifier().getBytes(java.nio.charset.StandardCharsets.UTF_8).length>RoutineIdentity.MAX_BYTES)throw new IllegalStateException("Native routine identity exceeds the 8KiB search identity budget; narrow the scope");
                        int size=object.getSerializedSize()+16;
                        if(size>65536)throw new IllegalStateException("Object identity exceeds the search row budget");
                        if(out.getObjectsCount()==limit||bytes+size>524288){more=true;break;}
                        out.addObjects(object);bytes+=size;
                    }
                }
                if(more){if(out.getObjectsCount()==0)throw new IllegalStateException("Object search cannot make progress within its byte budget");var last=out.getObjects(out.getObjectsCount()-1).toBuilder().putProperties("owner",owner).putProperties("contextRevision",Long.toString(revision)).putProperties("contextCatalog",session.context.catalog()).putProperties("search",request.getSearch()).build();if(last.getSerializedSize()>RoutineIdentity.CONTINUATION_BYTES)throw new IllegalStateException("Search continuation exceeds its identity budget");out.setContinuation(Base64.getUrlEncoder().withoutPadding().encodeToString(last.toByteArray()));}
                return out.setComplete(!more).build();
            }finally{context.removeListener(listener);}
        }
    }
    private static String binary(String field,boolean postgres){return postgres?field+" COLLATE \"C\"":"CONVERT("+field+" USING utf8mb4) COLLATE utf8mb4_bin";}
}
