package io.busystack.busydata;

import io.busystack.busydata.administration.PrivilegeTools;
import io.busystack.busydata.protocol.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class PrivilegeToolsTest {
    @Test void nativePrivilegeModelsKeepAccountHostsAndIdentifierBoundaries() {
        var receiver=Principal.newBuilder().setName("reader`\"; DROP TABLE x; --").setHost("%.example").setKind("account").build();
        var request=PrivilegeRequest.newBuilder().setScope(PrivilegeScope.TABLE_PRIVILEGE).setSchema("schema name").setTable("order").addPrivileges("select").addPrivileges("UPDATE").build();
        String mysql=PrivilegeTools.sql(Engine.MYSQL,request,receiver,Principal.getDefaultInstance(),"");
        assertEquals("GRANT SELECT, UPDATE ON `schema name`.`order` TO `reader``\"; DROP TABLE x; --`@`%.example`;",mysql);
        String postgres=PrivilegeTools.sql(Engine.POSTGRESQL,request,receiver,Principal.getDefaultInstance(),"");
        assertEquals("GRANT SELECT, UPDATE ON TABLE \"schema name\".\"order\" TO \"reader`\"\"; DROP TABLE x; --\";",postgres);
        var mariaRole=Principal.newBuilder().setName("reporting").setKind("role").build();
        var membership=PrivilegeRequest.newBuilder().setScope(PrivilegeScope.ROLE_MEMBERSHIP).setDelegation(true).build();
        assertEquals("GRANT `reporting` TO `reader``\"; DROP TABLE x; --`@`%.example` WITH ADMIN OPTION;",PrivilegeTools.sql(Engine.MARIADB,membership,receiver,mariaRole,""));
    }

    @Test void scopeAndPrivilegeValidationRejectsUnknownOrInjectedInstructions() {
        var receiver=Principal.newBuilder().setName("reader").setHost("%").build();
        var request=PrivilegeRequest.newBuilder().setSchema("public").setTable("x").addPrivileges("SELECT; DROP TABLE x").build();
        assertThrows(IllegalArgumentException.class,()->PrivilegeTools.sql(Engine.POSTGRESQL,request,receiver,receiver,""));
        var rejected=assertThrows(IllegalArgumentException.class,()->PrivilegeTools.sql(Engine.POSTGRESQL,request,receiver,receiver,""));
        assertFalse(rejected.getMessage().contains("DROP TABLE"));
        var oversized=request.toBuilder().clearPrivileges().addPrivileges("x".repeat(65)).build();
        assertThrows(IllegalArgumentException.class,()->PrivilegeTools.sql(Engine.POSTGRESQL,oversized,receiver,receiver,""));
        var wrongScope=request.toBuilder().clearPrivileges().addPrivileges("USAGE").setScope(PrivilegeScope.SCHEMA_PRIVILEGE).build();
        assertThrows(IllegalArgumentException.class,()->PrivilegeTools.sql(Engine.MYSQL,wrongScope,receiver,receiver,""));
        var revoke=wrongScope.toBuilder().setRevoke(true).setDelegation(true).build();
        assertThrows(IllegalArgumentException.class,()->PrivilegeTools.sql(Engine.POSTGRESQL,revoke,receiver,receiver,""));
    }
}
