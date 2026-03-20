import AppIntents
import WidgetKit

private let appGroupId = "group.habitseeding"
private let snapshotKey = "habit_progress_widget_snapshot_v1"
private let actionQueueKey = "habit_progress_widget_action_queue_v1"
private let widgetKind = "HabitProgressWidget"
private let maxVisiblePending = 3

@available(iOS 17.0, *)
struct ToggleHabitIntent: AppIntent {
  static var title: LocalizedStringResource = "Toggle habit"

  @Parameter(title: "Habit ID") var habitId: String

  init() {}

  init(habitId: String) {
    self.habitId = habitId
  }

  func perform() async throws -> some IntentResult {
    guard let ud = UserDefaults(suiteName: appGroupId) else {
      return .result()
    }

    var queue = ud.array(forKey: actionQueueKey) as? [[String: Any]] ?? []
    queue.append([
      "kind": "toggle",
      "habitId": habitId,
      "ts": Int(Date().timeIntervalSince1970 * 1000),
    ])
    ud.set(queue, forKey: actionQueueKey)

    if let raw = ud.string(forKey: snapshotKey),
       let data = raw.data(using: .utf8),
       let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
      var next = json
      let sourcePending =
        (next["pendingAll"] as? [[String: Any]]) ??
        (next["pending"] as? [[String: Any]]) ??
        []
      let updatedPendingAll = sourcePending.filter { it in
        let h = (it["habitId"] as? String) ?? ""
        return h != habitId
      }

      if updatedPendingAll.count != sourcePending.count {
        next["pendingAll"] = updatedPendingAll
        next["pending"] = Array(updatedPendingAll.prefix(maxVisiblePending))
        let pendingTotal = updatedPendingAll.count
        next["pendingTotal"] = pendingTotal
        let eligibleTotal = next["eligibleTotal"] as? Int ?? 0
        next["allDone"] = (eligibleTotal > 0 && pendingTotal == 0)
        next["generatedAtMs"] = Int(Date().timeIntervalSince1970 * 1000)
        if let nextData = try? JSONSerialization.data(withJSONObject: next),
           let nextStr = String(data: nextData, encoding: .utf8) {
          ud.set(nextStr, forKey: snapshotKey)
        }
      }
    }

    WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    return .result()
  }
}
