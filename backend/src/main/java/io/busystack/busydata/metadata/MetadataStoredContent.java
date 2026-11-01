package io.busystack.busydata.metadata;

import java.sql.*;
import java.util.Arrays;

/** Proves equality to freshly acquired metadata without restoring a second
 * semantic model. Called only inside the cache writer's reserved transaction. */
final class MetadataStoredContent {
    private MetadataStoredContent() {}

    @FunctionalInterface interface Check {void run() throws SQLException;}

    static boolean matches(Connection db,MetadataSnapshot snapshot,Check check)throws SQLException {
        if(!ownerMatches(db,snapshot,check))return false;
        if(!objectsMatch(db,snapshot,check))return false;
        return propertiesMatch(db,snapshot,check);
    }

    // SQLite affinity does not establish a stored value's type. Reject a wrong
    // storage class or oversized payload in SQL, before JDBC materializes it.
    private static String text(String column,int maximumBytes) {
        return "CASE WHEN typeof("+column+")='text' AND length(CAST("+column+" AS BLOB))<="+maximumBytes+" THEN "+column+" END";
    }
    private static String integer(String column) {
        return "CASE WHEN typeof("+column+")='integer' THEN "+column+" END";
    }
    private static boolean number(ResultSet rows,int index,long expected)throws SQLException {
        long actual=rows.getLong(index);return !rows.wasNull()&&actual==expected;
    }

    private static boolean ownerMatches(Connection db,MetadataSnapshot snapshot,Check check)throws SQLException {
        String ruleLength="CASE WHEN typeof(identifier_rules)='blob' THEN length(identifier_rules) ELSE -1 END";
        String rules="CASE WHEN ("+ruleLength+") BETWEEN 1 AND "+IdentifierRules.MAX_ENCODED_BYTES+" THEN identifier_rules END";
        String sql="SELECT "+String.join(",",text("profile",8192),integer("revision"),integer("configuration_revision"),integer("engine"),integer("case_rule"),rules)+" FROM publication WHERE source=?";
        try(var query=db.prepareStatement(sql)) {
            check.run();query.setString(1,snapshot.source());
            try(var rows=query.executeQuery()) {
                check.run();if(!rows.next())return false;
                long revision=rows.getLong(2);
                if(rows.wasNull()||revision<=0||revision>snapshot.revision())return false;
                boolean same=snapshot.profileId().equals(rows.getString(1))
                    &&number(rows,3,snapshot.configurationRevision())
                    &&number(rows,4,snapshot.rules().engine().getNumber())
                    &&number(rows,5,snapshot.rules().lowerCaseTableNames())
                    &&Arrays.equals(snapshot.rules().encode(),rows.getBytes(6));
                check.run();return same&&!rows.next();
            }
        }
    }

    private static boolean objectsMatch(Connection db,MetadataSnapshot snapshot,Check check)throws SQLException {
        String sql="SELECT "+String.join(",",text("identity",64),text("catalog",8192),text("schema_name",8192),
            integer("kind"),integer("subtype"),text("parent",8192),text("name",8192),text("signature",8192),
            text("native_key",8192),text("display_name",32768),text("quoted_name",32768),text("lookup_key",32768),
            text("source_text",262144),integer("level"),text("state",64),integer("source_revision"),integer("context_revision"))
            +" FROM object WHERE source=? ORDER BY identity";
        try(var query=db.prepareStatement(sql)) {
            check.run();query.setString(1,snapshot.source());
            try(var rows=query.executeQuery()) {
                int count=0;String last=null;
                while(rows.next()) {
                    check.run();if(++count>snapshot.identities().size())return false;
                    String key=rows.getString(1);if(key==null||key.equals(last))return false;last=key;
                    var object=snapshot.identities().get(key);if(object==null)return false;
                    var id=object.identity();
                    if(!id.catalog().equals(rows.getString(2))||!id.schema().equals(rows.getString(3))
                            ||!number(rows,4,id.kind().getNumber())||!number(rows,5,id.subtype().getNumber())
                            ||!id.parent().equals(rows.getString(6))||!id.name().equals(rows.getString(7))
                            ||!id.signature().equals(rows.getString(8))||!id.nativeKey().equals(rows.getString(9))
                            ||!object.displayName().equals(rows.getString(10))||!object.quotedIdentifier().equals(rows.getString(11))
                            ||!object.lookupKey().equals(rows.getString(12))||!object.source().equals(rows.getString(13))
                            ||!number(rows,14,object.level().number())||!object.state().name().equals(rows.getString(15))
                            ||!number(rows,16,object.sourceRevision())||!number(rows,17,object.contextRevision()))return false;
                }
                check.run();return count==snapshot.identities().size();
            }
        }
    }

    private static boolean propertiesMatch(Connection db,MetadataSnapshot snapshot,Check check)throws SQLException {
        long expected=0;for(var object:snapshot.persistenceObjects()){check.run();expected+=object.properties().size();}
        String sql="SELECT "+String.join(",",text("identity",64),text("name",1024),text("value",262144))
            +" FROM property WHERE source=? ORDER BY identity,name";
        try(var query=db.prepareStatement(sql)) {
            check.run();query.setString(1,snapshot.source());
            try(var rows=query.executeQuery()) {
                long count=0;String lastIdentity=null,lastName=null;MetadataObject object=null;
                while(rows.next()) {
                    check.run();if(++count>expected)return false;
                    String identity=rows.getString(1),name=rows.getString(2),value=rows.getString(3);
                    if(identity==null||name==null||value==null)return false;
                    if(identity.equals(lastIdentity)&&name.equals(lastName))return false;
                    if(!identity.equals(lastIdentity)){object=snapshot.identities().get(identity);if(object==null)return false;}
                    if(!value.equals(object.properties().get(name)))return false;
                    lastIdentity=identity;lastName=name;
                }
                check.run();return count==expected;
            }
        }
    }
}
