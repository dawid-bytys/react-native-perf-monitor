package com.perfmonitor

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Canvas
import android.graphics.DashPathEffect
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Typeface
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import java.text.NumberFormat
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min

@SuppressLint("ViewConstructor")
internal class PerfMonitorPanelView(
  context: Context,
  private val sampler: MetricsSampler,
  private val callbacks: Callbacks,
) : View(context) {
  interface Callbacks {
    fun onCloseRequested()
    fun onExpandedChanged(isExpanded: Boolean)
    fun onDragged(x: Float, y: Float, isFinished: Boolean)
  }

  private class MetricRow(
    val label: String,
    val value: String,
    val unit: String,
    val detail: String,
    val color: Int,
    val series: MetricSeries,
    val minimum: Double = 0.0,
    val maximum: Double,
    val guide: Double = 0.0,
  )

  private class CollapsedSegment(val label: String, val value: String, val color: Int)

  var isExpanded = true
    set(value) {
      field = value
      requestLayout()
      invalidate()
    }

  private val density = resources.displayMetrics.density
  private val touchSlop = ViewConfiguration.get(context).scaledTouchSlop
  private val numberFormat = NumberFormat.getIntegerInstance()

  private val backgroundPaint = fillPaint(colorFromHex(0x111114, 0.96f))
  private val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
    style = Paint.Style.STROKE
    strokeWidth = 1f
    color = colorFromHex(0xFFFFFF, 0.1f)
  }
  private val trackPaint = fillPaint(colorFromHex(0xFFFFFF, 0.035f))
  private val tilePaint = fillPaint(colorFromHex(0xFFFFFF, 0.05f))
  private val separatorPaint = fillPaint(colorFromHex(0xFFFFFF, 0.08f))
  private val areaPaint = fillPaint(0)
  private val dotPaint = fillPaint(0)
  private val linePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
    style = Paint.Style.STROKE
    strokeWidth = dp(1.5f)
    strokeJoin = Paint.Join.ROUND
    strokeCap = Paint.Cap.ROUND
  }
  private val guidePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
    style = Paint.Style.STROKE
    strokeWidth = dp(1f)
    color = colorFromHex(0xFFFFFF, 0.18f)
    pathEffect = DashPathEffect(floatArrayOf(dp(3f), dp(3f)), 0f)
  }
  private val headerPaint = textPaint(10f, Typeface.BOLD, PRIMARY_TEXT_COLOR, letterSpacing = 0.14f)
  private val labelPaint = textPaint(9f, Typeface.BOLD, SECONDARY_TEXT_COLOR, letterSpacing = 0.08f)
  private val valuePaint = textPaint(19f, Typeface.BOLD, PRIMARY_TEXT_COLOR)
  private val unitPaint = textPaint(10f, Typeface.NORMAL, SECONDARY_TEXT_COLOR)
  private val detailPaint = textPaint(9f, Typeface.NORMAL, SECONDARY_TEXT_COLOR)
  private val tileValuePaint = textPaint(12f, Typeface.BOLD, PRIMARY_TEXT_COLOR)
  private val collapsedLabelPaint = textPaint(10f, Typeface.BOLD, SECONDARY_TEXT_COLOR)
  private val collapsedValuePaint = textPaint(12f, Typeface.BOLD, PRIMARY_TEXT_COLOR)

  private val path = Path()
  private val rect = RectF()

  private var touchDownRawX = 0f
  private var touchDownRawY = 0f
  private var touchDownViewX = 0f
  private var touchDownViewY = 0f
  private var isDragging = false

  init {
    contentDescription = "react-native-perf-monitor"
  }

  override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
    if (!isExpanded) {
      setMeasuredDimension(ceil(collapsedWidth()).toInt(), dp(COLLAPSED_HEIGHT).toInt())
      return
    }

    val height = PADDING + HEADER_HEIGHT + HEADER_GAP + METRIC_ROW_COUNT * ROW_HEIGHT +
      SEPARATOR_GAP + TILE_HEIGHT * 2 + TILE_GAP + PADDING

    setMeasuredDimension(dp(EXPANDED_WIDTH).toInt(), dp(height).toInt())
  }

  fun refresh() {
    if (!isExpanded) {
      requestLayout()
    }

    invalidate()
  }

  override fun onDraw(canvas: Canvas) {
    drawBackground(canvas)

    if (isExpanded) {
      drawExpandedContent(canvas)
      return
    }

    drawCollapsedContent(canvas)
  }

  private fun drawBackground(canvas: Canvas) {
    val radius = if (isExpanded) dp(CORNER_RADIUS) else height / 2f

    rect.set(0.5f, 0.5f, width - 0.5f, height - 0.5f)
    canvas.drawRoundRect(rect, radius, radius, backgroundPaint)
    canvas.drawRoundRect(rect, radius, radius, borderPaint)
  }

  private fun drawExpandedContent(canvas: Canvas) {
    val snapshot = sampler.latestSnapshot
    var y = dp(PADDING)

    drawHeader(canvas, y, snapshot)
    y += dp(HEADER_HEIGHT + HEADER_GAP)

    metricRows(snapshot).forEach { row ->
      drawMetricRow(canvas, row, y)
      y += dp(ROW_HEIGHT)
    }

    canvas.drawRect(dp(PADDING), y + dp(3f), width - dp(PADDING), y + dp(3f) + 1f, separatorPaint)
    y += dp(SEPARATOR_GAP)

    drawTiles(canvas, y, snapshot)
  }

  private fun drawHeader(canvas: Canvas, y: Float, snapshot: MetricsSnapshot) {
    val close = closeButtonRect()

    dotPaint.color = colorForFps(snapshot.uiFps, snapshot.displayHz)
    canvas.drawCircle(dp(PADDING + 4), y + dp(12f), dp(4f), dotPaint)
    drawText(canvas, "PERF MONITOR", dp(PADDING + 15), y + dp(5f), headerPaint)
    drawRightAlignedText(canvas, "${snapshot.displayHz.toInt()} Hz", close.left - dp(4f), y + dp(6f), detailPaint)
    drawCloseGlyph(canvas, close)
  }

  private fun drawCloseGlyph(canvas: Canvas, frame: RectF) {
    val inset = dp(9f)

    linePaint.color = SECONDARY_TEXT_COLOR
    canvas.drawLine(frame.left + inset, frame.top + inset, frame.right - inset, frame.bottom - inset, linePaint)
    canvas.drawLine(frame.right - inset, frame.top + inset, frame.left + inset, frame.bottom - inset, linePaint)
  }

  private fun closeButtonRect(): RectF {
    val right = width - dp(PADDING) + dp(4f)
    val top = dp(PADDING) - dp(2f)

    return RectF(right - dp(28f), top, right, top + dp(28f))
  }

  private fun metricRows(snapshot: MetricsSnapshot) = listOf(
    uiRow(snapshot),
    jsRow(snapshot),
    cpuRow(snapshot),
    memoryRow(snapshot),
    reactRow(snapshot),
  )

  private fun uiRow(snapshot: MetricsSnapshot) = MetricRow(
    label = "UI THREAD",
    value = "%.0f".format(snapshot.uiFps),
    unit = "fps",
    detail = if (snapshot.droppedFrames > 0) "${snapshot.droppedFrames} dropped" else "smooth",
    color = colorForFps(snapshot.uiFps, snapshot.displayHz),
    series = sampler.uiFpsSeries,
    maximum = max(snapshot.displayHz, sampler.uiFpsSeries.maximum()),
  )

  private fun jsRow(snapshot: MetricsSnapshot): MetricRow {
    val maximum = max(snapshot.jsTargetFps, sampler.jsFpsSeries.maximum())

    if (!snapshot.hasJsMetrics) {
      return MetricRow("JS THREAD", "–", "fps", MISSING_JS_DETAIL, MUTED_TEXT_COLOR, sampler.jsFpsSeries, maximum = maximum)
    }

    val color = if (snapshot.isJsStalled) BAD_COLOR else colorForFps(snapshot.jsFps, snapshot.jsTargetFps)

    return MetricRow(
      label = "JS THREAD",
      value = "%.0f".format(snapshot.jsFps),
      unit = "fps",
      detail = if (snapshot.isJsStalled) "stalled" else "responsive",
      color = color,
      series = sampler.jsFpsSeries,
      maximum = maximum,
    )
  }

  private fun cpuRow(snapshot: MetricsSnapshot) = MetricRow(
    label = "CPU",
    value = "%.0f".format(snapshot.cpuPercent),
    unit = "%",
    detail = "${snapshot.cpuCores} cores",
    color = colorForCpu(snapshot.cpuPercent),
    series = sampler.cpuSeries,
    maximum = max(100.0, sampler.cpuSeries.maximum()),
  )

  private fun memoryRow(snapshot: MetricsSnapshot): MetricRow {
    val minimum = sampler.memorySeries.minimum()
    val maximum = sampler.memorySeries.maximum()
    val padding = max((maximum - minimum) * 0.2, BYTES_PER_MEGABYTE)
    val detail = if (snapshot.jsHeapTotalBytes > 0) {
      "JS heap %.0f / %.0f MB".format(
        snapshot.jsHeapUsedBytes / BYTES_PER_MEGABYTE,
        snapshot.jsHeapTotalBytes / BYTES_PER_MEGABYTE,
      )
    } else {
      "resident set"
    }

    return MetricRow(
      label = "MEMORY",
      value = "%.0f".format(snapshot.memoryBytes / BYTES_PER_MEGABYTE),
      unit = "MB",
      detail = detail,
      color = ACCENT_COLOR,
      series = sampler.memorySeries,
      minimum = max(minimum - padding, 0.0),
      maximum = maximum + padding,
    )
  }

  private fun reactRow(snapshot: MetricsSnapshot): MetricRow {
    val frameBudgetMs = 1000 / max(snapshot.displayHz, 1.0)
    val maximum = max(frameBudgetMs * 2, sampler.renderSeries.maximum())

    if (!snapshot.hasJsMetrics) {
      return MetricRow(
        "REACT COMMITS",
        "–",
        "/s",
        MISSING_JS_DETAIL,
        MUTED_TEXT_COLOR,
        sampler.renderSeries,
        maximum = maximum,
        guide = frameBudgetMs,
      )
    }

    val detail = if (snapshot.reactCommitsPerSecond > 0) {
      "avg %.1f · max %.1f ms".format(snapshot.reactRenderAvgMs, snapshot.reactRenderMaxMs)
    } else {
      "idle"
    }

    return MetricRow(
      label = "REACT COMMITS",
      value = "%.0f".format(snapshot.reactCommitsPerSecond),
      unit = "/s",
      detail = detail,
      color = colorForRenderMs(snapshot.reactRenderMaxMs, frameBudgetMs),
      series = sampler.renderSeries,
      maximum = maximum,
      guide = frameBudgetMs,
    )
  }

  private fun drawMetricRow(canvas: Canvas, row: MetricRow, y: Float) {
    val sparklineLeft = dp(PADDING + VALUE_COLUMN_WIDTH)
    val sparkline = RectF(sparklineLeft, y + dp(4f), width - dp(PADDING), y + dp(4f + SPARKLINE_HEIGHT))
    val valueTop = y + dp(12f)

    valuePaint.color = row.color

    val valueWidth = drawText(canvas, row.value, dp(PADDING), valueTop, valuePaint)
    val unitTop = valueTop + (unitPaint.fontMetrics.ascent - valuePaint.fontMetrics.ascent)

    drawText(canvas, row.label, dp(PADDING), y, labelPaint)
    drawText(canvas, row.unit, dp(PADDING) + valueWidth + dp(3f), unitTop, unitPaint)
    drawSparkline(canvas, row, sparkline)
    drawRightAlignedText(canvas, row.detail, width - dp(PADDING), sparkline.bottom + dp(2f), detailPaint)
  }

  private fun drawSparkline(canvas: Canvas, row: MetricRow, bounds: RectF) {
    val series = row.series
    val range = max(row.maximum - row.minimum, 0.0001)
    val step = bounds.width() / max(series.capacity - 1, 1)
    val startX = bounds.right - step * (series.count - 1)

    rect.set(bounds.left, bounds.top - 1f, bounds.right, bounds.bottom + 1f)
    canvas.drawRoundRect(rect, dp(4f), dp(4f), trackPaint)

    if (row.guide > 0 && row.guide < row.maximum) {
      val guideY = bounds.bottom - ((row.guide - row.minimum) / range * bounds.height()).toFloat()

      canvas.drawLine(bounds.left, guideY, bounds.right, guideY, guidePaint)
    }

    if (series.count < 2) {
      return
    }

    path.reset()

    for (index in 0 until series.count) {
      val normalized = ((series[index] - row.minimum) / range).coerceIn(0.0, 1.0)
      val x = startX + step * index
      val pointY = bounds.bottom - (normalized * bounds.height()).toFloat()

      if (index == 0) {
        path.moveTo(x, pointY)
      } else {
        path.lineTo(x, pointY)
      }
    }

    linePaint.color = row.color
    canvas.drawPath(path, linePaint)

    path.lineTo(bounds.right, bounds.bottom)
    path.lineTo(startX, bounds.bottom)
    path.close()
    areaPaint.color = withAlpha(row.color, 0.16f)
    canvas.drawPath(path, areaPaint)
  }

  private fun drawTiles(canvas: Canvas, y: Float, snapshot: MetricsSnapshot) {
    val tileWidth = (width - dp(PADDING * 2 + TILE_GAP)) / 2
    val secondColumnX = dp(PADDING) + tileWidth + dp(TILE_GAP)
    val secondRowY = y + dp(TILE_HEIGHT + TILE_GAP)
    val network = "↓${formatThroughput(snapshot.networkDownBytesPerSecond)} ↑${formatThroughput(snapshot.networkUpBytesPerSecond)}"
    val requests = if (snapshot.hasJsMetrics) numberFormat.format(snapshot.activeRequests) else "–"
    val thermal = snapshot.temperatureCelsius?.let { "${snapshot.thermalState.label} · %.0f°C".format(it) }
      ?: snapshot.thermalState.label

    drawTile(canvas, "NATIVE VIEWS", numberFormat.format(snapshot.viewCount), PRIMARY_TEXT_COLOR, dp(PADDING), y, tileWidth)
    drawTile(canvas, "ACTIVE REQUESTS", requests, PRIMARY_TEXT_COLOR, secondColumnX, y, tileWidth)
    drawTile(canvas, "NETWORK (APP)", network, PRIMARY_TEXT_COLOR, dp(PADDING), secondRowY, tileWidth)
    drawTile(canvas, "THERMAL STATE", thermal, colorForThermalState(snapshot.thermalState), secondColumnX, secondRowY, tileWidth)
  }

  private fun drawTile(canvas: Canvas, label: String, value: String, valueColor: Int, x: Float, y: Float, tileWidth: Float) {
    val availableWidth = tileWidth - dp(16f)

    rect.set(x, y, x + tileWidth, y + dp(TILE_HEIGHT))
    canvas.drawRoundRect(rect, dp(8f), dp(8f), tilePaint)
    drawText(canvas, label, x + dp(8f), y + dp(5f), labelPaint)

    tileValuePaint.color = valueColor
    tileValuePaint.textSize = sp(12f)

    val measuredWidth = tileValuePaint.measureText(value)

    if (measuredWidth > availableWidth) {
      tileValuePaint.textSize = max(sp(12f) * availableWidth / measuredWidth, sp(8f))
    }

    drawText(canvas, value, x + dp(8f), y + dp(17f), tileValuePaint)
  }

  private fun collapsedSegments(): List<CollapsedSegment> {
    val snapshot = sampler.latestSnapshot
    val jsColor = when {
      !snapshot.hasJsMetrics -> MUTED_TEXT_COLOR
      snapshot.isJsStalled -> BAD_COLOR
      else -> colorForFps(snapshot.jsFps, snapshot.jsTargetFps)
    }

    return listOf(
      CollapsedSegment("UI", "%.0f".format(snapshot.uiFps), colorForFps(snapshot.uiFps, snapshot.displayHz)),
      CollapsedSegment("JS", if (snapshot.hasJsMetrics) "%.0f".format(snapshot.jsFps) else "–", jsColor),
      CollapsedSegment("CPU", "%.0f%%".format(snapshot.cpuPercent), colorForCpu(snapshot.cpuPercent)),
      CollapsedSegment("RAM", "%.0f".format(snapshot.memoryBytes / BYTES_PER_MEGABYTE), ACCENT_COLOR),
    )
  }

  private fun collapsedWidth(): Float {
    val segmentsWidth = collapsedSegments().sumOf { segment ->
      (collapsedLabelPaint.measureText(segment.label) + dp(4f) + collapsedValuePaint.measureText(segment.value)).toDouble()
    }
    val gaps = dp(COLLAPSED_SEGMENT_GAP) * (collapsedSegments().size - 1)

    return segmentsWidth.toFloat() + gaps + dp(PADDING * 2)
  }

  private fun drawCollapsedContent(canvas: Canvas) {
    val baseline = height / 2f - (collapsedValuePaint.fontMetrics.ascent + collapsedValuePaint.fontMetrics.descent) / 2
    var x = dp(PADDING)

    collapsedSegments().forEach { segment ->
      collapsedValuePaint.color = segment.color
      canvas.drawText(segment.label, x, baseline, collapsedLabelPaint)
      x += collapsedLabelPaint.measureText(segment.label) + dp(4f)
      canvas.drawText(segment.value, x, baseline, collapsedValuePaint)
      x += collapsedValuePaint.measureText(segment.value) + dp(COLLAPSED_SEGMENT_GAP)
    }
  }

  @SuppressLint("ClickableViewAccessibility")
  override fun onTouchEvent(event: MotionEvent): Boolean {
    when (event.actionMasked) {
      MotionEvent.ACTION_DOWN -> {
        touchDownRawX = event.rawX
        touchDownRawY = event.rawY
        touchDownViewX = x
        touchDownViewY = y
        isDragging = false
      }

      MotionEvent.ACTION_MOVE -> handleDrag(event, isFinished = false)

      MotionEvent.ACTION_UP -> {
        if (isDragging) {
          handleDrag(event, isFinished = true)
        } else {
          handleTap(event)
        }
      }

      MotionEvent.ACTION_CANCEL -> if (isDragging) handleDrag(event, isFinished = true)
    }

    return true
  }

  private fun handleDrag(event: MotionEvent, isFinished: Boolean) {
    val deltaX = event.rawX - touchDownRawX
    val deltaY = event.rawY - touchDownRawY

    if (!isDragging && max(abs(deltaX), abs(deltaY)) < touchSlop) {
      return
    }

    isDragging = true
    callbacks.onDragged(touchDownViewX + deltaX, touchDownViewY + deltaY, isFinished)
  }

  private fun handleTap(event: MotionEvent) {
    if (isExpanded && closeButtonRect().contains(event.x, event.y)) {
      callbacks.onCloseRequested()
      return
    }

    isExpanded = !isExpanded
    callbacks.onExpandedChanged(isExpanded)
  }

  private fun drawText(canvas: Canvas, text: String, x: Float, top: Float, paint: Paint): Float {
    canvas.drawText(text, x, top - paint.fontMetrics.ascent, paint)

    return paint.measureText(text)
  }

  private fun drawRightAlignedText(canvas: Canvas, text: String, right: Float, top: Float, paint: Paint) {
    drawText(canvas, text, right - paint.measureText(text), top, paint)
  }

  private fun formatThroughput(bytesPerSecond: Double) = when {
    bytesPerSecond < 1024 -> "%.0f B/s".format(bytesPerSecond)
    bytesPerSecond < BYTES_PER_MEGABYTE -> "%.1f KB/s".format(bytesPerSecond / 1024)
    else -> "%.1f MB/s".format(bytesPerSecond / BYTES_PER_MEGABYTE)
  }

  private fun dp(value: Float) = value * density

  private fun sp(value: Float) = value * resources.displayMetrics.scaledDensity

  private fun fillPaint(color: Int) = Paint(Paint.ANTI_ALIAS_FLAG).apply {
    style = Paint.Style.FILL
    this.color = color
  }

  private fun textPaint(size: Float, style: Int, color: Int, letterSpacing: Float = 0f) =
    Paint(Paint.ANTI_ALIAS_FLAG).apply {
      textSize = sp(size)
      typeface = Typeface.create(Typeface.DEFAULT, style)
      fontFeatureSettings = "tnum"
      this.letterSpacing = letterSpacing
      this.color = color
    }

  private companion object {
    const val EXPANDED_WIDTH = 296f
    const val PADDING = 12f
    const val HEADER_HEIGHT = 24f
    const val HEADER_GAP = 8f
    const val ROW_HEIGHT = 40f
    const val VALUE_COLUMN_WIDTH = 100f
    const val SPARKLINE_HEIGHT = 22f
    const val SEPARATOR_GAP = 10f
    const val TILE_HEIGHT = 34f
    const val TILE_GAP = 8f
    const val COLLAPSED_HEIGHT = 30f
    const val COLLAPSED_SEGMENT_GAP = 10f
    const val CORNER_RADIUS = 14f
    const val METRIC_ROW_COUNT = 5
    const val BYTES_PER_MEGABYTE = 1024.0 * 1024.0
    const val MISSING_JS_DETAIL = "import the package in JS"

    val GOOD_COLOR = colorFromHex(0x34D399)
    val WARNING_COLOR = colorFromHex(0xFBBF24)
    val BAD_COLOR = colorFromHex(0xF87171)
    val ACCENT_COLOR = colorFromHex(0x60A5FA)
    val PRIMARY_TEXT_COLOR = colorFromHex(0xFFFFFF, 0.96f)
    val SECONDARY_TEXT_COLOR = colorFromHex(0x9CA3AF)
    val MUTED_TEXT_COLOR = colorFromHex(0xFFFFFF, 0.38f)

    fun colorFromHex(hex: Int, alpha: Float = 1f) = ((alpha * 255).toInt() shl 24) or (hex and 0xFFFFFF)

    fun withAlpha(color: Int, alpha: Float) = colorFromHex(color, alpha)

    fun colorForFps(fps: Double, targetFps: Double): Int {
      val ratio = if (targetFps > 0) fps / targetFps else 0.0

      return when {
        ratio >= 0.9 -> GOOD_COLOR
        ratio >= 0.6 -> WARNING_COLOR
        else -> BAD_COLOR
      }
    }

    fun colorForCpu(cpuPercent: Double) = when {
      cpuPercent < 60 -> GOOD_COLOR
      cpuPercent < 100 -> WARNING_COLOR
      else -> BAD_COLOR
    }

    fun colorForRenderMs(renderMs: Double, frameBudgetMs: Double) = when {
      renderMs < frameBudgetMs / 2 -> GOOD_COLOR
      renderMs < frameBudgetMs -> WARNING_COLOR
      else -> BAD_COLOR
    }

    fun colorForThermalState(state: ThermalState) = when (state) {
      ThermalState.NOMINAL -> GOOD_COLOR
      ThermalState.FAIR -> WARNING_COLOR
      ThermalState.SERIOUS, ThermalState.CRITICAL -> BAD_COLOR
      ThermalState.UNKNOWN -> SECONDARY_TEXT_COLOR
    }
  }
}
