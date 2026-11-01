package io.busystack.busydata.analysis.language;

import io.busystack.busydata.protocol.*;
import java.math.BigInteger;
import java.util.*;

/** Native names survive classification; unknown/user types never become VARCHAR. */
public final class SqlTypes {
    public enum Family { INTEGER,DECIMAL,REAL,TEXT,BINARY,BOOLEAN,DATE,TIME,TIMESTAMP,INTERVAL,JSON,JSONB,ARRAY,ENUM,SET,DOMAIN,UUID,NULL,UNKNOWN,USER }
    public record Type(Family family,String nativeName,int jdbcType,int precision,int scale,boolean unsigned,boolean nullable,Type element,boolean timezone,NumericShape numericShape) {
        public Type {Objects.requireNonNull(numericShape);}
        public Type(Family family,String nativeName,int jdbcType,int precision,int scale,boolean unsigned,boolean nullable,Type element,boolean timezone){this(family,nativeName,jdbcType,precision,scale,unsigned,nullable,element,timezone,NumericShape.UNKNOWN);}
        public boolean nativeKnown(){return known()&&!nativeName.isBlank();}
        public boolean numeric(){return family==Family.INTEGER||family==Family.DECIMAL||family==Family.REAL;}
        public boolean known(){return family!=Family.UNKNOWN;}
        public BigInteger minimumInteger(){if(year())return BigInteger.ZERO;return integerBits()==0?null:unsigned?BigInteger.ZERO:BigInteger.ONE.shiftLeft(integerBits()-1).negate();}
        public BigInteger maximumInteger(){if(year())return BigInteger.valueOf(2155);return integerBits()==0?null:BigInteger.ONE.shiftLeft(unsigned?integerBits():integerBits()-1).subtract(BigInteger.ONE);}
        private boolean year(){String name=nativeName.toLowerCase(Locale.ROOT).trim();return family==Family.INTEGER&&(name.equals("year")||name.startsWith("year("));}
        public int integerBits(){if(family!=Family.INTEGER)return 0;String name=declarationBase(nativeName.toLowerCase(Locale.ROOT).trim()).replace(" unsigned","").replace(" zerofill","").trim();return name.equals("tinyint")||name.equals("boolean")||name.equals("bool")?8:name.equals("smallint")||name.equals("int2")||name.equals("smallserial")?16:name.equals("mediumint")?24:name.equals("bigint")||name.equals("int8")||name.equals("bigserial")||name.equals("serial")&&unsigned?64:Set.of("int","integer","int4","serial","year").contains(name)?32:0;}
    }
    public static final Type UNKNOWN=new Type(Family.UNKNOWN,"unknown",java.sql.Types.OTHER,0,0,false,true,null,false);
    public static final Type NULL=new Type(Family.NULL,"NULL",java.sql.Types.NULL,0,0,false,true,null,false);
    private SqlTypes(){}
    /** Native declarations are bounded strings, but unanchored whitespace regexes
     * can still backtrack quadratically before a missing modifier parenthesis. */
    private static String declarationBase(String name){int modifier=name.indexOf('(');return (modifier<0?name:name.substring(0,modifier)).trim();}
    public static Type nativeType(String name,Engine engine){
        String nativeName=name==null?"":name;String key=nativeName.toLowerCase(Locale.ROOT).trim();String base=declarationBase(key).replace(" unsigned","").trim();if(engine!=Engine.POSTGRESQL)base=base.replace(" zerofill","").trim();
        if(key.endsWith("[]")){
            // Metadata type names have their own input boundary; the SQL parser's
            // nesting budget cannot protect a cached/native type descriptor.
            int dimensions=0,end=key.length();
            while(end>=2&&key.charAt(end-2)=='['&&key.charAt(end-1)==']'){
                if(++dimensions>AnalysisBudget.MAX_DEPTH)return new Type(Family.UNKNOWN,nativeName,java.sql.Types.OTHER,0,0,false,true,null,false);
                end-=2;while(end>0&&key.charAt(end-1)<=' ')end--;
            }
            String trimmed=nativeName.trim();
            return new Type(Family.ARRAY,nativeName,java.sql.Types.ARRAY,0,0,false,true,nativeType(trimmed.substring(0,trimmed.length()-2),engine),false);
        }
        Family family=switch(base){
            case "tinyint","smallint","mediumint","int","integer","bigint","int2","int4","int8","serial","smallserial","bigserial"->Family.INTEGER;
            case "year"->engine==Engine.POSTGRESQL?Family.USER:Family.INTEGER;
            case "numeric","decimal","dec","fixed","money"->Family.DECIMAL;
            case "float","float4","float8","double","double precision","real"->Family.REAL;
            case "char","character","varchar","character varying","text","tinytext","mediumtext","longtext","name","citext","xml"->Family.TEXT;
            case "bpchar"->engine==Engine.POSTGRESQL?Family.TEXT:Family.USER;
            case "bytea","binary","varbinary","blob","tinyblob","mediumblob","longblob","bit","bit varying","varbit"->Family.BINARY;
            case "boolean","bool"->engine==Engine.POSTGRESQL?Family.BOOLEAN:Family.INTEGER;
            case "date"->Family.DATE;
            case "time","time without time zone","time with time zone","timetz"->Family.TIME;
            case "timestamp","timestamp without time zone","timestamp with time zone","datetime","timestamptz"->Family.TIMESTAMP;
            case "interval"->Family.INTERVAL;
            case "json"->Family.JSON;
            case "jsonb"->Family.JSONB;
            case "enum"->Family.ENUM;
            case "set"->Family.SET;
            case "uuid"->Family.UUID;
            case "","unknown","anyelement","anycompatible","any","record"->Family.UNKNOWN;
            case "null"->Family.NULL;
            default->Family.USER;
        };
        int jdbc=switch(family){case INTEGER->java.sql.Types.BIGINT;case DECIMAL->java.sql.Types.NUMERIC;case REAL->java.sql.Types.DOUBLE;case TEXT,ENUM,SET->java.sql.Types.VARCHAR;case BINARY->java.sql.Types.BINARY;case BOOLEAN->java.sql.Types.BOOLEAN;case DATE->java.sql.Types.DATE;case TIME->java.sql.Types.TIME;case TIMESTAMP->java.sql.Types.TIMESTAMP;default->java.sql.Types.OTHER;};
        int precision=0,scale=0;var modifier=java.util.regex.Pattern.compile("\\(\\s*([0-9]{1,9})(?:\\s*,\\s*([+-]?[0-9]{1,9}))?\\s*\\)").matcher(key);
        if(modifier.find()&&Set.of(Family.DECIMAL,Family.TEXT,Family.BINARY,Family.TIME,Family.TIMESTAMP).contains(family)){precision=integer(modifier.group(1),0);scale=modifier.group(2)==null?0:integer(modifier.group(2),0);}
        return NativeNumericTypes.declared(new Type(family,nativeName,jdbc,precision,scale,(key.contains("unsigned")||engine!=Engine.POSTGRESQL&&(base.equals("serial")||key.contains("zerofill"))),true,null,key.contains("with time zone")||base.equals("timestamptz")||base.equals("timetz")),engine);
    }
    public static Type column(SchemaObject column,Engine engine){
        var p=column.getPropertiesMap();Type base=nativeType(p.getOrDefault("nativeType",p.getOrDefault("type",p.getOrDefault("typeName",""))),engine);
        String nativeKind=p.getOrDefault("nativeTypeKind",p.getOrDefault("typeKind",""));
        Family family=Set.of("d","domain").contains(nativeKind)?Family.DOMAIN:Set.of("e","enum").contains(nativeKind)?Family.ENUM:base.family();
        int precision=integer(p.get("precision"),integer(p.get("size"),0)),scale=integer(p.get("scale"),0);
        boolean nullable=!Set.of("NO","FALSE","0").contains(p.getOrDefault("nullable","").toUpperCase(Locale.ROOT));
        Type element=base.element();
        if(family==Family.DOMAIN&&!p.getOrDefault("domainBaseType","").isEmpty()) {
            Type underlying=nativeType(p.get("domainBaseType"),engine);
            element=new Type(underlying.family(),underlying.nativeName(),underlying.jdbcType(),precision,scale,underlying.unsigned(),nullable,underlying.element(),underlying.timezone());
        }
        return NativeNumericTypes.field(NativeNumericTypes.declared(new Type(family,base.nativeName(),integer(p.get("jdbcType"),base.jdbcType()),precision,scale,p.getOrDefault("unsigned","").equalsIgnoreCase("true")||base.unsigned(),nullable,element,base.timezone()),engine));
    }
    public static boolean sameBuiltinTypeName(String left,String right,Engine engine) {
        String a=builtin(left,engine),b=builtin(right,engine);return a!=null&&a.equals(b);
    }
    private static String builtin(String name,Engine engine) {
        String base=name.toLowerCase(Locale.ROOT).replaceAll("\\(\\s*[+-]?[0-9]+(?:\\s*,\\s*[+-]?[0-9]+)?\\s*\\)","").trim().replaceAll("\\s+"," ");
        if(engine==Engine.POSTGRESQL)return switch(base) {
            case "timestamp","timestamp without time zone"->"pg.timestamp";case "timestamptz","timestamp with time zone"->"pg.timestamptz";
            case "time","time without time zone"->"pg.time";case "timetz","time with time zone"->"pg.timetz";
            case "smallint","int2"->"pg.int2";case "integer","int","int4"->"pg.int4";case "bigint","int8"->"pg.int8";
            case "numeric","decimal"->"pg.numeric";case "real","float4"->"pg.float4";case "double precision","float8"->"pg.float8";
            case "boolean","bool"->"pg.bool";case "character varying","varchar"->"pg.varchar";case "character","char","bpchar"->"pg.bpchar";
            case "bit"->"pg.bit";case "bit varying","varbit"->"pg.varbit";
            case "date","interval","uuid","bytea","json","jsonb","text"->"pg."+base;default->null;
        };
        return switch(base){case "boolean","bool","tinyint"->"mysql.tinyint";case "int","integer"->"mysql.int";case "smallint","mediumint","bigint","timestamp","datetime","date","time","year","json"->"mysql."+base;default->null;};
    }
    static int integer(String text,int fallback){try{return Integer.parseInt(text);}catch(Exception ignored){return fallback;}}
    /** Only proven incompatibilities are errors. MySQL coercions are intentionally permissive. */
    public static boolean compatible(Type source,Type target,Engine engine){
        if(!source.known()||!target.known()||source.family()==Family.NULL||source.family()==target.family())return true;
        if(source.numeric()&&target.numeric())return true;
        if(source.family()==Family.DATE&&target.family()==Family.TIMESTAMP)return true;
        if(engine!=Engine.POSTGRESQL&&(source.family()==Family.BOOLEAN&&target.numeric()||source.numeric()&&target.family()==Family.BOOLEAN))return true;
        if(engine!=Engine.POSTGRESQL&&Set.of(Family.DATE,Family.TIME,Family.TIMESTAMP).contains(source.family())&&Set.of(Family.DATE,Family.TIME,Family.TIMESTAMP).contains(target.family()))return true;
        if(engine!=Engine.POSTGRESQL&&source.numeric()&&target.family()==Family.TEXT||engine!=Engine.POSTGRESQL&&source.family()==Family.TEXT&&target.numeric())return true;
        if(source.family()==Family.USER||target.family()==Family.USER||source.family()==Family.DOMAIN||target.family()==Family.DOMAIN)return true;
        // SQL string literals initially have unknown type, and are handled separately.
        return false;
    }
    public static Type common(Type left,Type right){
        if(left.family()==Family.NULL||left.family()==Family.UNKNOWN)return right;if(right.family()==Family.NULL||right.family()==Family.UNKNOWN)return left;
        if(left.family()==right.family())return left;
        if(left.numeric()&&right.numeric())return left.family()==Family.REAL?left:right.family()==Family.REAL?right:left.family()==Family.DECIMAL?left:right;
        return UNKNOWN;
    }
    public static Type nullable(Type type,boolean nullable){return new Type(type.family(),type.nativeName(),type.jdbcType(),type.precision(),type.scale(),type.unsigned(),nullable,type.element(),type.timezone(),type.numericShape());}
    public static Type shaped(Type type,NumericShape shape){return new Type(type.family(),type.nativeName(),type.jdbcType(),type.precision(),type.scale(),type.unsigned(),type.nullable(),type.element(),type.timezone(),shape);}

    /** SQL truth semantics remain engine-aware, while native result descriptors
     * match the pinned server protocol: PG bool, MySQL LONGLONG, MariaDB LONG. */
    public static Type truth(Engine engine,boolean nullable){Type type=nullable(nativeType(engine==Engine.POSTGRESQL?"boolean":engine==Engine.MYSQL?"bigint":"integer",engine),nullable);return engine==Engine.POSTGRESQL?type:shaped(type,new NumericShape(1,1,false,true,null,NumericShape.Origin.TRUTH));}
    public static Type base(Type type){return type.family()==Family.DOMAIN&&type.element()!=null?base(type.element()):type;}
    /** Native common result for CASE/COALESCE, set outputs, and merged join columns.
     * UNKNOWN here represents a contextually coercible literal/parameter; callers
     * must propagate unavailable symbol metadata before invoking this function. */
    public static Type common(Type left,Type right,Engine engine){return common(List.of(left,right),engine);}
    public static Type common(List<Type> values,Engine engine){
        boolean nullable=values.stream().anyMatch(t->t.nullable()||t.family()==Family.NULL);var known=values.stream().filter(t->t.known()&&t.family()!=Family.NULL).toList();
        if(known.isEmpty())return values.stream().anyMatch(t->t.family()==Family.UNKNOWN)||engine==Engine.POSTGRESQL?nullable(nativeType("text",engine),nullable):NULL;
        Type first=known.getFirst();
        // MySQL's aggregate_decimal_properties produces a signed DECIMAL for
        // CASE/COALESCE and set outputs, including identical unsigned inputs.
        // MariaDB retains unsigned only when every supplied input is unsigned.
        if(engine!=Engine.POSTGRESQL&&first.family()==Family.DECIMAL&&known.stream().allMatch(t->sameNative(t,first,engine)&&t.precision()==first.precision()&&t.scale()==first.scale())){
            boolean unsigned=engine==Engine.MARIADB&&values.stream().allMatch(Type::unsigned);
            String name="decimal"+(unsigned?" unsigned":"");
            return NativeNumericTypes.declared(new Type(Family.DECIMAL,name,first.jdbcType(),first.precision(),first.scale(),unsigned,nullable,null,false),engine);
        }
        if(known.stream().allMatch(t->sameNative(t,first,engine)&&t.precision()==first.precision()&&t.scale()==first.scale())&&(engine!=Engine.POSTGRESQL||first.family()!=Family.DOMAIN||known.size()==values.size())){
            Type result=NativeNumericTypes.commonShape(first,known,engine);
            // An unknown string/NULL coerces to the selected type without a
            // typmod, so CASE/COALESCE cannot retain another arm's modifier.
            if(engine==Engine.POSTGRESQL&&known.size()!=values.size()&&builtin(first.nativeName(),engine)!=null)result=withoutTypmod(result);
            return nullable(result,nullable);
        }
        // PostgreSQL selects the common type OID independently of its typmod.
        // Equal typmods were retained above; differing builtin typmods leave
        // varchar/char/numeric/time/etc. as that native type with no typmod.
        if(engine==Engine.POSTGRESQL&&builtin(first.nativeName(),engine)!=null&&known.stream().allMatch(t->sameNative(t,first,engine)))return nullable(withoutTypmod(first),nullable);
        known=known.stream().map(SqlTypes::base).toList();
        if(engine==Engine.POSTGRESQL&&known.stream().anyMatch(t->t.nativeName().equalsIgnoreCase("money")))return UNKNOWN;
        if(known.stream().allMatch(Type::numeric))return nullable(NativeNumericTypes.commonShape(numericCommon(known,engine,values.stream().allMatch(Type::unsigned)),known,engine),nullable);
        if(known.stream().allMatch(t->t.family()==Family.TEXT||engine!=Engine.POSTGRESQL&&(t.family()==Family.ENUM||t.family()==Family.SET)))return nullable(nativeType(engine==Engine.POSTGRESQL?"text":"varchar",engine),nullable);
        if(engine!=Engine.POSTGRESQL&&known.stream().allMatch(t->Set.of(Family.DATE,Family.TIME,Family.TIMESTAMP).contains(t.family())))return nullable(nativeType("datetime",engine),nullable);
        if(engine!=Engine.POSTGRESQL&&known.stream().allMatch(t->t.numeric()||Set.of(Family.TEXT,Family.ENUM,Family.SET,Family.BOOLEAN).contains(t.family())))return nullable(nativeType("varchar",engine),nullable);
        if(engine!=Engine.POSTGRESQL&&known.stream().allMatch(t->Set.of(Family.TEXT,Family.BINARY,Family.ENUM,Family.SET).contains(t.family())))return nullable(nativeType("varbinary",engine),nullable);
        if(engine==Engine.POSTGRESQL&&known.stream().allMatch(t->t.family()==Family.DATE||t.family()==Family.TIMESTAMP))return nullable(nativeType(known.stream().anyMatch(Type::timezone)?"timestamptz":"timestamp",engine),nullable);
        if(known.stream().allMatch(t->t.family()==Family.ARRAY)){
            if(known.stream().anyMatch(t->t.element()==null))return UNKNOWN;Type element=common(known.stream().map(Type::element).toList(),engine);return element.known()?new Type(Family.ARRAY,element.nativeName()+"[]",java.sql.Types.ARRAY,0,0,false,nullable,element,false):UNKNOWN;
        }
        return UNKNOWN;
    }
    private static Type withoutTypmod(Type type){
        String name=type.nativeName().replaceAll("\\(\\s*[+-]?[0-9]+(?:\\s*,\\s*[+-]?[0-9]+)?\\s*\\)","");
        return new Type(type.family(),name,type.jdbcType(),0,0,type.unsigned(),type.nullable(),type.element(),type.timezone());
    }
    public static boolean sameNative(Type left,Type right,Engine engine){
        if(!left.nativeKnown()||!right.nativeKnown()||left.family()!=right.family()||left.unsigned()!=right.unsigned()||left.timezone()!=right.timezone())return false;
        return left.nativeName().equalsIgnoreCase(right.nativeName())||sameBuiltinTypeName(left.nativeName(),right.nativeName(),engine);
    }
    public static int numericRank(Type input,Engine engine){
        Type type=base(input);if(type.family()==Family.INTEGER)return type.integerBits()==0?-1:type.integerBits()<=16?0:type.integerBits()<=32?1:2;
        if(type.family()==Family.DECIMAL)return 3;
        if(type.family()==Family.REAL){String name=type.nativeName().toLowerCase(Locale.ROOT);return engine==Engine.POSTGRESQL&&(name.equals("real")||name.equals("float4"))?4:5;}return -1;
    }
    private static Type numericCommon(List<Type> values,Engine engine,boolean allUnsigned){
        int rank=values.stream().mapToInt(t->numericRank(t,engine)).max().orElse(-1);
        if(rank<3&&values.stream().anyMatch(t->t.family()==Family.INTEGER&&!t.nativeKnown()))return NativeNumericTypes.unknownInteger(values.stream().anyMatch(Type::unsigned),values.stream().anyMatch(Type::nullable),NumericShape.UNKNOWN);
        if(engine==Engine.POSTGRESQL)return nativeType(switch(rank){case 0->"smallint";case 1->"integer";case 2->"bigint";case 3->"numeric";case 4->"real";default->"double precision";},engine);
        if(rank>=4)return nativeType("double",engine);if(rank==3)return nativeType("decimal"+(engine==Engine.MARIADB&&allUnsigned?" unsigned":""),engine);
        BigInteger minimum=values.stream().map(Type::minimumInteger).min(BigInteger::compareTo).orElse(BigInteger.ZERO),maximum=values.stream().map(Type::maximumInteger).max(BigInteger::compareTo).orElse(BigInteger.ZERO);
        for(String name:List.of("tinyint","smallint","mediumint","int","bigint"))for(boolean unsigned:new boolean[]{false,true}){
            if(unsigned&&minimum.signum()<0)continue;Type candidate=nativeType(name+(unsigned?" unsigned":""),engine);
            if(minimum.compareTo(candidate.minimumInteger())>=0&&maximum.compareTo(candidate.maximumInteger())<=0)return candidate;
        }return nativeType("decimal(20,0)",engine);
    }
    /** Finite implicit conversion facts used for overload resolution. Explicit
     * casts and assignment coercions deliberately use different rules. */
    public static boolean implicitlyCoercible(Type source,Type target,Engine engine){
        if(!source.known()||!target.known()||source.family()==Family.NULL)return true;
        source=base(source);target=base(target);if(sameNative(source,target,engine))return true;
        if(source.numeric()&&target.numeric())return engine!=Engine.POSTGRESQL||numericRank(source,engine)<=numericRank(target,engine);
        if(source.family()==Family.TEXT&&target.family()==Family.TEXT)return true;
        if(source.family()==Family.DATE&&target.family()==Family.TIMESTAMP)return true;
        if(source.family()==Family.TIMESTAMP&&target.family()==Family.TIMESTAMP)return engine!=Engine.POSTGRESQL||!source.timezone()||target.timezone();
        return engine!=Engine.POSTGRESQL&&compatible(source,target,engine);
    }
}
