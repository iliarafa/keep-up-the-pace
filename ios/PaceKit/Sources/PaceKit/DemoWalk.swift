import Foundation

/// The simulated walk behind demo mode. Ported from `use-pace-app.ts`.
public enum DemoWalk {
    public static let defaultDestination = Place(
        name: "Gantry Plaza State Park", area: "Long Island City",
        coordinate: LatLon(lat: 40.74551, lon: -73.95875))
    public static let tickInterval: TimeInterval = 0.25
    public static let startDistanceM = 280.0
    public static let startBearingDeg = 188.0
    /// Deliberately slower than the walker's pace so the demo finishes early.
    public static let plannedPaceMps = 0.85

    public static func startPoint(for dest: LatLon) -> LatLon {
        Geo.destinationPoint(from: dest, bearingDeg: startBearingDeg, distanceM: startDistanceM)
    }

    public static func arriveBy(start: LatLon, dest: LatLon, now: Date) -> Date {
        now + Geo.walkEstimateSec(distanceM: Geo.haversineM(start, dest), paceMps: plannedPaceMps)
    }

    public static func firstFix(start: LatLon, now: Date) -> GPSFix {
        GPSFix(coordinate: start, speedMps: 1.72, accuracyM: 5, timestamp: now)
    }

    /// Advances one tick: 1.72 ± 0.18 m/s, snapping to the destination once within the arrival radius.
    public static func step(from prev: GPSFix, toward dest: LatLon, now: Date) -> GPSFix {
        if Pace.hasArrived(straightLineM: Geo.haversineM(prev.coordinate, dest)) {
            return GPSFix(coordinate: dest, speedMps: 0, accuracyM: prev.accuracyM, timestamp: now)
        }
        let speed = 1.72 + sin(now.timeIntervalSince1970 / 3.2) * 0.18
        let next = Geo.moveTowards(from: prev.coordinate, to: dest, distanceM: speed * tickInterval)
        return GPSFix(coordinate: next, speedMps: speed, accuracyM: 5, timestamp: now)
    }
}
