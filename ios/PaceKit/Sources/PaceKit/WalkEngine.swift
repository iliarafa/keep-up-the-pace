import Foundation

/// What the walk screen shows at one moment.
public struct WalkMetrics: Equatable, Sendable {
    /// Distance left: the routed distance on routed walks, else the straight line. 0 once arrived.
    public var remainingM: Double
    public var straightLineM: Double
    public var headingDeg: Double
    /// Seconds ahead of schedule (positive = early). Frozen at arrival.
    public var deltaSec: Double
    public var speedMps: Double
    public var walkedM: Double
    public var arrived: Bool
}

/// The per-fix calculation for one walk, shared by the iPhone and the Watch. Feed it every
/// accepted fix with `ingest(_:)` and ask for `metrics(now:)` whenever the screen needs them.
public struct WalkEngine: Sendable {
    public let session: Session
    public private(set) var lastFix: GPSFix?
    public private(set) var walkedM = 0.0
    public private(set) var arrivedAt: Date?
    private var finalDeltaSec: Double?
    private var route: RouteTracker?

    public init(session: Session) {
        self.session = session
        if session.routed {
            route = RouteTracker(
                routeM: session.startDistanceM, at: session.start,
                straightLineM: Geo.haversineM(session.start, session.dest.coordinate), now: session.startAt)
        }
    }

    public var arrived: Bool { arrivedAt != nil }

    public mutating func ingest(_ fix: GPSFix) {
        guard !arrived else { return }
        if let lastFix { walkedM += Geo.haversineM(lastFix.coordinate, fix.coordinate) }
        route?.advance(to: fix.coordinate)
        lastFix = fix
    }

    /// Arrival is checked here, on straight-line distance. Once arrived, the delta is frozen at
    /// the value worked out with 0 m remaining — exactly arrive-by minus the arrival time.
    public mutating func metrics(now: Date) -> WalkMetrics? {
        guard let fix = lastFix else { return nil }
        let straight = straightLineM(from: fix)
        let heading = Geo.bearingDeg(from: fix.coordinate, to: session.dest.coordinate)
        if !arrived, Pace.hasArrived(straightLineM: straight) {
            arrivedAt = now
            finalDeltaSec = session.deltaSec(remainingM: 0, now: now)
        }
        if let finalDeltaSec {
            return WalkMetrics(
                remainingM: 0, straightLineM: straight, headingDeg: heading, deltaSec: finalDeltaSec,
                speedMps: fix.speedMps ?? 0, walkedM: walkedM, arrived: true)
        }
        let remaining = route?.remainingM(straightLineM: straight) ?? straight
        return WalkMetrics(
            remainingM: remaining, straightLineM: straight, headingDeg: heading,
            deltaSec: session.deltaSec(remainingM: remaining, now: now),
            speedMps: fix.speedMps ?? 0, walkedM: walkedM, arrived: false)
    }

    public func needsRouteRefresh(now: Date) -> Bool {
        guard !arrived, let route, let lastFix else { return false }
        return route.needsRefresh(straightLineM: straightLineM(from: lastFix), now: now)
    }

    public mutating func routeRefreshed(distanceM: Double, now: Date) {
        guard let lastFix else { return }
        let straight = straightLineM(from: lastFix)
        route?.refreshed(routeM: distanceM, at: lastFix.coordinate, straightLineM: straight, now: now)
    }

    public mutating func routeRefreshFailed(now: Date) {
        guard let lastFix else { return }
        let straight = straightLineM(from: lastFix)
        route?.refreshFailed(straightLineM: straight, now: now)
    }

    private func straightLineM(from fix: GPSFix) -> Double {
        Geo.haversineM(fix.coordinate, session.dest.coordinate)
    }
}
