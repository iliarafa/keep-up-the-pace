import Foundation
import PaceKit
import Testing
@testable import KeepThePace

/// Spec §4's session tests: `WalkSession` driven by a scripted location source.
@MainActor
@Suite struct WalkFlowTests {
    @Test func aLiveWalkRunsToArrival() async {
        let launch = Launch()
        await launch.startWalk()
        #expect(launch.walk.phase == .walk)
        #expect(abs((launch.walk.engine?.session.startDistanceM ?? 0) - 300) < 1e-6)
        for metres in stride(from: 60.0, through: 240, by: 60) {
            launch.clock.advance(45)
            launch.location.send(launch.fix(walked: metres))
        }
        #expect(launch.walk.phase == .walk)
        launch.clock.advance(45)
        launch.location.send(launch.fix(walked: 290))  // 10 m out: inside the 18 m radius
        #expect(launch.walk.phase == .arrived)
        #expect(launch.walk.metrics?.arrived == true)
        #expect(!launch.location.running)  // GPS stops on arrival
    }

    @Test func aPlacePickedBeforeGPSIsPlannedFromTheFirstFix() async {
        let launch = Launch()
        launch.routes.distanceM = 380
        launch.walk.choose(TestWalk.park)
        #expect(launch.walk.planner.plannedDistanceM == nil)
        #expect(launch.routes.requestedFrom.isEmpty)
        launch.location.send(launch.fix(walked: 0))
        await settle()
        #expect(launch.routes.requestedFrom == [TestWalk.start])
        #expect(launch.walk.planner.plannedFromRoute)
        #expect(launch.walk.planner.plannedDistanceM == 380)
    }

    @Test func aRoutedWalkRefreshesTheRouteFromWhereItWasAsked() async {
        let launch = Launch()
        launch.routes.distanceM = 380
        await launch.startWalk()
        #expect(launch.walk.engine?.session.routed == true)
        launch.clock.advance(60)
        launch.location.send(launch.fix(walked: 70))  // a minute on: the route is refreshed from here
        await settle()
        #expect(launch.routes.requestedFrom.count == 2)
        #expect(launch.routes.requestedFrom.last == launch.fix(walked: 70).coordinate)
        launch.walk.tick()
        #expect(abs((launch.walk.metrics?.remainingM ?? 0) - 380) < 1e-6)
    }

    @Test func endReturnsToSetupWithGPSOn() async {
        let launch = Launch()
        await launch.startWalk()
        launch.walk.finish()
        #expect(launch.walk.phase == .setup)
        #expect(launch.walk.engine == nil)
        #expect(launch.location.running)
    }
}
