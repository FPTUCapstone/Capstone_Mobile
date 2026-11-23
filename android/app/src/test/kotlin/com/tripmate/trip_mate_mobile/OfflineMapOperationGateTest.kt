package com.tripmate.trip_mate_mobile

import org.junit.Assert.*
import org.junit.Test

class OfflineMapOperationGateTest {
    @Test fun cancelDuringPreflightCannotDeleteAnExistingRegion() {
        val gate = OfflineMapOperationGate()
        val job = gate.beginDownload("already-committed")!!
        assertTrue(gate.beginCleanup(job))
        assertFalse(gate.shouldRemoveRegion(job))
        assertFalse(gate.claimNewRegion(job))
        gate.finish(job)
        assertFalse(gate.isBusy())
    }

    @Test fun confirmedNewGenerationOwnsOnlyItsStagingRegion() {
        val gate = OfflineMapOperationGate()
        val job = gate.beginDownload("new-generation")!!
        assertTrue(gate.claimNewRegion(job))
        assertTrue(gate.beginCleanup(job))
        assertTrue(gate.shouldRemoveRegion(job))
        assertNull(gate.beginDownload("next-generation"))
        gate.finish(job)
        assertNotNull(gate.beginDownload("next-generation"))
    }

    @Test fun asynchronousLastRegionRemovalBlocksNewStyleDownload() {
        val gate = OfflineMapOperationGate()
        val removal = gate.beginRemoval("last-region")!!
        assertTrue(gate.shouldRemoveRegion(removal))
        assertNull(gate.beginDownload("new-generation"))
        assertNull(gate.beginRemoval("another-region"))
        gate.finish(removal)
        assertNotNull(gate.beginDownload("new-generation"))
    }

    @Test fun lateCallbackFromDisposedActivityCannotReleaseNewOperation() {
        val gate = OfflineMapOperationGate()
        val disposed = gate.beginDownload("disposed-generation")!!
        gate.finish(disposed)
        val current = gate.beginDownload("new-activity-generation")!!
        gate.finish(disposed)
        assertTrue(gate.isBusy())
        assertFalse(gate.claimNewRegion(disposed))
        assertTrue(gate.claimNewRegion(current))
    }

    @Test fun cleanupIsStartedOnlyOnce() {
        val gate = OfflineMapOperationGate()
        val job = gate.beginDownload("generation")!!
        assertTrue(gate.beginCleanup(job))
        assertFalse(gate.beginCleanup(job))
    }
}
