package com.habitseeding.app

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dvb/habit_progress_widget")
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "updateWidgets" -> {
            HabitProgressAppWidget.updateAll(this)
            result.success(null)
          }
          "writeSnapshotToAppGroup" -> {
            val snapshot = call.argument<String>("snapshot")
            if (snapshot.isNullOrBlank()) {
              result.success(null)
              return@setMethodCallHandler
            }
            HabitProgressWidgetStore.writeSnapshotJson(this, snapshot)
            result.success(null)
          }
          "readAndClearQueuedWidgetActions" -> {
            result.success(HabitProgressWidgetStore.readAndClearQueuedActions(this))
          }
          else -> result.notImplemented()
        }
      }
  }
}
