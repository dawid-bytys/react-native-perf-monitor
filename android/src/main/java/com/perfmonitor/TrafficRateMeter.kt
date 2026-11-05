package com.perfmonitor

import kotlin.math.max

internal class TrafficRateMeter(private val windowNanos: Long) {
  private data class TrafficSample(val nanos: Long, val downBytes: Long, val upBytes: Long)

  private val samples = ArrayDeque<TrafficSample>()

  var downBytesPerSecond = 0.0
    private set

  var upBytesPerSecond = 0.0
    private set

  fun record(nanos: Long, downBytes: Long, upBytes: Long) {
    if (downBytes < 0 || upBytes < 0) {
      return
    }

    samples.addLast(TrafficSample(nanos, downBytes, upBytes))

    while (samples.size > 2 && nanos - samples[1].nanos >= windowNanos) {
      samples.removeFirst()
    }

    val oldest = samples.first()
    val elapsedSeconds = (nanos - oldest.nanos) / NANOS_PER_SECOND

    if (elapsedSeconds <= 0) {
      return
    }

    downBytesPerSecond = max(downBytes - oldest.downBytes, 0L) / elapsedSeconds
    upBytesPerSecond = max(upBytes - oldest.upBytes, 0L) / elapsedSeconds
  }

  private companion object {
    const val NANOS_PER_SECOND = 1_000_000_000.0
  }
}
