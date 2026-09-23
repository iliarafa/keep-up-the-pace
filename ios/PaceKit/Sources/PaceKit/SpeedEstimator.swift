import Foundation

public struct GpsFix: Codable, Hashable, Sendable {
    public var coordinate: LatLon
    public var speedMps: Double?
    public var accuracyM: Double?
    public var timestamp: Date

    public init(coordinate: LatLon, speedMps: Double?, accuracyM: Double?, timestamp: Date) {
        self.coordinate = coordinate
        self.speedMps = speedMps
        self.accuracyM = accuracyM
        self.timestamp = timestamp
    }
}

/// Turns raw location readings into fixes with a smoothed speed. Ported from `toFix` in
/// `src/hooks/use-geolocation.ts`, with two changes: inaccurate readings are dropped, and the
/// fallback speed uses haversine distance (the web version scales the whole distance by
/// cos(latitude), which under-counts north–south movement).
public struct SpeedEstimator: Sendable {
    public static let maxAccuracyM = 50.0
    public private(set) var last: GpsFix?

    public init() {}

    /// Returns nil (and keeps no state) for readings with invalid or worse-than-50 m accuracy.
    public mutating func accept(coordinate: LatLon, reportedSpeedMps: Double?, accuracyM: Double?, timestamp: Date) -> GpsFix? {
        if let accuracyM, accuracyM < 0 || accuracyM > Self.maxAccuracyM { return nil }
        var speed = reportedSpeedMps.flatMap { $0 >= 0 ? $0 : nil }
        if speed == nil, let last {
            let dt = timestamp.timeIntervalSince(last.timestamp)
            if dt > 0.4 { speed = max(0, Geo.haversineM(last.coordinate, coordinate) / dt) }
        }
        if speed == nil { speed = last?.speedMps }
        if let current = speed, let previous = last?.speedMps {
            speed = previous * 0.65 + current * 0.35
        }
        let fix = GpsFix(coordinate: coordinate, speedMps: speed, accuracyM: accuracyM, timestamp: timestamp)
        last = fix
        return fix
    }
}
