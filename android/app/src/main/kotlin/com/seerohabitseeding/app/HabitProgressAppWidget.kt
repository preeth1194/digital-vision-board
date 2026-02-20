package com.seerohabitseeding.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject

class HabitProgressAppWidget : AppWidgetProvider() {

  override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
    for (appWidgetId in appWidgetIds) {
      updateAppWidget(context, appWidgetManager, appWidgetId)
    }
  }

  companion object {
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    private const val SNAPSHOT_KEY = "flutter.habit_progress_widget_snapshot_v1"

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
        val prefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        val raw = prefs.getString(SNAPSHOT_KEY, null)

        var eligibleTotal = 0
        var pendingTotal = 0
        var allDone = false
        val pending = ArrayList<JSONObject>()

        if (!raw.isNullOrBlank()) {
          try {
            val obj = JSONObject(raw)
            eligibleTotal = obj.optInt("eligibleTotal", 0)
            pendingTotal = obj.optInt("pendingTotal", 0)
            allDone = obj.optBoolean("allDone", false)
            val arr = obj.optJSONArray("pending")
            if (arr != null) {
              for (i in 0 until arr.length()) {
                val it = arr.optJSONObject(i) ?: continue
                pending.add(it)
              }
            }
          } catch (_: Throwable) {}
        }

        views.setTextViewText(R.id.header_text, "Today")

        val showAllDone = allDone || (eligibleTotal > 0 && pendingTotal == 0)
        views.setViewVisibility(R.id.all_done_container, if (showAllDone) View.VISIBLE else View.GONE)
        views.setViewVisibility(R.id.rows_container, if (showAllDone) View.GONE else View.VISIBLE)

        if (showAllDone) {
          views.setTextViewText(R.id.all_done_text, "All done \uD83D\uDD25")
        } else if (eligibleTotal <= 0) {
          views.setTextViewText(R.id.all_done_text, "No habits today")
          views.setViewVisibility(R.id.all_done_container, View.VISIBLE)
          views.setViewVisibility(R.id.rows_container, View.GONE)
        }

        bindRow(context, views, R.id.row1, R.id.cb1, R.id.text1, pending.getOrNull(0))
        bindRow(context, views, R.id.row2, R.id.cb2, R.id.text2, pending.getOrNull(1))
        bindRow(context, views, R.id.row3, R.id.cb3, R.id.text3, pending.getOrNull(2))
      } catch (_: Throwable) {
        views.setTextViewText(R.id.header_text, "Open app to load habits")
        views.setViewVisibility(R.id.all_done_container, View.GONE)
        views.setViewVisibility(R.id.rows_container, View.GONE)
      }
      appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun bindRow(
      context: Context,
      views: RemoteViews,
      rowId: Int,
      cbId: Int,
      textId: Int,
      item: JSONObject?,
    ) {
      if (item == null) {
        views.setViewVisibility(rowId, View.GONE)
        return
      }
      val habitId = item.optString("habitId", "")
      val name = item.optString("name", "")
      if (habitId.isBlank()) {
        views.setViewVisibility(rowId, View.GONE)
        return
      }

      views.setViewVisibility(rowId, View.VISIBLE)
      views.setTextViewText(textId, name)
      views.setBoolean(cbId, "setChecked", false)

      val uri = Uri.parse(
        "dvb://widget/toggle?habitId=${Uri.encode(habitId)}&t=${System.currentTimeMillis()}"
      )
      val intent = Intent(Intent.ACTION_VIEW, uri).apply {
        setPackage(context.packageName)
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
      }
      val requestCode = habitId.hashCode()
      val pi = PendingIntent.getActivity(
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
