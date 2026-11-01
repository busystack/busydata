package io.busystack.busydata.analysis.language;

import java.util.concurrent.CancellationException;
import java.util.concurrent.TimeUnit;
import java.util.function.BooleanSupplier;

/** A request-local CPU budget; editor analysis never owns a database connection. */
public final class AnalysisBudget {
    public static final int MAX_DOCUMENT_UNITS=262_144, MAX_TOKENS=100_000, MAX_DEPTH=64, MAX_SCOPES=2048;
    private final long deadline;
    private final BooleanSupplier cancelled;
    public AnalysisBudget(long milliseconds,BooleanSupplier cancelled) {
        if(milliseconds<1||milliseconds>1500)throw new IllegalArgumentException("Invalid analysis deadline");
        this.deadline=System.nanoTime()+TimeUnit.MILLISECONDS.toNanos(milliseconds);this.cancelled=cancelled;
    }
    public static AnalysisBudget interactive(){return new AnalysisBudget(750,()->Thread.currentThread().isInterrupted());}
    public void check(){
        if(cancelled.getAsBoolean()||Thread.currentThread().isInterrupted())throw new CancellationException("SQL analysis cancelled");
        if(System.nanoTime()>deadline)throw new Limit("SQL analysis deadline exceeded");
    }
    public static final class Limit extends IllegalArgumentException {
        private static final java.util.Set<String> SAFE_REASONS=java.util.Set.of(
            "SQL analysis deadline exceeded","SQL nesting exceeds 64 levels","SQL query-scope budget exceeded",
            "SQL symbol document exceeds its budget","Semantic projection nesting exceeds 32 levels",
            "SQL document exceeds 256Ki UTF-16 units","SQL token budget exceeded","Formatting document exceeds its budget");
        public Limit(String message){super(message);}
        /** Only controlled constant reasons cross the editor boundary. A future
         * caller's dynamic message must not expose SQL, identifiers, or values. */
        public String diagnosticMessage(){return getMessage()!=null&&SAFE_REASONS.contains(getMessage())?getMessage():"SQL analysis resource limit reached; analyze a smaller statement or selection";}
    }
}
