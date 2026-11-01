package io.busystack.busydata.schema;

import com.google.gson.*;
import io.busystack.busydata.protocol.Engine;
import io.busystack.busydata.sessions.SessionRegistry;
import java.sql.*;
import java.util.*;

/** Exact routine ownership/ACLs; no authentication catalog material is read. */
final class RoutineAccess {
 static JsonObject capture(SessionRegistry.Session s,String schema,String name,String arguments,String kind,SnapshotBudget working)throws SQLException {
  var out=new JsonObject();var grants=new JsonArray();boolean pg=s.profile.getEngine()==Engine.POSTGRESQL;
  if(pg) {
   try(var st=s.adapter.catalogStatement(s.connection,"SELECT pg_get_userbyid(p.proowner),CASE WHEN a.grantee=0 THEN 'PUBLIC' ELSE pg_get_userbyid(a.grantee) END,a.is_grantable,a.grantee=0 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace CROSS JOIN LATERAL aclexplode(COALESCE(p.proacl,acldefault('f',p.proowner))) a WHERE n.nspname=? AND p.proname=? AND pg_get_function_identity_arguments(p.oid)=? ORDER BY 2,3")){
    st.setString(1,schema);st.setString(2,name);st.setString(3,arguments);st.setQueryTimeout(10);st.setMaxRows(501);
    try(var rows=st.executeQuery()){while(rows.next()){out.addProperty("owner",rows.getString(1));var grant=new JsonObject();grant.addProperty("principal",rows.getString(2));grant.addProperty("privilege","EXECUTE");grant.addProperty("delegation",rows.getBoolean(3));grant.addProperty("public",rows.getBoolean(4));working.retain(grant.toString());grants.add(grant);limit(grants);}}
   }
  }else {
   try(var st=s.adapter.catalogStatement(s.connection,"SELECT User,Host,Proc_priv FROM mysql.procs_priv WHERE Db=? AND Routine_name=? AND Routine_type=? ORDER BY User,Host")){
    st.setString(1,schema);st.setString(2,name);st.setString(3,kind);st.setQueryTimeout(10);st.setMaxRows(501);
    try(var rows=st.executeQuery()){while(rows.next()){var privileges=Arrays.asList(rows.getString(3).split(","));for(String privilege:privileges){if(privilege.equalsIgnoreCase("Grant"))continue;var grant=new JsonObject();grant.addProperty("principal",rows.getString(1));grant.addProperty("host",rows.getString(2));grant.addProperty("privilege",privilege.equalsIgnoreCase("Alter Routine")?"ALTER ROUTINE":privilege.toUpperCase(Locale.ROOT));grant.addProperty("delegation",privileges.stream().anyMatch(p->p.equalsIgnoreCase("Grant")));working.retain(grant.toString());grants.add(grant);limit(grants);}}}
   }catch(SQLException denied){if(denied.getSQLState()!=null&&denied.getSQLState().startsWith("42"))out.addProperty("unavailable","Routine grants could not be inspected; obtain catalog privileges before rebuilding this routine");else throw denied;}
  }
  out.add("grants",grants);return out;
 }
 private static void limit(JsonArray grants){if(grants.size()>500)throw new IllegalArgumentException("Routine grant limit is 500");}
 static List<String> restore(SessionRegistry.Session s,String schema,JsonObject routine) {
  if(!routine.has("access"))throw new UnsupportedOperationException("Routine access was not captured; refresh the snapshot before rebuilding");
  var access=routine.getAsJsonObject("access");if(access.has("unavailable"))throw new UnsupportedOperationException(access.get("unavailable").getAsString());
  boolean pg=s.profile.getEngine()==Engine.POSTGRESQL;String kind=Set.of("p","PROCEDURE").contains(routine.get("kind").getAsString())?"PROCEDURE":"FUNCTION";
  String object=kind+" "+s.adapter.table("",schema,routine.get("name").getAsString())+(pg?"("+routine.get("arguments").getAsString()+")":"");var out=new ArrayList<String>();
  if(pg){if(!access.has("owner"))throw new UnsupportedOperationException("Routine owner unavailable");out.add("ALTER "+object+" OWNER TO "+s.adapter.quote(access.get("owner").getAsString())+";");out.add("REVOKE ALL ON "+object+" FROM PUBLIC;");}
  for(var item:access.getAsJsonArray("grants")){var grant=item.getAsJsonObject();String privilege=grant.get("privilege").getAsString();if(!Set.of("EXECUTE","ALTER ROUTINE").contains(privilege)||pg&&!privilege.equals("EXECUTE"))throw new UnsupportedOperationException("Unsupported captured routine grant: "+privilege);String principal=pg&&grant.get("public").getAsBoolean()?"PUBLIC":s.adapter.quote(grant.get("principal").getAsString())+(pg?"":"@"+s.adapter.quote(grant.get("host").getAsString()));out.add("GRANT "+privilege+" ON "+object+" TO "+principal+(grant.get("delegation").getAsBoolean()?" WITH GRANT OPTION":"")+";");}
  return out;
 }
}
