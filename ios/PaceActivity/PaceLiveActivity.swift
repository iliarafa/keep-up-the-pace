import ActivityKit
import PaceKit
import SwiftUI
import WidgetKit

/// The walk on the lock screen and in the Dynamic Island (spec §1): destination, ±m:ss in the pace
/// colour, distance left and arrive-by.
struct PaceLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PaceActivityAttributes.self) { context in
            PaceLockScreenView(attributes: context.attributes, state: context.state, isStale: context.isStale)
                .activityBackgroundTint(Theme.background)
                .activitySystemActionForegroundColor(Theme.foreground)
        } dynamicIsland: { context in
            let readout = PaceReadout(context.state)
            let distance = Format.distance(meters: context.state.remainingM, units: context.state.units)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(readout.text)
                            .font(.system(.title, design: .monospaced).weight(.medium))
                            .foregroundStyle(readout.color)
                        Text(readout.label)
                            .font(.caption2.weight(.semibold))
                            .tracking(1.2)
                            .foregroundStyle(readout.color)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(context.state.arrived ? "Arrived" : "\(distance) left")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(Theme.foreground)
                        Text("by \(Format.clock(context.attributes.arriveBy))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Theme.muted)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.locationPaused ? "Location paused" : context.attributes.destinationName)
                        .font(.subheadline)
                        .foregroundStyle(context.state.locationPaused ? Theme.late : Theme.muted)
                        .lineLimit(1)
                }
            } compactLeading: {
                Text(readout.text)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(readout.color)
            } compactTrailing: {
                Text(distance)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.foreground)
            } minimal: {
                Text(readout.text)
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(readout.color)
            }
            .keylineTint(readout.color)
        }
    }
}

/// The ±m:ss as the Live Activity shows it, with its label and pace colour.
struct PaceReadout {
    let text: String
    let label: String
    let color: Color

    init(_ state: PaceActivityState) {
        let delta = Format.delta(sec: state.deltaSec)
        text = delta.tone == .ontime ? "0:00" : delta.sign + delta.clock
        label = (state.arrived ? "Arrived \(delta.label)" : delta.label).uppercased()
        color = Theme.paceColor(delta.tone)
    }
}

struct PaceLockScreenView: View {
    let attributes: PaceActivityAttributes
    let state: PaceActivityState
    let isStale: Bool

    var body: some View {
        let readout = PaceReadout(state)
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(attributes.destinationName)
                    .font(.headline)
                    .foregroundStyle(Theme.foreground)
                    .lineLimit(1)
                Text(detail)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                if let notice {
                    Text(notice)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.late)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(readout.text)
                    .font(.system(size: 40, weight: .medium, design: .monospaced))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundStyle(readout.color)
                Text(readout.label)
                    .font(.caption2.weight(.semibold))
                    .tracking(1.5)
                    .foregroundStyle(readout.color)
            }
        }
        .opacity(isStale && !state.arrived ? 0.55 : 1)
        .padding(16)
    }

    private var detail: String {
        let arriveBy = Format.clock(attributes.arriveBy)
        if state.arrived { return "Target \(arriveBy)" }
        return "\(Format.distance(meters: state.remainingM, units: state.units)) left · by \(arriveBy)"
    }

    private var notice: String? {
        if state.locationPaused { return "Location paused" }
        if isStale, !state.arrived { return "Not updating. Open Keep the Pace." }
        return nil
    }
}
