package io.busystack.busydata.transfers;

import java.io.IOException;
import java.util.Optional;
import java.util.OptionalInt;

/** A selected native client exited unsuccessfully; never a filesystem diagnosis. */
public final class NativeToolFailure extends IOException {
    public enum Category {
        DEADLOCK("database deadlock"),
        MISSING_LIBRARY("missing native library"),
        UNSUPPORTED_OPTION("unsupported native-tool option"),
        AUTHENTICATION("database authentication denied"),
        TLS("database TLS verification/negotiation failed"),
        PERMISSION("database or file permission denied"),
        HOSTNAME("hostname resolution failed"),
        CONNECTION("database connection failed"),
        SQL("database rejected SQL"),
        DISK_FULL("destination disk full"),
        UNCLASSIFIED("unclassified native-tool failure");
        private final String description;
        Category(String description){this.description=description;}
    }
    private final int exitCode;
    private final Category category;
    private final Integer databaseCode;
    private final String sqlState;
    NativeToolFailure(int exitCode,Category category,Integer databaseCode,String sqlState){
        super("Native tool exited "+exitCode+": "+category.description+
            (databaseCode==null?"":" (database code "+databaseCode+
                (sqlState==null?"":", SQLSTATE "+sqlState)+")")+
            ". Source values and server messages omitted.");
        if(exitCode==0)throw new IllegalArgumentException("Native failure requires a nonzero exit");
        this.exitCode=exitCode;this.category=category;this.databaseCode=databaseCode;this.sqlState=sqlState;
    }
    public String errorCode(){return category==Category.DEADLOCK?"NATIVE_DATABASE_DEADLOCK":"NATIVE_TOOL_FAILED";}
    public int exitCode(){return exitCode;}
    public Category category(){return category;}
    public OptionalInt databaseCode(){return databaseCode==null?OptionalInt.empty():OptionalInt.of(databaseCode);}
    public Optional<String> sqlState(){return Optional.ofNullable(sqlState);}
}
