package io.busystack.busydata;
import com.google.gson.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.administration.PrivilegeTools;
import java.nio.file.Path;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;
class RoleInheritanceIT {
 @TempDir Path root;
 @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
 void inspectionUsesActualInheritedRolesAndDefaultActivation(String engine)throws Exception {
  try(var f=new EngineFixture(root,engine)) {
   var s=f.open();f.execute(s,"CREATE TABLE role_evidence(id INTEGER PRIMARY KEY)");
   f.execute(s,f.engine==Engine.POSTGRESQL?"CREATE ROLE inherited_reader;CREATE ROLE selected_reader LOGIN;GRANT SELECT ON role_evidence TO inherited_reader;GRANT inherited_reader TO selected_reader":f.engine==Engine.MYSQL?"CREATE ROLE 'inherited_reader'@'%';CREATE USER 'selected_reader'@'%';GRANT SELECT ON role_evidence TO 'inherited_reader'@'%';GRANT 'inherited_reader'@'%' TO 'selected_reader'@'%'":"CREATE ROLE inherited_reader;CREATE USER 'selected_reader'@'%';GRANT SELECT ON role_evidence TO inherited_reader;GRANT inherited_reader TO 'selected_reader'@'%'");
   var principal=Principal.newBuilder().setName("selected_reader").setHost(f.engine==Engine.POSTGRESQL?"":"%").build();
   var tools=new PrivilegeTools();var inspection=tools.run(s,PrivilegeRequest.newBuilder().setGrantee(principal).build());
   var data=JsonParser.parseString(inspection.getDefinition()).getAsJsonObject();assertTrue(data.getAsJsonArray("inheritedRoles").toString().contains("inherited_reader"));
   if(f.engine==Engine.POSTGRESQL) {
    var tables=data.getAsJsonArray("effectiveCurrentDatabaseTables");assertTrue(tables.asList().stream().map(JsonElement::getAsJsonObject).anyMatch(t->t.get("relname").getAsString().equals("role_evidence")&&t.get("can_select").getAsBoolean()));
   }else {
    var role=Principal.newBuilder().setName("inherited_reader").setHost(f.engine==Engine.MYSQL?"%":"").build();
    var request=PrivilegeRequest.newBuilder().setAction(PrivilegeAction.DESIGN_PRIVILEGE).setGrantee(principal).setRole(role).setScope(PrivilegeScope.DEFAULT_ROLE).build();
    f.execute(s,String.join("\n",tools.run(s,request).getSqlList()));
    data=JsonParser.parseString(tools.run(s,PrivilegeRequest.newBuilder().setGrantee(principal).build()).getDefinition()).getAsJsonObject();assertTrue(data.getAsJsonArray("defaultRoles").toString().contains("inherited_reader"));
    f.execute(s,String.join("\n",tools.run(s,request.toBuilder().setRevoke(true).clearRole().build()).getSqlList()));
    data=JsonParser.parseString(tools.run(s,PrivilegeRequest.newBuilder().setGrantee(principal).build()).getDefinition()).getAsJsonObject();assertFalse(data.getAsJsonArray("defaultRoles").toString().contains("inherited_reader"));
   }
   assertFalse(inspection.getDefinition().contains("authentication_string"));assertFalse(inspection.getDefinition().contains("fixture"));
  }
 }
}
