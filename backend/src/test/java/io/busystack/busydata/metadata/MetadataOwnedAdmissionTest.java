package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

/** Final composition allocation adopts exact normalization reservations once. */
class MetadataOwnedAdmissionTest {
    private static MetadataObject object(String name){return MetadataObject.from("source","profile","",new IdentifierRules(Engine.POSTGRESQL,0),SchemaObject.newBuilder().setCatalog("db").setSchema("public").setName(name).setKind(ObjectKind.TABLE).putProperties("type","integer").putProperties("nullable","NO").build(),IntrospectionLevel.STRUCTURE,1,1);}
    private static long pending(MetadataPlatform platform,MetadataPlatform.AcquisitionAdmission admission)throws Exception{var field=MetadataPlatform.class.getDeclaredField("acquisitions");field.setAccessible(true);return ((Map<?,?>)field.get(platform)).get(admission) instanceof Long bytes?bytes:0;}
    @Test void normalizedOwnedObjectsTransferTheirExistingReservationWithoutDoubleCharge()throws Exception{
        var platform=new MetadataPlatform();var object=object("normalized");try(var admission=platform.admitAcquisition()){
            admission.reserve(object);long first=pending(platform,admission);assertTrue(first>=object.estimatedBytes());admission.reserveOwnedObject(object);assertEquals(first,pending(platform,admission));
            long allocation=first+2048;admission.reserveComposition(allocation,List.of(object));assertEquals(allocation,pending(platform,admission));assertThrows(IllegalStateException.class,()->admission.reserveOwnedObject(object),"One prepared candidate cannot normalize additional facts after its transfer");admission.committed();assertEquals(0,pending(platform,admission));
        }
    }
    @Test void aLayoutSharedWithAnEarlierNoncandidateFactIsTransferredOnlyOnce()throws Exception{
        var platform=new MetadataPlatform();var unused=object("unused");var owned=object("owned");var one=(CompactProperties)unused.properties();var two=(CompactProperties)owned.properties();assertSame(one.layoutIdentity(),two.layoutIdentity());
        try(var admission=platform.admitAcquisition()){
            admission.reserve(unused);admission.reserve(owned);long before=pending(platform,admission);assertEquals(unused.estimatedBytes()+owned.estimatedBytes()+one.layoutBytes(),before);
            long allocation=owned.estimatedBytes()+one.layoutBytes()+2048;admission.reserveComposition(allocation,List.of(owned));assertEquals(unused.estimatedBytes()+allocation,pending(platform,admission),"Shared layout remains charged once while both original and candidate facts are retained");
        }
    }
    @Test void anEmptyCandidateCannotLoseUnconsumedAcquisitionReservations()throws Exception{
        var platform=new MetadataPlatform();var admission=platform.admitAcquisition();try{admission.reserve(object("not-in-candidate"));long before=pending(platform,admission);admission.reserveComposition(0,List.of());assertEquals(before,pending(platform,admission));}finally{admission.close();}assertEquals(0,pending(platform,admission));
    }
}
