package com.perfmonitor

enum class ThermalState(val label: String) {
  UNKNOWN("Unknown"),
  NOMINAL("Nominal"),
  FAIR("Fair"),
  SERIOUS("Serious"),
  CRITICAL("Critical"),
}

data class JsReport(
  val frames: Double,
  val intervalMs: Double,
  val commits: Double,
  val renderTotalMs: Double,
  val renderMaxMs: Double,
  val heapUsedBytes: Double,
  val heapTotalBytes: Double,
  val activeRequests: Int,
)

data class MetricsSnapshot(
  val uiFps: Double = 0.0,
  val displayHz: Double = 60.0,
  val droppedFrames: Int = 0,
  val hasJsMetrics: Boolean = false,
  val isJsStalled: Boolean = false,
  val jsFps: Double = 0.0,
  val jsTargetFps: Double = 60.0,
  val cpuPercent: Double = 0.0,
  val cpuCores: Int = 0,
  val memoryBytes: Double = 0.0,
  val jsHeapUsedBytes: Double = -1.0,
  val jsHeapTotalBytes: Double = -1.0,
  val viewCount: Int = 0,
  val reactCommitsPerSecond: Double = 0.0,
  val reactRenderAvgMs: Double = 0.0,
  val reactRenderMaxMs: Double = 0.0,
  val networkDownBytesPerSecond: Double = 0.0,
  val networkUpBytesPerSecond: Double = 0.0,
  val activeRequests: Int = 0,
  val thermalState: ThermalState = ThermalState.UNKNOWN,
  val temperatureCelsius: Double? = null,
)
