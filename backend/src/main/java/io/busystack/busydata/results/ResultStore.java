package io.busystack.busydata.results;

import io.busystack.busydata.protocol.*;
import java.nio.file.*;
import java.io.*;
import java.util.*;
import java.util.concurrent.*;

public final class ResultStore implements AutoCloseable {
    /** A typed lifecycle failure; callers never classify diagnostic text. */
    public static final class Unavailable extends IllegalArgumentException {
        public Unavailable(){super("Retained result is unavailable");}
    }
    /** Private view indexes share the retained-result quota, reserved before SQLite writes. */
    public final class PrivateIndex implements AutoCloseable {
        public final Path path; private final long reserved; private boolean closed;
        private PrivateIndex(long maximum)throws IOException {
            reserved=maximum; reserve(maximum);
            Path created=null;
            try { if(usableSpace.applyAsLong(root)<maximum+64L*1024*1024)throw new IOException("RESULT_DISK_RESERVE");
                created=Files.createTempFile(root,"view-",".private"); privateFile(created); }
            catch(IOException error){release(maximum);if(created!=null)delete.delete(created);throw error;}
            path=created;indexes.put(path,this);
        }
        public synchronized void close()throws IOException {if(closed)return;delete.delete(path);closed=true;indexes.remove(path);release(reserved);}
    }
    private final ConcurrentMap<Path,PrivateIndex> indexes=new ConcurrentHashMap<>();
    public synchronized PrivateIndex privateIndex(long maximum)throws IOException {
        if(indexes.size()>=8||maximum<4096||maximum>128L*1024*1024)throw new IOException("Retained view index admission limit reached");
        return new PrivateIndex(maximum);
    }
    public final class Temporary implements AutoCloseable {
        public final Path path; private long bytes; private boolean closed; private volatile boolean pendingCleanup;
        private Temporary()throws IOException{path=Files.createTempFile(root,"transfer-",".private");try{privateFile(path);}catch(IOException primary){pendingCleanup=true;temporaries.put(path,this);try{close();}catch(IOException cleanup){primary.addSuppressed(cleanup);}throw primary;}}
        public OutputStream output()throws IOException {var stream=Files.newOutputStream(path);return new FilterOutputStream(stream){public void write(int value)throws IOException{write(new byte[]{(byte)value},0,1);}public void write(byte[] value,int offset,int length)throws IOException{reserveTransfer(length);bytes+=length;out.write(value,offset,length);}};}
        public synchronized void close()throws IOException{if(closed)return;pendingCleanup=true;delete.delete(path);closed=true;temporaries.remove(path);releaseTransfer(bytes);}
    }
    public Temporary temporary()throws IOException{retryTemporaryCleanup();synchronized(temporaryAdmission){if(temporaries.size()>=8)throw new IOException("Transfer temporary-file limit reached; resolve failed cleanup");var temporary=new Temporary();temporaries.put(temporary.path,temporary);return temporary;}}
    public void retryTemporaryCleanup(){for(var temporary:List.copyOf(temporaries.values()))if(temporary.pendingCleanup)try{temporary.close();}catch(IOException ignored){/* Remains reachable and quota charged. */}}
    public final class Result implements AutoCloseable {
        public final String id=UUID.randomUUID().toString();public volatile List<Column> columns;public final Profile targetProfile;public final String sourceSessionId;
        private final Path path,indexPath;private final RandomAccessFile file,index;private final Exception creationFailure;private long rowCount,bytes;
        private final Map<String,Path> cells=new HashMap<>();
        private final java.util.concurrent.locks.ReentrantLock rowIo=new java.util.concurrent.locks.ReentrantLock(true);
        public volatile boolean complete,limited,fetchFinished;private volatile boolean disposed,disposalRequested;
        private int leases;private boolean fileClosed,indexClosed;private String cleanupFailure="";
        public String jobId="",executionId="",documentId="";public int statementIndex;public final long created=System.currentTimeMillis();
        public volatile JobState jobState=JobState.FETCHING;
        public String sourceSql="",sourceSchema="";public boolean plan;
        private Value sqlProvenance;
        private long provenanceMetadata;
        private volatile io.busystack.busydata.metadata.RetainedMetadataProof metadataProof=io.busystack.busydata.metadata.RetainedMetadataProof.unavailable("UNAVAILABLE: execution metadata was not captured");
        private final Object proofLock=new Object();
        private boolean metadataProofCaptured,externalProofRetired;
        private long identityMetadata;
        private volatile io.busystack.busydata.metadata.PreparedMetadataWitness metadataWitness;
        public boolean attachMetadataWitness(io.busystack.busydata.metadata.PreparedMetadataWitness witness){synchronized(proofLock){if(metadataWitness!=null)throw new IllegalStateException("Retained metadata witness is immutable");if(disposalRequested||!metadataProof.available()||!witness.matches(sourceSessionId,metadataProof))return false;metadataWitness=witness;return true;}}
        public void verifyMetadataWitness(io.busystack.busydata.sessions.SessionRegistry.Session session,io.busystack.busydata.jobs.Jobs.Job job)throws Exception{if(targetProfile.getEngine()!=Engine.MARIADB)return;var witness=metadataWitness;if(witness==null)throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.INCOMPLETE_METADATA);witness.verify(session,job);}
        public io.busystack.busydata.metadata.RetainedMetadataProof metadataProof(){return metadataProof;}
        public void captureMetadataProof(io.busystack.busydata.metadata.MetadataSnapshot snapshot,io.busystack.busydata.adapters.JdbcAdapter.LiveContext context){captureMetadataProof(io.busystack.busydata.metadata.RetainedMetadataProof.captureExecution(snapshot,columns,targetProfile,sourceSessionId,sourceSql,context));}
        public void captureMetadataProof(io.busystack.busydata.metadata.RetainedMetadataProof captured){try(var prepared=prepareProof(this,captured)){prepared.complete(prepared.proof());}}
        public void invalidateMetadataProof(String reason){synchronized(proofLock){metadataProof=metadataProof.invalidate(reason);}}
        public io.busystack.busydata.metadata.PreparedMetadataWitness retireExternalMetadataProof(String reason){synchronized(proofLock){externalProofRetired=true;metadataProof=metadataProof.invalidateExternal(reason);var retired=metadataWitness;metadataWitness=null;return retired;}}
        public void invalidateExternalMetadataProof(String reason){var retired=retireExternalMetadataProof(reason);if(retired!=null)retired.close();}
        public synchronized void captureSql(String sql)throws Exception {
            if(sqlProvenance!=null)throw new IllegalStateException("SQL provenance is immutable");
            if(sql.isEmpty())return;
            int end=sql.offsetByCodePoints(0,Math.min(1024,sql.codePointCount(0,sql.length())));
            var preview=Value.newBuilder().setText(sql.substring(0,end)).setTruncated(end<sql.length());
            if(end<sql.length()) {
                String id=storeText("",new StringReader(sql));
                preview.setValueId(id).setOriginalBytes(Files.size(cell(id)));
            }
            var value=preview.build();
            reserveProvenanceMetadata(value.getSerializedSize());
            provenanceMetadata=value.getSerializedSize();sqlProvenance=value;
        }
        public io.busystack.busydata.analysis.LexicalSettings sourceLexical=io.busystack.busydata.analysis.LexicalSettings.DEFAULT;
        public final class Lease implements AutoCloseable {
            private boolean released;
            private Lease(){}
            public void close()throws Exception{synchronized(Result.this){if(released)return;released=true;leases--;if(disposalRequested&&leases==0)cleanup();}}
        }
        public synchronized Lease lease(){if(disposed||disposalRequested)throw new IllegalStateException("Result disposal was requested; new readers are not accepted");if(leases>=64)throw new IllegalStateException("Result reader limit reached; finish or cancel active readers");leases++;return new Lease();}
        public synchronized RetainedResult retained(){var entry=RetainedResult.newBuilder().setResult(StatementResult.newBuilder().setStatementIndex(statementIndex).setPlan(plan).setResultId(id).addAllColumns(columns).setFetchedRows(rows()).setComplete(complete).setLimited(limited).setUpdateCount(-1)).setJobId(jobId).setExecutionId(executionId).setDocumentId(documentId).setSessionId(sourceSessionId).setCreatedUnixMs(created).setDisposalPending(disposalRequested).setLeases(leases).setState(jobState).setTarget(targetProfile).setSourceSchema(sourceSchema).setAvailability(cleanupFailure.isEmpty()?(disposalRequested?"Disposal waits for active readers":"retained"):cleanupFailure);if(sqlProvenance!=null)entry.setSqlProvenance(sqlProvenance);return entry.build();}
        private Result(List<Column> columns,Profile targetProfile,String sourceSessionId){
            this.columns=List.copyOf(columns);this.targetProfile=targetProfile;this.sourceSessionId=sourceSessionId;path=root.resolve(id+".rows");indexPath=root.resolve(id+".index");RandomAccessFile rowsFile=null,indexFile=null;Exception primary=null;
            try{createFile.create(path);privateFile(path);createFile.create(indexPath);privateFile(indexPath);rowsFile=new RandomAccessFile(path.toFile(),"rw");indexFile=new RandomAccessFile(indexPath.toFile(),"rw");}
            catch(Exception failure){primary=failure;fetchFinished=true;jobState=JobState.FAILED;}
            file=rowsFile;index=indexFile;creationFailure=primary;
        }
        public void append(Row row)throws Exception {rowIo.lock();try{
            if(disposed||disposalRequested)throw new IllegalStateException("Result disposed");int size=row.getSerializedSize();
            if(size>262_144)throw new IOException("ROW_TOO_WIDE");if(rowCount>=1_000_000)throw new IOException("ROW_QUOTA");
            long position=file.length(),indexPosition=index.length();reserve(size+12);try{file.seek(position);file.writeInt(size);row.writeTo(new DataOutputStream(new OutputStream(){public void write(int b)throws IOException{file.write(b);}public void write(byte[] b,int off,int len)throws IOException{file.write(b,off,len);}}));index.seek(indexPosition);index.writeLong(position);rowCount++;bytes+=size+12;}catch(Exception e){try{file.setLength(position);index.setLength(indexPosition);release(size+12);}catch(IOException cleanup){bytes+=size+12;e.addSuppressed(cleanup);}throw e;}
        }finally{rowIo.unlock();}}
        public long rows(){rowIo.lock();try{return rowCount;}finally{rowIo.unlock();}}
        public Row read(long offset)throws Exception{rowIo.lock();try{if(disposed)throw new IllegalStateException("Result disposed");if(offset<0||offset>=rowCount)throw new IllegalArgumentException("Invalid row");index.seek(offset*8);file.seek(index.readLong());int size=file.readInt();if(size<0||size>262_144)throw new IOException("Corrupt private result row");byte[] data=new byte[size];file.readFully(data);return Row.parseFrom(data);}finally{rowIo.unlock();}}
        public Page page(PageRequest r)throws Exception {rowIo.lock();try{
            validatePage(r);
            var page=Page.newBuilder().setFirstOffset(r.getOffset()).setNextOffset(r.getOffset()).setFetchedRows(rowCount).setComplete(complete).setLimited(limited);
            if(disposed||disposalRequested)return page.setState(PageState.PAGE_DISPOSED).setAvailability("Result disposal was requested; SQL is not rerun").build();
            page.addAllColumns(columns);int used=page.build().getSerializedSize()+128;
            if(used>r.getMaxBytes())return page.clearColumns().setState(PageState.PAGE_METADATA_TOO_LARGE).setAvailability("Column metadata exceeds this page budget").build();
            if(r.getOffset()>=rowCount)return page.setState(fetchFinished?PageState.PAGE_END:PageState.PAGE_WAITING).setAvailability(fetchFinished?"End of retained rows":"Rows have not yet been fetched").build();
            try {
                for(long i=r.getOffset();i<rowCount&&i<r.getOffset()+r.getLimit();i++){
                    var row=read(i);int size=row.getSerializedSize()+8;
                    if(used+size>r.getMaxBytes()){
                        page.setState(page.getRowsCount()==0?PageState.PAGE_ROW_TOO_LARGE:PageState.PAGE_BYTE_LIMIT);
                        page.setAvailability(page.getRowsCount()==0?"A retained row plus metadata exceeds this page budget":"Continue at next_offset; this page reached its byte budget");break;
                    }
                    page.addRows(row);used+=size;page.setNextOffset(i+1);
                }
            }catch(IOException error){return page.clearRows().setNextOffset(r.getOffset()).setState(PageState.PAGE_FAILED).setAvailability("Retained data could not be read; retry or dispose this result explicitly").build();}
            return page.build();
        }finally{rowIo.unlock();}}
        private OutputStream cellOutput(Path target)throws IOException {
            var stream=Files.newOutputStream(target);return new FilterOutputStream(stream){public void write(int b)throws IOException{write(new byte[]{(byte)b},0,1);}public void write(byte[] b,int off,int len)throws IOException{reserve(len);bytes+=len;out.write(b,off,len);}};
        }
        public synchronized String storeBinary(byte[] prefix,InputStream rest)throws Exception {
            String value=UUID.randomUUID().toString();Path target=root.resolve(value+".cell");Files.createFile(target);cells.put(value,target);privateFile(target);
            try(var out=cellOutput(target)){out.write(prefix);rest.transferTo(out);}return value;
        }
        public synchronized String storeText(String prefix,Reader rest)throws Exception {
            String value=UUID.randomUUID().toString();Path target=root.resolve(value+".cell");Files.createFile(target);cells.put(value,target);privateFile(target);
            try(var out=new OutputStreamWriter(cellOutput(target),java.nio.charset.StandardCharsets.UTF_8)){out.write(prefix);rest.transferTo(out);}return value;
        }
        public synchronized Path cell(String value){if(disposed||!cells.containsKey(value))throw new IllegalArgumentException("Value stale or unavailable");return cells.get(value);}
        public ValueChunk value(ValueRequest r)throws Exception {
            if(r.getMaxBytes()<1||r.getMaxBytes()>65_536||r.getOffset()<0)throw new IllegalArgumentException("Value chunks must be 1–65536 bytes");try(var lease=lease()){Path target=cell(r.getValueId());long size=Files.size(target);if(r.getOffset()>size)throw new IllegalArgumentException("Offset exceeds cell size");
            try(var in=new RandomAccessFile(target.toFile(),"r")){in.seek(r.getOffset());byte[] chunk=new byte[(int)Math.min(r.getMaxBytes(),size-r.getOffset())];in.readFully(chunk);return ValueChunk.newBuilder().setData(com.google.protobuf.ByteString.copyFrom(chunk)).setTotalBytes(size).setComplete(r.getOffset()+chunk.length==size).build();}}
        }
        public synchronized void close()throws Exception{if(disposed)return;disposalRequested=true;if(leases==0)cleanup();}
        private void cleanup()throws Exception{rowIo.lock();try{
            final io.busystack.busydata.metadata.PreparedMetadataWitness witness;
            synchronized(proofLock){witness=metadataWitness;metadataWitness=null;}if(witness!=null)witness.close();
            Exception failure=null;
            try{if(!fileClosed){if(file!=null)file.close();fileClosed=true;}}catch(Exception error){failure=error;}
            try{if(!indexClosed){if(index!=null)index.close();indexClosed=true;}}catch(Exception error){if(failure==null)failure=error;else failure.addSuppressed(error);}
            for(var target:paths())try{delete.delete(target);}catch(Exception error){if(failure==null)failure=error;else failure.addSuppressed(error);}
            if(failure!=null){cleanupFailure="Disposal cleanup failed; quota remains charged. Retry disposal after resolving file access.";throw failure;}
            final List<Column> retiredColumns;final long retiredIdentity;
            synchronized(proofLock){disposed=true;retiredColumns=columns;retiredIdentity=identityMetadata;identityMetadata=0;metadataProof=io.busystack.busydata.metadata.RetainedMetadataProof.unavailable("RESULT_DISPOSED");}
            release(bytes);bytes=0;results.remove(id);catalogRevision.incrementAndGet();releaseMetadata(retiredColumns,provenanceMetadata+retiredIdentity);provenanceMetadata=0;
        }finally{rowIo.unlock();}}
        private List<Path> paths(){var targets=new ArrayList<Path>();targets.add(path);targets.add(indexPath);targets.addAll(cells.values());return targets;}
    }
    @FunctionalInterface public interface DeleteFile {void delete(Path path)throws IOException;}
    @FunctionalInterface public interface CreateFile {void create(Path path)throws IOException;}
    private final CreateFile createFile;
    private final DeleteFile delete;private long metadataBytes;private final java.util.concurrent.atomic.AtomicLong catalogRevision=new java.util.concurrent.atomic.AtomicLong(1);
    private final Object temporaryAdmission=new Object();
    private final ConcurrentMap<Path,Temporary> temporaries=new ConcurrentHashMap<>();
    private final Path root;private final ConcurrentMap<String,Result> results=new ConcurrentHashMap<>();private long allocated,transferAllocated;private final long quota;
    public static final long TRANSFER_QUOTA=16L*1024*1024*1024;
    public ResultStore(Path support,long quota)throws Exception{this(support,quota,Files::deleteIfExists);}
    public ResultStore(Path support,long quota,DeleteFile delete)throws Exception{this(support,quota,delete,Files::createFile);}
    private final java.util.function.ToLongFunction<Path> usableSpace;
    public ResultStore(Path support,long quota,DeleteFile delete,CreateFile createFile)throws Exception{this(support,quota,delete,createFile,path->path.toFile().getUsableSpace());}
    public ResultStore(Path support,long quota,DeleteFile delete,CreateFile createFile,java.util.function.ToLongFunction<Path> usableSpace)throws Exception{this.quota=quota;this.delete=delete;this.createFile=createFile;this.usableSpace=usableSpace;Path parent=support.resolve("results");Files.createDirectories(parent);privateDirectory(parent);
        // Metadata lease guarantees no other backend is writing these private files.
        try(var paths=Files.newDirectoryStream(parent)){int count=0;for(var p:paths){if(++count>16384)throw new IOException("Private result directory entry budget exceeded; resolve stale files before starting");String name=p.getFileName().toString();if(Files.isRegularFile(p,LinkOption.NOFOLLOW_LINKS)&&(name.matches("[a-f0-9-]{36}\\.(rows|index|cell)")||(name.startsWith("transfer-")||name.startsWith("view-"))&&name.endsWith(".private")))Files.delete(p);}}
        root=parent;
    }
    public Result create(List<Column> columns)throws Exception{return create(columns,Profile.getDefaultInstance(),"");}
    public Result create(List<Column> columns,Profile profile,String sessionId,io.busystack.busydata.metadata.RetainedMetadataProof proof)throws Exception{
        var raw=columns.stream().map(column->column.toBuilder().clearMetadataIdentity().clearMetadataSnapshotRevision().build()).toList();
        var result=create(raw,profile,sessionId);
        try(var prepared=prepareProof(result,proof)){return prepared.complete(prepared.proof());}
        catch(Exception failure){try{result.close();}catch(Exception cleanup){failure.addSuppressed(cleanup);}throw failure;}
    }
    /** Quota and column projections are prepared before entering a source
     * publication monitor. Completion performs only bounded reference updates. */
    public final class PreparedProof implements AutoCloseable {
        private final Result result;private final io.busystack.busydata.metadata.RetainedMetadataProof candidate;private final List<Column> enriched;
        private final long identityBytes,reservedBytes,reclaimedColumns;private boolean completed,transferred,closed;
        private PreparedProof(Result result,io.busystack.busydata.metadata.RetainedMetadataProof candidate,List<Column> enriched,long identityBytes,long reservedBytes,long reclaimedColumns){this.result=result;this.candidate=candidate;this.enriched=enriched;this.identityBytes=identityBytes;this.reservedBytes=reservedBytes;this.reclaimedColumns=reclaimedColumns;}
        public io.busystack.busydata.metadata.RetainedMetadataProof proof(){return candidate;}
        public Result complete(io.busystack.busydata.metadata.RetainedMetadataProof admitted){
            synchronized(result.proofLock){
                if(closed||completed||result.metadataProofCaptured)throw new IllegalStateException("Retained metadata proof is immutable");
                if(result.disposalRequested||result.disposed)throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.RESULT_DISPOSED);
                if((admitted.available()||admitted.capturedStructure())&&admitted!=candidate)throw new IllegalArgumentException("Unowned retained metadata proof");
                if(result.externalProofRetired)admitted=admitted.invalidateExternal("Native restore permanently retired this retained source");
                result.metadataProofCaptured=true;completed=true;
                if(admitted.available()||admitted.capturedStructure()){result.columns=enriched;result.identityMetadata=identityBytes;transferred=true;}
                result.metadataProof=admitted;return result;
            }
        }
        @Override public void close(){final long release;synchronized(result.proofLock){if(closed)return;closed=true;release=transferred?reclaimedColumns:reservedBytes;}if(release!=0)releasePreparedMetadata(release);}
    }
    public PreparedProof prepareProof(Result result,io.busystack.busydata.metadata.RetainedMetadataProof captured){
        var proof=Objects.requireNonNull(captured);var columns=result.columns;var enriched=new ArrayList<Column>(columns.size());
        for(var column:columns){var next=column.toBuilder().clearMetadataIdentity().clearMetadataSnapshotRevision();var identity=proof.columns().get(column.getOrdinal());if(proof.available()&&identity!=null&&!identity.identity().isEmpty())next.setMetadataIdentity(identity.identity()).setMetadataSnapshotRevision(proof.snapshotRevision());enriched.add(next.build());}
        boolean evidence=proof.available()||proof.capturedStructure();long identity=evidence?proof.estimatedBytes():0;long wire=enriched.stream().mapToLong(Column::getSerializedSize).sum();long delta=wire-columns.stream().mapToLong(Column::getSerializedSize).sum();long extra=Math.max(0,delta);long reserved=identity+extra;
        if(evidence&&!reservePreparedMetadata(identity,extra,wire)){proof=io.busystack.busydata.metadata.RetainedMetadataProof.unavailable(io.busystack.busydata.metadata.MetadataState.LIMITED,"Retained identity metadata quota reached");identity=0;reserved=0;}
        var prepared=new PreparedProof(result,proof,List.copyOf(enriched),identity,reserved,Math.max(0,-delta));
        final boolean unavailable;
        synchronized(result.proofLock){
            unavailable=result.metadataProofCaptured||result.disposalRequested||result.disposed;
            if(!unavailable&&!result.externalProofRetired)result.metadataProof=proof.invalidateExternal("Execution metadata proof is pending atomic admission");
        }
        if(unavailable){prepared.close();throw new IllegalStateException("Retained metadata proof is unavailable or already captured");}
        return prepared;
    }
    public synchronized Result create(List<Column> columns,Profile profile,String sessionId)throws Exception{if(results.size()>=64)throw new IllegalStateException("Dispose old results (64 retained result limit)");long size=columns.stream().mapToLong(Column::getSerializedSize).sum();if(columns.isEmpty()||columns.size()>2048||size>262144||metadataBytes+size>16L*1024*1024)throw new IllegalArgumentException("Result column metadata budget exceeded");var result=new Result(columns,profile,sessionId);results.put(result.id,result);catalogRevision.incrementAndGet();metadataBytes+=size;if(result.creationFailure!=null){try{result.close();}catch(Exception cleanup){result.creationFailure.addSuppressed(cleanup);}throw result.creationFailure;}return result;}
    private synchronized void reserveProvenanceMetadata(long bytes){if(bytes>8192||metadataBytes+bytes>16L*1024*1024)throw new IllegalArgumentException("Result provenance metadata budget exceeded");metadataBytes+=bytes;}
    private synchronized boolean reservePreparedMetadata(long identity,long extra,long wire){if(identity<0||identity>1_048_576||extra<0||wire>262144||metadataBytes+identity+extra>16L*1024*1024)return false;metadataBytes+=identity+extra;return true;}
    private synchronized void releasePreparedMetadata(long bytes){metadataBytes-=bytes;}
    public void invalidateMetadataProof(String sourceKey,String catalog,String schema,String table,String reason){
        for(var result:results.values()){var proof=result.metadataProof();if(proof.sourceKey().equals(sourceKey)&&(catalog.isEmpty()||catalog.equals(proof.catalog()))&&(schema.isEmpty()||schema.equals(proof.schema()))&&(table.isEmpty()||table.equals(proof.table())))result.invalidateMetadataProof(reason);}
    }
    /** Memory-only retirement happens while the source mutation lease is still
     * active. Physical close is a separate step after Source is unlocked. */
    public List<io.busystack.busydata.metadata.PreparedMetadataWitness> retireExternalMetadataProofs(String sourceKey,String reason){
        var retired=new ArrayList<io.busystack.busydata.metadata.PreparedMetadataWitness>();
        for(var result:results.values())if(result.metadataProof().sourceKey().equals(sourceKey)){var witness=result.retireExternalMetadataProof(reason);if(witness!=null)retired.add(witness);}
        return List.copyOf(retired);
    }
    public static void closeRetiredMetadataWitnesses(List<io.busystack.busydata.metadata.PreparedMetadataWitness> retired){RuntimeException failure=null;for(var witness:retired)try{witness.close();}catch(RuntimeException error){if(failure==null)failure=error;else failure.addSuppressed(error);}if(failure!=null)throw failure;}
    public void invalidateExternalMetadataProof(String sourceKey,String reason){closeRetiredMetadataWitnesses(retireExternalMetadataProofs(sourceKey,reason));}
    private synchronized void releaseMetadata(List<Column> columns,long provenance){metadataBytes-=columns.stream().mapToLong(Column::getSerializedSize).sum()+provenance;}
    public void finishJob(String jobId,JobState state){for(var result:results.values())if(result.jobId.equals(jobId))result.jobState=state;}
    public RetainedList list(RetainedRequest request){
        if(request.getLimit()<1||request.getLimit()>32||request.getOffset()<0)throw new IllegalArgumentException("Retained listing requires 1–32 entries");
        long revision=catalogRevision.get();if(request.getCatalogRevision()!=0&&request.getCatalogRevision()!=revision)throw new IllegalStateException("Retained catalog changed; start a new listing");
        var entries=results.values().stream().sorted(Comparator.comparingLong((Result r)->r.created).thenComparing(r->r.id)).toList();
        var out=RetainedList.newBuilder();int next=request.getOffset(),bytes=128;
        for(int i=next;i<entries.size()&&out.getResultsCount()<request.getLimit();i++){
            var entry=entries.get(i).retained();int size=entry.getSerializedSize()+8;if(bytes+size>1_048_576)break;
            out.addResults(entry);bytes+=size;next=i+1;
        }
        if(catalogRevision.get()!=revision)throw new IllegalStateException("Retained catalog changed during listing");
        return out.setNextOffset(next).setComplete(next>=entries.size()).setCatalogRevision(revision).build();
    }
    public void dispose(String id)throws Exception{var result=results.get(id);if(result==null)return;if(!result.fetchFinished)throw new IllegalStateException("Cancel the job or wait for fetching before disposal");result.close();}
    public Result get(String id){var r=results.get(id);if(r==null)throw new Unavailable();return r;}
    public Page page(PageRequest request)throws Exception {
        validatePage(request);
        var result=results.get(request.getResultId());
        if(result==null)return Page.newBuilder().setFirstOffset(request.getOffset()).setNextOffset(request.getOffset()).setState(PageState.PAGE_DISPOSED).setAvailability("Result was disposed or is unavailable in this backend instance").build();
        return result.page(request);
    }
    private static void validatePage(PageRequest request){if(request.getLimit()<1||request.getLimit()>500||request.getMaxBytes()<262_144||request.getMaxBytes()>1_048_576||request.getOffset()<0||request.getResultId().length()>64)throw new IllegalArgumentException("Page limits must be 1–500 rows and 256KiB–1MiB with a valid result handle");}
    private synchronized void reserve(long bytes)throws IOException{if(allocated+bytes>quota)throw new IOException("RESULT_DISK_QUOTA");allocated+=bytes;}
    private synchronized void release(long bytes){allocated-=bytes;}
    // FileStore enumerates /proc mounts on Linux, which strict Snap correctly
    // denies. Query the owned path directly (statvfs/GetDiskFreeSpaceEx) without
    // broadening confinement; an unavailable/zero answer still rejects writes.
    private synchronized void reserveTransfer(long bytes)throws IOException{if(transferAllocated+bytes>TRANSFER_QUOTA)throw new IOException("IMPORT_SNAPSHOT_QUOTA");if(usableSpace.applyAsLong(root)<bytes+64L*1024*1024)throw new IOException("IMPORT_SNAPSHOT_DISK_RESERVE");transferAllocated+=bytes;}
    private synchronized void releaseTransfer(long bytes){transferAllocated-=bytes;}
    public synchronized long transferBytes(){return transferAllocated;}
    public synchronized long bytes(){return allocated;}
    public void close(){for(var index:List.copyOf(indexes.values()))try{index.close();}catch(IOException ignored){}for(var temporary:List.copyOf(temporaries.values()))try{temporary.close();}catch(IOException ignored){}for(var r:List.copyOf(results.values()))try{r.close();}catch(Exception ignored){}}
    public static void privateDirectory(Path path)throws IOException{try{Files.setPosixFilePermissions(path,java.nio.file.attribute.PosixFilePermissions.fromString("rwx------"));}catch(UnsupportedOperationException ignored){}}
    public static void privateFile(Path path)throws IOException{try{Files.setPosixFilePermissions(path,java.nio.file.attribute.PosixFilePermissions.fromString("rw-------"));}catch(UnsupportedOperationException ignored){}}
}
