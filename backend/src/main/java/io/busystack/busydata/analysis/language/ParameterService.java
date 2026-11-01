package io.busystack.busydata.analysis.language;

import io.busystack.busydata.protocol.*;
import java.util.*;
import io.busystack.busydata.analysis.language.LosslessLexer.*;

/** Call-local parameter service. Its work is independent from document diagnostics. */
public final class ParameterService {
    private record Call(Token name,int open,int end,int active){}
    private ParameterService(){}
    public static ParameterInformation information(LosslessLexer.Document document,SemanticCatalog catalog,int caret,AnalysisBudget budget){
        if(caret<0||caret>document.source().length())throw new IllegalArgumentException("Invalid parameter-information caret");
        var out=ParameterInformation.newBuilder().setAvailability(catalog.context().complete()?"available":"incomplete-metadata");
        if(document.protectedAt(caret)!=null&&document.protectedAt(caret).kind()==Kind.COMMENT)return out.setAvailability("not-a-call").build();
        var stack=new ArrayDeque<Call>();Token previous=null;Call active=null;
        for(var token:document.significant()){
            budget.check();if(token.start()>caret)break;
            if(token.is("(")){stack.push(new Call(previous!=null&&previous.name()?previous:null,token.start(),document.source().length(),0));}
            else if(token.is(")")&&!stack.isEmpty()){if(token.start()>=caret){active=stack.peek();break;}stack.pop();}
            else if(token.is(",")&&!stack.isEmpty()){var call=stack.pop();stack.push(new Call(call.name(),call.open(),call.end(),call.active()+1));}
            previous=token;
        }
        if(active==null)for(var call:stack)if(call.name()!=null){active=call;break;}
        if(active==null||active.name()==null)return out.setAvailability("not-a-call").build();
        var nameParts=new ArrayList<Token>();nameParts.add(active.name());var significant=document.significant();int nameAt=significant.indexOf(active.name());while(nameAt>=2&&significant.get(nameAt-1).is(".")&&significant.get(nameAt-2).name()){nameParts.addFirst(significant.get(nameAt-2));nameAt-=2;}
        var name=new io.busystack.busydata.analysis.language.SyntaxTree.Name(nameParts);
        boolean procedure=nameAt>0&&significant.get(nameAt-1).is("CALL");
        int end=active.end(),depth=0;for(var token:significant){if(token.start()<active.open())continue;if(token.is("("))depth++;else if(token.is(")")&&--depth==0){end=token.end();break;}}
        var signatures=catalog.callSignatures(name,procedure,NativeCallSyntax.nativeEligible(document.dialect(),name,document.source(),active.open()),arity(significant,active.open(),end,budget));
        out.setStartUtf16(nameParts.getFirst().start()).setEndUtf16(end).setActiveArgument(active.active());
        int bytes=0;boolean limited=false;for(var signature:signatures){budget.check();if(out.getOverloadsCount()>=64){limited=true;break;}var mapped=signature.protocol();if(bytes+mapped.getSerializedSize()>65536){limited=true;break;}bytes+=mapped.getSerializedSize();out.addOverloads(mapped);}
        return out.setAvailability(limited?"limited":signatures.isEmpty()?(catalog.context().complete()?"unavailable-signature":"incomplete-metadata"):signatures.stream().allMatch(RoutineSignatures.Signature::complete)?"available":"partial-signatures").build();
    }
    private static int arity(List<Token> tokens,int open,int end,AnalysisBudget budget){
        var nesting=new ArrayDeque<String>();int commas=0;boolean present=false;
        for(var token:tokens){budget.check();if(token.start()<=open)continue;if(token.start()>=end)break;if(token.is(")")&&nesting.isEmpty())break;present=true;
            if(token.is("(")||token.is("[")||token.is("{"))nesting.push(token.text());
            else if(token.is(")")||token.is("]")||token.is("}")){if(!nesting.isEmpty())nesting.pop();}
            else if(token.is(",")&&nesting.isEmpty())commas++;
        }
        return present?commas+1:0;
    }
}
