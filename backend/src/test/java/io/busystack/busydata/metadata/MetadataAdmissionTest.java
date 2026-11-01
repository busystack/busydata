package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class MetadataAdmissionTest {
    private static MetadataObject object(int index){var identity=new MetadataIdentity("source","profile","db","public",ObjectKind.VIEW,ObjectSubtype.REGULAR_VIEW,"","v"+index,"","");return new MetadataObject(identity,identity.name(),identity.name(),identity.name(),Map.of(),"x".repeat(65536),IntrospectionLevel.SOURCE,MetadataState.AVAILABLE,1,1);}
    @Test void concurrentAcquisitionsShareOneBudgetAndFailureReleasesAdmission(){
        var platform=new MetadataPlatform();var first=platform.admitAcquisition();int admitted=0;
        try(var second=platform.admitAcquisition()){
            for(int index=0;index<860;index++)first.reserve(object(index));
            for(int index=0;index<860;index++)try{second.reserve(object(index+860));admitted++;}catch(IllegalStateException limit){break;}
            assertTrue(admitted>0&&admitted<860,"A second independent large catalog must be rejected while its native branches are acquired");
            assertThrows(IllegalStateException.class,()->second.reserve(object(2000)));
            first.close();assertDoesNotThrow(()->second.reserve(object(2001)));
        }finally{first.close();}
        try(var fresh=platform.admitAcquisition()){for(int index=0;index<860;index++)fresh.reserve(object(index));}
    }
}
