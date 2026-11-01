package io.busystack.busydata.schema;

import com.google.gson.*;
import io.busystack.busydata.protocol.Engine;
import io.busystack.busydata.sessions.SessionRegistry;
import java.sql.*;
import java.util.*;

/** Native view security/options and grants survive dependency rebuilds. */
final class ViewProperties {
 static JsonObject capture(SessionRegistry.Session s,String schema,SnapshotBudget working)throws SQLException {
  var out=new JsonObject();boolean pg=s.profile.getEngine()==Engine.POSTGRESQL;
  String query=pg?"SELECT c.relname,pg_get_userbyid(c.relowner),COALESCE(c.reloptions::text,'') FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=? AND c.relkind='v' ORDER BY c.relname":"SELECT TABLE_NAME,DEFINER,SECURITY_TYPE,CHECK_OPTION FROM information_schema.VIEWS WHERE TABLE_SCHEMA=? ORDER BY TABLE_NAME";
  try(var st=s.adapter.catalogStatement(s.connection,query)){st.setString(1,schema);st.setQueryTimeout(10);st.setMaxRows(1001);try(var rows=st.executeQuery()){while(rows.next()){
   if(out.size()>=1000)throw new IllegalArgumentException("View limit is 1000");String name=working.retain(rows.getString(1));var properties=new JsonObject();var grants=new JsonArray();
   if(pg){properties.addProperty("owner",rows.getString(2));String options=rows.getString(3);var parsed=new JsonObject();if(!options.isEmpty())for(String item:options.substring(1,options.length()-1).split(",")){String[] pair=item.split("=",2);if(pair.length==2)parsed.addProperty(pair[0],pair[1]);else throw new SQLException("View options cannot be represented safely");}properties.add("options",parsed);
    try(var access=s.adapter.catalogStatement(s.connection,"SELECT CASE WHEN a.grantee=0 THEN 'PUBLIC' ELSE pg_get_userbyid(a.grantee) END,a.privilege_type,a.is_grantable,a.grantee=0 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace CROSS JOIN LATERAL aclexplode(c.relacl) a WHERE n.nspname=? AND c.relname=? ORDER BY 1,2,3")){access.setString(1,schema);access.setString(2,name);access.setQueryTimeout(10);try(var acl=access.executeQuery()){while(acl.next()){var grant=new JsonObject();grant.addProperty("principal",acl.getString(1));grant.addProperty("privilege",acl.getString(2));grant.addProperty("delegation",acl.getBoolean(3));grant.addProperty("public",acl.getBoolean(4));working.retain(grant.toString());grants.add(grant);if(grants.size()>500)throw new IllegalArgumentException("View grants exceed 500");}}}
   }else{
    properties.addProperty("definer",rows.getString(2));properties.addProperty("security",rows.getString(3));properties.addProperty("check",rows.getString(4));
    try(var definition=s.connection.createStatement()){definition.setQueryTimeout(10);try(var nativeRows=definition.executeQuery("SHOW CREATE VIEW "+s.adapter.table("",schema,name))){if(!nativeRows.next())throw new SQLException("View disappeared during capture");String ddl=working.retain(nativeRows.getString(2));var tokens=io.busystack.busydata.analysis.SqlLexer.scan(ddl,s.profile.getEngine(),s.context.lexical());var as=tokens.stream().filter(t->t.is("AS")).findFirst().orElseThrow(()->new SQLException("View header unavailable"));properties.addProperty("nativeHeader",ddl.substring(0,as.end()));}}
    try(var access=s.adapter.catalogStatement(s.connection,"SELECT User,Host,Table_priv FROM mysql.tables_priv WHERE Db=? AND Table_name=? ORDER BY User,Host")){access.setString(1,schema);access.setString(2,name);access.setQueryTimeout(10);try(var acl=access.executeQuery()){while(acl.next())for(String privilege:acl.getString(3).split(",")){if(privilege.isBlank()||privilege.equalsIgnoreCase("Grant"))continue;var grant=new JsonObject();grant.addProperty("principal",acl.getString(1));grant.addProperty("host",acl.getString(2));grant.addProperty("privilege",privilege.toUpperCase(Locale.ROOT));grant.addProperty("delegation",Arrays.stream(acl.getString(3).split(",")).anyMatch(p->p.equalsIgnoreCase("Grant")));working.retain(grant.toString());grants.add(grant);if(grants.size()>500)throw new IllegalArgumentException("View grants exceed 500");}}}
    catch(SQLException denied){if(denied.getSQLState()!=null&&denied.getSQLState().startsWith("42"))properties.addProperty("grantVisibility","All table grants could not be inspected; rebuilding this view requires an explicit privilege-preservation plan");else throw denied;}
   }
   properties.add("grants",grants);out.add(name,properties);
  }}}
  return out;
 }
 private static String identifier(io.busystack.busydata.analysis.SqlLexer.Token token) {
  String text=token.text();if(token.kind()==io.busystack.busydata.analysis.SqlLexer.Kind.WORD)return text;
  if(token.kind()==io.busystack.busydata.analysis.SqlLexer.Kind.IDENTIFIER&&token.complete()){String quote=text.substring(0,1);return text.substring(1,text.length()-1).replace(quote+quote,quote);}
  throw new UnsupportedOperationException("Native view definer is not an exact quoted account");
 }
 static List<String> create(SessionRegistry.Session session,String schema,String name,String definition,JsonObject properties){
  var adapter=session.adapter;boolean pg=adapter.engine()==Engine.POSTGRESQL;String qualified=adapter.table("",schema,name);var statements=new ArrayList<String>();
  // PostgreSQL catalog definitions contain their own terminal semicolon;
  // CHECK OPTION belongs before that generated statement terminator.
  definition=definition.stripTrailing();if(definition.endsWith(";"))definition=definition.substring(0,definition.length()-1).stripTrailing();
  if(properties==null){statements.add("CREATE VIEW "+qualified+" AS "+definition+";");return statements;}
  if(properties.has("grantVisibility"))throw new UnsupportedOperationException(properties.get("grantVisibility").getAsString());
  var supported=pg?Set.of("owner","options","grants"):Set.of("definer","security","check","nativeHeader","grants");
  for(String key:properties.keySet())if(!supported.contains(key))throw new UnsupportedOperationException("Unsupported captured view property: "+key);
  if(pg){var options=properties.getAsJsonObject("options");var rendered=new ArrayList<String>();String check="";
   for(var option:options.entrySet()){String value=option.getValue().getAsString();if(Set.of("security_barrier","security_invoker").contains(option.getKey())&&Set.of("true","false").contains(value))rendered.add(option.getKey()+"="+value);else if(option.getKey().equals("check_option")&&Set.of("local","cascaded").contains(value))check=" WITH "+value.toUpperCase(Locale.ROOT)+" CHECK OPTION";else throw new UnsupportedOperationException("Unsupported captured view option: "+option.getKey());}
   statements.add("CREATE VIEW "+qualified+(rendered.isEmpty()?"":" WITH ("+String.join(",",rendered)+")")+" AS "+definition+check+";");statements.add("ALTER VIEW "+qualified+" OWNER TO "+adapter.quote(properties.get("owner").getAsString())+";");
  }else{
   String header=properties.get("nativeHeader").getAsString(),check=properties.get("check").getAsString(),security=properties.get("security").getAsString();
   if(!Set.of("DEFINER","INVOKER").contains(security))throw new UnsupportedOperationException("Unknown view security mode");
   var tokens=io.busystack.busydata.analysis.SqlLexer.scan(header,session.profile.getEngine(),session.context.lexical());
   boolean boundDefiner=false,boundSecurity=false;
   for(int i=0;i<tokens.size();i++) {
    if(tokens.get(i).is("DEFINER")&&i+4<tokens.size()&&tokens.get(i+1).text().equals("=")&&tokens.get(i+3).text().equals("@")) {
     String identity=identifier(tokens.get(i+2))+"@"+identifier(tokens.get(i+4));
     if(!identity.equals(properties.get("definer").getAsString()))throw new UnsupportedOperationException("Changing a view definer requires an exact native definition and account review");boundDefiner=true;
    }
    if(tokens.get(i).is("SQL")&&i+2<tokens.size()&&tokens.get(i+1).is("SECURITY")) {
     var value=tokens.get(i+2);header=header.substring(0,value.start())+security+header.substring(value.end());boundSecurity=true;
    }
   }
   if(!boundDefiner||!boundSecurity)throw new UnsupportedOperationException("Native view security header is incomplete");
   if(!Set.of("NONE","LOCAL","CASCADED").contains(check))throw new UnsupportedOperationException("Unknown view CHECK OPTION");
   statements.add(header+" "+definition+(check.equals("NONE")?"":" WITH "+check+" CHECK OPTION")+";");
  }
  for(var entry:properties.getAsJsonArray("grants")){var grant=entry.getAsJsonObject();String privilege=grant.get("privilege").getAsString();if(!Set.of("SELECT","INSERT","UPDATE","DELETE","TRUNCATE","MAINTAIN","REFERENCES","TRIGGER","SHOW VIEW","ALTER","DROP","INDEX").contains(privilege))throw new UnsupportedOperationException("Unsupported captured view privilege: "+privilege);String principal=pg&&grant.get("public").getAsBoolean()?"PUBLIC":adapter.quote(grant.get("principal").getAsString())+(pg?"":"@"+adapter.quote(grant.get("host").getAsString()));statements.add("GRANT "+privilege+" ON "+qualified+" TO "+principal+(grant.get("delegation").getAsBoolean()?" WITH GRANT OPTION":"")+";");}
  return statements;
 }
}
