import Foundation
import PaceKit
import Testing
@testable import KeepThePace

/// Where Live Activity updates and alerts fire during a walk (spec §2 and §4).
@MainActor
@Suite struct LiveActivityAlertTests {
    @Test func theLiveActivityFollowsTheWalkAndStaysFourMinutesAfterArrival() async {
        let launch = Launch()
        await launch.startWalk()
        #expect(launch.activity.shown.count == 1)
        #expect(abs((launch.activity.shown.first?.state.remainingM ?? 0) - 300) < 1e-6)
        launch.clock.advance(5)
        launch.walk.tick()
        #expect(launch.activity.shown.count == 1)  // routine updates wait 10 s
        launch.clock.advance(5)
        launch.walk.tick()
        #expect(launch.activity.shown.count == 2)
        launch.location.send(launch.fix(walked: 295))
        #expect(launch.activity.ended.count == 1)
        #expect(launch.activity.ended.first?.dismissAfter == 240)
        #expect(launch.activity.ended.first?.state?.arrived == true)
    }

    @Test func aStatusChangeWhileLockedAlertsTheLiveActivity() async {
        let launch = Launch()
        await launch.startWalk()
        launch.walk.sceneChanged(.background)
        launch.clock.advance(31)
        launch.location.send(launch.fix(walked: 0))  // still at the start: 31 s behind
        #expect(launch.activity.shown.last?.alert == .behind)
        #expect(launch.activity.shown.last?.state.status == .behind)
        #expect(launch.feedback.played.isEmpty)
    }

    @Test func aStatusChangeInTheAppPlaysAHaptic() async {
        let launch = Launch()
        await launch.startWalk()
        launch.clock.advance(31)
        launch.location.send(launch.fix(walked: 0))
        #expect(launch.feedback.played == [.behind])
        #expect(launch.activity.shown.last?.alert == nil)
        #expect(launch.activity.shown.last?.state.status == .behind)
    }

    @Test func hapticsOffMeansNoBuzz() async {
        let launch = Launch()
        launch.saved.settings.phoneHaptics = false
        await launch.startWalk()
        launch.walk.sceneChanged(.background)
        launch.clock.advance(31)
        launch.location.send(launch.fix(walked: 0))
        #expect(launch.activity.shown.last?.state.status == .behind)
        #expect(launch.activity.shown.last?.alert == nil)
        #expect(launch.feedback.played.isEmpty)
    }

    @Test func endingAWalkRemovesTheLiveActivityAtOnce() async {
        let launch = Launch()
        await launch.startWalk()
        launch.walk.finish()
        #expect(launch.activity.ended == [FakeLiveActivity.Ended(state: nil, dismissAfter: nil)])
    }

    @Test func locationTurnedOffShowsLocationPausedAtOnce() async {
        let launch = Launch()
        await launch.startWalk()
        launch.location.access = .denied
        launch.clock.advance(1)
        launch.walk.tick()
        #expect(launch.activity.shown.last?.state.locationPaused == true)
    }
}
