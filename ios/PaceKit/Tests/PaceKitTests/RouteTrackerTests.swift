import Foundation
import Testing
@testable import PaceKit

@Suite struct RouteTrackerTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let dest = LatLon(lat: 40.7536, lon: -73.9832)
    var start: LatLon { Geo.destinationPoint(from: dest, bearingDeg: 90, distanceM: 600) }

    func tracker(routeM: Double = 900) -> RouteTracker {
        RouteTracker(routeM: routeM, at: start, straightLineM: 600, now: now)
    }

    @Test func remainingShrinksByDistanceMoved() {
        var t = tracker()
        let step = Geo.moveTowards(from: start, to: dest, distanceM: 100)
        t.advance(to: step)
        #expect(abs(t.remainingM(straightLineM: 500) - 800) < 1e-6)
    }

    @Test func remainingNeverDropsBelowTheStraightLine() {
        var t = tracker(routeM: 620)
        // Walk 200 m away from the destination: route minus movement would be 420 m.
        t.advance(to: Geo.destinationPoint(from: start, bearingDeg: 90, distanceM: 200))
        #expect(t.remainingM(straightLineM: 800) == 800)
    }

    @Test func refreshIsDueAfterSixtySeconds() {
        let t = tracker()
        #expect(!t.needsRefresh(straightLineM: 600, now: now + 59))
        #expect(t.needsRefresh(straightLineM: 600, now: now + 60))
    }

    @Test func refreshIsDueWhenYouDriftOffTheRoute() {
        var t = tracker()
        let away = Geo.destinationPoint(from: start, bearingDeg: 90, distanceM: 40)
        t.advance(to: away)
        // Predicted straight line 600 - 40 = 560, actual 640: off by 80 m.
        #expect(t.needsRefresh(straightLineM: 640, now: now + 5))
        #expect(!t.needsRefresh(straightLineM: 620, now: now + 5))
    }

    @Test func refreshedStartsOver() {
        var t = tracker()
        t.advance(to: Geo.moveTowards(from: start, to: dest, distanceM: 100))
        let here = Geo.moveTowards(from: start, to: dest, distanceM: 100)
        t.refreshed(routeM: 750, at: here, straightLineM: 500, now: now + 60)
        #expect(t.routeM == 750)
        #expect(t.remainingM(straightLineM: 500) == 750)
        #expect(!t.needsRefresh(straightLineM: 500, now: now + 100))
    }

    @Test func failedRefreshKeepsTheEstimateAndWaits() {
        var t = tracker()
        let away = Geo.destinationPoint(from: start, bearingDeg: 90, distanceM: 40)
        t.advance(to: away)
        t.refreshFailed(straightLineM: 640, now: now + 5)
        #expect(abs(t.remainingM(straightLineM: 640) - 860) < 1e-6)
        #expect(!t.needsRefresh(straightLineM: 640, now: now + 30))
        #expect(t.needsRefresh(straightLineM: 640, now: now + 65))
    }
}
