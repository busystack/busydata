package io.busystack.busydata.analysis.language;

import java.util.*;
import java.util.function.ToIntFunction;
import io.busystack.busydata.protocol.Engine;
import io.busystack.busydata.analysis.language.RoutineSignatures.*;
import io.busystack.busydata.analysis.language.SqlTypes.*;

/** Deterministic argument-dependent selection over captured, visible signatures.
 * Namespace precedence is established by SemanticCatalog before this stage. */
public final class RoutineOverloads {
    public record Selection(List<Signature> candidates,boolean complete){public Selection{candidates=List.copyOf(candidates);}public Optional<Signature> unique(){return complete&&candidates.size()==1?Optional.of(candidates.getFirst()):Optional.empty();}}
    private RoutineOverloads(){}
    public static Selection select(List<Signature> signatures,List<Type> arguments,boolean namespaceComplete,Engine engine,AnalysisBudget budget){
        budget.check();if(!namespaceComplete||signatures.stream().anyMatch(s->!s.complete()))return new Selection(signatures,false);
        var inputs=new IdentityHashMap<Signature,List<Parameter>>();long work=0;
        for(var signature:signatures){budget.check();work+=signature.parameters().size()+(long)arguments.size();if(work>65_536)return new Selection(signatures,false);inputs.put(signature,signature.parameters().stream().filter(p->!Set.of("OUT","TABLE","RETURN").contains(p.mode())).toList());}
        var candidates=new ArrayList<Signature>();
        for(var signature:signatures){budget.check();if(!signature.accepts(arguments.size()))continue;boolean accepts=true;for(int index=0;index<arguments.size();index++){
            budget.check();Type target=parameter(inputs.get(signature),index);if(target==null||!SqlTypes.implicitlyCoercible(arguments.get(index),target,engine)){accepts=false;break;}}
            if(accepts)candidates.add(signature);
        }
        if(candidates.size()<2)return new Selection(candidates,true);
        candidates=best(candidates,s->score(inputs.get(s),arguments,engine,false,budget));
        if(candidates.size()<2)return new Selection(candidates,true);
        // PostgreSQL overload resolution prefers declared preferred types only
        // after exact input matches. A nearest numeric width is not a tie-break.
        if(engine==Engine.POSTGRESQL){
            candidates=best(candidates,s->score(inputs.get(s),arguments,engine,true,budget));
            for(int index=0;index<arguments.size()&&candidates.size()>1;index++)if(!arguments.get(index).known()||arguments.get(index).family()==Family.NULL){
                budget.check();final int position=index;var categories=new HashSet<String>();for(var candidate:candidates)categories.add(category(parameter(inputs.get(candidate),index)));
                String chosen=categories.contains("string")?"string":categories.size()==1?categories.iterator().next():null;
                if(chosen==null)continue;
                candidates.removeIf(s->!category(parameter(inputs.get(s),position)).equals(chosen));
                if(candidates.stream().anyMatch(s->preferred(parameter(inputs.get(s),position))))candidates.removeIf(s->!preferred(parameter(inputs.get(s),position)));
            }
            if(candidates.size()>1){
                var known=arguments.stream().filter(t->t.known()&&t.family()!=Family.NULL).map(SqlTypes::base).toList();
                if(!known.isEmpty()&&known.stream().allMatch(t->SqlTypes.sameNative(t,known.getFirst(),engine))){
                    var assumed=new ArrayList<Signature>();for(var candidate:candidates){budget.check();boolean accepts=true;for(int i=0;i<arguments.size();i++){budget.check();if((!arguments.get(i).known()||arguments.get(i).family()==Family.NULL)&&!SqlTypes.implicitlyCoercible(known.getFirst(),parameter(inputs.get(candidate),i),engine)){accepts=false;break;}}if(accepts)assumed.add(candidate);}
                    if(assumed.size()==1)candidates=assumed;
                }
            }
        }
        // A non-variadic overload with the same effective argument types wins
        // over an expanded variadic declaration. Different return types never
        // serve as an arbitrary tie-break.
        if(candidates.size()>1){var fixed=candidates.stream().filter(s->s.parameters().stream().noneMatch(Parameter::variadic)).toList();if(fixed.size()==1){Signature chosen=fixed.getFirst();boolean identical=true;for(var other:candidates)for(int i=0;i<arguments.size();i++){budget.check();if(!SqlTypes.sameNative(parameter(inputs.get(chosen),i),parameter(inputs.get(other),i),engine)){identical=false;break;}}if(identical)candidates=new ArrayList<>(fixed);}}
        return new Selection(candidates,true);
    }
    public static Type parameter(Signature signature,int argument){
        return parameter(signature.parameters().stream().filter(p->!Set.of("OUT","TABLE","RETURN").contains(p.mode())).toList(),argument);
    }
    private static Type parameter(List<Parameter> inputs,int argument){if(inputs.isEmpty()||argument>=inputs.size()&&!inputs.getLast().variadic())return null;var parameter=inputs.get(Math.min(argument,inputs.size()-1));Type type=parameter.type();return parameter.variadic()&&type.family()==Family.ARRAY&&type.element()!=null?type.element():type;}
    private static int score(List<Parameter> inputs,List<Type> arguments,Engine engine,boolean preference,AnalysisBudget budget){
        int score=0;for(int i=0;i<arguments.size();i++){
            budget.check();Type source=SqlTypes.base(arguments.get(i)),target=parameter(inputs,i);if(!source.known()||source.family()==Family.NULL||target==null)continue;
            if(preference){if(!SqlTypes.sameNative(source,target,engine)&&category(source).equals(category(target))&&preferred(target))score++;}
            else if(SqlTypes.sameNative(source,target,engine))score++;
        }return score;
    }
    private static ArrayList<Signature> best(List<Signature> candidates,ToIntFunction<Signature> score){int maximum=candidates.stream().mapToInt(score).max().orElse(0);return new ArrayList<>(candidates.stream().filter(s->score.applyAsInt(s)==maximum).toList());}
    private static String category(Type value){if(value==null)return "unknown";value=SqlTypes.base(value);return value.numeric()?"numeric":switch(value.family()){case TEXT->"string";case DATE,TIME,TIMESTAMP->"datetime";case ENUM->"enum:"+value.nativeName();case USER,DOMAIN->"user:"+value.nativeName();default->value.family().name();};}
    private static boolean preferred(Type type){if(type==null)return false;String name=type.nativeName().toLowerCase(Locale.ROOT);return type.family()==Family.TEXT&&name.equals("text")||type.family()==Family.REAL&&(name.equals("double precision")||name.equals("float8"))||type.family()==Family.TIMESTAMP&&type.timezone()||type.family()==Family.INTERVAL||type.family()==Family.BOOLEAN;}
}
