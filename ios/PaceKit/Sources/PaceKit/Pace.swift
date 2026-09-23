import Foundation

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
        if remainingM.isNaN { return .nan }  // as on the web: NaN in, NaN out ("on time", no alert)
        let actualCovered = max(0, startDistanceM - remainingM)
        return (actualCovered - expectedCovered) / requiredMps
    }

    /// Arrival is judged on straight-line distance only — never on the routed remaining distance.
    public static func hasArrived(straightLineM: Double) -> Bool {
        straightLineM <= arriveRadiusM
    }
}

extension Session {
    /// A walk always starts with at least this far to go…
    public static let minStartDistanceM = 30.0
    /// …and at least this long to do it in.
    public static let minLeadTimeSec: TimeInterval = 60

    /// Starts a walk with the web's start rules (`beginSession` in `use-pace-app.ts`): the start
    /// distance is the planned distance (straight-line if there is no plan) but at least 30 m, and
    /// arrive-by is at least a minute away.
    public static func begin(
        dest: Place, from start: LatLon, plannedDistanceM: Double?, arriveBy: Date, now: Date, demo: Bool, routed: Bool
    ) -> Session {
        let distance = plannedDistanceM ?? Geo.haversineM(start, dest.coordinate)
        return Session(
            dest: dest, start: start, startDistanceM: max(distance, minStartDistanceM), startAt: now,
            arriveBy: max(arriveBy, now + minLeadTimeSec), demo: demo, routed: routed)
    }
}
