import Foundation

/// Spherical-earth geodesy. Ported from `src/lib/geo.ts`.
public enum Geo {
    public static let earthRadiusM = 6_371_000.0
    /// Average walking speed used to estimate trip time.
    public static let defaultWalkingPaceMps = 1.34

    public static func haversineM(_ a: LatLon, _ b: LatLon) -> Double {
        let φ1 = toRad(a.lat)
        let φ2 = toRad(b.lat)
        let Δφ = toRad(b.lat - a.lat)
        let Δλ = toRad(b.lon - a.lon)
        let s = sin(Δφ / 2) * sin(Δφ / 2) + cos(φ1) * cos(φ2) * sin(Δλ / 2) * sin(Δλ / 2)
        return 2 * earthRadiusM * atan2(s.squareRoot(), (1 - s).squareRoot())
    }

    /// Initial bearing in degrees, 0..<360, clockwise from north.
    public static func bearingDeg(from: LatLon, to: LatLon) -> Double {
        let φ1 = toRad(from.lat)
        let φ2 = toRad(to.lat)
        let Δλ = toRad(to.lon - from.lon)
        let y = sin(Δλ) * cos(φ2)
        let x = cos(φ1) * sin(φ2) - sin(φ1) * cos(φ2) * cos(Δλ)
        return (toDeg(atan2(y, x)) + 360).truncatingRemainder(dividingBy: 360)
    }

    public static func destinationPoint(from: LatLon, bearingDeg: Double, distanceM: Double) -> LatLon {
        let δ = distanceM / earthRadiusM
        let θ = toRad(bearingDeg)
        let φ1 = toRad(from.lat)
        let λ1 = toRad(from.lon)
        let φ2 = asin(sin(φ1) * cos(δ) + cos(φ1) * sin(δ) * cos(θ))
        let λ2 = λ1 + atan2(sin(θ) * sin(δ) * cos(φ1), cos(δ) - sin(φ1) * sin(φ2))
        let lon = (toDeg(λ2) + 540).truncatingRemainder(dividingBy: 360) - 180
        return LatLon(lat: toDeg(φ2), lon: lon)
    }

    public static func moveTowards(from: LatLon, to: LatLon, distanceM: Double) -> LatLon {
        let d = haversineM(from, to)
        if d <= distanceM || d == 0 { return to }
        return destinationPoint(from: from, bearingDeg: bearingDeg(from: from, to: to), distanceM: distanceM)
    }

    public static func cardinal(_ deg: Double) -> String {
        guard deg.isFinite else { return "N" }  // the web's `dirs[NaN] ?? "N"`
        let dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int(JSNumber.round(deg / 45)) % 8
        return index >= 0 ? dirs[index] : "N"
    }

    public static func walkEstimateSec(distanceM: Double, paceMps: Double = defaultWalkingPaceMps) -> TimeInterval {
        distanceM <= 0 ? 0 : distanceM / paceMps
    }

    public static func roundUpToMinute(_ date: Date) -> Date {
        Date(timeIntervalSince1970: (date.timeIntervalSince1970 / 60).rounded(.up) * 60)
    }

    private static func toRad(_ deg: Double) -> Double { deg * .pi / 180 }
    private static func toDeg(_ rad: Double) -> Double { rad * 180 / .pi }
}
