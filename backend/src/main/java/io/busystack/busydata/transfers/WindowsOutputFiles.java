package io.busystack.busydata.transfers;

import java.io.IOException;
import java.lang.foreign.Arena;
import java.lang.foreign.FunctionDescriptor;
import java.lang.foreign.Linker;
import java.lang.foreign.MemoryLayout;
import java.lang.foreign.MemorySegment;
import java.lang.foreign.SymbolLookup;
import java.lang.foreign.ValueLayout;
import java.lang.invoke.MethodHandle;
import java.nio.ByteOrder;
import java.nio.file.Path;
import java.nio.file.NoSuchFileException;
import java.util.HexFormat;
import java.util.ArrayList;
import java.util.List;

/**
 * Windows-only filesystem primitives behind the shared output policy.
 * Uses Java 25's stable FFM API and the OS-owned Kernel32 DLL. No JNI library,
 * shell, user-configurable native library, copy fallback or TLS policy belongs
 * here. Native Windows execution is a separate required acceptance stage.
 */
final class WindowsOutputFiles implements AutoCloseable {
    private static final int FILE_SHARE_READ_WRITE = 3;
    private static final int FILE_SHARE_READ_WRITE_DELETE = 7;
    private static final int OPEN_EXISTING = 3;
    private static final int OPEN_DIRECTORY_NO_REPARSE = 0x02000000 | 0x00200000;
    private static final int FILE_ATTRIBUTE_DIRECTORY = 0x10;
    private static final int FILE_ATTRIBUTE_REPARSE_POINT = 0x400;
    private static final int FILE_ATTRIBUTE_TAG_INFO = 9;
    private static final int FILE_ID_INFO = 18;
    private static final int MOVEFILE_WRITE_THROUGH = 8;
    private static final ValueLayout.OfChar UTF16 = ValueLayout.JAVA_CHAR.withOrder(ByteOrder.LITTLE_ENDIAN);
    private final Path parent;
    private final Api api;
    private final List<MemorySegment> handles = new ArrayList<>();
    private boolean closed;

    private WindowsOutputFiles(Path parent, Api api) {
        this.parent = parent;
        this.api = api;
    }

    static WindowsOutputFiles open(Path requestedParent) throws IOException {
        if (!System.getProperty("os.name", "").startsWith("Windows") || ValueLayout.ADDRESS.byteSize() != 8)
            throw new IOException("Safe Windows output commit requires the approved Windows x64 platform");
        final Api api;
        try { api = ApiHolder.INSTANCE; }
        catch (LinkageError | RuntimeException failure) {
            throw new IOException("The Windows filesystem commit primitives are unavailable; no unsafe fallback is permitted", failure);
        }
        Path parent = requestedParent.toAbsolutePath().normalize();
        Path root = parent.getRoot();
        if (root == null) throw new IOException("Output parent must have a complete Windows volume path");
        if (parent.getNameCount() > 128) throw new IOException("Windows output parent exceeds the bounded directory depth");
        WindowsOutputFiles guard = new WindowsOutputFiles(parent, api);
        try {
            // Lock from volume root down. Each preceding directory is already
            // locked when opening its next child, so traversal cannot switch
            // to a replaced ancestor between validation and finalization.
            Path current = root;
            guard.lockDirectory(current);
            for (Path component : root.relativize(parent)) {
                current = current.resolve(component);
                guard.lockDirectory(current);
            }
            return guard;
        } catch (IOException | RuntimeException failure) {
            try { guard.close(); } catch (IOException cleanup) { failure.addSuppressed(cleanup); }
            throw failure;
        }
    }

    /** The approved Windows provider may omit BasicFileAttributes.fileKey().
     * Query the no-follow handle instead: volume serial plus the 128-bit file
     * ID identify the entry, including after a rename. No path/mtime surrogate
     * is accepted. FILE_ID_INFO is documented by the Windows File API.
     */
    static OutputTarget.EntryIdentity entryIdentity(Path path) throws IOException {
        if (!System.getProperty("os.name", "").startsWith("Windows") || ValueLayout.ADDRESS.byteSize() != 8)
            throw new IOException("Windows entry identity requires the approved Windows x64 platform");
        final Api api;
        try { api = ApiHolder.INSTANCE; }
        catch (LinkageError | RuntimeException failure) {
            throw new IOException("Windows filesystem identity primitives are unavailable", failure);
        }
        try (Arena arena = Arena.ofConfined()) {
            MemorySegment state = arena.allocate(api.stateLayout);
            MemorySegment handle = (MemorySegment) api.create.invokeExact(state, wide(arena, path),
                0, FILE_SHARE_READ_WRITE_DELETE, MemorySegment.NULL, OPEN_EXISTING, OPEN_DIRECTORY_NO_REPARSE, MemorySegment.NULL);
            if (handle.address() == -1L || handle.address() == 0L) {
                int code = state.get(ValueLayout.JAVA_INT, api.errorOffset);
                if (code == 2 || code == 3) throw new NoSuchFileException(path.toString());
                throw nativeFailure("Identify output entry", code);
            }
            IOException primary = null;
            try {
                MemorySegment attributes = arena.allocate(8, 4);
                int success = (int) api.info.invokeExact(state, handle, FILE_ATTRIBUTE_TAG_INFO, attributes, 8);
                if (success == 0) throw nativeFailure("Inspect output entry", state.get(ValueLayout.JAVA_INT, api.errorOffset));
                int flags = attributes.get(ValueLayout.JAVA_INT, 0);
                MemorySegment identity = arena.allocate(24, 8);
                success = (int) api.info.invokeExact(state, handle, FILE_ID_INFO, identity, 24);
                if (success == 0) throw nativeFailure("Read output file ID", state.get(ValueLayout.JAVA_INT, api.errorOffset));
                String key = "windows-volume=" + Long.toUnsignedString(identity.get(ValueLayout.JAVA_LONG, 0), 16)
                    + ";file=" + HexFormat.of().formatHex(identity.asSlice(8, 16).toArray(ValueLayout.JAVA_BYTE));
                String kind = (flags & FILE_ATTRIBUTE_REPARSE_POINT) != 0 ? "link"
                    : (flags & FILE_ATTRIBUTE_DIRECTORY) != 0 ? "directory" : "file";
                return new OutputTarget.EntryIdentity(key, kind);
            } catch (IOException failure) { primary = failure; throw failure; }
            catch (Throwable failure) { primary = invocationFailure(failure); throw primary; }
            finally {
                try {
                    int success = (int) api.close.invokeExact(state, handle);
                    if (success == 0) throw nativeFailure("Close output identity handle", state.get(ValueLayout.JAVA_INT, api.errorOffset));
                } catch (Throwable failure) {
                    IOException cleanup = failure instanceof IOException io ? io : invocationFailure(failure);
                    if (primary != null) primary.addSuppressed(cleanup); else throw cleanup;
                }
            }
        } catch (IOException failure) { throw failure; }
        catch (Throwable failure) { throw invocationFailure(failure); }
    }

    private void lockDirectory(Path directory) throws IOException {
        try (Arena arena = Arena.ofConfined()) {
            MemorySegment state = arena.allocate(api.stateLayout);
            MemorySegment handle = (MemorySegment) api.create.invokeExact(state, wide(arena, directory),
                0, FILE_SHARE_READ_WRITE, MemorySegment.NULL, OPEN_EXISTING,
                OPEN_DIRECTORY_NO_REPARSE, MemorySegment.NULL);
            if (handle.address() == -1L || handle.address() == 0L)
                throw nativeFailure("Lock output parent", error(state));
            handles.add(handle);
            MemorySegment attributes = arena.allocate(8, 4);
            int success = (int) api.info.invokeExact(state, handle, FILE_ATTRIBUTE_TAG_INFO, attributes, 8);
            if (success == 0) throw nativeFailure("Inspect output parent", error(state));
            int flags = attributes.get(ValueLayout.JAVA_INT, 0);
            if ((flags & FILE_ATTRIBUTE_REPARSE_POINT) != 0 || (flags & FILE_ATTRIBUTE_DIRECTORY) == 0)
                throw new IOException("Output parents must be ordinary directories; Windows reparse points are not permitted");
        } catch (IOException failure) { throw failure; }
        catch (Throwable failure) { throw invocationFailure(failure); }
    }

    synchronized void moveNew(Path partial, Path target) throws IOException {
        requireOpen();
        Path source = sibling(partial), destination = sibling(target);
        if (source.equals(destination)) throw new IOException("Partial output and destination must differ");
        try (Arena arena = Arena.ofConfined()) {
            MemorySegment state = arena.allocate(api.stateLayout);
            // Neither REPLACE_EXISTING nor COPY_ALLOWED is supplied. A file
            // appearing during commit causes a conflict; cross-volume moves
            // fail rather than turning into a non-atomic copy/delete.
            int success = (int) api.move.invokeExact(state, wide(arena, source),
                wide(arena, destination), MOVEFILE_WRITE_THROUGH);
            if (success == 0) throw nativeFailure("Commit new output", error(state));
        } catch (IOException failure) { throw failure; }
        catch (Throwable failure) { throw invocationFailure(failure); }
    }

    private Path sibling(Path requested) throws IOException {
        Path path = requested.toAbsolutePath().normalize();
        if (!parent.equals(path.getParent()))
            throw new IOException("Safe output finalization requires partial and destination in the locked directory");
        return path;
    }

    private void requireOpen() throws IOException {
        if (closed) throw new IOException("Output destination guard has already been closed");
    }

    @Override public synchronized void close() throws IOException {
        if (closed) return;
        closed = true;
        IOException failure = null;
        try (Arena arena = Arena.ofConfined()) {
            MemorySegment state = arena.allocate(api.stateLayout);
            for (int index = handles.size() - 1; index >= 0; index--) {
                try {
                    int success = (int) api.close.invokeExact(state, handles.get(index));
                    if (success == 0) throw nativeFailure("Close output directory guard", error(state));
                } catch (Throwable cleanup) {
                    IOException next = cleanup instanceof IOException io ? io : invocationFailure(cleanup);
                    if (failure == null) failure = next; else failure.addSuppressed(next);
                }
            }
        } finally { handles.clear(); }
        if (failure != null) throw failure;
    }

    private int error(MemorySegment state) { return state.get(ValueLayout.JAVA_INT, api.errorOffset); }

    private static IOException nativeFailure(String operation, int code) {
        return new IOException(operation + " failed (Windows error " + Integer.toUnsignedString(code)
            + "); the safe filesystem primitive failed; no copy or overwrite fallback was attempted");
    }

    private static IOException invocationFailure(Throwable failure) {
        return new IOException("Windows filesystem commit invocation failed; retain output/recovery files and review their state", failure);
    }

    private static MemorySegment wide(Arena arena, Path path) throws IOException {
        String value = extendedPath(path.toAbsolutePath().normalize().toString());
        MemorySegment text = arena.allocate((long) (value.length() + 1) * 2, 2);
        for (int index = 0; index < value.length(); index++) text.setAtIndex(UTF16, index, value.charAt(index));
        text.setAtIndex(UTF16, value.length(), '\0');
        return text;
    }

    static String extendedPath(String value) throws IOException {
        if (value.indexOf('\0') >= 0 || value.length() > 32760)
            throw new IOException("Windows output path exceeds its Unicode path bound");
        String path = value.replace('/', '\\');
        if (path.startsWith("\\\\?\\")) {
            String rest = path.substring(4);
            if (rest.matches("[A-Za-z]:\\\\.*") || rest.startsWith("UNC\\")) return path;
            throw new IOException("Windows device namespace is not an output destination");
        }
        if (path.startsWith("\\\\") && !path.startsWith("\\\\.\\")) return "\\\\?\\UNC\\" + path.substring(2);
        if (path.matches("[A-Za-z]:\\\\.*")) return "\\\\?\\" + path;
        throw new IOException("Windows output path must name an absolute drive or UNC destination");
    }

    private static final class ApiHolder { static final Api INSTANCE = new Api(); }

    private static final class Api {
        final Linker linker = Linker.nativeLinker();
        // Kernel32 is an OS KnownDLL. No workspace/environment library path is
        // accepted, and this initialization is never reached on Linux.
        final SymbolLookup symbols = SymbolLookup.libraryLookup("kernel32.dll", Arena.global());
        final MemoryLayout stateLayout = Linker.Option.captureStateLayout();
        final long errorOffset = stateLayout.byteOffset(MemoryLayout.PathElement.groupElement("GetLastError"));
        final MethodHandle create = function("CreateFileW", FunctionDescriptor.of(ValueLayout.ADDRESS,
            ValueLayout.ADDRESS, ValueLayout.JAVA_INT, ValueLayout.JAVA_INT, ValueLayout.ADDRESS,
            ValueLayout.JAVA_INT, ValueLayout.JAVA_INT, ValueLayout.ADDRESS));
        final MethodHandle info = function("GetFileInformationByHandleEx", FunctionDescriptor.of(ValueLayout.JAVA_INT,
            ValueLayout.ADDRESS, ValueLayout.JAVA_INT, ValueLayout.ADDRESS, ValueLayout.JAVA_INT));
        final MethodHandle close = function("CloseHandle", FunctionDescriptor.of(ValueLayout.JAVA_INT, ValueLayout.ADDRESS));
        final MethodHandle move = function("MoveFileExW", FunctionDescriptor.of(ValueLayout.JAVA_INT,
            ValueLayout.ADDRESS, ValueLayout.ADDRESS, ValueLayout.JAVA_INT));
        MethodHandle function(String name, FunctionDescriptor descriptor) {
            return linker.downcallHandle(symbols.find(name).orElseThrow(), descriptor,
                Linker.Option.captureCallState("GetLastError"));
        }
    }
}
