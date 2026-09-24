import Foundation
import PaceKit
@testable import KeepThePace

/// The walk the tests take: from 300 m due south of Bryant Park, straight to it.
enum TestWalk {
    static let park = Place(name: "Bryant Park", area: "Manhattan", coordinate: LatLon(lat: 40.7536, lon: -73.9832))
    static let start = Geo.destinationPoint(from: park.coordinate, bearingDeg: 180, distanceM: 300)

    static func fix(walked metres: Double, at time: Date) -> GPSFix {
        GPSFix(
            coordinate: Geo.moveTowards(from: start, to: park.coordinate, distanceM: metres), speedMps: 1.3,
            accuracyM: 5, timestamp: time)
    }
}

/// One app launch: a `WalkSession` wired to fakes, with the ticker off (tests call `tick()`).
@MainActor
struct Launch {
    let clock: TestClock
    let defaults: UserDefaults
    let saved: SavedData
    let location = FakeLocation()
    let routes = FakeRoutes()
    let walk: WalkSession

    /// Each launch gets empty storage of its own. Pass an earlier launch's `defaults` and `clock`
    /// to open the app again with what that launch saved.
    init(defaults: UserDefaults = UserDefaults(suiteName: "KeepThePaceTests.\(UUID().uuidString)")!,
         clock: TestClock = TestClock()) {
        self.clock = clock
        self.defaults = defaults
        saved = SavedData(defaults: defaults)
        walk = WalkSession(
            saved: saved, location: location, routes: routes, clock: { [clock] in clock.now }, tickInterval: nil)
    }

    /// A GPS reading `metres` along the test walk, stamped now.
    func fix(walked metres: Double) -> GPSFix {
        TestWalk.fix(walked: metres, at: clock.now)
    }

    /// GPS ready at the start point, the park picked, the walk started.
    func startWalk() async {
        location.send(fix(walked: 0))
        walk.choose(TestWalk.park)
        await settle()
        walk.startWalking()
    }
}

/// Lets tasks the session started (route requests) run to completion.
@MainActor
func settle() async {
    for _ in 0..<10 { await Task.yield() }
}
