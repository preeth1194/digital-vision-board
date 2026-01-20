import WidgetKit
import SwiftUI

private let appGroupId = "group.digital_vision_board"
private let snapshotKey = "habit_progress_widget_snapshot_v1"

struct HabitProgressEntry: TimelineEntry {
  let date: Date
  let snapshot: HabitProgressSnapshot?
}

struct HabitProgressSnapshot: Codable {
  struct PendingItem: Codable, Identifiable {
    let componentId: String
    let habitId: String
    let name: String
    var id: String { "\(componentId):\(habitId)" }
  }

  struct TimerState: Codable {
    let habitId: String
    let songsRemaining: Int?
    let currentSongTitle: String?
    let totalSongs: Int?
  }

  let v: Int?
  let generatedAtMs: Int?
  let isoDate: String?
  let boardId: String?
  let boardTitle: String?
  let eligibleTotal: Int?
  let pendingTotal: Int?
  let pending: [PendingItem]?
  let allDone: Bool?
  let timerStates: [TimerState]?
}

struct HabitProgressProvider: TimelineProvider {
  func placeholder(in context: Context) -> HabitProgressEntry {
    HabitProgressEntry(date: Date(), snapshot: nil)
  }

  func getSnapshot(in context: Context, completion: @escaping (HabitProgressEntry) -> Void) {
    completion(HabitProgressEntry(date: Date(), snapshot: loadSnapshot()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<HabitProgressEntry>) -> Void) {
    let entry = HabitProgressEntry(date: Date(), snapshot: loadSnapshot())
    // No periodic refresh; app will reload timelines when snapshot changes.
    completion(Timeline(entries: [entry], policy: .never))
  }

  private func loadSnapshot() -> HabitProgressSnapshot? {
    guard let ud = UserDefaults(suiteName: appGroupId) else { return nil }
    guard let raw = ud.string(forKey: snapshotKey) else { return nil }
    guard let data = raw.data(using: .utf8) else { return nil }
    return try? JSONDecoder().decode(HabitProgressSnapshot.self, from: data)
  }
}

struct HabitProgressWidget: Widget {
  let kind: String = "HabitProgressWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: HabitProgressProvider()) { entry in
      HabitProgressWidgetView(entry: entry)
    }
    .configurationDisplayName("Habit Progress")
    .description("Shows up to 3 of today’s pending habits from your default board.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct HabitProgressWidgetView: View {
  let entry: HabitProgressEntry

  var body: some View {
    let snap = entry.snapshot
    let title = (snap?.boardTitle?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
      ? (snap?.boardTitle ?? "Today")
      : "Today"
    let boardId = snap?.boardId ?? ""
    let pending = snap?.pending ?? []
    let eligibleTotal = snap?.eligibleTotal ?? 0
    let pendingTotal = snap?.pendingTotal ?? pending.count
    let allDone = (snap?.allDone ?? false) || (eligibleTotal > 0 && pendingTotal == 0)

    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.headline)
        .lineLimit(1)

      if allDone {
        Text("All done 🔥")
          .font(.body)
      } else if eligibleTotal <= 0 {
        Text("No habits today")
          .font(.body)
      } else {
        ForEach(pending.prefix(3)) { it in
          let timerState = snap?.timerStates?.first(where: { $0.habitId == it.habitId })
          HabitRow(boardId: boardId, item: it, timerState: timerState)
        }
      }

      Spacer(minLength: 0)
    }
    .padding()
    .applyWidgetBackground()
  }
}

struct HabitRow: View {
  let boardId: String
  let item: HabitProgressSnapshot.PendingItem
  let timerState: HabitProgressSnapshot.TimerState?

  var body: some View {
    let displayText: String
    if let timer = timerState, let remaining = timer.songsRemaining, let total = timer.totalSongs {
      if let songTitle = timer.currentSongTitle, !songTitle.isEmpty {
        displayText = "\(item.name) (\(remaining)/\(total)) - \(songTitle)"
      } else {
        displayText = "\(item.name) (\(remaining)/\(total) songs)"
      }
    } else {
      displayText = item.name
    }

    if #available(iOS 17.0, *) {
      Button(intent: ToggleHabitIntent(boardId: boardId, componentId: item.componentId, habitId: item.habitId)) {
        Label(displayText, systemImage: "circle")
          .labelStyle(.titleAndIcon)
          .font(.subheadline)
          .lineLimit(2)
      }
      .buttonStyle(.plain)
    } else {
      // Fallback: opens the app to apply the toggle.
      let url = URL(string: "dvb://widget/toggle?boardId=\(boardId)&componentId=\(item.componentId)&habitId=\(item.habitId)&t=\(Int(Date().timeIntervalSince1970*1000))")!
      Link(destination: url) {
        Label(displayText, systemImage: "circle")
          .labelStyle(.titleAndIcon)
          .font(.subheadline)
          .lineLimit(2)
      }
    }
  }
}

private extension View {
  @ViewBuilder
  func applyWidgetBackground() -> some View {
    if #available(iOS 17.0, *) {
      self.containerBackground(.background, for: .widget)
    } else {
      self.background(Color(.systemBackground))
    }
  }
}

