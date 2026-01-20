package com.example.digital_vision_board

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
    
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dvb/puzzle_widget")
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "updateWidgets" -> {
            PuzzleAppWidget.updateAll(this)
            result.success(null)
          }
          "writeSnapshotToAppGroup" -> {
            // iOS App Group write is handled in AppDelegate.swift
            // For Android, we just update the widget
            PuzzleAppWidget.updateAll(this)
            result.success(null)
          }
          else -> result.notImplemented()
        }
      }
    
    // Register music provider handler (placeholder for Spotify/Apple Music integration)
    MusicProviderHandler().setupMethodChannel(flutterEngine)
  }
}
