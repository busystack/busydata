package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.sessions.SessionRegistry;
import java.nio.file.Path;
import java.util.UUID;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

class CurrentStatementIT {
    @TempDir Path root;

    @org.junit.jupiter.api.Test
    void fullCapturedDocumentsRemainChargedWhileOnlyTheSelectionIsHistory() throws Exception {
        try (var fixture = new EngineFixture(root, "POSTGRESQL")) {
            var session = fixture.open();
            String sql = "SELECT 1; --" + "x".repeat(4_000_000);
            var queued = new java.util.ArrayList<io.busystack.busydata.jobs.Jobs.Job>();
            session.lock.lock();
            try {
                for (int i = 0; i < 4; i++) {
                    var request = ExecuteRequest.newBuilder().setSessionId(session.id)
                        .setExecutionId(UUID.randomUUID().toString()).setSql(sql).setCaretUtf16(9)
                        .setMode(ExecutionMode.CURRENT_STATEMENT).setRowLimit(100).build();
                    queued.add(fixture.jobs.execute(session, request.toBuilder()
                        .setApprovalToken(fixture.safety.review(request, session).getToken()).build()));
                }
                var rejected = ExecuteRequest.newBuilder().setSessionId(session.id)
                    .setExecutionId(UUID.randomUUID().toString()).setSql(sql).setCaretUtf16(9)
                    .setMode(ExecutionMode.CURRENT_STATEMENT).setRowLimit(100).build();
                var approved = rejected.toBuilder().setApprovalToken(fixture.safety.review(rejected, session).getToken()).build();
                assertThrows(IllegalStateException.class, () -> fixture.jobs.execute(session, approved),
                    "A tiny history fragment must not hide the full queued document's bytes");
                for (var job : queued) fixture.jobs.cancel(job.id);
                for (var job : queued) {
                    var outcome = job.finished.get(2, TimeUnit.SECONDS);
                    assertEquals(JobState.CANCELLED, outcome.getState());
                    assertEquals(0, outcome.getResultsCount(), "Cancelled queued SQL must never execute");
                }
            } finally {
                for (var job : queued) if (!io.busystack.busydata.jobs.Jobs.terminal(job.state)) fixture.jobs.cancel(job.id);
                session.lock.unlock();
            }
            fixture.execute(session, "SELECT 9");
        }
    }

    private static JobInfo current(EngineFixture fixture, SessionRegistry.Session session,
                                  String sql, int caret) throws Exception {
        var request = ExecuteRequest.newBuilder().setSessionId(session.id)
            .setExecutionId(UUID.randomUUID().toString()).setSql(sql).setCaretUtf16(caret)
            .setMode(ExecutionMode.CURRENT_STATEMENT).setRowLimit(100).build();
        var review = fixture.safety.review(request, session);
        assertEquals(1, review.getStatementsCount(), "Review must describe exactly the execution");
        var outcome = fixture.jobs.execute(session, request.toBuilder().setApprovalToken(review.getToken()).build())
            .finished.get(30, TimeUnit.SECONDS);
        assertEquals(JobState.COMPLETED, outcome.getState(), outcome.getErrorCode());
        return outcome;
    }

    @ParameterizedTest @ValueSource(strings = {"POSTGRESQL", "MYSQL", "MARIADB"})
    void naturalEndCaretAndReviewExecuteOnlyTheIntendedStatement(String engine) throws Exception {
        try (var fixture = new EngineFixture(root, engine)) {
            var session = fixture.open();
            fixture.execute(session, "CREATE TABLE bd_current(id INTEGER PRIMARY KEY,n VARCHAR(100));"
                + "INSERT INTO bd_current VALUES(1,'漢😀');");
            String sql = "SELECT 'first😀' AS n; SELECT 'second漢' AS n;\r\n";
            var first = current(fixture, session, sql, sql.indexOf(';') + 1);
            assertEquals("first😀", fixture.results.get(first.getResults(0).getResultId()).read(0).getValues(0).getText());
            var second = current(fixture, session, sql, sql.length());
            assertEquals("second漢", fixture.results.get(second.getResults(0).getResultId()).read(0).getValues(0).getText());
            var readOnly = fixture.sessions.open(OpenRequest.newBuilder()
                .setProfile(fixture.profile.toBuilder().setReadOnly(true)).setPassword("fixture").build());
            fixture.metadata.history(HistoryRequest.newBuilder().setAction(HistoryAction.SET_PRIVACY)
                .setRetainSql(true).setRetentionDays(30).build());
            String guarded = "SELECT id,n FROM bd_current ORDER BY id; DELETE FROM bd_current;";
            var selected = current(fixture, readOnly, guarded, guarded.indexOf(';') + 1);
            assertEquals("漢😀", fixture.results.get(selected.getResults(0).getResultId()).read(0).getValues(1).getText());
            var history = fixture.metadata.history(HistoryRequest.getDefaultInstance()).getEntriesList().stream()
                .filter(entry -> entry.getId().equals(selected.getJobId())).findFirst().orElseThrow();
            assertEquals("SELECT id,n FROM bd_current ORDER BY id", history.getSql(),
                "History must not retain an unsubmitted statement or its secrets");
            try (var statement = session.connection.createStatement();
                 var rows = statement.executeQuery("SELECT id,n FROM bd_current")) {
                assertTrue(rows.next()); assertEquals(1, rows.getInt(1)); assertEquals("漢😀", rows.getString(2));
                assertFalse(rows.next(), "The unselected DELETE must never execute");
            }
        }
    }

    @ParameterizedTest @ValueSource(strings = {"POSTGRESQL", "MYSQL", "MARIADB"})
    void lostReadResponseDoesNotBecomeAnUnknownWriteBecauseOfUnselectedSql(String engine) throws Exception {
        var armed = new java.util.concurrent.atomic.AtomicBoolean();
        var submissions = new java.util.concurrent.atomic.AtomicInteger();
        try (var fixture = new EngineFixture(root, engine, (adapter, request, port) -> {
            var physical = adapter.connect(request, port);
            var connection = adapter.engine() == Engine.POSTGRESQL
                ? NativePostgresFaults.wrap(physical, new NativePostgresFaults.Observer() {
                    @Override public void acknowledged(String sql) throws java.sql.SQLException {
                        if (armed.get() && sql.equals("SELECT id FROM bd_current")) {
                            submissions.incrementAndGet();
                            throw new java.sql.SQLException("Injected lost read response", "08006");
                        }
                    }
                }) : physical;
            return (java.sql.Connection) java.lang.reflect.Proxy.newProxyInstance(getClass().getClassLoader(),
                new Class[]{java.sql.Connection.class}, (proxy, method, args) -> {
                    Object value = TransactionFaultIT.Faults.invoke(connection, method, args);
                    if (value instanceof java.sql.Statement statement)
                        return java.lang.reflect.Proxy.newProxyInstance(getClass().getClassLoader(),
                            new Class[]{value instanceof java.sql.PreparedStatement
                                ? java.sql.PreparedStatement.class : java.sql.Statement.class}, (st, call, parameters) -> {
                                Object result = TransactionFaultIT.Faults.invoke(statement, call, parameters);
                                if (armed.get() && call.getName().equals("execute") && parameters != null
                                    && parameters.length > 0 && parameters[0].toString().equals("SELECT id FROM bd_current"))
                                {
                                    submissions.incrementAndGet();
                                    throw new java.sql.SQLException("Injected lost read response", "08006");
                                }
                                return result;
                            });
                    return value;
                });
        })) {
            var session = fixture.open();
            fixture.execute(session, "CREATE TABLE bd_current(id INTEGER PRIMARY KEY); INSERT INTO bd_current VALUES(1)");
            String sql = "SELECT id FROM bd_current; DELETE FROM bd_current;";
            var request = ExecuteRequest.newBuilder().setSessionId(session.id).setExecutionId(UUID.randomUUID().toString())
                .setSql(sql).setCaretUtf16(sql.indexOf(';') + 1).setMode(ExecutionMode.CURRENT_STATEMENT).setRowLimit(100).build();
            var approval = fixture.safety.review(request, session);
            armed.set(true);
            var outcome = fixture.jobs.execute(session, request.toBuilder().setApprovalToken(approval.getToken()).build())
                .finished.get(30, TimeUnit.SECONDS);
            assertEquals(JobState.INTERRUPTED, outcome.getState(), "Only the selected read was submitted");
            assertEquals(1, submissions.get(), "Lost responses must never cause SQL replay");
            assertEquals(TransactionState.UNKNOWN_TRANSACTION, session.state);
            armed.set(false);
            var observer = fixture.open();
            try (var statement = observer.connection.createStatement(); var rows = statement.executeQuery("SELECT id FROM bd_current")) {
                assertTrue(rows.next()); assertEquals(1, rows.getInt(1)); assertFalse(rows.next());
            }
        }
    }
}
