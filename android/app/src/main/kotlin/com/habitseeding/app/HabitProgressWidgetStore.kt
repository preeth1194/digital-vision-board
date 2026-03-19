package com.habitseeding.app

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

object HabitProgressWidgetStore {
  private const val FLUTTER_PREFS = "FlutterSharedPreferences"
  const val SNAPSHOT_KEY = "flutter.habit_progress_widget_snapshot_v1"
  private const val ACTION_QUEUE_KEY = "habit_progress_widget_action_queue_v1"
  private const val MAX_VISIBLE_PENDING = 3
  private val lock = Any()

  private fun prefs(context: Context) =
    context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)

  fun readSnapshotJson(context: Context): String? = prefs(context).getString(SNAPSHOT_KEY, null)

  fun writeSnapshotJson(context: Context, snapshotJson: String) {
    prefs(context).edit().putString(SNAPSHOT_KEY, snapshotJson).apply()
  }

  fun enqueueToggleAction(context: Context, habitId: String, ts: Long = System.currentTimeMillis()) {
    synchronized(lock) {
      val p = prefs(context)
      val queue = parseQueue(p.getString(ACTION_QUEUE_KEY, null))
      queue.put(
        JSONObject().apply {
          put("kind", "toggle")
          put("habitId", habitId)
          put("ts", ts)
        },
      )
      p.edit().putString(ACTION_QUEUE_KEY, queue.toString()).apply()
    }
  }

  fun readAndClearQueuedActions(context: Context): List<Map<String, String>> {
    synchronized(lock) {
      val p = prefs(context)
      val queue = parseQueue(p.getString(ACTION_QUEUE_KEY, null))
      p.edit().remove(ACTION_QUEUE_KEY).apply()
      val out = ArrayList<Map<String, String>>(queue.length())
      for (i in 0 until queue.length()) {
        val item = queue.optJSONObject(i) ?: continue
        val kind = item.optString("kind", "").trim()
        val habitId = item.optString("habitId", "").trim()
        val ts = item.optLong("ts", 0L).toString()
        if (kind.isBlank() || habitId.isBlank()) continue
        out.add(
          mapOf(
            "kind" to kind,
            "habitId" to habitId,
            "ts" to ts,
          ),
        )
      }
      return out
    }
  }

  fun applyOptimisticToggleToSnapshot(context: Context, habitId: String): Boolean {
    synchronized(lock) {
      val p = prefs(context)
      val raw = p.getString(SNAPSHOT_KEY, null) ?: return false
      val snap = try {
        JSONObject(raw)
      } catch (_: Throwable) {
        return false
      }

      val sourcePending = when {
        snap.has("pendingAll") -> snap.optJSONArray("pendingAll") ?: JSONArray()
        snap.has("pending") -> snap.optJSONArray("pending") ?: JSONArray()
        else -> JSONArray()
      }
      if (sourcePending.length() == 0) return false

      val updatedPendingAll = JSONArray()
      for (i in 0 until sourcePending.length()) {
        val item = sourcePending.optJSONObject(i) ?: continue
        val currentId = item.optString("habitId", "")
        if (currentId != habitId) updatedPendingAll.put(item)
      }
      if (updatedPendingAll.length() == sourcePending.length()) return false

      val updatedPending = JSONArray()
      val maxPending = minOf(updatedPendingAll.length(), MAX_VISIBLE_PENDING)
      for (i in 0 until maxPending) {
        updatedPending.put(updatedPendingAll.optJSONObject(i))
      }

      val pendingTotal = updatedPendingAll.length()
      val eligibleTotal = snap.optInt("eligibleTotal", 0)

      snap.put("pendingAll", updatedPendingAll)
      snap.put("pending", updatedPending)
      snap.put("pendingTotal", pendingTotal)
      snap.put("allDone", eligibleTotal > 0 && pendingTotal == 0)
      snap.put("generatedAtMs", System.currentTimeMillis())

      p.edit().putString(SNAPSHOT_KEY, snap.toString()).apply()
      return true
    }
  }

  private fun parseQueue(raw: String?): JSONArray {
    if (raw.isNullOrBlank()) return JSONArray()
    return try {
      JSONArray(raw)
    } catch (_: Throwable) {
      JSONArray()
    }
  }
}
