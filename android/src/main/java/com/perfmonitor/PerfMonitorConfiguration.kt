package com.perfmonitor

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager

internal class PerfMonitorConfiguration(
  val replacesDevMenu: Boolean,
  val showsOnLaunch: Boolean,
) {
  companion object {
    private const val REPLACE_DEV_MENU_KEY = "com.perfmonitor.REPLACE_DEV_MENU"
    private const val SHOW_ON_LAUNCH_KEY = "com.perfmonitor.SHOW_ON_LAUNCH"

    fun isDebuggable(context: Context) =
      context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0

    fun read(context: Context): PerfMonitorConfiguration {
      val metaData = context.packageManager
        .getApplicationInfo(context.packageName, PackageManager.GET_META_DATA)
        .metaData

      return PerfMonitorConfiguration(
        replacesDevMenu = metaData?.getBoolean(REPLACE_DEV_MENU_KEY, true) ?: true,
        showsOnLaunch = metaData?.getBoolean(SHOW_ON_LAUNCH_KEY, false) ?: false,
      )
    }
  }
}
