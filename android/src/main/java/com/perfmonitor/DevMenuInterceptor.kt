package com.perfmonitor

import android.app.Activity
import android.content.Context
import android.content.SharedPreferences
import android.os.Handler
import android.os.Looper
import androidx.core.content.edit
import com.facebook.react.ReactApplication
import com.facebook.react.devsupport.interfaces.DevSupportManager
import java.util.WeakHashMap

internal class DevMenuInterceptor(
  context: Context,
  private val onToggleRequested: () -> Unit,
) : SharedPreferences.OnSharedPreferenceChangeListener {
  private val preferences = context.getSharedPreferences(
    "${context.packageName}_preferences",
    Context.MODE_PRIVATE,
  )
  private val mainHandler = Handler(Looper.getMainLooper())
  private val interceptedManagers = WeakHashMap<DevSupportManager, Unit>()

  fun install() {
    preferences.edit { putBoolean(FPS_DEBUG_KEY, false) }
    preferences.registerOnSharedPreferenceChangeListener(this)
    disableExpoOverlayPermissionRequest()
  }

  fun interceptDevSupportManager(activity: Activity) {
    val reactApplication = activity.application as? ReactApplication ?: return
    val devSupportManager = runCatching { reactApplication.reactHost?.devSupportManager }.getOrNull() ?: return

    if (interceptedManagers.containsKey(devSupportManager)) {
      return
    }

    interceptedManagers[devSupportManager] = Unit
    devSupportManager.addCustomDevOption(activity.getString(com.facebook.react.R.string.catalyst_perf_monitor)) {
      onToggleRequested()
    }
  }

  override fun onSharedPreferenceChanged(sharedPreferences: SharedPreferences, key: String?) {
    if (key != FPS_DEBUG_KEY || !sharedPreferences.getBoolean(FPS_DEBUG_KEY, false)) {
      return
    }

    sharedPreferences.edit { putBoolean(FPS_DEBUG_KEY, false) }
    mainHandler.post(onToggleRequested)
  }

  private fun disableExpoOverlayPermissionRequest() {
    runCatching {
      Class.forName(EXPO_DEV_MENU_SETTINGS_CLASS)
        .getDeclaredField(EXPO_OVERLAY_PERMISSION_FIELD)
        .apply { isAccessible = true }
        .setBoolean(null, false)
    }
  }

  private companion object {
    const val FPS_DEBUG_KEY = "fps_debug"
    const val EXPO_DEV_MENU_SETTINGS_CLASS = "expo.modules.devmenu.DevMenuSettings"
    const val EXPO_OVERLAY_PERMISSION_FIELD = "performanceMonitorNeedsOverlayPermission"
  }
}
