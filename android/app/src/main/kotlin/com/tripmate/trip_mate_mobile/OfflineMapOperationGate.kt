package com.tripmate.trip_mate_mobile

/** Process-wide leases keep asynchronous SDK mutations from overlapping,
 * including callbacks belonging to an Activity that has already detached. */
class OfflineMapOperationGate {
    enum class Kind { DOWNLOAD, ESTIMATE, REMOVAL }

    class Lease internal constructor(val id: String, val kind: Kind) {
        internal var ownsRegion = kind == Kind.REMOVAL
        internal var cleaning = kind == Kind.REMOVAL
    }

    private var current: Lease? = null

    @Synchronized fun beginDownload(id: String): Lease? = begin(id, Kind.DOWNLOAD)
    @Synchronized fun beginEstimate(id: String): Lease? = begin(id, Kind.ESTIMATE)
    @Synchronized fun beginRemoval(id: String): Lease? = begin(id, Kind.REMOVAL)

    private fun begin(id: String, kind: Kind): Lease? {
        if (current != null) return null
        return Lease(id, kind).also { current = it }
    }

    /** Called only after the SDK confirms the region does not already exist. */
    @Synchronized fun claimNewRegion(lease: Lease): Boolean {
        if (current !== lease || lease.cleaning || lease.kind != Kind.DOWNLOAD) return false
        lease.ownsRegion = true
        return true
    }

    @Synchronized fun beginCleanup(lease: Lease): Boolean {
        if (current !== lease || lease.cleaning) return false
        lease.cleaning = true
        return true
    }

    @Synchronized fun shouldRemoveRegion(lease: Lease): Boolean =
        current === lease && lease.ownsRegion

    @Synchronized fun finish(lease: Lease) {
        if (current === lease) current = null
    }

    @Synchronized fun isBusy(): Boolean = current != null

    companion object {
        val shared = OfflineMapOperationGate()
    }
}
