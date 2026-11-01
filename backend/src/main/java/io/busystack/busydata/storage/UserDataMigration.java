package io.busystack.busydata.storage;

import io.busystack.busydata.metadata.MetadataIdentity;
import io.busystack.busydata.metadata.SourceIdentity;
import io.busystack.busydata.protocol.Profile;
import java.sql.Connection;
import java.util.Base64;

/** One transaction, owned by MetadataStore, from supported user data to schema 4. */
final class UserDataMigration {
    private UserDataMigration() {}
    static void migrate(Connection connection)throws Exception {
        if(connection.getAutoCommit())throw new IllegalStateException("User migration requires its initialization transaction");
        EditAssignmentMigration.migrate(connection);
        try(var statement=connection.createStatement();var rows=statement.executeQuery("SELECT 1 FROM migration WHERE version=4")){if(rows.next())return;}
        try(var statement=connection.createStatement()) {
            statement.execute("CREATE TABLE metadata_source_identity(fingerprint TEXT PRIMARY KEY NOT NULL,source TEXT NOT NULL UNIQUE)");
        }
        // Persist the existing opaque IDs before changing lookup. Object IDs,
        // cache rows, durable scope settings and Flutter column preferences keep
        // their current source component. Raw wire hashing exists only here.
        int count=0;
        try(var statement=connection.createStatement();var rows=statement.executeQuery("SELECT id,payload,length(payload) FROM profiles ORDER BY id LIMIT 129");
            var insert=connection.prepareStatement("INSERT INTO metadata_source_identity VALUES(?,?)")) {
            while(rows.next()) {
                if(++count>128||rows.getLong(3)>8192)throw new IllegalStateException("Source identity migration exceeds saved profile budget; records preserved");
                Profile profile=Profile.parseFrom(rows.getBytes(2));
                if(!rows.getString(1).equals(profile.getId()))throw new IllegalStateException("Saved profile identity is inconsistent; records preserved");
                String previous=MetadataIdentity.digest(Base64.getEncoder().encodeToString(profile.toBuilder().clearName().clearEnvironment().clearConnectTimeoutSeconds().clearQueryTimeoutSeconds().build().toByteArray()));
                insert.setString(1,SourceIdentity.fingerprint(profile));insert.setString(2,previous);insert.executeUpdate();
            }
        }
        try(var statement=connection.createStatement()){statement.executeUpdate("INSERT INTO migration VALUES(4)");}
    }
}
