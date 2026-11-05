package com.perfmonitor

import android.app.Activity
import android.app.Application
import android.content.Context
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.core.content.edit
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import java.lang.ref.WeakReference
import java.util.concurrent.CopyOnWriteArraySet
import kotlin.math.max
import kotlin.math.min

object PerfMonitorController : Application.ActivityLifecycleCallbacks, PerfMonitorPanelView.Callbacks {
  private const val PREFERENCES_NAME = "react_native_perf_monitor"
  private const val VISIBLE_KEY = "visible"
  private const val EXPANDED_KEY = "expanded"
  private const val PANEL_X_KEY = "panelX"
  private const val PANEL_Y_KEY = "panelY"
  private const val SCREEN_MARGIN_DP = 6f

  private val mainHandler = Handler(Looper.getMainLooper())
  private val visibilityListeners = CopyOnWriteArraySet<(Boolean) -> Unit>()

  private var application: Application? = null
  private var sampler: MetricsSampler? = null
  private var devMenuInterceptor: DevMenuInterceptor? = null
  private var resumedActivity: WeakReference<Activity>? = null
  private var panel: PerfMonitorPanelView? = null

  @Volatile
  var isVisible = false
    private set

  internal fun install(application: Application) {
    if (this.application != null || !PerfMonitorConfiguration.isDebuggable(application)) {
      return
    }

    val configuration = PerfMonitorConfiguration.read(application)

    this.application = application
    sampler = MetricsSampler(application) { panel?.refresh() }.apply {
      viewRootProvider = { resumedActivity?.get()?.findViewById(android.R.id.content) }
    }
    application.registerActivityLifecycleCallbacks(this)

    if (configuration.replacesDevMenu) {
      devMenuInterceptor = DevMenuInterceptor(application, ::toggle).apply { install() }
    }

    isVisible = configuration.showsOnLaunch || preferences(application).getBoolean(VISIBLE_KEY, false)
  }

  fun show() = setVisible(true)

  fun hide() = setVisible(false)

  fun toggle() = setVisible(!isVisible)

  fun addVisibilityListener(listener: (Boolean) -> Unit) {
    visibilityListeners.add(listener)
  }

  fun removeVisibilityListener(listener: (Boolean) -> Unit) {
    visibilityListeners.remove(listener)
  }

  internal fun recordJsReport(report: JsReport) {
    mainHandler.post { sampler?.recordJsReport(report) }
  }

  private fun setVisible(visible: Boolean) {
    if (Looper.myLooper() != Looper.getMainLooper()) {
      mainHandler.post { setVisible(visible) }
      return
    }

    val application = application ?: return

    if (isVisible == visible) {
      return
    }

    isVisible = visible
    preferences(application).edit { putBoolean(VISIBLE_KEY, visible) }

    if (visible) {
      resumedActivity?.get()?.let(::attach)
    } else {
      detach()
    }

    visibilityListeners.forEach { it(visible) }
  }

  private fun attach(activity: Activity) {
    val sampler = sampler ?: return

    if (!isVisible || panel != null) {
      return
    }

    val decorView = activity.window.decorView as ViewGroup
    val panelView = PerfMonitorPanelView(activity, sampler, this).apply {
      isExpanded = preferences(activity).getBoolean(EXPANDED_KEY, true)
      elevation = 1000f
    }

    decorView.addView(
      panelView,
      FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT),
    )
    panelView.addOnLayoutChangeListener { _, _, _, _, _, _, _, _, _ ->
      moveTo(panelView, panelView.x, panelView.y, isFinished = false)
    }
    panel = panelView
    restorePosition(panelView)
    sampler.start()
  }

  private fun detach() {
    sampler?.stop()
    panel?.let { (it.parent as? ViewGroup)?.removeView(it) }
    panel = null
  }

  private fun restorePosition(panelView: PerfMonitorPanelView) {
    val preferences = preferences(panelView.context)
    val insets = systemBarInsets(panelView)
    val margin = SCREEN_MARGIN_DP * panelView.resources.displayMetrics.density
    val x = preferences.getFloat(PANEL_X_KEY, insets.left + margin)
    val y = preferences.getFloat(PANEL_Y_KEY, insets.top + margin)

    panelView.post { moveTo(panelView, x, y, isFinished = false) }
  }

  private fun moveTo(panelView: PerfMonitorPanelView, x: Float, y: Float, isFinished: Boolean) {
    val parent = panelView.parent as? ViewGroup ?: return
    val insets = systemBarInsets(panelView)
    val margin = SCREEN_MARGIN_DP * panelView.resources.displayMetrics.density
    val minimumX = insets.left + margin
    val minimumY = insets.top + margin
    val maximumX = max(parent.width - insets.right - margin - panelView.width, minimumX)
    val maximumY = max(parent.height - insets.bottom - margin - panelView.height, minimumY)

    panelView.x = min(max(x, minimumX), maximumX)
    panelView.y = min(max(y, minimumY), maximumY)

    if (isFinished) {
      preferences(panelView.context).edit {
        putFloat(PANEL_X_KEY, panelView.x)
        putFloat(PANEL_Y_KEY, panelView.y)
      }
    }
  }

  private fun systemBarInsets(panelView: PerfMonitorPanelView) =
    ViewCompat.getRootWindowInsets(panelView)
      ?.getInsets(WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout())
      ?: androidx.core.graphics.Insets.NONE

  private fun preferences(context: Context) =
    context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)

  override fun onCloseRequested() = hide()

  override fun onExpandedChanged(isExpanded: Boolean) {
    val panelView = panel ?: return

    preferences(panelView.context).edit { putBoolean(EXPANDED_KEY, isExpanded) }
  }

  override fun onDragged(x: Float, y: Float, isFinished: Boolean) {
    val panelView = panel ?: return

    moveTo(panelView, x, y, isFinished)
  }

  override fun onActivityResumed(activity: Activity) {
    resumedActivity = WeakReference(activity)
    devMenuInterceptor?.interceptDevSupportManager(activity)
    attach(activity)
  }

  override fun onActivityPaused(activity: Activity) {
    if (resumedActivity?.get() === activity) {
      detach()
    }
  }

  override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) = Unit

  override fun onActivityStarted(activity: Activity) = Unit

  override fun onActivityStopped(activity: Activity) = Unit

  override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) = Unit

  override fun onActivityDestroyed(activity: Activity) = Unit
}
