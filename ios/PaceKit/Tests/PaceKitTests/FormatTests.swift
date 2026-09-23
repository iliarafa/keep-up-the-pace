import Foundation
import Testing
@testable import PaceKit

@Suite struct FormatTests {
    let golden = GoldenFixture.shared

    @Test func speedMatchesWeb() {
        for c in golden.speed {
            let out = Format.speed(mps: c.mps, units: Units(rawValue: c.units)!)
            #expect(out == SpeedText(value: c.value, unit: c.unit), "\(c)")
        }
    }

    @Test func distanceMatchesWeb() {
        for c in golden.distance {
            #expect(Format.distance(meters: c.m, units: Units(rawValue: c.units)!) == c.out, "\(c)")
        }
    }

    @Test func durationMatchesWeb() {
        for c in golden.duration {
            #expect(Format.duration(seconds: c.ms / 1000) == c.out, "\(c)")
        }
    }

    @Test func deltaMatchesWeb() {
        for c in golden.delta {
            let expected = DeltaText(sign: c.sign, clock: c.clock, label: c.label, tone: DeltaTone(rawValue: c.tone)!)
            #expect(Format.delta(sec: c.sec) == expected, "\(c)")
        }
    }

    @Test func headingMatchesWeb() {
        for c in golden.heading {
            #expect(Format.heading(c.deg) == c.out, "\(c)")
        }
    }

    @Test func nonFiniteInputs() {
        #expect(Format.speed(mps: .nan, units: .metric) == SpeedText(value: "0.0", unit: "km/h"))
        #expect(Format.distance(meters: .infinity, units: .imperial) == "—")
        #expect(Format.delta(sec: .nan).label == "on time")
        #expect(Format.heading(.nan) == "—")
        #expect(Format.duration(seconds: .infinity) == "—")
    }

    @Test func clockUsesLocaleAndTimeZone() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)  // 2023-11-14 22:13:20 UTC
        let us = Format.clock(date, locale: Locale(identifier: "en_US"), timeZone: TimeZone(identifier: "UTC")!)
        #expect(us.replacingOccurrences(of: "\u{202F}", with: " ") == "10:13 PM")
        let gr = Format.clock(date, locale: Locale(identifier: "en_GB"), timeZone: TimeZone(identifier: "Europe/Athens")!)
        #expect(["0:13", "00:13"].contains(gr), "24-hour clock in Athens time, got \(gr)")
    }

    @Test func unitsFollowLocale() {
        #expect(Units.auto(for: Locale(identifier: "en_US")) == .imperial)
        #expect(Units.auto(for: Locale(identifier: "en_GB")) == .metric)
        #expect(Units.auto(for: Locale(identifier: "el_GR")) == .metric)
    }
}
