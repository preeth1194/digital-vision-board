import WidgetKit
import SwiftUI

// Note: If you want both widgets in one bundle, remove @main from here
// and create a combined bundle. For now, keeping separate bundles.
struct HabitProgressWidgetBundle: WidgetBundle {
  var body: some Widget {
    HabitProgressWidget()
  }
}

