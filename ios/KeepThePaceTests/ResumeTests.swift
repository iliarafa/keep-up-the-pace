import Foundation
import PaceKit
import Testing
@testable import KeepThePace

/// Resuming a walk after the app is force-quit (spec §2 failure cases).
@MainActor
@Suite struct ResumeTests {
    @Test func aForceQuitWalkIsOfferedAndResumesWithoutBuzzingAgain() async {
        let first = Launch()
        await first.startWalk()
        first.walk.sceneChanged(.background)
        first.clock.advance(31)
        first.walk.tick()
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
