import PaceKit
import SwiftUI
import WidgetKit

// Placeholder so the extension builds. M5 replaces this with the real complication.
struct PaceEntry: TimelineEntry {
    let date: Date
}

struct PaceProvider: TimelineProvider {
    func placeholder(in context: Context) -> PaceEntry { PaceEntry(date: .now) }

    func getSnapshot(in context: Context, completion: @escaping (PaceEntry) -> Void) {
        completion(PaceEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PaceEntry>) -> Void) {
        completion(Timeline(entries: [PaceEntry(date: .now)], policy: .never))
    }
}

struct PaceComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PaceComplication", provider: PaceProvider()) { _ in
            Text("0:00")
        }
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct PaceComplicationBundle: WidgetBundle {
    var body: some Widget {
        PaceComplication()
    }
}
