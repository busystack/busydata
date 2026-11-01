package io.busystack.busydata.schema;

import io.busystack.busydata.adapters.JdbcAdapter;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.analysis.SqlAnalysis;
import io.busystack.busydata.safety.Safety;
import java.util.List;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

/** Approval evidence is a captured owner, independent of later model lookups. */
class TableBrowseFingerprintTest {
    private static final Profile PROFILE=Profile.newBuilder().setId("profile").setEngine(Engine.POSTGRESQL).setDatabase("database").build();
    private static final JdbcAdapter.LiveContext CONTEXT=new JdbcAdapter.LiveContext("database","public",List.of("public"),"");
    private static TableBrowse.Binding binding(long session,long context,String source,long generation,long metadata,long configuration){return new TableBrowse.Binding(null,PROFILE,CONTEXT,session,context,source,generation,metadata,configuration);}
    private static final TableBrowse.Binding OWNER=binding(7,3,"source",5,11,2);
    private static BrowseRequest request(){return BrowseRequest.newBuilder().setSessionId("physical-session").setDocumentId("document-owner").setCatalog("database").setSchema("public").setTable("selected").setRowLimit(100).setMetadataSnapshotRevision(11).setMetadataObjectIdentity("table-id").setOriginRelationshipIdentity("relationship-id").setOriginResultId("retained-result").setOriginSourceRow(4).addConditions(RowCondition.newBuilder().setColumn("id").setPredicate(ValuePredicate.EQUAL).setValue(Value.newBuilder().setSignedInteger("17"))).build();}
    @Test void aRecreatedSourceCannotReuseAnOldApprovalAtTheSameSnapshotNumber()throws Exception {
        var safety=new Safety(new SqlAnalysis());var request=request();String old=TableBrowse.fingerprint(request,OWNER,"");String token=safety.issue(old);
        assertThrows(IllegalArgumentException.class,()->safety.consume(token,TableBrowse.fingerprint(request,binding(7,3,"source",6,11,2),"")));
    }
    @Test void everyCapturedRevisionAndSourceRemainsPartOfTheReviewedOwner()throws Exception {
        String expected=TableBrowse.fingerprint(request(),OWNER,"");
        for(var changed:List.of(binding(8,3,"source",5,11,2),binding(7,4,"source",5,11,2),binding(7,3,"other-source",5,11,2),binding(7,3,"source",5,12,2),binding(7,3,"source",5,11,3)))assertNotEquals(expected,TableBrowse.fingerprint(request(),changed,""));
    }
    @Test void documentResultRowAndTypedPredicateCannotBeReboundByAnApproval()throws Exception {
        var original=request();String expected=TableBrowse.fingerprint(original,OWNER,"");
        for(var changed:List.of(original.toBuilder().setDocumentId("other-document").build(),original.toBuilder().setSessionId("other-session").build(),original.toBuilder().setOriginResultId("other-result").build(),original.toBuilder().setOriginSourceRow(5).build(),original.toBuilder().setMetadataObjectIdentity("other-table-id").build(),original.toBuilder().setRowLimit(101).build(),original.toBuilder().setConditions(0,original.getConditions(0).toBuilder().setValue(Value.newBuilder().setSignedInteger("18"))).build()))assertNotEquals(expected,TableBrowse.fingerprint(changed,OWNER,""));
    }
    @Test void transportNoncesDoNotReplaceCapturedReviewEvidence()throws Exception {
        var original=request();var submitted=original.toBuilder().setContext(Context.newBuilder().setRequestId("new-rpc")).setApprovalToken("opaque-token").setExecutionId("new-execution").build();
        assertEquals(TableBrowse.fingerprint(original,OWNER,""),TableBrowse.fingerprint(submitted,OWNER,""));
    }
}
