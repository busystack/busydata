package io.busystack.busydata.results;

import io.busystack.busydata.protocol.*;
import java.sql.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.function.BooleanSupplier;
import java.math.BigDecimal;

/** Disk-backed order/filter mappings over a fixed retained snapshot; no server SQL. */
public final class RetainedViews implements AutoCloseable {
    private final ResultStore store;
    private final ConcurrentMap<String,View> views=new ConcurrentHashMap<>();
    private final Semaphore builders=new Semaphore(2,true);
    public RetainedViews(ResultStore store){this.store=store;}
    public boolean contains(String id){return views.containsKey(id);}
    public final class View implements AutoCloseable {
        public final String id="view-"+UUID.randomUUID();
        public final ResultStore.Result source;
        private final ResultStore.Result.Lease sourceLease;
        private final ResultStore.PrivateIndex index;
        private final Connection connection;
        public final long snapshotRows;
        public final boolean partial;
        public long count;
        private int leases;
        private boolean disposalRequested;
        public synchronized AutoCloseable lease(){if(disposalRequested||disposed)throw new IllegalStateException("View disposal requested");leases++;var released=new java.util.concurrent.atomic.AtomicBoolean();return ()->{synchronized(View.this){if(released.getAndSet(true))return;leases--;if(disposalRequested&&leases==0)cleanup();}};}
        private boolean disposed;
        private View(ResultStore.Result source)throws Exception {
            this.source=source;sourceLease=source.lease();snapshotRows=source.rows();partial=!source.fetchFinished||!source.complete||source.limited;
            ResultStore.PrivateIndex file=null;Connection opened=null;
            try {
                file=store.privateIndex(128L*1024*1024);
                opened=DriverManager.getConnection("jdbc:sqlite:"+file.path);
                try(var statement=opened.createStatement()) {
                    statement.execute("PRAGMA journal_mode=OFF");statement.execute("PRAGMA synchronous=OFF");
                    statement.execute("PRAGMA cache_size=-1024");statement.execute("PRAGMA temp_store=MEMORY");
                    statement.execute("PRAGMA max_page_count=32768");
                }
                org.sqlite.Collation.create(opened,"retained",new org.sqlite.Collation(){protected int xCompare(String left,String right){return compareKey(left,right);}});
            } catch(Exception failure) {
                if(opened!=null)try{opened.close();}catch(Exception cleanup){failure.addSuppressed(cleanup);}
                if(file!=null)try{file.close();}catch(Exception cleanup){failure.addSuppressed(cleanup);}
                try{sourceLease.close();}catch(Exception cleanup){failure.addSuppressed(cleanup);}throw failure;
            }
            index=file;connection=opened;
        }
        public synchronized long sourceRow(long position)throws Exception {
            if(disposed||position<0||position>=count)throw new IllegalArgumentException("Retained view row unavailable");
            try(var statement=connection.prepareStatement("SELECT source FROM mapping WHERE position=?")) {
                statement.setLong(1,position);try(var rows=statement.executeQuery()){if(!rows.next())throw new IllegalStateException("View mapping missing");return rows.getLong(1);}
            }
        }
        public ResultViewInfo info(){return ResultViewInfo.newBuilder().setViewId(id).setResultId(source.id).setSourceRows(snapshotRows).setVisibleRows(count).setPartial(partial)
            .setAvailability((partial?"Fixed fetched-row snapshot; ":"Retained snapshot; ")+"exact numeric and ordinal retained-value ordering, independent of database collation; SQL was not executed").build();}
        public synchronized Page page(PageRequest request)throws Exception {
            if(request.getOffset()<0||request.getLimit()<1||request.getLimit()>500||request.getMaxBytes()<262144||request.getMaxBytes()>1048576)throw new IllegalArgumentException("Invalid retained-view page budget");
            if(disposalRequested)return Page.newBuilder().setState(PageState.PAGE_DISPOSED).setAvailability("View disposal requested").build();
            var page=Page.newBuilder().setFirstOffset(request.getOffset()).setNextOffset(request.getOffset()).setFetchedRows(count).setComplete(true).setLimited(partial).addAllColumns(source.columns).setAvailability(info().getAvailability());
            int bytes=page.build().getSerializedSize()+128;
            if(bytes>request.getMaxBytes())return page.clearColumns().setState(PageState.PAGE_METADATA_TOO_LARGE).build();
            if(request.getOffset()>=count)return page.setState(PageState.PAGE_END).build();
            for(long position=request.getOffset();position<count&&position<request.getOffset()+request.getLimit();position++) {
                long original=sourceRow(position);var row=source.read(original);int size=row.getSerializedSize()+24;
                if(bytes+size>request.getMaxBytes())return page.setState(page.getRowsCount()==0?PageState.PAGE_ROW_TOO_LARGE:PageState.PAGE_BYTE_LIMIT).build();
                page.addRows(row).addSourceRows(original).setNextOffset(position+1);bytes+=size;
            }
            return page.build();
        }
        public synchronized void close()throws Exception {
            disposalRequested=true;if(leases==0)cleanup();
        }
        private void cleanup()throws Exception {
            if(disposed)return;
            try { connection.close();index.close();sourceLease.close();disposed=true;views.remove(id); }
            catch(Exception failure){views.put(id,this);throw failure;}
        }
    }
    public View get(String id){var view=views.get(id);if(view==null)throw new IllegalArgumentException("Retained view is disposed or stale");return view;}
    public ResultViewInfo create(ResultViewRequest request,BooleanSupplier cancelled)throws Exception {
        if(request.getConditionsCount()>32||request.getOrderCount()>4)throw new IllegalArgumentException("Retained views support 32 conditions and four sort columns");
        if(!builders.tryAcquire())throw new IllegalStateException("Retained view build admission limit reached");
        View view=null;boolean adopted=false;
        try {
            var source=store.get(request.getResultId());
            var columns=new HashMap<String,Integer>();
            for(int i=0;i<source.columns.size();i++) {
                String label=source.columns.get(i).getName();
                if(columns.containsKey(label))columns.put(label,-1);else columns.put(label,i);
            }
            // Ordinals, not ambiguous labels, may be supplied as #1, #2, ... .
            for(int i=0;i<source.columns.size();i++)columns.put("#"+(i+1),i);
            var filters=new ArrayList<Integer>();var order=new ArrayList<Integer>();
            for(var condition:request.getConditionsList()){
                filters.add(column(columns,condition.getColumn()));
                if(condition.getValue().getSerializedSize()>8192)throw new IllegalArgumentException("Filter value exceeds 8KiB");
                if(condition.getPredicate()!=ValuePredicate.IS_NULL && condition.getPredicate()!=ValuePredicate.IS_NOT_NULL)key(condition.getValue());
            }
            for(var sort:request.getOrderList())order.add(column(columns,sort.getColumn()));
            view=new View(source);
            var fields=new ArrayList<String>();for(int i=0;i<order.size();i++)fields.add("k"+i+" TEXT COLLATE retained NOT NULL");
            var keys=new ArrayList<String>();for(int i=0;i<order.size();i++)keys.add("k"+i+(request.getOrder(i).getDescending()?" DESC":" ASC"));keys.add("source");
            fields.add("source INTEGER NOT NULL");
            try(var statement=view.connection.createStatement()) {
                statement.execute("CREATE TABLE ordered ("+String.join(",",fields)+", PRIMARY KEY ("+String.join(",",keys)+")) WITHOUT ROWID");
                statement.execute("CREATE TABLE mapping (position INTEGER PRIMARY KEY, source INTEGER NOT NULL)");
            }
            view.connection.setAutoCommit(false);
            try(var insert=view.connection.prepareStatement("INSERT INTO ordered VALUES ("+String.join(",",Collections.nCopies(order.size()+1,"?"))+")")) {
                for(long row=0;row<view.snapshotRows;row++) {
                    if((row&255)==0&&cancelled.getAsBoolean())throw new CancellationException();
                    var retained=source.read(row);boolean accepted=true;
                    for(int i=0;i<filters.size();i++) if(!matches(retained.getValues(filters.get(i)),request.getConditions(i))){accepted=false;break;}
                    if(!accepted)continue;
                    int keyBytes=0;
                    for(int i=0;i<order.size();i++){String value=key(retained.getValues(order.get(i)));keyBytes+=value.length()*2;if(keyBytes>16384)throw new IllegalArgumentException("Sort keys exceed the bounded 16KiB per-row key budget");insert.setString(i+1,value);}
                    insert.setLong(order.size()+1,row);insert.executeUpdate();
                }
            }
            // The primary B-tree already defines order: this scan needs no temporary sort.
            try(var statement=view.connection.createStatement();var rows=statement.executeQuery("SELECT source FROM ordered ORDER BY "+String.join(",",keys));var insert=view.connection.prepareStatement("INSERT INTO mapping VALUES (?,?)")) {
                while(rows.next()) {
                    if((view.count&255)==0&&cancelled.getAsBoolean())throw new CancellationException();
                    insert.setLong(1,view.count++);insert.setLong(2,rows.getLong(1));insert.executeUpdate();
                }
            }
            try(var statement=view.connection.createStatement()){statement.execute("DROP TABLE ordered");}
            view.connection.commit();view.connection.setAutoCommit(true);
            views.put(view.id,view);adopted=true;return view.info();
        } finally {
            try{if(view!=null&&!adopted)view.close();}finally{builders.release();}
        }
    }
    private static int column(Map<String,Integer> columns,String name){var index=columns.get(name);if(index==null||index<0)throw new IllegalArgumentException("Choose an unambiguous retained column ordinal");return index;}
    public static boolean matches(Value value,RowCondition condition) {
        if(condition.getPredicate()==ValuePredicate.IS_NULL)return value.hasNullValue();
        if(condition.getPredicate()==ValuePredicate.IS_NOT_NULL)return !value.hasNullValue();
        if(value.hasNullValue()||condition.getValue().hasNullValue())return false;
        int compared=compareKey(key(value),key(condition.getValue()));
        return switch(condition.getPredicate()){case EQUAL->compared==0;case NOT_EQUAL->compared!=0;case LESS->compared<0;case GREATER->compared>0;default->throw new IllegalArgumentException("Unsupported retained predicate");};
    }
    public static String key(Value value) {
        if(value.getTruncated()||!value.getValueId().isEmpty())throw new IllegalArgumentException("Full large values cannot be indexed within the bounded retained key budget; choose another column");
        if(value.hasDecimal() || value.hasSignedInteger() || value.hasUnsignedInteger())new BigDecimal(Values.text(value));
        return switch(value.getDataCase()) {
            case NULL_VALUE -> "0:";
            case SIGNED_INTEGER -> "1:"+value.getSignedInteger();case UNSIGNED_INTEGER -> "1:"+value.getUnsignedInteger();
            case DECIMAL -> "1:"+value.getDecimal();case REAL -> {if(!Double.isFinite(value.getReal()))throw new IllegalArgumentException("Nonfinite real ordering unavailable");yield "1:"+Double.toString(value.getReal());}
            case BOOLEAN -> "2:"+(value.getBoolean()?"1":"0");case TEXT -> "3:"+value.getText();case JSON -> "4:"+value.getJson();
            case BINARY -> "5:"+HexFormat.of().formatHex(value.getBinary().toByteArray());case TEMPORAL -> "6:"+value.getTemporal().getIso();
            default -> throw new IllegalArgumentException("This retained type has no exact comparison contract");
        };
    }
    public static int compareKey(String left,String right) {
        if(left.charAt(0)!=right.charAt(0))return Character.compare(left.charAt(0),right.charAt(0));
        if(left.startsWith("1:"))return new BigDecimal(left.substring(2)).compareTo(new BigDecimal(right.substring(2)));
        return left.compareTo(right);
    }
    public void dispose(String id)throws Exception{var view=views.get(id);if(view!=null)view.close();}
    public void close(){for(var view:List.copyOf(views.values()))try{view.close();}catch(Exception ignored){/* Charged cleanup remains owned by ResultStore. */}}
}
