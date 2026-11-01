import java.nio.file.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.attribute.BasicFileAttributes;
import java.security.MessageDigest;
import java.util.*;

/** JDK-only build receipt for the same canonical source model used by evidence. */
class BackendBuildIdentity {
    private static final HexFormat HEX=HexFormat.of();
    private static String quote(String value) {
        var out=new StringBuilder("\"");
        for(int index=0;index<value.length();index++) {
            char ch=value.charAt(index);
            switch(ch) {
                case '"' -> out.append("\\\""); case '\\' -> out.append("\\\\");
                case '\b' -> out.append("\\b"); case '\f' -> out.append("\\f");
                case '\n' -> out.append("\\n"); case '\r' -> out.append("\\r");
                case '\t' -> out.append("\\t");
                default -> {if(ch<32)out.append(String.format("\\u%04x",(int)ch));else out.append(ch);}
            }
        }
        return out.append('"').toString();
    }
    private static int compareCodePoints(String left,String right) {
        var a=left.codePoints().iterator();var b=right.codePoints().iterator();
        while(a.hasNext()&&b.hasNext()){int compare=Integer.compare(a.nextInt(),b.nextInt());if(compare!=0)return compare;}
        return Boolean.compare(a.hasNext(),b.hasNext());
    }
    private static Set<String> values(Properties policy,String key) {
        return new HashSet<>(List.of(policy.getProperty(key).split(",")));
    }
    private static String mode(String name,Properties policy) {
        if(values(policy,"executableExact").contains(name))return "0755";
        String prefix=policy.getProperty("executableRoot")+"/";
        if(name.startsWith(prefix)&&name.indexOf('/',prefix.length())<0) {
            String base=name.substring(prefix.length());
            boolean executable=values(policy,"executableExtensions").stream().anyMatch(name::endsWith);
            boolean excluded=values(policy,"nonExecutablePrefixes").stream().anyMatch(base::startsWith);
            if(executable&&!excluded)return "0755";
        }
        return "0644";
    }
    public static void main(String[] arguments)throws Exception {
        if(arguments.length!=2||Runtime.version().feature()!=25)
            throw new IllegalArgumentException("Java 25 and explicit build paths are required");
        Path root=Path.of(arguments[0]).toRealPath(),destination=Path.of(arguments[1]);
        var policy=new Properties();
        try(var reader=Files.newBufferedReader(root.resolve("tool/source_policy.properties"),StandardCharsets.UTF_8)){policy.load(reader);}
        var files=new TreeMap<String,Path>(BackendBuildIdentity::compareCodePoints);
        var generated=values(policy,"generatedParts");
        var generatedPaths=values(policy,"generatedPaths");
        for(String relative:policy.getProperty("inputs").split(",")) {
            Path input=root.resolve(relative);
            for(Path parent=input;!parent.equals(root);parent=parent.getParent())
                if(Files.isSymbolicLink(parent))throw new IllegalArgumentException("Source symbolic links are unsupported");
            if(!Files.exists(input,LinkOption.NOFOLLOW_LINKS))continue;
            if(Files.isRegularFile(input,LinkOption.NOFOLLOW_LINKS))files.put(relative,input);
            else if(Files.isDirectory(input,LinkOption.NOFOLLOW_LINKS))Files.walkFileTree(input,new SimpleFileVisitor<>() {
                @Override public FileVisitResult preVisitDirectory(Path path,BasicFileAttributes attrs) {
                    String relative=root.relativize(path).toString().replace('\\','/');
                    return generated.contains(path.getFileName().toString())||generatedPaths.contains(relative)
                        ?FileVisitResult.SKIP_SUBTREE:FileVisitResult.CONTINUE;
                }
                @Override public FileVisitResult visitFile(Path path,BasicFileAttributes attrs) {
                    if(path.toString().endsWith(".pyc"))return FileVisitResult.CONTINUE;
                    // Nofollow traversal reports a linked generated directory
                    // as a file. Apply the same directory exclusions as Python;
                    // ordinary files and every nonexcluded source link remain inputs.
                    String relative=root.relativize(path).toString().replace('\\','/');
                    if(attrs.isSymbolicLink()&&Files.isDirectory(path)&&
                        (generated.contains(path.getFileName().toString())||generatedPaths.contains(relative)))
                        return FileVisitResult.CONTINUE;
                    if(!attrs.isRegularFile()||attrs.isSymbolicLink())throw new IllegalArgumentException("Source non-regular files are unsupported");
                    files.put(root.relativize(path).toString().replace('\\','/'),path);return FileVisitResult.CONTINUE;
                }
            });
            else throw new IllegalArgumentException("Source input must be regular: "+relative);
        }
        if(files.size()>Integer.parseInt(policy.getProperty("maxFiles")))throw new IllegalArgumentException("Source file-count budget exceeded");
        var entries=new ArrayList<String>();long bytes=0;var caseNames=new HashSet<String>();
        for(var entry:files.entrySet()) {
            String name=entry.getKey();
            if(name.startsWith("/")||name.contains("\\")||name.contains(":")||name.getBytes(StandardCharsets.UTF_8).length>2048||name.chars().anyMatch(ch->ch<32))throw new IllegalArgumentException("Source paths must be normalized");
            if(!caseNames.add(name.toLowerCase(Locale.ROOT)))throw new IllegalArgumentException("Source paths collide on Windows");
            var before=Files.readAttributes(entry.getValue(),BasicFileAttributes.class,LinkOption.NOFOLLOW_LINKS);
            if(!before.isRegularFile()||before.size()>Long.parseLong(policy.getProperty("maxFileBytes")))throw new IllegalArgumentException("Source file byte budget exceeded");
            bytes+=before.size();if(bytes>Long.parseLong(policy.getProperty("maxSourceBytes")))throw new IllegalArgumentException("Source snapshot byte budget exceeded");
            var hash=MessageDigest.getInstance("SHA-256");long consumed=0;var buffer=new byte[65536];
            try(var input=Files.newInputStream(entry.getValue(),LinkOption.NOFOLLOW_LINKS)) {
                for(int size;(size=input.read(buffer))!=-1;){consumed+=size;if(consumed>before.size())throw new IllegalArgumentException("Source grew during hashing");hash.update(buffer,0,size);}
            }
            var after=Files.readAttributes(entry.getValue(),BasicFileAttributes.class,LinkOption.NOFOLLOW_LINKS);
            if(consumed!=before.size()||!Objects.equals(before.fileKey(),after.fileKey())||before.size()!=after.size()||!before.lastModifiedTime().equals(after.lastModifiedTime()))
                throw new IllegalArgumentException("Source changed during hashing");
            entries.add("{\"bytes\":"+before.size()+",\"mode\":"+quote(mode(name,policy))+",\"path\":"+quote(name)+",\"sha256\":"+quote(HEX.formatHex(hash.digest()))+",\"type\":\"file\"}");
        }
        String canonical="{\"files\":["+String.join(",",entries)+"],\"policy\":"+quote(policy.getProperty("policy"))+",\"schemaVersion\":1}\n";
        if(canonical.getBytes(StandardCharsets.UTF_8).length>4*1024*1024)throw new IllegalArgumentException("Source manifest byte budget exceeded");
        String identity=HEX.formatHex(MessageDigest.getInstance("SHA-256").digest(canonical.getBytes(StandardCharsets.UTF_8)));
        String json="{\"version\":2,\"buildSourceSha256\":"+quote(identity)+",\"backendSourceSha256\":"+quote(identity)+",\"files\":"+files.size()+",\"javaVersion\":"+quote(Runtime.version().toString())+"}\n";
        Files.createDirectories(destination.getParent());Path temporary=destination.resolveSibling(destination.getFileName()+".partial");
        // This is a replaceable build-owned generated receipt, never a user destination.
        try {Files.writeString(temporary,json,StandardCharsets.UTF_8);Files.move(temporary,destination,StandardCopyOption.REPLACE_EXISTING);}
        finally {Files.deleteIfExists(temporary);}
    }
}
