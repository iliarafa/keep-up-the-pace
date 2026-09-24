import Foundation
import PaceKit
import Testing
@testable import KeepThePace

/// Resuming a walk after the app is force-quit (spec §2 failure cases).
@MainActor
@Suite struct ResumeTests {
    /// Starts the test walk, walks it exactly on schedule for 100 s, and returns that launch (its
    /// walk saved) and the on-schedule speed.
    func walkOnPaceFor100Seconds() async -> (launch: Launch, mps: Double) {
        let launch = Launch()
        await launch.startWalk()
        let session = launch.walk.engine!.session
        let mps = session.startDistanceM / session.arriveBy.timeIntervalSince(session.startAt)
        launch.clock.advance(100)
        launch.location.send(launch.fix(walked: mps * 100))
        return (launch, mps)
    }

    @Test func aForceQuitWalkIsOfferedAndResumesWithoutBuzzingAgain() async {
        let first = Launch()
        await first.startWalk()
        first.walk.sceneChanged(.background)
        first.clock.advance(31)
        first.location.send(first.fix(walked: 0))  // still at the start: 31 s behind
        #expect(first.activity.shown.last?.alert == .behind)

        // Force-quit, then open the app again 30 s later.
        first.clock.advance(30)
        let second = Launch(defaults: first.defaults, clock: first.clock)
        #expect(second.walk.pendingResume?.engine.session == first.walk.engine?.session)
        #expect(second.activity.endAllCount == 0)  // its Live Activity is still there to adopt
        second.walk.resume()
        #expect(second.walk.phase == .walk)
        #expect(second.location.running)
        #expect(second.location.backgroundTracking)
        #expect(second.activity.shown.count == 1)
        #expect(second.activity.shown.first?.alert == nil)  // still behind: already announced
        #expect(second.activity.shown.first?.state.status == .behind)
    }

    @Test func aWalkerWhoKeptWalkingResumesOnPaceWithoutAlerts() async {
        let (first, mps) = await walkOnPaceFor100Seconds()
        // Force-quit; the walker keeps going and opens the app 60 s later.
        first.clock.advance(60)
        let second = Launch(defaults: first.defaults, clock: first.clock)
        second.location.send(second.fix(walked: mps * 160))  // the setup screen's GPS
        second.walk.resume()
        #expect(abs(second.activity.shown.first?.state.deltaSec ?? 99) < 1)
        second.clock.advance(5)
        second.location.send(second.fix(walked: mps * 165))
        #expect(second.activity.shown.allSatisfy { $0.alert == nil })
        #expect(second.feedback.played.isEmpty)
    }

    @Test func aResumeWithoutAFixWaitsForOneBeforeJudging() async {
        let (first, mps) = await walkOnPaceFor100Seconds()
        first.clock.advance(60)
        let second = Launch(defaults: first.defaults, clock: first.clock)
        second.walk.resume()  // no GPS fix yet: the saved one is 60 s old
        second.clock.advance(1)
        second.walk.tick()
        second.location.send(second.fix(walked: mps * 161))
        #expect(second.activity.shown.allSatisfy { $0.alert == nil })
        #expect(second.feedback.played.isEmpty)
        #expect(second.walk.metrics.map { abs($0.deltaSec) < 1 } == true)
    }

    @Test func arrivingJustAfterAResumeEndsTheLiveActivity() async {
        let (first, _) = await walkOnPaceFor100Seconds()
        first.clock.advance(120)
        let second = Launch(defaults: first.defaults, clock: first.clock)
        second.location.send(second.fix(walked: 295))  // at the park by the time the app opens
        second.walk.resume()
        #expect(second.walk.phase == .arrived)
        #expect(second.activity.ended.count == 1)
        #expect(second.activity.ended.first?.dismissAfter == 240)
        #expect(second.saved.activeWalk == nil)
    }

    @Test func startingANewWalkWhileOneIsOfferedDiscardsIt() async {
        let (first, _) = await walkOnPaceFor100Seconds()
        let second = Launch(defaults: first.defaults, clock: first.clock)
        #expect(second.walk.pendingResume != nil)
        await second.startWalk()
        #expect(second.walk.pendingResume == nil)
        #expect(second.activity.endAllCount == 1)
        #expect(second.walk.phase == .walk)
    }

    @Test func walksWhoseArriveByPassedOverAnHourAgoAreNotOffered() async {
        let first = Launch()
        await first.startWalk()
        first.clock.advance(3 * 60 * 60)
        let second = Launch(defaults: first.defaults, clock: first.clock)
        #expect(second.walk.pendingResume == nil)
        #expect(second.saved.activeWalk == nil)
        #expect(second.activity.endAllCount == 1)
    }

    @Test func endingAnOfferedWalkClearsIt() async {
        let first = Launch()
        await first.startWalk()
        let second = Launch(defaults: first.defaults, clock: first.clock)
        second.walk.discardResume()
        #expect(second.walk.pendingResume == nil)
        #expect(second.saved.activeWalk == nil)
        #expect(second.activity.endAllCount == 1)
    }

    @Test func aWalkThatEndedIsNotOffered() async {
        let first = Launch()
        await first.startWalk()
        first.walk.finish()
        let second = Launch(defaults: first.defaults, clock: first.clock)
        #expect(second.walk.pendingResume == nil)
    }

    @Test func demoWalksAreNotSaved() {
        let first = Launch()
        first.walk.startDemo()
        first.walk.tick()
        #expect(first.saved.activeWalk == nil)
        first.walk.finish()
    }
}
