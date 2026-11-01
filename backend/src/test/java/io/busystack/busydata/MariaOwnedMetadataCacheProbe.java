package io.busystack.busydata;

import java.nio.file.*;

/** Isolated source-frozen before/after experiment using the exact native regression body. */
public final class MariaOwnedMetadataCacheProbe {
    private MariaOwnedMetadataCacheProbe(){}
    public static void main(String[] args)throws Exception{
        if(args.length!=3||!java.util.Set.of("creation","removal").contains(args[1]))throw new IllegalArgumentException("Expected private output, transition and level");
        int level=Integer.parseInt(args[2]);if(level<1||level>3)throw new IllegalArgumentException("Expected introspection level1..3");
        var test=new MariaOwnedMetadataCacheIT();test.root=Path.of(args[0]).toAbsolutePath().resolve("fixture");Files.createDirectories(test.root);
        test.ownedCreationAndRemovalFinishBeforeDurableCacheUnlock(args[1],level);
    }
}
