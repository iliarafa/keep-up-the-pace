import Foundation
import PaceKit
@testable import KeepThePace

/// GPS the test drives by hand: `send(_:)` is a reading arriving.
@MainActor
final class FakeLocation: LocationProviding {
    var onFix: ((GPSFix) -> Void)?
    var access: LocationAccess = .allowed
    var precise = true
    private(set) var latestFix: GPSFix?
    private(set) var running = false
    private(set) var backgroundTracking = false

    func start() { running = true }

    func stop() {
        running = false
        latestFix = nil
    }

    func setBackgroundTracking(_ on: Bool) { backgroundTracking = on }

    func requestPrecise() {}

    func send(_ fix: GPSFix) {
        latestFix = fix
        onFix?(fix)
    }
}

/// Apple Maps stand-in: answers every request with `distanceM` and records where it was asked from.
@MainActor
final class FakeRoutes: RouteProviding {
    var distanceM: Double?
    private(set) var requestedFrom: [LatLon] = []

    func walkingDistanceM(from start: LatLon, to end: LatLon) async -> Double? {
        requestedFrom.append(start)
        return distanceM
    }
}

/// A clock the test moves by hand.
final class TestClock {
    var now = Date(timeIntervalSince1970: 1_800_000_000)

    func advance(_ seconds: TimeInterval) { now += seconds }
}
