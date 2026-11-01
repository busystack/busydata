package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.administration.AuthenticationTools;
import io.busystack.busydata.jobs.Jobs;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

class AuthenticationIT {
 @TempDir Path root;
 private static Jobs.Job apply(EngineFixture f,io.busystack.busydata.sessions.SessionRegistry.Session s,AuthenticationTools tools,AuthenticationRequest request)throws Exception{
  var approval=tools.review(s,request);assertFalse(approval.toString().contains(request.getPassword())&&!request.getPassword().isEmpty());
  var job=tools.apply(s,request.toBuilder().setExecutionId(UUID.randomUUID().toString()).setApprovalToken(approval.getToken()).build(),f.jobs);
  assertEquals(JobState.COMPLETED,job.finished.get(30,TimeUnit.SECONDS).getState(),job.info().toString());return job;
 }
 @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
 void nativeAccountChangesAuthenticateExactlyAndNeverRetainPasswords(String name)throws Exception{
  try(var f=new EngineFixture(root,name)){
   var admin=f.open();var tools=new AuthenticationTools(f.safety);
   f.metadata.history(HistoryRequest.newBuilder().setAction(HistoryAction.SET_PRIVACY).setRetainSql(true).setRetentionDays(30).build());
   var principal=Principal.newBuilder().setName("Busy 漢' account").setHost(f.engine==Engine.POSTGRESQL?"":"%").build();
   String first="start ' quoted \\ 漢 987",second="replacement \\ ' 🙃 654";
   var create=AuthenticationRequest.newBuilder().setPrincipal(principal).setAction(AuthenticationAction.CREATE_LOGIN).setPassword(first).build();
   apply(f,admin,tools,create);
   if(f.engine!=Engine.POSTGRESQL){var grant=PrivilegeRequest.newBuilder().setScope(PrivilegeScope.DATABASE_PRIVILEGE).setSchema("busydata").setGrantee(principal).addPrivileges("SELECT").build();f.execute(admin,io.busystack.busydata.administration.PrivilegeTools.sql(f.engine,grant,principal,Principal.getDefaultInstance(),"busydata"));}
   var login=f.profile.toBuilder().setId("created-account").setUser(principal.getName()).build();
   var opened=f.sessions.open(OpenRequest.newBuilder().setProfile(login).setPassword(first).build());f.sessions.command(SessionRequest.newBuilder().setSessionId(opened.id).setAction(SessionAction.DISCONNECT).setForce(true).build());
   apply(f,admin,tools,create.toBuilder().setAction(AuthenticationAction.SET_PASSWORD).setPassword(second).build());
   assertThrows(Exception.class,()->f.sessions.open(OpenRequest.newBuilder().setProfile(login).setPassword(first).build()));
   opened=f.sessions.open(OpenRequest.newBuilder().setProfile(login).setPassword(second).build());f.sessions.command(SessionRequest.newBuilder().setSessionId(opened.id).setAction(SessionAction.DISCONNECT).setForce(true).build());
   var ordinary=create.toBuilder().clearPassword();
   apply(f,admin,tools,ordinary.setAction(AuthenticationAction.LOCK_LOGIN).build());
   assertThrows(Exception.class,()->f.sessions.open(OpenRequest.newBuilder().setProfile(login).setPassword(second).build()));
   apply(f,admin,tools,ordinary.setAction(AuthenticationAction.UNLOCK_LOGIN).build());
   opened=f.sessions.open(OpenRequest.newBuilder().setProfile(login).setPassword(second).build());f.sessions.command(SessionRequest.newBuilder().setSessionId(opened.id).setAction(SessionAction.DISCONNECT).setForce(true).build());
   // Exact password contents are part of the one-use review binding.
   var reset=create.toBuilder().setAction(AuthenticationAction.SET_PASSWORD).build();
   var token=tools.review(admin,reset).getToken();
   var changed=tools.apply(admin,reset.toBuilder().setPassword(second).setExecutionId(UUID.randomUUID().toString()).setApprovalToken(token).build(),f.jobs);
   assertEquals(JobState.FAILED,changed.finished.get(30,TimeUnit.SECONDS).getState());
   apply(f,admin,tools,ordinary.setAction(AuthenticationAction.DROP_PRINCIPAL).build());
   assertThrows(Exception.class,()->f.sessions.open(OpenRequest.newBuilder().setProfile(login).setPassword(second).build()));
   var role=Principal.newBuilder().setName("Busy ordinary role").setHost(f.engine==Engine.MYSQL?"%":"").build();
   apply(f,admin,tools,AuthenticationRequest.newBuilder().setPrincipal(role).setAction(AuthenticationAction.CREATE_ROLE).build());
   apply(f,admin,tools,AuthenticationRequest.newBuilder().setPrincipal(role).setAction(AuthenticationAction.DROP_PRINCIPAL).build());
   String history=f.metadata.history(HistoryRequest.getDefaultInstance()).toString();
   assertFalse(history.contains(first));assertFalse(history.contains(second));
   for(var job:f.jobs.list("")){assertFalse(job.toString().contains(first));assertFalse(job.toString().contains(second));}
   var readOnly=f.sessions.open(OpenRequest.newBuilder().setProfile(f.profile.toBuilder().setReadOnly(true)).setPassword("fixture").build());
   assertThrows(IllegalArgumentException.class,()->tools.review(readOnly,create));
  }
 }
}
