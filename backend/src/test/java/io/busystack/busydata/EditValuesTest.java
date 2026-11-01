package io.busystack.busydata;

import io.busystack.busydata.analysis.language.SqlTypes;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.EditValues;
import com.google.protobuf.ByteString;
import java.sql.Types;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class EditValuesTest {
    private static SchemaObject column(String nativeType,int jdbc,int precision,int scale) {
        return SchemaObject.newBuilder().setKind(ObjectKind.COLUMN).setName("c").putProperties("type",nativeType).putProperties("jdbcType",Integer.toString(jdbc))
            .putProperties("precision",Integer.toString(precision)).putProperties("scale",Integer.toString(scale)).putProperties("nullable","YES").build();
    }
    private static Value text(String raw){return Value.newBuilder().setText(raw).build();}
    private static Value convert(String raw,SchemaObject column,Engine engine){return EditValues.convert(text(raw),column,engine,null);}
    private static void failure(EditValues.Code code,Runnable action){var failure=assertThrows(EditValues.Failure.class,action::run);assertEquals(code,failure.code());assertNull(failure.getCause());}

    @Test void everyIntegerWidthAndSignednessUsesNativeRangeInsteadOfJdbcFlattening() {
        var types=Map.of("tinyint",8,"smallint",16,"mediumint",24,"int",32,"bigint",64);
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB))for(var entry:types.entrySet())for(boolean unsigned:List.of(false,true)) {
            var c=column(entry.getKey()+(unsigned?" unsigned":""),Types.BIGINT,20,0).toBuilder().putProperties("unsigned",Boolean.toString(unsigned)).build();
            var type=SqlTypes.column(c,engine);var expectedMinimum=unsigned?java.math.BigInteger.ZERO:java.math.BigInteger.ONE.shiftLeft(entry.getValue()-1).negate();var expectedMaximum=java.math.BigInteger.ONE.shiftLeft(unsigned?entry.getValue():entry.getValue()-1).subtract(java.math.BigInteger.ONE);
            assertEquals(expectedMinimum,type.minimumInteger());assertEquals(expectedMaximum,type.maximumInteger());String minimum=expectedMinimum.toString(),maximum=expectedMaximum.toString();
            assertEquals(minimum,unsigned?convert(minimum,c,engine).getUnsignedInteger():convert(minimum,c,engine).getSignedInteger());
            assertEquals(maximum,unsigned?convert(maximum,c,engine).getUnsignedInteger():convert(maximum,c,engine).getSignedInteger());
            failure(EditValues.Code.OUT_OF_RANGE,()->convert(type.minimumInteger().subtract(java.math.BigInteger.ONE).toString(),c,engine));
            failure(EditValues.Code.OUT_OF_RANGE,()->convert(type.maximumInteger().add(java.math.BigInteger.ONE).toString(),c,engine));
        }
        for(String nativeName:List.of("smallint","integer","bigint","int2","int4","int8")) {
            var c=column(nativeName,Types.BIGINT,20,0);var t=SqlTypes.column(c,Engine.POSTGRESQL);
            assertEquals(t.maximumInteger().toString(),convert(t.maximumInteger().toString(),c,Engine.POSTGRESQL).getSignedInteger());
            failure(EditValues.Code.OUT_OF_RANGE,()->convert(t.maximumInteger().add(java.math.BigInteger.ONE).toString(),c,Engine.POSTGRESQL));
        }
        var u=column("bigint unsigned",Types.BIGINT,20,0);
        assertEquals("18446744073709551615",convert("18446744073709551615",u,Engine.MYSQL).getUnsignedInteger());
        failure(EditValues.Code.INVALID_FORMAT,()->convert("1.0",column("integer",Types.INTEGER,10,0),Engine.POSTGRESQL));
    }
    @Test void yearAndSerialFamiliesUseTheirOwnDeclaredRanges() {
        var year=column("year(4)",Types.SMALLINT,4,0);
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB)) {
            for(String valid:List.of("0","1901","2026","2155"))assertEquals(valid,convert(valid,year,engine).getSignedInteger());
            for(String invalid:List.of("1","69","1900","2156","-1"))failure(EditValues.Code.OUT_OF_RANGE,()->convert(invalid,year,engine));
        }
        assertEquals(SqlTypes.Family.USER,SqlTypes.column(year,Engine.POSTGRESQL).family());
        failure(EditValues.Code.UNSUPPORTED,()->convert("0",column("year(2)",Types.SMALLINT,2,0),Engine.MARIADB));
        assertEquals(new java.math.BigInteger("18446744073709551615"),SqlTypes.nativeType("serial",Engine.MYSQL).maximumInteger());
        assertEquals(new java.math.BigInteger("18446744073709551615"),SqlTypes.nativeType("int8 unsigned",Engine.MARIADB).maximumInteger());
        assertEquals(new java.math.BigInteger("4294967295"),SqlTypes.nativeType("int zerofill",Engine.MYSQL).maximumInteger());
        assertEquals(java.math.BigInteger.valueOf(32767),SqlTypes.nativeType("smallserial",Engine.POSTGRESQL).maximumInteger());
        assertEquals(java.math.BigInteger.valueOf(Long.MAX_VALUE),SqlTypes.nativeType("bigserial",Engine.POSTGRESQL).maximumInteger());
    }
    @Test void driverBooleanAliasDoesNotReduceNativeTinyintRangeToOneBit() {
        var tiny=column("tinyint(1)",Types.BIT,1,0);
        assertEquals("127",convert("127",tiny,Engine.MYSQL).getSignedInteger());
        assertEquals("0",convert("false",tiny,Engine.MYSQL).getSignedInteger());
        assertEquals("1",EditValues.convert(Value.newBuilder().setBoolean(true).build(),tiny,Engine.MARIADB,null).getSignedInteger());
        var bit=column("bit(1)",Types.BIT,1,0);assertTrue(convert("true",bit,Engine.MYSQL).getBoolean());
        failure(EditValues.Code.INVALID_FORMAT,()->convert("2",bit,Engine.MYSQL));
    }
    @Test void decimalConversionIsExactAndBoundedBeforeExpansionOrRounding() {
        var c=column("numeric(38,18)",Types.NUMERIC,38,18);
        String exact="12345678901234567890.123456789012345678";
        assertEquals(exact,convert(exact,c,Engine.POSTGRESQL).getDecimal());
        assertEquals("1.230000000000000000",convert("1.23",c,Engine.POSTGRESQL).getDecimal());
        failure(EditValues.Code.LOSS_OF_PRECISION,()->convert("1.1234567890123456789",c,Engine.POSTGRESQL));
        failure(EditValues.Code.OUT_OF_RANGE,()->convert("123456789012345678901.1",c,Engine.POSTGRESQL));
        var unconstrained=column("numeric",Types.NUMERIC,0,0);
        assertEquals("0.00000001",convert("1e-8",unconstrained,Engine.POSTGRESQL).getDecimal());
        for(String huge:List.of("1e1000000000","1e-1000000000","0e2147483647","1e999999999999999999999"))failure(EditValues.Code.VALUE_LIMIT,()->convert(huge,unconstrained,Engine.POSTGRESQL));
        failure(EditValues.Code.VALUE_LIMIT,()->convert("9".repeat(65_537),unconstrained,Engine.POSTGRESQL));
        var negative=column("numeric(2,-3)",Types.NUMERIC,2,-3);
        assertEquals("99000",convert("99000",negative,Engine.POSTGRESQL).getDecimal());
        failure(EditValues.Code.LOSS_OF_PRECISION,()->convert("99100",negative,Engine.POSTGRESQL));
        var fraction=column("numeric(3,5)",Types.NUMERIC,3,5);
        assertEquals("0.00123",convert("0.00123",fraction,Engine.POSTGRESQL).getDecimal());
        failure(EditValues.Code.OUT_OF_RANGE,()->convert("0.01",fraction,Engine.POSTGRESQL));
        failure(EditValues.Code.INVALID_TYPE,()->EditValues.convert(Value.newBuilder().setReal(1.25).build(),c,Engine.POSTGRESQL,null));
    }
    @Test void floatingPointTargetsRejectNonfiniteOverflowAndUnderflowBeforeReview() {
        var single=column("float",Types.FLOAT,12,0);var wide=column("double",Types.DOUBLE,22,0);
        assertEquals(1.5,convert("1.5",single,Engine.MYSQL).getReal());
        failure(EditValues.Code.OUT_OF_RANGE,()->convert("3.5e38",single,Engine.MYSQL));
        failure(EditValues.Code.OUT_OF_RANGE,()->convert("1e309",wide,Engine.MYSQL));
        failure(EditValues.Code.OUT_OF_RANGE,()->convert("1e-400",wide,Engine.MYSQL));
        failure(EditValues.Code.OUT_OF_RANGE,()->EditValues.convert(Value.newBuilder().setReal(Double.NaN).build(),wide,Engine.MYSQL,null));
        failure(EditValues.Code.OUT_OF_RANGE,()->EditValues.convert(Value.newBuilder().setReal(Double.POSITIVE_INFINITY).build(),wide,Engine.MYSQL,null));
    }
    @Test void booleansAcceptOnlyExplicitBooleanRepresentations() {
        var c=column("boolean",Types.BOOLEAN,1,0);
        for(String yes:List.of("true","TRUE","1"))assertTrue(convert(yes,c,Engine.POSTGRESQL).getBoolean());
        for(String no:List.of("false","FALSE","0"))assertFalse(convert(no,c,Engine.POSTGRESQL).getBoolean());
        for(String invalid:List.of("yes","on","2"," true ","NULL"))failure(EditValues.Code.INVALID_FORMAT,()->convert(invalid,c,Engine.POSTGRESQL));
    }
    @Test void temporalValidationPreservesTimezoneKindAndRejectsPrecisionLoss() {
        var date=column("date",Types.DATE,10,0);
        assertEquals("2024-02-29",convert("2024-02-29",date,Engine.POSTGRESQL).getTemporal().getIso());
        for(String unsupported:List.of("0000-01-01","-0001-02-28"))failure(EditValues.Code.UNSUPPORTED,()->convert(unsupported,date,Engine.POSTGRESQL));
        for(String invalid:List.of("2023-02-29","2024-02-30","0000-00-00","2024-13-01","2024-01-01T00:00:00"))assertThrows(EditValues.Failure.class,()->convert(invalid,date,Engine.MYSQL));
        var timestamp=column("timestamp(6) without time zone",Types.TIMESTAMP,29,6);
        assertEquals("2024-02-29T10:20:30.123456",convert("2024-02-29T10:20:30.123456",timestamp,Engine.POSTGRESQL).getTemporal().getIso());
        failure(EditValues.Code.INVALID_FORMAT,()->convert("2024-02-29T10:20:30Z",timestamp,Engine.POSTGRESQL));
        failure(EditValues.Code.LOSS_OF_PRECISION,()->convert("2024-02-29T10:20:30.1234567",timestamp,Engine.POSTGRESQL));
        var zoned=column("timestamp(6) with time zone",Types.TIMESTAMP_WITH_TIMEZONE,35,6);
        assertEquals("2024-02-29T10:20:30.123456+02:00",convert("2024-02-29T10:20:30.123456+02:00",zoned,Engine.POSTGRESQL).getTemporal().getIso());
        failure(EditValues.Code.INVALID_FORMAT,()->convert("2024-02-29T10:20:30",zoned,Engine.POSTGRESQL));
        var coarse=column("timestamp(3)",Types.TIMESTAMP,24,3);
        failure(EditValues.Code.LOSS_OF_PRECISION,()->convert("2024-02-29T10:20:30.1234",coarse,Engine.POSTGRESQL));
        assertEquals("2024-02-29T10:20:30.123",convert("2024-02-29T10:20:30.123000",coarse,Engine.POSTGRESQL).getTemporal().getIso());
    }
    @Test void mysqlAndMariaTimeDurationsAndTimestampReleaseRangesRemainDistinct() {
        var time=column("time(6)",Types.TIME,17,6);
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB)) {
            assertEquals("-25:00:00.123456",convert("-25:00:00.123456",time,engine).getTemporal().getIso());
            assertEquals("-838:59:59",convert("-838:59:59",time,engine).getTemporal().getIso());
            failure(EditValues.Code.OUT_OF_RANGE,()->convert("839:00:00",time,engine));
            failure(EditValues.Code.OUT_OF_RANGE,()->convert("12:60:00",time,engine));
        }
        assertEquals("838:59:59.999999",convert("838:59:59.999999",time,Engine.MARIADB).getTemporal().getIso());
        assertEquals("-838:59:59.999999",convert("-838:59:59.999999",time,Engine.MARIADB).getTemporal().getIso());
        for(String edge:List.of("838:59:59.000001","-838:59:59.000001"))failure(EditValues.Code.OUT_OF_RANGE,()->convert(edge,time,Engine.MYSQL));
        assertEquals("12:30",convert("12:30",time,Engine.POSTGRESQL).getTemporal().getIso());
        assertEquals("12:30:00",convert("12:30",time,Engine.MYSQL).getTemporal().getIso());
        assertEquals("12:30:00.123",convert("12:30:00.123000000",time,Engine.MYSQL).getTemporal().getIso());
        assertEquals("24:00:00",convert("24:00:00",time,Engine.POSTGRESQL).getTemporal().getIso());
        failure(EditValues.Code.INVALID_FORMAT,()->convert("25:00:00",time,Engine.POSTGRESQL));
        var ts=column("timestamp(6)",Types.TIMESTAMP,26,6).toBuilder().putProperties("sessionTimeZoneOffsetSeconds","0").build();
        assertEquals("2100-01-01T00:00",convert("2100-01-01T00:00:00",ts,Engine.MARIADB).getTemporal().getIso());
        failure(EditValues.Code.OUT_OF_RANGE,()->convert("2100-01-01T00:00:00",ts,Engine.MYSQL));
        failure(EditValues.Code.UNSUPPORTED,()->convert("1970-01-01T00:00:01",column("timestamp",Types.TIMESTAMP,26,6),Engine.MYSQL));
    }
    @Test void binaryBytesAndExplicitHexAreExactAndFixedPaddingIsNeverHidden() {
        var c=column("varbinary(10)",Types.VARBINARY,10,0);var bytes=ByteString.copyFrom(new byte[]{0,(byte)255,10});
        assertEquals(bytes,EditValues.convert(Value.newBuilder().setBinary(bytes).build(),c,Engine.MYSQL,null).getBinary());
        for(String hex:List.of("00ff0a","0x00ff0a","\\x00ff0a"))assertEquals(bytes,convert(hex,c,Engine.MYSQL).getBinary());
        for(String invalid:List.of("f","ff gg","'ff'","ff;DROP","ｅｅ"))failure(EditValues.Code.INVALID_FORMAT,()->convert(invalid,c,Engine.MYSQL));
        failure(EditValues.Code.LOSS_OF_PRECISION,()->convert("00ff",column("binary(3)",Types.BINARY,3,0),Engine.MYSQL));
        failure(EditValues.Code.OUT_OF_RANGE,()->convert("ffff",column("bit(9)",Types.BIT,9,0),Engine.MARIADB));
        failure(EditValues.Code.UNSUPPORTED,()->convert("01",column("bit(8)",Types.BIT,8,0),Engine.POSTGRESQL));
        failure(EditValues.Code.UNSUPPORTED,()->EditValues.convert(Value.newBuilder().setBoolean(true).build(),column("bit(1)",Types.BIT,1,0),Engine.POSTGRESQL,null));
    }
    @Test void jsonSyntaxIsStrictBoundedAndKeepsEveryNumberDuplicateAndWhitespace() {
        String raw=" {\"same\":123456789012345678901234567890.000000000001,\"same\":1e-1000,\"s\":\"\\uD83D\\uDE00\"} \r\n";
        var c=column("json",Types.OTHER,0,0);
        for(var engine:List.of(Engine.POSTGRESQL,Engine.MYSQL,Engine.MARIADB))assertEquals(raw,convert(raw,c,engine).getJson());
        for(String invalid:List.of("{\"n\":01}","[1,]","{\"x\":NaN}","[1] extra","{\"x\":}","\"bad\\q\"","\"\\uD800\"","\"\\uDC00\"","{\"a\" 1}","'single'","+1"))failure(EditValues.Code.INVALID_FORMAT,()->convert(invalid,c,Engine.MYSQL));
        failure(EditValues.Code.VALUE_LIMIT,()->convert("[".repeat(66)+"0"+"]".repeat(66),c,Engine.POSTGRESQL));
        failure(EditValues.Code.VALUE_LIMIT,()->convert("["+"0,".repeat(65_536)+"0]",c,Engine.MYSQL));
        failure(EditValues.Code.VALUE_LIMIT,()->convert("{\"n\":1e1000000000}",c,Engine.POSTGRESQL));
        assertEquals("\"\\u0000\"",convert("\"\\u0000\"",c,Engine.POSTGRESQL).getJson());
        failure(EditValues.Code.INVALID_FORMAT,()->convert("\"\\u0000\"",column("jsonb",Types.OTHER,0,0),Engine.POSTGRESQL));
    }
    @Test void textUnicodeLengthAndOpaqueNativeValuesAreValidatedWithoutGuessing() {
        var c=column("varchar(2)",Types.VARCHAR,2,0);
        assertEquals("😀é",convert("😀é",c,Engine.POSTGRESQL).getText());
        failure(EditValues.Code.OUT_OF_RANGE,()->convert("😀éz",c,Engine.POSTGRESQL));
        failure(EditValues.Code.INVALID_FORMAT,()->convert("\ud800",c,Engine.MYSQL));
        failure(EditValues.Code.INVALID_FORMAT,()->convert("\u0000",c,Engine.POSTGRESQL));
        assertEquals("\u0000",convert("\u0000",c,Engine.MYSQL).getText());
        var opaque=column("interval",Types.OTHER,0,0);var original=Value.newBuilder().setEngineValue(EngineValue.newBuilder().setTypeName("interval").setText("1 month")).build();
        assertEquals(original,EditValues.convert(original,opaque,Engine.POSTGRESQL,original));
        failure(EditValues.Code.INVALID_TYPE,()->EditValues.convert(original.toBuilder().setEngineValue(original.getEngineValue().toBuilder().setTypeName("other")).build(),opaque,Engine.POSTGRESQL,original));
        failure(EditValues.Code.UNSUPPORTED,()->EditValues.convert(original.toBuilder().setEngineValue(original.getEngineValue().toBuilder().setText("2 months")).build(),opaque,Engine.POSTGRESQL,original));
        failure(EditValues.Code.UNSUPPORTED,()->convert("unverified enum label",column("app.status",Types.OTHER,0,0).toBuilder().putProperties("nativeTypeKind","e").build(),Engine.POSTGRESQL));
    }
    @Test void onlyProvenBuiltinAliasesAcceptAnUnchangedRetainedOpaqueValue() {
        var original=Value.newBuilder().setEngineValue(EngineValue.newBuilder().setTypeName("timestamp").setText("infinity")).build();
        assertEquals(original,EditValues.convert(original,column("timestamp(6) without time zone",Types.TIMESTAMP,29,6),Engine.POSTGRESQL,original));
        failure(EditValues.Code.INVALID_TYPE,()->EditValues.convert(original,column("timestamp with time zone",Types.TIMESTAMP_WITH_TIMEZONE,35,6),Engine.POSTGRESQL,original));
        failure(EditValues.Code.INVALID_TYPE,()->EditValues.convert(original,column("public.timestamp",Types.OTHER,0,0),Engine.POSTGRESQL,original));
        failure(EditValues.Code.INVALID_TYPE,()->EditValues.convert(original,column("datetime",Types.TIMESTAMP,26,6),Engine.MYSQL,original));
    }
    @Test void domainDescriptorsAndNullabilityComeFromCentralNativeProperties() {
        var c=column("public.amount",Types.DISTINCT,10,2).toBuilder().putProperties("nativeTypeKind","d").putProperties("domainBaseType","numeric(10,2)").putProperties("nullable","NO").build();
        var type=SqlTypes.column(c,Engine.POSTGRESQL);assertEquals(SqlTypes.Family.DOMAIN,type.family());assertEquals(SqlTypes.Family.DECIMAL,type.element().family());assertFalse(type.nullable());
        assertEquals("12.30",convert("12.3",c,Engine.POSTGRESQL).getDecimal());
        for(String no:List.of("NO","false","0"))assertFalse(SqlTypes.column(c.toBuilder().putProperties("nullable",no).build(),Engine.POSTGRESQL).nullable());
        for(String uncertain:List.of("UNKNOWN","","YES"))assertTrue(SqlTypes.column(c.toBuilder().putProperties("nullable",uncertain).build(),Engine.POSTGRESQL).nullable());
    }
    @Test void completeEnumLabelsPermitOnlyVerifiedMembersAndUuidParsingIsStrict() {
        var c=column("app.status",Types.OTHER,0,0).toBuilder().putProperties("nativeTypeKind","e").putProperties("enumLabelsAvailability","AVAILABLE").putProperties("enumLabelCount","2").putProperties("enumLabel.0","first").putProperties("enumLabel.1","other").build();
        assertEquals("other",convert("other",c,Engine.POSTGRESQL).getText());failure(EditValues.Code.OUT_OF_RANGE,()->convert("missing",c,Engine.POSTGRESQL));
        var uuid=column("uuid",Types.OTHER,0,0);String exact="00112233-4455-6677-8899-aabbccddeeff";
        assertEquals(exact,convert(exact,uuid,Engine.POSTGRESQL).getEngineValue().getText());
        failure(EditValues.Code.INVALID_FORMAT,()->convert("1-1-1-1-1",uuid,Engine.POSTGRESQL));
    }
    @Test void arraysRequireExactRetainedProofAndStayCompleteAndBounded() {
        var column=column("integer[]",Types.ARRAY,0,0);var array=Value.newBuilder().setArray(ArrayValue.newBuilder().addValues(Value.newBuilder().setSignedInteger("123")).addValues(Value.newBuilder().setNullValue(Null.getDefaultInstance()))).build();
        assertEquals(array,EditValues.convert(array,column,Engine.POSTGRESQL,array));
        failure(EditValues.Code.UNSUPPORTED,()->EditValues.convert(array,column,Engine.POSTGRESQL,null));
        var modified=array.toBuilder().setArray(array.getArray().toBuilder().setValues(0,Value.newBuilder().setSignedInteger("124"))).build();
        failure(EditValues.Code.UNSUPPORTED,()->EditValues.convert(modified,column,Engine.POSTGRESQL,array));
        var incomplete=Value.newBuilder().setArray(ArrayValue.newBuilder().addValues(Value.newBuilder().setText("preview").setTruncated(true))).build();
        failure(EditValues.Code.INCOMPLETE_VALUE,()->EditValues.convert(incomplete,column,Engine.POSTGRESQL,incomplete));
        var many=Value.newBuilder().setArray(ArrayValue.newBuilder().addAllValues(Collections.nCopies(1024,text("v")))).build();
        failure(EditValues.Code.VALUE_LIMIT,()->EditValues.convert(many,column,Engine.POSTGRESQL,many));
    }
    @Test void incompleteAssignmentsAndDiagnosticsNeverRetainSensitiveParserInputs() {
        var c=column("integer",Types.INTEGER,10,0);String secret="password=never-include-this";
        var failure=assertThrows(EditValues.Failure.class,()->convert(secret,c,Engine.POSTGRESQL));assertFalse(failure.getMessage().contains(secret));assertNull(failure.getCause());
        failure(EditValues.Code.INCOMPLETE_VALUE,()->EditValues.convert(text("1").toBuilder().setTruncated(true).build(),c,Engine.POSTGRESQL,null));
        failure(EditValues.Code.INCOMPLETE_VALUE,()->EditValues.convert(text("1").toBuilder().setValueId("retained-value").build(),c,Engine.POSTGRESQL,null));
        failure(EditValues.Code.INCOMPLETE_VALUE,()->EditValues.convert(Value.newBuilder().setNullValue(Null.getDefaultInstance()).build(),c,Engine.POSTGRESQL,null));
        failure(EditValues.Code.VALUE_LIMIT,()->convert("s".repeat(EditValues.MAX_TEXT_UNITS+1),column("text",Types.VARCHAR,0,0),Engine.POSTGRESQL));
    }
}
