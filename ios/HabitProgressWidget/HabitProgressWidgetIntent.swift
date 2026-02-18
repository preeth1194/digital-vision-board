import AppIntents
import WidgetKit

private let appGroupId = "group.seerohabitseeding"
private let snapshotKey = "habit_progress_widget_snapshot_v1"
private let actionQueueKey = "habit_progress_widget_action_queue_v1"

@available(iOS 17.0, *)
struct ToggleHabitIntent: AppIntent {
  static var title: LocalizedStringResource = "Toggle habit"

  @Parameter(title: "Board ID") var boardId: String
  @Parameter(title: "Component ID") var componentId: String
  @Parameter(title: "Habit ID") var habitId: String

  init() {}

  init(boardId: String, componentId: String, habitId: String) {
    self.boardId = boardId
    self.componentId = componentId
    self.habitId = habitId
  }

  func perform() async throws -> some IntentResult {
    guard let ud = UserDefaults(suiteName: appGroupId) else {
      return .result()
    }

    // 1) Enqueue an action for the app to apply on next start/resume.
    var queue = ud.array(forKey: actionQueueKey) as? [[String: Any]] ?? []
    queue.append([
      "kind": "toggle",
      "boardId": boardId,
      "componentId": componentId,
      "habitId": habitId,
      "ts": Int(Date().timeIntervalSince1970 * 1000),
    ])
    ud.set(queue, forKey: actionQueueKey)

    // 2) Optimistically update the snapshot so the widget UI advances immediately.
    if let raw = ud.string(forKey: snapshotKey),
       let data = raw.data(using: .utf8),
       let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
      var next = json
      if var pending = next["pending"] as? [[String: Any]] {
        let before = pending.count
        pending.removeAll { it in
          let c = (it["componentId"] as? String) ?? ""
          let h = (it["habitId"] as? String) ?? ""
          return c == componentId && h == habitId
        }
        if pending.count != before {
          next["pending"] = pending
          let pendingTotal = max(0, (next["pendingTotal"] as? Int ?? pending.count) - 1)
          next["pendingTotal"] = pendingTotal
          let eligibleTotal = next["eligibleTotal"] as? Int ?? 0
          next["allDone"] = (eligibleTotal > 0 && pendingTotal == 0)
          if let nextData = try? JSONSerialization.data(withJSONObject: next),
             let nextStr = String(data: nextData, encoding: .utf8) {
            ud.set(nextStr, forKey: snapshotKey)
          }
        }
      }
    }

    WidgetCenter.shared.reloadAllTimelines()
    return .result()
  }
}

