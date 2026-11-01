package io.busystack.busydata.schema;

import com.google.protobuf.ByteString;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.results.ArrayParameters;
import io.busystack.busydata.sessions.SessionRegistry;
import java.sql.SQLException;
import java.sql.Types;
import java.util.Objects;

/** Pure optimistic predicates over verified identifiers and retained values.
 * Textual database equality may be case/accent insensitive or ignore padding;
 * retained text instead compares its exact UTF-8 representation. PostgreSQL's
 * format('%s', any) invokes the native output function without a bpchar->text
 * cast (which would discard padding). No function is executed during planning.
 *
 * Primary contracts: PostgreSQL17 functions-string §9.4.1/functions-binarystring;
 * REL_17_11 varlena.c text_format + OutputFunctionCall; MySQL8.4 CAST/CONVERT and
 * MariaDB CONVERT/BINARY documentation. Identifiers are quoted/verified upstream.
 */
public final class RowVerification {
    public record Predicate(String sql,Value value,int jdbcType,int arrayOid){}
    private RowVerification(){}

    public static Predicate predicate(SessionRegistry.Session session,String verifiedQuotedColumn,Value original,int jdbcType,int arrayOid)throws SQLException {
        Objects.requireNonNull(session);return predicate(session.profile.getEngine(),verifiedQuotedColumn,original,jdbcType,arrayOid);
    }
    static Predicate predicate(Engine engine,String verifiedQuotedColumn,Value original,int jdbcType,int arrayOid)throws SQLException {
        Objects.requireNonNull(original);
        if(engine!=Engine.POSTGRESQL&&engine!=Engine.MYSQL&&engine!=Engine.MARIADB)throw new IllegalArgumentException("Unsupported optimistic verification engine");
        quotedColumn(verifiedQuotedColumn,engine);
        if(original.getTruncated()||!original.getValueId().isEmpty()||original.getDataCase()==Value.DataCase.DATA_NOT_SET||original.getSerializedSize()>1_048_576)
            throw new IllegalArgumentException("A complete bounded retained original is required for verification");
        if(original.hasNullValue())return new Predicate(verifiedQuotedColumn+" IS NULL",null,jdbcType,arrayOid);
        if(original.hasArray()||jdbcType==Types.ARRAY) {
            if(engine!=Engine.POSTGRESQL||!original.hasArray()||arrayOid==0)throw new IllegalArgumentException("Verified native PostgreSQL array identity is required");
            ArrayParameters.validate(original);
            return new Predicate(pgBytes(verifiedQuotedColumn)+"="+pgBytes("?"),original,jdbcType,arrayOid);
        }
        String raw=switch(original.getDataCase()) {case TEXT->original.getText();case JSON->original.getJson();case ENGINE_VALUE->original.getEngineValue().getText();default->null;};
        if(raw!=null) {
            ByteString bytes=utf8(raw);
            String left=engine==Engine.POSTGRESQL?pgBytes(verifiedQuotedColumn):"CAST(CONVERT("+verifiedQuotedColumn+" USING utf8mb4) AS BINARY)";
            return new Predicate(left+"=?",Value.newBuilder().setBinary(bytes).build(),Types.VARBINARY,0);
        }
        return new Predicate(verifiedQuotedColumn+"=?",original,jdbcType,arrayOid);
    }
    private static String pgBytes(String expression){return "pg_catalog.convert_to(pg_catalog.format('%s',"+expression+"),'UTF8')";}
    private static ByteString utf8(String raw) {
        if(raw.length()>262_144)throw new IllegalArgumentException("Retained text exceeds the optimistic verification budget");
        for(int index=0;index<raw.length();index++) {
            char unit=raw.charAt(index);
            if(Character.isHighSurrogate(unit)){if(++index==raw.length()||!Character.isLowSurrogate(raw.charAt(index)))throw new IllegalArgumentException("Retained text has invalid Unicode");}
            else if(Character.isLowSurrogate(unit))throw new IllegalArgumentException("Retained text has invalid Unicode");
        }
        return ByteString.copyFromUtf8(raw);
    }
    private static void quotedColumn(String value,Engine engine) {
        char quote=engine==Engine.POSTGRESQL?'"':'`';
        if(value==null||value.length()<3||value.length()>1024||value.charAt(0)!=quote||value.charAt(value.length()-1)!=quote||value.indexOf('\0')>=0)
            throw new IllegalArgumentException("One verified quoted column identifier is required");
        for(int index=1;index<value.length()-1;index++)if(value.charAt(index)==quote){if(index+1>=value.length()-1||value.charAt(++index)!=quote)throw new IllegalArgumentException("One verified quoted column identifier is required");}
    }
}
