import WidgetKit
import SwiftUI

private let appGroupId = "group.seerohabitseeding"
private let snapshotKey = "habit_progress_widget_snapshot_v1"

struct HabitProgressEntry: TimelineEntry {
  let date: Date
  let snapshot: HabitProgressSnapshot?
}

struct HabitProgressSnapshot: Codable {
  struct PendingItem: Codable, Identifiable {
    let habitId: String
    let name: String
    var id: String { habitId }

    init(from decoder: Decoder) throws {
      let c = try decoder.container(keyedBy: CodingKeys.self)
      habitId = (try? c.decode(String.self, forKey: .habitId)) ?? ""
      name = (try? c.decode(String.self, forKey: .name)) ?? ""
    }
  }

  let v: Int?
  let generatedAtMs: Int?
  let isoDate: String?
  let eligibleTotal: Int?
  let pendingTotal: Int?
  let pending: [PendingItem]?
  let allDone: Bool?
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
    .configurationDisplayName("Habits")
    .description("Mark today's habits as done right from your home screen.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct HabitProgressWidgetView: View {
  let entry: HabitProgressEntry

  var body: some View {
    let snap = entry.snapshot
    let pending = snap?.pending ?? []
    let eligibleTotal = snap?.eligibleTotal ?? 0
    let pendingTotal = snap?.pendingTotal ?? pending.count
    let allDone = (snap?.allDone ?? false) || (eligibleTotal > 0 && pendingTotal == 0)

    VStack(alignment: .leading, spacing: 8) {
      Text("Today")
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
          HabitRow(item: it)
        }
      }

      Spacer(minLength: 0)
    }
    .padding()
    .applyWidgetBackground()
  }
}

struct HabitRow: View {
  let item: HabitProgressSnapshot.PendingItem

  var body: some View {
    if #available(iOS 17.0, *) {
      Button(intent: ToggleHabitIntent(habitId: item.habitId)) {
        Label(item.name, systemImage: "circle")
          .labelStyle(.titleAndIcon)
          .font(.subheadline)
          .lineLimit(2)
      }
      .buttonStyle(.plain)
    } else {
      let url = URL(string: "dvb://widget/toggle?habitId=\(item.habitId)&t=\(Int(Date().timeIntervalSince1970*1000))")!
      Link(destination: url) {
        Label(item.name, systemImage: "circle")
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
