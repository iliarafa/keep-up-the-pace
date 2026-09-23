import Foundation

public enum Units: String, Codable, Sendable, CaseIterable {
    case imperial, metric

    /// Imperial for US English, metric everywhere else — same rule as the web app.
    public static func auto(for locale: Locale) -> Units {
        locale.language.languageCode == .english && locale.region == .unitedStates ? .imperial : .metric
    }
}
