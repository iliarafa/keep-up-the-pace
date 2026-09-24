import PaceKit
import SwiftUI

/// The result of a walk: how early or late you arrived, target versus actual time, distance
/// walked and duration.
struct ArrivedView: View {
    let walk: WalkSession
    let saved: SavedData
    @ScaledMetric(relativeTo: .largeTitle) private var resultSize: CGFloat = 72

    var body: some View {
        if let engine = walk.engine, let metrics = walk.metrics, let arrivedAt = engine.arrivedAt {
            content(session: engine.session, metrics: metrics, arrivedAt: arrivedAt)
        }
    }

    private func content(session: Session, metrics: WalkMetrics, arrivedAt: Date) -> some View {
        let delta = Format.delta(sec: metrics.deltaSec)
        let color = Theme.paceColor(delta.tone)
        let headline = delta.tone == .ontime ? "Arrived on time" : "Arrived \(delta.clock) \(delta.label)"
        return VStack(alignment: .leading, spacing: 0) {
            MetricLabel("Arrived")
            Text(session.dest.name)
                .font(.title2.weight(.medium))
                .foregroundStyle(Theme.foreground)
                .padding(.top, 4)

            Text(delta.tone == .ontime ? "0:00" : delta.sign + delta.clock)
                .font(.system(size: resultSize, weight: .medium, design: .monospaced))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(color)
                .padding(.top, 32)
            Text(headline)
                .font(.headline)
                .foregroundStyle(color)
                .accessibilityIdentifier("arrivedResult")

            VStack(spacing: 14) {
                row("Target", Format.clock(session.arriveBy))
                row("Arrived", Format.clock(arrivedAt))
                row("Distance", Format.distance(meters: metrics.walkedM, units: saved.units))
                row("Duration", Format.duration(seconds: arrivedAt.timeIntervalSince(session.startAt)))
            }
            .padding(.top, 32)

            Spacer()

            if !saved.favorites.contains(session.dest) {
                Button {
                    saved.favorites.add(session.dest)
                } label: {
                    Label("Favorite this place", systemImage: "star")
                }
                .buttonStyle(OutlineButtonStyle())
                .padding(.bottom, 10)
            }
            Button("Done") { walk.finish() }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("doneButton")
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.background)
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(Theme.muted)
            Spacer()
            Text(value).monospacedDigit().foregroundStyle(Theme.foreground)
        }
        .font(.body)
    }
}
