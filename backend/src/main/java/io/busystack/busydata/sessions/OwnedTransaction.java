package io.busystack.busydata.sessions;

import io.busystack.busydata.protocol.TransactionState;
import java.sql.SQLException;

/** One cleanup policy for BusyData-owned editing/import/read transactions.
 * try-with-resources preserves the primary exception and attaches cleanup errors.
 * Auto-commit is restored only after acknowledged commit or rollback. */
public final class OwnedTransaction implements AutoCloseable {
    @FunctionalInterface public interface CommitGuard {void run()throws Exception;}
    private final SessionRegistry.Session session;
    private boolean committed,closed;
    OwnedTransaction(SessionRegistry.Session session)throws SQLException {
        this.session=session;
        if(session.state!=TransactionState.IDLE||!session.connection.getAutoCommit())
            throw new IllegalStateException("Finish the console transaction before starting an operation-owned transaction");
        try{session.connection.setAutoCommit(false);session.autoCommit=false;session.state=TransactionState.ACTIVE;}
        catch(SQLException failure){session.failure(failure,false);throw failure;}
    }
    public void commit(CommitGuard beforeCommit,Runnable acknowledgement)throws Exception {
        beforeCommit.run();
        try{session.connection.commit();committed=true;acknowledgement.run();}
        catch(SQLException failure){session.failure(failure,false);throw failure;}
    }
    public void close()throws SQLException {
        if(closed)return;closed=true;
        if(session.state==TransactionState.UNKNOWN_TRANSACTION||session.state==TransactionState.DISCONNECTED)return;
        if(!committed){
            try{session.connection.rollback();}
            catch(SQLException failure){session.quarantine(failure);throw failure;}
        }
        // JDBC setAutoCommit(true) can commit a pending transaction. Reaching
        // this point requires a confirmed rollback or a confirmed commit.
        try{session.connection.setAutoCommit(true);session.autoCommit=true;session.refresh();}
        catch(SQLException failure){session.quarantine(failure);throw failure;}
    }
}
