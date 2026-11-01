package io.busystack.busydata.storage;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.Assignments;
import java.sql.Connection;
import java.util.ArrayList;

/** One-way migration of schema-2 durable drafts, never a runtime wire fallback. */
final class EditAssignmentMigration {
    private EditAssignmentMigration() {}
    static void migrate(Connection connection)throws Exception {
        try(var check=connection.createStatement();var rows=check.executeQuery("SELECT 1 FROM migration WHERE version=3")){if(rows.next())return;}
        if(connection.getAutoCommit())throw new IllegalStateException("Edit migration requires its initialization transaction");
        record Draft(String id,byte[] payload){}
        var drafts=new ArrayList<Draft>();long total=0;
        try(var statement=connection.createStatement();var rows=statement.executeQuery("SELECT id,payload FROM edit_drafts")){
            while(rows.next()){
                byte[] bytes=rows.getBytes(2);total+=bytes.length;
                if(drafts.size()>=32||bytes.length>1_048_576||total>8_388_608)throw new IllegalStateException("Edit migration budget exceeded; drafts preserved");
                var stored=StoredEditDraft.parseFrom(bytes).toBuilder();var changes=stored.getChanges().toBuilder();
                for(int i=0;i<changes.getChangesCount();i++) {
                    var change=changes.getChanges(i).toBuilder();
                    for(var entry:change.getUnknownFields().getField(2).getLengthDelimitedList()) {
                        var input=entry.newCodedInput();int ordinal=0;Value value=null;
                        for(int tag;(tag=input.readTag())!=0;){
                            if(tag==8)ordinal=input.readUInt32();
                            else if(tag==18)value=Value.parseFrom(input.readBytes());
                            else if(!input.skipField(tag))break;
                        }
                        if(ordinal<1||value==null||change.containsValues(ordinal))throw new IllegalStateException("Invalid legacy draft assignment; record preserved");
                        change.putValues(ordinal,Assignments.value(value));
                    }
                    change.setUnknownFields(change.getUnknownFields().toBuilder().clearField(2).build());changes.setChanges(i,change);
                }
                drafts.add(new Draft(rows.getString(1),stored.setChanges(changes).build().toByteArray()));
            }
        }
        try(var update=connection.prepareStatement("UPDATE edit_drafts SET payload=? WHERE id=?")){
            for(var draft:drafts){update.setBytes(1,draft.payload());update.setString(2,draft.id());update.addBatch();}update.executeBatch();
        }
        try(var statement=connection.createStatement()){statement.executeUpdate("INSERT INTO migration VALUES(3)");}
    }
}
