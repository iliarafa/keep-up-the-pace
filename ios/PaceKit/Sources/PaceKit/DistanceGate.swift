import Foundation

/// Adds up distance moved without counting GPS wander. A fix only counts once it is more than
/// twice its accuracy from the last counted point (at least 5 m, at most 50 m). Two readings of a
/// phone standing still rarely differ by more than that, so standing still adds nothing, while
/// walking adds the whole way. The stretch not yet counted is `pendingM(to:)`.
public struct DistanceGate: Codable, Hashable, Sendable {
    public static let minStepM = 5.0
    public static let maxStepM = 50.0

    /// The last counted point.
    public private(set) var anchor: LatLon?

    public init(anchor: LatLon? = nil) {
        self.anchor = anchor
    }

    /// How far a fix must be from the last counted point to count. Unknown accuracy uses the maximum.
    public static func stepM(accuracyM: Double?) -> Double {
        guard let accuracyM else { return maxStepM }
        return min(max(2 * accuracyM, minStepM), maxStepM)
    }

    /// The distance from the last counted point to `point`, not counted yet.
    public func pendingM(to point: LatLon) -> Double {
        anchor.map { Geo.haversineM($0, point) } ?? 0
    }

    /// Feeds a fix. Returns the distance to count now: 0 while the fix is within the gate.
    public mutating func step(to point: LatLon, accuracyM: Double?) -> Double {
        guard let anchor else {
            self.anchor = point
            return 0
        }
        let distance = Geo.haversineM(anchor, point)
        guard distance > Self.stepM(accuracyM: accuracyM) else { return 0 }
        self.anchor = point
        return distance
    }
}
