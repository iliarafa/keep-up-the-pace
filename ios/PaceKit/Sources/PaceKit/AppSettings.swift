import Foundation

public enum UnitsSetting: String, Codable, Sendable, CaseIterable {
    case auto, imperial, metric

    public func resolved(for locale: Locale) -> Units {
        switch self {
        case .auto: Units.auto(for: locale)
        case .imperial: .imperial
        case .metric: .metric
        }
    }
}

/// How far off schedule counts as ahead or behind for alerts (spec §3: 15, 30 or 60 s).
public enum AlertThreshold: Int, Codable, Sendable, CaseIterable {
    case fifteen = 15
    case thirty = 30
    case sixty = 60

    public var seconds: Double { Double(rawValue) }
}

/// User settings. Decoding is tolerant — a missing or unreadable value falls back to its
/// default — so fields added in later versions never wipe what the user already chose.
public struct AppSettings: Codable, Equatable, Sendable {
    public var units: UnitsSetting
    public var alertThreshold: AlertThreshold
    /// Buzz on status changes: a haptic in the app, an alert on the Live Activity when locked.
    public var phoneHaptics: Bool

    public init(units: UnitsSetting = .auto, alertThreshold: AlertThreshold = .thirty, phoneHaptics: Bool = true) {
        self.units = units
        self.alertThreshold = alertThreshold
        self.phoneHaptics = phoneHaptics
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        units = (try? values.decodeIfPresent(UnitsSetting.self, forKey: .units)) ?? .auto
        alertThreshold = (try? values.decodeIfPresent(AlertThreshold.self, forKey: .alertThreshold)) ?? .thirty
        phoneHaptics = (try? values.decodeIfPresent(Bool.self, forKey: .phoneHaptics)) ?? true
    }
}
