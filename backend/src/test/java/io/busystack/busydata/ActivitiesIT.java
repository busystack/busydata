package io.busystack.busydata;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.administration.Activities;
import java.nio.file.Path;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;
class ActivitiesIT {
 @TempDir Path root;
 @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
 void liveActivityIdentityMatchesTheActualConnectionAndRejectsChangedQueries(String engine)throws Exception {
  try(var f=new EngineFixture(root,engine)) {
   var source=f.open();var other=f.open();
   long id;try(var statement=other.connection.createStatement();var row=statement.executeQuery(f.engine==Engine.POSTGRESQL?"SELECT pg_backend_pid()":"SELECT CONNECTION_ID()")){assertTrue(row.next());id=row.getLong(1);}
   var activities=new Activities();var inspected=activities.list(source);
   var entry=inspected.getEntriesList().stream().filter(value->value.getId()==id).findFirst().orElseThrow();
   assertEquals("busydata",entry.getDatabase());assertFalse(entry.getFingerprint().isEmpty());
   assertEquals(id,source.metadata(view->activities.verify(view,id,entry.getFingerprint())).getId());
   try(var statement=other.connection.createStatement();var row=statement.executeQuery("SELECT 'new activity identity'")){assertTrue(row.next());}
   assertThrows(IllegalStateException.class,()->source.metadata(view->activities.verify(view,id,entry.getFingerprint())));
   assertTrue(activities.list(source).getSerializedSize()<=1048576);
   assertThrows(IllegalArgumentException.class,()->source.metadata(view->activities.verify(view,id,"")));
   f.sessions.close(other.id,true);
   assertThrows(IllegalStateException.class,()->source.metadata(view->activities.verify(view,id,entry.getFingerprint())));
  }
 }
}
