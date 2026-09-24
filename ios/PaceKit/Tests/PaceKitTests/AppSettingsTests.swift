import Foundation
import Testing
@testable import PaceKit

@Suite struct AppSettingsTests {
    func decode(_ json: String) throws -> AppSettings {
        try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
    }

    @Test func defaults() {
        let s = AppSettings()
        #expect(s.units == .auto)
        #expect(s.alertThreshold == .thirty)
        #expect(s.phoneHaptics)
    }

    @Test func roundTrips() throws {
        let s = AppSettings(units: .metric, alertThreshold: .sixty, phoneHaptics: false)
        let data = try JSONEncoder().encode(s)
        #expect(try JSONDecoder().decode(AppSettings.self, from: data) == s)
    }

    @Test func missingOrUnknownValuesFallBackToDefaults() throws {
        #expect(try decode("{}") == AppSettings())
        #expect(try decode(#"{"units":"furlongs"}"#).units == .auto)
        #expect(try decode(#"{"units":"imperial","someFutureSetting":true}"#).units == .imperial)
        #expect(try decode(#"{"alertThreshold":45,"phoneHaptics":"yes"}"#) == AppSettings())
    }

    @Test func settingsSavedBeforeAlertsKeepTheirUnits() throws {
        // What M2 saved: units only.
        #expect(try decode(#"{"units":"metric"}"#) == AppSettings(units: .metric, alertThreshold: .thirty, phoneHaptics: true))
    }

    @Test func thresholdsAreFifteenThirtyAndSixtySeconds() {
        #expect(AlertThreshold.allCases.map(\.seconds) == [15, 30, 60])
    }

    @Test func autoFollowsTheLocale() {
        #expect(UnitsSetting.auto.resolved(for: Locale(identifier: "en_US")) == .imperial)
        #expect(UnitsSetting.auto.resolved(for: Locale(identifier: "el_GR")) == .metric)
        #expect(UnitsSetting.metric.resolved(for: Locale(identifier: "en_US")) == .metric)
    }
}
