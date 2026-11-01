package io.busystack.busydata.schema;

import io.busystack.busydata.protocol.*;

/** Editing intent is independent of the retained value transport. */
public final class Assignments {
    private Assignments() {}
    public static ValueAssignment value(Value value) {
        if(value.hasNullValue())return nullValue();
        if(value.getDataCase()==Value.DataCase.DATA_NOT_SET||value.getTruncated()||!value.getValueId().isEmpty())
            throw new IllegalArgumentException("An assignment requires a complete exact value");
        return ValueAssignment.newBuilder().setValue(value).build();
    }
    public static ValueAssignment nullValue(){return ValueAssignment.newBuilder().setNullValue(Null.getDefaultInstance()).build();}
    public static ValueAssignment defaultValue(){return ValueAssignment.newBuilder().setDefaultValue(DefaultValue.getDefaultInstance()).build();}
    public static Value bound(ValueAssignment assignment){
        return switch(assignment.getAssignmentCase()){
            case VALUE -> {value(assignment.getValue());yield assignment.getValue();}
            case NULL_VALUE -> Value.newBuilder().setNullValue(Null.getDefaultInstance()).build();
            case DEFAULT_VALUE, ASSIGNMENT_NOT_SET -> throw new IllegalArgumentException("DEFAULT and unset are not bound values");
        };
    }
}
