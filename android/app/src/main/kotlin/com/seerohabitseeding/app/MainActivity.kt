package com.seerohabitseeding.app

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
          else -> result.notImplemented()
        }
      }
  }
}
