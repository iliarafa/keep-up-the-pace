import Foundation
import Testing
@testable import PaceKit

@Suite struct DistanceGateTests {
    let here = LatLon(lat: 40.7536, lon: -73.9832)

    /// A phone standing still: readings 3 m either side of where it is.
    func wander(_ i: Int) -> LatLon {
        Geo.destinationPoint(from: here, bearingDeg: i.isMultiple(of: 2) ? 90 : 270, distanceM: 3)
    }

    @Test func firstFixOnlySetsTheAnchor() {
        var gate = DistanceGate()
        #expect(gate.step(to: here, accuracyM: 5) == 0)
        #expect(gate.anchor == here)
    }

    @Test func standingStillAddsNothing() {
        var gate = DistanceGate()
        var counted = 0.0
        for i in 0..<100 { counted += gate.step(to: wander(i), accuracyM: 5) }
        #expect(counted == 0)
        #expect(gate.pendingM(to: wander(101)) <= 6.001)
    }

    @Test func walkingCountsTheWholeWay() {
        var gate = DistanceGate()
        var counted = 0.0
        var point = here
        for _ in 0...71 {  // 72 steps of 1.4 m: 100.8 m due north
            counted += gate.step(to: point, accuracyM: 5)
            point = Geo.destinationPoint(from: point, bearingDeg: 0, distanceM: 1.4)
        }
        let last = Geo.destinationPoint(from: here, bearingDeg: 0, distanceM: 1.4 * 71)
        #expect(counted >= 1.4 * 71 - DistanceGate.stepM(accuracyM: 5))  // at most one step still pending
        #expect(abs(counted + gate.pendingM(to: last) - 1.4 * 71) < 1e-6)
    }

    @Test func stepIsTwiceTheAccuracyWithinLimits() {
        #expect(DistanceGate.stepM(accuracyM: nil) == 50)
        #expect(DistanceGate.stepM(accuracyM: 1) == 5)
        #expect(DistanceGate.stepM(accuracyM: 8) == 16)
        #expect(DistanceGate.stepM(accuracyM: 40) == 50)
    }
}
