package io.busystack.busydata.schema;

import com.google.protobuf.ByteString;
import io.busystack.busydata.protocol.*;
import java.sql.Types;
import java.util.List;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class RowVerificationTest {
    @Test void everyTextRepresentationComparesExactUtf8BytesWithoutJdbcWork()throws Exception {
        String raw="Case漢😀  ";var values=List.of(Value.newBuilder().setText(raw).build(),Value.newBuilder().setJson(raw).build(),Value.newBuilder().setEngineValue(EngineValue.newBuilder().setTypeName("opaque").setText(raw)).build());
        for(var engine:List.of(Engine.POSTGRESQL,Engine.MYSQL,Engine.MARIADB))for(var value:values) {
            var quoted=engine==Engine.POSTGRESQL?"\"v\"":"`v`";var p=RowVerification.predicate(engine,quoted,value,Types.VARCHAR,0);
            assertEquals(ByteString.copyFromUtf8(raw),p.value().getBinary());assertEquals(Types.VARBINARY,p.jdbcType());assertEquals(0,p.arrayOid());
            assertFalse(p.sql().contains(raw));assertTrue(p.sql().endsWith("=?"));
            assertTrue(p.sql().startsWith(engine==Engine.POSTGRESQL?"pg_catalog.convert_to(pg_catalog.format('%s',":"CAST(CONVERT("));
        }
    }
    @Test void nullNeverBecomesAParameterAndNumericTransportIsUnchanged()throws Exception {
        var p=RowVerification.predicate(Engine.POSTGRESQL,"\"n\"",Value.newBuilder().setNullValue(Null.getDefaultInstance()).build(),Types.NUMERIC,0);assertEquals("\"n\" IS NULL",p.sql());assertNull(p.value());
        var exact=Value.newBuilder().setDecimal("12345678901234567890.0000000001").build();p=RowVerification.predicate(Engine.MYSQL,"`n`",exact,Types.DECIMAL,0);assertSame(exact,p.value());assertEquals("`n`=?",p.sql());assertEquals(Types.DECIMAL,p.jdbcType());
    }
    @Test void nativeArrayPredicateFormatsBothSidesAndPreservesItsVerifiedOid()throws Exception {
        var array=Value.newBuilder().setArray(ArrayValue.newBuilder().setNativeLiteral("[0:1]={Case,NULL}").setElementNativeType("text").addValues(Value.newBuilder().setText("Case")).addValues(Value.newBuilder().setNullValue(Null.getDefaultInstance()))).build();
        var p=RowVerification.predicate(Engine.POSTGRESQL,"\"a\"",array,Types.ARRAY,1009);assertSame(array,p.value());assertEquals(1009,p.arrayOid());assertEquals(Types.ARRAY,p.jdbcType());
        assertEquals("pg_catalog.convert_to(pg_catalog.format('%s',\"a\"),'UTF8')=pg_catalog.convert_to(pg_catalog.format('%s',?),'UTF8')",p.sql());
        assertThrows(IllegalArgumentException.class,()->RowVerification.predicate(Engine.MYSQL,"`a`",array,Types.ARRAY,1009));
        assertThrows(IllegalArgumentException.class,()->RowVerification.predicate(Engine.POSTGRESQL,"\"a\"",array,Types.ARRAY,0));
    }
    @Test void identifiersMustBeOneAlreadyQuotedIdentity()throws Exception {
        var original=Value.newBuilder().setSignedInteger("1").build();
        assertEquals("\"a\"\"b\"=?",RowVerification.predicate(Engine.POSTGRESQL,"\"a\"\"b\"",original,Types.INTEGER,0).sql());
        for(String forged:List.of("n","\"n\" OR TRUE --","\"a\".\"b\"","\"\"","`n`","\"bad\u0000name\""))assertThrows(IllegalArgumentException.class,()->RowVerification.predicate(Engine.POSTGRESQL,forged,original,Types.INTEGER,0));
    }
    @Test void truncatedUnpairedAndOversizedOriginalsFailWithoutLeakingContents() {
        var truncated=Value.newBuilder().setText("secret").setTruncated(true).build();var error=assertThrows(IllegalArgumentException.class,()->RowVerification.predicate(Engine.POSTGRESQL,"\"n\"",truncated,Types.VARCHAR,0));assertFalse(error.getMessage().contains("secret"));
        assertThrows(IllegalArgumentException.class,()->RowVerification.predicate(Engine.MYSQL,"`n`",Value.newBuilder().setText("\ud800").build(),Types.VARCHAR,0));
        assertThrows(IllegalArgumentException.class,()->RowVerification.predicate(Engine.MYSQL,"`n`",Value.newBuilder().setText("x".repeat(262145)).build(),Types.VARCHAR,0));
    }
}
