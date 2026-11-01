package io.busystack.busydata.analysis.language;

import java.util.List;

/** Captured context only. No service reads mutable session state after admission. */
public record ResolutionContext(String catalog,String schema,List<String> searchPath,boolean complete,long metadataRevision,long configurationRevision,io.busystack.busydata.metadata.IdentifierRules identifierRules,io.busystack.busydata.metadata.MetadataSnapshot snapshot,String temporarySchema) {
    public static final ResolutionContext UNAVAILABLE=new ResolutionContext("","",List.of(),false,0,0);
    public ResolutionContext(String catalog,String schema,List<String> searchPath,boolean complete,long metadataRevision,long configurationRevision){this(catalog,schema,searchPath,complete,metadataRevision,configurationRevision,null,null,"");}
    public ResolutionContext(String catalog,String schema,List<String> searchPath,boolean complete,long metadataRevision,long configurationRevision,io.busystack.busydata.metadata.IdentifierRules rules){this(catalog,schema,searchPath,complete,metadataRevision,configurationRevision,rules,null,"");}
    public ResolutionContext(String catalog,String schema,List<String> searchPath,boolean complete,long metadataRevision,long configurationRevision,io.busystack.busydata.metadata.IdentifierRules rules,io.busystack.busydata.metadata.MetadataSnapshot snapshot){this(catalog,schema,searchPath,complete,metadataRevision,configurationRevision,rules,snapshot,"");}
    public ResolutionContext {searchPath=List.copyOf(searchPath);java.util.Objects.requireNonNull(temporarySchema);if(identifierRules!=null&&!identifierRules.complete()||snapshot!=null&&(!snapshot.identifierRulesAvailable()||snapshot.sessionResolution().state()!=io.busystack.busydata.metadata.MetadataState.AVAILABLE))complete=false;}
    public io.busystack.busydata.metadata.IdentifierRules rules(Dialect dialect){return identifierRules!=null?identifierRules:snapshot!=null?snapshot.rules():new io.busystack.busydata.metadata.IdentifierRules(dialect.engine(),0);}
}
