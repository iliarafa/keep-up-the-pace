import Foundation
import Testing
@testable import PaceKit

@Suite struct SpeedEstimatorTests {
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    let here = LatLon(lat: 60, lon: 10)

    @Test func rejectsInaccurateAndInvalidReadings() {
        var e = SpeedEstimator()
        #expect(e.accept(coordinate: here, reportedSpeedMps: 1, accuracyM: 50.1, timestamp: t0) == nil)
        #expect(e.accept(coordinate: here, reportedSpeedMps: 1, accuracyM: -1, timestamp: t0) == nil)
        #expect(e.last == nil)
        #expect(e.accept(coordinate: here, reportedSpeedMps: 1, accuracyM: 50, timestamp: t0) != nil)
    }

    @Test func usesReportedSpeedThenSmooths() {
        var e = SpeedEstimator()
        #expect(e.accept(coordinate: here, reportedSpeedMps: 1.5, accuracyM: 5, timestamp: t0)?.speedMps == 1.5)
        let second = e.accept(coordinate: here, reportedSpeedMps: 2.0, accuracyM: 5, timestamp: t0 + 1)
        #expect(abs(second!.speedMps! - 1.675) < 1e-12)
    }

    @Test func derivesSpeedFromHaversineWhenNotReported() {
        var e = SpeedEstimator()
        _ = e.accept(coordinate: here, reportedSpeedMps: nil, accuracyM: 5, timestamp: t0)
        // Due north at 60°N: the web version's formula would report half the true speed here.
        let north = LatLon(lat: 60.001, lon: 10)
        let fix = e.accept(coordinate: north, reportedSpeedMps: -1, accuracyM: 5, timestamp: t0 + 10)
        #expect(abs(fix!.speedMps! - Geo.haversineM(here, north) / 10) < 1e-9)
        #expect(fix!.speedMps! > 11)
    }

    @Test func keepsLastSpeedWhenFixesAreTooClose() {
        var e = SpeedEstimator()
        _ = e.accept(coordinate: here, reportedSpeedMps: 1.4, accuracyM: 5, timestamp: t0)
        let fix = e.accept(coordinate: LatLon(lat: 60.0001, lon: 10), reportedSpeedMps: nil, accuracyM: 5, timestamp: t0 + 0.3)
        #expect(abs(fix!.speedMps! - 1.4) < 1e-12)
    }

    @Test func noSpeedWithoutHistory() {
        var e = SpeedEstimator()
        let fix = e.accept(coordinate: here, reportedSpeedMps: nil, accuracyM: nil, timestamp: t0)
        #expect(fix != nil)   // unknown accuracy is accepted; only worse than 50 m is rejected
        #expect(fix?.speedMps == nil)
    }
}
