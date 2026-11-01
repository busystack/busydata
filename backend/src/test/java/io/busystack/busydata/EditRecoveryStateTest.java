package io.busystack.busydata;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.storage.MetadataStore;
import java.nio.file.Path;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;
class EditRecoveryStateTest {
 @TempDir Path root;
 @Test void crashDuringApplicationProhibitsReplayAndDoesNotRestoreAnySession()throws Exception{
  String id;
  try(var store=new MetadataStore(root)){
   id=store.saveEditDraft("",StoredEditDraft.newBuilder().setDocumentId("document").setSourceSql("SELECT id FROM rows").build());
   store.editDraftState(id,"STAGED","APPLYING");assertThrows(IllegalStateException.class,()->store.deleteEditDraft(id));
  }
  try(var store=new MetadataStore(root)){
   assertEquals("UNKNOWN_OUTCOME",store.editDraft(id).state());
   assertThrows(IllegalStateException.class,()->store.saveEditDraft(id,StoredEditDraft.getDefaultInstance()));
   store.deleteEditDraft(id);assertTrue(store.editDrafts().isEmpty());
  }
 }
 @Test void recoveryQuotasRejectReplacementWithoutLosingExistingWork()throws Exception{
  try(var store=new MetadataStore(root)){
   String id=store.saveEditDraft("",StoredEditDraft.newBuilder().setDocumentId("preserved").build());
   assertThrows(IllegalArgumentException.class,()->store.saveEditDraft(id,StoredEditDraft.newBuilder().setSourceSql("x".repeat(1048576)).build()));
   assertEquals("preserved",store.editDraft(id).data().getDocumentId());
  }
 }
}
