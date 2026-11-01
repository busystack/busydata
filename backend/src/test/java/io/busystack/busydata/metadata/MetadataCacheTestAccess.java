package io.busystack.busydata.metadata;

import io.busystack.busydata.sessions.SessionRegistry;
import java.util.Map;

/** Test-only access to the existing absolute-deadline publication operation. */
public final class MetadataCacheTestAccess {
    private MetadataCacheTestAccess(){}
    /** Wait for this exact terminal receipt; the native attempt keeps its
     * original deadline and is never replayed by this test-only operation. */
    public static MetadataRepository.WriteMetrics await(MetadataRepository.WriteReceipt receipt)throws java.sql.SQLException{
        return receipt.await(System.nanoTime()+java.util.concurrent.TimeUnit.SECONDS.toNanos(30));
    }
    @FunctionalInterface public interface OpenSqlite {
        java.sql.Connection open(java.nio.file.Path file,java.util.Properties options)throws java.sql.SQLException;
    }
    public static MetadataPlatform platform(io.busystack.busydata.storage.MetadataStore storage,OpenSqlite connections)throws Exception{
        return new MetadataPlatform(storage,new MetadataRepository(storage.root(),connections::open));
    }
    public static MetadataSnapshot publish(MetadataPlatform platform,SessionRegistry.Session owner,MetadataPlatform.RefreshReservation reservation,IdentifierRules rules,Map<MetadataScope,MetadataPlatform.Branch> branches,long deadline)throws Exception{
        return platform.publish(owner,reservation,rules,branches,null,deadline,null);
    }
}
