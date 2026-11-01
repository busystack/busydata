package io.busystack.busydata.analysis;

import io.busystack.busydata.protocol.Engine;
import java.util.List;
import java.util.concurrent.AbstractExecutorService;
import java.util.concurrent.CancellationException;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.Future;
import java.util.concurrent.RejectedExecutionException;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class SqlParsingCancellationTest {
    @Test void anAlreadyInterruptedCallerDoesNotSubmitParsing(){
        var executor=new CompleteBeforeGet(false);
        try{
            Thread.currentThread().interrupt();
            assertThrows(CancellationException.class,()->SqlParsing.parse("SELECT 1",Engine.MYSQL,LexicalSettings.DEFAULT,executor));
            assertTrue(Thread.currentThread().isInterrupted(),"Pre-parse cancellation must preserve the caller flag");
            assertEquals(0,executor.submissions,"Cancellation must be checked before scheduling parser work");
        }finally{Thread.interrupted();}
    }
    @Test void aCompletedParserFutureCannotReturnSyntaxAfterCallerInterruption(){
        var executor=new CompleteBeforeGet(true);
        try{
            assertFalse(Thread.currentThread().isInterrupted());
            assertThrows(CancellationException.class,()->SqlParsing.parse("SELECT 1",Engine.MYSQL,LexicalSettings.DEFAULT,executor));
            assertEquals(1,executor.submissions);
            assertEquals(1,executor.successfulCompletions,"The real upstream parse must complete before interrupt injection");
            assertTrue(Thread.currentThread().isInterrupted(),"The completed-future cancellation boundary must preserve the caller flag");
        }finally{Thread.interrupted();}
    }
    @Test void aCompletedParserFutureStillReturnsSyntaxWithoutCancellation()throws Exception{
        var executor=new CompleteBeforeGet(false);
        assertInstanceOf(net.sf.jsqlparser.statement.select.PlainSelect.class,SqlParsing.parse("SELECT 1",Engine.MYSQL,LexicalSettings.DEFAULT,executor));
        assertEquals(1,executor.submissions);
        assertEquals(1,executor.successfulCompletions);
        assertFalse(Thread.currentThread().isInterrupted());
    }
    /** Complete the genuine submitted parser operation before Future.get, then optionally interrupt its caller.
     * This schedules the completion race deterministically without sleeps, reflection, or dependency changes. */
    private static final class CompleteBeforeGet extends AbstractExecutorService {
        private final boolean interruptAfterCompletion;
        private boolean shutdown;
        int submissions,successfulCompletions;
        CompleteBeforeGet(boolean interruptAfterCompletion){this.interruptAfterCompletion=interruptAfterCompletion;}
        @Override public void execute(Runnable operation){
            if(shutdown)throw new RejectedExecutionException();
            submissions++;
            operation.run();
            var completed=assertInstanceOf(Future.class,operation);
            assertTrue(completed.isDone());
            try{
                assertNotNull(completed.get(),"The actual JSQLParser operation must succeed before cancellation is injected");
                successfulCompletions++;
            }catch(InterruptedException|ExecutionException failure){throw new AssertionError("The controlled upstream parser operation failed",failure);}
            if(interruptAfterCompletion)Thread.currentThread().interrupt();
        }
        @Override public void shutdown(){shutdown=true;}
        @Override public List<Runnable> shutdownNow(){shutdown=true;return List.of();}
        @Override public boolean isShutdown(){return shutdown;}
        @Override public boolean isTerminated(){return shutdown;}
        @Override public boolean awaitTermination(long timeout,TimeUnit unit){return shutdown;}
    }
}
