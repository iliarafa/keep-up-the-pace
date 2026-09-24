import Foundation
import Testing
@testable import PaceKit

@Suite struct WalkAlertsTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func metrics(delta: Double, remaining: Double = 500, arrived: Bool = false) -> WalkMetrics {
        WalkMetrics(
            remainingM: remaining, straightLineM: remaining, headingDeg: 0, deltaSec: delta, speedMps: 1.3,
            walkedM: 100, arrived: arrived)
    }

    /// One update at `now + t`, judged from a fix taken `fixAge` seconds earlier.
    func update(
        _ a: inout WalkAlerts, delta: Double, at t: TimeInterval, arrived: Bool = false, paused: Bool = false,
        appActive: Bool = false, haptics: Bool = true, fixAge: TimeInterval = 0
    ) -> WalkAlerts.Decision {
        a.update(
            metrics(delta: delta, arrived: arrived), fixAt: now + t - fixAge, units: .metric, locationPaused: paused,
            now: now + t, appActive: appActive, hapticsOn: haptics)
    }

    @Test func firstUpdateGoesOutAtOnce() {
        var a = WalkAlerts(thresholdSec: 30)
        let d = update(&a, delta: -5, at: 0)
        #expect(d.activity?.status == .onTime)
        #expect(d.activity?.remainingM == 500)
        #expect(d.alert == nil)
        #expect(d.haptic == nil)
    }

    @Test func routineUpdatesGoOutAtMostEveryTenSeconds() {
        var a = WalkAlerts(thresholdSec: 30)
        _ = update(&a, delta: -5, at: 0)
        #expect(update(&a, delta: -6, at: 5).activity == nil)
        #expect(update(&a, delta: -7, at: 9.9).activity == nil)
        #expect(update(&a, delta: -8, at: 10).activity?.deltaSec == -8)
    }

    @Test func statusChangeWhileLockedAlertsTheLiveActivity() {
        var a = WalkAlerts(thresholdSec: 30)
        _ = update(&a, delta: -5, at: 0)
        let d = update(&a, delta: -31, at: 3)
        #expect(d.activity?.status == .behind)
        #expect(d.alert == .behind)
        #expect(d.haptic == nil)
    }

    @Test func statusChangeInTheAppPlaysAHaptic() {
        var a = WalkAlerts(thresholdSec: 30)
        _ = update(&a, delta: -5, at: 0, appActive: true)
        let d = update(&a, delta: -31, at: 3, appActive: true)
        #expect(d.haptic == .behind)
        #expect(d.alert == nil)
        #expect(d.activity?.status == .behind)
    }

    @Test func hapticsOffMeansNoBuzz() {
        var a = WalkAlerts(thresholdSec: 15)
        _ = update(&a, delta: 0, at: 0, haptics: false)
        let d = update(&a, delta: 16, at: 3, haptics: false)
        #expect(d.activity?.status == .ahead)
        #expect(d.alert == nil)
        #expect(d.haptic == nil)
    }

    @Test func arrivalAndLocationPausedGoOutAtOnce() {
        var a = WalkAlerts(thresholdSec: 30)
        _ = update(&a, delta: -5, at: 0)
        #expect(update(&a, delta: -5, at: 2, paused: true).activity?.locationPaused == true)
        #expect(update(&a, delta: -5, at: 3, paused: true).activity == nil)
        let arrived = update(&a, delta: -40, at: 4, arrived: true)
        #expect(arrived.activity?.arrived == true)
        #expect(arrived.alert == nil)  // arriving isn't a status change
    }

    @Test func aResumedWalkDoesNotBuzzAgain() {
        var a = WalkAlerts(thresholdSec: 30, status: .behind)
        let d = update(&a, delta: -40, at: 0)
        #expect(d.activity?.status == .behind)
        #expect(d.alert == nil)
    }

    @Test func nonFiniteDeltaIsSentAsZero() {
        var a = WalkAlerts(thresholdSec: 30)
        #expect(update(&a, delta: .nan, at: 0).activity?.deltaSec == 0)
    }

    @Test func alertTextNamesTheChangeAndTheNumbers() {
        #expect(PaceActivityState.alertTitle(for: .behind) == "Falling behind")
        #expect(PaceActivityState.alertTitle(for: .ahead) == "Ahead of schedule")
        #expect(PaceActivityState.alertTitle(for: .onTime) == "Back on pace")
        let state = PaceActivityState(deltaSec: -45, status: .behind, remainingM: 643.7, units: .imperial, arrived: false)
        #expect(state.alertBody == "\u{2212}0:45 · 0.4 mi to go")
    }

    @Test func aStaleFixHoldsTheStatus() {
        var a = WalkAlerts(thresholdSec: 30)
        _ = update(&a, delta: -5, at: 0)
        let held = update(&a, delta: -40, at: 20, fixAge: 16)  // judged from a 16 s old fix
        #expect(held.activity?.status == .onTime)
        #expect(held.alert == nil)
        #expect(held.haptic == nil)
        #expect(update(&a, delta: -40, at: 21).alert == .behind)  // a fresh fix judges again
    }

    @Test func locationPausedHoldsTheStatus() {
        var a = WalkAlerts(thresholdSec: 30)
        _ = update(&a, delta: -5, at: 0)
        let paused = update(&a, delta: -40, at: 3, paused: true)
        #expect(paused.activity?.locationPaused == true)
        #expect(paused.activity?.status == .onTime)
        #expect(paused.alert == nil)
    }

    @Test func aUnitsChangeGoesOutAtOnce() {
        var a = WalkAlerts(thresholdSec: 30)
        _ = a.update(
            metrics(delta: -5), fixAt: now, units: .metric, locationPaused: false, now: now, appActive: false,
            hapticsOn: true)
        let d = a.update(
            metrics(delta: -5), fixAt: now + 2, units: .imperial, locationPaused: false, now: now + 2,
            appActive: false, hapticsOn: true)
        #expect(d.activity?.units == .imperial)
    }
}
