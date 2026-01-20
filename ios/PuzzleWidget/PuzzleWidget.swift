import WidgetKit
import SwiftUI

private let appGroupId = "group.digital_vision_board"
private let snapshotKey = "puzzle_widget_snapshot_v1"

struct PuzzleEntry: TimelineEntry {
  let date: Date
  let snapshot: PuzzleSnapshot?
}

struct PuzzleSnapshot: Codable {
  let v: Int?
  let generatedAtMs: Int?
  let imagePath: String?
  let piecePositions: [Int]?
  let positionPieces: [Int]?
  let isCompleted: Bool?
  let goalTitle: String?
}

struct PuzzleProvider: TimelineProvider {
  func placeholder(in context: Context) -> PuzzleEntry {
    PuzzleEntry(date: Date(), snapshot: nil)
  }

  func getSnapshot(in context: Context, completion: @escaping (PuzzleEntry) -> Void) {
    completion(PuzzleEntry(date: Date(), snapshot: loadSnapshot()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<PuzzleEntry>) -> Void) {
    let entry = PuzzleEntry(date: Date(), snapshot: loadSnapshot())
    // No periodic refresh; app will reload timelines when snapshot changes.
    completion(Timeline(entries: [entry], policy: .never))
  }

  private func loadSnapshot() -> PuzzleSnapshot? {
    guard let ud = UserDefaults(suiteName: appGroupId) else { return nil }
    guard let raw = ud.string(forKey: snapshotKey) else { return nil }
    guard let data = raw.data(using: .utf8) else { return nil }
    return try? JSONDecoder().decode(PuzzleSnapshot.self, from: data)
  }
}

struct PuzzleWidget: Widget {
  let kind: String = "PuzzleWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: PuzzleProvider()) { entry in
      PuzzleWidgetView(entry: entry)
    }
    .configurationDisplayName("Puzzle Challenge")
    .description("Solve puzzles from your goal images directly from your home screen.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct PuzzleWidgetView: View {
  let entry: PuzzleEntry

  var body: some View {
    let snap = entry.snapshot
    let imagePath = snap?.imagePath ?? ""
    let isCompleted = snap?.isCompleted ?? false
    let goalTitle = snap?.goalTitle
    let piecePositions = snap?.piecePositions ?? []

    VStack(alignment: .leading, spacing: 8) {
      Text("Puzzle Challenge")
        .font(.headline)
        .lineLimit(1)

      if imagePath.isEmpty {
        Text("No puzzle available")
          .font(.subheadline)
          .foregroundColor(.secondary)
      } else if isCompleted {
        // Show completion state
        VStack(alignment: .leading, spacing: 4) {
          Image(systemName: "party.popper.fill")
            .foregroundColor(.yellow)
            .font(.title2)
          
          let goalMessage = (goalTitle?.isEmpty == false)
            ? "You are 1 step closer in reaching your goal: \(goalTitle!)"
            : "You are 1 step closer in reaching your goal!"
          
          Text(goalMessage)
            .font(.subheadline)
            .lineLimit(3)
            .foregroundColor(.primary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
      } else {
        // Show puzzle progress
        let correctPieces = piecePositions.enumerated().filter { $0.element == $0.offset }.count
        let totalPieces = piecePositions.isEmpty ? 16 : piecePositions.count
        
        VStack(alignment: .leading, spacing: 4) {
          Text("Progress: \(correctPieces)/\(totalPieces)")
            .font(.subheadline)
            .foregroundColor(.primary)
          
          Text("Tap to solve puzzle")
            .font(.caption)
            .foregroundColor(.secondary)
            .italic()
        }
      }

      Spacer(minLength: 0)
    }
    .padding()
    .applyWidgetBackground()
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
