import Foundation

public struct SpeedText: Equatable, Sendable {
    public let value: String
    public let unit: String
}

public enum DeltaTone: String, Codable, Sendable {
    case early, late, ontime
}

public struct DeltaText: Equatable, Sendable {
    /// "+", "−" (U+2212) or "" when on time.
    public let sign: String
    public let clock: String
    public let label: String
    public let tone: DeltaTone
}

/// Display formatting. Ported from `src/lib/format.ts`; output matches the web app.
public enum Format {
    public static func speed(mps: Double, units: Units) -> SpeedText {
        if !mps.isFinite || mps < 0.15 {
            return SpeedText(value: "0.0", unit: units == .imperial ? "mph" : "km/h")
        }
        if units == .imperial {
            return SpeedText(value: JSNumber.toFixed(mps * 2.236936, 1), unit: "mph")
        }
        return SpeedText(value: JSNumber.toFixed(mps * 3.6, 1), unit: "km/h")
    }

    public static func distance(meters: Double, units: Units) -> String {
        if !meters.isFinite || meters < 0 { return "—" }
        if units == .imperial {
            let feet = meters * 3.28084
            if feet < 900 { return "\(Int(JSNumber.round(feet))) ft" }
            let miles = meters / 1609.344
            return "\(JSNumber.toFixed(miles, miles >= 10 ? 0 : 1)) mi"
        }
        if meters < 280 { return "\(Int(JSNumber.round(meters))) m" }
        let km = meters / 1000
        return "\(JSNumber.toFixed(km, km >= 10 ? 0 : 1)) km"
    }

    public static func clock(_ date: Date, locale: Locale = .current, timeZone: TimeZone = .current) -> String {
        let style = Date.FormatStyle(
            date: .omitted, time: .shortened, locale: locale,
            calendar: Calendar(identifier: .gregorian), timeZone: timeZone)
        return date.formatted(style)
    }

    public static func duration(seconds: TimeInterval) -> String {
        guard seconds.isFinite else { return "—" }
        let totalMin = max(0, Int(JSNumber.round(seconds / 60)))
        if totalMin < 60 { return "\(totalMin) min" }
        let h = totalMin / 60
        let m = totalMin % 60
        return m > 0 ? "\(h) hr \(m) min" : "\(h) hr"
    }

    public static func delta(sec: Double) -> DeltaText {
        let abs = Swift.abs(sec)
        if !sec.isFinite || abs < 3 {
            return DeltaText(sign: "", clock: "0:00", label: "on time", tone: .ontime)
        }
        let s = Int(JSNumber.round(abs))
        let h = s / 3600
        let m = (s % 3600) / 60
        let r = s % 60
        let clock = h > 0 ? "\(h):\(pad2(m)):\(pad2(r))" : "\(m):\(pad2(r))"
        let early = sec > 0
        return DeltaText(sign: early ? "+" : "\u{2212}", clock: clock, label: early ? "early" : "late", tone: early ? .early : .late)
    }

    public static func heading(_ deg: Double) -> String {
        guard deg.isFinite else { return "—" }
        let n = ((Int(JSNumber.round(deg)) % 360) + 360) % 360
        return String(format: "%03d°", n)
    }

    private static func pad2(_ n: Int) -> String { n < 10 ? "0\(n)" : "\(n)" }
}
