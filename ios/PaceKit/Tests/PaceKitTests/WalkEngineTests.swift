import Foundation
import Testing
@testable import PaceKit

@Suite struct WalkEngineTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let dest = Place(name: "Bryant Park", area: "Manhattan", coordinate: LatLon(lat: 40.7536, lon: -73.9832))
    var start: LatLon { Geo.destinationPoint(from: dest.coordinate, bearingDeg: 180, distanceM: 1000) }

    func session(routed: Bool = false, startDistanceM: Double = 1000) -> Session {
        Session(dest: dest, start: start, startDistanceM: startDistanceM, startAt: now, arriveBy: now + 1000,
                demo: false, routed: routed)
    }

    func fix(metresFromStart m: Double, at t: Date, speed: Double? = 1.2) -> GPSFix {
        GPSFix(coordinate: Geo.moveTowards(from: start, to: dest.coordinate, distanceM: m), speedMps: speed,
               accuracyM: 5, timestamp: t)
    }

    @Test func noMetricsBeforeTheFirstFix() {
        var e = WalkEngine(session: session())
        #expect(e.metrics(now: now) == nil)
    }

    @Test func straightLineWalkReportsDistanceHeadingAndDelta() {
        var e = WalkEngine(session: session())
        e.ingest(fix(metresFromStart: 0, at: now))
        e.ingest(fix(metresFromStart: 600, at: now + 500))
        let m = e.metrics(now: now + 500)!
        #expect(abs(m.remainingM - 400) < 1e-6)
        #expect(abs(m.straightLineM - 400) < 1e-6)
        #expect(abs(m.headingDeg - 0) < 0.01 || abs(m.headingDeg - 360) < 0.01)  // due north
        #expect(abs(m.deltaSec - 100) < 1e-6)  // 600 m covered, 500 m due at 1 m/s
        #expect(abs(m.walkedM - 600) < 1e-6)
        #expect(m.speedMps == 1.2)
        #expect(!m.arrived)
    }

    @Test func routedWalkUsesTheRouteDistance() {
        var e = WalkEngine(session: session(routed: true, startDistanceM: 1300))
        e.ingest(fix(metresFromStart: 0, at: now))
        e.ingest(fix(metresFromStart: 300, at: now + 200))
        let m = e.metrics(now: now + 200)!
        #expect(abs(m.remainingM - 1000) < 1e-6)  // 1300 m route minus 300 m walked
    }

    @Test func arrivalFreezesTheDeltaAtArriveByMinusArrivalTime() {
        var e = WalkEngine(session: session())
        e.ingest(fix(metresFromStart: 0, at: now))
        e.ingest(fix(metresFromStart: 985, at: now + 900))  // 15 m out: inside the 18 m radius
        let m = e.metrics(now: now + 900)!
        #expect(m.arrived)
        #expect(m.remainingM == 0)
        #expect(abs(m.deltaSec - 100) < 1e-9)  // arrive-by now+1000, arrived at now+900
        #expect(e.arrivedAt == now + 900)
        // Later fixes and ticks don't change the result.
        e.ingest(fix(metresFromStart: 900, at: now + 950))
        let later = e.metrics(now: now + 2000)!
        #expect(abs(later.deltaSec - 100) < 1e-9)
        #expect(abs(later.walkedM - 985) < 1e-6)
    }

    @Test func routeRefreshOnlyForRoutedWalks() {
        var plain = WalkEngine(session: session())
        plain.ingest(fix(metresFromStart: 0, at: now))
        #expect(!plain.needsRouteRefresh(now: now + 120))

        var routed = WalkEngine(session: session(routed: true, startDistanceM: 1300))
        routed.ingest(fix(metresFromStart: 0, at: now))
        #expect(!routed.needsRouteRefresh(now: now + 30))
        #expect(routed.needsRouteRefresh(now: now + 60))
        routed.routeRefreshed(distanceM: 1250, now: now + 60)
        #expect(!routed.needsRouteRefresh(now: now + 90))
        #expect(abs(routed.metrics(now: now + 90)!.remainingM - 1250) < 1e-6)
        routed.routeRefreshFailed(now: now + 150)
        #expect(!routed.needsRouteRefresh(now: now + 180))
    }
}
