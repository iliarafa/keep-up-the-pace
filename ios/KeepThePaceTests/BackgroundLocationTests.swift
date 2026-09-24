import Foundation
import PaceKit
import Testing
@testable import KeepThePace

/// GPS in the background: on for the length of a real walk, off in setup (spec §1).
@MainActor
@Suite struct BackgroundLocationTests {
    @Test func aRealWalkTracksInTheBackgroundUntilItEnds() async {
        let launch = Launch()
        await launch.startWalk()
        #expect(launch.location.backgroundTracking)
        launch.walk.finish()
        #expect(!launch.location.backgroundTracking)
    }

    @Test func aDemoWalkLeavesTheGPSOff() {
        let launch = Launch()
        launch.walk.startDemo()
        #expect(launch.walk.phase == .walk)
        #expect(!launch.location.running)
        #expect(!launch.location.backgroundTracking)
        launch.walk.finish()
    }

    @Test func setupGPSStopsInTheBackground() {
        let launch = Launch()
        launch.walk.setupAppeared()
        launch.location.send(launch.fix(walked: 0))
        launch.walk.sceneChanged(.background)
        #expect(!launch.location.running)
        #expect(launch.walk.origin == nil)  // an old fix never becomes a walk's start point
        launch.walk.sceneChanged(.active)
        #expect(launch.location.running)
    }
}
