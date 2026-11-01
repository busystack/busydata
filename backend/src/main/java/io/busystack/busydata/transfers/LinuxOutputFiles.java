package io.busystack.busydata.transfers;

import java.io.IOException;
import java.lang.foreign.*;
import java.lang.invoke.MethodHandle;
import java.nio.file.*;

/** Descriptor-relative Linux commits. Unsupported renameat2 is a failure, never a move fallback. */
final class LinuxOutputFiles implements AutoCloseable {
    private static final Linker LINKER=Linker.nativeLinker();
    private static final SymbolLookup LIBC=LINKER.defaultLookup();
    private static final MethodHandle OPEN=call("open",FunctionDescriptor.of(ValueLayout.JAVA_INT,ValueLayout.ADDRESS,ValueLayout.JAVA_INT));
    private static final MethodHandle OPENAT=call("openat",FunctionDescriptor.of(ValueLayout.JAVA_INT,ValueLayout.JAVA_INT,ValueLayout.ADDRESS,ValueLayout.JAVA_INT));
    private static final MethodHandle CLOSE=call("close",FunctionDescriptor.of(ValueLayout.JAVA_INT,ValueLayout.JAVA_INT));
    private static final MemoryLayout STATE=Linker.Option.captureStateLayout();
    private static final long ERRNO_OFFSET=STATE.byteOffset(MemoryLayout.PathElement.groupElement("errno"));
    private static final MethodHandle RENAME=optional("renameat2",FunctionDescriptor.of(ValueLayout.JAVA_INT,ValueLayout.JAVA_INT,ValueLayout.ADDRESS,ValueLayout.JAVA_INT,ValueLayout.ADDRESS,ValueLayout.JAVA_INT));
    private static final int FLAGS=0x200000|0x10000|0x20000|0x80000; // PATH|DIRECTORY|NOFOLLOW|CLOEXEC
    private int descriptor;
    private LinuxOutputFiles(int descriptor){this.descriptor=descriptor;}
    static LinuxOutputFiles open(Path parent)throws IOException {
        int descriptor=-1;
        try(var arena=Arena.ofConfined()) {
            var state=arena.allocate(STATE);
            descriptor=(int)OPEN.invokeExact(state,arena.allocateFrom("/"),FLAGS);
            if(descriptor<0)throw error("Open destination root",state);
            for(Path component:parent.toAbsolutePath().normalize()) {
                int next=(int)OPENAT.invokeExact(state,descriptor,arena.allocateFrom(component.toString()),FLAGS);
                if(next<0)throw error("Destination ancestor must be an ordinary accessible directory",state);
                int closed=(int)CLOSE.invokeExact(state,descriptor);descriptor=next;
                if(closed!=0)throw error("Close destination ancestor",state);
            }
            return new LinuxOutputFiles(descriptor);
        }catch(Throwable failure){
            if(descriptor>=0)try(var cleanupArena=Arena.ofConfined()){int ignored=(int)CLOSE.invokeExact(cleanupArena.allocate(STATE),descriptor);}catch(Throwable cleanup){failure.addSuppressed(cleanup);}
            throw io(failure);
        }
    }
    Path directory(){return Path.of("/proc/self/fd/"+descriptor);}
    void moveNew(String partial,String target)throws IOException{rename(partial,target,1);}
    private void rename(String partial,String target,int flags)throws IOException {
        if(RENAME==null)throw new AtomicMoveNotSupportedException(partial,target,"Filesystem requires Linux renameat2; no unsafe fallback");
        try(var arena=Arena.ofConfined()) {
            var state=arena.allocate(STATE);
            int result=(int)RENAME.invokeExact(state,descriptor,arena.allocateFrom(partial),descriptor,arena.allocateFrom(target),flags);
            if(result!=0){int code=state.get(ValueLayout.JAVA_INT,ERRNO_OFFSET);if(code==17)throw new FileAlreadyExistsException(target);if(code==18||code==22||code==38||code==95)throw new AtomicMoveNotSupportedException(partial,target,"Safe destination commit unsupported (errno "+code+")");throw new FileSystemException(partial,target,"Safe destination commit failed (errno "+code+")");}
        }catch(Throwable failure){throw io(failure);}
    }
    @Override public void close()throws IOException {
        if(descriptor<0)return;int owned=descriptor;descriptor=-1;
        try(var arena=Arena.ofConfined()){var state=arena.allocate(STATE);int result=(int)CLOSE.invokeExact(state,owned);if(result!=0)throw error("Close destination directory",state);}catch(Throwable failure){throw io(failure);}
    }
    private static MethodHandle call(String name,FunctionDescriptor signature){return LINKER.downcallHandle(LIBC.find(name).orElseThrow(),signature,Linker.Option.captureCallState("errno"));}
    private static MethodHandle optional(String name,FunctionDescriptor signature){return LIBC.find(name).map(symbol->LINKER.downcallHandle(symbol,signature,Linker.Option.captureCallState("errno"))).orElse(null);}
    private static IOException error(String action,MemorySegment state){return new IOException(action+" (errno "+state.get(ValueLayout.JAVA_INT,ERRNO_OFFSET)+")");}
    private static IOException io(Throwable failure){return failure instanceof IOException value?value:new IOException("Safe destination primitive failed",failure);}
}
