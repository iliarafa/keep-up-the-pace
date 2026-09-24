import Foundation

/// Turns raw location readings into fixes with a smoothed speed. Ported from `toFix` in
/// `src/hooks/use-geolocation.ts`, with three changes: inaccurate readings are dropped, stale
/// readings are dropped (the web gets that from `maximumAge: 1000`), and the fallback speed uses
/// haversine distance (the web version scales the whole distance by cos(latitude), which
/// under-counts north–south movement).
public struct SpeedEstimator: Sendable {
    public static let maxAccuracyM = 50.0
    /// Readings older than this when they arrive are cached positions, not live ones.
    public static let maxAgeSec: TimeInterval = 1

    /// Why a reading was dropped.
    public enum Rejection: String, Sendable {
        case inaccurate, stale
    }

    public private(set) var last: GPSFix?
    /// Why the latest reading was dropped, or nil if it was accepted. For logging.
    public private(set) var lastRejection: Rejection?

    public init() {}

    /// Returns nil for readings with invalid or worse-than-50 m accuracy, and for readings more
    /// than `maxAgeSec` old when they arrived — so a cached position never becomes a walk's start
    /// point. A dropped reading leaves `last` alone and sets `lastRejection`.
    public mutating func accept(
        coordinate: LatLon, reportedSpeedMps: Double?, accuracyM: Double?, timestamp: Date, receivedAt: Date
    ) -> GPSFix? {
        if let accuracyM, accuracyM < 0 || accuracyM > Self.maxAccuracyM {
            lastRejection = .inaccurate
            return nil
        }
        if receivedAt.timeIntervalSince(timestamp) > Self.maxAgeSec {
            lastRejection = .stale
            return nil
        }
        lastRejection = nil
        var speed = reportedSpeedMps.flatMap { $0 >= 0 ? $0 : nil }
        if speed == nil, let last {
            let dt = timestamp.timeIntervalSince(last.timestamp)
            if dt > 0.4 { speed = max(0, Geo.haversineM(last.coordinate, coordinate) / dt) }
        }
        if speed == nil { speed = last?.speedMps }
        if let current = speed, let previous = last?.speedMps {
            speed = previous * 0.65 + current * 0.35
        }
        let fix = GPSFix(coordinate: coordinate, speedMps: speed, accuracyM: accuracyM, timestamp: timestamp)
        last = fix
        return fix
    }
}
