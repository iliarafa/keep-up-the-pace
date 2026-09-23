import Foundation
import Testing
@testable import PaceKit

@Suite struct AppSettingsTests {
    func decode(_ json: String) throws -> AppSettings {
        try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
    }

    @Test func defaultsToAutoUnits() {
        #expect(AppSettings().units == .auto)
    }

    @Test func roundTrips() throws {
        let data = try JSONEncoder().encode(AppSettings(units: .metric))
        #expect(try JSONDecoder().decode(AppSettings.self, from: data).units == .metric)
    }

    @Test func missingOrUnknownValuesFallBackToDefaults() throws {
        #expect(try decode("{}").units == .auto)
        #expect(try decode(#"{"units":"furlongs"}"#).units == .auto)
        #expect(try decode(#"{"units":"imperial","someFutureSetting":true}"#).units == .imperial)
    }

    @Test func autoFollowsTheLocale() {
        #expect(UnitsSetting.auto.resolved(for: Locale(identifier: "en_US")) == .imperial)
        #expect(UnitsSetting.auto.resolved(for: Locale(identifier: "el_GR")) == .metric)
        #expect(UnitsSetting.metric.resolved(for: Locale(identifier: "en_US")) == .metric)
    }
}
