import Foundation

/// Decides, on each update of a walk, when the phone buzzes and when the Live Activity is updated
/// (spec §2, "Walk tracked on iPhone", steps 2–3):
/// - A status change buzzes: a haptic while the app is open, an alert on the Live Activity while
///   it isn't. Nothing buzzes when iPhone haptics are off.
/// - The Live Activity is updated at once for a status change, arrival, "location paused" or a
///   units change, and otherwise at most every 10 s.
public struct WalkAlerts: Codable, Hashable, Sendable {
    public static let routineIntervalSec: TimeInterval = 10

    public struct Decision: Equatable, Sendable {
        /// Send this to the Live Activity now; nil means no update this time.
        public var activity: PaceActivityState?
        /// Attach an alert for this status change to that update.
        public var alert: PaceStatus?
        /// Play the haptic for this status change in the app.
        public var haptic: PaceStatus?

        public init(activity: PaceActivityState? = nil, alert: PaceStatus? = nil, haptic: PaceStatus? = nil) {
            self.activity = activity
            self.alert = alert
            self.haptic = haptic
        }
    }

    public private(set) var machine: PaceStatusMachine
    private var lastSent: PaceActivityState?
    private var lastSentAt: Date?

    /// `status` is where a resumed walk left off, so it doesn't buzz again for the same change.
    public init(thresholdSec: Double, status: PaceStatus = .onTime) {
        machine = PaceStatusMachine(thresholdSec: thresholdSec, status: status)
    }

    public var status: PaceStatus { machine.status }

    public mutating func update(
        _ metrics: WalkMetrics, units: Units, locationPaused: Bool, now: Date, appActive: Bool, hapticsOn: Bool
    ) -> Decision {
        let change = metrics.arrived ? nil : machine.update(deltaSec: metrics.deltaSec)
        let state = PaceActivityState(
            deltaSec: metrics.deltaSec.isFinite ? metrics.deltaSec : 0, status: machine.status,
            remainingM: metrics.remainingM, units: units, arrived: metrics.arrived, locationPaused: locationPaused)
        var decision = Decision()
        if let change, hapticsOn {
            if appActive {
                decision.haptic = change
            } else {
                decision.alert = change
            }
        }
        let urgent = change != nil || state.arrived != lastSent?.arrived
            || state.locationPaused != lastSent?.locationPaused || state.units != lastSent?.units
        let due = lastSentAt.map { now.timeIntervalSince($0) >= Self.routineIntervalSec } ?? true
        if urgent || due {
            decision.activity = state
            lastSent = state
            lastSentAt = now
        }
        return decision
    }
}
