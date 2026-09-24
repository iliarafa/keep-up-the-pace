/// The alert bucket relative to the user's alert threshold (15, 30 or 60 s). It only drives
/// alerts (Watch haptics, Live Activity alert updates); the on-screen readout's colour and
/// label come from `Format.delta(sec:)`'s `DeltaTone`.
public enum PaceStatus: String, Codable, Sendable {
    case ahead, onTime, behind
}

/// Buckets the schedule delta into ahead / on time / behind. To leave ahead or behind,
/// the delta must come back inside the threshold by `recoveryMarginSec`, so hovering at
/// the edge doesn't flip the status (and buzz the user) over and over.
public struct PaceStatusMachine: Codable, Hashable, Sendable {
    public let thresholdSec: Double
    public let recoveryMarginSec: Double
    public private(set) var status: PaceStatus

    /// `status` is where the machine starts: a resumed walk carries on from its saved status, so
    /// it doesn't buzz again for a change it already announced.
    public init(thresholdSec: Double = 30, recoveryMarginSec: Double = 5, status: PaceStatus = .onTime) {
        self.thresholdSec = thresholdSec
        self.recoveryMarginSec = recoveryMarginSec
        self.status = status
    }

    /// Feeds a new delta. Returns the new status only when it changed.
    public mutating func update(deltaSec: Double) -> PaceStatus? {
        guard deltaSec.isFinite else { return nil }
        let next = nextStatus(for: deltaSec)
        guard next != status else { return nil }
        status = next
        return next
    }

    private func nextStatus(for delta: Double) -> PaceStatus {
        if delta >= thresholdSec { return .ahead }
        if delta <= -thresholdSec { return .behind }
        let recovery = thresholdSec - recoveryMarginSec
        switch status {
        case .ahead: return delta < recovery ? .onTime : .ahead
        case .behind: return delta > -recovery ? .onTime : .behind
        case .onTime: return .onTime
        }
    }
}
