package io.busystack.busydata.analysis.language;

import io.busystack.busydata.analysis.LexicalSettings;
import io.busystack.busydata.protocol.*;
import java.util.*;
import io.busystack.busydata.analysis.language.LosslessLexer.Token;

/** One source snapshot. Parsing, binding and each editor service have separate owners. */
public final class SemanticDocument {
    public record TableReference(String catalog,String schema,String table){}
    public record SymbolReference(TableReference table,int start,int end,SyntaxTree.Name name){public SymbolReference(TableReference table,int start,int end){this(table,start,end,null);}}
    public static final class AmbiguousReference extends IllegalArgumentException {public AmbiguousReference(){super("Ambiguous table alias");}}
    private final SyntaxTree tree;private final AnalysisBudget budget;private final Dialect dialect;
    public SemanticDocument(String sql,Engine engine){this(sql,engine,LexicalSettings.DEFAULT);}
    public SemanticDocument(String sql,Engine engine,LexicalSettings settings){this(sql,engine,settings,AnalysisBudget.interactive());}
    public SemanticDocument(String sql,Engine engine,LexicalSettings settings,AnalysisBudget budget){this.budget=budget;this.dialect=new Dialect(engine,settings);tree=SyntaxParser.parse(LosslessLexer.scan(sql,dialect,budget),budget);}
    public SyntaxTree syntax(){return tree;}
    public SemanticBinder bind(ResolutionContext context){return new SemanticBinder(tree,new SemanticCatalog(dialect,context,budget),budget);}
    public List<Completion> complete(int caret,ResolutionContext context){return new CompletionService(bind(context),budget).complete(caret);}
    public CompletionService.Batch completeBatch(int caret,ResolutionContext context,Map<String,String> snippets){return new CompletionService(bind(context),budget).completeBatch(caret,snippets);}
    public List<TableReference> references(){
        var binder=bind(ResolutionContext.UNAVAILABLE);var out=new LinkedHashSet<TableReference>();
        for(var query:tree.queries())for(var relation:query.relations())if(validReference(relation.name())&&(relation.name().parts().size()>1||binder.findCte(query,dialect.identifier(relation.name().last()))==null))out.add(reference(relation.name().parts()));
        return out.stream().limit(33).toList();
    }
    public SymbolReference referenceAt(int caret){return referenceAt(caret,ResolutionContext.UNAVAILABLE);}
    public SymbolReference referenceAt(int caret,ResolutionContext context){
        if(caret<0||caret>tree.document().source().length())throw new IllegalArgumentException("Invalid symbol caret");if(tree.document().protectedAt(caret)!=null)return null;
        var binder=bind(context);
        for(var query:tree.queries())for(var relation:query.relations())if(validReference(relation.name())){
            if(relation.name().parts().size()==1&&binder.findCte(query,dialect.identifier(relation.name().last()))!=null)continue;
            var names=new ArrayList<>(relation.name().parts());if(relation.alias()!=null)names.add(relation.alias());for(var name:names)if(caret>=name.start()&&caret<=name.end())return new SymbolReference(reference(relation.name().parts()),name.start(),name.end(),relation.name());
        }
        var query=tree.at(caret);if(query==null)return null;
        var tokens=tree.document().significant();for(int i=0;i+1<tokens.size();i++){
            var token=tokens.get(i);if(!token.name()||caret<token.start()||caret>token.end()||!tokens.get(i+1).is(".")||!unqualifiedAliasPrefix(tokens,i))continue;
            var relations=binder.visible(query).stream().filter(r->r.syntax().visibleName()!=null&&binder.aliasKey(r.syntax().visibleName()).equals(binder.aliasKey(token))).toList();if(relations.size()>1)throw new AmbiguousReference();
            if(relations.size()==1){var relation=relations.getFirst().syntax();if(!validReference(relation.name())||relation.name().parts().size()==1&&binder.findCte(query,dialect.identifier(relation.name().last()))!=null)return null;return new SymbolReference(reference(relation.name().parts()),token.start(),token.end(),relation.name());}
        }return null;
    }
    private boolean validReference(SyntaxTree.Name name){
        if(!dialect.supportsObjectName(name))return false;
        var tokens=tree.document().significant();int low=0,high=tokens.size();
        while(low<high){int middle=(low+high)>>>1;if(tokens.get(middle).start()<name.end())low=middle+1;else high=middle;}
        return low==tokens.size()||!tokens.get(low).is(".");
    }
    private boolean unqualifiedAliasPrefix(List<Token> tokens,int index){
        if(index>0&&tokens.get(index-1).is("."))return false;
        int after=index+1,parts=1;
        while(after+1<tokens.size()&&tokens.get(after).is(".")&&tokens.get(after+1).name()){parts++;after+=2;}
        return parts<=2&&!(after+1<tokens.size()&&tokens.get(after).is("."));
    }
    private TableReference reference(List<Token> parts){
        if(parts.isEmpty()||parts.size()>dialect.maximumObjectNameParts())throw new IllegalArgumentException("Unsupported object qualification");
        return switch(parts.size()){
            case 1->new TableReference("","",dialect.identifier(parts.getFirst()));
            case 2->new TableReference("",dialect.identifier(parts.getFirst()),dialect.identifier(parts.get(1)));
            case 3->new TableReference(dialect.identifier(parts.getFirst()),dialect.identifier(parts.get(1)),dialect.identifier(parts.get(2)));
            default->throw new IllegalArgumentException("Unsupported object qualification");
        };
    }
}
