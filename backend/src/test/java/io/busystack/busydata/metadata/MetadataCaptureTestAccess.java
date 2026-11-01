package io.busystack.busydata.metadata;

import io.busystack.busydata.sessions.SessionRegistry;
import java.lang.reflect.Field;
import java.util.Map;

/** Test-only observation of real published owners. Never creates or replaces a
 * source/overlay, changes its clock, or injects a production acquisition hook. */
public final class MetadataCaptureTestAccess {
    private MetadataCaptureTestAccess(){}
    private static Map<?,?> owners(MetadataPlatform platform,String name)throws Exception {
        Field field=MetadataPlatform.class.getDeclaredField(name);field.setAccessible(true);return (Map<?,?>)field.get(platform);
    }
    public static Object sourceMonitor(MetadataPlatform platform,SessionRegistry.Session owner)throws Exception {
        var source=owners(platform,"sources").get(owner.metadataSourceIdentity);
        if(!(source instanceof MetadataPlatform.Source))throw new IllegalStateException("No actual metadata source was published");return source;
    }
    public static Object overlayOwner(MetadataPlatform platform,SessionRegistry.Session owner)throws Exception {
        var overlay=owners(platform,"overlays").get(owner.id);if(overlay==null)throw new IllegalStateException("No actual metadata overlay was published");return overlay;
    }
    public static boolean coverageOnlyRebase(MetadataSnapshot overlay,MetadataSnapshot durable){return overlay.composed()&&overlay.canRebaseCoverageOnto(durable);}
}
