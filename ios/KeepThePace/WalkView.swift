import PaceKit
import SwiftUI

/// The walk screen, laid out like the web's `WalkView`: heading and speed up top, the big
/// ±m:ss in the pace colour at the bottom.
struct WalkView: View {
    let walk: WalkSession
    let saved: SavedData
    @ScaledMetric(relativeTo: .largeTitle) private var deltaSize: CGFloat = 96

    var body: some View {
        if let engine = walk.engine {
            content(session: engine.session, metrics: walk.metrics)
        }
    }

    private func content(session: Session, metrics: WalkMetrics?) -> some View {
        let units = saved.units
        let delta = Format.delta(sec: metrics?.deltaSec ?? 0)
        let color = Theme.paceColor(delta.tone)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    MetricLabel("Keep the Pace")
                    Text(session.dest.name)
                        .font(.title2.weight(.medium))
                        .foregroundStyle(Theme.foreground)
                        .lineLimit(1)
                    Text("\(Format.distance(meters: metrics?.remainingM ?? session.startDistanceM, units: units)) left · \(Format.clock(session.arriveBy))")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                Button("End") { walk.finish() }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.muted)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityIdentifier("endButton")
            }

            if walk.locationPaused {
                Label("Location paused. Turn location back on to keep tracking.", systemImage: "location.slash")
                    .font(.footnote)
                    .foregroundStyle(Theme.late)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.top, 16)
                    .accessibilityIdentifier("locationPausedBanner")
            }

            MetricLabel("Heading").padding(.top, 32)
            HStack(spacing: 20) {
                CompassView(bearing: metrics?.headingDeg ?? 0)
                    .frame(width: 96, height: 96)
                if let metrics {
                    (Text(Format.heading(metrics.headingDeg))
                        + Text("  \(Geo.cardinal(metrics.headingDeg))").font(.title3).foregroundColor(Theme.muted))
                        .font(.system(.largeTitle, design: .monospaced).weight(.medium))
                        .foregroundStyle(Theme.foreground)
                }
            }
            .padding(.top, 12)

            MetricLabel("Speed").padding(.top, 32)
            let speed = Format.speed(mps: metrics?.speedMps ?? 0, units: units)
            (Text(speed.value) + Text("  \(speed.unit)").font(.title3).foregroundColor(Theme.muted))
                .font(.system(.largeTitle, design: .monospaced).weight(.medium))
                .foregroundStyle(Theme.foreground)
                .padding(.top, 4)

            Spacer(minLength: 24)

            MetricLabel("Delta")
            Text(delta.sign + delta.clock)
                .font(.system(size: deltaSize, weight: .medium, design: .monospaced))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.5), value: delta.tone)
                .accessibilityIdentifier("deltaReadout")
            Text(delta.label.uppercased())
                .font(.subheadline.weight(.medium))
                .tracking(2)
                .foregroundStyle(color)
                .padding(.top, 8)

            HStack {
                Text("Tracking on iPhone")
                Spacer()
                if session.demo { Text("Preview walk") }
            }
            .font(.caption)
            .foregroundStyle(Theme.faint)
            .padding(.top, 24)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.background)
    }
}

/// Compass ring with an arrow pointing at the destination (bearing from north), like the web's.
struct CompassView: View {
    let bearing: Double

    var body: some View {
        ZStack {
            Circle().stroke(Theme.line, lineWidth: 1.5)
            Text("N")
                .font(.caption2)
                .foregroundStyle(Theme.muted)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 4)
            Image(systemName: "location.north.fill")
                .font(.title)
                .foregroundStyle(Theme.foreground)
                .rotationEffect(.degrees(bearing))
        }
        .accessibilityHidden(true)
    }
}
