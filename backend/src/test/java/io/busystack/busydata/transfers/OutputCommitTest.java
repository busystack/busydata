package io.busystack.busydata.transfers;

import java.io.IOException;
import java.nio.file.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

class OutputCommitTest {
    @TempDir Path root;
    @ParameterizedTest @ValueSource(strings={"file","link","directory"})
    void lateEntryAtAbsentDestinationRemainsUntouched(String kind)throws Exception {
        Path target=root.resolve("output"),victim=root.resolve("victim");Files.writeString(victim,"victim");
        Object[] key=new Object[1];
        try(var output=OutputCommit.open(target,false,OutputTarget.identity(target),new OutputCommit.Faults(){
            public void beforePublish(Path t,Path partial)throws Exception {
                switch(kind){case "file"->Files.writeString(t,"late");case "link"->Files.createSymbolicLink(t,victim);case "directory"->{Files.createDirectory(t);Files.writeString(t.resolve("child"),"late");}}
                key[0]=OutputTarget.entryIdentity(t);
            }
        })) {Files.writeString(output.partial(),"output");assertThrows(IOException.class,output::commit);}
        assertEquals(key[0],OutputTarget.entryIdentity(target));
        if(kind.equals("file"))assertEquals("late",Files.readString(target));
        if(kind.equals("directory"))assertEquals("late",Files.readString(target.resolve("child")));
        if(kind.equals("link"))assertEquals(victim,Files.readSymbolicLink(target));
        assertEquals("victim",Files.readString(victim));assertNoPartials();
    }
    @Test void actualCancelledHashRestoresAndReleasesHandles()throws Exception {
        Path parent=Files.createDirectory(root.resolve("selected")),target=parent.resolve("output");Files.writeString(target,"reviewed");var original=OutputTarget.entryIdentity(target);
        try(var output=OutputCommit.open(target,true,OutputTarget.identity(target),new OutputCommit.Faults(){
            public void beforeVerify(Path recovery){Thread.currentThread().interrupt();}
        })) {Files.writeString(output.partial(),"output");try{assertThrows(java.io.InterruptedIOException.class,output::commit);}finally{Thread.interrupted();}}
        assertEquals(original,OutputTarget.entryIdentity(target));assertEquals("reviewed",Files.readString(target));
        Path moved=Files.move(parent,root.resolve("released-parent"));assertEquals(original,OutputTarget.entryIdentity(moved.resolve("output")));
        try(var entries=Files.list(moved)){assertEquals(1,entries.count());}assertNoPartials();
    }
    @Test void publicationFailureIntoVacancyRestoresOriginal()throws Exception {
        Path target=root.resolve("output");Files.writeString(target,"reviewed");var original=OutputTarget.entryIdentity(target);
        try(var output=OutputCommit.open(target,true,OutputTarget.identity(target),new OutputCommit.Faults(){
            public void beforePublish(Path t,Path partial)throws Exception{throw new AccessDeniedException("injected publication");}
        })) {Files.writeString(output.partial(),"output");assertThrows(AccessDeniedException.class,output::commit);}
        assertEquals(original,OutputTarget.entryIdentity(target));assertEquals("reviewed",Files.readString(target));assertNoPartials();
    }
    @Test void writerImmediatelyBeforeRestoreIsNotClobberedAndStagingIsCleaned()throws Exception {
        Path target=root.resolve("output");Files.writeString(target,"reviewed");var original=OutputTarget.entryIdentity(target);
        OutputCommit.RecoveryRequired failure;
        try(var output=OutputCommit.open(target,true,OutputTarget.identity(target),new OutputCommit.Faults(){
            public void beforeVerify(Path r)throws Exception{throw new IOException("verification failure");}
            public void beforeRestore(Path t,Path r)throws Exception{Files.writeString(t,"late writer");}
        })) {Files.writeString(output.partial(),"output");failure=assertThrows(OutputCommit.RecoveryRequired.class,output::commit);}
        assertFalse(failure.published);assertEquals("late writer",Files.readString(target));
        assertEquals(original,OutputTarget.entryIdentity(failure.recovery));assertEquals("reviewed",Files.readString(failure.recovery));
        assertEquals("verification failure",failure.getCause().getMessage());assertInstanceOf(FileAlreadyExistsException.class,failure.getSuppressed()[0]);
        assertFalse(Files.exists(failure.partial));try(var entries=Files.list(root)){assertEquals(2,entries.count());}
    }
    @Test void postPublicationCleanupFailureIsPublishedAndNotRolledBack()throws Exception {
        Path target=root.resolve("output");Files.writeString(target,"reviewed");var original=OutputTarget.entryIdentity(target);
        OutputCommit.RecoveryRequired failure;
        try(var output=OutputCommit.open(target,true,OutputTarget.identity(target),new OutputCommit.Faults(){
            public void beforeCleanup(Path t,Path r)throws Exception{throw new AccessDeniedException("injected cleanup");}
        })) {Files.writeString(output.partial(),"output");failure=assertThrows(OutputCommit.RecoveryRequired.class,output::commit);}
        assertTrue(failure.published);assertEquals("output",Files.readString(target));assertEquals(original,OutputTarget.entryIdentity(failure.recovery));
        assertEquals("reviewed",Files.readString(failure.recovery));assertEquals("OUTPUT_PUBLISHED_RECOVERY_REQUIRED",io.busystack.busydata.storage.IoFailure.code(failure));
        try(var entries=Files.list(root)){assertEquals(2,entries.count());}
    }
    @ParameterizedTest @ValueSource(strings={"file","link","directory","missing"})
    void recoverySubstitutionStopsMutation(String kind)throws Exception {
        Path target=root.resolve("output"),kept=root.resolve("kept"),victim=root.resolve("victim");Files.writeString(target,"reviewed");Files.writeString(victim,"untouched");
        OutputCommit.RecoveryRequired failure;
        try(var output=OutputCommit.open(target,true,OutputTarget.identity(target),new OutputCommit.Faults(){
            public void afterPreserve(Path t,Path r)throws Exception {
                Files.move(r,kept);
                switch(kind){case "file"->Files.writeString(r,"other");case "link"->Files.createSymbolicLink(r,victim);case "directory"->Files.createDirectory(r);}
            }
        })) {Files.writeString(output.partial(),"output");failure=assertThrows(OutputCommit.RecoveryRequired.class,output::commit);}
        assertFalse(failure.published);assertFalse(Files.exists(target,LinkOption.NOFOLLOW_LINKS));assertEquals("reviewed",Files.readString(kept));assertEquals("untouched",Files.readString(victim));
        assertFalse(Files.exists(failure.partial));
        switch(kind){case "file"->assertEquals("other",Files.readString(failure.recovery));case "link"->assertEquals(victim,Files.readSymbolicLink(failure.recovery));case "directory"->assertTrue(Files.isDirectory(failure.recovery));case "missing"->assertFalse(Files.exists(failure.recovery,LinkOption.NOFOLLOW_LINKS));}
    }
    @Test void changedPartialIsNeitherPublishedNorDeleted()throws Exception {
        Path target=root.resolve("output"),kept=root.resolve("kept");
        var output=OutputCommit.open(target,false,OutputTarget.identity(target),new OutputCommit.Faults(){
            public void beforePublish(Path t,Path partial)throws Exception{Files.move(partial,kept);Files.writeString(partial,"foreign");}
        });
        Path staging=output.partial();Files.writeString(staging,"produced");assertThrows(IOException.class,output::commit);
        assertThrows(IOException.class,output::close);assertFalse(Files.exists(target));assertEquals("produced",Files.readString(kept));
        try(var entries=Files.list(root)){Path retained=entries.filter(p->p.getFileName().toString().endsWith(".partial")).findFirst().orElseThrow();assertEquals("foreign",Files.readString(retained));}
    }
    @ParameterizedTest @ValueSource(strings={"file","link","directory"})
    void displacedEntryIsRestoredWithoutFollowingOrReviewingIt(String kind)throws Exception {
        Path target=root.resolve("output.csv"),old=root.resolve("reviewed"),victim=root.resolve("victim");
        Files.writeString(target,"reviewed");Files.writeString(victim,"untouched");
        Object[] displaced=new Object[1];
        try(var output=OutputCommit.open(target,true,OutputTarget.identity(target),new OutputCommit.Faults(){
            public void beforePrimitive(Path t,Path partial)throws Exception {
                Files.move(t,old);
                switch(kind){case "file"->Files.writeString(t,"other");case "link"->Files.createSymbolicLink(t,victim);case "directory"->{Files.createDirectory(t);Files.writeString(t.resolve("child"),"child");}}
                displaced[0]=Files.readAttributes(t,java.nio.file.attribute.BasicFileAttributes.class,LinkOption.NOFOLLOW_LINKS).fileKey();
            }
        })) {Files.writeString(output.partial(),"produced");assertThrows(IOException.class,output::commit);}
        assertEquals(displaced[0],Files.readAttributes(target,java.nio.file.attribute.BasicFileAttributes.class,LinkOption.NOFOLLOW_LINKS).fileKey());
        if(kind.equals("link"))assertEquals(victim,Files.readSymbolicLink(target));
        else if(kind.equals("directory"))assertEquals("child",Files.readString(target.resolve("child")));
        else assertEquals("other",Files.readString(target));
        assertEquals("untouched",Files.readString(victim));assertNoPartials();
    }
    @ParameterizedTest @ValueSource(booleans={false,true})
    void throwingOrCancelledVerificationRestoresWithoutHashingAgain(boolean cancel)throws Exception {
        Path target=root.resolve("output.csv");Files.writeString(target,"reviewed");
        Object key=Files.readAttributes(target,java.nio.file.attribute.BasicFileAttributes.class).fileKey();
        try(var output=OutputCommit.open(target,true,OutputTarget.identity(target),new OutputCommit.Faults(){
            public void afterPreserve(Path t,Path recovery)throws Exception {if(cancel)Thread.currentThread().interrupt();throw new java.io.InterruptedIOException("verification interrupted");}
        })) {Files.writeString(output.partial(),"produced");try{assertThrows(IOException.class,output::commit);}finally{Thread.interrupted();}}
        assertEquals("reviewed",Files.readString(target));assertEquals(key,Files.readAttributes(target,java.nio.file.attribute.BasicFileAttributes.class).fileKey());assertNoPartials();
    }
    @Test void absentDestinationPublishesWholePrivateFile()throws Exception {
        Path target=root.resolve("new.csv");
        try(var output=OutputCommit.open(target,false)){Files.writeString(output.partial(),"exact 漢😀");output.commit();assertEquals("exact 漢😀",Files.readString(target));}
        assertNoPartials();
    }
    @Test void existingDestinationRequiresExplicitReplacement()throws Exception {
        Path target=root.resolve("old.csv");Files.writeString(target,"original");
        assertThrows(FileAlreadyExistsException.class,()->OutputCommit.open(target,false));assertEquals("original",Files.readString(target));assertNoPartials();
    }
    @Test void destinationCreatedDuringExecutionConflicts()throws Exception {
        Path target=root.resolve("new.csv");String reviewed=OutputTarget.identity(target);
        try(var output=OutputCommit.open(target,false,reviewed,new OutputCommit.Faults(){public void beforeCommit(Path target,Path partial)throws Exception{Files.writeString(target,"other");}})) {
            Files.writeString(output.partial(),"export");assertThrows(IOException.class,output::commit);assertEquals("other",Files.readString(target));
        }assertNoPartials();
    }
    @Test void destinationCreatedInsideFinalizationNeverClobbered()throws Exception {
        Path target=root.resolve("new.csv");
        try(var output=OutputCommit.open(target,false,OutputTarget.identity(target),new OutputCommit.Faults(){public void beforePrimitive(Path target,Path partial)throws Exception{Files.writeString(target,"late other");}})) {
            Files.writeString(output.partial(),"export");assertThrows(IOException.class,output::commit);assertEquals("late other",Files.readString(target));
        }assertNoPartials();
    }
    @Test void overwriteChoiceDoesNotApproveFileAppearingAtAbsentDestination()throws Exception {
        Path target=root.resolve("new.csv");
        try(var output=OutputCommit.open(target,true,OutputTarget.identity(target),new OutputCommit.Faults(){public void beforePrimitive(Path target,Path partial)throws Exception{Files.writeString(target,"unreviewed");}})) {
            Files.writeString(output.partial(),"export");assertThrows(IOException.class,output::commit);assertEquals("unreviewed",Files.readString(target));
        }assertNoPartials();
    }
    @Test void replacementBetweenReviewAndOpeningRejected()throws Exception {
        Path target=root.resolve("old.csv");Files.writeString(target,"reviewed");String reviewed=OutputTarget.identity(target);Files.delete(target);Files.writeString(target,"other");
        assertThrows(IOException.class,()->OutputCommit.open(target,true,reviewed));assertEquals("other",Files.readString(target));assertNoPartials();
    }
    @Test void reviewedReplacementCommitsExactBytes()throws Exception {
        Path target=root.resolve("old.csv");Files.writeString(target,"original");
        try(var output=OutputCommit.open(target,true)){Files.writeString(output.partial(),"approved replacement");output.commit();}
        assertEquals("approved replacement",Files.readString(target));assertNoPartials();
    }
    @Test void changedReviewedTargetPreservedBeforePrimitive()throws Exception {
        Path target=root.resolve("old.csv");Files.writeString(target,"original");
        try(var output=OutputCommit.open(target,true,OutputTarget.identity(target),new OutputCommit.Faults(){public void beforeCommit(Path target,Path partial)throws Exception{Files.writeString(target,"concurrent");}})) {
            Files.writeString(output.partial(),"export");assertThrows(IOException.class,output::commit);assertEquals("concurrent",Files.readString(target));
        }assertNoPartials();
    }
    @Test void lateReplacementIsRestoredToItsOwnPathAndNeverExchangedForOutput()throws Exception {
        Path target=root.resolve("old.csv");Files.writeString(target,"original");
        try(var output=OutputCommit.open(target,true,OutputTarget.identity(target),new OutputCommit.Faults(){public void beforePrimitive(Path target,Path partial)throws Exception{Files.writeString(target,"late user file");}})) {
            Files.writeString(output.partial(),"export");assertThrows(IOException.class,output::commit);
        }
        assertEquals("late user file",Files.readString(target));assertNoPartials();
    }
    @Test void lateNewIdentityIsRestoredToItsOwnPathAndNeverExchangedForOutput()throws Exception {
        Path target=root.resolve("old.csv");Files.writeString(target,"original");
        try(var output=OutputCommit.open(target,true,OutputTarget.identity(target),new OutputCommit.Faults(){public void beforePrimitive(Path target,Path partial)throws Exception{Files.delete(target);Files.writeString(target,"late replacement inode");}})) {
            Files.writeString(output.partial(),"export");assertThrows(IOException.class,output::commit);
        }
        assertEquals("late replacement inode",Files.readString(target));assertNoPartials();
    }
    @Test void writerAppearingAfterPreservationKeepsItsPathAndReviewedOriginalIsRecoverable()throws Exception {
        Path target=root.resolve("old.csv");Files.writeString(target,"reviewed original");
        try(var output=OutputCommit.open(target,true,OutputTarget.identity(target),new OutputCommit.Faults(){public void afterPreserve(Path target,Path recovery)throws Exception{Files.writeString(target,"late user file");}})) {
            Files.writeString(output.partial(),"export");assertThrows(OutputCommit.RecoveryRequired.class,output::commit);
        }
        assertEquals("late user file",Files.readString(target));
        try(var files=Files.list(root)){assertTrue(files.filter(path->path.getFileName().toString().startsWith(".busydata-")).anyMatch(path->{try{return Files.readString(path).equals("reviewed original");}catch(IOException ignored){return false;}}));}
    }
    @Test void unsupportedAtomicPrimitiveFailsWithoutFallback()throws Exception {failedPrimitive(new AtomicMoveNotSupportedException("partial","target","injected unsupported filesystem"));}
    @Test void postReplacementRacePreservesOriginalWithoutOverwritingThirdWriter()throws Exception {
        Path target=root.resolve("old.csv");Files.writeString(target,"reviewed original");
        try(var output=OutputCommit.open(target,true,OutputTarget.identity(target),new OutputCommit.Faults(){public void afterPrimitive(Path target,Path partial)throws Exception{Files.delete(target);Files.writeString(target,"third writer");}})) {
            Files.writeString(output.partial(),"export");assertThrows(OutputCommit.RecoveryRequired.class,output::commit);
        }
        assertEquals("third writer",Files.readString(target));
        try(var files=Files.list(root)){assertTrue(files.filter(path->path.getFileName().toString().startsWith(".busydata-")).anyMatch(path->{try{return Files.readString(path).equals("reviewed original");}catch(IOException ignored){return false;}}));}
    }
    @Test void retainedRecoveryHasPrivatePermissions()throws Exception {
        if(System.getProperty("os.name").startsWith("Windows"))return;
        Path target=root.resolve("old.csv");Files.writeString(target,"original");Files.setPosixFilePermissions(target,java.nio.file.attribute.PosixFilePermissions.fromString("rw-r--r--"));
        try(var output=OutputCommit.open(target,true,OutputTarget.identity(target),new OutputCommit.Faults(){public void afterPrimitive(Path target,Path partial)throws Exception{Files.delete(target);Files.writeString(target,"other");}})) {
            Files.writeString(output.partial(),"export");assertThrows(OutputCommit.RecoveryRequired.class,output::commit);
        }
        try(var files=Files.list(root)){Path backup=files.filter(path->path.getFileName().toString().startsWith(".busydata-")).findFirst().orElseThrow();assertEquals(java.nio.file.attribute.PosixFilePermissions.fromString("rw-------"),Files.getPosixFilePermissions(backup));assertEquals("original",Files.readString(backup));}
    }
    @Test void crossDevicePrimitiveFailsWithoutCopyFallback()throws Exception {failedPrimitive(new FileSystemException("partial","target","injected cross-device failure"));}
    private void failedPrimitive(IOException fault)throws Exception {
        Path target=root.resolve("old.csv");Files.writeString(target,"original");
        try(var output=OutputCommit.open(target,true,OutputTarget.identity(target),new OutputCommit.Faults(){public void beforePrimitive(Path target,Path partial)throws Exception{throw fault;}})) {
            Files.writeString(output.partial(),"export");assertSame(fault,assertThrows(IOException.class,output::commit));assertEquals("original",Files.readString(target));
        }assertNoPartials();
    }
    @Test void symlinkAndParentSymlinkRejected()throws Exception {
        if(System.getProperty("os.name").startsWith("Windows"))return; // covered by required native reparse suite
        Path victim=root.resolve("victim");Files.writeString(victim,"private");Path link=root.resolve("link");Files.createSymbolicLink(link,victim);
        assertThrows(IOException.class,()->OutputCommit.open(link,true));assertEquals("private",Files.readString(victim));
        Path real=Files.createDirectory(root.resolve("real")),alias=root.resolve("alias");Files.createSymbolicLink(alias,real);
        assertThrows(IOException.class,()->OutputCommit.open(alias.resolve("out.csv"),false));
    }
    @Test void symlinkCreatedImmediatelyBeforeCommitNotFollowed()throws Exception {
        if(System.getProperty("os.name").startsWith("Windows"))return;
        Path target=root.resolve("new.csv"),victim=root.resolve("victim");Files.writeString(victim,"private");
        try(var output=OutputCommit.open(target,false,OutputTarget.identity(target),new OutputCommit.Faults(){public void beforePrimitive(Path target,Path partial)throws Exception{Files.createSymbolicLink(target,victim);}})) {
            Files.writeString(output.partial(),"export");assertThrows(IOException.class,output::commit);assertEquals("private",Files.readString(victim));assertTrue(Files.isSymbolicLink(target));
        }assertNoPartials();
    }
    @Test void parentReplacementRejectedAndUnrelatedDirectoryUntouched()throws Exception {
        Path parent=Files.createDirectory(root.resolve("selected")),target=parent.resolve("out.csv"),moved=root.resolve("moved");
        boolean[] prevented={false};
        try(var output=OutputCommit.open(target,false,OutputTarget.identity(target),new OutputCommit.Faults(){public void beforeCommit(Path target,Path partial)throws Exception{
            try{Files.move(parent,moved);}catch(IOException locked){assertTrue(System.getProperty("os.name").startsWith("Windows"));assertTrue(Files.isDirectory(parent));assertFalse(Files.exists(moved));prevented[0]=true;return;}
            Files.createDirectory(parent);Files.writeString(target,"unrelated");
        }})) {
            Files.writeString(output.partial(),"export");
            Exception failure=null;try{output.commit();}catch(Exception caught){failure=caught;}
            if(prevented[0]){assertNull(failure);assertEquals("export",Files.readString(target));}
            else {assertInstanceOf(IOException.class,failure);assertEquals("unrelated",Files.readString(target));}
        }
        if(prevented[0])Files.move(parent,moved); // Closing must release the Windows directory guards.
        try(var files=Files.list(moved)){assertEquals(prevented[0]?1:0,files.count());}
    }
    @Test void cancellationAndFailureCleanupIsIdempotent()throws Exception {
        Path target=root.resolve("never.csv");var output=OutputCommit.open(target,false);Files.writeString(output.partial(),"partial");output.close();output.close();assertFalse(Files.exists(target));assertNoPartials();
    }
    @Test void cleanupFailurePreservesPrimaryAndOriginal()throws Exception {
        Path target=root.resolve("old.csv");Files.writeString(target,"original");IOException primary=new IOException("encoding failed");
        var caught=assertThrows(IOException.class,()->{try(var output=OutputCommit.open(target,true,OutputTarget.identity(target),new OutputCommit.Faults(){public void delete(Path path)throws IOException{throw new IOException("injected denied cleanup");}})){Files.writeString(output.partial(),"partial");throw primary;}});
        assertSame(primary,caught);assertEquals(1,caught.getSuppressed().length);assertEquals("original",Files.readString(target));
        var staging=assertInstanceOf(OutputCommit.RecoveryRequired.class,caught.getSuppressed()[0]);
        assertFalse(staging.published);assertNull(staging.recovery);assertEquals("partial",Files.readString(staging.partial));
        assertEquals("injected denied cleanup",staging.reason);
    }
    @Test void unicodeAndDeepLongPaths()throws Exception {
        Path directory=root;for(int i=0;i<8;i++)directory=Files.createDirectory(directory.resolve("資料😀-"+"long".repeat(8)+i));
        Path target=directory.resolve("出力😀.csv");try(var output=OutputCommit.open(target,false)){Files.writeString(output.partial(),"Unicode");output.commit();}assertEquals("Unicode",Files.readString(target));
    }
    @Test void windowsPathsCanonicalizedWithoutDeviceNamespace()throws Exception {
        assertEquals("\\\\?\\C:\\資料😀\\out.csv",WindowsOutputFiles.extendedPath("C:\\資料😀\\out.csv"));
        assertEquals("\\\\?\\UNC\\server\\share\\out.csv",WindowsOutputFiles.extendedPath("\\\\server\\share\\out.csv"));
        assertThrows(IOException.class,()->WindowsOutputFiles.extendedPath("\\\\.\\PhysicalDrive0"));assertThrows(IOException.class,()->WindowsOutputFiles.extendedPath("relative.csv"));
    }
    @Test void allTransferFinalizersUseSharedOwner()throws Exception {
        String source=Files.readString(Path.of("src/main/java/io/busystack/busydata/transfers/Transfers.java"));
        assertFalse(source.contains("Files.move("));assertFalse(source.contains("Files.createTempFile("));assertEquals(3,source.split("OutputCommit.open",-1).length-1);
        String policy=Files.readString(Path.of("src/main/java/io/busystack/busydata/transfers/OutputCommit.java"));
        String linux=Files.readString(Path.of("src/main/java/io/busystack/busydata/transfers/LinuxOutputFiles.java"));
        String windows=Files.readString(Path.of("src/main/java/io/busystack/busydata/transfers/WindowsOutputFiles.java"));
        assertFalse(policy.contains(".exchange("));assertFalse(linux.contains("RENAME_EXCHANGE"));assertFalse(windows.contains("ReplaceFileW"));
    }
    private void assertNoPartials()throws Exception {try(var files=Files.list(root)){assertEquals(0,files.filter(path->path.getFileName().toString().startsWith(".busydata-")).count());}}
}
