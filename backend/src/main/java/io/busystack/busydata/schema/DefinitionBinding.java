package io.busystack.busydata.schema;

import com.google.gson.JsonObject;
import io.busystack.busydata.analysis.*;
import io.busystack.busydata.protocol.Engine;
import io.busystack.busydata.sessions.SessionRegistry;
import java.util.*;

/** Binds native designer text to the inspected identity without AST serialization. */
final class DefinitionBinding {
 private record Header(List<SqlLexer.Token> tokens,int kind,int name,int lastName,int argumentsEnd,List<String> signature){}
 static String qualifyRoutine(SessionRegistry.Session s,String schema,String name,String definition) {
  var value=header(s,definition);return bind(s,schema,name,definition,value.tokens,value.name,value.lastName);
 }
 static String routine(SessionRegistry.Session s,String schema,JsonObject captured,String definition) {
  var old=header(s,captured.get("definition").getAsString());var next=header(s,definition);
  String expected=Set.of("p","PROCEDURE").contains(captured.get("kind").getAsString())?"PROCEDURE":"FUNCTION";
  if(!next.tokens.get(next.kind).is(expected)||!old.signature.equals(next.signature))throw new IllegalArgumentException("Retain the inspected routine kind, argument signature and return type; signature changes require a separate new definition and dependency review");
  String bound=bind(s,schema,captured.get("name").getAsString(),definition,next.tokens,next.name,next.lastName);
  if(s.profile.getEngine()==Engine.POSTGRESQL&&!next.tokens.stream().limit(next.kind).anyMatch(t->t.is("REPLACE")))bound=bound.substring(0,next.tokens.getFirst().end())+" OR REPLACE"+bound.substring(next.tokens.getFirst().end());
  return bound;
 }
 static String trigger(SessionRegistry.Session s,String schema,String table,String name,String definition) {
  var tokens=tokens(s,definition);int kind=find(tokens,"TRIGGER");if(kind<0||kind+1>=tokens.size())throw new IllegalArgumentException("Provide a complete CREATE TRIGGER definition");
  int last=lastName(tokens,kind+1);String bound=bind(s,schema,name,definition,tokens,kind+1,last);
  // Re-scan after qualification because offsets in the rest of the text moved.
  tokens=tokens(s,bound);int on=find(tokens,"ON");if(on<0||on+1>=tokens.size())throw new IllegalArgumentException("Trigger definition must identify its inspected table");
  return bind(s,schema,table,bound,tokens,on+1,lastName(tokens,on+1));
 }
 private static Header header(SessionRegistry.Session s,String sql) {
  var tokens=tokens(s,sql);int kind=-1;for(int i=1;i<Math.min(tokens.size(),32);i++)if(tokens.get(i).is("FUNCTION")||tokens.get(i).is("PROCEDURE")){kind=i;break;}
  if(kind<0||kind+2>=tokens.size())throw new IllegalArgumentException("Provide a complete native CREATE FUNCTION/PROCEDURE definition");int first=kind+1,last=lastName(tokens,first),open=last+1;
  if(open>=tokens.size()||!tokens.get(open).text().equals("("))throw new IllegalArgumentException("Routine argument signature is unavailable");int depth=0,end=-1;
  for(int i=open;i<tokens.size();i++){String t=tokens.get(i).text();if(t.equals("("))depth++;if(t.equals(")")&&--depth==0){end=i;break;}}
  if(end<0)throw new IllegalArgumentException("Complete the routine argument signature");var signature=new ArrayList<String>();for(int i=open;i<=end;i++)signature.add(canonical(tokens.get(i)));
  if(tokens.get(kind).is("FUNCTION")){
   if(end+1>=tokens.size()||!tokens.get(end+1).is("RETURNS"))throw new IllegalArgumentException("Retain the inspected native RETURNS clause");
   var boundary=Set.of("LANGUAGE","AS","RETURN","BEGIN","COMMENT","DETERMINISTIC","NOT","CONTAINS","NO","READS","MODIFIES","SQL","IMMUTABLE","STABLE","VOLATILE","STRICT","CALLED","SECURITY","PARALLEL","COST","ROWS","SUPPORT","SET","WINDOW","TRANSFORM");depth=0;
   for(int i=end+1;i<tokens.size();i++){var token=tokens.get(i);if(i>end+1&&depth==0&&token.kind()==SqlLexer.Kind.WORD&&boundary.contains(token.text().toUpperCase(Locale.ROOT)))break;signature.add(canonical(token));if(token.text().equals("("))depth++;else if(token.text().equals(")"))depth--;}
  }
  return new Header(tokens,kind,first,last,end,List.copyOf(signature));
 }
 private static String canonical(SqlLexer.Token token){return token.kind()==SqlLexer.Kind.WORD?token.text().toUpperCase(Locale.ROOT):token.text();}
 private static List<SqlLexer.Token> tokens(SessionRegistry.Session s,String sql){
  if(sql.length()>65536)throw new IllegalArgumentException("Native definition exceeds 64Ki UTF-16 units");var parts=new SqlAnalysis().split(sql,s.profile.getEngine(),s.context.lexical());if(parts.size()!=1)throw new IllegalArgumentException("Provide one complete native CREATE definition; extra statements require separate review");
  var out=SqlLexer.scan(sql,s.profile.getEngine(),s.context.lexical()).stream().filter(t->t.kind()!=SqlLexer.Kind.COMMENT).toList();if(out.isEmpty()||!out.getFirst().is("CREATE")||out.stream().anyMatch(t->!t.complete()))throw new IllegalArgumentException("Complete the native CREATE definition");return out;
 }
 private static int find(List<SqlLexer.Token> tokens,String word){for(int i=1;i<Math.min(tokens.size(),64);i++)if(tokens.get(i).is(word))return i;return -1;}
 private static int lastName(List<SqlLexer.Token> tokens,int first){return first+2<tokens.size()&&tokens.get(first+1).text().equals(".")?first+2:first;}
 private static String identifier(SqlLexer.Token token,boolean pg){if(token.kind()==SqlLexer.Kind.WORD)return pg?token.text().toLowerCase(Locale.ROOT):token.text();if(token.kind()==SqlLexer.Kind.IDENTIFIER){String q=token.text().substring(0,1);return token.text().substring(1,token.text().length()-1).replace(q+q,q);}throw new IllegalArgumentException("Use the exact native object identifier");}
 private static String bind(SessionRegistry.Session s,String schema,String name,String text,List<SqlLexer.Token> tokens,int first,int last){boolean pg=s.profile.getEngine()==Engine.POSTGRESQL;if(!identifier(tokens.get(last),pg).equals(name)||first!=last&&!identifier(tokens.get(first),pg).equals(schema))throw new IllegalArgumentException("The native definition targets another object; retain the inspected schema/name");return text.substring(0,tokens.get(first).start())+s.adapter.table("",schema,name)+text.substring(tokens.get(last).end());}
}
