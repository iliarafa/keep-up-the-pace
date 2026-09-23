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

    @Test func beginAppliesTheWebStartRules() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let dest = Place(name: "Bryant Park", area: "Manhattan", coordinate: LatLon(lat: 40.7536, lon: -73.9832))
        let start = LatLon(lat: 40.7527, lon: -73.9772)
        let tooClose = Session.begin(
            dest: dest, from: start, plannedDistanceM: 12, arriveBy: now - 300, now: now, demo: false, routed: true)
        #expect(tooClose.startDistanceM == 30)
        #expect(tooClose.arriveBy == now + 60)
        #expect(tooClose.startAt == now)
        #expect(tooClose.routed)
        let unplanned = Session.begin(
            dest: dest, from: start, plannedDistanceM: nil, arriveBy: now + 900, now: now, demo: true, routed: false)
        #expect(abs(unplanned.startDistanceM - Geo.haversineM(start, dest.coordinate)) < 1e-9)
        #expect(unplanned.arriveBy == now + 900)
    }

    @Test func arrivalRadiusIsInclusive() {
        #expect(Pace.hasArrived(straightLineM: 18))
        #expect(!Pace.hasArrived(straightLineM: 18.01))
    }

    @Test func nanRemainingDistanceGivesNaNLikeTheWeb() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let delta = Pace.scheduleDeltaSec(
            startDistanceM: 1000, remainingM: .nan, startAt: start, arriveBy: start + 600, now: start + 60)
        #expect(delta.isNaN)
    }
}
