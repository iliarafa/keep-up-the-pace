import Foundation

/// Which device is tracking the walk (spec §1). The Watch takes part from M5.
public enum TrackingDevice: String, Codable, Sendable {
    case phone, watch
}

/// What the walk's Live Activity shows: its ActivityKit content state (spec §1), plus whether
/// location is paused (spec §2 failure cases).
public struct PaceActivityState: Codable, Hashable, Sendable {
    public var deltaSec: Double
    public var status: PaceStatus
    public var remainingM: Double
    public var units: Units
    public var arrived: Bool
    public var trackingDevice: TrackingDevice
    public var locationPaused: Bool

    public init(
        deltaSec: Double, status: PaceStatus, remainingM: Double, units: Units, arrived: Bool,
        trackingDevice: TrackingDevice = .phone, locationPaused: Bool = false
    ) {
        self.deltaSec = deltaSec
        self.status = status
        self.remainingM = remainingM
        self.units = units
        self.arrived = arrived
        self.trackingDevice = trackingDevice
        self.locationPaused = locationPaused
    }

    /// The alert title for a status change.
    public static func alertTitle(for status: PaceStatus) -> String {
        switch status {
        case .behind: "Falling behind"
        case .ahead: "Ahead of schedule"
        case .onTime: "Back on pace"
        }
    }

    /// The alert body: the ±m:ss and the distance left, e.g. "−0:45 · 0.4 mi to go".
    public var alertBody: String {
        let delta = Format.delta(sec: deltaSec)
        return "\(delta.sign)\(delta.clock) · \(Format.distance(meters: remainingM, units: units)) to go"
    }
}
