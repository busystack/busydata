package io.busystack.busydata.safety;

import io.busystack.busydata.analysis.SqlAnalysis;
import io.busystack.busydata.analysis.LexicalSettings;
import io.busystack.busydata.sessions.SessionRegistry;
import io.busystack.busydata.protocol.*;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

public final class Safety {
    private record Permit(String fingerprint,long expires,String sourceSha256) {}
    private final Map<String,Permit> permits=new ConcurrentHashMap<>();
    private final SqlAnalysis analysis;
    private final java.util.function.LongSupplier clock;
    public Safety(SqlAnalysis analysis){this(analysis,System::currentTimeMillis);}
    Safety(SqlAnalysis analysis,java.util.function.LongSupplier clock){this.analysis=analysis;this.clock=Objects.requireNonNull(clock);}
    public Approval review(ExecuteRequest r,SessionRegistry.Session session) {
        var reviewed=review(r,session.targetProfile(),session.revision,session.context.lexical()).toBuilder();
        if(session.profile.getEngine()==Engine.POSTGRESQL&&reviewed.getRisksCount()>0)reviewed.addRisks("Current search path: "+String.join(", ",session.context.searchPath()));
        return reviewed.build();
    }
    public Approval review(ExecuteRequest r,Profile profile,long revision) {return review(r,profile,revision,LexicalSettings.DEFAULT);}
    private Approval review(ExecuteRequest r,Profile profile,long revision,LexicalSettings lexical) {
        var fragments=analysis.execution(r,profile.getEngine(),lexical);
        var result=Approval.newBuilder();
        for(var f:fragments) {
            result.addStatements(f.text());
            if(!analysis.readOnly(f.text()))result.addRisks("May modify data, session state, or schema; rollback depends on the engine");
        }
        if(profile.getEnvironment()==Environment.PRODUCTION)result.addRisks("PRODUCTION: "+profile.getHost()+":"+profile.getPort()+"/"+profile.getDatabase());
        if(profile.getReadOnly() && fragments.stream().anyMatch(f->!analysis.readOnly(f.text())))throw new IllegalArgumentException("Read-only profile rejects this SQL");
        long expiry=clock.getAsLong()+120_000;
        if(permits.size()>=256)permits.entrySet().removeIf(e->e.getValue().expires()<clock.getAsLong());
        if(permits.size()>=256)throw new IllegalStateException("Too many pending approvals");
        String token=issue(fingerprint(r,profile,revision,lexical));
        return result.setToken(token).setExpiresUnixMs(expiry).build();
    }
    public void authorize(ExecuteRequest r,SessionRegistry.Session session) {
        authorize(r,session.targetProfile(),session.revision,session.context.lexical());
    }
    public void authorize(ExecuteRequest r,Profile profile,long revision) {authorize(r,profile,revision,LexicalSettings.DEFAULT);}
    private void authorize(ExecuteRequest r,Profile profile,long revision,LexicalSettings lexical) {
        var fragments=analysis.execution(r,profile.getEngine(),lexical);
        boolean modifies=fragments.stream().anyMatch(f->!analysis.readOnly(f.text()));
        if(profile.getReadOnly() && modifies)throw new IllegalArgumentException("Read-only profile rejects this SQL");
        if(modifies || profile.getEnvironment()==Environment.PRODUCTION || !r.getApprovalToken().isBlank())consume(r.getApprovalToken(),fingerprint(r,profile,revision,lexical));
    }
    public String issue(String fingerprint){return issue(fingerprint,"");}
    /** Server-owned source evidence shares the same bounded, expiring permit store. */
    public String issueSource(String fingerprint,String sourceSha256){
        if(sourceSha256==null||!sourceSha256.matches("[0-9a-f]{64}"))throw new IllegalArgumentException("Invalid reviewed source digest");
        return issue(fingerprint,sourceSha256);
    }
    private synchronized String issue(String fingerprint,String sourceSha256){permits.entrySet().removeIf(e->e.getValue().expires()<clock.getAsLong());if(permits.size()>=256)throw new IllegalStateException("Too many pending approvals");String token=UUID.randomUUID().toString();permits.put(token,new Permit(fingerprint,clock.getAsLong()+120_000,sourceSha256));return token;}
    public void discard(String token){permits.remove(token);}
    public void consume(String token,String fingerprint) {
        Permit permit=permits.remove(token);
        if(permit==null || !permit.sourceSha256().isEmpty() || permit.expires()<clock.getAsLong() || !sameFingerprint(permit,fingerprint))throw new IllegalArgumentException("Review required or approval stale");
    }
    @FunctionalInterface public interface SourceFingerprint {String fingerprint(String reviewedSha256)throws Exception;}
    /** Consume before slow admission IO; callers must still verify these bytes before submission. */
    public String consumeSource(String token,SourceFingerprint fingerprint)throws Exception {
        Permit permit=permits.remove(token);
        if(permit==null||permit.sourceSha256().isEmpty()||permit.expires()<clock.getAsLong())throw new IllegalArgumentException("Review required or approval stale");
        if(!sameFingerprint(permit,fingerprint.fingerprint(permit.sourceSha256())))throw new IllegalArgumentException("Review required or approval stale");
        return permit.sourceSha256();
    }
    private static boolean sameFingerprint(Permit permit,String fingerprint){return MessageDigest.isEqual(permit.fingerprint().getBytes(StandardCharsets.UTF_8),fingerprint.getBytes(StandardCharsets.UTF_8));}
    public static String fingerprint(ExecuteRequest r,Profile p,long revision) {return fingerprint(r,p,revision,LexicalSettings.DEFAULT);}
    private static String fingerprint(ExecuteRequest r,Profile p,long revision,LexicalSettings lexical) {
        try { var digest=MessageDigest.getInstance("SHA-256");digest.update(r.toBuilder().clearContext().clearApprovalToken().clearExecutionId().build().toByteArray());digest.update(p.toByteArray());digest.update(lexical.toString().getBytes(StandardCharsets.US_ASCII));digest.update(Long.toString(revision).getBytes(StandardCharsets.US_ASCII));return HexFormat.of().formatHex(digest.digest()); }
        catch(Exception e){throw new IllegalStateException(e);}
    }
    public static String changeFingerprint(ChangeRequest request,Profile profile,long revision,String metadata) {
        try{var digest=MessageDigest.getInstance("SHA-256");digest.update("row-change".getBytes(StandardCharsets.US_ASCII));digest.update(request.toBuilder().clearContext().build().toByteArray());digest.update(profile.toByteArray());digest.update(Long.toString(revision).getBytes(StandardCharsets.US_ASCII));digest.update(metadata.getBytes(StandardCharsets.UTF_8));return HexFormat.of().formatHex(digest.digest());}catch(Exception error){throw new IllegalStateException(error);}
    }
}
