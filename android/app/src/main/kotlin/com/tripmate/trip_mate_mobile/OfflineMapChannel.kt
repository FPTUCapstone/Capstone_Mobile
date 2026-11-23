package com.tripmate.trip_mate_mobile

import android.content.Context
import android.os.Handler
import android.os.StatFs
import com.mapbox.common.Cancelable
import com.mapbox.common.NetworkRestriction
import com.mapbox.common.TileRegion
import com.mapbox.common.TileRegionLoadOptions
import com.mapbox.common.TileRegionErrorType
import com.mapbox.common.TileRegionEstimateOptions
import com.mapbox.common.TileStore
import com.mapbox.geojson.Geometry
import com.mapbox.geojson.Polygon
import com.mapbox.geojson.MultiPolygon
import com.mapbox.maps.GlyphsRasterizationMode
import com.mapbox.maps.MapboxMapsOptions
import com.mapbox.maps.OfflineManager
import com.mapbox.maps.StylePackLoadOptions
import com.mapbox.maps.StylePackErrorType
import com.mapbox.maps.TilesetDescriptorOptions
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File

/** App-owned bridge: no changes to the installed Mapbox Flutter plugin. */
class OfflineMapChannel(context: Context, messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {
    private val root = File(context.noBackupFilesDir, "offline-trips")
    private val handler = Handler(context.mainLooper)
    private val channel = MethodChannel(messenger, "com.tripmate.trip_mate_mobile/offline_map")
    private val offlineManager by lazy { OfflineManager() }
    private var store: TileStore? = null
    private var active: Download? = null
    private val gate = OfflineMapOperationGate.shared
    private val styleUri = "mapbox://styles/mapbox/standard"

    private class Download(val lease: OfflineMapOperationGate.Lease, val limit: Long, val result: MethodChannel.Result) {
        val id get() = lease.id
        var styleHandle: Cancelable? = null
        var tileHandle: Cancelable? = null
        var styleBytes = 0L
        var finished = false
    }

    init { channel.setMethodCallHandler(this) }

    fun dispose() {
        channel.setMethodCallHandler(null)
        val job = active ?: return
        if (!job.finished) {
            job.finished = true
            gate.beginCleanup(job.lease)
            job.styleHandle?.cancel()
            job.tileHandle?.cancel()
            cleanupLease(job.lease) {
                finish(job)
                job.result.error("cancelled", "Offline operation cancelled when the Activity detached", null)
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "initialize" -> { initialize(); result.success(null) }
                "storage" -> {
                    initialize()
                    result.success(mapOf("path" to File(root, "packages").absolutePath,
                        "freeBytes" to StatFs(root.absolutePath).availableBytes))
                }
                "download" -> download(call, result)
                "estimate" -> estimate(call, result)
                "cancel" -> cancel(result)
                "verify" -> verify(call.argument<String>("regionId")!!, result)
                "regions" -> {
                    initialize()
                    store!!.getAllTileRegions { expected -> handler.post {
                        if (expected.isError) result.error("regions_unavailable", "Offline map regions could not be read", null)
                        else result.success(expected.value?.map { it.id } ?: emptyList<String>())
                    } }
                }
                "remove" -> {
                    initialize()
                    val id = call.argument<String>("regionId")!!
                    requireValidId(id)
                    val lease = gate.beginRemoval(id)
                    if (lease == null) { result.error("busy", "An offline map operation is active", null); return }
                    cleanupLease(lease) { success ->
                        gate.finish(lease)
                        if (success) result.success(null)
                        else result.error("cleanup_failed", "Offline map cleanup is incomplete", null)
                    }
                }
                else -> result.notImplemented()
            }
        } catch (_: Exception) {
            result.error("offline_map_failed", "Offline map operation failed", null)
        }
    }

    private fun initialize() {
        if (store != null) return
        root.mkdirs()
        val tileRoot = File(root, "tiles").apply { mkdirs() }
        check(TileStore.setRootPath(tileRoot.absolutePath).error == null)
        store = TileStore.create()
        // Configure before creating any offline map view; the SDK uses global options.
        MapboxMapsOptions.tileStore = store
        MapboxMapsOptions.dataPath = File(root, "styles").apply { mkdirs() }.absolutePath
    }

    private fun descriptor() = offlineManager.createTilesetDescriptor(
        TilesetDescriptorOptions.Builder().styleURI(styleUri).minZoom(10).maxZoom(16).build()
    )

    private fun download(call: MethodCall, result: MethodChannel.Result) {
        initialize()
        val id = call.argument<String>("regionId")!!
        val limit = call.argument<Number>("maxBytes")!!.toLong()
        require(limit in 1..150000000)
        requireValidId(id)
        val geometry = geometry(call)
        val lease = gate.beginDownload(id)
        if (lease == null) { result.error("busy", "An offline map operation is active", null); return }
        val job = Download(lease, limit, result)
        active = job
        store!!.getTileRegion(id) { existing -> handler.post {
            if (job.finished) return@post
            if (existing.value != null || existing.error?.type != TileRegionErrorType.DOES_NOT_EXIST) {
                job.finished = true
                finish(job)
                job.result.error("region_exists_or_unavailable", "Use a new offline generation", null)
            } else if (gate.claimNewRegion(lease)) loadStyle(job, geometry)
        } }
    }

    private fun geometry(call: MethodCall): Geometry {
        val value = call.argument<Map<String, Any?>>("geometry")!!
        val json = JSONObject(value).toString()
        return when (value["type"]) {
            "Polygon" -> Polygon.fromJson(json)
            "MultiPolygon" -> MultiPolygon.fromJson(json)
            else -> throw IllegalArgumentException("Offline coverage must be a polygon")
        }
    }

    private fun estimate(call: MethodCall, result: MethodChannel.Result) {
        initialize()
        val id = call.argument<String>("regionId")!!
        requireValidId(id)
        val geometry = geometry(call)
        val lease = gate.beginEstimate(id)
        if (lease == null) { result.error("busy", "An offline map operation is active", null); return }
        val job = Download(lease, 150000000, result)
        active = job
        val options = TileRegionLoadOptions.Builder().geometry(geometry)
            .descriptors(listOf(descriptor())).acceptExpired(true)
            .networkRestriction(NetworkRestriction.NONE).build()
        job.tileHandle = store!!.estimateTileRegion(id, options,
            TileRegionEstimateOptions(0.1f, 5000L, 10000L, null), {},
            { expected -> handler.post {
                if (job.finished) return@post
                val estimate = expected.value
                if (estimate == null) {
                    job.finished = true
                    finish(job)
                    result.success(null)
                } else offlineManager.getStylePack(styleUri) { expectedStyle -> handler.post {
                    if (job.finished) return@post
                    val style = expectedStyle.value
                    val known = style != null && style.requiredResourceCount == style.completedResourceCount && style.completedResourceSize > 0
                    job.finished = true
                    finish(job)
                    // Style size is unknown on first download; never report a
                    // tile-only estimate as the complete map-package size.
                    result.success(if (known) estimate.storageSize + style!!.completedResourceSize else null)
                } }
            } }
        )
    }

    private fun loadStyle(job: Download, geometry: Geometry) {
        offlineManager.getStylePack(styleUri) { expected -> handler.post {
            if (job.finished) return@post
            val existing = expected.value
            if (existing != null && existing.requiredResourceCount == existing.completedResourceCount && existing.completedResourceSize > 0) {
                job.styleBytes = existing.completedResourceSize
                loadTiles(job, geometry)
            } else {
                job.styleHandle = offlineManager.loadStylePack(
                    styleUri,
                    StylePackLoadOptions.Builder().glyphsRasterizationMode(GlyphsRasterizationMode.IDEOGRAPHS_RASTERIZED_LOCALLY).acceptExpired(true).build(),
                    { progress -> handler.post {
                        if (!job.finished) report(job, progress.completedResourceSize,
                            progress.completedResourceCount, progress.requiredResourceCount)
                    } },
                    { loaded -> handler.post {
                        if (job.finished) return@post
                        val pack = loaded.value
                        if (pack == null || pack.requiredResourceCount != pack.completedResourceCount || pack.completedResourceSize <= 0) {
                            fail(job, "style_incomplete")
                        } else {
                            job.styleBytes = pack.completedResourceSize
                            loadTiles(job, geometry)
                        }
                    } }
                )
            }
        } }
    }

    private fun loadTiles(job: Download, geometry: Geometry) {
        if (job.styleBytes >= job.limit) { fail(job, "size_limit"); return }
        val options = TileRegionLoadOptions.Builder().geometry(geometry)
            .descriptors(listOf(descriptor())).acceptExpired(true)
            .networkRestriction(NetworkRestriction.NONE).build()
        job.tileHandle = store!!.loadTileRegion(job.id, options,
            { progress -> handler.post {
                if (!job.finished) report(job, job.styleBytes + progress.completedResourceSize,
                    progress.completedResourceCount, progress.requiredResourceCount)
            } },
            { loaded -> handler.post {
                if (job.finished) return@post
                val region = loaded.value
                if (region == null || region.requiredResourceCount != region.completedResourceCount) {
                    fail(job, "tiles_incomplete")
                } else if (job.styleBytes + region.completedResourceSize > job.limit) {
                    fail(job, "size_limit")
                } else {
                    job.finished = true
                    finish(job)
                    job.result.success(resourceMap(region, job.styleBytes))
                }
            } }
        )
    }

    private fun report(job: Download, bytes: Long, completed: Long, required: Long) {
        if (bytes > job.limit) { fail(job, "size_limit"); return }
        channel.invokeMethod("progress", mapOf("regionId" to job.id, "bytes" to bytes,
            "completed" to completed, "required" to required))
    }

    private fun fail(job: Download, code: String) {
        if (job.finished) return
        job.finished = true
        gate.beginCleanup(job.lease)
        job.styleHandle?.cancel()
        job.tileHandle?.cancel()
        cleanupLease(job.lease) { success ->
            finish(job)
            job.result.error(if (success) code else "cleanup_failed",
                "Offline map download did not complete", null)
        }
    }

    private fun cancel(result: MethodChannel.Result) {
        val job = active
        if (job == null) {
            if (gate.isBusy()) result.error("cleanup_pending", "An offline map operation is still pending", null)
            else result.success(null)
            return
        }
        if (job.finished) { result.error("cleanup_pending", "Offline map cleanup is pending", null); return }
        job.finished = true
        gate.beginCleanup(job.lease)
        job.styleHandle?.cancel()
        job.tileHandle?.cancel()
        cleanupLease(job.lease) { success ->
            finish(job)
            job.result.error(if (success) "cancelled" else "cleanup_failed",
                "Offline download cancelled", null)
            if (success) result.success(null)
            else result.error("cleanup_failed", "Offline map cleanup is incomplete", null)
        }
    }

    private fun requireValidId(id: String) {
        require(Regex("[A-Za-z0-9_-]{1,128}").matches(id))
    }

    private fun finish(job: Download) {
        gate.finish(job.lease)
        if (active === job) active = null
    }

    private fun cleanupLease(lease: OfflineMapOperationGate.Lease, completed: (Boolean) -> Unit) {
        if (!gate.shouldRemoveRegion(lease)) completed(true)
        else cleanup(lease.id, completed)
    }

    /** Retain shared style while any other region refers to it. Native eviction
     * can be deferred; success means references removed, not disk bytes freed. */
    private fun cleanup(id: String, completed: (Boolean) -> Unit) {
        store!!.removeTileRegion(id) { removed -> handler.post {
            if (removed.isError && removed.error?.type != TileRegionErrorType.DOES_NOT_EXIST) {
                completed(false)
            } else {
                store!!.getAllTileRegions { remaining -> handler.post {
                    if (remaining.isError) completed(false)
                    else if (remaining.value?.isNotEmpty() == true) completed(true)
                    else offlineManager.removeStylePack(styleUri) { style -> handler.post {
                        completed(!style.isError || style.error?.type == StylePackErrorType.DOES_NOT_EXIST)
                    } }
                } }
            }
        } }
    }

    private fun verify(id: String, result: MethodChannel.Result) {
        initialize()
        requireValidId(id)
        store!!.getTileRegion(id) { expected -> handler.post {
            val region = expected.value
            if (region == null || region.completedResourceCount != region.requiredResourceCount || region.completedResourceSize <= 0) {
                result.error("incomplete", "Offline tiles are missing", null)
            } else {
                offlineManager.getStylePack(styleUri) { expectedStyle -> handler.post {
                    val style = expectedStyle.value
                    if (style == null || style.completedResourceCount != style.requiredResourceCount || style.completedResourceSize <= 0) {
                        result.error("incomplete", "Offline style is missing", null)
                    } else {
                        store!!.tileRegionContainsDescriptors(id, listOf(descriptor())) { contains -> handler.post {
                            if (contains.value == true) result.success(resourceMap(region, style.completedResourceSize))
                            else result.error("incomplete", "Offline coverage is missing", null)
                        } }
                    }
                } }
            }
        } }
    }

    private fun resourceMap(region: TileRegion, styleBytes: Long) = mapOf(
        "regionId" to region.id, "styleUri" to styleUri,
        "styleBytes" to styleBytes, "tileBytes" to region.completedResourceSize
    )
}
