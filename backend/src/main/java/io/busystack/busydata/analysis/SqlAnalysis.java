package io.busystack.busydata.analysis;

import io.busystack.busydata.protocol.*;
import java.util.*;
import java.util.regex.*;
import net.sf.jsqlparser.parser.CCJSqlParserUtil;

/** Offsets are Java/Dart UTF-16 code units in the original, unnormalised text. */
public final class SqlAnalysis {
    public record Fragment(int start,int end,String text,int nextOffset,String delimiter) {
        public Fragment(int start,int end,String text){this(start,end,text,end,";");}
        public Fragment shifted(int offset){return new Fragment(start+offset,end+offset,text,nextOffset+offset,delimiter);}
    }
    /** Leading token only, for cancellation around transaction boundaries; this
     * is not a statement authorization or dialect-validity classification. */
    public String leadingKeyword(String sql) {
        int index=0;
        while(index<sql.length()){
            if(SqlLexicalCharacters.isSpace(sql.charAt(index))){index++;continue;}
            if(sql.startsWith("--",index)){while(index<sql.length()&&sql.charAt(index)!='\n'&&sql.charAt(index)!='\r')index++;continue;}
            if(sql.startsWith("/*",index)){
                index+=2;int depth=1;
                while(index<sql.length()&&depth>0){if(sql.startsWith("/*",index)){depth++;index+=2;}else if(sql.startsWith("*/",index)){depth--;index+=2;}else index++;}
                continue;
            }
            break;
        }
        int start=index;while(index<sql.length()&&SqlLexicalCharacters.identifierPart(sql.codePointAt(index),Engine.POSTGRESQL))index+=Character.charCount(sql.codePointAt(index));
        return sql.substring(start,index).toUpperCase(Locale.ROOT);
    }
    public List<Fragment> split(String sql, Engine engine) {
        return split(sql,engine,LexicalSettings.DEFAULT);
    }
    /** The review and executor must select the same original SQL. Fragment.end
     * excludes a client delimiter; nextOffset includes it. A caret immediately
     * after a terminator (or its following whitespace) still selects that
     * statement, unless it is already inside the next statement. */
    public List<Fragment> execution(ExecuteRequest request,Engine engine,LexicalSettings settings) {
        if(request.getMode()==ExecutionMode.UNRECOGNIZED)throw new IllegalArgumentException("Unknown execution mode");
        String sql=request.getSql();
        int caret=request.getCaretUtf16();
        if(request.getMode()==ExecutionMode.CURRENT_STATEMENT&&(caret<0||caret>sql.length()))throw new IllegalArgumentException("Invalid UTF-16 caret");
        var fragments=split(sql,engine,settings);
        if(request.getMode()!=ExecutionMode.CURRENT_STATEMENT) {
            if(fragments.isEmpty())throw new IllegalArgumentException("No executable statement");
            return fragments;
        }
        var active=currentFragment(fragments,sql,caret);if(active!=null)return List.of(active);
        throw new IllegalArgumentException("No SQL statement at this position; move the caret into a statement or select SQL explicitly");
    }
    /** Shared selection only: neither formatting nor execution selection calls the editor parser. */
    private static Fragment currentFragment(List<Fragment> fragments,String sql,int caret) {
        for(var fragment:fragments)if(caret>=fragment.start()&&caret<=fragment.end())return fragment;
        for(var fragment:fragments) {
            int boundary=fragment.nextOffset();
            while(boundary<sql.length()&&SqlLexicalCharacters.isSpace(sql.charAt(boundary)))boundary++;
            if(caret>fragment.end()&&caret<=boundary)return fragment;
        }
        return null;
    }
    public List<Fragment> split(String sql,Engine engine,LexicalSettings settings){return split(sql,engine,settings,";");}
    public List<Fragment> split(String sql,Engine engine,LexicalSettings settings,String initialDelimiter) {
        if (sql.length() > 8_000_000) throw new IllegalArgumentException("Document exceeds 8M UTF-16 units");
        var out = new ArrayList<Fragment>();
        int start = 0, block = 0; char quote = 0; boolean line = false, escapeQuote = false; String dollar = null, delimiter = initialDelimiter;
        boolean create=false,routine=false;String previousWord="";var compound=new ArrayDeque<String>();
        for (int i = 0; i < sql.length(); i++) {
            char c = sql.charAt(i), n = i+1 < sql.length() ? sql.charAt(i+1) : 0;
            if (line) { if (c == '\n' || c == '\r') line = false; continue; }
            if (block > 0) {
                if (c == '/' && n == '*' && engine==Engine.POSTGRESQL) { block++; i++; }
                else if (c == '*' && n == '/') { block--; i++; }
                continue;
            }
            if (dollar != null) { if (sql.startsWith(dollar,i)) { i += dollar.length()-1; dollar=null; } continue; }
            if (quote != 0) {
                if (c == quote) { if (n == quote) i++; else quote=0; }
                else if (c == '\\' && escapeQuote) i++;
                continue;
            }
            if ((i == 0 || sql.charAt(i-1) == '\n') && engine != Engine.POSTGRESQL) {
                var m = Pattern.compile("(?i)[ \\t]*DELIMITER[ \\t]+(\\S+)[ \\t]*(?:\\r?\\n|$)").matcher(sql);
                m.region(i,sql.length());
                if (m.lookingAt()) {
                    if (!sql.substring(start,i).isBlank()) throw new IllegalArgumentException("DELIMITER must start between statements");
                    delimiter=m.group(1); if (delimiter.length()>16) throw new IllegalArgumentException("Delimiter too long");
                    i=m.end()-1; start=m.end(); continue;
                }
            }
            if (c == '-' && n == '-' && (engine == Engine.POSTGRESQL || i+2 == sql.length() || SqlLexicalCharacters.mysqlCommentFollower(sql.codePointAt(i+2)))) { line=true;i++;continue; }
            if (c == '#' && engine != Engine.POSTGRESQL) {line=true;continue;}
            if (c == '/' && n == '*') {block=1;i++;continue;}
            if (c == '\'' || c == '"' || (c == '`' && engine != Engine.POSTGRESQL)) {quote=c;boolean string=c=='\''||c=='"'&&engine!=Engine.POSTGRESQL&&!settings.ansiQuotes();escapeQuote=string&&(engine!=Engine.POSTGRESQL?!settings.noBackslashEscapes():!settings.standardConformingStrings()||i>0&&(sql.charAt(i-1)=='E'||sql.charAt(i-1)=='e')&&(i<2||!SqlLexicalCharacters.identifierPart(sql.codePointBefore(i-1),engine)));continue;}
            if(c=='$'&&engine==Engine.POSTGRESQL&&(i==0||!SqlLexicalCharacters.identifierPart(sql.codePointBefore(i),engine))){
                String tag=dollarDelimiter(sql,i);if(tag!=null){dollar=tag;i+=tag.length()-1;continue;}
            }
            // A reviewed client DELIMITER is authoritative even for procedural
            // syntax the tolerant compound tracker does not recognize. Check
            // before scanning identifier words, including alphabetic markers.
            if (sql.startsWith(delimiter,i)&&(!delimiter.equals(";")||compound.isEmpty())) { add(out,sql,start,i,i+delimiter.length(),delimiter);i+=delimiter.length()-1;start=i+1;create=false;routine=false;previousWord="";compound.clear();continue; }
            if(SqlLexicalCharacters.identifierStart(sql.codePointAt(i),engine)&&(i==0||!SqlLexicalCharacters.identifierPart(sql.codePointBefore(i),engine))) {
                int end=i+Character.charCount(sql.codePointAt(i));while(end<sql.length()&&SqlLexicalCharacters.identifierPart(sql.codePointAt(end),engine)&&!sql.startsWith(delimiter,end))end+=Character.charCount(sql.codePointAt(end));
                String word=sql.substring(i,end).toUpperCase(Locale.ROOT);
                if(word.equals("CREATE"))create=true;
                if(create&&Set.of("FUNCTION","PROCEDURE","TRIGGER").contains(word))routine=true;
                if(routine) {
                    if(word.equals("END")){if(!compound.isEmpty())compound.pop();}
                    else if(!previousWord.equals("END")&&(word.equals("BEGIN")||word.equals("CASE")||word.equals("LOOP")||word.equals("REPEAT")||word.equals("WHILE")||word.equals("IF")&&controlThen(sql,end,settings))){if(compound.size()>=64)throw new IllegalArgumentException("Procedural nesting exceeds 64 levels");compound.push(word);}
                }
                previousWord=word;i=end-1;continue;
            }

        }
        add(out,sql,start,sql.length(),sql.length(),delimiter); return List.copyOf(out);
    }
    private static String dollarDelimiter(String sql,int start){
        int end=start+1;if(end<sql.length()&&sql.charAt(end)=='$')return "$$";
        if(end>=sql.length()||!SqlLexicalCharacters.identifierStart(sql.codePointAt(end),Engine.POSTGRESQL))return null;
        do{end+=Character.charCount(sql.codePointAt(end));}while(end<sql.length()&&SqlLexicalCharacters.dollarTagPart(sql.codePointAt(end)));
        return end<sql.length()&&sql.charAt(end)=='$'?sql.substring(start,end+1):null;
    }
    private static boolean controlThen(String sql,int offset,LexicalSettings settings) {
        // IF(expr,...) is a function; procedural IF has THEN before its body terminator.
        var tokens=SqlLexer.scan(sql.substring(offset,Math.min(sql.length(),offset+65536)),Engine.MYSQL,settings);
        int depth=0;
        for(var token:tokens){if(token.text().equals("("))depth++;else if(token.text().equals(")"))depth--;else if(depth<=0&&(token.text().equals(";")||token.is("END")))return false;else if(depth==0&&token.is("THEN"))return true;}
        return false;
    }
    private static void add(List<Fragment> out,String sql,int start,int end,int nextOffset,String delimiter) {
        while (start<end && SqlLexicalCharacters.isSpace(sql.charAt(start))) start++;
        while (end>start && SqlLexicalCharacters.isSpace(sql.charAt(end-1))) end--;
        if(start<end && !sql.substring(start,end).replaceAll("(?s)/\\*.*?\\*/|(?m)--[^\\r\\n]*|(?m)#[^\\r\\n]*", "").isBlank()) {if(out.size()>=1000)throw new IllegalArgumentException("Script exceeds 1000 statements");out.add(new Fragment(start,end,sql.substring(start,end),nextOffset,delimiter));}
    }
    public boolean readOnly(String sql) {
        if(sql.length()>262144)return false; // Unknown classification requires review; raw SQL remains executable.
        try {
            var statement=SqlParsing.parse(sql,Engine.POSTGRESQL);
            // A conservative review classification, never an authorization boundary.
            if (!(statement instanceof net.sf.jsqlparser.statement.select.Select)) return false;
            String clean=sql.toUpperCase(Locale.ROOT);
            return !Pattern.compile("\\b(INTO|FOR\\s+UPDATE|FOR\\s+SHARE|INSERT|UPDATE|DELETE|CALL|SET_CONFIG|NEXTVAL|PG_.*|LOAD_FILE|SLEEP|GET_LOCK)\\b").matcher(clean).find();
        } catch(Exception ignored) { return false; }
    }
    public Analysis analyze(AnalysisRequest request){return analyze(request,LexicalSettings.DEFAULT,io.busystack.busydata.analysis.language.ResolutionContext.UNAVAILABLE);}
    public Analysis analyze(AnalysisRequest request,LexicalSettings settings,io.busystack.busydata.analysis.language.ResolutionContext context){return analyze(request,settings,context,()->io.grpc.Context.current().isCancelled());}
    public Analysis analyze(AnalysisRequest request,LexicalSettings settings,io.busystack.busydata.analysis.language.ResolutionContext context,java.util.function.BooleanSupplier cancelled){
        if(request.getCaretUtf16()<0||request.getCaretUtf16()>request.getSql().length())throw new IllegalArgumentException("Invalid UTF-16 caret");
        if(request.getOperation()==AnalysisOperation.UNRECOGNIZED)throw new IllegalArgumentException("Unknown SQL analysis operation");
        io.busystack.busydata.analysis.language.SnippetCatalog.validate(request.getSnippetsMap());
        if(request.getFormatCurrentStatement()&&request.getOperation()!=AnalysisOperation.FORMAT)throw new IllegalArgumentException("Current-statement formatting requires the formatting operation");
        if(request.getMetadataSnapshotRevision()!=0&&request.getMetadataSnapshotRevision()!=context.metadataRevision()||request.getMetadataConfigurationRevision()!=0&&request.getMetadataConfigurationRevision()!=context.configurationRevision())throw new IllegalStateException("SQL metadata revision changed");
        var result=Analysis.newBuilder().setDocumentId(request.getDocumentId()).setDocumentVersion(request.getDocumentVersion())
            .setBackendInstance(request.getContext().getInstanceId()).setSessionId(request.getSessionId())
            .setContextRevision(request.getContextRevision()).setSessionRevision(request.getSessionRevision()).setCaretUtf16(request.getCaretUtf16())
            .setOperation(request.getOperation()).setMetadataSnapshotRevision(context.metadataRevision()).setMetadataConfigurationRevision(context.configurationRevision())
            .setMetadataSourceIdentity(context.snapshot()==null?"":context.snapshot().source())
            .setAvailability(context.complete()?"available":"incomplete-metadata");
        var budget=new io.busystack.busydata.analysis.language.AnalysisBudget(request.getOperation()==AnalysisOperation.FORMAT?1500:750,cancelled);
        var dialect=new io.busystack.busydata.analysis.language.Dialect(request.getEngine(),settings);
        try {
            switch(request.getOperation()) {
                case FORMAT -> {
                    var options=request.hasFormatSettings()?io.busystack.busydata.analysis.language.SqlFormatter.Options.from(request.getFormatSettings()):io.busystack.busydata.analysis.language.SqlFormatter.Options.DEFAULT;
                    int start=request.hasFormatSettings()?request.getFormatSettings().getStartUtf16():0,end=request.hasFormatSettings()?request.getFormatSettings().getEndUtf16():0;
                    if(end==0)end=request.getSql().length();
                    if(request.getFormatCurrentStatement()){
                        if(request.getSql().length()>io.busystack.busydata.analysis.language.AnalysisBudget.MAX_DOCUMENT_UNITS)throw new io.busystack.busydata.analysis.language.AnalysisBudget.Limit("Formatting document exceeds its budget");
                        budget.check();var active=currentFragment(split(request.getSql(),request.getEngine(),settings),request.getSql(),request.getCaretUtf16());budget.check();
                        if(active==null){result.setAvailability("no-active-statement");break;}
                        start=active.start();end=active.end();
                    }
                    var formatted=io.busystack.busydata.analysis.language.SqlFormatter.format(request.getSql(),dialect,options,start,end,budget);
                    result.setAvailability(formatted.availability());if(formatted.available())result.setFormattedSql(formatted.sql()).addAllFormatTokens(formatted.tokens());
                }
                case PARAMETER_INFORMATION -> {
                    var document=io.busystack.busydata.analysis.language.LosslessLexer.scan(request.getSql(),dialect,budget);
                    var catalog=new io.busystack.busydata.analysis.language.SemanticCatalog(dialect,context,budget);
                    var information=io.busystack.busydata.analysis.language.ParameterService.information(document,catalog,request.getCaretUtf16(),budget);
                    result.setParameterInformation(information);if(information.getAvailability().equals("limited")&&context.complete())result.setAvailability("limited");
                }
                case DDL_IMPACT -> result.addAllDdlEffects(io.busystack.busydata.analysis.language.DdlImpact.analyze(io.busystack.busydata.analysis.language.LosslessLexer.scan(request.getSql(),dialect,budget),context));
                case COMPLETION -> {
                    var document=new io.busystack.busydata.analysis.language.SemanticDocument(request.getSql(),request.getEngine(),settings,budget);
                    var batch=document.completeBatch(request.getCaretUtf16(),context,request.getSnippetsMap());
                    result.addAllCompletions(batch.items()).setCompletionLimited(batch.limited());
                    var active=document.syntax().at(request.getCaretUtf16());
                    if(active!=null&&active.opaque())result.setAvailability("unsupported");
                    else if(batch.metadataIncomplete())result.setAvailability("incomplete-metadata");
                    else if(batch.limited()&&context.complete())result.setAvailability("limited");
                }
                case DIAGNOSTICS -> {
                    var document=new io.busystack.busydata.analysis.language.SemanticDocument(request.getSql(),request.getEngine(),settings,budget);
                    var binding=document.bind(context);var issues=binding.diagnostics();
                    for(var query:document.syntax().queries())if(query.parent()==null)result.addStatements(Span.newBuilder().setStartUtf16(query.start()).setEndUtf16(query.end()).setSupported(!query.opaque()&&issues.stream().noneMatch(issue->issue.source().equals("parser")&&issue.start()>=query.start()&&issue.start()<query.end())));
                    var inspectionSettings=new HashMap<String,InspectionSetting>();
                    for(var setting:request.getInspectionsList()){
                        if(setting.getCode().isEmpty()||!Set.of("error","warning","hint","information","").contains(setting.getSeverity()))throw new IllegalArgumentException("Invalid SQL inspection setting");
                        if(inspectionSettings.put(setting.getCode(),setting)!=null)throw new IllegalArgumentException("Duplicate SQL inspection setting");
                    }
                    for(var issue:issues){
                        var setting=inspectionSettings.get(issue.code());if(setting!=null&&!setting.getEnabled())continue;
                        var diagnostic=Diagnostic.newBuilder().setCode(issue.code()).setSource(issue.source()).setSeverity(setting!=null&&!setting.getSeverity().isEmpty()?setting.getSeverity():issue.severity()).setStartUtf16(issue.start()).setEndUtf16(issue.end()).setMessage(issue.message()).setIncomplete(issue.incomplete()).setEngine(request.getEngine());
                        if(issue.code().equals("binding.ambiguous-column")){
                            var query=document.syntax().at(issue.start());
                            var token=document.syntax().document().significant().stream().filter(t->t.start()==issue.start()).findFirst().orElse(null);
                            if(query!=null&&token!=null)for(var column:binding.columns(query,null,token))if(!column.qualifier().isEmpty())diagnostic.addFixes(QuickFix.newBuilder().setLabel(dialect.insertion(column.qualifier())+"."+dialect.insertion(column.name())).setStartUtf16(issue.start()).setEndUtf16(issue.end()).setReplacement(dialect.insertion(column.qualifier())+"."+dialect.insertion(column.name())));
                        }
                        result.addDiagnostics(diagnostic);
                    }
                }
                case SYMBOL_RESOLUTION -> throw new IllegalArgumentException("Symbol resolution requires the captured workbench metadata owner");
                default -> throw new IllegalArgumentException("Unknown SQL analysis operation");
            }
            budget.check();
        } catch(io.busystack.busydata.analysis.language.AnalysisBudget.Limit limit) {
            result.clearCompletions().clearCompletionLimited().clearFormattedSql().clearFormatTokens().clearParameterInformation().clearDdlEffects().clearDiagnostics().clearStatements()
                .setAvailability("limited").addDiagnostics(Diagnostic.newBuilder().setCode("analysis.limit").setSource("availability").setSeverity("hint").setMessage(limit.diagnosticMessage()).setIncomplete(true).setEngine(request.getEngine()));
            if(request.getOperation()==AnalysisOperation.DIAGNOSTICS)result.addStatements(Span.newBuilder().setEndUtf16(request.getSql().length()).setSupported(false));
        }
        return result.build();
    }
}
