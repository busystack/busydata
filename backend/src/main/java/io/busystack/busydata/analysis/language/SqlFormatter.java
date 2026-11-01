package io.busystack.busydata.analysis.language;

import io.busystack.busydata.protocol.FormatSettings;
import io.busystack.busydata.protocol.FormatToken;
import java.util.*;
import io.busystack.busydata.analysis.language.LosslessLexer.*;

/** Token-preserving formatting. A failed proof returns unavailable, never edited SQL. */
public final class SqlFormatter {
    public record Options(String keywordCase,int indentation,int continuation,boolean clauseBreaks,String joinLayout,String commaPlacement,String logicalPlacement,boolean wrapLists,boolean wrapArguments,boolean indentSubqueries,boolean cteBreaks,boolean parenthesisSpacing,boolean operatorSpacing,boolean alignment,int maximumLine,boolean preserveBlankLines) {
        public static final Options DEFAULT=new Options("preserve",4,4,true,"new-line","trailing","same-line",false,false,true,true,false,true,false,100,true);
        public Options {
            if(!Set.of("preserve","upper","lower").contains(keywordCase)||indentation<1||indentation>16||continuation<0||continuation>32||maximumLine<20||maximumLine>1000||!Set.of("new-line","same-line").contains(joinLayout)||!Set.of("leading","trailing").contains(commaPlacement)||!Set.of("leading","trailing","same-line").contains(logicalPlacement))throw new IllegalArgumentException("Invalid SQL formatting options");
        }
        public static Options from(FormatSettings settings){return new Options(settings.getKeywordCase().isEmpty()?"preserve":settings.getKeywordCase(),settings.getIndentationWidth()==0?4:settings.getIndentationWidth(),settings.getContinuationIndent(),settings.getClauseLineBreaks(),settings.getJoinLayout().isEmpty()?"new-line":settings.getJoinLayout(),settings.getCommaPlacement().isEmpty()?"trailing":settings.getCommaPlacement(),settings.getLogicalOperatorPlacement().isEmpty()?"same-line":settings.getLogicalOperatorPlacement(),settings.getWrapLists(),settings.getWrapArguments(),settings.getIndentSubqueries(),settings.getCteLineBreaks(),settings.getParenthesisSpacing(),settings.getOperatorSpacing(),settings.getAlignment(),settings.getMaxLineLength()==0?100:settings.getMaxLineLength(),settings.getPreserveBlankLines());}
    }
    public record Result(String sql,List<FormatToken> tokens,String availability) {public Result {tokens=List.copyOf(tokens);}public boolean available(){return availability.equals("available");}}
    private static final Set<String> BREAKS=Set.of("FROM","WHERE","GROUP","HAVING","WINDOW","ORDER","LIMIT","OFFSET","FETCH","RETURNING","UNION","INTERSECT","EXCEPT","SET","VALUES");
    private static final Set<String> SAFE_KEYWORDS=Set.of("SELECT","FROM","WHERE","AS","WITH","RECURSIVE","JOIN","LEFT","RIGHT","FULL","INNER","OUTER","CROSS","NATURAL","ON","USING","GROUP","ORDER","BY","HAVING","WINDOW","OVER","PARTITION","ROWS","RANGE","BETWEEN","UNBOUNDED","PRECEDING","FOLLOWING","CURRENT","ROW","FILTER","LIMIT","OFFSET","FETCH","FIRST","NEXT","ONLY","UNION","EXCEPT","INTERSECT","ALL","DISTINCT","RETURNING","INSERT","UPDATE","DELETE","INTO","SET","VALUES","DEFAULT","NULL","TRUE","FALSE","AND","OR","NOT","IS","IN","EXISTS","LIKE","ILIKE","CASE","WHEN","THEN","ELSE","END","ASC","DESC","NULLS","LAST","CAST","CONFLICT","DO","NOTHING","DUPLICATE","KEY","CREATE","ALTER","DROP","RENAME","TRUNCATE","COMMENT","TABLE","VIEW","INDEX","SCHEMA","DATABASE","SEQUENCE","FUNCTION","PROCEDURE","TRIGGER","CONSTRAINT","TEMP","TEMPORARY","REPLACE","CASCADE","RESTRICT","ADD","COLUMN","TO");
    private SqlFormatter(){}
    public static Result format(String source,Dialect dialect,Options options,int start,int end,AnalysisBudget budget){
        if(start<0||end<start||end>source.length())throw new IllegalArgumentException("Invalid format selection");
        var full=LosslessLexer.scan(source,dialect,budget);
        // A selection must contain whole lexical tokens; never split literal/comment contents.
        for(var token:full.tokens())if(token.start()<start&&token.end()>start||token.start()<end&&token.end()>end)return new Result("",List.of(),"selection-splits-token");
        boolean initiallyDisabled=false,canEnable=false;
        for(var token:full.tokens()){
            budget.check();int directive=formatDirective(token);
            if(token.end()<=start){if(directive<0)initiallyDisabled=true;else if(directive>0)initiallyDisabled=false;}
            else if(token.start()>=start&&token.end()<=end&&directive>0)canEnable=true;
            if(token.start()>=end)break;
        }
        // An inherited disabled range is already a proven no-op, including
        // incomplete SQL. Do not require its intentionally untouched syntax to parse.
        if(initiallyDisabled&&!canEnable){
            var mappings=new ArrayList<FormatToken>();
            for(var token:full.tokens()){
                budget.check();if(token.kind()!=Kind.WHITESPACE)mappings.add(FormatToken.newBuilder().setSourceStartUtf16(token.start()).setSourceEndUtf16(token.end()).setFormattedStartUtf16(token.start()).build());
            }
            return new Result(source,mappings,"available");
        }
        String selected=source.substring(start,end);var document=LosslessLexer.scan(selected,dialect,budget);
        if(document.tokens().stream().anyMatch(t->!t.complete()||t.kind()==Kind.ERROR))return new Result("",List.of(),"incomplete-syntax");
        int balance=0;for(var token:document.significant()){if(token.is("("))balance++;if(token.is(")")&&--balance<0)return new Result("",List.of(),"incomplete-syntax");}if(balance!=0)return new Result("",List.of(),"incomplete-syntax");
        var tokens=document.tokens().stream().filter(t->t.kind()!=Kind.WHITESPACE).toList();String newline=source.contains("\r\n")?"\r\n":"\n";
        var originalGaps=new HashSet<Integer>();
        for(int i=0;i<tokens.size();i++){
            var token=tokens.get(i);int prior=i-1;
            if(token.kind()==Kind.STRING){
                if(prior>=0&&tokens.get(prior).kind()==Kind.WORD&&Set.of("E","B","X","N").contains(tokens.get(prior).text().toUpperCase(Locale.ROOT))&&tokens.get(prior).end()==token.start())prior--;
                while(prior>=0&&tokens.get(prior).kind()==Kind.COMMENT)prior--;
                if(prior>=0&&tokens.get(prior).kind()==Kind.STRING)for(int gap=prior+1;gap<=i;gap++)originalGaps.add(gap);
            }
            if(token.is("(")&&!dialect.postgres()){
                prior=i-1;while(prior>=0&&tokens.get(prior).kind()==Kind.COMMENT)prior--;
                if(prior>=0&&tokens.get(prior).name())for(int gap=prior+1;gap<=i;gap++)originalGaps.add(gap);
            }
        }
        var output=new StringBuilder(selected.length()+128);Token previous=null;int depth=0;boolean disabled=initiallyDisabled;int disabledFrom=disabled?0:-1;int lineLength=0;boolean cteList=false;
        var protectedNames=new HashSet<Integer>();var syntax=SyntaxParser.parse(document,budget);
        if(syntax.issues().stream().anyMatch(issue->issue.source().equals("parser")&&issue.severity().equals("error")))return new Result("",List.of(),"incomplete-syntax");
        if(syntax.queries().stream().anyMatch(SyntaxTree.Query::opaque))return new Result("",List.of(),"opaque-region");
        for(var query:syntax.queries()){for(var relation:query.relations()){if(relation.name()!=null)for(var part:relation.name().parts())protectedNames.add(part.start());if(relation.alias()!=null)protectedNames.add(relation.alias().start());}for(var cte:query.ctes())protectedNames.add(cte.name().start());}
        // The tolerant DDL tree does not yet assign keyword/name roles inside
        // every native declaration. A nonreserved word can be a case-sensitive
        // MySQL table/database name, so preserve case beyond the proven command.
        for(var query:syntax.queries())if(Set.of("CREATE","ALTER","DROP","RENAME","TRUNCATE","COMMENT").contains(query.kind()))for(var token:document.significant())if(token.start()>query.start()&&token.end()<=query.end()&&token.name())protectedNames.add(token.start());
        for(int tokenIndex=0;tokenIndex<tokens.size();tokenIndex++){
            var token=tokens.get(tokenIndex);
            budget.check();int directive=formatDirective(token);boolean off=directive<0,on=directive>0;
            if(disabled){if(on){output.append(selected,disabledFrom,token.end());disabled=false;previous=token;lineLength=lastLine(output);}continue;}
            String gap=previous==null?selected.substring(0,token.start()):selected.substring(previous.end(),token.start());
            String word=token.kind()==Kind.WORD?token.text().toUpperCase(Locale.ROOT):"";
            boolean comment=token.kind()==Kind.COMMENT,priorLineComment=previous!=null&&previous.kind()==Kind.COMMENT&&(previous.text().startsWith("--")||previous.text().startsWith("#"));
            boolean clause=options.clauseBreaks()&&BREAKS.contains(word);
            boolean join=options.joinLayout().equals("new-line")&&(word.equals("JOIN")&&(previous==null||!Set.of("LEFT","RIGHT","INNER","OUTER","CROSS","FULL","NATURAL").contains(previous.text().toUpperCase(Locale.ROOT)))||Set.of("LEFT","RIGHT","INNER","CROSS","FULL","NATURAL").contains(word)&&tokenIndex+1<tokens.size()&&(tokens.get(tokenIndex+1).is("JOIN")||tokens.get(tokenIndex+1).is("OUTER")));
            boolean cteMain=cteList&&depth==0&&Set.of("SELECT","INSERT","UPDATE","DELETE").contains(word);
            boolean cteBreak=options.cteBreaks()&&depth==0&&cteList&&(cteMain||previous!=null&&previous.is(","));
            if(word.equals("WITH")&&depth==0)cteList=true;if(cteMain)cteList=false;
            if(token.is(")"))depth=Math.max(0,depth-1);
            int indent=options.indentSubqueries()?depth*options.indentation():0;
            boolean listBreak=previous!=null&&previous.is(",")&&(depth==0?options.wrapLists():options.wrapArguments())&&options.commaPlacement().equals("trailing");
            boolean leadingComma=token.is(",")&&options.commaPlacement().equals("leading")&&(depth==0?options.wrapLists():options.wrapArguments());
            boolean logical=Set.of("AND","OR").contains(word)&&options.logicalPlacement().equals("leading")||previous!=null&&Set.of("AND","OR").contains(previous.text().toUpperCase(Locale.ROOT))&&options.logicalPlacement().equals("trailing");
            boolean wrap=previous!=null&&lineLength+gap.length()+token.text().length()>options.maximumLine()&&(previous.is(",")||Set.of("AND","OR").contains(word));
            boolean newlineGap=gap.contains("\n")||gap.contains("\r");
            if(previous==null){output.append(gap);}
            else if(originalGaps.contains(tokenIndex)){output.append(gap);}
            else if(priorLineComment||previous.is(";")||clause||join||cteBreak||listBreak||leadingComma||logical||wrap||comment&&newlineGap){
                if(output.length()>0&&!endsNewline(output))output.append(newline);
                if(options.preserveBlankLines()&&countLines(gap)>1)output.append(newline);
                output.append(" ".repeat(Math.min(1024,indent+(listBreak||wrap?options.continuation():0))));
            }else if(previous.kind()==Kind.COMMENT&&newlineGap){output.append(newline).append(" ".repeat(indent));}
            else if(token.is("(")&&previous.name()){
                // MySQL builtin recognition depends on adjacency unless IGNORE_SPACE is active.
                output.append(gap);
            }else if(token.kind()==Kind.STRING&&previous.kind()==Kind.WORD&&gap.isEmpty()){}
            else if(token.is(".")||previous.is(".")||token.is("::")||previous.is("::")||token.is(",")||token.is(";")||token.is("]")||previous.is("[")){}
            else if(token.is(")")||previous.is("(")){if(options.parenthesisSpacing()&&!previous.is("("))output.append(' ');else if(options.parenthesisSpacing()&&!token.is(")"))output.append(' ');}
            else if(token.kind()==Kind.OPERATOR||previous.kind()==Kind.OPERATOR){if(options.operatorSpacing()&&!token.is("*")&&!previous.is("*"))output.append(' ');else output.append(gap.isEmpty()?"":" ");}
            else if(!gap.isEmpty()||previous.is(",")||previous.name()&&token.name())output.append(' ');
            String text=token.text();if(token.kind()==Kind.WORD&&SAFE_KEYWORDS.contains(word)&&!protectedNames.contains(token.start())&&!options.keywordCase().equals("preserve"))text=options.keywordCase().equals("upper")?word:word.toLowerCase(Locale.ROOT);
            output.append(text);if(token.is("("))depth++;previous=token;lineLength=lastLine(output);
            if(off){disabled=true;disabledFrom=token.end();}
        }
        if(disabled)output.append(selected,disabledFrom,selected.length());
        else if(previous!=null){String trailing=selected.substring(previous.end());if(trailing.endsWith("\r\n")||trailing.endsWith("\n"))output.append(newline);else output.append(trailing);}
        else output.append(selected);
        // Every transformation, including the syntax-based alignment pass, owns
        // only this range. Reattach the untouched prefix/suffix after all edits.
        String formattedSelection=output.toString();
        if(options.alignment())formattedSelection=alignAssignments(formattedSelection,dialect,budget,initiallyDisabled);
        String formatted=source.substring(0,start)+formattedSelection+source.substring(end);
        var checked=LosslessLexer.scan(formatted,dialect,budget);
        var before=full.tokens().stream().filter(t->t.kind()!=Kind.WHITESPACE).toList();var after=checked.tokens().stream().filter(t->t.kind()!=Kind.WHITESPACE).toList();
        if(before.size()!=after.size())return new Result("",List.of(),"token-proof-failed");var mappings=new ArrayList<FormatToken>();
        for(int i=0;i<before.size();i++){
            var a=before.get(i);var b=after.get(i);boolean safeCase=a.kind()==Kind.WORD&&SAFE_KEYWORDS.contains(a.text().toUpperCase(Locale.ROOT))&&a.text().equalsIgnoreCase(b.text());
            if(a.kind()!=b.kind()||!a.text().equals(b.text())&&!safeCase)return new Result("",List.of(),"token-proof-failed");
            mappings.add(FormatToken.newBuilder().setSourceStartUtf16(a.start()).setSourceEndUtf16(a.end()).setFormattedStartUtf16(b.start()).build());
        }
        return new Result(formatted,mappings,"available");
    }
    private static int countLines(String text){int count=0;for(int i=0;i<text.length();i++)if(text.charAt(i)=='\n')count++;return count;}
    private static boolean endsNewline(StringBuilder text){return text.length()>0&&(text.charAt(text.length()-1)=='\n'||text.charAt(text.length()-1)=='\r');}
    private static int lastLine(StringBuilder text){int i=text.length()-1;while(i>=0&&text.charAt(i)!='\n'&&text.charAt(i)!='\r')i--;return text.length()-i-1;}
    private static int formatDirective(Token token){
        if(token.kind()!=Kind.COMMENT)return 0;
        return switch(token.text().strip().toLowerCase(Locale.ROOT)){case "-- busydata-format:off"->-1;case "-- busydata-format:on"->1;default->0;};
    }
    private static boolean overlapsDisabled(List<int[]> ranges,int start,int end){
        int low=0,high=ranges.size();
        while(low<high){int middle=(low+high)>>>1;if(ranges.get(middle)[1]<=start)low=middle+1;else high=middle;}
        return low<ranges.size()&&ranges.get(low)[0]<end;
    }
    private static String alignAssignments(String source,Dialect dialect,AnalysisBudget budget,boolean initiallyDisabled){
        var document=LosslessLexer.scan(source,dialect,budget);var syntax=SyntaxParser.parse(document,budget);var insertions=new TreeMap<Integer,Integer>();
        var disabledRanges=new ArrayList<int[]>();int disabledFrom=initiallyDisabled?0:-1;
        for(var token:document.tokens()){
            budget.check();int directive=formatDirective(token);
            if(directive<0&&disabledFrom<0)disabledFrom=token.start();
            else if(directive>0&&disabledFrom>=0){disabledRanges.add(new int[]{disabledFrom,token.end()});disabledFrom=-1;}
        }
        if(disabledFrom>=0)disabledRanges.add(new int[]{disabledFrom,source.length()});
        for(var query:syntax.queries())for(var clause:query.clauses())if(clause.name().equals("SET")){
            budget.check();if(overlapsDisabled(disabledRanges,clause.start(),clause.end()))continue;
            var equals=new ArrayList<Token>();for(var element:clause.elements())if(element instanceof SyntaxTree.Leaf leaf&&leaf.token().is("="))equals.add(leaf.token());
            if(equals.size()<2)continue;int maximum=0;var positions=new HashMap<Integer,Integer>();var lines=new HashSet<Integer>();boolean distinct=true;
            for(var token:equals){int lineStart=source.lastIndexOf('\n',token.start()-1)+1;if(!lines.add(lineStart)){distinct=false;break;}int position=token.start()-lineStart;positions.put(token.start(),position);maximum=Math.max(maximum,position);}
            if(distinct)for(var token:equals){int spaces=maximum-positions.get(token.start());if(spaces>0&&spaces<=128)insertions.put(token.start(),spaces);}
        }
        if(insertions.isEmpty())return source;var out=new StringBuilder(source.length()+insertions.size()*8);int previous=0;for(var insertion:insertions.entrySet()){out.append(source,previous,insertion.getKey()).append(" ".repeat(insertion.getValue()));previous=insertion.getKey();}return out.append(source,previous,source.length()).toString();
    }
}
