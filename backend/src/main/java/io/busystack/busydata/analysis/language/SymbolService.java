package io.busystack.busydata.analysis.language;

import io.busystack.busydata.analysis.LexicalSettings;
import io.busystack.busydata.analysis.SqlAnalysis;
import io.busystack.busydata.protocol.*;
import java.util.Set;
import java.util.function.BooleanSupplier;

/** Bounded navigation over one captured context and immutable metadata snapshot.
 * This service owns no session, JDBC connection, refresh or editor state. */
public final class SymbolService {
    private SymbolService(){}

    public static ResolvedSymbol resolve(AnalysisRequest request,String profileId,LexicalSettings settings,
            ResolutionContext context,BooleanSupplier cancelled) {
        var out=ResolvedSymbol.newBuilder();
        if(request.getCaretUtf16()<0||request.getCaretUtf16()>request.getSql().length())throw new IllegalArgumentException("Invalid UTF-16 symbol caret");
        if(context.snapshot()==null)return out.setAvailability("session-required").build();
        var budget=new AnalysisBudget(750,cancelled);
        try {
            if(request.getSql().length()>AnalysisBudget.MAX_DOCUMENT_UNITS)throw new AnalysisBudget.Limit("SQL symbol document exceeds its budget");
            budget.check();
            // Execution keeps its independent, safety-validated splitter. The
            // tolerant editor parser resolves only the selected original span.
            var statements=new SqlAnalysis().split(request.getSql(),request.getEngine(),settings);
            budget.check();
            var active=statements.stream().filter(fragment->request.getCaretUtf16()>=fragment.start()&&request.getCaretUtf16()<=fragment.end()).findFirst().orElse(null);
            if(active==null)return out.setComplete(true).setAvailability("not-an-object-reference").build();
            var dialect=new Dialect(request.getEngine(),settings);
            var reference=new SemanticDocument(active.text(),request.getEngine(),settings,budget).referenceAt(request.getCaretUtf16()-active.start(),context);
            budget.check();
            if(reference==null){boolean available=context.rules(dialect).complete()&&context.snapshot().identifierRulesAvailable();return out.setComplete(available).setAvailability(available?"not-an-object-reference":"incomplete-metadata").build();}
            out.setSpan(Span.newBuilder().setStartUtf16(reference.start()+active.start()).setEndUtf16(reference.end()+active.start()));
            var name=reference.name();
            if(name.parts().size()==1)for(var prior:statements){
                if(prior.start()>=active.start())break;
                var tokens=LosslessLexer.scan(prior.text(),dialect,budget).significant();
                if(!tokens.isEmpty()&&Set.of("SET","USE","RESET","DISCARD","CALL","DO","EXECUTE").stream().anyMatch(tokens.getFirst()::is))return out.setAvailability("ambiguous").build();
            }
            var rules=context.rules(dialect);
            if(!dialect.supportsObjectName(name)||name.parts().size()>2&&(!dialect.postgres()||!rules.lookup(ObjectKind.CATALOG,name.parts().getFirst().identifier(),name.parts().getFirst().quoted()).equals(rules.lookup(ObjectKind.CATALOG,context.catalog(),true))))return out.setAvailability("unsupported-qualification").build();
            out.setProfileId(profileId).setCatalog(context.catalog());
            if(!dialect.postgres())out.setSchema(context.catalog());
            var catalog=new SemanticCatalog(dialect,context,budget);
            var matches=catalog.resolveSymbols(name);
            budget.check();
            if(matches.limited())return out.setAvailability("limited").build();
            if(!matches.objects().isEmpty()){
                for(var object:matches.objects())out.addCandidates(object.toBuilder().clearProperties().clearDefinition());
                if(matches.objects().size()==1){var object=matches.objects().getFirst();out.setCatalog(object.getCatalog()).setSchema(object.getSchema());}
                if(!matches.complete())return out.setComplete(false).setAvailability("incomplete-metadata").build();
                return out.setComplete(matches.caseChoice()?matches.complete():true).setAvailability(matches.caseChoice()?"choose-native-case":matches.objects().size()==1?"exact":"ambiguous").build();
            }
            return out.setComplete(matches.complete()).setAvailability(matches.complete()?"not-found":"incomplete-metadata").build();
        }catch(SemanticDocument.AmbiguousReference ambiguous){return out.setAvailability("ambiguous").build();}
        catch(AnalysisBudget.Limit limited){return out.clearCandidates().setComplete(false).setAvailability("limited").build();}
    }
}
