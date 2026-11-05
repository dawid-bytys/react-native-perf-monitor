package com.perfmonitor

import com.facebook.react.bridge.ReactApplicationContext

class PerfMonitorModule(reactContext: ReactApplicationContext) :
  NativePerfMonitorSpec(reactContext) {

  override fun multiply(a: Double, b: Double): Double {
    return a * b
  }

  companion object {
    const val NAME = NativePerfMonitorSpec.NAME
  }
}
