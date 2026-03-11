import Flutter
import UIKit
#if canImport(WidgetKit)
import WidgetKit
#endif
import MediaPlayer

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let channelName = "dvb/habit_progress_widget"
  private let snapshotKey = "habit_progress_widget_snapshot_v1"
  private let actionQueueKey = "habit_progress_widget_action_queue_v1"
  private var habitProgressChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    if let controller = window?.rootViewController as? FlutterViewController {
      _registerHabitProgressChannel(messenger: controller.binaryMessenger)
    }
    return result
  }

  private func _registerHabitProgressChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    habitProgressChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      switch call.method {
      case "updateWidgets":
        #if canImport(WidgetKit)
        if #available(iOS 14.0, *) {
          WidgetCenter.shared.reloadAllTimelines()
        }
        #endif
        result(nil)
      case "writeSnapshotToAppGroup":
        guard
          let args = call.arguments as? [String: Any],
          let snapshot = args["snapshot"] as? String
        else {
          result(nil)
          return
        }
        let groupId = (args["iosAppGroupId"] as? String) ?? "group.habitseeding"
        let ud = UserDefaults(suiteName: groupId)
        ud?.set(snapshot, forKey: self.snapshotKey)
        ud?.synchronize()
        #if canImport(WidgetKit)
        if #available(iOS 14.0, *) {
          WidgetCenter.shared.reloadAllTimelines()
        }
        #endif
        result(nil)
      case "readAndClearQueuedWidgetActions":
        let groupId: String
        if let args = call.arguments as? [String: Any], let g = args["iosAppGroupId"] as? String {
          groupId = g
        } else {
          groupId = "group.habitseeding"
        }
        let ud = UserDefaults(suiteName: groupId)
        let raw = ud?.array(forKey: self.actionQueueKey) as? [[String: Any]] ?? []
        ud?.set([], forKey: self.actionQueueKey)
        ud?.synchronize()
        let mapped: [[String: String]] = raw.map { item in
          var out: [String: String] = [:]
          for (k, v) in item {
            out[String(describing: k)] = String(describing: v)
          }
          return out
        }
        result(mapped)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
