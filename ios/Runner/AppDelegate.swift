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

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Register music provider handler (placeholder for Spotify/Apple Music integration)
    if let registrar = self.registrar(forPlugin: "MusicProviderHandler") {
      MusicProviderHandler.register(with: registrar)
    }

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: channelName, binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else { return }
        switch call.method {
        case "updateWidgets":
          #if canImport(WidgetKit)
          WidgetCenter.shared.reloadAllTimelines()
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
          let groupId = (args["iosAppGroupId"] as? String) ?? "group.digital_vision_board"
          let ud = UserDefaults(suiteName: groupId)
          ud?.set(snapshot, forKey: self.snapshotKey)
          ud?.synchronize()
          #if canImport(WidgetKit)
          WidgetCenter.shared.reloadAllTimelines()
          #endif
          result(nil)
        case "readAndClearQueuedWidgetActions":
          let groupId: String
          if let args = call.arguments as? [String: Any], let g = args["iosAppGroupId"] as? String {
            groupId = g
          } else {
            groupId = "group.digital_vision_board"
          }
          let ud = UserDefaults(suiteName: groupId)
          let raw = ud?.array(forKey: self.actionQueueKey) as? [[String: Any]] ?? []
          ud?.set([], forKey: self.actionQueueKey)
          ud?.synchronize()
          // Flutter expects List<Map<String, String>>.
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

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
