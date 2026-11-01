package io.busystack.busydata.results;

import io.busystack.busydata.protocol.*;
import java.math.BigDecimal;
import java.util.*;
import java.util.function.BooleanSupplier;

/** Exact, bounded retained-selection calculations. Never executes database SQL. */
public final class RetainedAggregates {
    private final ResultStore results;
    private final RetainedViews views;
    public RetainedAggregates(ResultStore results,RetainedViews views){this.results=results;this.views=views;}
    public ResultAggregateReply calculate(ResultAggregateRequest request,BooleanSupplier cancelled)throws Exception {
        if(request.getFirstRow()<0||request.getRowCount()<1||request.getRowCount()>100_000||request.getOrdinalsCount()<1||request.getOrdinalsCount()>2048||
            (long)request.getRowCount()*request.getOrdinalsCount()>100_000)throw new IllegalArgumentException("Aggregate selection exceeds 100000 cells");
        var view=request.getViewId().isEmpty()?null:views.get(request.getViewId());
        var source=results.get(request.getResultId());
        if(view!=null&&view.source!=source)throw new IllegalArgumentException("Aggregate view/result owner mismatch");
        long count=view==null?source.rows():view.count;
        if(request.getFirstRow()>count-request.getRowCount())throw new IllegalArgumentException("Aggregate rows are outside the retained snapshot");
        var seen=new HashSet<Integer>();var states=new LinkedHashMap<Integer,Accumulator>();
        for(int ordinal:request.getOrdinalsList()){
            if(ordinal<1||ordinal>source.columns.size()||!seen.add(ordinal))throw new IllegalArgumentException("Aggregate requires distinct retained column ordinals");
            states.put(ordinal,new Accumulator());
        }
        long deadline=System.nanoTime()+2_000_000_000L;long bytes=0;
        try(var lease=source.lease();AutoCloseable viewLease=view==null?()->{}:view.lease()){
            for(long row=request.getFirstRow();row<request.getFirstRow()+request.getRowCount();row++){
                if(cancelled.getAsBoolean())throw new java.util.concurrent.CancellationException();
                if(System.nanoTime()>deadline)throw new java.sql.SQLTimeoutException("Aggregate deadline exceeded");
                var values=source.read(view==null?row:view.sourceRow(row));
                for(var entry:states.entrySet()){
                    Value value=values.getValues(entry.getKey()-1);bytes+=value.getSerializedSize();
                    if(bytes>8_388_608)throw new IllegalArgumentException("Aggregate selected-value budget exceeds 8MiB");
                    entry.getValue().add(value);
                }
            }
        }
        var out=ResultAggregateReply.newBuilder().setResultId(source.id).setViewId(request.getViewId()).setScope("selected-retained-cells")
            .setPartial(view==null?!source.complete||source.limited:view.partial);
        int responseBytes=out.build().getSerializedSize();
        for(var entry:states.entrySet()){
            var column=entry.getValue().finish(entry.getKey());responseBytes+=column.getSerializedSize()+8;
            if(responseBytes>1_048_576)throw new IllegalArgumentException("Aggregate response exceeds 1MiB; narrow the selected scope");
            out.addColumns(column);
        }
        return out.build();
    }
    private static final class Accumulator {
        long selected,nulls;String family="";boolean incompatible;BigDecimal sum=BigDecimal.ZERO;Value min,max;
        final Set<String> distinct=new HashSet<>();
        void add(Value value){
            selected++;
            if(value.getTruncated()||!value.getValueId().isEmpty())throw new IllegalArgumentException("Aggregate requires complete retained values");
            if(value.hasNullValue()){nulls++;return;}
            String next=switch(value.getDataCase()){
                case SIGNED_INTEGER,UNSIGNED_INTEGER,DECIMAL -> "numeric";
                case TEXT -> "text";case BOOLEAN -> "boolean";
                case TEMPORAL -> temporalFamily(value);
                default -> "unsupported";
            };
            if(family.isEmpty())family=next;else if(!family.equals(next))incompatible=true;
            if(next.equals("numeric")){
                BigDecimal number=new BigDecimal(Values.text(value));sum=sum.add(number);
                distinct.add("n:"+number.stripTrailingZeros().toPlainString());
            }else if(next.startsWith("temporal:"))distinct.add(next+":"+temporal(value));
            else distinct.add(next+":"+Base64.getEncoder().encodeToString(value.toByteArray()));
            if(!incompatible&&!next.equals("unsupported")){
                if(min==null||compare(value,min,next)<0)min=value;
                if(max==null||compare(value,max,next)>0)max=value;
            }
        }
        private static String temporalFamily(Value value){
            try{return "temporal:"+temporal(value).getClass().getName();}catch(java.time.DateTimeException|IllegalArgumentException unsupported){return "unsupported";}
        }
        private static Comparable<?> temporal(Value value){
            var time=value.getTemporal();String iso=time.getIso();
            if(iso.contains("T"))return time.getZone().equals("offset in value")?java.time.OffsetDateTime.parse(iso).toInstant():java.time.LocalDateTime.parse(iso);
            if(iso.contains(":")){
                if(time.getZone().equals("offset in value"))throw new IllegalArgumentException("Offset time ordering unavailable");
                var duration=java.util.regex.Pattern.compile("(-?)([0-9]{2,3}):([0-9]{2})(?::([0-9]{2})(?:\\.([0-9]{1,9}))?)?").matcher(iso);
                if(!duration.matches())throw new IllegalArgumentException("Native time ordering unavailable");
                int hours=Integer.parseInt(duration.group(2)),minutes=Integer.parseInt(duration.group(3)),seconds=duration.group(4)==null?0:Integer.parseInt(duration.group(4));
                if(hours>838||minutes>59||seconds>59)throw new IllegalArgumentException("Native time ordering unavailable");
                var result=BigDecimal.valueOf(hours*3600L+minutes*60L+seconds);
                if(duration.group(5)!=null)result=result.add(new BigDecimal("0."+duration.group(5)));
                return (duration.group(1).isEmpty()?result:result.negate()).stripTrailingZeros();
            }
            return java.time.LocalDate.parse(iso);
        }
        @SuppressWarnings({"rawtypes","unchecked"})
        static int compare(Value a,Value b,String family){if(family.startsWith("temporal:"))return ((Comparable)temporal(a)).compareTo(temporal(b));return switch(family){
            case "numeric" -> new BigDecimal(Values.text(a)).compareTo(new BigDecimal(Values.text(b)));
            case "boolean" -> Boolean.compare(a.getBoolean(),b.getBoolean());
            default -> a.getText().compareTo(b.getText());
        };}
        ColumnAggregate finish(int ordinal){
            var out=ColumnAggregate.newBuilder().setOrdinal(ordinal).setSelectedCount(selected).setNullCount(nulls).setNonNullCount(selected-nulls).setDistinctCount(distinct.size());
            if(incompatible||family.equals("unsupported"))return out.setAvailability(incompatible?"incompatible-types":"unsupported-ordering").build();
            if(min!=null)out.setMinimum(min).setMaximum(max);
            if(family.equals("numeric")&&selected>nulls){
                out.setSum(sum.toPlainString());
                try{out.setAverage(sum.divide(BigDecimal.valueOf(selected-nulls)).toPlainString());}
                catch(ArithmeticException repeating){out.setAverage(sum.toPlainString()+"/"+(selected-nulls));}
            }
            return out.setAvailability(family.equals("text")?"available-ordinal-text-order":"available").build();
        }
    }
}
