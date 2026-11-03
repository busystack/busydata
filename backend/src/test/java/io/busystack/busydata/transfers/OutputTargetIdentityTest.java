package io.busystack.busydata.transfers;

import java.nio.file.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

/** Real platform identities: the Windows provider may return a null Java file key. */
class OutputTargetIdentityTest {
    @TempDir Path root;

    @Test void renamedEntryKeepsIdentityAndEveryQueryReleasesItsHandle()throws Exception {
        Path source=root.resolve("original.csv"),renamed=root.resolve("renamed.csv");
        Files.writeString(source,"exact output");
        var identity=OutputTarget.entryIdentity(source);assertNotNull(identity);assertEquals("file",identity.kind());
        for(int i=0;i<16;i++)assertEquals(identity,OutputTarget.entryIdentity(source));
        Files.move(source,renamed);
        assertNull(OutputTarget.entryIdentity(source));assertEquals(identity,OutputTarget.entryIdentity(renamed));
        Files.delete(renamed);assertNull(OutputTarget.entryIdentity(renamed));
        Path parent=root.resolve("parent"),moved=root.resolve("moved");Files.createDirectory(parent);
        var directory=OutputTarget.entryIdentity(parent);assertEquals("directory",directory.kind());
        Files.move(parent,moved);assertEquals(directory,OutputTarget.entryIdentity(moved));Files.delete(moved);
    }

    @Test void identicalBytesAndTimestampDoNotApproveAReplacementEntry()throws Exception {
        Path target=root.resolve("output.csv"),original=root.resolve("original.csv");Files.writeString(target,"same bytes");
        var time=Files.getLastModifiedTime(target);var entry=OutputTarget.entryIdentity(target);String reviewed=OutputTarget.identity(target);
        Files.move(target,original);Files.writeString(target,"same bytes");Files.setLastModifiedTime(target,time);
        assertNotEquals(entry,OutputTarget.entryIdentity(target));assertNotEquals(reviewed,OutputTarget.identity(target));
        assertThrows(java.io.IOException.class,()->OutputCommit.open(target,true,reviewed));
        assertEquals("same bytes",Files.readString(target));assertEquals("same bytes",Files.readString(original));
    }

    @Test void aReplacementParentCannotReuseAnApprovalForIdenticalOutput()throws Exception {
        Path parent=root.resolve("selected"),retained=root.resolve("retained");Files.createDirectory(parent);
        Path target=parent.resolve("output.csv");Files.writeString(target,"same bytes");
        String reviewed=OutputTarget.identity(target);var entry=OutputTarget.entryIdentity(target);
        Files.move(parent,retained);Files.createDirectory(parent);Files.writeString(target,"same bytes");
        assertNotEquals(reviewed,OutputTarget.identity(target));assertNotEquals(entry,OutputTarget.entryIdentity(target));
        assertThrows(java.io.IOException.class,()->OutputCommit.open(target,true,reviewed));
        assertEquals("same bytes",Files.readString(retained.resolve("output.csv")));assertEquals("same bytes",Files.readString(target));
    }
}
