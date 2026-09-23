import ActivityKit
import PaceKit
import SwiftUI
import WidgetKit

// Placeholder so the extension builds. M3 replaces this with the real Live Activity.
struct PaceActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var deltaSec: Double
    }
    var destinationName: String
}

struct PaceLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PaceActivityAttributes.self) { context in
            Text(context.attributes.destinationName)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) { Text(context.attributes.destinationName) }
            } compactLeading: {
                Text("±")
            } compactTrailing: {
                Text("0:00")
            } minimal: {
                Text("±")
            }
        }
    }
}

@main
struct PaceActivityBundle: WidgetBundle {
    var body: some Widget {
        PaceLiveActivity()
    }
}
