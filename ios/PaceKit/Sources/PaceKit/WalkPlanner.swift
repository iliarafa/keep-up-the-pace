import Foundation

/// The setup screen's plan: destination, arrive-by and planned distance. Ported from
/// `chooseDestination`, `bumpArriveBy` and `setArriveByInput` in `use-pace-app.ts`.
public struct WalkPlanner: Equatable, Sendable {
    /// Distance assumed for the default arrive-by when there is no location to measure from yet
    /// (as on the web). It is never shown or used as the walk's distance.
    public static let fallbackDistanceM = 1200.0
    /// The time estimate never plans for less than this distance (as on the web).
    public static let minEstimateDistanceM = 80.0

    public private(set) var destination: Place?
    public private(set) var arriveBy: Date?
    /// The walk's planned distance: the walking route, or the straight line from where the plan
    /// was made. Nil until there is a location to measure from.
    public private(set) var plannedDistanceM: Double?
    /// True once the planned distance comes from a walking route rather than a straight line.
    public private(set) var plannedFromRoute = false
    private var arriveByEdited = false
    private var planID = 0

    public init() {}

    /// Picks a destination and sets arrive-by from the straight-line distance. Returns an id to
    /// pass back to `routeResolved` with the walking-route distance, or nil when there is no
    /// origin to route from; `originFound` then completes the plan when the first fix arrives.
    public mutating func choose(_ place: Place, from origin: LatLon?, now: Date) -> Int? {
        destination = place
        arriveByEdited = false
        planID += 1
        plannedFromRoute = false
        plannedDistanceM = origin.map { Geo.haversineM($0, place.coordinate) }
        arriveBy = Self.defaultArriveBy(distanceM: plannedDistanceM ?? Self.fallbackDistanceM, now: now)
        return origin == nil ? nil : planID
    }

    /// Completes a plan made before there was a location: measures the straight line from the
    /// first fix and, unless the user has edited the time, sets arrive-by from it. Returns an id
    /// for `routeResolved`, or nil when there is no such plan to complete.
    public mutating func originFound(_ origin: LatLon, now: Date) -> Int? {
        guard let destination, plannedDistanceM == nil else { return nil }
        planID += 1
        let distance = Geo.haversineM(origin, destination.coordinate)
        plannedDistanceM = distance
        if !arriveByEdited { arriveBy = Self.defaultArriveBy(distanceM: distance, now: now) }
        return planID
    }

    /// Upgrades the plan to the routed distance — unless the route failed, the user has edited
    /// the time since, or picked another destination.
    public mutating func routeResolved(planID id: Int, distanceM: Double?, now: Date) {
        guard id == planID, !arriveByEdited, let distanceM else { return }
        plannedFromRoute = true
        plannedDistanceM = distanceM
        arriveBy = Self.defaultArriveBy(distanceM: distanceM, now: now)
    }

    /// Moves arrive-by by whole minutes, never to less than a minute from now.
    public mutating func bump(minutes: Int, now: Date) {
        arriveByEdited = true
        let base = arriveBy ?? now + 15 * 60
        arriveBy = max(now + 60, base + TimeInterval(minutes * 60))
    }

    /// Sets arrive-by from a picked clock time. A time already past today (by more than 30 s)
    /// means that time tomorrow, as on the web.
    public mutating func setArriveBy(hour: Int, minute: Int, now: Date, calendar: Calendar) {
        var parts = calendar.dateComponents([.year, .month, .day], from: now)
        parts.hour = hour
        parts.minute = minute
        parts.second = 0
        guard var date = calendar.date(from: parts) else { return }
        if date < now - 30 {
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        }
        arriveByEdited = true
        arriveBy = date
    }

    /// Whether a walk can start: a destination, a time, and a live location to start from.
    public func canStart(hasLocation: Bool) -> Bool {
        destination != nil && arriveBy != nil && hasLocation
    }

    /// The real walk this plan starts from `start` (spec §2.5). A routed plan keeps its route
    /// distance. A straight-line plan is measured again from `start`, so the pace number starts
    /// at zero even if the user moved after picking the place.
    public func beginSession(from start: LatLon, now: Date) -> Session? {
        guard let destination, let arriveBy else { return nil }
        return Session.begin(
            dest: destination, from: start, plannedDistanceM: plannedFromRoute ? plannedDistanceM : nil,
            arriveBy: arriveBy, now: now, demo: false, routed: plannedFromRoute)
    }

    public static func defaultArriveBy(distanceM: Double, now: Date) -> Date {
        Geo.roundUpToMinute(now + Geo.walkEstimateSec(distanceM: max(distanceM, minEstimateDistanceM)))
    }
}
