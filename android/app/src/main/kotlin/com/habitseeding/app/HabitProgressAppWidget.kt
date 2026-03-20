package com.habitseeding.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import kotlin.math.max
import org.json.JSONObject

class HabitProgressAppWidget : AppWidgetProvider() {

  override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
    for (appWidgetId in appWidgetIds) {
      updateAppWidget(context, appWidgetManager, appWidgetId)
    }
  }

  override fun onAppWidgetOptionsChanged(
    context: Context,
    appWidgetManager: AppWidgetManager,
    appWidgetId: Int,
    newOptions: android.os.Bundle,
  ) {
    super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
    updateAppWidget(context, appWidgetManager, appWidgetId)
  }

  companion object {
    private data class PendingItem(val habitId: String, val name: String)

    fun updateAll(context: Context) {
      val mgr = AppWidgetManager.getInstance(context)
      val ids = mgr.getAppWidgetIds(ComponentName(context, HabitProgressAppWidget::class.java))
      if (ids.isEmpty()) return
      for (id in ids) {
        updateAppWidget(context, mgr, id)
      }
    }

    private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
      val views = RemoteViews(context.packageName, R.layout.habit_progress_widget)
      try {
        val raw = HabitProgressWidgetStore.readSnapshotJson(context)

        var eligibleTotal = 0
        var pendingTotal = 0
        var allDone = false
        val pendingAll = ArrayList<PendingItem>()
        val pending = ArrayList<PendingItem>()

        if (!raw.isNullOrBlank()) {
          try {
            val obj = JSONObject(raw)
            eligibleTotal = obj.optInt("eligibleTotal", 0)
            pendingTotal = obj.optInt("pendingTotal", 0)
            allDone = obj.optBoolean("allDone", false)
            val fullArr = obj.optJSONArray("pendingAll")
            if (fullArr != null) {
              for (i in 0 until fullArr.length()) {
                val it = fullArr.optJSONObject(i) ?: continue
                val habitId = it.optString("habitId", "").trim()
                val name = it.optString("name", "").trim()
                if (habitId.isNotEmpty()) pendingAll.add(PendingItem(habitId = habitId, name = name))
              }
            }
            val arr = obj.optJSONArray("pending")
            if (arr != null) {
              for (i in 0 until arr.length()) {
                val it = arr.optJSONObject(i) ?: continue
                val habitId = it.optString("habitId", "").trim()
                val name = it.optString("name", "").trim()
                if (habitId.isNotEmpty()) pending.add(PendingItem(habitId = habitId, name = name))
              }
            }
          } catch (_: Throwable) {}
        }

        val sourcePending = if (pendingAll.isNotEmpty()) pendingAll else pending
        if (pendingTotal <= 0 && sourcePending.isNotEmpty()) {
          pendingTotal = sourcePending.size
        }
        views.setTextViewText(R.id.header_text, "Today")
        views.setTextViewText(R.id.pending_left_text, if (eligibleTotal > 0) "$pendingTotal left" else "")
        views.setViewVisibility(R.id.pending_left_text, if (eligibleTotal > 0) View.VISIBLE else View.GONE)
        val doneCount = max(0, eligibleTotal - pendingTotal)
        views.setTextViewText(R.id.subtitle_text, "$doneCount of $eligibleTotal done")
        views.setViewVisibility(R.id.subtitle_text, if (eligibleTotal > 0) View.VISIBLE else View.GONE)

        val showAllDone = allDone || (eligibleTotal > 0 && pendingTotal == 0)
        val noHabits = eligibleTotal <= 0
        val showStatus = showAllDone || noHabits
        views.setViewVisibility(R.id.status_container, if (showStatus) View.VISIBLE else View.GONE)
        views.setViewVisibility(R.id.rows_container, if (showStatus) View.GONE else View.VISIBLE)
        views.setViewVisibility(R.id.more_text, View.GONE)

        if (showAllDone) {
          views.setTextViewText(R.id.status_text, "All done for today")
        } else if (noHabits) {
          views.setTextViewText(R.id.status_text, "No habits scheduled today")
        } else {
          val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
          val maxVisibleRows = maxRowsForSize(options, pendingTotal)
          val shown = sourcePending.take(maxVisibleRows)
          val extraCount = max(0, pendingTotal - shown.size)
          bindRow(context, views, appWidgetId, R.id.row1, R.id.cb1, R.id.text1, shown.getOrNull(0))
          bindRow(context, views, appWidgetId, R.id.row2, R.id.cb2, R.id.text2, shown.getOrNull(1))
          bindRow(context, views, appWidgetId, R.id.row3, R.id.cb3, R.id.text3, shown.getOrNull(2))
          if (extraCount > 0) {
            views.setTextViewText(R.id.more_text, "+$extraCount more")
            views.setViewVisibility(R.id.more_text, View.VISIBLE)
          }
        }
      } catch (_: Throwable) {
        views.setTextViewText(R.id.header_text, "Open app to load habits")
        views.setViewVisibility(R.id.status_container, View.GONE)
        views.setViewVisibility(R.id.rows_container, View.GONE)
        views.setViewVisibility(R.id.subtitle_text, View.GONE)
        views.setViewVisibility(R.id.pending_left_text, View.GONE)
        views.setViewVisibility(R.id.more_text, View.GONE)
      }
      appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun maxRowsForSize(options: android.os.Bundle?, pendingTotal: Int): Int {
      val minWidthDp = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH) ?: 0
      val minHeightDp = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT) ?: 0
      val isSmall = (minWidthDp in 1..219) || (minHeightDp in 1..139)
      if (isSmall) return 1
      return if (pendingTotal > 2) 2 else 3
    }

    private fun bindRow(
      context: Context,
      views: RemoteViews,
      appWidgetId: Int,
      rowId: Int,
      cbId: Int,
      textId: Int,
      item: PendingItem?,
    ) {
      if (item == null) {
        views.setViewVisibility(rowId, View.GONE)
        return
      }
      val habitId = item.habitId
      val name = item.name
      if (habitId.isBlank()) {
        views.setViewVisibility(rowId, View.GONE)
        return
      }

      views.setViewVisibility(rowId, View.VISIBLE)
      views.setTextViewText(textId, name)
      views.setBoolean(cbId, "setChecked", false)

      val intent = Intent(context, HabitProgressWidgetActionReceiver::class.java).apply {
        action = HabitProgressWidgetActionReceiver.ACTION_TOGGLE_HABIT
        putExtra(HabitProgressWidgetActionReceiver.EXTRA_HABIT_ID, habitId)
      }
      val requestCode = (31 * appWidgetId) + habitId.hashCode()
      val pi = PendingIntent.getBroadcast(
        context,
        requestCode,
        intent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
      )
      views.setOnClickPendingIntent(rowId, pi)
      views.setOnClickPendingIntent(cbId, pi)
      views.setOnClickPendingIntent(textId, pi)
    }
  }
}
