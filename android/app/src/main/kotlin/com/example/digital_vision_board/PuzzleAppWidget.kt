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

class PuzzleAppWidget : AppWidgetProvider() {

  override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
    for (appWidgetId in appWidgetIds) {
      updateAppWidget(context, appWidgetManager, appWidgetId)
    }
  }

  companion object {
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    private const val SNAPSHOT_KEY = "flutter.puzzle_widget_snapshot_v1"

    fun updateAll(context: Context) {
      val mgr = AppWidgetManager.getInstance(context)
      val ids = mgr.getAppWidgetIds(ComponentName(context, PuzzleAppWidget::class.java))
      if (ids.isEmpty()) return
      for (id in ids) {
        updateAppWidget(context, mgr, id)
      }
    }

    private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
      val views = RemoteViews(context.packageName, R.layout.puzzle_widget)

      val prefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
      val raw = prefs.getString(SNAPSHOT_KEY, null)

      var imagePath = ""
      var isCompleted = false
      var goalTitle: String? = null
      var piecePositions: List<Int> = emptyList()

      if (!raw.isNullOrBlank()) {
        try {
          val obj = JSONObject(raw)
          imagePath = obj.optString("imagePath", "")
          isCompleted = obj.optBoolean("isCompleted", false)
          goalTitle = obj.optString("goalTitle", null)
          val positionsArr = obj.optJSONArray("piecePositions")
          if (positionsArr != null) {
            piecePositions = (0 until positionsArr.length()).map { positionsArr.optInt(it, -1) }
          }
        } catch (_: Throwable) {
          // ignore
        }
      }

      // Set title
      views.setTextViewText(R.id.puzzle_title, "Puzzle Challenge")

      if (imagePath.isBlank()) {
        // No puzzle available
        views.setTextViewText(R.id.puzzle_status, "No puzzle available")
        views.setViewVisibility(R.id.puzzle_completion_container, View.GONE)
        views.setViewVisibility(R.id.puzzle_grid_container, View.GONE)
        views.setViewVisibility(R.id.puzzle_status, View.VISIBLE)
      } else if (isCompleted) {
        // Show completion state
        views.setViewVisibility(R.id.puzzle_completion_container, View.VISIBLE)
        views.setViewVisibility(R.id.puzzle_grid_container, View.GONE)
        views.setViewVisibility(R.id.puzzle_status, View.GONE)
        
        val goalMessage = if (!goalTitle.isNullOrBlank()) {
          "You are 1 step closer in reaching your goal: $goalTitle"
        } else {
          "You are 1 step closer in reaching your goal!"
        }
        views.setTextViewText(R.id.puzzle_completion_text, goalMessage)
      } else {
        // Show puzzle grid preview
        views.setViewVisibility(R.id.puzzle_completion_container, View.GONE)
        views.setViewVisibility(R.id.puzzle_grid_container, View.VISIBLE)
        views.setViewVisibility(R.id.puzzle_status, View.GONE)
        
        // Show progress text
        val correctPieces = piecePositions.countIndexed { index, pos -> pos == index }
        val totalPieces = if (piecePositions.isNotEmpty()) piecePositions.size else 16
        views.setTextViewText(R.id.puzzle_progress, "Progress: $correctPieces/$totalPieces")
      }

      // Set click intent to open puzzle
      val uri = Uri.parse("dvb://puzzle?t=${System.currentTimeMillis()}")
      val intent = Intent(Intent.ACTION_VIEW, uri).apply {
        setPackage(context.packageName)
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
      }
      val pi = PendingIntent.getActivity(
        context,
        0,
        intent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
      )
      views.setOnClickPendingIntent(R.id.puzzle_container, pi)
      views.setOnClickPendingIntent(R.id.puzzle_title, pi)
      views.setOnClickPendingIntent(R.id.puzzle_completion_container, pi)
      views.setOnClickPendingIntent(R.id.puzzle_grid_container, pi)

      appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun <T> List<T>.countIndexed(predicate: (Int, T) -> Boolean): Int {
      var count = 0
      forEachIndexed { index, element ->
        if (predicate(index, element)) count++
      }
      return count
    }
  }
}
