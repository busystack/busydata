package io.busystack.busydata.schema;

import io.busystack.busydata.metadata.TableStructure;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.rpc.WorkbenchFailure;
import java.util.*;

/** Pure intentions from the central native structure; no SQL, JDBC or type coercion. */
final class CloneRowPolicy {
    private CloneRowPolicy(){}
    private record Key(List<String> columns,boolean nullsDistinct){}
    private static WorkbenchFailure incomplete(){return new WorkbenchFailure(WorkbenchFailure.Reason.INCOMPLETE_METADATA);}
    private static WorkbenchFailure unsupported(){return new WorkbenchFailure(WorkbenchFailure.Reason.UNSUPPORTED);}
    private static String fact(SchemaObject object,String name){String value=object.getPropertiesOrDefault(name,"");if(value.isEmpty())throw incomplete();return value;}
    private static boolean flag(SchemaObject object,String name){return switch(fact(object,name)){case "true"->true;case "false"->false;default->throw incomplete();};}
    private static int count(SchemaObject object,String name){try{int value=Integer.parseInt(fact(object,name));if(value<1||value>2048)throw incomplete();return value;}catch(NumberFormatException unavailable){throw incomplete();}}
    private static void sameScope(SchemaObject object,SchemaObject scope){
        if(!object.getCatalog().equals(scope.getCatalog())||!object.getSchema().equals(scope.getSchema())||!object.getTable().equals(scope.getTable()))throw incomplete();
    }
    static Set<String> omitted(TableStructure table,Map<String,Value> retained){
        if(table.columns().isEmpty()||table.columns().size()>2048||table.indexes().size()>32768||table.constraints().size()>32768)throw incomplete();
        var columns=new HashMap<String,SchemaObject>();var scope=table.columns().getFirst();
        for(var column:table.columns()){
            sameScope(column,scope);if(column.getKind()!=ObjectKind.COLUMN||!table.types().containsKey(column.getName())||columns.put(column.getName(),column)!=null)throw incomplete();
        }
        if(!columns.keySet().equals(table.types().keySet())||!columns.keySet().containsAll(retained.keySet()))throw incomplete();
        if(!columns.keySet().containsAll(table.generated()))throw incomplete();
        for(var identity:table.identities())if(identity.isEmpty()||!columns.keySet().containsAll(identity))throw incomplete();
        var omitted=new TreeSet<String>(table.generated());
        // Row identity stays unchanged and is not a clone key: JDBC can include
        // payload attributes in a unique-index identity. Native key counts decide.
        for(var column:table.columns())if(!column.getPropertiesOrDefault("identityKind","").isEmpty())omitted.add(column.getName());
        boolean primaryConstraint=false;int uniqueConstraints=0;
        for(var constraint:table.constraints()){
            sameScope(constraint,scope);
            if(constraint.getKind()!=ObjectKind.CONSTRAINT)throw incomplete();
            switch(SchemaConstraints.kind(fact(constraint,"type"))){
                case "p"->{if(primaryConstraint)throw incomplete();primaryConstraint=true;}
                case "u"->uniqueConstraints++;
                case "f","c","n"->{}
                // Exclusion/constraint-trigger semantics cannot be reconstructed from labels.
                default->throw unsupported();
            }
        }
        int uniqueIndexes=0,primaryIndexes=0,components=0;var names=new HashSet<String>();var computedKeys=new ArrayList<Key>();
        for(var index:table.indexes()){
            sameScope(index,scope);if(index.getKind()!=ObjectKind.INDEX||!names.add(index.getName()))throw incomplete();
            if(!fact(index,"uniquenessAvailability").equals("AVAILABLE"))throw incomplete();
            String uniqueness=fact(index,"uniqueness");
            if(uniqueness.equals("NON_UNIQUE"))continue;
            if(!uniqueness.equals("UNIQUE")||!fact(index,"indexStructureVersion").equals("2"))throw incomplete();
            uniqueIndexes++;
            if(!fact(index,"columnComponentsComplete").equals("true"))throw incomplete();
            String state=fact(index,"indexStateAvailability");
            if(state.equals("AVAILABLE")){
                if(!flag(index,"valid")||!flag(index,"ready")||!flag(index,"live"))throw unsupported();
            }else if(!state.equals("NOT_EXPOSED"))throw incomplete();
            if(flag(index,"partial"))throw unsupported();
            if(!fact(index,"predicateAvailability").equals("ABSENT"))throw incomplete();
            int total=count(index,"columnCount"),keys=count(index,"keyColumnCount");if(keys>total||(components+=total)>32768)throw incomplete();
            boolean primary=flag(index,"primary");if(primary)primaryIndexes++;
            boolean nullsDistinct=switch(fact(index,"uniqueNullsPolicy")){case "DISTINCT"->true;case "NOT_DISTINCT"->false;default->throw incomplete();};
            var keyColumns=new ArrayList<String>();boolean computed=false;
            for(int ordinal=0;ordinal<total;ordinal++){
                if(flag(index,"included."+ordinal)!=(ordinal>=keys))throw incomplete();
                if(ordinal>=keys)continue; // INCLUDE attributes never acquire uniqueness semantics.
                if(!fact(index,"keyKind."+ordinal).equals("COLUMN"))throw unsupported();
                String name=fact(index,"column."+ordinal);var column=columns.get(name);if(column==null||keyColumns.contains(name))throw incomplete();keyColumns.add(name);
                boolean identity=!column.getPropertiesOrDefault("identityKind","").isEmpty();
                boolean generated=table.generated().contains(name)&&!identity;
                computed|=generated;
                var value=retained.get(name);
                boolean preserveNull=!primary&&nullsDistinct&&!table.generated().contains(name)&&value!=null&&value.hasNullValue();
                if(!preserveNull)omitted.add(name);
            }
            if(computed)computedKeys.add(new Key(List.copyOf(keyColumns),nullsDistinct));
        }
        if(primaryIndexes>1||primaryConstraint!=(primaryIndexes==1)||uniqueIndexes-primaryIndexes<uniqueConstraints)throw incomplete();
        // A generated expression may reproduce a unique value from copied inputs.
        // Only a plain, retained, preserved NULL under native DISTINCT policy proves safety.
        for(var key:computedKeys){
            boolean witness=key.nullsDistinct()&&key.columns().stream().anyMatch(name->!omitted.contains(name)&&!table.generated().contains(name)&&retained.containsKey(name)&&retained.get(name).hasNullValue());
            if(!witness)throw unsupported();
        }
        return Collections.unmodifiableSet(omitted);
    }
}
