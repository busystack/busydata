package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import java.nio.file.Path;
import java.sql.Connection;
import java.util.concurrent.CopyOnWriteArrayList;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

/** Actual driver read deadlines must admit the selected SQL deadline and cancellation. */
class QuerySocketTimeoutIT {
    @TempDir Path root;

    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void selectedLongDeadlineRetainsBoundedReadsAndPromptCancellation(String engine)throws Exception {
        var opened=new CopyOnWriteArrayList<Connection>();
        try(var fixture=new EngineFixture(root,engine,(adapter,request,port)->{
            var connection=adapter.connect(request,port);opened.add(connection);return connection;
        })) {
            int[][] profiles={{0,300000},{60,300000},{1200,1205000},{3600,3605000}};
            for(var selected:profiles) {
                opened.clear();
                var request=OpenRequest.newBuilder().setProfile(fixture.profile.toBuilder()
                    .setQueryTimeoutSeconds(selected[0])).setPassword("fixture").build();
                var session=fixture.sessions.open(request);
                try {
                    assertEquals(selected[1],session.connection.getNetworkTimeout(),
                        "The official driver's physical read bound must preserve default behavior and admit the selected SQL deadline plus cancellation");
                    if(engine.equals("MYSQL"))assertEquals(300000,opened.get(1).getNetworkTimeout(),
                        "The independently owned cancellation connection keeps its original read bound");
                    int metadataTimeout=session.metadata(view->view.connection.getNetworkTimeout());
                    assertEquals(300000,metadataTimeout,
                        "Independent metadata views keep their original bounded transport");
                } finally {
                    fixture.sessions.close(session.id,true);
                }
            }
            CancellationControlIT.assertPromptCancellation(fixture.sessions,fixture.jobs,
                fixture.safety,fixture.results,OpenRequest.newBuilder()
                    .setProfile(fixture.profile.toBuilder().setQueryTimeoutSeconds(1200))
                    .setPassword("fixture").build());
        }
    }
}
