package com.pianoflow.android.ui

import android.view.View
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import kotlin.math.max

object UiUtils {
  private const val MIN_EDGE_DP = 10f

  /** Practice: hide status/nav bars; respect cutout + gesture safe areas. */
  fun applyImmersivePractice(
      activity: AppCompatActivity,
      root: View,
      topBar: View? = null,
      bottomBar: View? = null,
  ) {
    WindowCompat.setDecorFitsSystemWindows(activity.window, false)
    WindowInsetsControllerCompat(activity.window, activity.window.decorView).apply {
      hide(WindowInsetsCompat.Type.systemBars())
      systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
    }
    val minPx = (MIN_EDGE_DP * activity.resources.displayMetrics.density).toInt()
    ViewCompat.setOnApplyWindowInsetsListener(root) { v, insets ->
      val safe =
          insets.getInsets(
              WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout(),
          )
      val left = max(safe.left, minPx)
      val top = max(safe.top, minPx)
      val right = max(safe.right, minPx)
      val bottom = max(safe.bottom, minPx)
      if (topBar != null && bottomBar != null) {
        val innerH = (8 * activity.resources.displayMetrics.density).toInt()
        val innerV = (6 * activity.resources.displayMetrics.density).toInt()
        topBar.setPadding(left + innerH, top + innerV, right + innerH, innerV)
        bottomBar.setPadding(left + innerH, innerV, right + innerH, bottom + innerV)
        v.setPadding(0, 0, 0, 0)
      } else {
        v.setPadding(left, top, right, bottom)
      }
      insets
    }
    ViewCompat.requestApplyInsets(root)
  }
}
