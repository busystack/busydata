package io.busystack.busydata.results;

import io.busystack.busydata.analysis.SqlLexicalCharacters;
import io.busystack.busydata.analysis.language.SqlTypes;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.EditValues;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.regex.Pattern;

/** Pure PostgreSQL array input validation against one verified native column.
 * Array syntax is distinct from SQL syntax. Original bounds/literal bytes are
 * retained; the review tree contains scalar values from the shared converter. */
public final class ArrayAssignments {
    public static final int MAX_UNITS=16384,MAX_ITEMS=1024,MAX_DIMENSIONS=6;
    private static final Map<String,String> BUILTINS=Map.ofEntries(Map.entry("int2","21"),Map.entry("int4","23"),Map.entry("int8","20"),Map.entry("numeric","1700"),Map.entry("float4","700"),Map.entry("float8","701"),Map.entry("bool","16"),Map.entry("text","25"),Map.entry("varchar","1043"),Map.entry("bpchar","1042"),Map.entry("bytea","17"),Map.entry("uuid","2950"),Map.entry("date","1082"),Map.entry("time","1083"),Map.entry("timetz","1266"),Map.entry("timestamp","1114"),Map.entry("timestamptz","1184"),Map.entry("json","114"),Map.entry("jsonb","3802"));
    private static final Pattern MODIFIERS=Pattern.compile("\\(\\s*([+-]?[0-9]+)\\s*(?:,\\s*([+-]?[0-9]+)\\s*)?\\)");
    public static final class Failure extends IllegalArgumentException {
        private final EditValues.Code code;
        private Failure(EditValues.Code code){super("Array assignment validation: "+code.name());this.code=code;}
        public EditValues.Code code(){return code;}
    }
    private ArrayAssignments(){}
    private static Failure fail(EditValues.Code code){return new Failure(code);}
    public static Value convert(Value input,SchemaObject column){
        if(input.getTruncated()||!input.getValueId().isEmpty())throw fail(EditValues.Code.INCOMPLETE_VALUE);
        String literal;
        if(input.hasText())literal=input.getText();
        else if(input.hasArray()&&input.getArray().getNativeBinary().isEmpty())literal=input.getArray().getNativeLiteral();
        else throw fail(EditValues.Code.UNSUPPORTED);
        if(literal.length()>MAX_UNITS||literal.getBytes(StandardCharsets.UTF_8).length>65536)throw fail(EditValues.Code.VALUE_LIMIT);
        for(int at=0;at<literal.length();at++){char unit=literal.charAt(at);if(unit==0)throw fail(EditValues.Code.INVALID_FORMAT);if(Character.isHighSurrogate(unit)){if(++at==literal.length()||!Character.isLowSurrogate(literal.charAt(at)))throw fail(EditValues.Code.INVALID_FORMAT);}else if(Character.isLowSurrogate(unit))throw fail(EditValues.Code.INVALID_FORMAT);}
        String name=column.getPropertiesOrDefault("arrayElementType","");
        if(!column.getPropertiesOrDefault("nativeTypeAvailability","").equals("AVAILABLE")||!column.getPropertiesOrDefault("arrayElementSchema","").equals("pg_catalog")||!column.getPropertiesOrDefault("arrayElementKind","").equals("b")||!column.getPropertiesOrDefault("arrayElementDelimiter","").equals(",")||!BUILTINS.getOrDefault(name,"").equals(column.getPropertiesOrDefault("arrayElementTypeId",""))||!BUILTINS.containsKey(name))throw fail(EditValues.Code.UNSUPPORTED);
        var scalar=scalarColumn(column,name);var parser=new Parser(literal,scalar);var parsed=parser.parse();
        var array=parsed.value().getArray().toBuilder().setNativeLiteral(literal).setElementNativeType(name);
        var result=Value.newBuilder().setArray(array).build();if(result.getSerializedSize()>1_048_576)throw fail(EditValues.Code.VALUE_LIMIT);return result;
    }
    private static SchemaObject scalarColumn(SchemaObject column,String elementName){
        String declaration=column.getPropertiesOrDefault("type","").trim();if(!declaration.endsWith("[]"))throw fail(EditValues.Code.METADATA_UNAVAILABLE);declaration=declaration.substring(0,declaration.length()-2).trim();
        if(!SqlTypes.sameBuiltinTypeName(declaration,elementName,Engine.POSTGRESQL))throw fail(EditValues.Code.METADATA_UNAVAILABLE);
        var scalar=SchemaObject.newBuilder().setKind(ObjectKind.COLUMN).setName(column.getName()).putProperties("type",declaration).putProperties("nullable","YES");var type=SqlTypes.nativeType(declaration,Engine.POSTGRESQL);var modifiers=MODIFIERS.matcher(declaration);
        if(modifiers.find())try{
            int first=Integer.parseInt(modifiers.group(1));
            if(type.family()==SqlTypes.Family.DECIMAL){if(first<1||first>1000)throw fail(EditValues.Code.METADATA_UNAVAILABLE);int scale=modifiers.group(2)==null?0:Integer.parseInt(modifiers.group(2));if(scale< -1000||scale>1000)throw fail(EditValues.Code.METADATA_UNAVAILABLE);scalar.putProperties("precision",Integer.toString(first)).putProperties("scale",Integer.toString(scale));}
            else if(type.family()==SqlTypes.Family.TEXT){if(first<1||modifiers.group(2)!=null)throw fail(EditValues.Code.METADATA_UNAVAILABLE);scalar.putProperties("precision",Integer.toString(first));}
            else if(type.family()==SqlTypes.Family.TIME||type.family()==SqlTypes.Family.TIMESTAMP){if(first<0||first>6||modifiers.group(2)!=null)throw fail(EditValues.Code.METADATA_UNAVAILABLE);scalar.putProperties("scale",Integer.toString(first));}
            else throw fail(EditValues.Code.METADATA_UNAVAILABLE);
        }catch(NumberFormatException invalid){throw fail(EditValues.Code.METADATA_UNAVAILABLE);}
        return scalar.build();
    }
    private record Parsed(Value value,List<Integer> shape){private Parsed{shape=List.copyOf(shape);}}
    private static final class Parser {
        private final String source;private final SchemaObject scalar;private final SqlTypes.Type type;private int at,items,nodes,valueBytes;
        private Parser(String source,SchemaObject scalar){this.source=source;this.scalar=scalar;type=SqlTypes.column(scalar,Engine.POSTGRESQL);}
        private Parsed parse(){
            spaces();var dimensions=new ArrayList<Integer>();
            while(take('[')){
                if(dimensions.size()>=MAX_DIMENSIONS)throw fail(EditValues.Code.VALUE_LIMIT);int first=bound(),lower=1,upper=first;if(take(':')){lower=first;upper=bound();}require(']');long length=(long)upper-lower+1;if(upper==Integer.MAX_VALUE||length<1||length>MAX_ITEMS)throw fail(EditValues.Code.OUT_OF_RANGE);dimensions.add((int)length);spaces();
            }
            if(!dimensions.isEmpty()){require('=');spaces();}var parsed=array(1);spaces();if(at!=source.length())throw fail(EditValues.Code.INVALID_FORMAT);if(!dimensions.isEmpty()&&!dimensions.equals(parsed.shape()))throw fail(EditValues.Code.INVALID_FORMAT);return parsed;
        }
        private Parsed array(int depth){
            if(depth>MAX_DIMENSIONS||++nodes>MAX_ITEMS*MAX_DIMENSIONS)throw fail(EditValues.Code.VALUE_LIMIT);require('{');spaces();var values=new ArrayList<Value>();List<Integer> inner=null;Boolean nested=null;
            if(take('}')){if(depth!=1)throw fail(EditValues.Code.UNSUPPORTED);return new Parsed(Value.newBuilder().setArray(ArrayValue.getDefaultInstance()).build(),List.of(0));}
            for(;;){
                spaces();boolean child=peek('{');if(nested!=null&&nested!=child)throw fail(EditValues.Code.INVALID_FORMAT);nested=child;
                if(child){var parsed=array(depth+1);if(inner!=null&&!inner.equals(parsed.shape()))throw fail(EditValues.Code.INVALID_FORMAT);inner=parsed.shape();values.add(parsed.value());}
                else {if(++items>MAX_ITEMS)throw fail(EditValues.Code.VALUE_LIMIT);var element=element();valueBytes+=element.getSerializedSize();if(valueBytes>1_048_576)throw fail(EditValues.Code.VALUE_LIMIT);values.add(element);}
                spaces();if(take('}'))break;require(',');spaces();if(peek('}'))throw fail(EditValues.Code.INVALID_FORMAT);
            }
            var shape=new ArrayList<Integer>();shape.add(values.size());if(inner!=null)shape.addAll(inner);return new Parsed(Value.newBuilder().setArray(ArrayValue.newBuilder().addAllValues(values)).build(),shape);
        }
        private Value element(){
            boolean quoted=take('"'),escaped=false;var raw=new StringBuilder();int meaningful=0;
            if(quoted){boolean closed=false;while(at<source.length()){char unit=source.charAt(at++);if(unit=='"'){closed=true;break;}if(unit=='\\'){if(at==source.length())throw fail(EditValues.Code.INVALID_FORMAT);unit=source.charAt(at++);}raw.append(unit);}if(!closed)throw fail(EditValues.Code.INVALID_FORMAT);spaces();if(!peek(',')&&!peek('}'))throw fail(EditValues.Code.INVALID_FORMAT);}
            else {
                while(at<source.length()&&!peek(',')&&!peek('}')){char unit=source.charAt(at++);if(unit=='{'||unit=='"')throw fail(EditValues.Code.INVALID_FORMAT);if(unit=='\\'){if(at==source.length())throw fail(EditValues.Code.INVALID_FORMAT);unit=source.charAt(at++);escaped=true;raw.append(unit);meaningful=raw.length();}else {raw.append(unit);if(!SqlLexicalCharacters.isSpace(unit))meaningful=raw.length();}}
                raw.setLength(meaningful);if(raw.isEmpty())throw fail(EditValues.Code.INVALID_FORMAT);
            }
            if(!quoted&&!escaped&&raw.toString().equalsIgnoreCase("NULL"))return Values.nil();
            String text=raw.toString();
            if(type.family()!=SqlTypes.Family.TEXT&&type.family()!=SqlTypes.Family.JSON&&type.family()!=SqlTypes.Family.JSONB)text=trimSpaces(text);
            if(Set.of(SqlTypes.Family.INTEGER,SqlTypes.Family.DECIMAL,SqlTypes.Family.REAL,SqlTypes.Family.DATE,SqlTypes.Family.TIME,SqlTypes.Family.TIMESTAMP).contains(type.family())&&Set.of("NAN","INFINITY","+INFINITY","-INFINITY","INF","+INF","-INF").contains(text.toUpperCase(Locale.ROOT)))throw fail(EditValues.Code.UNSUPPORTED);
            if(type.family()==SqlTypes.Family.BOOLEAN){String word=text.toLowerCase(Locale.ROOT);boolean yes=List.of("true","yes","on","1").stream().anyMatch(value->!word.isEmpty()&&value.startsWith(word)),no=List.of("false","no","off","0").stream().anyMatch(value->!word.isEmpty()&&value.startsWith(word));if(yes==no)throw fail(EditValues.Code.INVALID_FORMAT);text=yes?"true":"false";}
            if(type.family()==SqlTypes.Family.BINARY&&!text.startsWith("\\x"))throw fail(EditValues.Code.UNSUPPORTED);
            if(type.family()==SqlTypes.Family.TIMESTAMP&&text.length()>10&&text.charAt(10)==' ')text=text.substring(0,10)+'T'+text.substring(11);
            if(type.timezone()&&text.matches(".*[+-][0-9]{2}"))text+=":00";
            return EditValues.convert(Value.newBuilder().setText(text).build(),scalar,Engine.POSTGRESQL,null);
        }
        private int bound(){int start=at;if(peek('+')||peek('-'))at++;int digits=at;while(at<source.length()&&source.charAt(at)>='0'&&source.charAt(at)<='9')at++;if(digits==at)throw fail(EditValues.Code.INVALID_FORMAT);try{return Integer.parseInt(source.substring(start,at));}catch(NumberFormatException invalid){throw fail(EditValues.Code.OUT_OF_RANGE);}}
        private void spaces(){while(at<source.length()&&SqlLexicalCharacters.isSpace(source.charAt(at)))at++;}
        private boolean peek(char value){return at<source.length()&&source.charAt(at)==value;}
        private boolean take(char value){if(!peek(value))return false;at++;return true;}
        private void require(char value){if(!take(value))throw fail(EditValues.Code.INVALID_FORMAT);}
    }
    private static String trimSpaces(String value){int start=0,end=value.length();while(start<end&&SqlLexicalCharacters.isSpace(value.charAt(start)))start++;while(end>start&&SqlLexicalCharacters.isSpace(value.charAt(end-1)))end--;return value.substring(start,end);}
}
