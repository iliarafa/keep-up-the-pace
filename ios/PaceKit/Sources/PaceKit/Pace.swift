import Foundation

public struct Place: Codable, Hashable, Sendable {
    public var name: String
    public var area: String
    public var coordinate: LatLon

    public init(name: String, area: String, coordinate: LatLon) {
        self.name = name
        self.area = area
        self.coordinate = coordinate
    }
}

/// One walk, fixed at start. Ported from `Session` in `src/lib/pace.ts`.
public struct Session: Codable, Hashable, Sendable {
    public var dest: Place
    public var start: LatLon
    public var startDistanceM: Double
    public var startAt: Date
    public var arriveBy: Date
    public var demo: Bool
    public var routed: Bool

    public init(dest: Place, start: LatLon, startDistanceM: Double, startAt: Date, arriveBy: Date, demo: Bool, routed: Bool) {
        self.dest = dest
        self.start = start
        self.startDistanceM = startDistanceM
        self.startAt = startAt
        self.arriveBy = arriveBy
        self.demo = demo
        self.routed = routed
    }

    public func deltaSec(remainingM: Double, now: Date) -> Double {
        Pace.scheduleDeltaSec(startDistanceM: startDistanceM, remainingM: remainingM, startAt: startAt, arriveBy: arriveBy, now: now)
    }
}

public enum Pace {
    /// Straight-line distance at which a walk counts as arrived.
    public static let arriveRadiusM = 18.0

    /// Seconds ahead of schedule (positive = early, negative = late): distance actually
    /// covered minus distance a constant pace would have covered by now, in seconds.
    public static func scheduleDeltaSec(startDistanceM: Double, remainingM: Double, startAt: Date, arriveBy: Date, now: Date) -> Double {
        let budget = arriveBy.timeIntervalSince(startAt)
        if budget <= 0 || startDistanceM <= 0 { return 0 }
        let requiredMps = startDistanceM / budget
        if requiredMps <= 0 { return 0 }
        let elapsed = max(0, now.timeIntervalSince(startAt))
        let expectedCovered = requiredMps * elapsed
        let actualCovered = max(0, startDistanceM - remainingM)
        return (actualCovered - expectedCovered) / requiredMps
    }

    public static func hasArrived(remainingM: Double) -> Bool {
        remainingM <= arriveRadiusM
    }
}
