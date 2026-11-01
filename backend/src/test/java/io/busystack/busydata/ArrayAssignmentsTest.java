package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.results.*;
import io.busystack.busydata.schema.EditValues;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class ArrayAssignmentsTest {
    private static SchemaObject column(String declaration,String element,String oid){return SchemaObject.newBuilder().setKind(ObjectKind.COLUMN).setName("values").putProperties("type",declaration).putProperties("nativeTypeAvailability","AVAILABLE").putProperties("nativeTypeId","1007").putProperties("arrayElementSchema","pg_catalog").putProperties("arrayElementKind","b").putProperties("arrayElementType",element).putProperties("arrayElementTypeId",oid).putProperties("arrayElementDelimiter",",").build();}
    private static SchemaObject integers(){return column("integer[]","int4","23");}
    private static Value convert(String literal,SchemaObject column){return EditValues.convert(Value.newBuilder().setText(literal).build(),column,Engine.POSTGRESQL,null);}
    private static String quoted(String value){return "{\""+value.replace("\\","\\\\").replace("\"","\\\"")+"\"}";}
    @Test void boundsAndRectangularDimensionsKeepTheirExactNativeRepresentation(){
        String literal="[0:1][-2:-1]={{1,2},{3,NULL}}";var value=convert(literal,integers());assertEquals(literal,value.getArray().getNativeLiteral());assertEquals("int4",value.getArray().getElementNativeType());assertEquals("2",value.getArray().getValues(0).getArray().getValues(1).getSignedInteger());assertTrue(value.getArray().getValues(1).getArray().getValues(1).hasNullValue());assertEquals("{}",convert("{}",integers()).getArray().getNativeLiteral());assertEquals("1",convert("[1]={1}",integers()).getArray().getValues(0).getSignedInteger());
    }
    @Test void exactIntegerAndDecimalScalarsReuseTheSharedNativeValidation(){
        assertEquals("9223372036854775807",convert("{9223372036854775807}",column("bigint[]","int8","20")).getArray().getValues(0).getSignedInteger());assertEquals(EditValues.Code.OUT_OF_RANGE,assertThrows(EditValues.Failure.class,()->convert("{9223372036854775808}",column("bigint[]","int8","20"))).code());
        String number="12345678901234567890.123456789012345678";assertEquals(number,convert("{"+number+"}",column("numeric[]","numeric","1700")).getArray().getValues(0).getDecimal());assertEquals("99.99",convert("{99.99}",column("numeric(4,2)[]","numeric","1700")).getArray().getValues(0).getDecimal());assertEquals(EditValues.Code.LOSS_OF_PRECISION,assertThrows(EditValues.Failure.class,()->convert("{1.234}",column("numeric(4,2)[]","numeric","1700"))).code());
    }
    @Test void quotedEscapedEmptyAndNullTextElementsAreDistinct(){
        String literal="{\"a,b\",\"brace{value}\",\"quote\\\"slash\\\\\",\"\",NULL,\"NULL\",N\\ULL, spaced value ,\\ value\\ }";var values=convert(literal,column("text[]","text","25")).getArray().getValuesList();assertEquals("a,b",values.get(0).getText());assertEquals("brace{value}",values.get(1).getText());assertEquals("quote\"slash\\",values.get(2).getText());assertEquals("",values.get(3).getText());assertTrue(values.get(4).hasNullValue());assertEquals("NULL",values.get(5).getText());assertEquals("NULL",values.get(6).getText());assertEquals("spaced value",values.get(7).getText());assertEquals(" value ",values.get(8).getText());
    }
    @Test void nativeBooleanSpellingsAndCanonicalTemporalUuidJsonAndByteaValuesAreTyped(){
        var booleans=convert("{t,F,yes,no,on,off,1,0,tr,fa}",column("boolean[]","bool","16")).getArray().getValuesList();for(int index=0;index<booleans.size();index++)assertEquals(index%2==0,booleans.get(index).getBoolean());
        assertEquals("00000000-0000-0000-0000-000000000001",convert("{00000000-0000-0000-0000-000000000001}",column("uuid[]","uuid","2950")).getArray().getValues(0).getEngineValue().getText());assertEquals("2024-01-02",convert("{2024-01-02}",column("date[]","date","1082")).getArray().getValues(0).getTemporal().getIso());
        assertEquals("2024-01-02T12:00:00.123",convert(quoted("2024-01-02 12:00:00.123"),column("timestamp(3) without time zone[]","timestamp","1114")).getArray().getValues(0).getTemporal().getIso());assertTrue(convert(quoted("2024-01-02 12:00:00+00"),column("timestamp with time zone[]","timestamptz","1184")).getArray().getValues(0).getTemporal().getIso().endsWith("Z"));
        String json="{\"x\":1.230000000000000001}";assertEquals(json,convert(quoted(json),column("jsonb[]","jsonb","3802")).getArray().getValues(0).getJson());assertEquals("00ff",HexFormat.of().formatHex(convert(quoted("\\x00ff"),column("bytea[]","bytea","17")).getArray().getValues(0).getBinary().toByteArray()));
    }
    @Test void malformedArraysDimensionsMixedLevelsAndIncompleteQuotedValuesAreRejected(){
        for(String literal:List.of("","{} trailing","{1,}","{,1}","{{1},{1,2}}","{1,{2}}","{\"unterminated}","{a\"b}","[0:2]={1,2}","[ 0:1]={1,2}"))assertEquals(EditValues.Code.INVALID_FORMAT,assertThrows(EditValues.Failure.class,()->convert(literal,integers()),literal).code());
        for(String literal:List.of("[2:0]={1}","[2147483647:2147483647]={1}","[-2147483649:-2147483649]={1}"))assertEquals(EditValues.Code.OUT_OF_RANGE,assertThrows(EditValues.Failure.class,()->convert(literal,integers())).code());assertEquals(EditValues.Code.UNSUPPORTED,assertThrows(EditValues.Failure.class,()->convert("{{}}",integers())).code());
    }
    @Test void nativeEvidenceCannotBeInferredFromAnIdentifierOrForgedPreviewTree(){
        for(var column:List.of(integers().toBuilder().putProperties("arrayElementSchema","public").build(),integers().toBuilder().putProperties("arrayElementKind","d").build(),integers().toBuilder().putProperties("arrayElementDelimiter",";").build(),integers().toBuilder().putProperties("arrayElementTypeId","99999").build(),integers().toBuilder().removeProperties("arrayElementDelimiter").build()))assertEquals(EditValues.Code.UNSUPPORTED,assertThrows(EditValues.Failure.class,()->convert("{1}",column)).code());
        var forged=Value.newBuilder().setArray(ArrayValue.newBuilder().setNativeLiteral("{1}").setElementNativeType("unverified").addValues(Value.newBuilder().setSignedInteger("999"))).build();var validated=EditValues.convert(forged,integers(),Engine.POSTGRESQL,null);assertEquals("1",validated.getArray().getValues(0).getSignedInteger());assertEquals("int4",validated.getArray().getElementNativeType());
    }
    @Test void itemDimensionAndSourceBudgetsRejectBeforeUnboundedParsing(){
        assertEquals(1024,convert("{"+String.join(",",Collections.nCopies(1024,"1"))+"}",integers()).getArray().getValuesCount());assertEquals(EditValues.Code.VALUE_LIMIT,assertThrows(EditValues.Failure.class,()->convert("{"+String.join(",",Collections.nCopies(1025,"1"))+"}",integers())).code());assertEquals(EditValues.Code.VALUE_LIMIT,assertThrows(EditValues.Failure.class,()->convert("{".repeat(7)+"1"+"}".repeat(7),integers())).code());assertEquals(EditValues.Code.VALUE_LIMIT,assertThrows(EditValues.Failure.class,()->convert("{"+"1".repeat(16384)+"}",integers())).code());for(String literal:List.of("{\0}","{\ud800}"))assertEquals(EditValues.Code.INVALID_FORMAT,assertThrows(EditValues.Failure.class,()->convert(literal,integers())).code());
    }
    @Test void exactNumericExpansionHasAnAggregateBudgetBeforeTheReviewTreeAccumulates(){assertEquals(EditValues.Code.VALUE_LIMIT,assertThrows(EditValues.Failure.class,()->convert("{"+String.join(",",Collections.nCopies(32,"1e60000"))+"}",column("numeric[]","numeric","1700"))).code());}
    @Test void bindingAdmissionCountsScalarItemsRatherThanRectangularArrayContainers()throws Exception {String row="{"+String.join(",",Collections.nCopies(32,"1"))+"}",literal="  {"+String.join(",",Collections.nCopies(32,row))+"}\r\n";var value=convert(literal,integers());assertEquals(literal,value.getArray().getNativeLiteral());ArrayParameters.validate(value);}
    @Test void opaqueRetainedNativeArraysRemainAvailableOnlyWithTheirOriginalProof(){
        var original=Value.newBuilder().setArray(ArrayValue.newBuilder().setNativeLiteral("{opaque}").setElementNativeType("custom").addValues(Value.newBuilder().setEngineValue(EngineValue.newBuilder().setTypeName("custom").setText("opaque")))).build();var custom=column("public.custom[]","custom","99999");assertSame(original,EditValues.convert(original,custom,Engine.POSTGRESQL,original));assertEquals(EditValues.Code.UNSUPPORTED,assertThrows(EditValues.Failure.class,()->EditValues.convert(original,custom,Engine.POSTGRESQL,null)).code());
    }
}
