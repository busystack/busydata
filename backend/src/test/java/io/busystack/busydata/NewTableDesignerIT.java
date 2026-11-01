package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.SchemaTools;
import java.nio.file.Path;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;
class NewTableDesignerIT {
 @TempDir Path root;
 @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
 void typedNewTableDesignerAppliesIdentityDefaultsGeneratedColumnsAndComments(String engine)throws Exception {
  try(var f=new EngineFixture(root,engine)) {
   var s=f.open();var tools=new SchemaTools(f.metadata.metadataPlatform());var snapshot=tools.capture(s,f.schema());
   var request=SchemaToolRequest.newBuilder().setAction(SchemaToolAction.DESIGN_COLUMN).setSchema(f.schema()).setSourceSnapshot(snapshot.toString()).setOperation("table").setObjectName("Created 漢")
    .addDesignedColumns(DesignedColumn.newBuilder().setName("id").setType("integer").setIdentity(f.engine==Engine.POSTGRESQL?"always":"byDefault"))
    .addDesignedColumns(DesignedColumn.newBuilder().setName("n").setType("integer").setDefaultExpression("7"))
    .addDesignedColumns(DesignedColumn.newBuilder().setName("g").setType("integer").setGeneratedExpression("n+1").setNullable(true))
    .addDesignedColumns(DesignedColumn.newBuilder().setName("v").setType("varchar(80)").setDefaultExpression("'Unicode 漢'").setNullable(true).setComment("Keep 'quotes' and \\ slash"))
    .addObjectColumns("id").build();
   var plan=tools.run(s,request);assertTrue(plan.getComplete(),plan.toString());assertFalse(plan.getEquivalent());
   var applied=f.execute(s,String.join("\n",plan.getSqlList()));assertEquals(JobState.COMPLETED,applied.state,applied.info().toString());
   String table=s.adapter.table("",f.schema(),"Created 漢");f.execute(s,"INSERT INTO "+table+" (n) VALUES(9)");
   try(var statement=s.connection.createStatement();var row=statement.executeQuery("SELECT id,n,g,v FROM "+table)){assertTrue(row.next());assertEquals(1,row.getInt(1));assertEquals(9,row.getInt(2));assertEquals(10,row.getInt(3));assertEquals("Unicode 漢",row.getString(4));assertFalse(row.next());}
   var object=tools.capture(s,f.schema()).getAsJsonObject("tables").getAsJsonObject("Created 漢");
   assertEquals("Keep 'quotes' and \\ slash",object.getAsJsonObject("columns").getAsJsonObject("v").get("comment").getAsString());
   assertThrows(IllegalArgumentException.class,()->tools.run(s,request));
   if(f.engine!=Engine.POSTGRESQL) {
    f.execute(s,"SET sql_mode='NO_BACKSLASH_ESCAPES'");
    var next=request.toBuilder().setSourceSnapshot(tools.capture(s,f.schema()).toString()).setObjectName("No escapes").build();
    var noEscapes=tools.run(s,next);assertEquals(JobState.COMPLETED,f.execute(s,String.join("\n",noEscapes.getSqlList())).state);
    assertEquals("Keep 'quotes' and \\ slash",tools.capture(s,f.schema()).getAsJsonObject("tables").getAsJsonObject("No escapes").getAsJsonObject("columns").getAsJsonObject("v").get("comment").getAsString());
   }
  }
 }
}
