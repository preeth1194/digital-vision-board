package com.example.digital_vision_board

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

      val prefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
      val raw = prefs.getString(SNAPSHOT_KEY, null)

      var boardId = ""
      var boardTitle = "Today"
      var eligibleTotal = 0
      var pendingTotal = 0
      var allDone = false
      val pending = ArrayList<JSONObject>()
      val timerStates = HashMap<String, JSONObject>()

      if (!raw.isNullOrBlank()) {
        try {
          val obj = JSONObject(raw)
          boardId = obj.optString("boardId", "")
          boardTitle = obj.optString("boardTitle", "Today")
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
          // Load timer states for song-based habits
          val timerStatesArr = obj.optJSONArray("timerStates")
          if (timerStatesArr != null) {
            for (i in 0 until timerStatesArr.length()) {
              val timerState = timerStatesArr.optJSONObject(i) ?: continue
              val habitId = timerState.optString("habitId", "")
              if (habitId.isNotBlank()) {
                timerStates[habitId] = timerState
              }
            }
          }
        } catch (_: Throwable) {
          // ignore
        }
      }

      views.setTextViewText(R.id.header_text, boardTitle)

      val showAllDone = allDone || (eligibleTotal > 0 && pendingTotal == 0)
      views.setViewVisibility(R.id.all_done_container, if (showAllDone) View.VISIBLE else View.GONE)
      views.setViewVisibility(R.id.rows_container, if (showAllDone) View.GONE else View.VISIBLE)

      if (showAllDone) {
        views.setTextViewText(R.id.all_done_text, "All done 🔥")
      } else if (eligibleTotal <= 0) {
        views.setTextViewText(R.id.all_done_text, "No habits today")
        views.setViewVisibility(R.id.all_done_container, View.VISIBLE)
        views.setViewVisibility(R.id.rows_container, View.GONE)
      }

      bindRow(
        context = context,
        views = views,
        rowId = R.id.row1,
        cbId = R.id.cb1,
        textId = R.id.text1,
        item = pending.getOrNull(0),
        boardId = boardId,
        timerState = timerStates[pending.getOrNull(0)?.optString("habitId", "")],
      )
      bindRow(
        context = context,
        views = views,
        rowId = R.id.row2,
        cbId = R.id.cb2,
        textId = R.id.text2,
        item = pending.getOrNull(1),
        boardId = boardId,
        timerState = timerStates[pending.getOrNull(1)?.optString("habitId", "")],
      )
      bindRow(
        context = context,
        views = views,
        rowId = R.id.row3,
        cbId = R.id.cb3,
        textId = R.id.text3,
        item = pending.getOrNull(2),
        boardId = boardId,
        timerState = timerStates[pending.getOrNull(2)?.optString("habitId", "")],
      )

      appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun bindRow(
      context: Context,
      views: RemoteViews,
      rowId: Int,
      cbId: Int,
      textId: Int,
      item: JSONObject?,
      boardId: String,
      timerState: JSONObject? = null,
    ) {
      if (item == null) {
        views.setViewVisibility(rowId, View.GONE)
        return
      }
      val componentId = item.optString("componentId", "")
      val habitId = item.optString("habitId", "")
      val name = item.optString("name", "")
      if (boardId.isBlank() || componentId.isBlank() || habitId.isBlank()) {
        views.setViewVisibility(rowId, View.GONE)
        return
      }

      views.setViewVisibility(rowId, View.VISIBLE)
      
      // Display habit name with timer info if available
      val displayText = if (timerState != null) {
        val songsRemaining = timerState.optInt("songsRemaining", 0)
        val totalSongs = timerState.optInt("totalSongs", 0)
        val currentSong = timerState.optString("currentSongTitle", "")
        if (currentSong.isNotBlank()) {
          "$name ($songsRemaining/$totalSongs) - $currentSong"
        } else {
          "$name ($songsRemaining/$totalSongs songs)"
        }
      } else {
        name
      }
      views.setTextViewText(textId, displayText)
      views.setBoolean(cbId, "setChecked", false)

      val uri = Uri.parse(
        "dvb://widget/toggle?boardId=${Uri.encode(boardId)}&componentId=${Uri.encode(componentId)}&habitId=${Uri.encode(habitId)}&t=${System.currentTimeMillis()}"
      )
      val intent = Intent(Intent.ACTION_VIEW, uri).apply {
        // Ensure it resolves to this app.
        setPackage(context.packageName)
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
      }
      val requestCode = (boardId + ":" + componentId + ":" + habitId).hashCode()
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

