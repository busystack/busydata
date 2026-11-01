package io.busystack.busydata;

import com.google.protobuf.CodedOutputStream;
import com.google.protobuf.ByteString;
import com.google.protobuf.UnknownFieldSet;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.Assignments;
import io.busystack.busydata.storage.MetadataStore;
import java.io.ByteArrayOutputStream;
import java.nio.file.Path;
import java.sql.DriverManager;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

class EditAssignmentsTest {
    @TempDir Path root;
    @Test void nullDefaultAndUnsetAreDistinctAndDefaultIsNeverABoundString(){
        assertNotEquals(Assignments.defaultValue(),Assignments.nullValue());
        assertEquals(ValueAssignment.AssignmentCase.ASSIGNMENT_NOT_SET,ValueAssignment.getDefaultInstance().getAssignmentCase());
        assertEquals("DEFAULT",Assignments.bound(Assignments.value(Value.newBuilder().setText("DEFAULT").build())).getText());
        assertThrows(IllegalArgumentException.class,()->Assignments.bound(Assignments.defaultValue()));
        assertThrows(IllegalArgumentException.class,()->Assignments.value(Value.newBuilder().setText("preview").setTruncated(true).build()));
    }
    @Test void schemaTwoDraftValuesMigrateAtomicallyOnceWithoutChangingUserData()throws Exception {
        String id;
        try(var store=new MetadataStore(root)){
            store.save(Profile.newBuilder().setId("preserved").setName("User connection").build());
            id=store.saveEditDraft("",StoredEditDraft.newBuilder().setDocumentId("document").build());
        }
        var bytes=new ByteArrayOutputStream();var entry=CodedOutputStream.newInstance(bytes);entry.writeUInt32(1,2);entry.writeMessage(2,Value.newBuilder().setDecimal("9007199254740993.123456789").build());entry.flush();
        var old=StagedChange.newBuilder().setKind(ChangeKind.UPDATE).setSourceRow(7).setUnknownFields(UnknownFieldSet.newBuilder().addField(2,UnknownFieldSet.Field.newBuilder().addLengthDelimited(ByteString.copyFrom(bytes.toByteArray())).build()).build()).build();
        var stored=StoredEditDraft.newBuilder().setDocumentId("document").setChanges(ChangeRequest.newBuilder().setSessionId("old-session").addChanges(old)).build();
        try(var db=DriverManager.getConnection("jdbc:sqlite:"+root.resolve("metadata.sqlite"))){
            try(var statement=db.createStatement()){statement.executeUpdate("DELETE FROM migration WHERE version>=3");statement.execute("DROP TABLE metadata_source_identity");}
            try(var statement=db.prepareStatement("UPDATE edit_drafts SET payload=? WHERE id=?")){statement.setBytes(1,stored.toByteArray());statement.setString(2,id);statement.executeUpdate();}
        }
        for(int restart=0;restart<2;restart++)try(var store=new MetadataStore(root)){
            var change=store.editDraft(id).data().getChanges().getChanges(0);assertEquals(7,change.getSourceRow());assertEquals("9007199254740993.123456789",change.getValuesOrThrow(2).getValue().getDecimal());
            assertFalse(change.getUnknownFields().hasField(2));assertEquals("User connection",store.profiles().getFirst().getName());
        }
    }
}
