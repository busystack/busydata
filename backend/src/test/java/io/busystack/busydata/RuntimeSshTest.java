package io.busystack.busydata;

import org.junit.jupiter.api.Test;

class RuntimeSshTest {
    @Test void packagingSmokeReviewsTheActualHostKeyAndForwardsThroughThePinnedSession()throws Exception {
        RuntimeCheck.verifySshRuntime();
    }
}
