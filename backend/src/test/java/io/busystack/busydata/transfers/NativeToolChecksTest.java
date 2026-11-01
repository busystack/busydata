package io.busystack.busydata.transfers;
import io.busystack.busydata.protocol.*;
import java.nio.file.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;
class NativeToolChecksTest {
 @TempDir Path root;
 @Test void reviewsBindExactSelectedExecutableAndTlsContents()throws Exception {
  Path tool=root.resolve("pg_dump"),ca=root.resolve("ca.pem");Files.writeString(tool,"selected binary");tool.toFile().setExecutable(true);Files.writeString(ca,"selected CA");
  var request=ToolRequest.newBuilder().setNativeToolPath(tool.toString()).build();var profile=Profile.newBuilder().setTls(Tls.newBuilder().setCaFile(ca.toString())).build();
  String first=NativeToolChecks.reviewedFiles(request,profile);assertEquals(first,NativeToolChecks.reviewedFiles(request,profile));
  Files.writeString(tool,"replacement binary");String next=NativeToolChecks.reviewedFiles(request,profile);assertNotEquals(first,next);
  Files.writeString(ca,"replacement CA");assertNotEquals(next,NativeToolChecks.reviewedFiles(request,profile));
 }
 @Test void oversizedSelectedInputsFailBeforeReadingTheirContents()throws Exception {
  Path tool=root.resolve("mysql");try(var file=new java.io.RandomAccessFile(tool.toFile(),"rw")){file.setLength(128L*1024*1024+1);}tool.toFile().setExecutable(true);
  assertThrows(IllegalArgumentException.class,()->NativeToolChecks.reviewedFiles(ToolRequest.newBuilder().setNativeToolPath(tool.toString()).build(),Profile.getDefaultInstance()));
 }
}
