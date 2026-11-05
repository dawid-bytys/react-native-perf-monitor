package com.perfmonitor

class MetricSeries(val capacity: Int) {
  private val values = DoubleArray(capacity)
  private var start = 0

  var count = 0
    private set

  fun push(value: Double) {
    if (count < capacity) {
      values[(start + count) % capacity] = value
      count += 1
      return
    }

    values[start] = value
    start = (start + 1) % capacity
  }

  operator fun get(index: Int): Double = values[(start + index) % capacity]

  fun minimum(): Double = if (count == 0) 0.0 else (0 until count).minOf { get(it) }

  fun maximum(): Double = if (count == 0) 0.0 else (0 until count).maxOf { get(it) }
}
