import WidgetKit
import SwiftUI

private let appGroupId = "group.habitseeding"
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
  @Environment(\.widgetFamily) private var family
  let entry: HabitProgressEntry

  var body: some View {
    let isSmall = family == .systemSmall
    let maxVisibleRows = isSmall ? 1 : 3
    let snap = entry.snapshot
    let pending = snap?.pending ?? []
    let eligibleTotal = snap?.eligibleTotal ?? 0
    let pendingTotal = snap?.pendingTotal ?? pending.count
    let allDone = (snap?.allDone ?? false) || (eligibleTotal > 0 && pendingTotal == 0)
    let doneCount = max(0, eligibleTotal - pendingTotal)
    let shownPendingCount = min(maxVisibleRows, pending.count)
    let extraCount = max(0, pendingTotal - shownPendingCount)

    VStack(alignment: .leading, spacing: isSmall ? 6 : 10) {
      HStack(alignment: .center) {
        Text("Today")
          .font(isSmall ? .subheadline.weight(.semibold) : .headline.weight(.semibold))
          .foregroundStyle(WidgetPalette.forestDeep)
          .lineLimit(1)
          .layoutPriority(1)
        Spacer(minLength: 8)
        if eligibleTotal > 0 {
          Text("\(pendingTotal) left")
            .font(.caption.weight(.semibold))
            .foregroundStyle(WidgetPalette.honeyText)
            .lineLimit(1)
        }
      }

      if eligibleTotal > 0 {
        Text("\(doneCount) of \(eligibleTotal) done")
          .font(.caption2)
          .foregroundStyle(WidgetPalette.secondaryText)
          .lineLimit(1)
      }

      if allDone {
        HStack(spacing: 8) {
          Image(systemName: "checkmark.circle.fill")
            .font(.subheadline)
            .foregroundStyle(WidgetPalette.sproutGreen)
          Text("All done for today")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(WidgetPalette.forestDeep)
        }
      } else if eligibleTotal <= 0 {
        HStack(spacing: 8) {
          Image(systemName: "leaf")
            .font(.subheadline)
            .foregroundStyle(WidgetPalette.sproutGreen)
          Text("No habits scheduled today")
            .font(.subheadline)
            .foregroundStyle(WidgetPalette.forestDeep)
        }
      } else {
        ForEach(pending.prefix(maxVisibleRows)) { it in
          HabitRow(item: it)
        }
        if extraCount > 0 {
          Text("+\(extraCount) more")
            .font(.caption.weight(.semibold))
            .foregroundStyle(WidgetPalette.secondaryText)
            .padding(.top, 2)
        }
      }

      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding(isSmall ? 10 : 14)
    .applyWidgetBackground()
  }
}

struct HabitRow: View {
  let item: HabitProgressSnapshot.PendingItem

  @ViewBuilder
  private var rowContent: some View {
    HStack(spacing: 8) {
      Image(systemName: "circle")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(WidgetPalette.honeyText)
      Text(item.name)
        .font(.subheadline)
        .foregroundStyle(WidgetPalette.forestDeep)
        .lineLimit(1)
      Spacer(minLength: 0)
    }
    .padding(.vertical, 2)
  }

  var body: some View {
    if #available(iOS 17.0, *) {
      Button(intent: ToggleHabitIntent(habitId: item.habitId)) {
        rowContent
      }
      .buttonStyle(.plain)
    } else {
      let url = URL(string: "dvb://widget/toggle?habitId=\(item.habitId)&t=\(Int(Date().timeIntervalSince1970*1000))")!
      Link(destination: url) {
        rowContent
      }
    }
  }
}

private enum WidgetPalette {
  static let mistBackground = Color(red: 246 / 255, green: 244 / 255, blue: 239 / 255)
  static let skyTopTint = Color(red: 234 / 255, green: 242 / 255, blue: 234 / 255)
  static let forestDeep = Color(red: 59 / 255, green: 45 / 255, blue: 32 / 255)
  static let sproutGreen = Color(red: 74 / 255, green: 122 / 255, blue: 90 / 255)
  static let honeyText = Color(red: 122 / 255, green: 85 / 255, blue: 32 / 255)
  static let secondaryText = Color(red: 92 / 255, green: 78 / 255, blue: 64 / 255)
}

private extension View {
  @ViewBuilder
  func applyWidgetBackground() -> some View {
    if #available(iOS 17.0, *) {
      self.containerBackground(
        LinearGradient(
          colors: [WidgetPalette.skyTopTint, WidgetPalette.mistBackground],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        ),
        for: .widget
      )
    } else {
      self.background(
        LinearGradient(
          colors: [WidgetPalette.skyTopTint, WidgetPalette.mistBackground],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
    }
  }
}
