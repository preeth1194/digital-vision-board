package com.digitalvisionboard.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import java.io.File

class PuzzleAppWidget : AppWidgetProvider() {

  override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
    for (appWidgetId in appWidgetIds) {
      updateAppWidget(context, appWidgetManager, appWidgetId)
    }
  }

  companion object {
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    private const val SNAPSHOT_KEY = "flutter.puzzle_widget_snapshot_v1"
    private val TILE_VIEW_IDS = listOf(
      R.id.tile_0, R.id.tile_1, R.id.tile_2, R.id.tile_3,
      R.id.tile_4, R.id.tile_5, R.id.tile_6, R.id.tile_7,
      R.id.tile_8, R.id.tile_9, R.id.tile_10, R.id.tile_11,
      R.id.tile_12, R.id.tile_13, R.id.tile_14, R.id.tile_15,
    )

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
      var positionPieces: List<Int> = emptyList()

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
          val positionPiecesArr = obj.optJSONArray("positionPieces")
          if (positionPiecesArr != null) {
            positionPieces = (0 until positionPiecesArr.length()).map { positionPiecesArr.optInt(it, -1) }
          }
        } catch (_: Throwable) {
          // ignore
        }
      }

      // Set title
      views.setTextViewText(R.id.puzzle_title, "Puzzle Challenge")

      if (imagePath.isBlank()) {
        // No puzzle available
        views.setViewVisibility(R.id.puzzle_title, View.VISIBLE)
        views.setTextViewText(R.id.puzzle_status, "No puzzle available")
        views.setViewVisibility(R.id.puzzle_completion_container, View.GONE)
        views.setViewVisibility(R.id.puzzle_grid_container, View.GONE)
        views.setViewVisibility(R.id.puzzle_status, View.VISIBLE)
      } else if (isCompleted) {
        // Show completion state
        views.setViewVisibility(R.id.puzzle_title, View.VISIBLE)
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
        // Show puzzle grid (fills widget; hide title so grid dominates)
        views.setViewVisibility(R.id.puzzle_title, View.GONE)
        views.setViewVisibility(R.id.puzzle_completion_container, View.GONE)
        views.setViewVisibility(R.id.puzzle_grid_container, View.VISIBLE)
        views.setViewVisibility(R.id.puzzle_status, View.GONE)

        val tilesSet = try {
          loadAndSetPuzzleTiles(context, views, imagePath, positionPieces)
        } catch (_: Throwable) {
          false
        }
        views.setViewVisibility(R.id.puzzle_tiles_grid, if (tilesSet) View.VISIBLE else View.GONE)
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

    /**
     * Load puzzle image, slice into 16 tiles, and set each tile ImageView from positionPieces.
     * Returns true if tiles were set, false on any failure (caller should hide puzzle_tiles_grid).
     */
    private fun loadAndSetPuzzleTiles(
      context: Context,
      views: RemoteViews,
      imagePath: String,
      positionPieces: List<Int>,
    ): Boolean {
      if (imagePath.isBlank()) return false
      val file = resolveImageFile(context, imagePath) ?: return false
      val source = BitmapFactory.decodeFile(file.absolutePath) ?: return false
      if (source.width < 4 || source.height < 4) {
        source.recycle()
        return false
      }
      val tileW = source.width / 4
      val tileH = source.height / 4
      val tiles = (0 until 16).map { i ->
        val col = i % 4
        val row = i / 4
        Bitmap.createBitmap(source, col * tileW, row * tileH, tileW, tileH)
      }
      source.recycle()
      val posToPiece = if (positionPieces.size >= 16) {
        positionPieces
      } else {
        (0 until 16).map { it }
      }
      for (pos in 0 until 16) {
        val pieceIndex = posToPiece.getOrElse(pos) { pos }.coerceIn(0, 15)
        views.setImageViewBitmap(TILE_VIEW_IDS[pos], tiles[pieceIndex])
      }
      return true
    }

    private fun resolveImageFile(context: Context, imagePath: String): File? {
      val f = File(imagePath)
      if (f.exists() && f.canRead()) return f
      val withFilesDir = File(context.filesDir, imagePath)
      if (withFilesDir.exists() && withFilesDir.canRead()) return withFilesDir
      val relative = imagePath.trimStart('/', '\\')
      if (relative != imagePath) {
        val rel = File(context.filesDir, relative)
        if (rel.exists() && rel.canRead()) return rel
      }
      return null
    }
  }
}
