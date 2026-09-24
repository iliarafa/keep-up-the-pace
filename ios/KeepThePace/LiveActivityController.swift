// ActivityKit's `Activity` isn't marked Sendable, but its async update and end are made to be called
// from tasks; `@preconcurrency` lets Swift 6 hand it to them.
@preconcurrency import ActivityKit
import Foundation
import OSLog
import PaceKit

/// Starts, updates and ends the walk's Live Activity (spec §1). Each update is marked stale two
/// minutes on, so a Live Activity left behind by a force-quit shows that it stopped updating
/// (spec §2).
@MainActor
final class LiveActivityController: LiveActivityControlling {
    static let staleAfterSec: TimeInterval = 120

    private var activity: Activity<PaceActivityAttributes>?
    private let log = Logger(subsystem: "com.iliasrafailidis.delta", category: "liveActivity")

    func show(_ state: PaceActivityState, for session: Session, alert: PaceStatus?) {
        let content = ActivityContent(state: state, staleDate: .now + Self.staleAfterSec)
        if activity == nil {
            activity = Self.running(for: session)
        }
        guard let activity else {
            start(session, content)
            return
        }
        var alertConfiguration: AlertConfiguration?
        if let alert {
            let title = PaceActivityState.alertTitle(for: alert)
            log.info("Status alert: \(title, privacy: .public), \(state.alertBody, privacy: .public)")
            alertConfiguration = AlertConfiguration(title: "\(title)", body: "\(state.alertBody)", sound: .default)
        }
        Task { await activity.update(content, alertConfiguration: alertConfiguration) }
    }

    func end(_ state: PaceActivityState?, dismissAfter: TimeInterval?) {
        guard let activity else { return }
        self.activity = nil
        let content = state.map { ActivityContent(state: $0, staleDate: nil) }
        let policy: ActivityUIDismissalPolicy = dismissAfter.map { .after(.now + $0) } ?? .immediate
        Task { await activity.end(content, dismissalPolicy: policy) }
    }

    func endAll() {
        activity = nil
        for leftover in Activity<PaceActivityAttributes>.activities {
            Task { await leftover.end(nil, dismissalPolicy: .immediate) }
        }
    }

    private func start(_ session: Session, _ content: ActivityContent<PaceActivityState>) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = PaceActivityAttributes(
            destinationName: session.dest.name, arriveBy: session.arriveBy, startedAt: session.startAt)
        do {
            activity = try Activity.request(attributes: attributes, content: content)
        } catch {
            log.error("Couldn't start the Live Activity: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// The Live Activity an earlier launch started for this walk, if it is still up.
    private static func running(for session: Session) -> Activity<PaceActivityAttributes>? {
        Activity<PaceActivityAttributes>.activities.first {
            abs($0.attributes.startedAt.timeIntervalSince(session.startAt)) < 1
                && ($0.activityState == .active || $0.activityState == .stale)
        }
    }
}
