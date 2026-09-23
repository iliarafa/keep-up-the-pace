import Foundation
import Testing
@testable import PaceKit

@Suite struct DemoWalkTests {
    let dest = DemoWalk.defaultDestination.coordinate
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func startsTwoHundredEightyMetresSouthish() {
        let start = DemoWalk.startPoint(for: dest)
        #expect(abs(Geo.haversineM(start, dest) - 280) < 0.01)
        #expect(abs(Geo.bearingDeg(from: dest, to: start) - 188) < 0.01)
    }

    @Test func plansAtPointEightFiveMetresPerSecond() {
        let start = DemoWalk.startPoint(for: dest)
        let arrive = DemoWalk.arriveBy(start: start, dest: dest, now: now)
        #expect(abs(arrive.timeIntervalSince(now) - Geo.haversineM(start, dest) / 0.85) < 1e-6)
    }

    @Test func stepMovesTowardDestinationAtWalkingSpeed() {
        let first = DemoWalk.firstFix(start: DemoWalk.startPoint(for: dest), now: now)
        let next = DemoWalk.step(from: first, toward: dest, now: now + 0.25)
        let moved = Geo.haversineM(first.coordinate, dest) - Geo.haversineM(next.coordinate, dest)
        #expect(abs(moved - next.speedMps! * 0.25) < 1e-6)
        #expect((1.54...1.90).contains(next.speedMps!))
        #expect(next.accuracyM == 5 && next.timestamp == now + 0.25)
    }

    @Test func snapsToDestinationInsideArrivalRadius() {
        let close = GpsFix(
            coordinate: Geo.destinationPoint(from: dest, bearingDeg: 90, distanceM: 10),
            speedMps: 1.7, accuracyM: 5, timestamp: now)
        let next = DemoWalk.step(from: close, toward: dest, now: now + 0.25)
        #expect(next.coordinate == dest)
        #expect(next.speedMps == 0)
    }
}
