import Foundation
import Testing
@testable import PaceKit

@Suite struct PaceTests {
    @Test func scheduleDeltaMatchesWeb() {
        for c in GoldenFixture.shared.scheduleDelta {
            let out = Pace.scheduleDeltaSec(
                startDistanceM: c.startDistanceM, remainingM: c.remainingM,
                startAt: date(ms: c.startAt), arriveBy: date(ms: c.arriveBy), now: date(ms: c.now))
            #expect(abs(out - c.out) < 1e-5, "\(c)")
        }
    }

    @Test func onScheduleHalfwayIsZero() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let delta = Pace.scheduleDeltaSec(
            startDistanceM: 1000, remainingM: 500, startAt: start, arriveBy: start + 600, now: start + 300)
        #expect(abs(delta) < 1e-9)
    }

    @Test func sessionDeltaUsesItsOwnSchedule() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let session = Session(
            dest: Place(name: "Bryant Park", area: "Manhattan", coordinate: LatLon(lat: 40.7536, lon: -73.9832)), start: LatLon(lat: 40.74, lon: -73.96),
            startDistanceM: 1000, startAt: start, arriveBy: start + 1000, demo: false, routed: false)
        // 1 m/s required; 600 m covered after 500 s is 100 s early.
        #expect(abs(session.deltaSec(remainingM: 400, now: start + 500) - 100) < 1e-9)
    }

    @Test func arrivalRadiusIsInclusive() {
        #expect(Pace.hasArrived(remainingM: 18))
        #expect(!Pace.hasArrived(remainingM: 18.01))
    }
}
