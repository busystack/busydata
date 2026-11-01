package io.busystack.busydata.metadata;

import io.busystack.busydata.adapters.JdbcAdapter;
import io.busystack.busydata.protocol.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

/** Parsed physical names confer no metadata authority or write provenance. */
class ParsedPhysicalReferenceTest {
    private static Profile profile(Engine engine){return Profile.newBuilder().setId("profile").setEngine(engine).setDatabase("db").build();}
    private static JdbcAdapter.LiveContext context(String mode){return new JdbcAdapter.LiveContext("db","db",List.of("db"),"",mode,true,"+00:00","UTC",true,"ISO, MDY");}
    @Test void coldQuotedReferencesRemainSyntaxOnlyAndKeepExactEscapes(){
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB)){
            var parsed=RetainedMetadataProof.parsedReference(profile(engine),"SELECT id FROM `other``db`.`a``b` AS x WHERE id=1",context("")).orElseThrow();
            assertEquals("other`db",parsed.database());assertEquals("a`b",parsed.name());assertTrue(parsed.quoted());
            var empty=new MetadataSnapshot("source","profile",1,1,1,new IdentifierRules(engine,0),List.of(),Map.of());
            assertTrue(RetainedMetadataProof.sourceRelation(empty,profile(engine),"owner","SELECT id FROM `other``db`.`a``b`",context("")).isEmpty(),"Syntax cannot certify an object, structure, or generation");
        }
    }
    @Test void currentDatabaseAndActiveAnsiQuotesAreCaptured(){
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB)){
            var implicit=RetainedMetadataProof.parsedReference(profile(engine),"SELECT * FROM MiXeD",context("")).orElseThrow();assertEquals("db",implicit.database());assertEquals("MiXeD",implicit.name());assertFalse(implicit.quoted());
            var quoted=RetainedMetadataProof.parsedReference(profile(engine),"SELECT * FROM \"other\".\"MiXeD\"",context("ANSI_QUOTES")).orElseThrow();assertEquals("other",quoted.database());assertEquals("MiXeD",quoted.name());assertTrue(quoted.quoted());
        }
    }
    @Test void ambiguousUnsupportedOrOversizedSourcesNeverBecomeNativeCandidates(){
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB))for(String sql:List.of("SELECT * FROM db.one JOIN db.two ON one.id=two.id","WITH c AS (SELECT * FROM t) SELECT * FROM c","SELECT * FROM (SELECT * FROM t) d","SELECT * FROM t UNION ALL SELECT * FROM u","SELECT DISTINCT id FROM t","SELECT id FROM t GROUP BY id","SELECT * FROM server.db.t","SELECT * FROM `"+"a".repeat(257)+"`","SELECT * FROM t WHERE ("))assertTrue(RetainedMetadataProof.parsedReference(profile(engine),sql,context("")).isEmpty(),engine+": unsupported source shape");
        assertTrue(RetainedMetadataProof.parsedReference(profile(Engine.POSTGRESQL),"SELECT * FROM public.t",context("")).isEmpty());
        assertTrue(RetainedMetadataProof.parsedReference(profile(Engine.MYSQL),"SELECT * FROM t",null).isEmpty());
    }
    @Test void cancellationCannotTurnAParserFailureIntoAnIdentifier(){
        try{
            Thread.currentThread().interrupt();
            assertTrue(RetainedMetadataProof.parsedReference(profile(Engine.MYSQL),"SELECT * FROM t",context("")).isEmpty(),"An interrupted parser must not return a physical reference");
            assertTrue(Thread.currentThread().isInterrupted(),"The interrupted parser caller must retain its cancellation signal");
        }finally{Thread.interrupted();}
    }
}
