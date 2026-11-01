package io.busystack.busydata.transfers;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.results.*;
import io.busystack.busydata.jobs.Jobs;
import io.busystack.busydata.sessions.SessionRegistry;
import java.io.*;
import java.nio.charset.*;
import java.nio.file.*;
import java.sql.*;
import java.util.*;
import java.util.concurrent.TimeUnit;
import com.google.gson.*;
import com.google.gson.stream.JsonReader;
import org.apache.commons.csv.*;

public final class Transfers {
    private final ResultStore results;
    private final RetainedViews retainedViews;
    private final io.busystack.busydata.security.NativeToolTransport nativeTransport;
    private final java.util.concurrent.Semaphore transfers=new java.util.concurrent.Semaphore(2,true);
    public Transfers(ResultStore results){this(results,new io.busystack.busydata.security.NativeToolTransport());}
    public Transfers(ResultStore results,io.busystack.busydata.security.NativeToolTransport nativeTransport){this.results=results;this.nativeTransport=nativeTransport;this.retainedViews=null;}
    public Transfers(ResultStore results,RetainedViews views){this.results=results;this.retainedViews=views;this.nativeTransport=new io.busystack.busydata.security.NativeToolTransport();}
    public void run(Jobs.Job job,ToolRequest r)throws Exception {
        run(job,r,Set.of(ToolKind.EXPORT_RESULT,ToolKind.EXPORT_QUERY,ToolKind.DUMP).contains(r.getKind())?OutputTarget.identity(Path.of(r.getPath())):"");
    }
    public void run(Jobs.Job job,ToolRequest r,String reviewedOutput)throws Exception {
        if(r.getPath().isBlank()||!Path.of(r.getPath()).isAbsolute())throw new IllegalArgumentException("Native picker must supply an absolute path");
        if(!transfers.tryAcquire())throw new IllegalStateException("Transfer limit (2) reached");
        try{switch(r.getKind()){case EXPORT_RESULT->export(job,r,reviewedOutput);case EXPORT_QUERY->exportQuery(job,r,reviewedOutput);case IMPORT_CSV,IMPORT_JSON->importRows(job,r);case DUMP,RESTORE->nativeTool(job,r,reviewedOutput);default->throw new IllegalArgumentException("Invalid transfer");}}finally{transfers.release();}
    }
    private static Path output(ToolRequest r)throws Exception {
        Path target=Path.of(r.getPath());if(Files.exists(target,LinkOption.NOFOLLOW_LINKS)&&!r.getOverwrite())throw new IllegalArgumentException("Overwrite requires review");
        if(Files.isSymbolicLink(target))throw new IllegalArgumentException("Output symlinks are not accepted");
        return target;
    }
    private void exportQuery(Jobs.Job job,ToolRequest request,String reviewedOutput)throws Exception{
        var session=job.session;
        if(!session.connection.getAutoCommit()||session.state!=TransactionState.IDLE)throw new IllegalArgumentException("Finish the console transaction before a direct export; this job owns its read transaction");
        var analysis=new io.busystack.busydata.analysis.SqlAnalysis();var fragments=analysis.split(request.getSql(),session.profile.getEngine());
        if(fragments.size()!=1||!Set.of("SELECT","WITH").contains(analysis.leadingKeyword(fragments.getFirst().text())))throw new IllegalArgumentException("Direct export requires one reviewed SELECT or WITH query; the owned server transaction enforces read-only execution");
        long quota=OutputTarget.quota(request);
        Path target=output(request);
        try(var commit=OutputCommit.open(target,request.getOverwrite(),reviewedOutput)) {
          Path partial=commit.partial();
          try(var transaction=session.ownedTransaction()){
            try(var policy=session.connection.createStatement()){policy.setQueryTimeout(5);policy.execute("SET TRANSACTION READ ONLY");}
            try(var statement=session.adapter.rawStatement(session.connection,true,session.profile.getQueryTimeoutSeconds(),0);
                var writer=new BufferedWriter(new OutputStreamWriter(OutputTarget.stream(partial,quota),StandardCharsets.UTF_8))){
                job.statement=statement;job.checkCancel();job.state=JobState.EXECUTING;
                try(var rows=statement.executeQuery(fragments.getFirst().text())){
                    var encoder=new ExportEncoder(writer,request,job,Values.columns(rows.getMetaData()));encoder.begin();job.state=JobState.FETCHING;
                    while(rows.next()){job.checkCancel();encoder.row(rows,job.progress++);}encoder.end();
                }
            }finally{job.statement=null;}
          }
            job.checkCancel();commit.commit();job.commitAcknowledged();
            job.message("Direct export wrote "+job.progress+" rows from this explicit execution; no interactive result was retained");
        }
    }
    private void export(Jobs.Job job,ToolRequest r,String reviewedOutput)throws Exception {
        var view=retainedViews!=null&&retainedViews.contains(r.getResultId())?retainedViews.get(r.getResultId()):null;
        var result=view==null?results.get(r.getResultId()):view.source;long rowCount=view==null?result.rows():view.count;
        if(view==null&&!result.fetchFinished&&!result.complete&&!result.limited)throw new IllegalArgumentException("Wait for fetching to finish; export never reruns SQL");
        Path target=output(r);long quota=OutputTarget.quota(r);
        try(var commit=OutputCommit.open(target,r.getOverwrite(),reviewedOutput)) {
            Path partial=commit.partial();
            if(Set.of("json","ndjson").contains(r.getFormat())&&result.columns.stream().map(Column::getName).distinct().count()!=result.columns.size())throw new IllegalArgumentException("JSON export requires unique result labels; choose CSV/TSV or explicitly alias columns");
            if(!r.getValueId().isEmpty()) {
                try(var input=Files.newInputStream(result.cell(r.getValueId()));var output=OutputTarget.stream(partial,quota)){byte[] buffer=new byte[65536];int n;while((n=input.read(buffer))!=-1){job.checkCancel();output.write(buffer,0,n);job.progress+=n;}}
                job.checkCancel();commit.commit();job.commitAcknowledged();return;
            }
            try(var writer=new BufferedWriter(new OutputStreamWriter(OutputTarget.stream(partial,quota),StandardCharsets.UTF_8))) {
                if(Set.of("csv","tsv").contains(r.getFormat())) {
                    char delimiter=CsvContract.delimiter(r);String marker=CsvContract.marker(r);
                    for(int c=0;c<result.columns.size();c++){if(c>0)writer.write(delimiter);writer.write('"');writer.write(result.columns.get(c).getName().replace("\"","\"\""));writer.write('"');}writer.write('\n');
                    for(long i=0;i<rowCount;i++){job.checkCancel();var row=result.read(view==null?i:view.sourceRow(i));for(int c=0;c<row.getValuesCount();c++){if(c>0)writer.write(delimiter);var v=row.getValues(c);if(v.hasNullValue())writer.write(marker);else {writer.write('"');writeExact(writer,v,result,job,"csv");writer.write('"');}}writer.write('\n');job.progress++;}
                } else if(Set.of("json","ndjson").contains(r.getFormat())) {
                    boolean lines=r.getFormat().equals("ndjson");if(!lines)writer.write("[\n");
                    for(long i=0;i<rowCount;i++){job.checkCancel();if(!lines&&i>0)writer.write(",\n");writer.write('{');var row=result.read(view==null?i:view.sourceRow(i));for(int j=0;j<result.columns.size();j++){if(j>0)writer.write(',');writer.write(new JsonPrimitive(result.columns.get(j).getName()).toString());writer.write(':');Value v=row.getValues(j);if(v.getValueId().isEmpty()){if(v.getTruncated())throw new IllegalArgumentException("Full value unavailable");writer.write(json(v).toString());}else{boolean raw=v.hasJson();if(!raw)writer.write('"');writeExact(writer,v,result,job,raw?"raw":"json");if(!raw)writer.write('"');}}writer.write('}');if(lines)writer.write('\n');job.progress++;}if(!lines)writer.write("\n]\n");
                } else throw new IllegalArgumentException("Choose CSV, TSV, JSON, or NDJSON");
            }
            job.checkCancel();commit.commit();job.commitAcknowledged();
            if(view!=null)job.message("Exported the selected filtered retained view; source snapshot "+view.snapshotRows+" rows. SQL was not executed.");
            if(!result.complete)job.message("Export contains only the retained, incomplete result; SQL was not rerun");
        }
    }
    public static JsonElement json(Value v){return switch(v.getDataCase()){case NULL_VALUE->JsonNull.INSTANCE;case BOOLEAN->new JsonPrimitive(v.getBoolean());case REAL->Double.isFinite(v.getReal())?new JsonPrimitive(v.getReal()):new JsonPrimitive(Values.text(v));case JSON->JsonParser.parseString(v.getJson());default->new JsonPrimitive(Values.text(v));};}
    private static void writeExact(Writer out,Value value,ResultStore.Result result,Jobs.Job job,String format)throws Exception {
        boolean jsonEscape=format.equals("json");
        if(value.getValueId().isEmpty()){if(value.getTruncated())throw new IllegalArgumentException("Full value unavailable");String text=Values.text(value);out.write(jsonEscape?new JsonPrimitive(text).toString().substring(1,new JsonPrimitive(text).toString().length()-1):text.replace("\"","\"\""));return;}
        if(value.hasBinary()){try(var in=Files.newInputStream(result.cell(value.getValueId()))){byte[] buffer=new byte[8192];int n;while((n=in.read(buffer))!=-1){job.checkCancel();out.write(HexFormat.of().formatHex(buffer,0,n));}}return;}
        try(var in=Files.newBufferedReader(result.cell(value.getValueId()),StandardCharsets.UTF_8)){char[] buffer=new char[8192];int n;while((n=in.read(buffer))!=-1){job.checkCancel();for(int i=0;i<n;i++){char c=buffer[i];if(jsonEscape){switch(c){case '"'->out.write("\\\"");case '\\'->out.write("\\\\");case '\n'->out.write("\\n");case '\r'->out.write("\\r");case '\t'->out.write("\\t");default->{if(c<32)out.write(String.format("\\u%04x",(int)c));else out.write(c);}}}else{if(c=='"'&&format.equals("csv"))out.write('"');out.write(c);}}}}
    }
    private void importRows(Jobs.Job job,ToolRequest r)throws Exception {
        try(var snapshot=ImportSources.snapshot(r,results,job::checkCancel)){importSnapshot(job,snapshot.request());}
    }
    private void importSnapshot(Jobs.Job job,ToolRequest r)throws Exception {
        var s=job.session;if(s.profile.getReadOnly())throw new IllegalArgumentException("Read-only profile");
        if(!s.connection.getAutoCommit()||s.state!=TransactionState.IDLE)throw new IllegalArgumentException("Finish the console transaction before import");
        job.checkCancel();
        Path source=ImportSources.selected(r);if(!r.getSourceSha256().isEmpty()&&!r.getSourceSha256().equals(ImportSources.hash(source,job.cancel::get)))throw new IllegalStateException("Import source changed after preview");
        job.checkCancel();
        if(r.getColumnsCount()==0||r.getColumnsCount()>2048)throw new IllegalArgumentException("Explicit column mapping required");
        if(!new HashSet<>(r.getColumnsList()).containsAll(r.getColumnMappingMap().keySet()))throw new IllegalArgumentException("Mapping must use selected target columns");
        String target=s.adapter.table("",r.getSchema(),r.getTable());var types=new HashMap<String,Integer>();
        try(var columns=s.connection.getMetaData().getColumns(s.connection.getCatalog(),r.getSchema().isBlank()?null:r.getSchema(),r.getTable(),null)){while(columns.next())if(!"YES".equals(columns.getString("IS_GENERATEDCOLUMN")))types.put(columns.getString("COLUMN_NAME"),columns.getInt("DATA_TYPE"));}
        if(!types.keySet().containsAll(r.getColumnsList())||new HashSet<>(r.getColumnsList()).size()!=r.getColumnsCount())throw new IllegalArgumentException("Mapping includes unknown, duplicate, or generated columns");
        if(s.profile.getEngine()!=Engine.POSTGRESQL)try(var st=s.connection.prepareStatement("SELECT ENGINE FROM information_schema.TABLES WHERE TABLE_SCHEMA=? AND TABLE_NAME=?")){st.setString(1,r.getSchema().isBlank()?s.connection.getCatalog():r.getSchema());st.setString(2,r.getTable());try(var rows=st.executeQuery()){if(!rows.next()||!"InnoDB".equalsIgnoreCase(rows.getString(1)))throw new IllegalArgumentException("Import requires an InnoDB table");}}
        String sql="INSERT INTO "+target+" ("+String.join(",",r.getColumnsList().stream().map(s.adapter::quote).toList())+") VALUES ("+String.join(",",Collections.nCopies(r.getColumnsCount(),"?"))+")";
        try(var batch=new ImportBatch(job,r,types,sql);var reader=ImportSources.reader(r)) {
            if(r.getKind()==ToolKind.IMPORT_CSV) {
                try(var parser=CsvContract.input(r).parse(reader)) {
                    if(new HashSet<>(parser.getHeaderNames()).size()!=parser.getHeaderNames().size())throw new IllegalArgumentException("Duplicate CSV headers are ambiguous");
                    if(!parser.getHeaderMap().keySet().containsAll(r.getColumnsList().stream().map(col->ImportSources.sourceColumn(r,col)).toList()))throw new IllegalArgumentException("CSV header does not match mapping");
                    for(var row:parser){var values=new ArrayList<String>(r.getColumnsCount());for(String column:r.getColumnsList())values.add(row.get(ImportSources.sourceColumn(r,column)));batch.accept(values);}
                }
            } else if(r.getFormat().equals("ndjson")) {
                String line;while((line=boundedLine(reader))!=null){if(line.isBlank())continue;batch.accept(jsonValues(r,JsonParser.parseString(line).getAsJsonObject()));}
            } else {
                try(var json=new JsonReader(reader)){json.beginArray();while(json.hasNext())batch.accept(jsonValues(r,JsonParser.parseReader(json).getAsJsonObject()));json.endArray();if(json.peek()!=com.google.gson.stream.JsonToken.END_DOCUMENT)throw new IOException("Unexpected content after JSON array");}
            }
            batch.finish();job.message("Import committed "+job.committedRows+" rows; rejected "+job.rejectedRows+". Policy: "+r.getImportPolicy());
        }finally{job.statement=null;}
    }
    private static String boundedLine(Reader reader)throws IOException{var b=new StringBuilder();int c;while((c=reader.read())!=-1){if(c=='\n')break;if(b.length()>=1_048_576)throw new IOException("NDJSON record exceeds 1MiB");b.append((char)c);}return c==-1&&b.isEmpty()?null:b.toString();}
    private static List<String> jsonValues(ToolRequest r,JsonObject object){
        var values=new ArrayList<String>(r.getColumnsCount());for(String col:r.getColumnsList()){var value=object.get(ImportSources.sourceColumn(r,col));if(value==null)throw new IllegalArgumentException("JSON mapping is missing a selected source column");values.add(value.isJsonNull()?null:value.isJsonPrimitive()?value.getAsString():value.toString());}return values;
    }
    private static final class ImportBatch implements AutoCloseable {
        private final Jobs.Job job;private final ToolRequest request;private final Map<String,Integer> types;private final PreparedStatement statement;
        private final int batchRows,errorLimit;private io.busystack.busydata.sessions.OwnedTransaction transaction;
        private int pending,transactionRows;private long bytes,sourceRow;
        ImportBatch(Jobs.Job job,ToolRequest request,Map<String,Integer> types,String sql)throws Exception{
            this.job=job;this.request=request;this.types=types;
            batchRows=request.getBatchRows()==0?256:request.getBatchRows();errorLimit=request.getErrorLimit()==0?100:request.getErrorLimit();
            if(batchRows<1||batchRows>1000||errorLimit<1||errorLimit>1000)throw new IllegalArgumentException("Import batch rows: 1–1000; error collection: 1–1000");
            var prepared=job.session.connection.prepareStatement(sql);try{prepared.setQueryTimeout(job.session.profile.getQueryTimeoutSeconds()==0?60:job.session.profile.getQueryTimeoutSeconds());}catch(SQLException failure){try{prepared.close();}catch(SQLException cleanup){failure.addSuppressed(cleanup);}throw failure;}statement=prepared;
        }
        void accept(List<String> values)throws Exception{
            job.checkCancel();sourceRow++;long rowBytes=64;
            for(String value:values)rowBytes+=value==null?8:value.length()*3L+32;
            if(rowBytes>2_097_152)throw new IOException("Import row exceeds the 2MiB parameter budget");
            if(bytes+rowBytes>2_097_152)flush();
            if(transaction==null)transaction=job.session.ownedTransaction();
            Savepoint savepoint=request.getImportPolicy()==ImportPolicy.SKIP_INVALID_ROWS?job.session.connection.setSavepoint():null;
            try{
                statement.clearParameters();int index=1;for(int i=0;i<values.size();i++)ImportValues.bind(statement,index++,values.get(i),types.get(request.getColumns(i)));
                job.statement=statement;job.checkCancel();
                if(savepoint!=null)statement.executeUpdate();else{statement.addBatch();pending++;bytes+=rowBytes;}
                transactionRows++;job.progress++;
                if(savepoint!=null)job.session.connection.releaseSavepoint(savepoint);
            }catch(SQLException|IllegalArgumentException failure){
                if(savepoint==null||failure instanceof SQLException sql&&sql.getSQLState()!=null&&sql.getSQLState().startsWith("08"))throw failure;
                try{job.session.connection.rollback(savepoint);job.session.connection.releaseSavepoint(savepoint);}
                catch(SQLException cleanup){job.session.quarantine(cleanup);failure.addSuppressed(cleanup);throw failure;}
                job.rejectedRows++;job.message("Rejected import source row "+sourceRow+": "+(failure instanceof SQLException sql?"SQLSTATE "+sql.getSQLState():"conversion failed")+"; source values omitted");
                if(job.rejectedRows>=errorLimit)throw new IOException("Import error collection limit reached; earlier committed batches remain");
            }
            if(pending>=batchRows)flush();
            if(request.getImportPolicy()!=ImportPolicy.ATOMIC_IMPORT&&transactionRows>=batchRows)commit(false);
        }
        private void flush()throws Exception{if(pending==0)return;job.checkCancel();job.statement=statement;job.checkCancel();statement.executeBatch();statement.clearBatch();pending=0;bytes=0;}
        private void commit(boolean last)throws Exception{
            if(transaction==null)return;flush();job.statement=null;var current=transaction;
            current.commit(job::beginCommit,()->{job.committedRows+=transactionRows;if(last)job.commitAcknowledged();else job.boundaryAcknowledged();});
            transaction=null;transactionRows=0;current.close();
        }
        void finish()throws Exception{commit(true);}
        public void close()throws Exception{
            job.statement=null;try(var handle=statement){if(transaction!=null)transaction.close();}
        }
    }
    private void nativeTool(Jobs.Job job,ToolRequest request,String reviewedOutput)throws Exception {
        if(request.getKind()==ToolKind.RESTORE) {
            try(var snapshot=ImportSources.snapshot(request,results,job::checkCancel)){nativeToolSnapshot(job,snapshot.request(),reviewedOutput);}
        }else nativeToolSnapshot(job,request,reviewedOutput);
    }
    private void nativeToolSnapshot(Jobs.Job job,ToolRequest r,String reviewedOutput)throws Exception {
        var profile=job.session.profile.toBuilder().setDatabase(job.session.context.catalog()).build();
        int nativePort=job.session.nativePort();
        if(r.getKind()==ToolKind.RESTORE && profile.getReadOnly())throw new IllegalArgumentException("Read-only profile");
        Path executable=Path.of(r.getNativeToolPath());
        if(!executable.isAbsolute()||!Files.isRegularFile(executable)||!Files.isExecutable(executable))throw new IllegalArgumentException("Choose an installed compatible native tool by absolute path");
        String name=executable.getFileName().toString().replace(".exe","");boolean postgres=profile.getEngine()==Engine.POSTGRESQL,dump=r.getKind()==ToolKind.DUMP;
        String expected=postgres?(dump?"pg_dump":"psql"):(profile.getEngine()==Engine.MYSQL?(dump?"mysqldump":"mysql"):(dump?"mariadb-dump":"mariadb"));
        if(!name.equals(expected))throw new IllegalArgumentException("Selected tool must be "+expected);
        String versionText=NativeToolChecks.version(job,executable);
        var major=java.util.regex.Pattern.compile(postgres?"(?:PostgreSQL|psql)\\)?\\s+(\\d+)":profile.getEngine()==Engine.MARIADB?"(?:Distrib|from)\\s+(\\d+)":"Ver\\s+(\\d+)").matcher(versionText);
        int serverMajor=job.session.connection.getMetaData().getDatabaseMajorVersion();
        if(!major.find()||Integer.parseInt(major.group(1))!=serverMajor)throw new IllegalArgumentException("Native tool must match the server major version");
        for(String text:List.of(profile.getHost(),profile.getDatabase(),profile.getUser(),job.session.password()))if(text.contains("\n")||text.contains("\r")||text.contains("\0"))throw new IllegalArgumentException("Native-tool credential/endpoint contains an unsupported control character");
        io.busystack.busydata.security.NativeTlsPolicy.preflight(profile);
        Path destination=dump?output(r):Path.of(r.getPath());
        if(!dump&&!Files.isRegularFile(destination))throw new IllegalArgumentException("Restore source missing");
        OutputCommit commit=dump?OutputCommit.open(destination,r.getOverwrite(),reviewedOutput):null;
        Path partial=commit==null?null:commit.partial();
        Exception primary=null;
        Path defaults=null;io.busystack.busydata.security.NativeMysqlRelay relay=null;var command=new ArrayList<String>();command.add(executable.toString());
        boolean relayed=profile.getSsh().getEnabled()&&!postgres;
        try(var tlsMaterial=new io.busystack.busydata.security.JdbcTlsMaterial(job.session.temporaryFiles)) {
            Path rootSnapshot=tlsMaterial.nativeRoots(profile);
            if(!postgres){
                defaults=job.session.temporaryFiles.create("busydata-native-",".cnf");
                String password=job.session.password().replace("\\","\\\\").replace("\"","\\\"").replace("\n","\\n").replace("\r","\\r").replace("\t","\\t");
                Files.writeString(defaults,"[client]\npassword=\""+password+"\"\n",StandardCharsets.UTF_8);
                command.add("--defaults-file="+defaults);if(profile.getEngine()==Engine.MYSQL)command.add("--no-login-paths");if(!relayed){command.add("--protocol=TCP");command.add("--host="+profile.getHost());command.add("--port="+nativePort);}command.add("--user="+profile.getUser());
                if(!dump){command.add("--local-infile=0");command.add("--binary-mode");command.add("--batch");command.add("--skip-reconnect");}
                else {command.add("--single-transaction");command.add("--quick");command.add("--routines");command.add("--hex-blob");}
                if(profile.getEngine()==Engine.MYSQL)command.add("--ssl-mode="+(relayed?"DISABLED":io.busystack.busydata.security.NativeTlsPolicy.mysqlMode(profile.getTls().getMode())));
                else{command.add(relayed?"--skip-ssl":switch(profile.getTls().getMode()){case DISABLED,DRIVER_DEFAULT->"--skip-ssl";case VERIFY_FULL,INSECURE,VERIFY_CA->"--ssl";default->throw new IllegalArgumentException("Invalid native TLS mode");});if(!relayed&&profile.getTls().getMode()==TlsMode.VERIFY_FULL)command.add("--ssl-verify-server-cert");}
                if(!relayed&&rootSnapshot!=null)command.add("--ssl-ca="+rootSnapshot);
                if(!relayed&&profile.getTls().getMode()!=TlsMode.DISABLED && profile.getTls().getMode()!=TlsMode.DRIVER_DEFAULT && !profile.getTls().getClientCert().isEmpty()){command.add("--ssl-cert="+profile.getTls().getClientCert());command.add("--ssl-key="+profile.getTls().getClientKey());}
                if(dump){command.add("--");command.add(profile.getDatabase());}
                else{command.add("--local-infile=0");command.add("--database="+profile.getDatabase());}
            } else {
                defaults=job.session.temporaryFiles.create("busydata-native-",".pgpass");
                if(java.util.stream.Stream.of(profile.getHost(),profile.getDatabase(),profile.getUser(),job.session.password()).anyMatch(v->v.contains("\n")||v.contains("\r")))throw new IllegalArgumentException("Native PostgreSQL password files cannot represent newline-containing credentials or endpoint fields");
                String fields=String.join(":",List.of(profile.getHost(),Integer.toString(nativePort),profile.getDatabase(),profile.getUser(),job.session.password()).stream().map(v->v.replace("\\","\\\\").replace(":","\\:")).toList());
                Files.writeString(defaults,fields+"\n",StandardCharsets.UTF_8);
                command.add("--host="+profile.getHost());command.add("--port="+nativePort);command.add("--username="+profile.getUser());command.add("--dbname="+postgresDatabase(profile,nativePort));command.add("--no-password");
                if(!dump){
                    var patch=java.util.regex.Pattern.compile("(?:PostgreSQL|psql)\\)?\\s+(\\d+)\\.(\\d+)").matcher(versionText);
                    if(!patch.find()||Integer.parseInt(patch.group(1))==17&&Integer.parseInt(patch.group(2))<11||Integer.parseInt(patch.group(1))==18&&Integer.parseInt(patch.group(2))<6)throw new IllegalArgumentException("Selected psql must include the fixed restricted-mode implementation (17.11 / 18.6 or newer)");
                    command.add("--no-psqlrc");command.add("--set=ON_ERROR_STOP=1");command.add("--file=-");
                }
            }
            var builder=new ProcessBuilder(command);
            io.busystack.busydata.security.NativeToolTransport.sanitize(builder);
            if(profile.getSsh().getEnabled()){if(postgres)builder.environment().put("PGHOSTADDR","127.0.0.1");else relay=nativeTransport.forward(builder,profile,nativePort,tlsMaterial.nativeContext(profile,rootSnapshot));}
            builder.environment().remove("MYSQL_PWD");builder.environment().remove("MYSQL_TEST_LOGIN_FILE");
            for(String variable:List.of("PGOPTIONS","PGSERVICE","PGSERVICEFILE","PGSYSCONFDIR"))builder.environment().remove(variable);
            if(postgres){builder.environment().remove("PGPASSWORD");builder.environment().put("PGPASSFILE",defaults.toString());builder.environment().put("PGSSLMODE",io.busystack.busydata.security.NativeTlsPolicy.postgresMode(profile.getTls().getMode()));
                builder.environment().remove("PGSSLROOTCERT");
                if(rootSnapshot!=null)builder.environment().put("PGSSLROOTCERT",rootSnapshot.toString());
                boolean clientIdentity=profile.getTls().getMode()!=TlsMode.DISABLED && profile.getTls().getMode()!=TlsMode.DRIVER_DEFAULT && !profile.getTls().getClientCert().isEmpty();
                if(rootSnapshot==null)builder.environment().put("PGSSLROOTCERT",defaults+".no-root-certificate");
                builder.environment().put("PGSSLCERT",clientIdentity?profile.getTls().getClientCert():defaults+".no-client-certificate");builder.environment().put("PGSSLKEY",clientIdentity?profile.getTls().getClientKey():defaults+".no-client-key");}
            if(dump)builder.redirectOutput(ProcessBuilder.Redirect.PIPE);else {if(!postgres)builder.redirectInput(destination.toFile());builder.redirectOutput(ProcessBuilder.Redirect.DISCARD);}
            job.checkCancel();if(!dump)job.beforeExternalMutation();job.checkCancel();var child=builder.start();job.process=child;
            if(!dump){job.externalMutationStarted();job.message("Restore uses a separate native session; partial commits cannot be rolled back by the console.");}
            var inputFailure=new java.util.concurrent.CompletableFuture<Void>();
            Thread inputDrain=!dump&&postgres?Thread.ofVirtual().start(()->{try(var pipe=child.getOutputStream()){PostgresRestoreInput.write(destination,pipe,job::checkCancel);inputFailure.complete(null);}catch(Exception failure){inputFailure.completeExceptionally(failure);child.destroy();}}):null;
            var outputFailure=new java.util.concurrent.CompletableFuture<Void>();
            Thread outputDrain=dump?Thread.ofVirtual().start(()->{try(var input=child.getInputStream();var output=OutputTarget.stream(partial,OutputTarget.quota(r))){byte[] buffer=new byte[65536];int count;while((count=input.read(buffer))!=-1){job.checkCancel();output.write(buffer,0,count);}outputFailure.complete(null);}catch(Exception failure){outputFailure.completeExceptionally(failure);child.destroy();}}):null;
            var diagnostics=new NativeDiagnostics();
            var errorDrain=Thread.ofVirtual().start(()->{try{diagnostics.drain(child.getErrorStream());}catch(IOException ignored){}});
            while(!child.waitFor(250,TimeUnit.MILLISECONDS))job.checkCancel();
            errorDrain.join(3000);if(outputDrain!=null){outputDrain.join(3000);outputFailure.get(3,TimeUnit.SECONDS);}if(inputDrain!=null){inputDrain.join(3000);inputFailure.get(3,TimeUnit.SECONDS);}job.checkCancel();
            if(child.exitValue()!=0){var failure=diagnostics.failure(child.exitValue());job.message(failure.getMessage());throw failure;}
            if(relay!=null)relay.check();
            if(dump){commit.commit();job.commitAcknowledged();}
            else {job.externalMutationAcknowledged();job.message("Restore completed. Native tools use their own session and can partially commit; the console transaction does not protect this restore.");}
        }catch(Exception failure){primary=failure;throw failure;}
        finally {
            var cleanup=new java.util.ArrayList<Exception>();
            try{if(job.process!=null&&job.process.isAlive()){job.process.destroy();if(!job.process.waitFor(3,TimeUnit.SECONDS))job.process.destroyForcibly();}}catch(Exception failure){cleanup.add(failure);}
            try{if(relay!=null)relay.close();}catch(Exception failure){cleanup.add(failure);}
            try{if(commit!=null)commit.close();}catch(Exception failure){cleanup.add(failure);}
            for(Path file:new Path[]{defaults})if(file!=null)try{Files.deleteIfExists(file);}catch(Exception failure){cleanup.add(failure);}
            if(primary!=null)for(var failure:cleanup)primary.addSuppressed(failure);
            else if(!cleanup.isEmpty())job.message("Native operation acknowledgement retained; private-file/process cleanup failed. Inspect local permissions; credentials are omitted.");
        }
    }
    private static String postgresDatabase(Profile profile,int port)throws java.net.URISyntaxException {
        // A database identifier is never libpq conninfo supplied by a workspace.
        String authority=new java.net.URI("postgresql",null,profile.getHost(),port,"/",null,null).toASCIIString();
        return authority+java.net.URLEncoder.encode(profile.getDatabase(),StandardCharsets.UTF_8).replace("+","%20");
    }

}
