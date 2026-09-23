import Testing
@testable import PaceKit

@Suite struct PaceStatusMachineTests {
    @Test func startsOnTime() {
        #expect(PaceStatusMachine().status == .onTime)
    }

    @Test func crossesThresholdIntoBehind() {
        var m = PaceStatusMachine()
        #expect(m.update(deltaSec: -29.9) == nil)
        #expect(m.update(deltaSec: -30) == .behind)
        #expect(m.status == .behind)
    }

    @Test func behindNeedsRecoveryMarginToReturn() {
        var m = PaceStatusMachine()
        _ = m.update(deltaSec: -40)
        #expect(m.update(deltaSec: -27) == nil)   // inside threshold, not past the margin
        #expect(m.update(deltaSec: -25) == nil)   // exactly at -(30 - 5) still counts as behind
        #expect(m.update(deltaSec: -24.9) == .onTime)
    }

    @Test func aheadNeedsRecoveryMarginToReturn() {
        var m = PaceStatusMachine()
        #expect(m.update(deltaSec: 30) == .ahead)
        #expect(m.update(deltaSec: 26) == nil)
        #expect(m.update(deltaSec: 25) == nil)   // exactly +(30 - 5) still counts as ahead
        #expect(m.update(deltaSec: 24.9) == .onTime)
    }

    @Test func jumpsDirectlyBetweenAheadAndBehind() {
        var m = PaceStatusMachine()
        _ = m.update(deltaSec: 45)
        #expect(m.update(deltaSec: -31) == .behind)
        #expect(m.update(deltaSec: 31) == .ahead)
    }

    @Test func reportsOnlyChanges() {
        var m = PaceStatusMachine()
        #expect(m.update(deltaSec: -35) == .behind)
        #expect(m.update(deltaSec: -50) == nil)
        #expect(m.update(deltaSec: -35) == nil)
    }

    @Test func ignoresNonFiniteDeltas() {
        var m = PaceStatusMachine()
        #expect(m.update(deltaSec: .nan) == nil)
        #expect(m.update(deltaSec: -.infinity) == nil)
        #expect(m.status == .onTime)
    }

    @Test func customThreshold() {
        var m = PaceStatusMachine(thresholdSec: 15, recoveryMarginSec: 5)
        #expect(m.update(deltaSec: -15) == .behind)
        #expect(m.update(deltaSec: -10) == nil)
        #expect(m.update(deltaSec: -9.9) == .onTime)
    }
}
