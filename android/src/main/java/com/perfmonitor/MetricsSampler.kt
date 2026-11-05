package com.perfmonitor

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.display.DisplayManager
import android.net.TrafficStats
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.Process
import android.system.Os
import android.system.OsConstants
import android.view.Choreographer
import android.view.Display
import android.view.View
import android.view.ViewGroup
import java.io.File
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

internal class MetricsSampler(
  private val context: Context,
  private val onSnapshot: (MetricsSnapshot) -> Unit,
) : Choreographer.FrameCallback {
  var viewRootProvider: () -> View? = { null }

  val uiFpsSeries = MetricSeries(SERIES_CAPACITY)
  val jsFpsSeries = MetricSeries(SERIES_CAPACITY)
  val cpuSeries = MetricSeries(SERIES_CAPACITY)
  val memorySeries = MetricSeries(SERIES_CAPACITY)
  val renderSeries = MetricSeries(SERIES_CAPACITY)

  var latestSnapshot = MetricsSnapshot()
    private set

  private val handler = Handler(Looper.getMainLooper())
  private val sampleRunnable = object : Runnable {
    override fun run() {
      sample()
      handler.postDelayed(this, SAMPLE_INTERVAL_MS)
    }
  }
  private val pageSizeBytes = Os.sysconf(OsConstants._SC_PAGESIZE).toDouble()
  private val uid = Process.myUid()

  private var isRunning = false
  private var previousFrameNanos = 0L
  private var framesInWindow = 0
  private var droppedFramesInWindow = 0
  private var windowStartNanos = 0L
  private var cpuMillisAtWindowStart = 0L
  private val trafficRateMeter = TrafficRateMeter(TRAFFIC_WINDOW_NANOS)
  private var sampleCount = 0
  private var viewCount = 0
  private var temperatureCelsius: Double? = null
  private var displayHz = 60.0

  private var hasJsReports = false
  private var lastJsReportNanos = 0L
  private var pendingJsFrames = 0.0
  private var pendingJsIntervalMs = 0.0
  private var pendingCommits = 0.0
  private var pendingRenderTotalMs = 0.0
  private var pendingRenderMaxMs = 0.0
  private var jsHeapUsedBytes = -1.0
  private var jsHeapTotalBytes = -1.0
  private var activeRequests = 0
  private var jsFps = 0.0
  private var jsTargetFps = DEFAULT_JS_TARGET_FPS

  fun start() {
    if (isRunning) {
      return
    }

    isRunning = true
    resetWindow()
    Choreographer.getInstance().postFrameCallback(this)
    handler.postDelayed(sampleRunnable, SAMPLE_INTERVAL_MS)
  }

  fun stop() {
    isRunning = false
    Choreographer.getInstance().removeFrameCallback(this)
    handler.removeCallbacks(sampleRunnable)
  }

  fun recordJsReport(report: JsReport) {
    hasJsReports = true
    lastJsReportNanos = System.nanoTime()
    pendingJsFrames += report.frames
    pendingJsIntervalMs += report.intervalMs
    pendingCommits += report.commits
    pendingRenderTotalMs += report.renderTotalMs
    pendingRenderMaxMs = max(pendingRenderMaxMs, report.renderMaxMs)
    jsHeapUsedBytes = report.heapUsedBytes
    jsHeapTotalBytes = report.heapTotalBytes
    activeRequests = report.activeRequests
  }

  override fun doFrame(frameTimeNanos: Long) {
    if (!isRunning) {
      return
    }

    if (previousFrameNanos > 0) {
      val gapNanos = (frameTimeNanos - previousFrameNanos).toDouble()
      val budgetNanos = NANOS_PER_SECOND / displayHz

      droppedFramesInWindow += max((gapNanos / budgetNanos).roundToInt() - 1, 0)
    }

    previousFrameNanos = frameTimeNanos
    framesInWindow += 1
    Choreographer.getInstance().postFrameCallback(this)
  }

  private fun resetWindow() {
    displayHz = readDisplayHz()
    windowStartNanos = System.nanoTime()
    previousFrameNanos = 0L
    framesInWindow = 0
    droppedFramesInWindow = 0
    cpuMillisAtWindowStart = Process.getElapsedCpuTime()
  }

  private fun sample() {
    val now = System.nanoTime()
    val elapsedSeconds = max((now - windowStartNanos) / NANOS_PER_SECOND, 0.001)

    refreshSlowMetrics()
    trafficRateMeter.record(now, TrafficStats.getUidRxBytes(uid), TrafficStats.getUidTxBytes(uid))

    val systemSnapshot = MetricsSnapshot(
      uiFps = min(framesInWindow / elapsedSeconds, displayHz),
      displayHz = displayHz,
      droppedFrames = droppedFramesInWindow,
      cpuPercent = readCpuPercent(elapsedSeconds),
      cpuCores = Runtime.getRuntime().availableProcessors(),
      memoryBytes = readResidentMemoryBytes(),
      viewCount = viewCount,
      networkDownBytesPerSecond = trafficRateMeter.downBytesPerSecond,
      networkUpBytesPerSecond = trafficRateMeter.upBytesPerSecond,
      thermalState = readThermalState(),
      temperatureCelsius = temperatureCelsius,
    )
    val snapshot = withJsMetrics(systemSnapshot, now, elapsedSeconds)

    recordSeries(snapshot)
    latestSnapshot = snapshot
    sampleCount += 1
    windowStartNanos = now
    framesInWindow = 0
    droppedFramesInWindow = 0
    displayHz = readDisplayHz()

    onSnapshot(snapshot)
  }

  private fun refreshSlowMetrics() {
    if (sampleCount % VIEW_COUNT_SAMPLE_STRIDE == 0) {
      viewCount = viewRootProvider()?.let(::countViews) ?: 0
    }

    if (sampleCount % TEMPERATURE_SAMPLE_STRIDE == 0) {
      temperatureCelsius = readBatteryTemperatureCelsius()
    }
  }

  private fun withJsMetrics(
    systemSnapshot: MetricsSnapshot,
    now: Long,
    elapsedSeconds: Double,
  ): MetricsSnapshot {
    if (!hasJsReports) {
      return systemSnapshot
    }

    val isStalled = (now - lastJsReportNanos) / NANOS_PER_SECOND > JS_STALL_THRESHOLD_SECONDS

    if (pendingJsIntervalMs > 0) {
      jsFps = pendingJsFrames / pendingJsIntervalMs * 1000
    } else if (isStalled) {
      jsFps = 0.0
    }

    if (jsFps > DEFAULT_JS_TARGET_FPS * 1.1) {
      jsTargetFps = max(jsTargetFps, displayHz)
    }

    val snapshot = systemSnapshot.copy(
      hasJsMetrics = true,
      isJsStalled = isStalled,
      jsFps = min(jsFps, jsTargetFps),
      jsTargetFps = jsTargetFps,
      jsHeapUsedBytes = jsHeapUsedBytes,
      jsHeapTotalBytes = jsHeapTotalBytes,
      activeRequests = activeRequests,
      reactCommitsPerSecond = pendingCommits / elapsedSeconds,
      reactRenderAvgMs = if (pendingCommits > 0) pendingRenderTotalMs / pendingCommits else 0.0,
      reactRenderMaxMs = pendingRenderMaxMs,
    )

    pendingJsFrames = 0.0
    pendingJsIntervalMs = 0.0
    pendingCommits = 0.0
    pendingRenderTotalMs = 0.0
    pendingRenderMaxMs = 0.0

    return snapshot
  }

  private fun recordSeries(snapshot: MetricsSnapshot) {
    uiFpsSeries.push(snapshot.uiFps)
    cpuSeries.push(snapshot.cpuPercent)
    memorySeries.push(snapshot.memoryBytes)

    if (snapshot.hasJsMetrics) {
      jsFpsSeries.push(snapshot.jsFps)
      renderSeries.push(snapshot.reactRenderMaxMs)
    }
  }

  private fun readDisplayHz(): Double {
    val displayManager = context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
    val refreshRate = displayManager.getDisplay(Display.DEFAULT_DISPLAY)?.refreshRate ?: 60f

    return refreshRate.roundToInt().toDouble()
  }

  private fun readCpuPercent(elapsedSeconds: Double): Double {
    val cpuMillis = Process.getElapsedCpuTime()
    val cpuPercent = (cpuMillis - cpuMillisAtWindowStart) / 1000.0 / elapsedSeconds * 100

    cpuMillisAtWindowStart = cpuMillis

    return max(cpuPercent, 0.0)
  }

  private fun readResidentMemoryBytes(): Double {
    val residentPages = runCatching {
      File("/proc/self/statm").readText().trim().split(" ")[1].toDouble()
    }.getOrDefault(0.0)

    return residentPages * pageSizeBytes
  }

  private fun readThermalState(): ThermalState {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
      return ThermalState.UNKNOWN
    }

    val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager

    return when (powerManager.currentThermalStatus) {
      PowerManager.THERMAL_STATUS_NONE -> ThermalState.NOMINAL
      PowerManager.THERMAL_STATUS_LIGHT, PowerManager.THERMAL_STATUS_MODERATE -> ThermalState.FAIR
      PowerManager.THERMAL_STATUS_SEVERE -> ThermalState.SERIOUS
      else -> ThermalState.CRITICAL
    }
  }

  private fun readBatteryTemperatureCelsius(): Double? {
    val batteryStatus = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
    val tenthsOfDegree = batteryStatus?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, Int.MIN_VALUE)

    if (tenthsOfDegree == null || tenthsOfDegree == Int.MIN_VALUE) {
      return null
    }

    return tenthsOfDegree / 10.0
  }

  private fun countViews(view: View): Int {
    if (view !is ViewGroup) {
      return 1
    }

    return 1 + (0 until view.childCount).sumOf { countViews(view.getChildAt(it)) }
  }

  private companion object {
    const val SAMPLE_INTERVAL_MS = 500L
    const val SERIES_CAPACITY = 60
    const val VIEW_COUNT_SAMPLE_STRIDE = 2
    const val TEMPERATURE_SAMPLE_STRIDE = 4
    const val JS_STALL_THRESHOLD_SECONDS = 1.0
    const val DEFAULT_JS_TARGET_FPS = 60.0
    const val NANOS_PER_SECOND = 1_000_000_000.0
    const val TRAFFIC_WINDOW_NANOS = 2_000_000_000L
  }
}
