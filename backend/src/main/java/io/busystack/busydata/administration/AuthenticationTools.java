package io.busystack.busydata.administration;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.sessions.SessionRegistry;
import io.busystack.busydata.safety.Safety;
import io.busystack.busydata.jobs.Jobs;
import java.sql.*;
import java.util.*;
import java.security.MessageDigest;
import java.nio.charset.StandardCharsets;

/** Typed native account management. Secret SQL is never a document/history draft. */
public final class AuthenticationTools {
    private record Target(String account,String policy,String literal,boolean role){}
    private final Safety safety;
    public AuthenticationTools(Safety safety){this.safety=safety;}
    private Target target(SessionRegistry.Session s,AuthenticationRequest r)throws Exception {
        var p=r.getPrincipal();var action=r.getAction();Engine engine=s.profile.getEngine();
        if(s.profile.getReadOnly())throw new IllegalArgumentException("Read-only profile rejects account changes");
        if(action==AuthenticationAction.UNRECOGNIZED)throw new IllegalArgumentException("Unknown account operation");
        if(p.getName().isBlank()||p.getName().length()>128||p.getHost().length()>255||p.getName().indexOf(0)>=0||p.getHost().indexOf(0)>=0)throw new IllegalArgumentException("Choose an exact named principal and host");
        boolean create=action==AuthenticationAction.CREATE_LOGIN||action==AuthenticationAction.CREATE_ROLE;
        boolean password=action==AuthenticationAction.CREATE_LOGIN||action==AuthenticationAction.SET_PASSWORD;
        if(password&&(r.getPassword().isEmpty()||r.getPassword().length()>1024||r.getPassword().indexOf(0)>=0))throw new IllegalArgumentException("Enter a nonempty password of at most 1024 UTF-16 units");
        if(!password&&!r.getPassword().isEmpty())throw new IllegalArgumentException("This operation does not accept a password");
        if(engine==Engine.POSTGRESQL&&!p.getHost().isEmpty()||engine==Engine.MARIADB&&action==AuthenticationAction.CREATE_ROLE&&!p.getHost().isEmpty())throw new IllegalArgumentException("This role does not have a host component");
        if((engine==Engine.MYSQL||engine==Engine.MARIADB&&action==AuthenticationAction.CREATE_LOGIN)&&p.getHost().isBlank())throw new IllegalArgumentException("Specify the exact account-host component; wildcards require explicit review");
        return s.metadata(view->{
            boolean role=action==AuthenticationAction.CREATE_ROLE;String identity="absent",policy="",mode="";
            String query=engine==Engine.POSTGRESQL?"SELECT oid::text,rolcanlogin::text FROM pg_roles WHERE rolname=?":engine==Engine.MYSQL?"SELECT plugin,account_locked FROM mysql.user WHERE User=? AND Host=?":"SELECT plugin,is_role FROM mysql.user WHERE User=? AND Host=?";
            try(var st=view.connection.prepareStatement(query)){st.setString(1,p.getName());if(engine!=Engine.POSTGRESQL)st.setString(2,p.getHost());st.setQueryTimeout(10);try(var row=st.executeQuery()){
                if(row.next()){if(create)throw new IllegalArgumentException("Principal already exists; choose a different name");identity=row.getString(1)+":"+row.getString(2);role=engine==Engine.POSTGRESQL?!row.getBoolean(2):engine==Engine.MARIADB&&row.getString(2).equals("Y");if(password&&engine==Engine.MYSQL&&!row.getString(1).equals("caching_sha2_password"))throw new IllegalArgumentException("Password reset would change an unsupported authentication plugin; inspect the server authentication policy");}
                else if(!create)throw new IllegalArgumentException("Principal no longer exists or is not visible");
            }}
            if(engine==Engine.POSTGRESQL&&password){try(var st=view.connection.createStatement();var row=st.executeQuery("SHOW password_encryption")){row.next();policy=row.getString(1);if(!policy.equals("scram-sha-256"))throw new IllegalArgumentException("Server password_encryption must be scram-sha-256; review that server policy before creating/resetting passwords");}}
            if(engine!=Engine.POSTGRESQL){try(var st=view.connection.createStatement();var row=st.executeQuery("SELECT @@session.sql_mode")){row.next();mode=row.getString(1);}if(engine==Engine.MARIADB&&action==AuthenticationAction.CREATE_LOGIN)try(var st=view.connection.createStatement();var row=st.executeQuery("SELECT @@session.old_passwords")){row.next();if(row.getInt(1)!=0)throw new IllegalArgumentException("Server is configured for obsolete password hashing; review the server policy before creating an account");}}
            if(engine==Engine.MARIADB&&!role&&p.getHost().isBlank())throw new IllegalArgumentException("Specify the exact account-host component");
            if(role&&password)throw new IllegalArgumentException("Choose a login account, not a non-login role");
            if(engine==Engine.MARIADB&&role&&(action==AuthenticationAction.LOCK_LOGIN||action==AuthenticationAction.UNLOCK_LOGIN))throw new IllegalArgumentException("MariaDB roles do not have login locking; choose a user account");
            String account=view.adapter.quote(p.getName())+(engine==Engine.POSTGRESQL||engine==Engine.MARIADB&&role?"":"@"+view.adapter.quote(p.getHost()));
            String literal=engine==Engine.POSTGRESQL?"E'"+r.getPassword().replace("\\","\\\\").replace("'","''")+"'":"'"+(Arrays.asList(mode.split(",")).contains("NO_BACKSLASH_ESCAPES")?r.getPassword():r.getPassword().replace("\\","\\\\")).replace("'","''")+"'";
            return new Target(account,identity+":"+policy+":"+mode,literal,role);
        });
    }
    private static String description(AuthenticationRequest r,Target t){return r.getAction()+" "+t.account+(r.getAction()==AuthenticationAction.CREATE_LOGIN||r.getAction()==AuthenticationAction.SET_PASSWORD?" · password [redacted]":"");}
    private String fingerprint(SessionRegistry.Session s,AuthenticationRequest r,Target t)throws Exception{
        var hash=MessageDigest.getInstance("SHA-256");hash.update("authentication".getBytes(StandardCharsets.US_ASCII));hash.update(r.toBuilder().clearContext().clearExecutionId().clearApprovalToken().build().toByteArray());hash.update(s.profile.toByteArray());hash.update((s.revision+":"+s.contextRevision+":"+t.policy).getBytes(StandardCharsets.UTF_8));return HexFormat.of().formatHex(hash.digest());
    }
    public Approval review(SessionRegistry.Session s,AuthenticationRequest r)throws Exception{
        var target=target(s,r);return Approval.newBuilder().setToken(safety.issue(fingerprint(s,r,target))).setExpiresUnixMs(System.currentTimeMillis()+120000).addStatements(description(r,target))
            .addRisks(s.profile.getEnvironment()+" · "+s.profile.getHost()+":"+s.profile.getPort()+"/"+s.context.catalog())
            .addRisks("Account changes can prevent login or expose data. MySQL/MariaDB account changes implicitly commit; PostgreSQL changes use the current transaction. Existing sessions and saved credentials are not automatically changed.")
            .addRisks("The database server may audit this operation. Review its logging policy before submitting credentials.").build();
    }
    public Jobs.Job apply(SessionRegistry.Session s,AuthenticationRequest r,Jobs jobs)throws Exception {
        // Only a redacted command is retained even if SQL-history retention is on.
        return jobs.submitSql(s,r.getExecutionId(),"-- Authentication management: "+r.getAction(),job->{
            var target=target(s,r);safety.consume(r.getApprovalToken(),fingerprint(s,r,target));
            Engine engine=s.profile.getEngine();String sql=switch(r.getAction()){
                case CREATE_LOGIN -> engine==Engine.POSTGRESQL?"CREATE ROLE "+target.account+" LOGIN PASSWORD "+target.literal:"CREATE USER "+target.account+" IDENTIFIED "+(engine==Engine.MYSQL?"WITH caching_sha2_password BY ":"BY ")+target.literal;
                case CREATE_ROLE -> "CREATE ROLE "+target.account+(engine==Engine.POSTGRESQL?" NOLOGIN":"");
                case SET_PASSWORD -> engine==Engine.POSTGRESQL?"ALTER ROLE "+target.account+" PASSWORD "+target.literal:engine==Engine.MYSQL?"ALTER USER "+target.account+" IDENTIFIED WITH caching_sha2_password BY "+target.literal:"SET PASSWORD FOR "+target.account+" = PASSWORD("+target.literal+")";
                case LOCK_LOGIN,UNLOCK_LOGIN -> engine==Engine.POSTGRESQL?"ALTER ROLE "+target.account+(r.getAction()==AuthenticationAction.LOCK_LOGIN?" NOLOGIN":" LOGIN"):"ALTER USER "+target.account+(r.getAction()==AuthenticationAction.LOCK_LOGIN?" ACCOUNT LOCK":" ACCOUNT UNLOCK");
                case DROP_PRINCIPAL -> "DROP "+(engine==Engine.POSTGRESQL||engine==Engine.MARIADB&&target.role?"ROLE ":"USER ")+target.account;
                default -> throw new IllegalArgumentException("Unknown account operation");
            };
            try(var statement=s.adapter.rawStatement(s.connection,false,s.profile.getQueryTimeoutSeconds(),0)){
                job.statement=statement;job.checkCancel();statement.execute(sql);job.statement=null;
                if(s.autoCommit&&s.state==TransactionState.IDLE||engine!=Engine.POSTGRESQL)job.commitAcknowledged();
                job.message(description(r,target)+" acknowledged by the server"+(!s.autoCommit&&engine==Engine.POSTGRESQL?"; commit or rollback the console transaction":""));
            }
        });
    }
}
