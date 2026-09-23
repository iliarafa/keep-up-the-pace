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

/// User settings. Decoding is tolerant — a missing or unreadable value falls back to its
/// default — so fields added in later versions never wipe what the user already chose.
public struct AppSettings: Codable, Equatable, Sendable {
    public var units: UnitsSetting

    public init(units: UnitsSetting = .auto) {
        self.units = units
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        units = (try? values.decodeIfPresent(UnitsSetting.self, forKey: .units)) ?? .auto
    }
}
