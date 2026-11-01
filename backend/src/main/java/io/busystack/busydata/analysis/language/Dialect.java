package io.busystack.busydata.analysis.language;

import io.busystack.busydata.analysis.LexicalSettings;
import io.busystack.busydata.protocol.Engine;
import java.util.*;

/** Pinned engine grammar capabilities, independent of the execution splitter. */
public record Dialect(Engine engine,LexicalSettings lexical) {
    public static final Set<String> KEYWORDS=Set.of("SELECT","FROM","WHERE","AS","WITH","RECURSIVE","JOIN","LEFT","RIGHT","FULL","INNER","OUTER","CROSS","NATURAL","ON","USING","GROUP","ORDER","BY","HAVING","WINDOW","OVER","PARTITION","ROWS","RANGE","GROUPS","BETWEEN","UNBOUNDED","PRECEDING","FOLLOWING","CURRENT","ROW","EXCLUDE","FILTER","WITHIN","LIMIT","OFFSET","FETCH","FIRST","NEXT","ONLY","TIES","UNION","EXCEPT","INTERSECT","ALL","DISTINCT","DISTINCTROW","RETURNING","INSERT","UPDATE","DELETE","INTO","SET","VALUES","VALUE","DEFAULT","NULL","TRUE","FALSE","AND","OR","NOT","IS","IN","EXISTS","LIKE","ILIKE","REGEXP","RLIKE","CASE","WHEN","THEN","ELSE","END","ASC","DESC","NULLS","LAST","CAST","COLLATE","LATERAL","MATERIALIZED","CONFLICT","DO","NOTHING","DUPLICATE","KEY","CREATE","ALTER","DROP","RENAME","TRUNCATE","COMMENT","TABLE","VIEW","INDEX","SCHEMA","DATABASE","SEQUENCE","FUNCTION","PROCEDURE","TRIGGER","CONSTRAINT","IF","TEMP","TEMPORARY","REPLACE","CASCADE","RESTRICT","ADD","COLUMN","TO","USE","RESET","DISCARD","CALL","BEGIN","COMMIT","ROLLBACK","TRANSACTION","FOR","SHARE","OF","NOWAIT","SKIP","LOCKED","RETURN","RETURNS","LANGUAGE","DECLARE","LOW_PRIORITY","HIGH_PRIORITY","IGNORE","SQL_CALC_FOUND_ROWS","SQL_NO_CACHE","SQL_CACHE","STRAIGHT_JOIN","FORCE","LOCK","MODE","EXTRACT","INTERVAL","AT","TIME","ZONE");
    public Dialect {if(engine!=Engine.POSTGRESQL&&engine!=Engine.MYSQL&&engine!=Engine.MARIADB)throw new IllegalArgumentException("Unsupported SQL dialect");Objects.requireNonNull(lexical);}
    public boolean postgres(){return engine==Engine.POSTGRESQL;}
    /** Table/routine/type object identities: PostgreSQL database.schema.object,
     * MySQL/MariaDB database.object. Columns add their own final component. */
    public int maximumObjectNameParts(){return postgres()?3:2;}
    public boolean supportsObjectName(SyntaxTree.Name name){return name!=null&&!name.parts().isEmpty()&&name.parts().size()<=maximumObjectNameParts();}
    public boolean returning(String statement){return postgres()||engine==Engine.MARIADB&&Set.of("INSERT","DELETE","REPLACE").contains(statement);}
    public boolean lateral(){return engine!=Engine.MARIADB;}
    public String identifier(LosslessLexer.Token token){return token.quoted()?token.identifier():postgres()?io.busystack.busydata.metadata.IdentifierRules.postgresUnquoted(token.text()):token.text();}
    public String aliasKey(LosslessLexer.Token token){return identifier(token);}
    public boolean columnMatches(String exact,LosslessLexer.Token token,io.busystack.busydata.metadata.IdentifierRules rules){return rules.matches(io.busystack.busydata.protocol.ObjectKind.COLUMN,exact,token.identifier(),token.quoted());}
    public String quote(String identifier){return new io.busystack.busydata.metadata.IdentifierRules(engine,0).quote(identifier);}
    public String insertion(String identifier){
        return identifier.matches("[a-z_][a-z0-9_$]*")&&!KEYWORDS.contains(identifier.toUpperCase(Locale.ROOT))?identifier:quote(identifier);
    }
    public List<String> types(){return postgres()?List.of("smallint","integer","bigint","numeric","real","double precision","boolean","text","varchar","bytea","date","time","timestamp","timestamptz","interval","uuid","json","jsonb"):List.of("tinyint","smallint","mediumint","int","bigint","decimal","float","double","boolean","char","varchar","text","binary","varbinary","blob","date","time","datetime","timestamp","json","enum","set");}
}
