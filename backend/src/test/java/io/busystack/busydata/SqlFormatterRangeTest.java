package io.busystack.busydata;

import io.busystack.busydata.analysis.LexicalSettings;
import io.busystack.busydata.analysis.SqlAnalysis;
import io.busystack.busydata.analysis.language.AnalysisBudget;
import io.busystack.busydata.analysis.language.Dialect;
import io.busystack.busydata.analysis.language.LosslessLexer;
import io.busystack.busydata.analysis.language.SqlFormatter;
import io.busystack.busydata.protocol.AnalysisOperation;
import io.busystack.busydata.protocol.AnalysisRequest;
import io.busystack.busydata.protocol.Engine;
import io.busystack.busydata.protocol.FormatSettings;
import io.busystack.busydata.protocol.FormatToken;
import java.util.List;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import static org.junit.jupiter.api.Assertions.*;

class SqlFormatterRangeTest {
    private static final SqlFormatter.Options ALIGNED = new SqlFormatter.Options(
        "preserve", 4, 4, true, "new-line", "trailing", "same-line",
        true, false, true, true, false, true, true, 100, true);
    private static final FormatSettings ALIGNED_SETTINGS = FormatSettings.newBuilder()
        .setKeywordCase("preserve").setIndentationWidth(4).setContinuationIndent(4)
        .setClauseLineBreaks(true).setJoinLayout("new-line").setCommaPlacement("trailing")
        .setLogicalOperatorPlacement("same-line").setWrapLists(true)
        .setIndentSubqueries(true).setCteLineBreaks(true).setOperatorSpacing(true)
        .setAlignment(true).setMaxLineLength(100).setPreserveBlankLines(true).build();

    @ParameterizedTest
    @EnumSource(value = Engine.class, names = {"POSTGRESQL", "MYSQL", "MARIADB"})
    void selectedSelectNeverAlignsMultilineUpdatesBeforeOrAfterItsRange(Engine engine) {
        for (String newline : List.of("\n", "\r\n")) {
            for (String finalNewline : List.of("", newline)) {
                String prefix = prefix(newline);
                String selected = select(engine);
                String suffix = suffix(newline, finalNewline);
                String source = prefix + selected + suffix;
                var formatted = format(source, engine, prefix.length(), prefix.length() + selected.length());

                assertEquals("available", formatted.availability());
                assertNotEquals(source, formatted.sql(), "The selected SELECT must actually be formatted");
                assertOutsideRange(prefix, suffix, formatted.sql());
                assertMappings(source, formatted.sql(), formatted.tokens(), engine, prefix.length(),
                    prefix.length() + selected.length());
                assertEquals(formatted.sql(), format(formatted.sql(), engine, prefix.length(),
                    formatted.sql().length() - suffix.length()).sql());
                assertLineEndingsAndFinalNewline(source, formatted.sql(), newline);
            }
        }
    }

    @ParameterizedTest
    @EnumSource(value = Engine.class, names = {"POSTGRESQL", "MYSQL", "MARIADB"})
    void selectedUpdateStillAlignsOnlyItsOwnAssignments(Engine engine) {
        for (String newline : List.of("\n", "\r\n")) {
            String prefix = prefix(newline);
            String selected = "UPDATE chosen SET a=1,long_name=2 WHERE id=3";
            String suffix = suffix(newline, newline);
            String source = prefix + selected + suffix;
            var formatted = format(source, engine, prefix.length(), prefix.length() + selected.length());

            assertEquals("available", formatted.availability());
            assertOutsideRange(prefix, suffix, formatted.sql());
            String changed = formatted.sql().substring(prefix.length(), formatted.sql().length() - suffix.length());
            String[] lines = changed.split("\\R");
            String first = List.of(lines).stream().filter(line -> line.startsWith("SET a")).findFirst().orElseThrow();
            String second = List.of(lines).stream().filter(line -> line.stripLeading().startsWith("long_name")).findFirst().orElseThrow();
            assertEquals(first.indexOf('='), second.indexOf('='), "Selected assignments should remain aligned");
            assertMappings(source, formatted.sql(), formatted.tokens(), engine, prefix.length(),
                prefix.length() + selected.length());
            assertEquals(formatted.sql(), format(formatted.sql(), engine, prefix.length(),
                formatted.sql().length() - suffix.length()).sql());
        }
    }

    @ParameterizedTest
    @EnumSource(value = Engine.class, names = {"POSTGRESQL", "MYSQL", "MARIADB"})
    void currentStatementUsesTheSameRangeBoundaryWithAssignmentAlignment(Engine engine) {
        for (String newline : List.of("\n", "\r\n")) {
            String prefix = prefix(newline);
            String selected = select(engine);
            String suffix = suffix(newline, newline);
            String source = prefix + selected + suffix;
            var request = AnalysisRequest.newBuilder().setEngine(engine).setOperation(AnalysisOperation.FORMAT)
                .setSql(source).setCaretUtf16(prefix.length() + 2).setFormatCurrentStatement(true)
                .setFormatSettings(ALIGNED_SETTINGS).build();
            var service = new SqlAnalysis();
            var formatted = service.analyze(request);

            assertEquals("available", formatted.getAvailability());
            assertNotEquals(source, formatted.getFormattedSql());
            assertOutsideRange(prefix, suffix, formatted.getFormattedSql());
            assertMappings(source, formatted.getFormattedSql(), formatted.getFormatTokensList(), engine,
                prefix.length(), prefix.length() + selected.length());
            assertEquals(formatted.getFormattedSql(), service.analyze(request.toBuilder()
                .setSql(formatted.getFormattedSql()).build()).getFormattedSql());
            assertLineEndingsAndFinalNewline(source, formatted.getFormattedSql(), newline);
        }
    }

    @ParameterizedTest
    @EnumSource(value = Engine.class, names = {"POSTGRESQL", "MYSQL", "MARIADB"})
    void malformedUnselectedStatementsAndQuotedContentsRemainExact(Engine engine) {
        String prefix = "-- 😀 malformed prefix remains owned by the editor\r\nUPDATE broken SET ;\r\n";
        String selected = select(engine);
        String suffix = ";\r\nUPDATE other SET ;\r\n-- 😀 suffix\r\n";
        String source = prefix + selected + suffix;
        var formatted = format(source, engine, prefix.length(), prefix.length() + selected.length());

        assertEquals("available", formatted.availability());
        assertOutsideRange(prefix, suffix, formatted.sql());
        assertTrue(formatted.sql().contains(quoted(engine)));
        assertTrue(formatted.sql().contains("'😀  literal; -- unchanged'"));
        assertMappings(source, formatted.sql(), formatted.tokens(), engine, prefix.length(),
            prefix.length() + selected.length());
    }

    @ParameterizedTest
    @EnumSource(value = Engine.class, names = {"POSTGRESQL", "MYSQL", "MARIADB"})
    void malformedSelectedRangeAndSplitTokensReturnNoEdit(Engine engine) {
        for (String selected : List.of("SELECT (1", "SELECT 'unfinished", "SELECT 1 +")) {
            String source = prefix("\n") + selected;
            var formatted = format(source, engine, source.length() - selected.length(), source.length());
            assertEquals("incomplete-syntax", formatted.availability());
            assertEquals("", formatted.sql());
            assertTrue(formatted.tokens().isEmpty());
        }
        String source = "SELECT '😀 untouched';";
        var split = format(source, engine, source.indexOf("untouched") + 1, source.length());
        assertEquals("selection-splits-token", split.availability());
        assertEquals("", split.sql());
        assertTrue(split.tokens().isEmpty());
    }

    @ParameterizedTest
    @EnumSource(value = Engine.class, names = {"POSTGRESQL", "MYSQL", "MARIADB"})
    void selectedDisabledRegionAndItsCommentsRemainExact(Engine engine) {
        String prefix = prefix("\r\n");
        String selected = "SELECT  1;\r\n-- busydata-format:off\r\n"
            + "UPDATE held SET a=1,\r\n    much_longer_name=2; -- 😀 preserve\r\n"
            + "-- busydata-format:on\r\nSELECT  2";
        String suffix = suffix("\r\n", "\r\n");
        String source = prefix + selected + suffix;
        var formatted = format(source, engine, prefix.length(), prefix.length() + selected.length());

        assertEquals("available", formatted.availability());
        assertOutsideRange(prefix, suffix, formatted.sql());
        String disabled = selected.substring(selected.indexOf("-- busydata-format:off"),
            selected.indexOf("-- busydata-format:on") + "-- busydata-format:on".length());
        assertTrue(formatted.sql().contains(disabled));
        assertMappings(source, formatted.sql(), formatted.tokens(), engine, prefix.length(),
            prefix.length() + selected.length());
        assertEquals(formatted.sql(), format(formatted.sql(), engine, prefix.length(),
            formatted.sql().length() - suffix.length()).sql());
    }

    @ParameterizedTest
    @EnumSource(value = Engine.class, names = {"POSTGRESQL", "MYSQL", "MARIADB"})
    void selectionsAtBeginningMiddleAndEndOfInheritedDisabledRegionAreExact(Engine engine) {
        for (String newline : List.of("\n", "\r\n")) {
            String opening = prefix(newline) + "-- busydata-format:off" + newline;
            var statements = List.of(select(engine),
                "UPDATE held SET a=1," + newline + "  much_longer_name=2 WHERE id=3",
                "SELECT    '-- busydata-format:on' FROM    held");
            String source = opening + String.join(";" + newline, statements)
                + ";" + newline + "-- busydata-format:on" + newline + "SELECT  outside;" + newline;
            for (String statement : statements) {
                int start = source.indexOf(statement), end = start + statement.length();
                var formatted = format(source, engine, start, end);
                assertEquals("available", formatted.availability());
                assertEquals(source, formatted.sql(), "A disabled selection must be a complete no-op");
                assertMappings(source, formatted.sql(), formatted.tokens(), engine, start, end);
                assertEquals(source, format(formatted.sql(), engine, start, end).sql());
            }
        }
    }

    @ParameterizedTest
    @EnumSource(value = Engine.class, names = {"POSTGRESQL", "MYSQL", "MARIADB"})
    void inheritedDisabledPrefixResumesOnlyAfterItsRealClosingComment(Engine engine) {
        for (String newline : List.of("\n", "\r\n")) {
            String prefix = prefix(newline) + "-- busydata-format:off" + newline;
            String held = "UPDATE held SET a='-- busydata-format:on'," + newline
                + "      much_longer_name=2 WHERE id=3;" + newline
                + "-- busydata-format:on" + newline;
            String selected = held + "UPDATE chosen SET a=1,long_name=2 WHERE id=3";
            String suffix = suffix(newline, newline), source = prefix + selected + suffix;
            var formatted = format(source, engine, prefix.length(), prefix.length() + selected.length());

            assertEquals("available", formatted.availability());
            assertOutsideRange(prefix, suffix, formatted.sql());
            assertEquals(held, formatted.sql().substring(prefix.length(), prefix.length() + held.length()));
            String enabled = formatted.sql().substring(prefix.length() + held.length(),
                formatted.sql().length() - suffix.length());
            assertNotEquals("UPDATE chosen SET a=1,long_name=2 WHERE id=3", enabled);
            assertAssignmentColumnsAligned(enabled);
            assertMappings(source, formatted.sql(), formatted.tokens(), engine, prefix.length(),
                prefix.length() + selected.length());
            assertEquals(formatted.sql(), format(formatted.sql(), engine, prefix.length(),
                formatted.sql().length() - suffix.length()).sql());
        }
    }

    @ParameterizedTest
    @EnumSource(value = Engine.class, names = {"POSTGRESQL", "MYSQL", "MARIADB"})
    void selectionEndingBeforeAnOutsideClosingDirectiveKeepsItsDisabledTailExact(Engine engine) {
        for (String newline : List.of("\n", "\r\n")) {
            String prefix = prefix(newline);
            String held = "-- busydata-format:off" + newline
                + "UPDATE held SET a=1," + newline + "      much_longer_name=2 WHERE id=3";
            String selected = "SELECT  id,name FROM orders WHERE id=1;" + newline + held;
            String suffix = ";" + newline + "-- busydata-format:on" + newline + "SELECT  outside;" + newline;
            String source = prefix + selected + suffix;
            var formatted = format(source, engine, prefix.length(), prefix.length() + selected.length());

            assertEquals("available", formatted.availability());
            assertOutsideRange(prefix, suffix, formatted.sql());
            assertNotEquals(source, formatted.sql(), "The preceding enabled SELECT must still format");
            assertTrue(formatted.sql().substring(0, formatted.sql().length() - suffix.length()).endsWith(held));
            assertMappings(source, formatted.sql(), formatted.tokens(), engine, prefix.length(),
                prefix.length() + selected.length());
            assertEquals(formatted.sql(), format(formatted.sql(), engine, prefix.length(),
                formatted.sql().length() - suffix.length()).sql());
        }
    }

    @ParameterizedTest
    @EnumSource(value = Engine.class, names = {"POSTGRESQL", "MYSQL", "MARIADB"})
    void currentStatementHonorsFormatterOffFromAnEarlierStatement(Engine engine) {
        for (String newline : List.of("\n", "\r\n")) {
            String prefix = prefix(newline) + "-- busydata-format:off" + newline
                + "SELECT    1;" + newline;
            String selected = select(engine);
            String suffix = ";" + newline + "-- busydata-format:on" + newline + "SELECT  outside;" + newline;
            String source = prefix + selected + suffix;
            var request = AnalysisRequest.newBuilder().setEngine(engine).setOperation(AnalysisOperation.FORMAT)
                .setSql(source).setCaretUtf16(prefix.length() + 2).setFormatCurrentStatement(true)
                .setFormatSettings(ALIGNED_SETTINGS).build();
            var formatted = new SqlAnalysis().analyze(request);

            assertEquals("available", formatted.getAvailability());
            assertEquals(source, formatted.getFormattedSql());
            assertMappings(source, formatted.getFormattedSql(), formatted.getFormatTokensList(), engine,
                prefix.length(), prefix.length() + selected.length());
        }
    }

    @ParameterizedTest
    @EnumSource(value = Engine.class, names = {"POSTGRESQL", "MYSQL", "MARIADB"})
    void closedPrefixAndLiteralIdentifierOrBlockCommentLookalikesDoNotDisableAlignment(Engine engine) {
        String markerIdentifier = engine == Engine.POSTGRESQL
            ? "\"-- busydata-format:off\"" : "`-- busydata-format:off`";
        String prefix = prefix("\r\n") + "-- busydata-format:off\r\nSELECT    1;\r\n"
            + "-- busydata-format:on\r\nSELECT '-- busydata-format:off', " + markerIdentifier
            + ";\r\n/* -- busydata-format:off */\r\n";
        String selected = "UPDATE chosen SET a='-- busydata-format:off',long_name=2 WHERE id=3";
        String suffix = suffix("\r\n", "\r\n"), source = prefix + selected + suffix;
        var formatted = format(source, engine, prefix.length(), prefix.length() + selected.length());

        assertEquals("available", formatted.availability());
        assertOutsideRange(prefix, suffix, formatted.sql());
        String changed = formatted.sql().substring(prefix.length(), formatted.sql().length() - suffix.length());
        assertAssignmentColumnsAligned(changed);
        assertTrue(changed.contains("'-- busydata-format:off'"));
        assertMappings(source, formatted.sql(), formatted.tokens(), engine, prefix.length(),
            prefix.length() + selected.length());
        assertEquals(formatted.sql(), format(formatted.sql(), engine, prefix.length(),
            formatted.sql().length() - suffix.length()).sql());
    }

    @ParameterizedTest
    @EnumSource(value = Engine.class, names = {"POSTGRESQL", "MYSQL", "MARIADB"})
    void inheritedDisabledMalformedSyntaxReturnsOnlyAnExactNoOp(Engine engine) {
        String prefix = prefix("\r\n") + "-- busydata-format:off\r\n";
        String selected = "UPDATE held SET a=(\r\n";
        String suffix = "-- busydata-format:on\r\nSELECT  outside;\r\n";
        String source = prefix + selected + suffix;
        var formatted = format(source, engine, prefix.length(), prefix.length() + selected.length());

        assertEquals("available", formatted.availability());
        assertEquals(source, formatted.sql());
        assertMappings(source, formatted.sql(), formatted.tokens(), engine, prefix.length(),
            prefix.length() + selected.length());
    }

    private static void assertAssignmentColumnsAligned(String formatted) {
        List<String> lines = formatted.lines().toList();
        String first = lines.stream().filter(line -> line.startsWith("SET a")).findFirst().orElseThrow();
        String second = lines.stream().filter(line -> line.stripLeading().startsWith("long_name")).findFirst().orElseThrow();
        assertEquals(first.indexOf('='), second.indexOf('='), "Enabled selected assignments should align");
    }

    private static SqlFormatter.Result format(String source, Engine engine, int start, int end) {
        return SqlFormatter.format(source, new Dialect(engine, LexicalSettings.DEFAULT), ALIGNED,
            start, end, AnalysisBudget.interactive());
    }

    private static String prefix(String newline) {
        return "-- 😀 keep prefix" + newline + "UPDATE before_table" + newline
            + "SET a = 1," + newline + "    much_longer_name = 2" + newline
            + "WHERE id = 3;" + newline + newline;
    }

    private static String suffix(String newline, String finalNewline) {
        return ";" + newline + newline + "UPDATE after_table" + newline
            + "SET tiny = 4," + newline + "    longer_column_name = 5" + newline
            + "WHERE id = 6;" + newline + "-- 😀 keep suffix" + finalNewline;
    }

    private static String quoted(Engine engine) {
        return engine == Engine.POSTGRESQL ? "\"Odd \"\" Name\"" : "`Odd `` Name`";
    }

    private static String select(Engine engine) {
        return "SELECT  " + quoted(engine) + ", '😀  literal; -- unchanged' FROM orders WHERE id=1";
    }

    private static void assertOutsideRange(String prefix, String suffix, String formatted) {
        assertEquals(prefix, formatted.substring(0, prefix.length()), "Unselected UTF-16 prefix changed");
        assertEquals(suffix, formatted.substring(formatted.length() - suffix.length()),
            "Unselected UTF-16 suffix changed");
    }

    private static void assertLineEndingsAndFinalNewline(String source, String formatted, String newline) {
        if (newline.equals("\r\n")) assertFalse(formatted.replace("\r\n", "").contains("\n"));
        else assertFalse(formatted.contains("\r"));
        assertEquals(source.endsWith(newline), formatted.endsWith(newline));
    }

    private static void assertMappings(String source, String formatted, List<FormatToken> mappings,
                                       Engine engine, int start, int end) {
        var dialect = new Dialect(engine, LexicalSettings.DEFAULT);
        var before = LosslessLexer.scan(source, dialect, AnalysisBudget.interactive()).tokens().stream()
            .filter(token -> token.kind() != LosslessLexer.Kind.WHITESPACE).toList();
        var after = LosslessLexer.scan(formatted, dialect, AnalysisBudget.interactive()).tokens().stream()
            .filter(token -> token.kind() != LosslessLexer.Kind.WHITESPACE).toList();
        assertEquals(before.size(), mappings.size());
        assertEquals(before.size(), after.size());
        int shift = formatted.length() - source.length();
        for (int i = 0; i < mappings.size(); i++) {
            var mapping = mappings.get(i);
            var original = before.get(i);
            var changed = after.get(i);
            assertEquals(original.kind(), changed.kind());
            assertEquals(original.text(), changed.text(), "Comments, literals and identifier contents must remain exact");
            assertEquals(original.start(), mapping.getSourceStartUtf16());
            assertEquals(original.end(), mapping.getSourceEndUtf16());
            assertEquals(changed.start(), mapping.getFormattedStartUtf16());
            assertEquals(original.text(), formatted.substring(mapping.getFormattedStartUtf16(),
                mapping.getFormattedStartUtf16() + original.text().length()));
            if (original.end() <= start) assertEquals(original.start(), changed.start());
            if (original.start() >= end) assertEquals(original.start() + shift, changed.start());
        }
    }
}
