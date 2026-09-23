/// Parses typed coordinates like "40.7455, -73.9588". Ported from `parseCoords` in `src/lib/geocode.ts`.
public enum CoordinateParser {
    public static func parse(_ query: String) -> Place? {
        guard let m = query.wholeMatch(of: /\s*(-?\d{1,3}\.\d+)\s*[, ]\s*(-?\d{1,3}\.\d+)\s*/),
              let lat = Double(m.1), let lon = Double(m.2),
              abs(lat) <= 90, abs(lon) <= 180
        else { return nil }
        return Place(
            name: "\(JSNumber.toFixed(lat, 5)), \(JSNumber.toFixed(lon, 5))",
            area: "Coordinates",
            coordinate: LatLon(lat: lat, lon: lon))
    }
}
