package io.busystack.busydata;

import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.EditValues;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import static org.junit.jupiter.api.Assertions.*;

class NativeEnumSetTest {
    private static Value text(String value){return Value.newBuilder().setText(value).build();}
    private static SchemaObject evidence(Engine engine,String declaration,String kind){return EditTypeEvidence.forColumn(MetadataSnapshot.empty("source","profile",new IdentifierRules(engine,0)),SchemaObject.newBuilder().setKind(ObjectKind.COLUMN).setName("value").putProperties("type",declaration).putProperties("nativeTypeKind",kind).putProperties("nativeTypeAvailability","AVAILABLE").build());}
    @ParameterizedTest @EnumSource(value=Engine.class,names={"MYSQL","MARIADB"})
    void canonicalNativeEscapesPreserveExactLabelsIndependentlyOfSqlMode(Engine engine){
        var decoded=NativeEnumSet.decode("enum('','quote''value','back\\\\slash','line\\nvalue','carriage\\rvalue','zero\\0value','漢😀','tab\tvalue')",engine);
        assertTrue(decoded.available());assertEquals(NativeEnumSet.Kind.ENUM,decoded.kind());assertEquals(List.of("","quote'value","back\\slash","line\nvalue","carriage\rvalue","zero\0value","漢😀","tab\tvalue"),decoded.members());
        var literalSlash=NativeEnumSet.decode("enum('literal\\\\n')",engine);assertEquals(List.of("literal\\n"),literalSlash.members());
    }
    @Test void malformedUnknownAndHexFormsDoNotProducePartialEvidence(){
        for(String declaration:List.of("enum()","enum('a'","enum('a',)","enum('a') extra","enum('raw\nline')","enum('raw\0zero')","enum('a' 'b')","enum('a', 'b')")){var result=NativeEnumSet.decode(declaration,Engine.MYSQL);assertFalse(result.available(),declaration);assertTrue(result.members().isEmpty());}
        for(String declaration:List.of("enum(x'ff')","enum('a\\t')","enum('a\\q')","enum('a\\'b')"))assertEquals(NativeEnumSet.Availability.UNSUPPORTED,NativeEnumSet.decode(declaration,Engine.MYSQL).availability());
        assertEquals(NativeEnumSet.Availability.UNSUPPORTED,NativeEnumSet.decode("enum('a')",Engine.POSTGRESQL).availability());
        assertFalse(NativeEnumSet.decode("enum('\ud800')",Engine.MYSQL).available());
    }
    @Test void declarationAndMemberBudgetsAreExplicit(){
        assertEquals(NativeEnumSet.Availability.LIMITED,NativeEnumSet.decode("enum('"+"x".repeat(32768)+"')",Engine.MYSQL).availability());
        assertEquals(NativeEnumSet.Availability.LIMITED,NativeEnumSet.decode("enum("+String.join(",",Collections.nCopies(1025,"'x'"))+")",Engine.MYSQL).availability());
        assertEquals(NativeEnumSet.Availability.LIMITED,NativeEnumSet.decode("set("+String.join(",",Collections.nCopies(65,"'x'"))+")",Engine.MYSQL).availability());
        assertTrue(NativeEnumSet.decode("set('a','a')",Engine.MYSQL).available(),"Decoding must preserve native duplicates rather than normalize metadata");
    }
    @ParameterizedTest @EnumSource(value=Engine.class,names={"MYSQL","MARIADB"})
    void exactEnumAndCanonicalSetInputsAreValidatedWithoutServerNormalization(Engine engine){
        var enumeration=evidence(engine,"enum('','quote''value','back\\\\slash','line\\nvalue')","enum");assertEquals("AVAILABLE",enumeration.getPropertiesOrThrow("enumLabelsAvailability"));
        for(String value:List.of("","quote'value","back\\slash","line\nvalue"))assertEquals(text(value),EditValues.convert(text(value),enumeration,engine,null));
        assertThrows(EditValues.Failure.class,()->EditValues.convert(text("QUOTE'value"),enumeration,engine,null));
        var set=evidence(engine,"set('one','quote''value','back\\\\slash','line\\nvalue')","set");assertEquals("AVAILABLE",set.getPropertiesOrThrow("setMembersAvailability"));
        for(String value:List.of("","one","quote'value,back\\slash","one,line\nvalue"))assertEquals(text(value),EditValues.convert(text(value),set,engine,null));
        for(String invalid:List.of("back\\slash,one","one,one","one,","ONE","1","unknown"))assertThrows(EditValues.Failure.class,()->EditValues.convert(text(invalid),set,engine,null),invalid);
        for(String declaration:List.of("set('','a')","set('a,b','c')","set('a','a')"))assertEquals(EditValues.Code.UNSUPPORTED,assertThrows(EditValues.Failure.class,()->EditValues.convert(text("a"),evidence(engine,declaration,"set"),engine,null)).code());
    }
}
