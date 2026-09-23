import Foundation

public struct GPSFix: Codable, Hashable, Sendable {
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
