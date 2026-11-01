package io.busystack.busydata.schema;

import com.google.gson.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.metadata.MetadataSnapshot;
import io.busystack.busydata.sessions.SessionRegistry;
import java.util.*;

/** Changes a captured object and delegates ordering and risk reporting to schema comparison. */
final class ObjectDesigner {
    private final SessionRegistry.Session session;private final boolean pg;private final MetadataSnapshot identifierEvidence;
    ObjectDesigner(SessionRegistry.Session session,MetadataSnapshot identifierEvidence){this.session=session;this.identifierEvidence=Objects.requireNonNull(identifierEvidence);if(identifierEvidence.rules().engine()!=session.profile.getEngine())throw new IllegalArgumentException("Native constraint rules belong to another engine");pg=session.profile.getEngine()==Engine.POSTGRESQL;}
    SchemaToolResult design(SchemaToolRequest request,JsonObject current)throws Exception{
        if(request.getSourceSnapshot().isEmpty())throw new IllegalArgumentException("Inspect the object before generating changes");
        var source=SchemaConstraints.importSnapshot(SnapshotJson.read(request.getSourceSnapshot()));
        if(!source.equals(current))throw new IllegalArgumentException("Object metadata changed since inspection; refresh the designer");
        if(request.getOperation().equals("table"))return newTable(request,current);
        var target=source.deepCopy();String schema=target.get("schema").getAsString(),name=request.getTable();
        var table=target.getAsJsonObject("tables").getAsJsonObject(name);
        if(Set.of("add","drop","alter","index","constraint","property","trigger").contains(request.getOperation())&&table==null)throw new IllegalArgumentException("Choose an existing table");
        switch(request.getOperation()){
            case "add","drop","alter"->column(request,table);
            case "index"->index(request,table,schema);
            case "constraint"->constraint(request,table,schema);
            case "property"->{var properties=table.getAsJsonObject("properties");String property=request.getProperty();if(!Set.of("engine","collation","rowFormat","comment","persistence").contains(property)||!properties.has(property))throw new IllegalArgumentException("Choose a supported property for this engine");properties.addProperty(property,request.getValue());}
            case "view"->{var views=target.getAsJsonObject("views");if(request.getProperty().equals("drop")){views.remove(request.getObjectName());target.getAsJsonObject("viewProperties").remove(request.getObjectName());}else{expressionDefinition(request.getDefinition());views.addProperty(request.getObjectName(),request.getDefinition());var dependencies=new com.google.gson.JsonArray();for(String reference:io.busystack.busydata.analysis.SqlParsing.tables(request.getDefinition(),session.profile.getEngine()))for(String candidate:views.keySet())if(reference.equals(candidate)||reference.equals(schema+"."+candidate)||reference.equals(session.adapter.table("",schema,candidate)))dependencies.add(candidate);target.getAsJsonObject("viewDependencies").add(request.getObjectName(),dependencies);}}
            case "routine"->{var routines=target.getAsJsonObject("routines");var routine=routines.getAsJsonObject(request.getObjectName());if(routine==null){if(request.getProperty().equals("drop"))throw new IllegalArgumentException("Choose a captured routine, including its full identity signature");return newRoutine(request,schema);}if(request.getProperty().equals("drop"))routines.remove(request.getObjectName());else{definition(request.getDefinition());if(routine.has("bindingUnavailable"))throw new IllegalArgumentException(routine.get("bindingUnavailable").getAsString());routine.addProperty("definition",DefinitionBinding.routine(session,schema,routine,request.getDefinition()));}}
            case "trigger"->{if(!SchemaDiff.triggerLookupAvailable(identifierEvidence))throw new IllegalArgumentException("Native trigger lookup is unsupported or unavailable for this captured server");var triggers=table.getAsJsonObject("triggers");if(request.getProperty().equals("drop"))triggers.remove(request.getObjectName());else{definition(request.getDefinition());triggers.addProperty(request.getObjectName(),DefinitionBinding.trigger(session,schema,request.getTable(),request.getObjectName(),request.getDefinition()));}}
            default->throw new IllegalArgumentException("Choose a supported object operation");
        }
        var plan=new SchemaDiff(session,identifierEvidence).compare(request.toBuilder().setSourceSnapshot(source.toString()).setTargetSnapshot(target.toString()).build());
        return plan.toBuilder().setSnapshot(target.toString()).addRisks("Designer changes retain unselected captured properties. Apply generated SQL through the normal reviewed execution command; generation does not execute it.").build();
    }
    private SchemaToolResult newRoutine(SchemaToolRequest request,String schema) {
        definition(request.getDefinition());identifier(request.getObjectName());
        var fragments=new io.busystack.busydata.analysis.SqlAnalysis().split(request.getDefinition(),session.profile.getEngine(),session.context.lexical());
        if(fragments.size()!=1)throw new IllegalArgumentException("Provide one complete CREATE FUNCTION or CREATE PROCEDURE definition; other statements require separate review");
        var tokens=io.busystack.busydata.analysis.SqlLexer.scan(fragments.getFirst().text(),session.profile.getEngine(),session.context.lexical()).stream().filter(t->t.kind()!=io.busystack.busydata.analysis.SqlLexer.Kind.COMMENT).toList();
        if(tokens.isEmpty()||!tokens.getFirst().is("CREATE")||tokens.stream().anyMatch(t->!t.complete()))throw new IllegalArgumentException("Provide a complete native CREATE routine definition");
        int kind=-1;for(int i=1;i<Math.min(tokens.size(),32);i++)if(tokens.get(i).is("FUNCTION")||tokens.get(i).is("PROCEDURE")){kind=i;break;}
        if(kind<0||kind+4>=tokens.size()||!tokens.get(kind+2).text().equals(".")||!identifierToken(tokens.get(kind+1)).equals(schema)||!identifierToken(tokens.get(kind+3)).equals(request.getObjectName())||!tokens.get(kind+4).text().equals("("))throw new IllegalArgumentException("Qualify the CREATE routine name with the inspected schema and exact new object name");
        return SchemaToolResult.newBuilder().setComplete(true).addSql(RoutineDefinitions.script(fragments.getFirst().text(),pg))
            .addRisks("Create the exact native routine in the inspected schema. Review its language, authentication/definer, search path, arguments, return type, and procedural/dynamic dependencies. Server validation is authoritative; creation does not promise universal dependency inference. MySQL/MariaDB DDL implicitly commits.").build();
    }
    private static String identifierToken(io.busystack.busydata.analysis.SqlLexer.Token token) {
        if(token.kind()==io.busystack.busydata.analysis.SqlLexer.Kind.WORD)return token.text();
        if(token.kind()==io.busystack.busydata.analysis.SqlLexer.Kind.IDENTIFIER&&token.complete()){String quote=token.text().substring(0,1);return token.text().substring(1,token.text().length()-1).replace(quote+quote,quote);}
        return "";
    }
    private SchemaToolResult newTable(SchemaToolRequest request,JsonObject current)throws Exception {
        String name=request.getObjectName(),schema=current.get("schema").getAsString();identifier(name);
        if(current.getAsJsonObject("tables").has(name)||current.getAsJsonObject("views").has(name))throw new IllegalArgumentException("Table or view already exists");
        if(request.getDesignedColumnsCount()<1||request.getDesignedColumnsCount()>128)throw new IllegalArgumentException("Choose 1–128 columns for the new table");
        var names=new LinkedHashSet<String>();var definitions=new ArrayList<String>();var comments=new ArrayList<String>();
        var primary=request.getObjectColumnsList();
        if(primary.size()>32||new HashSet<>(primary).size()!=primary.size())throw new IllegalArgumentException("Choose up to 32 unique primary-key columns in order");
        for(var column:request.getDesignedColumnsList()) {
            identifier(column.getName());if(!names.add(column.getName()))throw new IllegalArgumentException("Duplicate column name");
            String ddl=session.adapter.quote(column.getName())+" "+type(column.getType());
            int generation=(column.getDefaultExpression().isEmpty()?0:1)+(column.getIdentity().isEmpty()?0:1)+(column.getGeneratedExpression().isEmpty()?0:1);
            if(generation>1)throw new IllegalArgumentException("A column can have a default, identity, or generated expression");
            if(!column.getCollation().isEmpty()){if(!column.getCollation().matches("[A-Za-z0-9_]{1,128}"))throw new IllegalArgumentException("Choose a named collation");ddl+=" COLLATE "+session.adapter.quote(column.getCollation());}
            if(!column.getIdentity().isEmpty()) {
                if(!Set.of("always","byDefault").contains(column.getIdentity()))throw new IllegalArgumentException("Choose always or byDefault identity");
                if(!pg&&(!column.getIdentity().equals("byDefault")||!primary.contains(column.getName())))throw new IllegalArgumentException("MySQL/MariaDB auto-increment requires a keyed column and by-default generation");
                ddl+=pg?" GENERATED "+(column.getIdentity().equals("always")?"ALWAYS":"BY DEFAULT")+" AS IDENTITY":" AUTO_INCREMENT";
            }else if(!column.getGeneratedExpression().isEmpty()){expression(column.getGeneratedExpression());ddl+=" GENERATED ALWAYS AS ("+column.getGeneratedExpression()+") STORED";}
            else if(!column.getDefaultExpression().isEmpty()){expression(column.getDefaultExpression());ddl+=" DEFAULT "+column.getDefaultExpression();}
            if(!column.getNullable())ddl+=" NOT NULL";
            if(column.getComment().length()>4096)throw new IllegalArgumentException("Column comment exceeds 4096 characters");
            if(!column.getComment().isEmpty()) {if(pg)comments.add("COMMENT ON COLUMN "+session.adapter.table("",schema,name)+"."+session.adapter.quote(column.getName())+" IS "+string(column.getComment())+";");else ddl+=" COMMENT "+string(column.getComment());}
            definitions.add(ddl);
        }
        if(!names.containsAll(primary))throw new IllegalArgumentException("Primary-key columns must exist in the new table");
        if(!primary.isEmpty())definitions.add("PRIMARY KEY ("+String.join(",",primary.stream().map(session.adapter::quote).toList())+")");
        String sql="CREATE TABLE "+session.adapter.table("",schema,name)+" (\n  "+String.join(",\n  ",definitions)+"\n);";
        return SchemaToolResult.newBuilder().setComplete(true).addSql(sql).addAllSql(comments)
            .addRisks("Create a new table with the reviewed columns and primary key. Server defaults determine unselected storage properties; inspect the created object before further changes. MySQL/MariaDB DDL implicitly commits.").build();
    }
    private void identifier(String name){session.adapter.quote(name);if(pg&&name.getBytes(java.nio.charset.StandardCharsets.UTF_8).length>63||!pg&&name.codePointCount(0,name.length())>64)throw new IllegalArgumentException("Identifier exceeds this engine’s limit");}
    private String string(String value){return (pg?"E":"")+"'"+((pg||!session.context.lexical().noBackslashEscapes())?value.replace("\\","\\\\"):value).replace("'","''")+"'";}
    private void column(SchemaToolRequest request,JsonObject table)throws Exception{
        var columns=table.getAsJsonObject("columns");String name=request.getColumn();session.adapter.quote(name);
        if(request.getOperation().equals("drop")){if(!columns.has(name))throw new IllegalArgumentException("Column does not exist");columns.remove(name);return;}
        var column=columns.getAsJsonObject(name);
        if(request.getOperation().equals("add")){
            if(column!=null)throw new IllegalArgumentException("Column already exists");String type=type(request.getType());
            column=new JsonObject();column.addProperty("type",type);column.addProperty("nullable",request.getNullable());column.add("default",JsonNull.INSTANCE);column.addProperty("special","");column.addProperty("generated","");column.addProperty("ordinal",columns.size()+1);
            column.addProperty("comment","");column.addProperty("collation","");
            String nativeDefinition=session.adapter.quote(name)+" "+type;
            if(request.getProperty().equals("generated")){expression(request.getValue());if(request.getValue().isEmpty())throw new IllegalArgumentException("Provide a generated expression");column.addProperty("generated",pg?"s":request.getValue());if(pg)column.addProperty("default",request.getValue());nativeDefinition+=" GENERATED ALWAYS AS ("+request.getValue()+") STORED";}
            else if(request.getProperty().equals("identity")){if(!Set.of("always","byDefault").contains(request.getValue()))throw new IllegalArgumentException("Choose an identity generation mode");column.addProperty("special",pg?(request.getValue().equals("always")?"a":"d"):"auto_increment");nativeDefinition+=pg?" GENERATED "+(request.getValue().equals("always")?"ALWAYS":"BY DEFAULT")+" AS IDENTITY":" AUTO_INCREMENT";}
            else if(request.getProperty().equals("default")){expression(request.getValue());if(!request.getValue().isEmpty()){column.addProperty("default",request.getValue());nativeDefinition+=" DEFAULT "+request.getValue();}}
            if(!request.getNullable())nativeDefinition+=" NOT NULL";
            if(!pg)column.addProperty("definition",nativeDefinition);columns.add(name,column);return;
        }
        if(column==null)throw new IllegalArgumentException("Column does not exist");String property=request.getProperty(),value=request.getValue();
        switch(property){
            case "type"->{value=type(value);column.addProperty("type",value);}
            case "nullable"->{if(!Set.of("true","false").contains(value))throw new IllegalArgumentException("Choose nullable or NOT NULL");column.addProperty("nullable",Boolean.parseBoolean(value));}
            case "default"->{expression(value);if(!text(column,"generated").isBlank()||!text(column,"special").isBlank()&&pg)throw new IllegalArgumentException("Generated/identity columns cannot receive an ordinary default");if(value.isEmpty())column.add("default",JsonNull.INSTANCE);else column.addProperty("default",value);}
            case "generated"->{expression(value);column.addProperty("generated",pg?(value.isEmpty()?"":"s"):value);if(pg){if(value.isEmpty())column.add("default",JsonNull.INSTANCE);else column.addProperty("default",value);}}
            case "identity"->{if(!Set.of("none","always","byDefault").contains(value))throw new IllegalArgumentException("Choose none, always, or by default");column.addProperty("special",pg?(value.equals("always")?"a":value.equals("byDefault")?"d":""):value.equals("none")?"":"auto_increment");}
            case "comment"->{if(value.length()>4096)throw new IllegalArgumentException("Comment exceeds 4096 characters");column.addProperty("comment",value);}
            case "collation"->{if(!value.isEmpty()){if(!value.matches("[A-Za-z0-9_]{1,128}"))throw new IllegalArgumentException("Choose a named collation");if(pg)try(var statement=session.connection.prepareStatement("SELECT quote_ident(n.nspname)||'.'||quote_ident(c.collname) FROM pg_collation c JOIN pg_namespace n ON n.oid=c.collnamespace WHERE c.collname=? AND n.nspname=ANY(current_schemas(true)) ORDER BY array_position(current_schemas(true),n.nspname) LIMIT 1")){statement.setString(1,value);try(var rows=statement.executeQuery()){if(!rows.next())throw new IllegalArgumentException("Collation not found in the current search path");value=rows.getString(1);}}}column.addProperty("collation",value);}
            default->throw new IllegalArgumentException("Choose a supported column property");
        }
        if(!pg){if(!column.has("definition"))throw new IllegalArgumentException("Native column definition unavailable");column.addProperty("definition",ColumnDdl.change(column.get("definition").getAsString(),property,value,session.context.lexical().noBackslashEscapes()));}
    }
    private void index(SchemaToolRequest request,JsonObject table,String schema){
        String name=request.getObjectName();session.adapter.quote(name);var indexes=table.getAsJsonObject("indexes");
        if(request.getProperty().equals("drop")){if(!indexes.has(name))throw new IllegalArgumentException("Choose an independent index; constraint-backed indexes belong to their constraint");indexes.remove(name);return;}
        if(indexes.has(name)||SchemaConstraints.hasName(table,name))throw new IllegalArgumentException("Index or constraint name already exists");String columns=columns(request.getObjectColumnsList(),table);
        indexes.addProperty(name,pg?"CREATE "+(request.getUnique()?"UNIQUE ":"")+"INDEX "+session.adapter.quote(name)+" ON "+session.adapter.table("",schema,request.getTable())+" ("+columns+")":(request.getUnique()?"UNIQUE KEY ":"KEY ")+session.adapter.quote(name)+" ("+columns+")");
    }
    private void constraint(SchemaToolRequest request,JsonObject table,String schema)throws Exception{
        var constraints=table.getAsJsonObject("constraints");String name=request.getObjectName();session.adapter.quote(name);String kind=request.getObjectKind();
        String type=SchemaConstraints.type(session.profile.getEngine(),kind);
        if(request.getProperty().equals("drop")){
            String selected=request.getIdentifier().isEmpty()?type:request.getIdentifier();var found=SchemaConstraints.find(table,name,selected);
            if(found==null||!selected.equals(type))throw new IllegalArgumentException("Choose the exact constraint name and native type");
            if(SchemaConstraints.kind(type).equals("f")&&!SchemaConstraints.foreignKeyDropsUnambiguous(table,identifierEvidence))throw new IllegalArgumentException("Native foreign-key DROP identity is unavailable or ambiguous");
            constraints.remove(SchemaConstraints.key(name,selected));return;
        }
        if(pg?SchemaConstraints.hasName(table,name):constraints.has(SchemaConstraints.key(name,type)))throw new IllegalArgumentException("Constraint name/type already exists");
        String body=switch(kind){
            case "primary"->"PRIMARY KEY ("+columns(request.getObjectColumnsList(),table)+")";
            case "unique"->"UNIQUE ("+columns(request.getObjectColumnsList(),table)+")";
            case "check"->{expression(request.getExpression());if(request.getExpression().isEmpty())throw new IllegalArgumentException("Provide a CHECK expression");yield "CHECK ("+request.getExpression()+")";}
            case "foreign"->{if(request.getReferenceColumnsCount()!=request.getObjectColumnsCount()||request.getObjectColumnsCount()==0)throw new IllegalArgumentException("Foreign-key mappings must have equal nonempty column lists");yield "FOREIGN KEY ("+columns(request.getObjectColumnsList(),table)+") REFERENCES "+session.adapter.table("",request.getReferenceSchema().isEmpty()?schema:request.getReferenceSchema(),request.getReferenceTable())+" ("+String.join(",",request.getReferenceColumnsList().stream().map(session.adapter::quote).toList())+")"+foreignPolicy(request);}
            default->throw new IllegalArgumentException("Choose primary, unique, check, or foreign key");
        };
        SchemaConstraints.put(constraints,name,type,"CONSTRAINT "+session.adapter.quote(name)+" "+body);
    }
    private String foreignPolicy(SchemaToolRequest request) {
        StringBuilder policy=new StringBuilder();
        for(var item:List.of(Map.entry("DELETE",request.getOnDelete()),Map.entry("UPDATE",request.getOnUpdate())))if(!item.getValue().isEmpty()) {
            if(!Set.of("NO ACTION","RESTRICT","CASCADE","SET NULL","SET DEFAULT").contains(item.getValue())||!pg&&item.getValue().equals("SET DEFAULT"))throw new IllegalArgumentException("Choose a foreign-key action supported by this engine");
            policy.append(" ON ").append(item.getKey()).append(" ").append(item.getValue());
        }
        if(request.getDeferrable()||request.getInitiallyDeferred()) {
            if(!pg)throw new IllegalArgumentException("MySQL/MariaDB foreign keys do not support deferred checking");
            if(!request.getDeferrable())throw new IllegalArgumentException("Initially deferred requires a deferrable constraint");
            policy.append(" DEFERRABLE").append(request.getInitiallyDeferred()?" INITIALLY DEFERRED":" INITIALLY IMMEDIATE");
        }
        return policy.toString();
    }
    private String columns(List<String> names,JsonObject table){if(names.isEmpty()||names.size()>32||new HashSet<>(names).size()!=names.size()||!table.getAsJsonObject("columns").keySet().containsAll(names))throw new IllegalArgumentException("Choose 1–32 unique existing columns in order");return String.join(",",names.stream().map(session.adapter::quote).toList());}
    private String type(String value){String type=value.strip().toLowerCase(Locale.ROOT);if(!type.matches("(?:tinyint|smallint|mediumint|integer|int|bigint|real|double(?: precision)?|float|boolean|bool|text|tinytext|mediumtext|longtext|json|jsonb|uuid|date|year|time(?:\\([0-6]\\))?(?: (?:with|without) time zone)?|timestamp(?:\\([0-6]\\))?(?: (?:with|without) time zone)?|datetime(?:\\([0-6]\\))?|interval|bytea|tinyblob|mediumblob|longblob|blob|(?:var)?binary\\([1-9][0-9]{0,5}\\)|(?:var)?char\\([1-9][0-9]{0,5}\\)|(?:decimal|numeric)\\([1-9][0-9]?(?:,[0-9]{1,2})?\\))(?: unsigned)?"))throw new IllegalArgumentException("Choose a supported built-in type; existing unselected types remain intact");if(pg&&type.endsWith(" unsigned"))throw new IllegalArgumentException("PostgreSQL does not have unsigned column types");return type;}
    private void expression(String value)throws Exception{if(value.isEmpty())return;if(value.length()>4096)throw new IllegalArgumentException("Expression exceeds 4096 characters");io.busystack.busydata.analysis.SqlParsing.expression(value,session.profile.getEngine(),session.context.lexical());}
    private void expressionDefinition(String value)throws Exception{definition(value);var statement=io.busystack.busydata.analysis.SqlParsing.parse(value,session.profile.getEngine(),session.context.lexical());if(!(statement instanceof net.sf.jsqlparser.statement.select.Select))throw new IllegalArgumentException("View definition must contain one SELECT");}
    private static void definition(String value){if(value.isBlank()||value.length()>65_536||value.indexOf('\0')>=0)throw new IllegalArgumentException("Provide a nonempty native definition at most 64Ki UTF-16 units");}
    private static String text(JsonObject value,String property){return !value.has(property)||value.get(property).isJsonNull()?"":value.get(property).getAsString();}
}
