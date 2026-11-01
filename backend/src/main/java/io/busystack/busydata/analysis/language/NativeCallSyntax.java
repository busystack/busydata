package io.busystack.busydata.analysis.language;

import io.busystack.busydata.analysis.SqlLexicalCharacters;
import io.busystack.busydata.protocol.Engine;
import java.util.*;

/** Native lexical call facts, separate from metadata/name/signature resolution.
 * The sets contain only the language service's finite builtin catalog names
 * classified by pinned MySQL8.4.10/MariaDB11.8.9 lexical sources and
 * verified against same-name stored functions on both pinned servers.
 * Quoted aggregate/window keywords differ from generic native names.
 * Neither this check nor any semantic reader performs JDBC work. */
public final class NativeCallSyntax {
    private static final Set<String> MYSQL_SPECIAL=Set.of("count","min","max","sum");
    private static final Set<String> MARIA_SPECIAL=Set.of("count","min","max","sum","rank","dense_rank");
    private static final Set<String> MYSQL_QUOTED_STORED=Set.of("avg","coalesce","row_number","rank","dense_rank");
    private static final Set<String> MARIA_QUOTED_STORED=Set.of("avg","row_number");
    private NativeCallSyntax(){}
    public static boolean nativeEligible(Dialect dialect,SyntaxTree.Name name,String source,int openParen){
        if(dialect.postgres())return true;
        if(name.parts().size()!=1)return false;
        var token=name.last();String key=token.identifier().toLowerCase(Locale.ROOT);var special=dialect.engine()==Engine.MYSQL?MYSQL_SPECIAL:MARIA_SPECIAL;
        var quotedStored=dialect.engine()==Engine.MYSQL?MYSQL_QUOTED_STORED:MARIA_QUOTED_STORED;
        if(token.quoted())return !special.contains(key)&&!quotedStored.contains(key);
        if(!special.contains(key))return true;
        if(openParen<token.end()||openParen>=source.length()||source.charAt(openParen)!='(')throw new IllegalArgumentException("Invalid native call span");
        if(openParen==token.end())return true;
        if(!dialect.lexical().ignoreSpace())return false;
        // A comment is not skipped by the native name/parenthesis lookahead,
        // even when IGNORE_SPACE permits ordinary whitespace here.
        for(int index=token.end();index<openParen;index++)if(!SqlLexicalCharacters.isSpace(source.charAt(index)))return false;
        return true;
    }
}
