import Foundation

/// Distance left along a walking route between route refreshes, and when to refresh.
///
/// Between refreshes the last route distance is reduced by how far you have moved. A refresh is
/// due every 60 s, or sooner when your straight-line distance to the destination has drifted more
/// than 75 m from what the last refresh predicted (you went off the route).
public struct RouteTracker: Equatable, Sendable {
    public static let refreshIntervalSec: TimeInterval = 60
    public static let driftLimitM = 75.0

    public private(set) var routeM: Double
    private var movedM = 0.0
    private var lastPoint: LatLon
    private var straightLineAtRefreshM: Double
    private var refreshedAt: Date

    public init(routeM: Double, at point: LatLon, straightLineM: Double, now: Date) {
        self.routeM = routeM
        lastPoint = point
        straightLineAtRefreshM = straightLineM
        refreshedAt = now
    }

    public mutating func advance(to point: LatLon) {
        movedM += Geo.haversineM(lastPoint, point)
        lastPoint = point
    }

    /// The route distance left — never less than the straight line to the destination.
    public func remainingM(straightLineM: Double) -> Double {
        max(straightLineM, routeM - movedM)
    }

    public func needsRefresh(straightLineM: Double, now: Date) -> Bool {
        if now.timeIntervalSince(refreshedAt) >= Self.refreshIntervalSec { return true }
        let predicted = straightLineAtRefreshM - movedM
        return abs(straightLineM - predicted) > Self.driftLimitM
    }

    public mutating func refreshed(routeM: Double, at point: LatLon, straightLineM: Double, now: Date) {
        self = RouteTracker(routeM: routeM, at: point, straightLineM: straightLineM, now: now)
    }

    /// A refresh failed: keep the current estimate, and wait a full interval before trying again.
    public mutating func refreshFailed(straightLineM: Double, now: Date) {
        refreshedAt = now
        straightLineAtRefreshM = straightLineM + movedM
    }
}
