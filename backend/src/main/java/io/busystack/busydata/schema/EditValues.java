package io.busystack.busydata.schema;

import com.google.protobuf.ByteString;
import io.busystack.busydata.analysis.language.SqlTypes;
import io.busystack.busydata.protocol.*;
import java.math.*;
import java.sql.Types;
import java.time.*;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.regex.Pattern;

/** Pure, bounded edit conversion against one captured authoritative column.
 * No JDBC, SQL execution, locale parsing or driver-dependent coercion occurs here.
 * The caller handles NULL/DEFAULT and verifies result/row/metadata ownership.
 */
public final class EditValues {
    public static final int MAX_TEXT_UNITS=262_144,MAX_VALUE_BYTES=1_048_576,MAX_DECIMAL_CHARS=65_536;
    private static final Pattern INTEGER=Pattern.compile("[+-]?[0-9]+"),NUMBER=Pattern.compile("[+-]?(?:[0-9]+(?:\\.[0-9]*)?|\\.[0-9]+)(?:[eE][+-]?[0-9]+)?");
    private static final Pattern DATE=Pattern.compile("[+-]?[0-9]{4,9}-[0-9]{2}-[0-9]{2}"),TIME=Pattern.compile("[0-9]{2}:[0-9]{2}(?::[0-9]{2}(?:\\.[0-9]{1,9})?)?"),DURATION=Pattern.compile("(-?)([0-9]{2,3}):([0-9]{2})(?::([0-9]{2})(?:\\.([0-9]{1,9}))?)?");
    public enum Code { INCOMPLETE_VALUE,INVALID_TYPE,INVALID_FORMAT,OUT_OF_RANGE,LOSS_OF_PRECISION,VALUE_LIMIT,METADATA_UNAVAILABLE,UNSUPPORTED }
    /** Fixed safe descriptions deliberately exclude user values and parser causes. */
    public static final class Failure extends IllegalArgumentException {
        private final Code code;
        private Failure(Code code){super("Edit value validation: "+code.name());this.code=code;}
        public Code code(){return code;}
    }
    private EditValues(){}
    private static Failure fail(Code code){return new Failure(code);}

    public static Value convert(Value input,SchemaObject column,Engine engine,Value original) {
        Objects.requireNonNull(input);Objects.requireNonNull(column);Objects.requireNonNull(engine);
        if(engine!=Engine.POSTGRESQL&&engine!=Engine.MYSQL&&engine!=Engine.MARIADB)throw fail(Code.UNSUPPORTED);
        if(input.getDataCase()==Value.DataCase.DATA_NOT_SET||input.hasNullValue()||input.getTruncated()||!input.getValueId().isEmpty())throw fail(Code.INCOMPLETE_VALUE);
        if(input.getSerializedSize()>MAX_VALUE_BYTES)throw fail(Code.VALUE_LIMIT);
        var type=SqlTypes.column(column,engine);
        if(type.family()==SqlTypes.Family.DOMAIN) {
            if(type.element()==null||!type.element().known())throw fail(Code.METADATA_UNAVAILABLE);
            type=type.element();
        }
        if(input.hasEngineValue()) {
            String exact=SqlTypes.column(column,engine).nativeName();
            if(!input.getEngineValue().getTypeName().equals(exact)&&!SqlTypes.sameBuiltinTypeName(input.getEngineValue().getTypeName(),exact,engine))throw fail(Code.INVALID_TYPE);
            text(input.getEngineValue().getText(),engine);
            if(type.family()==SqlTypes.Family.UUID)return uuid(input.getEngineValue().getText(),exact);
            if(original!=null&&input.equals(original))return input;
            throw fail(Code.UNSUPPORTED);
        }
        try {
            if(type.family()==SqlTypes.Family.BOOLEAN||engine!=Engine.POSTGRESQL&&type.family()==SqlTypes.Family.BINARY&&(type.jdbcType()==Types.BOOLEAN||type.jdbcType()==Types.BIT)&&type.precision()==1)return bool(input);
            return switch(type.family()) {
                case INTEGER->integer(input,type,engine);
                case DECIMAL->decimal(input,type);
                case REAL->real(input,type,engine);
                case BOOLEAN->bool(input);
                case TEXT->character(input,type,engine);
                case BINARY->binary(input,type,engine);
                case DATE,TIME,TIMESTAMP->temporal(input,type,column,engine);
                case JSON,JSONB->json(input,type,engine);
                case UUID->uuid(scalarText(input),type.nativeName());
                case ENUM,SET->enumerated(input,column,type,original,engine);
                case ARRAY->array(input,original,column,engine);
                case INTERVAL,USER,UNKNOWN,DOMAIN,NULL->throw fail(Code.UNSUPPORTED);
            };
        }catch(Failure failure){throw failure;}
        catch(NumberFormatException|DateTimeException|ArithmeticException exception){throw fail(Code.INVALID_FORMAT);}
    }

    private static String scalarText(Value value) {
        return switch(value.getDataCase()) {
            case TEXT->value.getText();case SIGNED_INTEGER->value.getSignedInteger();case UNSIGNED_INTEGER->value.getUnsignedInteger();case DECIMAL->value.getDecimal();
            default->throw fail(Code.INVALID_TYPE);
        };
    }
    private static String text(String value,Engine engine) {
        if(value.length()>MAX_TEXT_UNITS)throw fail(Code.VALUE_LIMIT);
        for(int i=0;i<value.length();i++) {
            char unit=value.charAt(i);
            if(unit==0&&engine==Engine.POSTGRESQL)throw fail(Code.INVALID_FORMAT);
            if(Character.isHighSurrogate(unit)){if(++i==value.length()||!Character.isLowSurrogate(value.charAt(i)))throw fail(Code.INVALID_FORMAT);}
            else if(Character.isLowSurrogate(unit))throw fail(Code.INVALID_FORMAT);
        }
        return value;
    }
    private static Value integer(Value input,SqlTypes.Type type,Engine engine) {
        if(engine==Engine.POSTGRESQL&&type.unsigned())throw fail(Code.METADATA_UNAVAILABLE);
        boolean booleanTransport=engine!=Engine.POSTGRESQL&&(type.jdbcType()==Types.BIT||type.jdbcType()==Types.BOOLEAN);
        String raw=input.hasBoolean()&&engine!=Engine.POSTGRESQL?(input.getBoolean()?"1":"0"):scalarText(input);
        if(booleanTransport&&raw.equalsIgnoreCase("true"))raw="1";else if(booleanTransport&&raw.equalsIgnoreCase("false"))raw="0";
        if(raw.length()>128)throw fail(Code.VALUE_LIMIT);
        BigInteger number;
        if(input.hasDecimal()){preflightDecimal(raw);number=new BigDecimal(raw).toBigIntegerExact();}
        else {if(!INTEGER.matcher(raw).matches())throw fail(Code.INVALID_FORMAT);number=new BigInteger(raw);}
        String name=type.nativeName().toLowerCase(Locale.ROOT).trim();
        if(name.equals("year(2)"))throw fail(Code.UNSUPPORTED);
        if((name.equals("year")||name.startsWith("year("))&&engine!=Engine.POSTGRESQL&&number.signum()!=0&&number.compareTo(BigInteger.valueOf(1901))<0)throw fail(Code.OUT_OF_RANGE);
        if(type.minimumInteger()==null||type.maximumInteger()==null)throw fail(Code.METADATA_UNAVAILABLE);
        if(number.compareTo(type.minimumInteger())<0||number.compareTo(type.maximumInteger())>0)throw fail(Code.OUT_OF_RANGE);
        return type.unsigned()?Value.newBuilder().setUnsignedInteger(number.toString()).build():Value.newBuilder().setSignedInteger(number.toString()).build();
    }
    private static void preflightDecimal(String raw) {
        if(raw.length()>MAX_DECIMAL_CHARS||!NUMBER.matcher(raw).matches())throw fail(raw.length()>MAX_DECIMAL_CHARS?Code.VALUE_LIMIT:Code.INVALID_FORMAT);
        int at=Math.max(raw.indexOf('e'),raw.indexOf('E')),exponent=0;
        if(at>=0) {
            String exp=raw.substring(at+1);int sign=exp.startsWith("-")?-1:1,index=exp.startsWith("-")||exp.startsWith("+")?1:0;
            if(exp.length()-index>6)throw fail(Code.VALUE_LIMIT);
            for(;index<exp.length();index++){exponent=exponent*10+exp.charAt(index)-'0';if(exponent>MAX_DECIMAL_CHARS)throw fail(Code.VALUE_LIMIT);}
            exponent*=sign;
        }else at=raw.length();
        int dot=raw.indexOf('.'),fraction=dot>=0?at-dot-1:0,digits=0;
        for(int i=0;i<at;i++)if(raw.charAt(i)>='0'&&raw.charAt(i)<='9')digits++;
        long scale=(long)fraction-exponent;
        if(Math.abs(scale)>MAX_DECIMAL_CHARS||digits+Math.max(0L,-scale)>MAX_DECIMAL_CHARS||Math.max(digits+1L,scale+2)>MAX_DECIMAL_CHARS)throw fail(Code.VALUE_LIMIT);
    }
    private static Value decimal(Value input,SqlTypes.Type type) {
        String raw=scalarText(input);preflightDecimal(raw);BigDecimal number=new BigDecimal(raw);
        if(type.unsigned()&&number.signum()<0)throw fail(Code.OUT_OF_RANGE);
        if(type.precision()>0) {
            if(Math.abs((long)type.scale())>MAX_DECIMAL_CHARS)throw fail(Code.METADATA_UNAVAILABLE);
            long requested=(long)number.precision()+Math.max(0L,(long)type.scale()-number.scale());
            if(requested>MAX_DECIMAL_CHARS)throw fail(Code.VALUE_LIMIT);
            try {number=number.setScale(type.scale(),RoundingMode.UNNECESSARY);}catch(ArithmeticException exception){throw fail(Code.LOSS_OF_PRECISION);}
            if(number.precision()>type.precision())throw fail(Code.OUT_OF_RANGE);
        }
        long p=number.precision(),s=number.scale(),length=s<=0?p-s:s>=p?s+2:p+1;
        if(length+(number.signum()<0?1:0)>MAX_DECIMAL_CHARS)throw fail(Code.VALUE_LIMIT);
        return Value.newBuilder().setDecimal(number.toPlainString()).build();
    }
    private static Value real(Value input,SqlTypes.Type type,Engine engine) {
        double number;
        if(input.hasReal())number=input.getReal();else {String raw=scalarText(input);preflightDecimal(raw);number=Double.parseDouble(raw);if(number==0&&new BigDecimal(raw).signum()!=0)throw fail(Code.OUT_OF_RANGE);}
        if(!Double.isFinite(number)||type.unsigned()&&number<0)throw fail(Code.OUT_OF_RANGE);
        String nativeName=type.nativeName().toLowerCase(Locale.ROOT);
        if(type.jdbcType()==Types.REAL||engine==Engine.POSTGRESQL&&(nativeName.equals("real")||nativeName.equals("float4"))||engine!=Engine.POSTGRESQL&&(nativeName.equals("float")||nativeName.startsWith("float("))) {
            float narrowed=(float)number;if(!Float.isFinite(narrowed)||narrowed==0&&number!=0)throw fail(Code.OUT_OF_RANGE);number=narrowed;
        }
        return Value.newBuilder().setReal(number).build();
    }
    private static Value bool(Value input) {
        if(input.hasBoolean())return Value.newBuilder().setBoolean(input.getBoolean()).build();
        String raw=scalarText(input);
        if(raw.equalsIgnoreCase("true")||raw.equals("1"))return Value.newBuilder().setBoolean(true).build();
        if(raw.equalsIgnoreCase("false")||raw.equals("0"))return Value.newBuilder().setBoolean(false).build();
        throw fail(Code.INVALID_FORMAT);
    }
    private static Value character(Value input,SqlTypes.Type type,Engine engine) {
        if(!input.hasText()&&!input.hasJson())throw fail(Code.INVALID_TYPE);
        String raw=text(input.hasText()?input.getText():input.getJson(),engine);
        if(input.hasJson())new JsonCheck(raw,false).read();
        if(type.precision()>0&&raw.codePointCount(0,raw.length())>type.precision())throw fail(Code.OUT_OF_RANGE);
        return Value.newBuilder().setText(raw).build();
    }
    private static Value binary(Value input,SqlTypes.Type type,Engine engine) {
        String name=type.nativeName().toLowerCase(Locale.ROOT).trim();
        if(engine==Engine.POSTGRESQL&&(name.startsWith("bit")||name.startsWith("varbit")))throw fail(Code.UNSUPPORTED);
        ByteString bytes;
        if(input.hasBinary())bytes=input.getBinary();
        else {
            if(!input.hasText())throw fail(Code.INVALID_TYPE);String raw=input.getText();
            if(raw.startsWith("0x")||raw.startsWith("\\x"))raw=raw.substring(2);
            if(raw.length()>MAX_TEXT_UNITS)throw fail(Code.VALUE_LIMIT);
            if((raw.length()&1)!=0)throw fail(Code.INVALID_FORMAT);
            for(int i=0;i<raw.length();i++)if(Character.digit(raw.charAt(i),16)<0||raw.charAt(i)>127)throw fail(Code.INVALID_FORMAT);
            bytes=ByteString.copyFrom(HexFormat.of().parseHex(raw));
        }
        if(bytes.size()>MAX_VALUE_BYTES-16)throw fail(Code.VALUE_LIMIT);
        if(name.startsWith("bit")&&type.precision()>1) {
            if(type.precision()>64||bytes.size()!=(type.precision()+7)/8||new BigInteger(1,bytes.toByteArray()).bitLength()>type.precision())throw fail(Code.OUT_OF_RANGE);
        }else if(type.precision()>0&&bytes.size()>type.precision())throw fail(Code.OUT_OF_RANGE);
        if((name.equals("binary")||name.startsWith("binary("))&&type.precision()>0&&bytes.size()!=type.precision())throw fail(Code.LOSS_OF_PRECISION);
        return Value.newBuilder().setBinary(bytes).build();
    }
    private static Value temporal(Value input,SqlTypes.Type type,SchemaObject column,Engine engine) {
        if(!input.hasTemporal()&&!input.hasText())throw fail(Code.INVALID_TYPE);
        String raw=input.hasTemporal()?input.getTemporal().getIso():input.getText();
        if(raw.length()>96)throw fail(Code.VALUE_LIMIT);
        int scale=column.containsProperties("scale")?type.scale():6;
        if(scale<0||scale>6)throw fail(Code.METADATA_UNAVAILABLE);
        boolean zone=type.timezone();String canonical;
        if(type.family()==SqlTypes.Family.DATE) {
            if(!DATE.matcher(raw).matches())throw fail(Code.INVALID_FORMAT);LocalDate date=LocalDate.parse(raw,DateTimeFormatter.ISO_LOCAL_DATE);dateRange(date,engine,false);canonical=date.toString();
        }else if(type.family()==SqlTypes.Family.TIME) {
            if(engine!=Engine.POSTGRESQL&&!zone) {
                var match=DURATION.matcher(raw);if(!match.matches())throw fail(Code.INVALID_FORMAT);
                int hours=Integer.parseInt(match.group(2)),minutes=Integer.parseInt(match.group(3)),seconds=match.group(4)==null?0:Integer.parseInt(match.group(4));
                if(hours>838||minutes>59||seconds>59)throw fail(Code.OUT_OF_RANGE);
                if(engine==Engine.MYSQL&&hours==838&&minutes==59&&seconds==59&&match.group(5)!=null&&match.group(5).chars().anyMatch(digit->digit!='0'))throw fail(Code.OUT_OF_RANGE);
                fraction(match.group(5),scale);String fractional=match.group(5)==null?"":match.group(5).replaceFirst("0+$","");canonical=match.group(1)+String.format(Locale.ROOT,"%02d:%02d:%02d",hours,minutes,seconds)+(fractional.isEmpty()?"":"."+fractional);
            }else if(zone) {
                var endOfDay=Pattern.compile("24:00:00(?:\\.(0{1,9}))?(Z|[+-][0-9]{2}:[0-9]{2}(?::[0-9]{2})?)").matcher(raw);
                if(endOfDay.matches()){
                    fraction(endOfDay.group(1),scale);var offset=ZoneOffset.of(endOfDay.group(2));if(Math.abs(offset.getTotalSeconds())>57_599)throw fail(Code.OUT_OF_RANGE);canonical="24:00:00"+offset.getId();
                }else {OffsetTime time=OffsetTime.parse(raw,DateTimeFormatter.ISO_OFFSET_TIME);if(Math.abs(time.getOffset().getTotalSeconds())>57_599)throw fail(Code.OUT_OF_RANGE);nanos(time.getNano(),scale);canonical=time.toString();}
            }else {
                if(raw.matches("24:00:00(?:\\.0{1,9})?")){fraction(raw.contains(".")?raw.substring(raw.indexOf('.')+1):null,scale);canonical="24:00:00";}
                else {if(!TIME.matcher(raw).matches())throw fail(Code.INVALID_FORMAT);LocalTime time=LocalTime.parse(raw,DateTimeFormatter.ISO_LOCAL_TIME);nanos(time.getNano(),scale);canonical=time.toString();}
            }
        }else if(zone) {
            if(raw.indexOf('T')<0)throw fail(Code.INVALID_FORMAT);
            OffsetDateTime time=OffsetDateTime.parse(raw,DateTimeFormatter.ISO_OFFSET_DATE_TIME);if(Math.abs(time.getOffset().getTotalSeconds())>57_599)throw fail(Code.OUT_OF_RANGE);dateRange(time.toLocalDate(),engine,true);nanos(time.getNano(),scale);canonical=time.toString();
        }else {
            if(raw.indexOf('T')<0)throw fail(Code.INVALID_FORMAT);
            LocalDateTime time=LocalDateTime.parse(raw,DateTimeFormatter.ISO_LOCAL_DATE_TIME);dateRange(time.toLocalDate(),engine,true);nanos(time.getNano(),scale);
            if(engine!=Engine.POSTGRESQL&&type.nativeName().toLowerCase(Locale.ROOT).startsWith("timestamp"))timestampRange(time,column,engine);
            canonical=time.toString();
        }
        return Value.newBuilder().setTemporal(Temporal.newBuilder().setIso(canonical).setKind(type.nativeName()).setZone(zone?"offset in value":"local, no timezone")).build();
    }
    private static void dateRange(LocalDate date,Engine engine,boolean timestamp) {
        if(engine==Engine.POSTGRESQL) {
            // The exact outer boundary dates and BC JDBC interpretation require
            // a richer native value form; do not relabel a valid edge as invalid.
            if(date.getYear()<1||date.getYear()>(timestamp?294275:5874896))throw fail(Code.UNSUPPORTED);
        }else if(date.getYear()<1000||date.getYear()>9999)throw fail(Code.OUT_OF_RANGE);
    }
    private static void timestampRange(LocalDateTime value,SchemaObject column,Engine engine) {
        LocalDateTime minimum=LocalDateTime.of(1970,1,1,0,0,1),maximum=engine==Engine.MARIADB?LocalDateTime.of(2106,2,7,6,28,15,999_999_000):LocalDateTime.of(2038,1,19,3,14,7,999_999_000);
        String offset=column.getPropertiesOrDefault("sessionTimeZoneOffsetSeconds","");
        if(!offset.isEmpty()) {
            int seconds;try {seconds=Integer.parseInt(offset);}catch(NumberFormatException exception){throw fail(Code.METADATA_UNAVAILABLE);}
            if(Math.abs((long)seconds)>64_800)throw fail(Code.METADATA_UNAVAILABLE);
            value=value.minusSeconds(seconds);
            if(value.isBefore(minimum)||value.isAfter(maximum))throw fail(Code.OUT_OF_RANGE);
        }else if(value.isBefore(minimum.plusDays(1))||value.isAfter(maximum.minusDays(1)))throw fail(Code.UNSUPPORTED);
    }
    private static void nanos(int value,int scale){int step=1;for(int i=scale;i<9;i++)step*=10;if(value%step!=0)throw fail(Code.LOSS_OF_PRECISION);}
    private static void fraction(String value,int scale){if(value!=null)for(int i=scale;i<value.length();i++)if(value.charAt(i)!='0')throw fail(Code.LOSS_OF_PRECISION);}
    private static Value json(Value input,SqlTypes.Type type,Engine engine) {
        if(!input.hasText()&&!input.hasJson())throw fail(Code.INVALID_TYPE);String raw=text(input.hasJson()?input.getJson():input.getText(),engine);
        new JsonCheck(raw,engine==Engine.POSTGRESQL&&type.family()==SqlTypes.Family.JSONB).read();
        return Value.newBuilder().setJson(raw).build();
    }
    private static Value uuid(String raw,String nativeName) {
        if(!raw.matches("[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"))throw fail(Code.INVALID_FORMAT);
        return Value.newBuilder().setEngineValue(EngineValue.newBuilder().setTypeName(nativeName).setText(UUID.fromString(raw).toString())).build();
    }
    private static Value retainedArray(Value input,Value original) {
        if(!input.hasArray()||original==null||!input.equals(original))throw fail(Code.UNSUPPORTED);
        checkArray(input,0,new int[]{0});return input;
    }
    private static Value array(Value input,Value original,SchemaObject column,Engine engine){
        if(input.hasArray()&&original!=null&&input.equals(original))return retainedArray(input,original);
        if(engine!=Engine.POSTGRESQL)throw fail(Code.UNSUPPORTED);
        try{return io.busystack.busydata.results.ArrayAssignments.convert(input,column);}catch(io.busystack.busydata.results.ArrayAssignments.Failure failure){throw fail(failure.code());}
    }
    private static void checkArray(Value value,int depth,int[] elements) {
        if(depth>16||++elements[0]>1024)throw fail(Code.VALUE_LIMIT);
        if(value.getTruncated()||!value.getValueId().isEmpty()||value.getDataCase()==Value.DataCase.DATA_NOT_SET)throw fail(Code.INCOMPLETE_VALUE);
        if(value.hasArray())for(var child:value.getArray().getValuesList())checkArray(child,depth+1,elements);
    }
    private static Value enumerated(Value input,SchemaObject column,SqlTypes.Type type,Value original,Engine engine) {
        if(!input.hasText())throw fail(Code.INVALID_TYPE);String raw=text(input.getText(),engine);
        if(original!=null&&input.equals(original))return input;
        boolean set=type.family()==SqlTypes.Family.SET;String prefix=set?"setMember":"enumLabel";
        if(!column.getPropertiesOrDefault(prefix+"sAvailability","").equals("AVAILABLE"))throw fail(Code.UNSUPPORTED);
        int count;try{count=Integer.parseInt(column.getPropertiesOrDefault(prefix+"Count",""));}catch(NumberFormatException exception){throw fail(Code.METADATA_UNAVAILABLE);}
        if(count<1||count>(set?64:1024))throw fail(Code.METADATA_UNAVAILABLE);var members=new ArrayList<String>();
        for(int i=0;i<count;i++){String key=prefix+"."+i;if(!column.containsProperties(key))throw fail(Code.METADATA_UNAVAILABLE);members.add(column.getPropertiesOrThrow(key));}
        if(!set){if(members.contains(raw))return Value.newBuilder().setText(raw).build();throw fail(Code.OUT_OF_RANGE);}
        // A textual SET assignment must already be its exact native representation.
        // No reordering, deduplication, trimming, case folding or numeric-bit aliases.
        if(members.stream().anyMatch(m->m.isEmpty()||m.indexOf(',')>=0)||new HashSet<>(members).size()!=members.size())throw fail(Code.UNSUPPORTED);
        if(raw.isEmpty())return Value.newBuilder().setText(raw).build();int previous=-1;
        for(String member:raw.split(",",-1)){int index=members.indexOf(member);if(index<0)throw fail(Code.OUT_OF_RANGE);if(index<=previous)throw fail(Code.INVALID_FORMAT);previous=index;}
        return Value.newBuilder().setText(raw).build();
    }

    /** Strict streaming syntax validation; numbers and duplicate keys stay raw. */
    private static final class JsonCheck {
        final String source;final boolean jsonb;int position,nodes;
        JsonCheck(String source,boolean jsonb){this.source=source;this.jsonb=jsonb;}
        void read(){value(0);space();if(position!=source.length())throw fail(Code.INVALID_FORMAT);}
        void space(){while(position<source.length()&&" \r\n\t".indexOf(source.charAt(position))>=0)position++;}
        boolean take(char token){space();if(position<source.length()&&source.charAt(position)==token){position++;return true;}return false;}
        void value(int depth) {
            if(depth>64||++nodes>65_536)throw fail(Code.VALUE_LIMIT);space();if(position==source.length())throw fail(Code.INVALID_FORMAT);
            char first=source.charAt(position);
            if(first=='{'||first=='[') {position++;char end=first=='{'?'}':']';if(take(end))return;
                do {if(first=='{'){if(++nodes>65_536)throw fail(Code.VALUE_LIMIT);string();if(!take(':'))throw fail(Code.INVALID_FORMAT);}value(depth+1);}while(take(','));
                if(!take(end))throw fail(Code.INVALID_FORMAT);return;
            }
            if(first=='"'){string();return;}
            for(String literal:List.of("true","false","null"))if(source.startsWith(literal,position)){position+=literal.length();return;}
            int start=position;if(first=='-')position++;
            if(position==source.length())throw fail(Code.INVALID_FORMAT);
            if(source.charAt(position)=='0')position++;else {if(!digit(source.charAt(position))||source.charAt(position)=='0')throw fail(Code.INVALID_FORMAT);while(position<source.length()&&digit(source.charAt(position)))position++;}
            if(position<source.length()&&source.charAt(position)=='.'){position++;int digits=position;while(position<source.length()&&digit(source.charAt(position)))position++;if(position==digits)throw fail(Code.INVALID_FORMAT);}
            if(position<source.length()&&(source.charAt(position)=='e'||source.charAt(position)=='E')){position++;if(position<source.length()&&(source.charAt(position)=='+'||source.charAt(position)=='-'))position++;int digits=position;while(position<source.length()&&digit(source.charAt(position)))position++;if(position==digits)throw fail(Code.INVALID_FORMAT);}
            preflightDecimal(source.substring(start,position));
        }
        static boolean digit(char value){return value>='0'&&value<='9';}
        int hex(){if(position+4>source.length())throw fail(Code.INVALID_FORMAT);int code=0;for(int i=0;i<4;i++){char c=source.charAt(position++);int digit=Character.digit(c,16);if(digit<0||c>127)throw fail(Code.INVALID_FORMAT);code=code*16+digit;}return code;}
        void string() {
            space();if(position==source.length()||source.charAt(position++)!='"')throw fail(Code.INVALID_FORMAT);
            while(position<source.length()) {
                char value=source.charAt(position++);if(value=='"')return;if(value<32)throw fail(Code.INVALID_FORMAT);
                if(value!='\\')continue;if(position==source.length())throw fail(Code.INVALID_FORMAT);char escaped=source.charAt(position++);
                if(escaped=='u') {int code=hex();if(jsonb&&code==0)throw fail(Code.INVALID_FORMAT);if(Character.isHighSurrogate((char)code)){if(position+2>source.length()||source.charAt(position++)!='\\'||source.charAt(position++)!='u'||!Character.isLowSurrogate((char)hex()))throw fail(Code.INVALID_FORMAT);}else if(Character.isLowSurrogate((char)code))throw fail(Code.INVALID_FORMAT);}
                else if("\"\\/bfnrt".indexOf(escaped)<0)throw fail(Code.INVALID_FORMAT);
            }
            throw fail(Code.INVALID_FORMAT);
        }
    }
}
