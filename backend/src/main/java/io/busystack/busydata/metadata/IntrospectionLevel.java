package io.busystack.busydata.metadata;

public enum IntrospectionLevel {
    NAMES(1), STRUCTURE(2), SOURCE(3);
    private final int number;
    IntrospectionLevel(int number){this.number=number;}
    public int number(){return number;}
    public boolean includes(IntrospectionLevel requested){return number>=requested.number;}
    public static IntrospectionLevel of(int number){return switch(number){case 1->NAMES;case 2->STRUCTURE;case 3->SOURCE;default->throw new IllegalArgumentException("Introspection level must be 1, 2 or 3");};}
}
