package io.busystack.busydata.metadata;

import java.util.concurrent.atomic.AtomicLong;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

/** Private in-memory identity tokens never wrap into a previously valid owner. */
class MetadataOwnedRecordTokenTest {
    @Test void distinctOwnersHaveStrictlyIncreasingNonzeroTokens(){
        var owners=new AtomicLong();
        long first=MetadataPlatform.nextOwnedRecordOwner(owners),second=MetadataPlatform.nextOwnedRecordOwner(owners);
        assertTrue(first>0);assertTrue(second>first);assertNotEquals(first,second);
    }
    @Test void exhaustionFailsWithoutWrappingOrReusingAnOwner(){
        var owners=new AtomicLong(Long.MAX_VALUE-1);
        assertEquals(Long.MAX_VALUE,MetadataPlatform.nextOwnedRecordOwner(owners));
        assertThrows(IllegalStateException.class,()->MetadataPlatform.nextOwnedRecordOwner(owners));
        assertEquals(Long.MAX_VALUE,owners.get());
        assertThrows(IllegalStateException.class,()->MetadataPlatform.nextOwnedRecordOwner(owners));
        assertEquals(Long.MAX_VALUE,owners.get());
    }
}
