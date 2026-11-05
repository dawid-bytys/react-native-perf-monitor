package com.perfmonitor

import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReadableMap

class RNPerfMonitorModule(reactContext: ReactApplicationContext) :
  NativeRNPerfMonitorSpec(reactContext) {
  private val visibilityListener: (Boolean) -> Unit = { isVisible -> emitOnVisibilityChange(isVisible) }

  init {
    PerfMonitorController.addVisibilityListener(visibilityListener)
  }

  override fun invalidate() {
    PerfMonitorController.removeVisibilityListener(visibilityListener)
    super.invalidate()
  }

  override fun show() = PerfMonitorController.show()

  override fun hide() = PerfMonitorController.hide()

  override fun toggle() = PerfMonitorController.toggle()

  override fun isVisible() = PerfMonitorController.isVisible

  override fun reportJsMetrics(report: ReadableMap) {
    val jsReport = JsReport(
      frames = report.getDouble("frames"),
      intervalMs = report.getDouble("intervalMs"),
      commits = report.getDouble("commits"),
      renderTotalMs = report.getDouble("renderTotalMs"),
      renderMaxMs = report.getDouble("renderMaxMs"),
      heapUsedBytes = report.getDouble("heapUsedBytes"),
      heapTotalBytes = report.getDouble("heapTotalBytes"),
      activeRequests = report.getDouble("activeRequests").toInt(),
    )

    PerfMonitorController.recordJsReport(jsReport)
  }

  companion object {
    const val NAME = NativeRNPerfMonitorSpec.NAME
  }
}
