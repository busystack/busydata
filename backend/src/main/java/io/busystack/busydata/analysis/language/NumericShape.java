package io.busystack.busydata.analysis.language;

import java.math.BigInteger;
import java.util.Objects;

/** Bounded server display/precision evidence, independent of integer value range.
 * Missing evidence remains unknown; no SQL value is evaluated by the database.
 * Widths are primitive descriptors, never allocation sizes; a large LOB width
 * does not materialize any part of its value. */
public record NumericShape(int characters,int integerDigits,boolean constant,boolean nonNegative,BigInteger exact,Origin origin) {
    public enum Origin {UNKNOWN,DECLARED,FIELD,LITERAL,EXPRESSION,CAST,FUNCTION,SUBQUERY,TRUTH}
    public static final NumericShape UNKNOWN=new NumericShape(-1,-1,false,false,null,Origin.UNKNOWN);
    public NumericShape {
        Objects.requireNonNull(origin);
        if(characters< -1||integerDigits< -1||exact!=null&&exact.bitLength()>65)throw new IllegalArgumentException("Invalid bounded numeric shape");
    }
    public boolean known(){return characters>=0&&integerDigits>=0;}
    public NumericShape field(boolean unsigned){return new NumericShape(characters,integerDigits,false,unsigned,null,Origin.FIELD);}
}
