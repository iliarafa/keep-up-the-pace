# M3 — Background, Live Activity and Alerts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A walk keeps tracking with the phone locked. The Live Activity on the lock screen and in the Dynamic Island shows the ±m:ss, the distance left and the arrive-by time, updated at least every 10 s, and the phone buzzes when you fall behind, get ahead or get back on pace. A walk survives a force-quit and can be resumed. **Exit criterion (spec §5, M3):** a real walk with the phone locked, where the Live Activity stays current and buzzes on status changes. You check this on your iPhone with the device-walk checklist that Task 9 writes.

**Architecture:**
- **PaceKit gains the rules**, all covered by `swift test`:
  - `WalkAlerts` decides when to buzz and when to update the Live Activity.
  - `PaceActivityState` is what the Live Activity shows, plus the alert text.
  - `DistanceGate` stops GPS wander counting as walking.
  - A Codable `WalkEngine` and `ActiveWalk` let a walk be saved and resumed.
  - The new alert settings, and drop reasons in `SpeedEstimator` for the device-walk logs.
- **The app gets seams:**
  - `WalkSession` talks to protocols (`LocationProviding`, `RouteProviding`, `LiveActivityControlling`, `FeedbackPlaying`) and takes a clock.
  - A new `KeepThePaceTests` target drives it with fakes. These are spec §4's session tests, deferred from M2.
- **The real implementations:**
  - `LocationService` gets background updates during walks and Precise Location handling.
  - `LiveActivityController` uses ActivityKit.
  - `FeedbackController` uses Core Haptics.
- **Shared code:** `ios/Shared/` is compiled into both the app and the `PaceActivity` extension (`Theme` and `PaceActivityAttributes`). The extension draws the lock-screen and Dynamic Island layouts.

**Tech Stack:** Swift 6 (Xcode 27), SwiftUI, Core Location background updates, ActivityKit and WidgetKit (Live Activity), Core Haptics, OSLog, Swift Testing (PaceKit and the new app unit tests), XCUITest (the existing demo walk), XcodeGen.

**Spec:** `docs/superpowers/specs/2026-09-22-ios-watch-app-design.md` (amended 2026-09-23). This plan implements milestone **M3**. The previous plan (`docs/superpowers/plans/2026-09-23-ios-m2-iphone-core.md`) delivered M2.

**Prototyped before writing:** every code block in this plan was built and run in a scratch copy, task by task.
- `swift test` passes after each task.
- The new app unit tests pass (`make test-app`).
- The iOS and watch builds are clean.
- The demo-walk UI test passes.
- A simulated walk with the simulator locked showed, on the lock screen and in the Dynamic Island:
  - the Live Activity updating in the background;
  - a "Falling behind" alert sent at −0:30;
  - the arrived state;
  - "Not updating" after a force-quit;
  - Resume taking over the same Live Activity.

## Global Constraints

- **Build:** minimum OS iOS 17.0, Swift 6 language mode (`SWIFT_VERSION: "6.0"` in `ios/project.yml`). The code must compile with **no errors and no warnings**. The only exception is Xcode's informational `appintentsmetadataprocessor … Metadata extraction skipped` line.
- **PaceKit stays Foundation-only:** no UIKit, SwiftUI, CoreLocation, MapKit, ActivityKit, CoreHaptics or HealthKit imports. Rules go in PaceKit, where `swift test` covers them; the app layer only wires and draws.
- **Pace colour (spec §3):** everywhere, including the Live Activity, the ±m:ss colour and its "early", "late" or "on time" label follow `Format.delta(sec:)`'s `DeltaTone` (within 3 s counts as on time). `PaceStatus`, driven by the 15, 30 or 60 s threshold, only decides when the phone buzzes.
- **Alerts (spec §2, "Walk tracked on iPhone"):**
  - `PaceStatusMachine` decides when the status changes: threshold from Settings (default 30 s), 5 s recovery margin.
  - On a change, the app plays a haptic if it is active. Otherwise it sends a Live Activity update with an `AlertConfiguration`.
  - Routine Live Activity updates without an alert go out at most every 10 s.
  - With "iPhone haptics" off, nothing buzzes.
- **Live Activity (spec §1):**
  - The attributes hold the destination name and the arrive-by time, plus the walk's start time to identify it.
  - The content state holds `deltaSec`, `status`, `remainingM`, `units`, `arrived`, `trackingDevice` and `locationPaused`.
  - Lock screen: destination, ±m:ss in the pace colour, distance left and arrive-by.
  - Dynamic Island compact view: ±m:ss on the leading side, distance on the trailing side. The expanded view has the full layout.
- **Stale and end (spec §2):** every update sets a `staleDate` 2 minutes later. On arrival, the Live Activity ends showing the final state and is dismissed after 4 minutes. End removes it at once.
- **Force-quit (spec §2):** a real walk in progress is saved under `activeWalk.v1`. The next launch offers Resume or End.
- **Location:**
  - Permission is "When In Use" only, and it is never requested at launch.
  - Background updates run only during a real walk, with the blue location indicator on.
  - Setup GPS stops when the app goes to the background.
- **Location paused (spec §2):** if location is turned off mid-walk, the walk screen shows its banner and the Live Activity shows "Location paused". The walk isn't ended.
- **Settings (spec §3):**
  - M3 adds Alert threshold (15, 30 or 60 s; default 30) and iPhone haptics (default on).
  - Watch haptics, Save walks to Health and Prefer Apple Watch arrive with M4–M6.
  - `AppSettings` decoding stays tolerant.
- **Persistence:** the App Group defaults (`group.com.iliasrafailidis.delta`) keep `settings.v1`, `favorites.v1` and `recents.v1`, and add `activeWalk.v1`.
- **Project:**
  - `ios/project.yml` is the source of truth. Every `make` target that builds runs `xcodegen generate` first, so new files are picked up.
  - `ios/Shared/` is compiled into both the app and the PaceActivity extension.
- **IDs:** bundle IDs, App Group and team are unchanged. The unit-test bundle is `com.iliasrafailidis.delta.tests`.
- **Repo rules:**
  - Do not modify anything under `src/`.
  - Commits go on `main` and end with the line `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
  - Never stage `.claude/` or `.superpowers/`.
- **Commands** run from the repo root unless a step says `cd ios` or `cd ios/PaceKit`.

## Decisions this plan makes

The spec leaves these open; this plan settles them as follows:
1. **Demo walks** show the Live Activity and play haptics too, as a preview. They never use background GPS and are never saved for Resume.
2. **Arriving doesn't buzz.** Only status changes do (spec §2). The Live Activity ends showing "Arrived m:ss early/late".
3. **"iPhone haptics" off silences both** the in-app haptic and the lock-screen alert. The Live Activity keeps updating.
4. **A saved walk is offered for Resume** only while its arrive-by is less than an hour past. Older ones are dropped without asking.
5. **The screen may auto-lock during a walk.** The web app holds a wake lock because a browser can't track in the background. Background location and the Live Activity replace it.
6. **GPS wander:** a fix counts towards the distance walked only once it is more than twice its accuracy (clamped to 5–50 m) from the last counted point. The uncounted stretch still goes into the live numbers, so nothing lags.
7. **Precise Location off:** the setup screen shows a prompt that asks iOS for precise location for this walk (temporary full accuracy), instead of waiting for GPS forever.
8. **Simulated walks** use `xcrun simctl location` through `make sim-walk`, instead of the GPX files the spec's layout lists.
9. **Alert wording:** the titles are "Falling behind", "Ahead of schedule" and "Back on pace". The body is the ±m:ss and the distance left, e.g. "−0:45 · 0.4 mi to go".
10. **No notification permission is requested.** Spec §3 asks for it "only if Live Activity alerts need them". An alert-flagged Live Activity update lights up the lock screen and plays its sound without notification permission, so none is requested.

## Out of scope for M3

These come in later milestones, so do not build them now:
- Saving walks to Health, and the End rule that depends on it: save only if the walk lasted at least 60 s and covered at least 50 m (M4).
- Anything on the Watch (M5–M6).
- The first-launch explainer, the accessibility pass and the app icon (M7).
- Live Activities updated by push.

## File map

```
ios/
  project.yml                     KeepThePaceTests target + scheme test action (T1); Shared/ in app and extension (T5);
                                  precise-location purpose string (T6)
  Makefile                        test-app, test-ui runs only the UI test (T1); sim-start, sim-walk (T9)
  PaceKit/Sources/PaceKit/
    AppSettings.swift             alert threshold, iPhone haptics                                   (T2)
    PaceStatusMachine.swift       starting status, Codable                                          (T2)
    DistanceGate.swift            new: GPS wander filter                                            (T3)
    RouteTracker.swift            uses DistanceGate, Codable                                        (T3)
    WalkEngine.swift              uses DistanceGate, Codable, route refresh from the request point   (T3)
    ActiveWalk.swift              new: the saved walk and when to offer it                          (T3)
    PaceActivityState.swift       new: Live Activity content, alert text, TrackingDevice            (T4)
    WalkAlerts.swift              new: when to buzz and when to update the Live Activity            (T4)
    SpeedEstimator.swift          why a reading was dropped                                         (T6)
  PaceKit/Tests/PaceKitTests/     tests for each of the above                                       (T2–T4, T6)
  Shared/                         compiled into KeepThePace and PaceActivity
    Theme.swift                   moved from KeepThePace/                                           (T5)
    PaceActivityAttributes.swift  new                                                               (T5)
  PaceActivity/
    PaceActivityBundle.swift      the widget bundle only                                            (T5)
    PaceLiveActivity.swift        new: lock screen and Dynamic Island                               (T5)
  KeepThePace/
    WalkServices.swift            new: the seams                                                    (T1, T6, T7)
    LocationService.swift         LocationProviding (T1); background, precise, drop logs            (T6)
    RouteService.swift            RouteProviding (T1); logs route failures                          (T6)
    WalkSession.swift             seams (T1); background (T6); Live Activity and alerts (T7); resume (T8)
    LiveActivityController.swift  new: ActivityKit                                                  (T7)
    FeedbackController.swift      new: Core Haptics                                                 (T7)
    SavedData.swift               activeWalk                                                        (T8)
    RootView.swift                scene phase                                                       (T6)
    SetupView.swift               Precise Location prompt (T6); Resume card                         (T8)
    SettingsView.swift            Alerts section                                                    (T7)
  KeepThePaceTests/               new: app unit tests
    Fakes.swift, Launch.swift, WalkFlowTests.swift                                                  (T1)
    BackgroundLocationTests.swift                                                                   (T6)
    ActivityFakes.swift, LiveActivityAlertTests.swift                                               (T7)
    ResumeTests.swift                                                                               (T8)
docs/checklists/m3-device-walk.md  new: the M3 exit walk                                            (T9)
CLAUDE.md                         iOS section                                                       (T9)
```

## Testing approach

- **PaceKit:** test-first for every rule (`cd ios && make test`).
- **App:** `WalkSession` unit tests run with fake GPS, routing, Live Activity, haptics and clock (`cd ios && make test-app`). They cover the walk, background GPS, when Live Activity updates and alerts fire, and resuming. These are spec §4's session tests. The Watch takeover arrives in M6, and the End discard rule in M4.
- **UI:** the demo-walk UI test must keep passing (`cd ios && make test-ui`).
- **Simulator:** a simulated walk with the simulator locked (Task 9).
- **Device:** your walk with `docs/checklists/m3-device-walk.md`. This is the M3 exit.
- **Simulator hiccups:** now and then `xcodebuild` reports `Simulator device failed to launch … No such process` and runs no tests at all. That's the simulator, not the code: run the same command again. It happened once while this plan was being checked, and the rerun passed.

Test counts after each task:

| After | PaceKit (`make test`) | App (`make test-app`) |
|---|---|---|
| start | 82 tests in 14 suites | none |
| Task 1 | 82 in 14 | 4 tests in 1 suite |
| Task 2 | 86 in 14 | 4 in 1 |
| Task 3 | 97 in 16 | 4 in 1 |
| Task 4 | 106 in 17 | 4 in 1 |
| Task 5 | 106 in 17 | 4 in 1 |
| Task 6 | 109 in 17 | 7 in 2 |
| Task 7 | 109 in 17 | 13 in 3 |
| Task 8 | 109 in 17 | 18 in 4 |

---

### Task 1: `WalkSession` test seams and the app unit-test target

The M2 review found that `WalkSession` has logic of its own, but its GPS, routing and clock were hard-wired, so it had no automated tests. This task puts those behind small protocols and adds a hosted unit-test target. Four tests then check M2's existing behaviour through the seams. No behaviour changes in this task.

**Files:**
- Modify: `ios/project.yml` (new `KeepThePaceTests` target; the scheme's test action)
- Modify: `ios/Makefile` (new `test-app`; `test-ui` runs only the UI test)
- Create: `ios/KeepThePaceTests/Fakes.swift`, `ios/KeepThePaceTests/Launch.swift`, `ios/KeepThePaceTests/WalkFlowTests.swift`
- Create: `ios/KeepThePace/WalkServices.swift`
- Modify (full replacement): `ios/KeepThePace/LocationService.swift`, `ios/KeepThePace/WalkSession.swift`
- Modify: `ios/KeepThePace/RouteService.swift`

**Interfaces:**
- Consumes (M2):
  - `FixSource` (`onFix`, `start()`, `stop()`)
  - `WalkPlanner.choose/originFound/routeResolved/beginSession`
  - `WalkEngine`
  - `SavedData(defaults:)`
- Produces:
  - `enum LocationAccess { notDetermined, allowed, denied }` (replaces `LocationService.Access`)
  - `protocol LocationProviding: FixSource { var access: LocationAccess { get }; var latestFix: GPSFix? { get } }`
  - `protocol RouteProviding { func walkingDistanceM(from:to:) async -> Double? }`
  - `WalkSession.init(saved:location:search:routes:clock:tickInterval:)`
  - `WalkSession.tick()` (internal; recomputes the metrics)
- Produces, test side:
  - `FakeLocation` (`send(_:)`, `running`), `FakeRoutes` (`distanceM`, `requestedFrom`), `TestClock` (`now`, `advance(_:)`)
  - `TestWalk` (`park`, `start`, `fix(walked:at:)`)
  - `Launch` (`clock`, `defaults`, `saved`, `location`, `routes`, `walk`, `fix(walked:)`, `startWalk()`)
  - `settle()`

- [ ] **Step 1: Add the unit-test target**

In `ios/project.yml`, replace:

```yaml
  KeepThePaceUITests:
    type: bundle.ui-testing
```

with:

```yaml
  KeepThePaceTests:
    type: bundle.unit-test
    platform: iOS
    sources: [KeepThePaceTests]
    dependencies:
      - target: KeepThePace
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.iliasrafailidis.delta.tests
        TARGETED_DEVICE_FAMILY: "1"
  KeepThePaceUITests:
    type: bundle.ui-testing
```

XcodeGen hosts a unit-test bundle in the app it depends on, so the tests can `@testable import KeepThePace`. The tests `import PaceKit` through the app's build products; don't add PaceKit as a dependency of the test target too. That would link a second copy of it.

In `ios/project.yml`, replace:

```yaml
      targets:
        - KeepThePaceUITests
```

with:

```yaml
      targets:
        - KeepThePaceTests
        - KeepThePaceUITests
```

- [ ] **Step 2: Add `make test-app`**

In `ios/Makefile`, replace:

```make
.PHONY: generate test golden build-ios build-watch test-ui
```

with:

```make
.PHONY: generate test golden build-ios build-watch test-app test-ui
```

In `ios/Makefile`, replace:

```make
# The demo-walk UI test on the iPhone simulator. Takes about 3 minutes. Not -quiet, so the
# per-test results and "** TEST SUCCEEDED **" are printed.
test-ui: generate
	xcodebuild -project KeepThePace.xcodeproj -derivedDataPath build CODE_SIGNING_ALLOWED=NO -scheme KeepThePace -destination 'platform=iOS Simulator,name=$(SIM_IPHONE)' test
```

with:

```make
# The app's unit tests (WalkSession with fake GPS, routing, Live Activity and haptics) on the
# iPhone simulator. Not -quiet, so the per-test results and "** TEST SUCCEEDED **" are printed.
test-app: generate
	xcodebuild -project KeepThePace.xcodeproj -derivedDataPath build CODE_SIGNING_ALLOWED=NO -scheme KeepThePace -destination 'platform=iOS Simulator,name=$(SIM_IPHONE)' -only-testing:KeepThePaceTests test

# The demo-walk UI test on the iPhone simulator. Takes about 3 minutes. Not -quiet, so the
# per-test results and "** TEST SUCCEEDED **" are printed.
test-ui: generate
	xcodebuild -project KeepThePace.xcodeproj -derivedDataPath build CODE_SIGNING_ALLOWED=NO -scheme KeepThePace -destination 'platform=iOS Simulator,name=$(SIM_IPHONE)' -only-testing:KeepThePaceUITests test
```

The Makefile recipe lines start with a tab.

- [ ] **Step 3: Write the fakes and the test harness**

Create `ios/KeepThePaceTests/Fakes.swift`:

```swift
import Foundation
import PaceKit
@testable import KeepThePace

/// GPS the test drives by hand: `send(_:)` is a reading arriving.
@MainActor
final class FakeLocation: LocationProviding {
    var onFix: ((GPSFix) -> Void)?
    var access: LocationAccess = .allowed
    private(set) var latestFix: GPSFix?
    private(set) var running = false

    func start() { running = true }

    func stop() {
        running = false
        latestFix = nil
    }

    func send(_ fix: GPSFix) {
        latestFix = fix
        onFix?(fix)
    }
}

/// Apple Maps stand-in: answers every request with `distanceM` and records where it was asked from.
@MainActor
final class FakeRoutes: RouteProviding {
    var distanceM: Double?
    private(set) var requestedFrom: [LatLon] = []

    func walkingDistanceM(from start: LatLon, to end: LatLon) async -> Double? {
        requestedFrom.append(start)
        return distanceM
    }
}

/// A clock the test moves by hand.
final class TestClock {
    var now = Date(timeIntervalSince1970: 1_800_000_000)

    func advance(_ seconds: TimeInterval) { now += seconds }
}
```

Create `ios/KeepThePaceTests/Launch.swift`:

```swift
import Foundation
import PaceKit
@testable import KeepThePace

/// The walk the tests take: from 300 m due south of Bryant Park, straight to it.
enum TestWalk {
    static let park = Place(name: "Bryant Park", area: "Manhattan", coordinate: LatLon(lat: 40.7536, lon: -73.9832))
    static let start = Geo.destinationPoint(from: park.coordinate, bearingDeg: 180, distanceM: 300)

    static func fix(walked metres: Double, at time: Date) -> GPSFix {
        GPSFix(
            coordinate: Geo.moveTowards(from: start, to: park.coordinate, distanceM: metres), speedMps: 1.3,
            accuracyM: 5, timestamp: time)
    }
}

/// One app launch: a `WalkSession` wired to fakes, with the ticker off (tests call `tick()`).
@MainActor
struct Launch {
    let clock: TestClock
    let defaults: UserDefaults
    let saved: SavedData
    let location = FakeLocation()
    let routes = FakeRoutes()
    let walk: WalkSession

    /// Each launch gets empty storage of its own. Pass an earlier launch's `defaults` and `clock`
    /// to open the app again with what that launch saved.
    init(defaults: UserDefaults = UserDefaults(suiteName: "KeepThePaceTests.\(UUID().uuidString)")!,
         clock: TestClock = TestClock()) {
        self.clock = clock
        self.defaults = defaults
        saved = SavedData(defaults: defaults)
        walk = WalkSession(
            saved: saved, location: location, routes: routes, clock: { [clock] in clock.now }, tickInterval: nil)
    }

    /// A GPS reading `metres` along the test walk, stamped now.
    func fix(walked metres: Double) -> GPSFix {
        TestWalk.fix(walked: metres, at: clock.now)
    }

    /// GPS ready at the start point, the park picked, the walk started.
    func startWalk() async {
        location.send(fix(walked: 0))
        walk.choose(TestWalk.park)
        await settle()
        walk.startWalking()
    }
}

/// Lets tasks the session started (route requests) run to completion.
@MainActor
func settle() async {
    for _ in 0..<10 { await Task.yield() }
}
```

- [ ] **Step 4: Write the walk-flow tests**

Create `ios/KeepThePaceTests/WalkFlowTests.swift`:

```swift
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
```

- [ ] **Step 5: Run the tests to see them fail**

Run: `cd ios && make test-app > /tmp/ktp-t1.log 2>&1; echo "exit $?"; grep -oE "cannot find type '[A-Za-z]+' in scope" /tmp/ktp-t1.log | sort -u`
Expected: a non-zero exit, with `cannot find type 'LocationProviding' in scope` and `cannot find type 'RouteProviding' in scope` among the errors. The seams don't exist yet.

- [ ] **Step 6: Add the seams**

Create `ios/KeepThePace/WalkServices.swift`:

```swift
import Foundation
import PaceKit

/// Whether the app may use location.
enum LocationAccess {
    case notDetermined, allowed, denied
}

/// The live GPS as `WalkSession` sees it: `LocationService` in the app, a fake in tests.
@MainActor
protocol LocationProviding: FixSource {
    var access: LocationAccess { get }
    /// The latest accepted fix, or nil until one arrives.
    var latestFix: GPSFix? { get }
}

/// Walking distance along streets: `RouteService` (Apple Maps) in the app, a fake in tests.
@MainActor
protocol RouteProviding {
    func walkingDistanceM(from start: LatLon, to end: LatLon) async -> Double?
}
```

Replace the whole of `ios/KeepThePace/LocationService.swift` with the version below. The only changes are the top-level `LocationAccess` and the `LocationProviding` conformance:

```swift
import CoreLocation
import Observation
import PaceKit

/// Foreground GPS ("When In Use"). Readings go through PaceKit's `SpeedEstimator`, which drops
/// inaccurate and stale ones and smooths the speed. Background updates come in M3.
@MainActor
@Observable
final class LocationService: NSObject, LocationProviding, CLLocationManagerDelegate {
    private(set) var access: LocationAccess = .notDetermined
    /// The latest accepted fix, or nil until one arrives.
    private(set) var latestFix: GPSFix?
    @ObservationIgnored var onFix: ((GPSFix) -> Void)?
    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var estimator = SpeedEstimator()
    @ObservationIgnored private var wantsUpdates = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .fitness
        access = Self.access(for: manager.authorizationStatus)
    }

    /// Starts updates, asking for permission first if the user hasn't been asked yet.
    func start() {
        wantsUpdates = true
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    func stop() {
        wantsUpdates = false
        manager.stopUpdatingLocation()
        estimator = SpeedEstimator()
        latestFix = nil
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Delegate calls arrive on the main thread, where the manager was created.
        MainActor.assumeIsolated {
            access = Self.access(for: self.manager.authorizationStatus)
            if access == .allowed, wantsUpdates {
                self.manager.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        MainActor.assumeIsolated {
            for location in locations {
                accept(location)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Transient failures (no fix yet) are normal; denial arrives via the authorization callback.
    }

    private func accept(_ location: CLLocation) {
        guard let fix = estimator.accept(
            coordinate: LatLon(location.coordinate),
            reportedSpeedMps: location.speed,
            accuracyM: location.horizontalAccuracy,
            timestamp: location.timestamp,
            receivedAt: .now)
        else { return }
        latestFix = fix
        onFix?(fix)
    }

    private static func access(for status: CLAuthorizationStatus) -> LocationAccess {
        switch status {
        case .notDetermined: .notDetermined
        case .authorizedWhenInUse, .authorizedAlways: .allowed
        default: .denied
        }
    }
}
```

Append to `ios/KeepThePace/RouteService.swift`:

```swift

extension RouteService: RouteProviding {}
```

Replace the whole of `ios/KeepThePace/WalkSession.swift` with the version below. It takes the GPS, routing, a clock and the tick interval as parameters, and `tick()` is internal so tests can call it. Every other line is M2's:

```swift
import Foundation
import Observation
import PaceKit

/// The app's walk flow: setup → walk → arrived. Planning rules, pace maths and arrival live in
/// PaceKit (`WalkPlanner`, `Session.begin`, `WalkEngine`); this class wires them to the GPS, the
/// demo walk, Apple Maps routing and a one-second clock. The GPS, routing and clock can be
/// replaced by fakes in tests.
@MainActor
@Observable
final class WalkSession {
    enum Phase {
        case setup, walk, arrived
    }

    private(set) var phase: Phase = .setup
    private(set) var planner = WalkPlanner()
    private(set) var engine: WalkEngine?
    private(set) var metrics: WalkMetrics?

    let location: any LocationProviding
    let search: PlaceSearchService
    @ObservationIgnored private let routes: any RouteProviding
    @ObservationIgnored private let saved: SavedData
    @ObservationIgnored private let clock: () -> Date
    @ObservationIgnored private let tickInterval: Duration?
    @ObservationIgnored private var demo: DemoLocationSource?
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var walkID = 0
    @ObservationIgnored private var refreshingRoute = false

    /// `clock` and `tickInterval` exist for tests: a test passes its own clock and a nil interval,
    /// and calls `tick()` itself.
    init(
        saved: SavedData, location: any LocationProviding = LocationService(),
        search: PlaceSearchService = PlaceSearchService(), routes: any RouteProviding = RouteService(),
        clock: @escaping () -> Date = { .now }, tickInterval: Duration? = .seconds(1)
    ) {
        self.saved = saved
        self.location = location
        self.search = search
        self.routes = routes
        self.clock = clock
        self.tickInterval = tickInterval
        location.onFix = { [weak self] fix in self?.liveFix(fix) }
    }

    /// The latest live GPS fix, used as the walk's start point.
    var origin: GPSFix? { location.latestFix }

    var canStart: Bool { planner.canStart(hasLocation: origin != nil) }

    // MARK: Setup

    /// Starts GPS for the setup screen if the user already allowed it. The permission prompt
    /// waits until they search or tap Start.
    func setupAppeared() {
        if location.access == .allowed { location.start() }
    }

    /// Starts GPS, asking for permission first if needed. Called on the first search and from the
    /// "Enable location" prompt (spec: location is requested at the moment it's needed).
    func requestLocation() {
        location.start()
    }

    func choose(_ place: Place) {
        let from = origin?.coordinate
        guard let planID = planner.choose(place, from: from, now: clock()), let from else { return }
        routePlan(planID, from: from, to: place.coordinate)
    }

    /// Upgrades the plan to the walking-route distance when Apple Maps answers.
    private func routePlan(_ planID: Int, from: LatLon, to: LatLon) {
        Task {
            let distance = await routes.walkingDistanceM(from: from, to: to)
            planner.routeResolved(planID: planID, distanceM: distance, now: clock())
        }
    }

    func bumpArriveBy(minutes: Int) {
        planner.bump(minutes: minutes, now: clock())
    }

    func setArriveBy(_ picked: Date) {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: picked)
        planner.setArriveBy(hour: parts.hour ?? 0, minute: parts.minute ?? 0, now: clock(), calendar: .current)
    }

    // MARK: Walking

    func startWalking() {
        guard let fix = origin, let session = planner.beginSession(from: fix.coordinate, now: clock()) else {
            location.start()
            return
        }
        begin(session, firstFix: fix)
    }

    /// A simulated walk to the chosen destination (or the default demo destination), 280 m away.
    func startDemo() {
        let dest = planner.destination ?? DemoWalk.defaultDestination
        let start = DemoWalk.startPoint(for: dest.coordinate)
        let now = clock()
        let session = Session.begin(
            dest: dest, from: start, plannedDistanceM: nil,
            arriveBy: DemoWalk.arriveBy(start: start, dest: dest.coordinate, now: now),
            now: now, demo: true, routed: false)
        location.stop()
        let source = DemoLocationSource(start: start, dest: dest.coordinate, now: now)
        source.onFix = { [weak self] fix in self?.walkFix(fix) }
        demo = source
        begin(session, firstFix: nil)
        source.start()
    }

    /// Ends the walk (End) or leaves the arrived screen (Done).
    func finish() {
        stopWalk()
        engine = nil
        metrics = nil
        phase = .setup
        if location.access == .allowed { location.start() }
    }

    private func begin(_ session: Session, firstFix: GPSFix?) {
        walkID += 1
        refreshingRoute = false
        engine = WalkEngine(session: session)
        saved.recents.record(session.dest)
        phase = .walk
        if let firstFix { walkFix(firstFix) }
        guard let tickInterval else { return }
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: tickInterval)
                self?.tick()
            }
        }
    }

    private func liveFix(_ fix: GPSFix) {
        switch phase {
        case .setup:
            // A place picked before the first fix is planned from here.
            if let planID = planner.originFound(fix.coordinate, now: clock()), let dest = planner.destination {
                routePlan(planID, from: fix.coordinate, to: dest.coordinate)
            }
        case .walk:
            guard engine?.session.demo == false else { return }
            walkFix(fix)
            refreshRouteIfDue()
        case .arrived:
            break
        }
    }

    private func walkFix(_ fix: GPSFix) {
        engine?.ingest(fix)
        tick()
    }

    /// Recomputes the walk's numbers. Runs on every fix and once a second.
    func tick() {
        guard phase == .walk else { return }
        metrics = engine?.metrics(now: clock())
        if metrics?.arrived == true {
            stopWalk()
            phase = .arrived
        }
    }

    private func refreshRouteIfDue() {
        guard !refreshingRoute, let engine, engine.needsRouteRefresh(now: clock()), let from = engine.lastFix else { return }
        refreshingRoute = true
        let id = walkID
        let to = engine.session.dest.coordinate
        Task {
            let distance = await routes.walkingDistanceM(from: from.coordinate, to: to)
            guard id == walkID else { return }
            if let distance {
                self.engine?.routeRefreshed(distanceM: distance, now: clock())
            } else {
                self.engine?.routeRefreshFailed(now: clock())
            }
            refreshingRoute = false
        }
    }

    private func stopWalk() {
        ticker?.cancel()
        ticker = nil
        demo?.stop()
        demo = nil
        if engine?.session.demo == false { location.stop() }
    }
}
```

`SetupView` and `WalkView` read `walk.location.access` and compare it with `.allowed`, `.denied` and `.notDetermined`. Those keep compiling against `LocationAccess` unchanged.

- [ ] **Step 7: Run the tests to see them pass**

Run: `cd ios && make test-app > /tmp/ktp-t1.log 2>&1; echo "exit $?"; grep -E "Test run with|TEST SUCCEEDED|TEST FAILED|error:|warning:" /tmp/ktp-t1.log | grep -v appintentsmetadataprocessor`
Expected: `exit 0`, `✔ Test run with 4 tests in 1 suite passed` and `** TEST SUCCEEDED **`. There should be no `warning:` lines. Several simulators may be booted, and two may be named "iPhone 17"; xcodebuild then says it uses the first match, which is fine.

- [ ] **Step 8: Check the rest still builds and passes**

Run each:
1. `cd ios && make test 2>&1 | tail -1`: `Test run with 82 tests in 14 suites passed`, with no warnings.
2. `cd ios && make build-ios > /tmp/ktp-b1.log 2>&1; echo "exit $?"; grep -E "error:|warning:" /tmp/ktp-b1.log | grep -v appintentsmetadataprocessor`: `exit 0` and no grep output.

- [ ] **Step 9: Commit**

```bash
git add ios/project.yml ios/Makefile ios/KeepThePaceTests ios/KeepThePace/WalkServices.swift ios/KeepThePace/LocationService.swift ios/KeepThePace/RouteService.swift ios/KeepThePace/WalkSession.swift
git commit -m "iOS: WalkSession test seams and the app unit-test target

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Alert settings and a status machine that can resume

**Files:**
- Modify (full replacement): `ios/PaceKit/Sources/PaceKit/AppSettings.swift`, `ios/PaceKit/Sources/PaceKit/PaceStatusMachine.swift`
- Test (full replacement): `ios/PaceKit/Tests/PaceKitTests/AppSettingsTests.swift`, `ios/PaceKit/Tests/PaceKitTests/PaceStatusMachineTests.swift`

**Interfaces:**
- Produces:
  - `enum AlertThreshold: Int { fifteen = 15, thirty = 30, sixty = 60 }` with `seconds: Double`
  - `AppSettings.alertThreshold` (default `.thirty`) and `AppSettings.phoneHaptics` (default `true`)
  - `AppSettings.init(units:alertThreshold:phoneHaptics:)`
  - `PaceStatusMachine.init(thresholdSec:recoveryMarginSec:status:)`, and `PaceStatusMachine` is now `Codable, Hashable`

- [ ] **Step 1: Write the failing tests**

Replace the whole of `ios/PaceKit/Tests/PaceKitTests/AppSettingsTests.swift` with:

```swift
import Foundation
import Testing
@testable import PaceKit

@Suite struct AppSettingsTests {
    func decode(_ json: String) throws -> AppSettings {
        try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
    }

    @Test func defaults() {
        let s = AppSettings()
        #expect(s.units == .auto)
        #expect(s.alertThreshold == .thirty)
        #expect(s.phoneHaptics)
    }

    @Test func roundTrips() throws {
        let s = AppSettings(units: .metric, alertThreshold: .sixty, phoneHaptics: false)
        let data = try JSONEncoder().encode(s)
        #expect(try JSONDecoder().decode(AppSettings.self, from: data) == s)
    }

    @Test func missingOrUnknownValuesFallBackToDefaults() throws {
        #expect(try decode("{}") == AppSettings())
        #expect(try decode(#"{"units":"furlongs"}"#).units == .auto)
        #expect(try decode(#"{"units":"imperial","someFutureSetting":true}"#).units == .imperial)
        #expect(try decode(#"{"alertThreshold":45,"phoneHaptics":"yes"}"#) == AppSettings())
    }

    @Test func settingsSavedBeforeAlertsKeepTheirUnits() throws {
        // What M2 saved: units only.
        #expect(try decode(#"{"units":"metric"}"#) == AppSettings(units: .metric, alertThreshold: .thirty, phoneHaptics: true))
    }

    @Test func thresholdsAreFifteenThirtyAndSixtySeconds() {
        #expect(AlertThreshold.allCases.map(\.seconds) == [15, 30, 60])
    }

    @Test func autoFollowsTheLocale() {
        #expect(UnitsSetting.auto.resolved(for: Locale(identifier: "en_US")) == .imperial)
        #expect(UnitsSetting.auto.resolved(for: Locale(identifier: "el_GR")) == .metric)
        #expect(UnitsSetting.metric.resolved(for: Locale(identifier: "en_US")) == .metric)
    }
}
```

Replace the whole of `ios/PaceKit/Tests/PaceKitTests/PaceStatusMachineTests.swift` with:

```swift
import Foundation
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

    @Test func resumesFromASavedStatus() {
        var m = PaceStatusMachine(thresholdSec: 30, status: .behind)
        #expect(m.update(deltaSec: -40) == nil)   // still behind: nothing new to announce
        #expect(m.update(deltaSec: -20) == .onTime)
    }

    @Test func roundTripsThroughJSON() throws {
        var m = PaceStatusMachine(thresholdSec: 15)
        _ = m.update(deltaSec: 20)
        let decoded = try JSONDecoder().decode(PaceStatusMachine.self, from: JSONEncoder().encode(m))
        #expect(decoded == m)
        #expect(decoded.status == .ahead)
    }
}
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `cd ios/PaceKit && swift test 2>&1 | grep -oE "cannot find '[A-Za-z]+' in scope|has no member '[A-Za-z]+'" | sort -u`
Expected: `cannot find 'AlertThreshold' in scope`, `has no member 'alertThreshold'` and `has no member 'phoneHaptics'`.

- [ ] **Step 3: Implement**

Replace the whole of `ios/PaceKit/Sources/PaceKit/AppSettings.swift` with:

```swift
import Foundation

public enum UnitsSetting: String, Codable, Sendable, CaseIterable {
    case auto, imperial, metric

    public func resolved(for locale: Locale) -> Units {
        switch self {
        case .auto: Units.auto(for: locale)
        case .imperial: .imperial
        case .metric: .metric
        }
    }
}

/// How far off schedule counts as ahead or behind for alerts (spec §3: 15, 30 or 60 s).
public enum AlertThreshold: Int, Codable, Sendable, CaseIterable {
    case fifteen = 15
    case thirty = 30
    case sixty = 60

    public var seconds: Double { Double(rawValue) }
}

/// User settings. Decoding is tolerant — a missing or unreadable value falls back to its
/// default — so fields added in later versions never wipe what the user already chose.
public struct AppSettings: Codable, Equatable, Sendable {
    public var units: UnitsSetting
    public var alertThreshold: AlertThreshold
    /// Buzz on status changes: a haptic in the app, an alert on the Live Activity when locked.
    public var phoneHaptics: Bool

    public init(units: UnitsSetting = .auto, alertThreshold: AlertThreshold = .thirty, phoneHaptics: Bool = true) {
        self.units = units
        self.alertThreshold = alertThreshold
        self.phoneHaptics = phoneHaptics
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        units = (try? values.decodeIfPresent(UnitsSetting.self, forKey: .units)) ?? .auto
        alertThreshold = (try? values.decodeIfPresent(AlertThreshold.self, forKey: .alertThreshold)) ?? .thirty
        phoneHaptics = (try? values.decodeIfPresent(Bool.self, forKey: .phoneHaptics)) ?? true
    }
}
```

Replace the whole of `ios/PaceKit/Sources/PaceKit/PaceStatusMachine.swift` with:

```swift
/// The alert bucket relative to the user's alert threshold (15, 30 or 60 s). It only drives
/// alerts (Watch haptics, Live Activity alert updates); the on-screen readout's colour and
/// label come from `Format.delta(sec:)`'s `DeltaTone`.
public enum PaceStatus: String, Codable, Sendable {
    case ahead, onTime, behind
}

/// Buckets the schedule delta into ahead / on time / behind. To leave ahead or behind,
/// the delta must come back inside the threshold by `recoveryMarginSec`, so hovering at
/// the edge doesn't flip the status (and buzz the user) over and over.
public struct PaceStatusMachine: Codable, Hashable, Sendable {
    public let thresholdSec: Double
    public let recoveryMarginSec: Double
    public private(set) var status: PaceStatus

    /// `status` is where the machine starts: a resumed walk carries on from its saved status, so
    /// it doesn't buzz again for a change it already announced.
    public init(thresholdSec: Double = 30, recoveryMarginSec: Double = 5, status: PaceStatus = .onTime) {
        self.thresholdSec = thresholdSec
        self.recoveryMarginSec = recoveryMarginSec
        self.status = status
    }

    /// Feeds a new delta. Returns the new status only when it changed.
    public mutating func update(deltaSec: Double) -> PaceStatus? {
        guard deltaSec.isFinite else { return nil }
        let next = nextStatus(for: deltaSec)
        guard next != status else { return nil }
        status = next
        return next
    }

    private func nextStatus(for delta: Double) -> PaceStatus {
        if delta >= thresholdSec { return .ahead }
        if delta <= -thresholdSec { return .behind }
        let recovery = thresholdSec - recoveryMarginSec
        switch status {
        case .ahead: return delta < recovery ? .onTime : .ahead
        case .behind: return delta > -recovery ? .onTime : .behind
        case .onTime: return .onTime
        }
    }
}
```

- [ ] **Step 4: Run the tests to see them pass**

Run: `cd ios/PaceKit && swift test 2>&1 | tail -1`
Expected: `Test run with 86 tests in 14 suites passed`, with no warnings.

- [ ] **Step 5: Commit**

```bash
git add ios/PaceKit
git commit -m "PaceKit: alert threshold and iPhone haptics settings; status machine can resume

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Task 3: GPS wander filter, a resumable engine, and route refreshes from the request point

**What this fixes:**
- Two readings of a phone standing still differ by a few metres. M2 added every such jump to the distance walked, and to the route progress. The final review measured 148 m of "walking" in 50 s of standing still. `DistanceGate` stops that.
- The engine becomes Codable so a walk can be saved (Task 8).
- A route refresh is now applied for the point it was requested from. The final review found it applied at a later fix.

**Files:**
- Create: `ios/PaceKit/Sources/PaceKit/DistanceGate.swift`, `ios/PaceKit/Sources/PaceKit/ActiveWalk.swift`
- Modify (full replacement): `ios/PaceKit/Sources/PaceKit/RouteTracker.swift`, `ios/PaceKit/Sources/PaceKit/WalkEngine.swift`
- Test: create `DistanceGateTests.swift` and `ActiveWalkTests.swift`; full replacement of `RouteTrackerTests.swift` and `WalkEngineTests.swift` (all in `ios/PaceKit/Tests/PaceKitTests/`)
- Modify: `ios/KeepThePace/WalkSession.swift` (one call)

**Interfaces:**
- Consumes: `Geo.haversineM`, `Session`, `GPSFix`, `PaceStatus`.
- Produces:
  - `DistanceGate`: `stepM(accuracyM:)`, `pendingM(to:)`, `step(to:accuracyM:) -> Double`, `anchor`
  - `RouteTracker.advance(to:accuracyM:)` (accuracy defaults to nil) and `RouteTracker.movedM`; `RouteTracker` is now `Codable, Hashable`
  - `WalkEngine` is now `Codable, Equatable`, and `walkedM` is a computed property
  - `WalkEngine.routeRefreshed(distanceM:from:now:)` replaces `routeRefreshed(distanceM:now:)`
  - `ActiveWalk(engine:status:)`, `ActiveWalk.isResumable(now:)`, `ActiveWalk.resumeWindowSec` (3600)

- [ ] **Step 1: Write the failing tests**

Create `ios/PaceKit/Tests/PaceKitTests/DistanceGateTests.swift`:

```swift
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
```

Create `ios/PaceKit/Tests/PaceKitTests/ActiveWalkTests.swift`:

```swift
import Foundation
import Testing
@testable import PaceKit

@Suite struct ActiveWalkTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let dest = Place(name: "Bryant Park", area: "Manhattan", coordinate: LatLon(lat: 40.7536, lon: -73.9832))

    func walk(arriveIn seconds: TimeInterval, routed: Bool = false) -> ActiveWalk {
        let start = Geo.destinationPoint(from: dest.coordinate, bearingDeg: 180, distanceM: 800)
        let session = Session(
            dest: dest, start: start, startDistanceM: routed ? 950 : 800, startAt: now - 300,
            arriveBy: now + seconds, demo: false, routed: routed)
        var engine = WalkEngine(session: session)
        engine.ingest(GPSFix(coordinate: start, speedMps: 1.3, accuracyM: 5, timestamp: now - 300))
        engine.ingest(GPSFix(
            coordinate: Geo.moveTowards(from: start, to: dest.coordinate, distanceM: 350), speedMps: 1.3,
            accuracyM: 5, timestamp: now - 10))
        return ActiveWalk(engine: engine, status: .behind)
    }

    @Test func resumableUntilAnHourAfterArriveBy() {
        #expect(walk(arriveIn: 600).isResumable(now: now))
        #expect(walk(arriveIn: -3599).isResumable(now: now))
        #expect(!walk(arriveIn: -3600).isResumable(now: now))
    }

    @Test func arrivedWalkIsNotResumable() {
        var active = walk(arriveIn: 600)
        active.engine.ingest(GPSFix(coordinate: dest.coordinate, speedMps: 1.3, accuracyM: 5, timestamp: now))
        _ = active.engine.metrics(now: now)
        #expect(!active.isResumable(now: now))
    }

    @Test func roundTripsThroughJSON() throws {
        let active = walk(arriveIn: 600, routed: true)
        let decoded = try JSONDecoder().decode(ActiveWalk.self, from: JSONEncoder().encode(active))
        #expect(decoded == active)
        var a = active.engine
        var b = decoded.engine
        #expect(a.metrics(now: now) == b.metrics(now: now))
        #expect(decoded.status == .behind)
    }
}
```

Replace the whole of `ios/PaceKit/Tests/PaceKitTests/RouteTrackerTests.swift` with the version below. The first six tests are unchanged and `gpsWanderDoesNotEatTheRoute` is new:

```swift
import Foundation
import Testing
@testable import PaceKit

@Suite struct RouteTrackerTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let dest = LatLon(lat: 40.7536, lon: -73.9832)
    var start: LatLon { Geo.destinationPoint(from: dest, bearingDeg: 90, distanceM: 600) }

    func tracker(routeM: Double = 900) -> RouteTracker {
        RouteTracker(routeM: routeM, at: start, straightLineM: 600, now: now)
    }

    @Test func remainingShrinksByDistanceMoved() {
        var t = tracker()
        let step = Geo.moveTowards(from: start, to: dest, distanceM: 100)
        t.advance(to: step)
        #expect(abs(t.remainingM(straightLineM: 500) - 800) < 1e-6)
    }

    @Test func remainingNeverDropsBelowTheStraightLine() {
        var t = tracker(routeM: 620)
        // Walk 200 m away from the destination: route minus movement would be 420 m.
        t.advance(to: Geo.destinationPoint(from: start, bearingDeg: 90, distanceM: 200))
        #expect(t.remainingM(straightLineM: 800) == 800)
    }

    @Test func refreshIsDueAfterSixtySeconds() {
        let t = tracker()
        #expect(!t.needsRefresh(straightLineM: 600, now: now + 59))
        #expect(t.needsRefresh(straightLineM: 600, now: now + 60))
    }

    @Test func refreshIsDueWhenYouDriftOffTheRoute() {
        var t = tracker()
        let away = Geo.destinationPoint(from: start, bearingDeg: 90, distanceM: 40)
        t.advance(to: away)
        // Predicted straight line 600 - 40 = 560, actual 640: off by 80 m.
        #expect(t.needsRefresh(straightLineM: 640, now: now + 5))
        #expect(!t.needsRefresh(straightLineM: 620, now: now + 5))
    }

    @Test func refreshedStartsOver() {
        var t = tracker()
        t.advance(to: Geo.moveTowards(from: start, to: dest, distanceM: 100))
        let here = Geo.moveTowards(from: start, to: dest, distanceM: 100)
        t.refreshed(routeM: 750, at: here, straightLineM: 500, now: now + 60)
        #expect(t.routeM == 750)
        #expect(t.remainingM(straightLineM: 500) == 750)
        #expect(!t.needsRefresh(straightLineM: 500, now: now + 100))
    }

    @Test func failedRefreshKeepsTheEstimateAndWaits() {
        var t = tracker()
        let away = Geo.destinationPoint(from: start, bearingDeg: 90, distanceM: 40)
        t.advance(to: away)
        t.refreshFailed(straightLineM: 640, now: now + 5)
        #expect(abs(t.remainingM(straightLineM: 640) - 860) < 1e-6)
        #expect(!t.needsRefresh(straightLineM: 640, now: now + 30))
        #expect(t.needsRefresh(straightLineM: 640, now: now + 65))
    }

    @Test func gpsWanderDoesNotEatTheRoute() {
        var t = tracker()
        for i in 0..<50 {
            t.advance(to: Geo.destinationPoint(from: start, bearingDeg: i.isMultiple(of: 2) ? 0 : 180, distanceM: 3), accuracyM: 5)
        }
        #expect(t.remainingM(straightLineM: 600) >= 900 - 6.001)
    }
}
```

Replace the whole of `ios/PaceKit/Tests/PaceKitTests/WalkEngineTests.swift` with the version below:
- `routeRefreshOnlyForRoutedWalks` now passes `from: start`.
- Three tests are new at the end.

```swift
import Foundation
import Testing
@testable import PaceKit

@Suite struct WalkEngineTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let dest = Place(name: "Bryant Park", area: "Manhattan", coordinate: LatLon(lat: 40.7536, lon: -73.9832))
    var start: LatLon { Geo.destinationPoint(from: dest.coordinate, bearingDeg: 180, distanceM: 1000) }

    func session(routed: Bool = false, startDistanceM: Double = 1000) -> Session {
        Session(dest: dest, start: start, startDistanceM: startDistanceM, startAt: now, arriveBy: now + 1000,
                demo: false, routed: routed)
    }

    func fix(metresFromStart m: Double, at t: Date, speed: Double? = 1.2) -> GPSFix {
        GPSFix(coordinate: Geo.moveTowards(from: start, to: dest.coordinate, distanceM: m), speedMps: speed,
               accuracyM: 5, timestamp: t)
    }

    @Test func noMetricsBeforeTheFirstFix() {
        var e = WalkEngine(session: session())
        #expect(e.metrics(now: now) == nil)
    }

    @Test func straightLineWalkReportsDistanceHeadingAndDelta() {
        var e = WalkEngine(session: session())
        e.ingest(fix(metresFromStart: 0, at: now))
        e.ingest(fix(metresFromStart: 600, at: now + 500))
        let m = e.metrics(now: now + 500)!
        #expect(abs(m.remainingM - 400) < 1e-6)
        #expect(abs(m.straightLineM - 400) < 1e-6)
        #expect(abs(m.headingDeg - 0) < 0.01 || abs(m.headingDeg - 360) < 0.01)  // due north
        #expect(abs(m.deltaSec - 100) < 1e-6)  // 600 m covered, 500 m due at 1 m/s
        #expect(abs(m.walkedM - 600) < 1e-6)
        #expect(m.speedMps == 1.2)
        #expect(!m.arrived)
    }

    @Test func routedWalkUsesTheRouteDistance() {
        var e = WalkEngine(session: session(routed: true, startDistanceM: 1300))
        e.ingest(fix(metresFromStart: 0, at: now))
        e.ingest(fix(metresFromStart: 300, at: now + 200))
        let m = e.metrics(now: now + 200)!
        #expect(abs(m.remainingM - 1000) < 1e-6)  // 1300 m route minus 300 m walked
    }

    @Test func arrivalFreezesTheDeltaAtArriveByMinusArrivalTime() {
        var e = WalkEngine(session: session())
        e.ingest(fix(metresFromStart: 0, at: now))
        e.ingest(fix(metresFromStart: 985, at: now + 900))  // 15 m out: inside the 18 m radius
        let m = e.metrics(now: now + 900)!
        #expect(m.arrived)
        #expect(m.remainingM == 0)
        #expect(abs(m.deltaSec - 100) < 1e-9)  // arrive-by now+1000, arrived at now+900
        #expect(e.arrivedAt == now + 900)
        // Later fixes and ticks don't change the result.
        e.ingest(fix(metresFromStart: 900, at: now + 950))
        let later = e.metrics(now: now + 2000)!
        #expect(abs(later.deltaSec - 100) < 1e-9)
        #expect(abs(later.walkedM - 985) < 1e-6)
    }

    @Test func routedWalkArrivesOnTheStraightLine() {
        // The route is 1300 m, so about 315 m of route is "left" at the last fix. Arrival is still
        // judged on the 15 m straight line (spec §2).
        var e = WalkEngine(session: session(routed: true, startDistanceM: 1300))
        e.ingest(fix(metresFromStart: 0, at: now))
        e.ingest(fix(metresFromStart: 985, at: now + 900))
        let m = e.metrics(now: now + 900)!
        #expect(m.arrived)
        #expect(m.remainingM == 0)
        #expect(abs(m.deltaSec - 100) < 1e-9)  // arrive-by now+1000, arrived at now+900
    }

    @Test func routeRefreshOnlyForRoutedWalks() {
        var plain = WalkEngine(session: session())
        plain.ingest(fix(metresFromStart: 0, at: now))
        #expect(!plain.needsRouteRefresh(now: now + 120))

        var routed = WalkEngine(session: session(routed: true, startDistanceM: 1300))
        routed.ingest(fix(metresFromStart: 0, at: now))
        #expect(!routed.needsRouteRefresh(now: now + 30))
        #expect(routed.needsRouteRefresh(now: now + 60))
        routed.routeRefreshed(distanceM: 1250, from: start, now: now + 60)
        #expect(!routed.needsRouteRefresh(now: now + 90))
        #expect(abs(routed.metrics(now: now + 90)!.remainingM - 1250) < 1e-6)
        routed.routeRefreshFailed(now: now + 150)
        #expect(!routed.needsRouteRefresh(now: now + 180))
    }

    @Test func standingStillAddsNoDistance() {
        var e = WalkEngine(session: session())
        for i in 0..<60 {
            let spot = Geo.destinationPoint(from: start, bearingDeg: i.isMultiple(of: 2) ? 90 : 270, distanceM: 3)
            e.ingest(GPSFix(coordinate: spot, speedMps: 0, accuracyM: 5, timestamp: now + Double(i)))
        }
        #expect(e.walkedM <= 6.001)
    }

    @Test func routeRefreshTakesOffWhatYouWalkedWhileItWasInFlight() {
        var e = WalkEngine(session: session(routed: true, startDistanceM: 1300))
        e.ingest(fix(metresFromStart: 0, at: now))
        e.ingest(fix(metresFromStart: 100, at: now + 60))  // walked on while the request was out
        e.routeRefreshed(distanceM: 1250, from: start, now: now + 61)
        #expect(abs(e.metrics(now: now + 61)!.remainingM - 1150) < 1e-6)
    }

    @Test func engineRoundTripsThroughJSON() throws {
        var e = WalkEngine(session: session(routed: true, startDistanceM: 1300))
        e.ingest(fix(metresFromStart: 0, at: now))
        e.ingest(fix(metresFromStart: 240, at: now + 200))
        var decoded = try JSONDecoder().decode(WalkEngine.self, from: JSONEncoder().encode(e))
        #expect(decoded == e)
        #expect(decoded.metrics(now: now + 210) == e.metrics(now: now + 210))
    }
}
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `cd ios/PaceKit && swift test 2>&1 | grep -oE "cannot find '[A-Za-z]+' in scope|has no member '[A-Za-z]+'" | sort -u`
Expected: `cannot find 'ActiveWalk' in scope`. The compiler stops at the first test file it can't build, so the missing `DistanceGate` may not be listed yet.

- [ ] **Step 3: Implement the gate**

Create `ios/PaceKit/Sources/PaceKit/DistanceGate.swift`:

```swift
import Foundation

/// Adds up distance moved without counting GPS wander. A fix only counts once it is more than
/// twice its accuracy from the last counted point (at least 5 m, at most 50 m). Two readings of a
/// phone standing still rarely differ by more than that, so standing still adds nothing, while
/// walking adds the whole way. The stretch not yet counted is `pendingM(to:)`.
public struct DistanceGate: Codable, Hashable, Sendable {
    public static let minStepM = 5.0
    public static let maxStepM = 50.0

    /// The last counted point.
    public private(set) var anchor: LatLon?

    public init(anchor: LatLon? = nil) {
        self.anchor = anchor
    }

    /// How far a fix must be from the last counted point to count. Unknown accuracy uses the maximum.
    public static func stepM(accuracyM: Double?) -> Double {
        guard let accuracyM else { return maxStepM }
        return min(max(2 * accuracyM, minStepM), maxStepM)
    }

    /// The distance from the last counted point to `point`, not counted yet.
    public func pendingM(to point: LatLon) -> Double {
        anchor.map { Geo.haversineM($0, point) } ?? 0
    }

    /// Feeds a fix. Returns the distance to count now: 0 while the fix is within the gate.
    public mutating func step(to point: LatLon, accuracyM: Double?) -> Double {
        guard let anchor else {
            self.anchor = point
            return 0
        }
        let distance = Geo.haversineM(anchor, point)
        guard distance > Self.stepM(accuracyM: accuracyM) else { return 0 }
        self.anchor = point
        return distance
    }
}
```

- [ ] **Step 4: Use it in the route tracker and the engine**

Replace the whole of `ios/PaceKit/Sources/PaceKit/RouteTracker.swift` with:

```swift
import Foundation

/// Distance left along a walking route between route refreshes, and when to refresh.
///
/// Between refreshes the last route distance is reduced by how far you have moved (GPS wander
/// excluded, see `DistanceGate`). A refresh is due every 60 s, or sooner when your straight-line
/// distance to the destination has drifted more than 75 m from what the last refresh predicted
/// (you went off the route).
public struct RouteTracker: Codable, Hashable, Sendable {
    public static let refreshIntervalSec: TimeInterval = 60
    public static let driftLimitM = 75.0

    public private(set) var routeM: Double
    private var countedM = 0.0
    private var gate: DistanceGate
    private var lastPoint: LatLon
    private var straightLineAtRefreshM: Double
    private var refreshedAt: Date

    public init(routeM: Double, at point: LatLon, straightLineM: Double, now: Date) {
        self.routeM = routeM
        gate = DistanceGate(anchor: point)
        lastPoint = point
        straightLineAtRefreshM = straightLineM
        refreshedAt = now
    }

    /// How far you have moved since the last refresh.
    public var movedM: Double { countedM + gate.pendingM(to: lastPoint) }

    public mutating func advance(to point: LatLon, accuracyM: Double? = nil) {
        countedM += gate.step(to: point, accuracyM: accuracyM)
        lastPoint = point
    }

    /// The route distance left — never less than the straight line to the destination.
    public func remainingM(straightLineM: Double) -> Double {
        max(straightLineM, routeM - movedM)
    }

    public func needsRefresh(straightLineM: Double, now: Date) -> Bool {
        if now.timeIntervalSince(refreshedAt) >= Self.refreshIntervalSec { return true }
        let predicted = straightLineAtRefreshM - movedM
        return abs(straightLineM - predicted) > Self.driftLimitM
    }

    public mutating func refreshed(routeM: Double, at point: LatLon, straightLineM: Double, now: Date) {
        self = RouteTracker(routeM: routeM, at: point, straightLineM: straightLineM, now: now)
    }

    /// A refresh failed: keep the current estimate, and wait a full interval before trying again.
    public mutating func refreshFailed(straightLineM: Double, now: Date) {
        refreshedAt = now
        straightLineAtRefreshM = straightLineM + movedM
    }
}
```

Replace the whole of `ios/PaceKit/Sources/PaceKit/WalkEngine.swift` with:

```swift
import Foundation

/// What the walk screen shows at one moment.
public struct WalkMetrics: Equatable, Sendable {
    /// Distance left: the routed distance on routed walks, else the straight line. 0 once arrived.
    public var remainingM: Double
    public var straightLineM: Double
    public var headingDeg: Double
    /// Seconds ahead of schedule (positive = early). Frozen at arrival.
    public var deltaSec: Double
    public var speedMps: Double
    public var walkedM: Double
    public var arrived: Bool
}

/// The per-fix calculation for one walk, shared by the iPhone and the Watch. Feed it every
/// accepted fix with `ingest(_:)` and ask for `metrics(now:)` whenever the screen needs them.
/// It is Codable so a walk in progress can be saved and resumed after a force-quit.
public struct WalkEngine: Codable, Equatable, Sendable {
    public let session: Session
    public private(set) var lastFix: GPSFix?
    public private(set) var arrivedAt: Date?
    private var countedM = 0.0
    private var gate = DistanceGate()
    private var finalDeltaSec: Double?
    private var route: RouteTracker?

    public init(session: Session) {
        self.session = session
        if session.routed {
            route = RouteTracker(
                routeM: session.startDistanceM, at: session.start,
                straightLineM: Geo.haversineM(session.start, session.dest.coordinate), now: session.startAt)
        }
    }

    public var arrived: Bool { arrivedAt != nil }

    /// Distance walked so far, GPS wander excluded.
    public var walkedM: Double {
        countedM + (lastFix.map { gate.pendingM(to: $0.coordinate) } ?? 0)
    }

    public mutating func ingest(_ fix: GPSFix) {
        guard !arrived else { return }
        countedM += gate.step(to: fix.coordinate, accuracyM: fix.accuracyM)
        route?.advance(to: fix.coordinate, accuracyM: fix.accuracyM)
        lastFix = fix
    }

    /// Arrival is checked here, on straight-line distance. Once arrived, the delta is frozen at
    /// the value worked out with 0 m remaining — exactly arrive-by minus the arrival time.
    public mutating func metrics(now: Date) -> WalkMetrics? {
        guard let fix = lastFix else { return nil }
        let straight = straightLineM(from: fix)
        let heading = Geo.bearingDeg(from: fix.coordinate, to: session.dest.coordinate)
        if !arrived, Pace.hasArrived(straightLineM: straight) {
            arrivedAt = now
            finalDeltaSec = session.deltaSec(remainingM: 0, now: now)
        }
        if let finalDeltaSec {
            return WalkMetrics(
                remainingM: 0, straightLineM: straight, headingDeg: heading, deltaSec: finalDeltaSec,
                speedMps: fix.speedMps ?? 0, walkedM: walkedM, arrived: true)
        }
        let remaining = route?.remainingM(straightLineM: straight) ?? straight
        return WalkMetrics(
            remainingM: remaining, straightLineM: straight, headingDeg: heading,
            deltaSec: session.deltaSec(remainingM: remaining, now: now),
            speedMps: fix.speedMps ?? 0, walkedM: walkedM, arrived: false)
    }

    public func needsRouteRefresh(now: Date) -> Bool {
        guard !arrived, let route, let lastFix else { return false }
        return route.needsRefresh(straightLineM: straightLineM(from: lastFix), now: now)
    }

    /// A route refresh came back. `origin` is where it was requested from; you may have walked on
    /// while it was in flight, so that stretch comes off the new distance.
    public mutating func routeRefreshed(distanceM: Double, from origin: LatLon, now: Date) {
        guard let lastFix else { return }
        let straight = straightLineM(from: lastFix)
        let sinceRequest = Geo.haversineM(origin, lastFix.coordinate)
        route?.refreshed(
            routeM: max(0, distanceM - sinceRequest), at: lastFix.coordinate, straightLineM: straight, now: now)
    }

    public mutating func routeRefreshFailed(now: Date) {
        guard let lastFix else { return }
        let straight = straightLineM(from: lastFix)
        route?.refreshFailed(straightLineM: straight, now: now)
    }

    private func straightLineM(from fix: GPSFix) -> Double {
        Geo.haversineM(fix.coordinate, session.dest.coordinate)
    }
}
```

- [ ] **Step 5: Add the saved walk**

Create `ios/PaceKit/Sources/PaceKit/ActiveWalk.swift`:

```swift
import Foundation

/// A walk in progress, saved so it can be resumed after the app is force-quit (spec §1 `Stores`,
/// §2 failure cases). Demo walks are never saved.
public struct ActiveWalk: Codable, Equatable, Sendable {
    /// A walk whose arrive-by passed longer ago than this is not offered again.
    public static let resumeWindowSec: TimeInterval = 60 * 60

    public var engine: WalkEngine
    /// The last alert status, so a resumed walk doesn't buzz again for a change it already announced.
    public var status: PaceStatus

    public init(engine: WalkEngine, status: PaceStatus) {
        self.engine = engine
        self.status = status
    }

    /// Whether to offer Resume on launch: the walk hasn't arrived, and arrive-by is less than an
    /// hour ago.
    public func isResumable(now: Date) -> Bool {
        !engine.arrived && now.timeIntervalSince(engine.session.arriveBy) < Self.resumeWindowSec
    }
}
```

- [ ] **Step 6: Run the tests to see them pass**

Run: `cd ios/PaceKit && swift test 2>&1 | tail -1`
Expected: `Test run with 97 tests in 16 suites passed`, with no warnings.

- [ ] **Step 7: Pass the request point from the app**

In `ios/KeepThePace/WalkSession.swift`, replace:

```swift
                self.engine?.routeRefreshed(distanceM: distance, now: clock())
```

with:

```swift
                self.engine?.routeRefreshed(distanceM: distance, from: from.coordinate, now: clock())
```

`from` is the fix the refresh was requested from; `refreshRouteIfDue()` already captures it.

- [ ] **Step 8: Check the app**

Run each:
1. `cd ios && make test-app > /tmp/ktp-t3.log 2>&1; echo "exit $?"; grep -E "Test run with|TEST SUCCEEDED|TEST FAILED|error:|warning:" /tmp/ktp-t3.log | grep -v appintentsmetadataprocessor`: `exit 0`, 4 tests in 1 suite passed, `** TEST SUCCEEDED **`.
2. `cd ios && make build-ios > /tmp/ktp-b3.log 2>&1; echo "exit $?"; grep -E "error:|warning:" /tmp/ktp-b3.log | grep -v appintentsmetadataprocessor`: `exit 0` and no grep output.

- [ ] **Step 9: Commit**

```bash
git add ios/PaceKit ios/KeepThePace/WalkSession.swift
git commit -m "PaceKit: GPS wander filter, a Codable engine and ActiveWalk; route refreshes apply from their request point

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Live Activity state and the alert rules

**Files:**
- Create: `ios/PaceKit/Sources/PaceKit/PaceActivityState.swift`, `ios/PaceKit/Sources/PaceKit/WalkAlerts.swift`
- Test: create `ios/PaceKit/Tests/PaceKitTests/WalkAlertsTests.swift`

**Interfaces:**
- Consumes: `WalkMetrics`, `Units`, `PaceStatus`, `PaceStatusMachine.init(thresholdSec:recoveryMarginSec:status:)`, `Format.delta`, `Format.distance`.
- Produces:
  - `enum TrackingDevice { phone, watch }`
  - `PaceActivityState(deltaSec:status:remainingM:units:arrived:trackingDevice:locationPaused:)`. It is `Codable, Hashable, Sendable`; `trackingDevice` defaults to `.phone` and `locationPaused` to `false`.
  - `PaceActivityState.alertTitle(for:) -> String` and `alertBody: String`
  - `WalkAlerts(thresholdSec:status:)`, `WalkAlerts.status`, `WalkAlerts.routineIntervalSec` (10)
  - `WalkAlerts.update(_ metrics:units:locationPaused:now:appActive:hapticsOn:) -> WalkAlerts.Decision`
  - `Decision.activity: PaceActivityState?`, `Decision.alert: PaceStatus?`, `Decision.haptic: PaceStatus?`

- [ ] **Step 1: Write the failing tests**

Create `ios/PaceKit/Tests/PaceKitTests/WalkAlertsTests.swift`:

```swift
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

    func update(
        _ a: inout WalkAlerts, delta: Double, at t: TimeInterval, arrived: Bool = false, paused: Bool = false,
        appActive: Bool = false, haptics: Bool = true
    ) -> WalkAlerts.Decision {
        a.update(
            metrics(delta: delta, arrived: arrived), units: .metric, locationPaused: paused, now: now + t,
            appActive: appActive, hapticsOn: haptics)
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
}
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `cd ios/PaceKit && swift test 2>&1 | grep -oE "cannot find '[A-Za-z]+' in scope|has no member '[A-Za-z]+'" | sort -u`
Expected: `cannot find 'PaceActivityState' in scope` and `cannot find 'WalkAlerts' in scope`.

- [ ] **Step 3: Implement**

Create `ios/PaceKit/Sources/PaceKit/PaceActivityState.swift`:

```swift
import Foundation

/// Which device is tracking the walk (spec §1). The Watch takes part from M5.
public enum TrackingDevice: String, Codable, Sendable {
    case phone, watch
}

/// What the walk's Live Activity shows: its ActivityKit content state (spec §1), plus whether
/// location is paused (spec §2 failure cases).
public struct PaceActivityState: Codable, Hashable, Sendable {
    public var deltaSec: Double
    public var status: PaceStatus
    public var remainingM: Double
    public var units: Units
    public var arrived: Bool
    public var trackingDevice: TrackingDevice
    public var locationPaused: Bool

    public init(
        deltaSec: Double, status: PaceStatus, remainingM: Double, units: Units, arrived: Bool,
        trackingDevice: TrackingDevice = .phone, locationPaused: Bool = false
    ) {
        self.deltaSec = deltaSec
        self.status = status
        self.remainingM = remainingM
        self.units = units
        self.arrived = arrived
        self.trackingDevice = trackingDevice
        self.locationPaused = locationPaused
    }

    /// The alert title for a status change.
    public static func alertTitle(for status: PaceStatus) -> String {
        switch status {
        case .behind: "Falling behind"
        case .ahead: "Ahead of schedule"
        case .onTime: "Back on pace"
        }
    }

    /// The alert body: the ±m:ss and the distance left, e.g. "−0:45 · 0.4 mi to go".
    public var alertBody: String {
        let delta = Format.delta(sec: deltaSec)
        return "\(delta.sign)\(delta.clock) · \(Format.distance(meters: remainingM, units: units)) to go"
    }
}
```

Create `ios/PaceKit/Sources/PaceKit/WalkAlerts.swift`:

```swift
import Foundation

/// Decides, on each update of a walk, when the phone buzzes and when the Live Activity is updated
/// (spec §2, "Walk tracked on iPhone", steps 2–3):
/// - A status change buzzes: a haptic while the app is open, an alert on the Live Activity while
///   it isn't. Nothing buzzes when iPhone haptics are off.
/// - The Live Activity is updated at once for a status change, arrival, "location paused" or a
///   units change, and otherwise at most every 10 s.
public struct WalkAlerts: Codable, Hashable, Sendable {
    public static let routineIntervalSec: TimeInterval = 10

    public struct Decision: Equatable, Sendable {
        /// Send this to the Live Activity now; nil means no update this time.
        public var activity: PaceActivityState?
        /// Attach an alert for this status change to that update.
        public var alert: PaceStatus?
        /// Play the haptic for this status change in the app.
        public var haptic: PaceStatus?

        public init(activity: PaceActivityState? = nil, alert: PaceStatus? = nil, haptic: PaceStatus? = nil) {
            self.activity = activity
            self.alert = alert
            self.haptic = haptic
        }
    }

    public private(set) var machine: PaceStatusMachine
    private var lastSent: PaceActivityState?
    private var lastSentAt: Date?

    /// `status` is where a resumed walk left off, so it doesn't buzz again for the same change.
    public init(thresholdSec: Double, status: PaceStatus = .onTime) {
        machine = PaceStatusMachine(thresholdSec: thresholdSec, status: status)
    }

    public var status: PaceStatus { machine.status }

    public mutating func update(
        _ metrics: WalkMetrics, units: Units, locationPaused: Bool, now: Date, appActive: Bool, hapticsOn: Bool
    ) -> Decision {
        let change = metrics.arrived ? nil : machine.update(deltaSec: metrics.deltaSec)
        let state = PaceActivityState(
            deltaSec: metrics.deltaSec.isFinite ? metrics.deltaSec : 0, status: machine.status,
            remainingM: metrics.remainingM, units: units, arrived: metrics.arrived, locationPaused: locationPaused)
        var decision = Decision()
        if let change, hapticsOn {
            if appActive {
                decision.haptic = change
            } else {
                decision.alert = change
            }
        }
        let urgent = change != nil || state.arrived != lastSent?.arrived
            || state.locationPaused != lastSent?.locationPaused || state.units != lastSent?.units
        let due = lastSentAt.map { now.timeIntervalSince($0) >= Self.routineIntervalSec } ?? true
        if urgent || due {
            decision.activity = state
            lastSent = state
            lastSentAt = now
        }
        return decision
    }
}
```

- [ ] **Step 4: Run the tests to see them pass**

Run: `cd ios/PaceKit && swift test 2>&1 | tail -1`
Expected: `Test run with 106 tests in 17 suites passed`, with no warnings.

- [ ] **Step 5: Commit**

```bash
git add ios/PaceKit
git commit -m "PaceKit: Live Activity state and the rules for when to buzz and update it

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: The Live Activity: lock screen and Dynamic Island

The extension draws the walk from `PaceActivityState`. Its attributes type and the colours are shared with the app through a new `ios/Shared/` folder. Nothing starts a Live Activity yet; Task 7 does.

**Files:**
- Move: `ios/KeepThePace/Theme.swift` → `ios/Shared/Theme.swift`
- Create: `ios/Shared/PaceActivityAttributes.swift`, `ios/PaceActivity/PaceLiveActivity.swift`
- Modify (full replacement): `ios/PaceActivity/PaceActivityBundle.swift`
- Modify: `ios/project.yml` (sources of `KeepThePace` and `PaceActivity`)

**Interfaces:**
- Consumes: `PaceActivityState`, `Format`, `Theme.paceColor(_:)`.
- Produces:
  - `struct PaceActivityAttributes: ActivityAttributes`: `ContentState = PaceActivityState`, with `destinationName: String`, `arriveBy: Date`, `startedAt: Date`
  - The `PaceLiveActivity` widget
  - `PaceReadout` (the ±m:ss text, label and colour)
  - `PaceLockScreenView`

- [ ] **Step 1: Move the theme into Shared**

```bash
mkdir -p ios/Shared
git mv ios/KeepThePace/Theme.swift ios/Shared/Theme.swift
```

In `ios/project.yml`, replace:

```yaml
    sources: [KeepThePace]
```

with:

```yaml
    sources: [KeepThePace, Shared]
```

In `ios/project.yml`, replace:

```yaml
    sources: [PaceActivity]
```

with:

```yaml
    sources: [PaceActivity, Shared]
```

- [ ] **Step 2: Add the attributes**

Create `ios/Shared/PaceActivityAttributes.swift`:

```swift
import ActivityKit
import Foundation
import PaceKit

/// The walk's Live Activity (spec §1). The destination and arrive-by don't change during a walk;
/// `PaceActivityState` carries the live numbers. Compiled into the app and the PaceActivity
/// extension.
struct PaceActivityAttributes: ActivityAttributes {
    typealias ContentState = PaceActivityState

    var destinationName: String
    var arriveBy: Date
    /// When the walk started. It identifies the walk, so a relaunched app adopts its own Live Activity.
    var startedAt: Date
}
```

- [ ] **Step 3: Draw the Live Activity**

Replace the whole of `ios/PaceActivity/PaceActivityBundle.swift` with:

```swift
import SwiftUI
import WidgetKit

@main
struct PaceActivityBundle: WidgetBundle {
    var body: some Widget {
        PaceLiveActivity()
    }
}
```

Create `ios/PaceActivity/PaceLiveActivity.swift`:

```swift
import ActivityKit
import PaceKit
import SwiftUI
import WidgetKit

/// The walk on the lock screen and in the Dynamic Island (spec §1): destination, ±m:ss in the pace
/// colour, distance left and arrive-by.
struct PaceLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PaceActivityAttributes.self) { context in
            PaceLockScreenView(attributes: context.attributes, state: context.state, isStale: context.isStale)
                .activityBackgroundTint(Theme.background)
                .activitySystemActionForegroundColor(Theme.foreground)
        } dynamicIsland: { context in
            let readout = PaceReadout(context.state)
            let distance = Format.distance(meters: context.state.remainingM, units: context.state.units)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(readout.text)
                            .font(.system(.title, design: .monospaced).weight(.medium))
                            .foregroundStyle(readout.color)
                        Text(readout.label)
                            .font(.caption2.weight(.semibold))
                            .tracking(1.2)
                            .foregroundStyle(readout.color)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(context.state.arrived ? "Arrived" : "\(distance) left")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(Theme.foreground)
                        Text("by \(Format.clock(context.attributes.arriveBy))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Theme.muted)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.locationPaused ? "Location paused" : context.attributes.destinationName)
                        .font(.subheadline)
                        .foregroundStyle(context.state.locationPaused ? Theme.late : Theme.muted)
                        .lineLimit(1)
                }
            } compactLeading: {
                Text(readout.text)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(readout.color)
            } compactTrailing: {
                Text(distance)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.foreground)
            } minimal: {
                Text(readout.text)
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(readout.color)
            }
            .keylineTint(readout.color)
        }
    }
}

/// The ±m:ss as the Live Activity shows it, with its label and pace colour.
struct PaceReadout {
    let text: String
    let label: String
    let color: Color

    init(_ state: PaceActivityState) {
        let delta = Format.delta(sec: state.deltaSec)
        text = delta.tone == .ontime ? "0:00" : delta.sign + delta.clock
        label = (state.arrived ? "Arrived \(delta.label)" : delta.label).uppercased()
        color = Theme.paceColor(delta.tone)
    }
}

struct PaceLockScreenView: View {
    let attributes: PaceActivityAttributes
    let state: PaceActivityState
    let isStale: Bool

    var body: some View {
        let readout = PaceReadout(state)
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(attributes.destinationName)
                    .font(.headline)
                    .foregroundStyle(Theme.foreground)
                    .lineLimit(1)
                Text(detail)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                if let notice {
                    Text(notice)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.late)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(readout.text)
                    .font(.system(size: 40, weight: .medium, design: .monospaced))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundStyle(readout.color)
                Text(readout.label)
                    .font(.caption2.weight(.semibold))
                    .tracking(1.5)
                    .foregroundStyle(readout.color)
            }
        }
        .opacity(isStale && !state.arrived ? 0.55 : 1)
        .padding(16)
    }

    private var detail: String {
        let arriveBy = Format.clock(attributes.arriveBy)
        if state.arrived { return "Target \(arriveBy)" }
        return "\(Format.distance(meters: state.remainingM, units: state.units)) left · by \(arriveBy)"
    }

    private var notice: String? {
        if state.locationPaused { return "Location paused" }
        if isStale, !state.arrived { return "Not updating. Open Keep the Pace." }
        return nil
    }
}
```

- [ ] **Step 4: Build**

Run each:
1. `cd ios && make build-ios > /tmp/ktp-b5.log 2>&1; echo "exit $?"; grep -E "error:|warning:" /tmp/ktp-b5.log | grep -v appintentsmetadataprocessor`: `exit 0` and no grep output.
2. `cd ios && make test-app > /tmp/ktp-t5.log 2>&1; echo "exit $?"; grep -E "Test run with|TEST SUCCEEDED|TEST FAILED" /tmp/ktp-t5.log`: `exit 0`, 4 tests in 1 suite passed.

The layout is checked on the simulator's lock screen in Task 9.

- [ ] **Step 5: Commit**

```bash
git add ios/project.yml ios/Shared ios/KeepThePace ios/PaceActivity
git commit -m "iOS: the Live Activity's lock screen and Dynamic Island; Theme moves to ios/Shared

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Task 6: Background location, Precise Location and the dropped-reading log

**What this adds:**
- During a real walk, GPS keeps running with the app in the background (spec §1), with the blue location indicator on.
- In setup, GPS stops when the app goes to the background. That way a stale fix is never a walk's start point; the M2 review flagged it.
- When Precise Location is off, every fix fails the 50 m filter. The setup screen now says so and offers to ask for precise location for this walk.
- `SpeedEstimator` reports why it dropped a reading, and `LocationService` logs it. The device walk then shows whether the 1 s stale-fix limit drops real fixes (spec §1).
- `RouteService` logs Apple Maps failures, which otherwise fall back to the straight line silently.

**Files:**
- Modify (full replacement): `ios/PaceKit/Sources/PaceKit/SpeedEstimator.swift`; test `ios/PaceKit/Tests/PaceKitTests/SpeedEstimatorTests.swift`
- Create: `ios/KeepThePaceTests/BackgroundLocationTests.swift`
- Modify (full replacement): `ios/KeepThePace/WalkServices.swift`, `ios/KeepThePace/LocationService.swift`, `ios/KeepThePace/RouteService.swift`, `ios/KeepThePaceTests/Fakes.swift`
- Modify:
  - `ios/KeepThePace/WalkSession.swift`: four edits
  - `ios/KeepThePace/RootView.swift`: two edits
  - `ios/KeepThePace/SetupView.swift`: one edit
  - `ios/project.yml`: the precise-location purpose string

**Interfaces:**
- Consumes (Task 1): `LocationProviding`, `FakeLocation`, `Launch`.
- Produces:
  - `SpeedEstimator.Rejection { inaccurate, stale }` and `SpeedEstimator.lastRejection`
  - `LocationProviding` gains `precise: Bool`, `setBackgroundTracking(_ on: Bool)` and `requestPrecise()`
  - `LocationService.precisePurposeKey` (`"PreciseWalk"`)
  - `WalkSession.sceneChanged(_ scene: ScenePhase)`
  - `FakeLocation` gains `precise` and `backgroundTracking`

- [ ] **Step 1: Write the failing PaceKit tests**

Replace the whole of `ios/PaceKit/Tests/PaceKitTests/SpeedEstimatorTests.swift` with the version below. The first six tests are unchanged, and the last three are new:
- `dropsSayWhy` covers the drop reason.
- `aDroppedReadingKeepsTheLastFix` and `readingsStampedAheadOfTheClockAreAccepted` are cheap tests deferred from the M1 and M2 reviews.

```swift
import Foundation
import Testing
@testable import PaceKit

@Suite struct SpeedEstimatorTests {
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    let here = LatLon(lat: 60, lon: 10)

    @Test func rejectsInaccurateAndInvalidReadings() {
        var e = SpeedEstimator()
        #expect(e.accept(coordinate: here, reportedSpeedMps: 1, accuracyM: 50.1, timestamp: t0, receivedAt: t0) == nil)
        #expect(e.accept(coordinate: here, reportedSpeedMps: 1, accuracyM: -1, timestamp: t0, receivedAt: t0) == nil)
        #expect(e.last == nil)
        #expect(e.accept(coordinate: here, reportedSpeedMps: 1, accuracyM: 50, timestamp: t0, receivedAt: t0) != nil)
    }

    @Test func usesReportedSpeedThenSmooths() {
        var e = SpeedEstimator()
        #expect(e.accept(coordinate: here, reportedSpeedMps: 1.5, accuracyM: 5, timestamp: t0, receivedAt: t0)?.speedMps == 1.5)
        let second = e.accept(coordinate: here, reportedSpeedMps: 2.0, accuracyM: 5, timestamp: t0 + 1, receivedAt: t0 + 1)
        #expect(abs(second!.speedMps! - 1.675) < 1e-12)
    }

    @Test func derivesSpeedFromHaversineWhenNotReported() {
        var e = SpeedEstimator()
        _ = e.accept(coordinate: here, reportedSpeedMps: nil, accuracyM: 5, timestamp: t0, receivedAt: t0)
        // Due north at 60°N: the web version's formula would report half the true speed here.
        let north = LatLon(lat: 60.001, lon: 10)
        let fix = e.accept(coordinate: north, reportedSpeedMps: -1, accuracyM: 5, timestamp: t0 + 10, receivedAt: t0 + 10)
        #expect(abs(fix!.speedMps! - Geo.haversineM(here, north) / 10) < 1e-9)
        #expect(fix!.speedMps! > 11)
    }

    @Test func keepsLastSpeedWhenFixesAreTooClose() {
        var e = SpeedEstimator()
        _ = e.accept(coordinate: here, reportedSpeedMps: 1.4, accuracyM: 5, timestamp: t0, receivedAt: t0)
        let fix = e.accept(coordinate: LatLon(lat: 60.0001, lon: 10), reportedSpeedMps: nil, accuracyM: 5, timestamp: t0 + 0.3, receivedAt: t0 + 0.3)
        #expect(abs(fix!.speedMps! - 1.4) < 1e-12)
    }

    @Test func rejectsStaleReadings() {
        var e = SpeedEstimator()
        // Delivered 1.5 s after it was measured: a cached position, not a live one.
        #expect(e.accept(coordinate: here, reportedSpeedMps: 1, accuracyM: 5, timestamp: t0, receivedAt: t0 + 1.5) == nil)
        #expect(e.last == nil)
        #expect(e.accept(coordinate: here, reportedSpeedMps: 1, accuracyM: 5, timestamp: t0, receivedAt: t0 + 1) != nil)
    }

    @Test func noSpeedWithoutHistory() {
        var e = SpeedEstimator()
        let fix = e.accept(coordinate: here, reportedSpeedMps: nil, accuracyM: nil, timestamp: t0, receivedAt: t0)
        #expect(fix != nil)   // unknown accuracy is accepted; only worse than 50 m is rejected
        #expect(fix?.speedMps == nil)
    }

    @Test func dropsSayWhy() {
        var e = SpeedEstimator()
        _ = e.accept(coordinate: here, reportedSpeedMps: 1, accuracyM: 80, timestamp: t0, receivedAt: t0)
        #expect(e.lastRejection == .inaccurate)
        _ = e.accept(coordinate: here, reportedSpeedMps: 1, accuracyM: 5, timestamp: t0, receivedAt: t0 + 5)
        #expect(e.lastRejection == .stale)
        _ = e.accept(coordinate: here, reportedSpeedMps: 1, accuracyM: 5, timestamp: t0, receivedAt: t0)
        #expect(e.lastRejection == nil)
    }

    @Test func aDroppedReadingKeepsTheLastFix() {
        var e = SpeedEstimator()
        let first = e.accept(coordinate: here, reportedSpeedMps: 1.2, accuracyM: 5, timestamp: t0, receivedAt: t0)
        _ = e.accept(coordinate: LatLon(lat: 60.01, lon: 10), reportedSpeedMps: 9, accuracyM: 90, timestamp: t0 + 1, receivedAt: t0 + 1)
        #expect(e.last == first)
    }

    @Test func readingsStampedAheadOfTheClockAreAccepted() {
        // A phone clock slightly behind the GPS time must not drop every reading.
        var e = SpeedEstimator()
        #expect(e.accept(coordinate: here, reportedSpeedMps: 1, accuracyM: 5, timestamp: t0 + 2, receivedAt: t0) != nil)
    }
}
```

Run: `cd ios/PaceKit && swift test 2>&1 | grep -oE "cannot find '[A-Za-z]+' in scope|has no member '[A-Za-z]+'" | sort -u`
Expected: `has no member 'lastRejection'`.

- [ ] **Step 2: Record why a reading was dropped**

Replace the whole of `ios/PaceKit/Sources/PaceKit/SpeedEstimator.swift` with:

```swift
import Foundation

/// Turns raw location readings into fixes with a smoothed speed. Ported from `toFix` in
/// `src/hooks/use-geolocation.ts`, with three changes: inaccurate readings are dropped, stale
/// readings are dropped (the web gets that from `maximumAge: 1000`), and the fallback speed uses
/// haversine distance (the web version scales the whole distance by cos(latitude), which
/// under-counts north–south movement).
public struct SpeedEstimator: Sendable {
    public static let maxAccuracyM = 50.0
    /// Readings older than this when they arrive are cached positions, not live ones.
    public static let maxAgeSec: TimeInterval = 1

    /// Why a reading was dropped.
    public enum Rejection: String, Sendable {
        case inaccurate, stale
    }

    public private(set) var last: GPSFix?
    /// Why the latest reading was dropped, or nil if it was accepted. For logging.
    public private(set) var lastRejection: Rejection?

    public init() {}

    /// Returns nil for readings with invalid or worse-than-50 m accuracy, and for readings more
    /// than `maxAgeSec` old when they arrived — so a cached position never becomes a walk's start
    /// point. A dropped reading leaves `last` alone and sets `lastRejection`.
    public mutating func accept(
        coordinate: LatLon, reportedSpeedMps: Double?, accuracyM: Double?, timestamp: Date, receivedAt: Date
    ) -> GPSFix? {
        if let accuracyM, accuracyM < 0 || accuracyM > Self.maxAccuracyM {
            lastRejection = .inaccurate
            return nil
        }
        if receivedAt.timeIntervalSince(timestamp) > Self.maxAgeSec {
            lastRejection = .stale
            return nil
        }
        lastRejection = nil
        var speed = reportedSpeedMps.flatMap { $0 >= 0 ? $0 : nil }
        if speed == nil, let last {
            let dt = timestamp.timeIntervalSince(last.timestamp)
            if dt > 0.4 { speed = max(0, Geo.haversineM(last.coordinate, coordinate) / dt) }
        }
        if speed == nil { speed = last?.speedMps }
        if let current = speed, let previous = last?.speedMps {
            speed = previous * 0.65 + current * 0.35
        }
        let fix = GPSFix(coordinate: coordinate, speedMps: speed, accuracyM: accuracyM, timestamp: timestamp)
        last = fix
        return fix
    }
}
```

Run: `cd ios/PaceKit && swift test 2>&1 | tail -1`
Expected: `Test run with 109 tests in 17 suites passed`, with no warnings.

- [ ] **Step 3: Write the failing app tests**

Create `ios/KeepThePaceTests/BackgroundLocationTests.swift`:

```swift
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
```

Run: `cd ios && make test-app > /tmp/ktp-t6.log 2>&1; echo "exit $?"; grep -oE "has no member '[A-Za-z]+'" /tmp/ktp-t6.log | sort -u`
Expected: a non-zero exit, `has no member 'backgroundTracking'` and `has no member 'sceneChanged'`.

- [ ] **Step 4: Extend the location seam and its fake**

Replace the whole of `ios/KeepThePace/WalkServices.swift` with:

```swift
import Foundation
import PaceKit

/// Whether the app may use location.
enum LocationAccess {
    case notDetermined, allowed, denied
}

/// The live GPS as `WalkSession` sees it: `LocationService` in the app, a fake in tests.
@MainActor
protocol LocationProviding: FixSource {
    var access: LocationAccess { get }
    /// False when Precise Location is off; fixes are then too coarse to use.
    var precise: Bool { get }
    /// The latest accepted fix, or nil until one arrives.
    var latestFix: GPSFix? { get }
    /// Keeps location updates coming while the app is in the background, for the length of a walk.
    func setBackgroundTracking(_ on: Bool)
    /// Asks for precise location for this walk when Precise Location is off.
    func requestPrecise()
}

/// Walking distance along streets: `RouteService` (Apple Maps) in the app, a fake in tests.
@MainActor
protocol RouteProviding {
    func walkingDistanceM(from start: LatLon, to end: LatLon) async -> Double?
}
```

Replace the whole of `ios/KeepThePaceTests/Fakes.swift` with the version below. `FakeLocation` gains `precise`, `backgroundTracking`, `setBackgroundTracking(_:)` and `requestPrecise()`; the rest is unchanged:

```swift
import Foundation
import PaceKit
@testable import KeepThePace

/// GPS the test drives by hand: `send(_:)` is a reading arriving.
@MainActor
final class FakeLocation: LocationProviding {
    var onFix: ((GPSFix) -> Void)?
    var access: LocationAccess = .allowed
    var precise = true
    private(set) var latestFix: GPSFix?
    private(set) var running = false
    private(set) var backgroundTracking = false

    func start() { running = true }

    func stop() {
        running = false
        latestFix = nil
    }

    func setBackgroundTracking(_ on: Bool) { backgroundTracking = on }

    func requestPrecise() {}

    func send(_ fix: GPSFix) {
        latestFix = fix
        onFix?(fix)
    }
}

/// Apple Maps stand-in: answers every request with `distanceM` and records where it was asked from.
@MainActor
final class FakeRoutes: RouteProviding {
    var distanceM: Double?
    private(set) var requestedFrom: [LatLon] = []

    func walkingDistanceM(from start: LatLon, to end: LatLon) async -> Double? {
        requestedFrom.append(start)
        return distanceM
    }
}

/// A clock the test moves by hand.
final class TestClock {
    var now = Date(timeIntervalSince1970: 1_800_000_000)

    func advance(_ seconds: TimeInterval) { now += seconds }
}
```

- [ ] **Step 5: Background updates, Precise Location and the log in `LocationService`**

Replace the whole of `ios/KeepThePace/LocationService.swift` with:

```swift
import CoreLocation
import Observation
import OSLog
import PaceKit

/// The iPhone's GPS ("When In Use"). Readings go through PaceKit's `SpeedEstimator`, which drops
/// inaccurate and stale ones and smooths the speed. During a walk, updates continue in the
/// background with the blue location indicator showing (spec §1).
@MainActor
@Observable
final class LocationService: NSObject, LocationProviding, CLLocationManagerDelegate {
    /// The Info.plist `NSLocationTemporaryUsageDescriptionDictionary` key for precise location.
    static let precisePurposeKey = "PreciseWalk"

    private(set) var access: LocationAccess = .notDetermined
    private(set) var precise = true
    private(set) var latestFix: GPSFix?
    @ObservationIgnored var onFix: ((GPSFix) -> Void)?
    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var estimator = SpeedEstimator()
    @ObservationIgnored private var wantsUpdates = false
    @ObservationIgnored private let log = Logger(subsystem: "com.iliasrafailidis.delta", category: "location")

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .fitness
        readAuthorization()
    }

    /// Starts updates, asking for permission first if the user hasn't been asked yet.
    func start() {
        wantsUpdates = true
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    func stop() {
        wantsUpdates = false
        manager.stopUpdatingLocation()
        estimator = SpeedEstimator()
        latestFix = nil
    }

    /// Updates started (or restarted) while the app is in the foreground then keep coming in the
    /// background, until this is turned off again.
    func setBackgroundTracking(_ on: Bool) {
        manager.allowsBackgroundLocationUpdates = on
        manager.pausesLocationUpdatesAutomatically = !on
        manager.showsBackgroundLocationIndicator = on
        if on, wantsUpdates, access == .allowed {
            manager.startUpdatingLocation()
        }
    }

    func requestPrecise() {
        manager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: Self.precisePurposeKey)
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Delegate calls arrive on the main thread, where the manager was created.
        MainActor.assumeIsolated {
            readAuthorization()
            if access == .allowed, wantsUpdates {
                self.manager.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        MainActor.assumeIsolated {
            for location in locations {
                accept(location)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Transient failures (no fix yet) are normal; denial arrives via the authorization callback.
    }

    private func accept(_ location: CLLocation) {
        let receivedAt = Date.now
        guard let fix = estimator.accept(
            coordinate: LatLon(location.coordinate),
            reportedSpeedMps: location.speed,
            accuracyM: location.horizontalAccuracy,
            timestamp: location.timestamp,
            receivedAt: receivedAt)
        else {
            if let reason = estimator.lastRejection {
                let age = receivedAt.timeIntervalSince(location.timestamp)
                log.debug("""
                    Dropped a \(reason.rawValue, privacy: .public) reading: \
                    accuracy \(location.horizontalAccuracy, format: .fixed(precision: 0)) m, \
                    age \(age, format: .fixed(precision: 1)) s
                    """)
            }
            return
        }
        latestFix = fix
        onFix?(fix)
    }

    private func readAuthorization() {
        access = switch manager.authorizationStatus {
        case .notDetermined: .notDetermined
        case .authorizedWhenInUse, .authorizedAlways: .allowed
        default: .denied
        }
        precise = manager.accuracyAuthorization == .fullAccuracy
    }
}
```

About `setBackgroundTracking(true)`:
- Core Location keeps an app with "When In Use" permission running in the background if `allowsBackgroundLocationUpdates` is on and updates were started while the app was in the foreground. That's why it restarts updates.
- `UIBackgroundModes: [location]` has been in `project.yml` since M0. Without it, setting the flag would crash the app.

Replace the whole of `ios/KeepThePace/RouteService.swift` with the version below. It logs the failure before falling back to the straight line; everything else is Task 1's:

```swift
import MapKit
import OSLog
import PaceKit

/// Walking distance along streets from Apple Maps, or nil when there is no route (the app then
/// uses the straight line). Failures are logged, for the device walk.
@MainActor
struct RouteService {
    private let log = Logger(subsystem: "com.iliasrafailidis.delta", category: "route")

    func walkingDistanceM(from start: LatLon, to end: LatLon) async -> Double? {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: start.clCoordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: end.clCoordinate))
        request.transportType = .walking
        do {
            let response = try await MKDirections(request: request).calculate()
            return response.routes.first?.distance
        } catch {
            log.error("No walking route: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}

extension RouteService: RouteProviding {}
```

In `ios/project.yml`, replace:

```yaml
        UIBackgroundModes: [location]
        NSSupportsLiveActivities: true
        NSLocationWhenInUseUsageDescription: Keep the Pace uses your location to measure how far you are from your destination and whether you're on schedule.
```

with:

```yaml
        UIBackgroundModes: [location]
        NSSupportsLiveActivities: true
        NSLocationWhenInUseUsageDescription: Keep the Pace uses your location to measure how far you are from your destination and whether you're on schedule.
        NSLocationTemporaryUsageDescriptionDictionary:
          PreciseWalk: Keep the Pace needs your precise location to tell whether you're on schedule to within a few seconds.
```

- [ ] **Step 6: Wire it into `WalkSession`**

In `ios/KeepThePace/WalkSession.swift`, make these four replacements.

Replace:

```swift
import Observation
import PaceKit
```

with:

```swift
import Observation
import PaceKit
import SwiftUI
```

Replace:

```swift
    func choose(_ place: Place) {
```

with:

```swift
    /// The app moved to or from the foreground. In setup, GPS stops in the background, so an old
    /// fix is never a walk's start point.
    func sceneChanged(_ scene: ScenePhase) {
        guard phase == .setup else { return }
        switch scene {
        case .background: location.stop()
        case .active: setupAppeared()
        default: break
        }
    }

    func choose(_ place: Place) {
```

Replace:

```swift
        phase = .walk
        if let firstFix { walkFix(firstFix) }
```

with:

```swift
        phase = .walk
        if !session.demo { location.setBackgroundTracking(true) }
        if let firstFix { walkFix(firstFix) }
```

Replace:

```swift
        if engine?.session.demo == false { location.stop() }
```

with:

```swift
        if engine?.session.demo == false {
            location.setBackgroundTracking(false)
            location.stop()
        }
```

- [ ] **Step 7: Pass scene changes in, and show the Precise Location prompt**

In `ios/KeepThePace/RootView.swift`, replace:

```swift
    let walk: WalkSession
    let saved: SavedData
```

with:

```swift
    let walk: WalkSession
    let saved: SavedData
    @Environment(\.scenePhase) private var scenePhase
```

In `ios/KeepThePace/RootView.swift`, replace:

```swift
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
```

with:

```swift
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
        .onChange(of: scenePhase) { _, newPhase in walk.sceneChanged(newPhase) }
```

In `ios/KeepThePace/SetupView.swift`, replace:

```swift
        case .allowed:
            if walk.origin != nil {
```

with:

```swift
        case .allowed:
            if !walk.location.precise {
                Button("Precise Location is off. Tap to allow it for this walk.") { walk.location.requestPrecise() }
                    .font(.caption)
                    .foregroundStyle(Theme.late)
                    .multilineTextAlignment(.center)
            } else if walk.origin != nil {
```

- [ ] **Step 8: Run the tests to see them pass**

Run each:
1. `cd ios && make test-app > /tmp/ktp-t6.log 2>&1; echo "exit $?"; grep -E "Test run with|TEST SUCCEEDED|TEST FAILED|error:|warning:" /tmp/ktp-t6.log | grep -v appintentsmetadataprocessor`: `exit 0`, `✔ Test run with 7 tests in 2 suites passed`, `** TEST SUCCEEDED **`, and no warnings.
2. `cd ios && make build-ios > /tmp/ktp-b6.log 2>&1; echo "exit $?"; grep -E "error:|warning:" /tmp/ktp-b6.log | grep -v appintentsmetadataprocessor`: `exit 0` and no grep output.
3. `plutil -p ios/KeepThePace/Info.plist | grep -A2 NSLocationTemporaryUsageDescriptionDictionary`: shows the `PreciseWalk` entry.

- [ ] **Step 9: Commit**

```bash
git add ios/PaceKit ios/project.yml ios/KeepThePace ios/KeepThePaceTests
git commit -m "iOS: GPS runs in the background during walks, Precise Location prompt, dropped-reading log

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Live Activity updates and status alerts

This wires spec §2's "Walk tracked on iPhone", steps 2–3. After this task:
- Every walk has a Live Activity.
- A status change buzzes: a haptic in the app, or an alert on the lock screen.
- Routine updates go out at most every 10 s.
- Arrival leaves the Live Activity up for 4 minutes, and End removes it.
- Settings gains the Alerts section.

**Files:**
- Create: `ios/KeepThePaceTests/ActivityFakes.swift`, `ios/KeepThePaceTests/LiveActivityAlertTests.swift`
- Create: `ios/KeepThePace/LiveActivityController.swift`, `ios/KeepThePace/FeedbackController.swift`
- Modify (full replacement): `ios/KeepThePaceTests/Launch.swift`, `ios/KeepThePace/WalkServices.swift`, `ios/KeepThePace/WalkSession.swift`
- Modify: `ios/KeepThePace/SettingsView.swift` (the Alerts section)

**Interfaces:**
- Consumes:
  - Task 4: `WalkAlerts`, `PaceActivityState`
  - Task 5: `PaceActivityAttributes`
  - Task 2: `AppSettings.alertThreshold` and `.phoneHaptics`
  - Task 6: `LocationProviding`
- Produces:
  - `protocol LiveActivityControlling`: `show(_:for:alert:)`, `end(_:dismissAfter:)`, `endAll()`
  - `protocol FeedbackPlaying`: `play(_:)`
  - `LiveActivityController` (`staleAfterSec` = 120) and `FeedbackController`
  - `WalkSession.init(saved:location:search:routes:liveActivity:feedback:clock:tickInterval:)`
  - `WalkSession.arrivedActivitySec` (240)
- Produces, test side:
  - `FakeLiveActivity` (`shown`, `ended`, `endAllCount`) and `FakeFeedback` (`played`)
  - `Launch.activity` and `Launch.feedback`

- [ ] **Step 1: Write the fakes and the failing tests**

Create `ios/KeepThePaceTests/ActivityFakes.swift`:

```swift
import Foundation
import PaceKit
@testable import KeepThePace

/// Records what the Live Activity was asked to show.
@MainActor
final class FakeLiveActivity: LiveActivityControlling {
    struct Shown: Equatable {
        var state: PaceActivityState
        var alert: PaceStatus?
    }

    struct Ended: Equatable {
        var state: PaceActivityState?
        var dismissAfter: TimeInterval?
    }

    private(set) var shown: [Shown] = []
    private(set) var ended: [Ended] = []
    private(set) var endAllCount = 0

    func show(_ state: PaceActivityState, for session: Session, alert: PaceStatus?) {
        shown.append(Shown(state: state, alert: alert))
    }

    func end(_ state: PaceActivityState?, dismissAfter: TimeInterval?) {
        ended.append(Ended(state: state, dismissAfter: dismissAfter))
    }

    func endAll() { endAllCount += 1 }
}

/// Records the haptics played.
@MainActor
final class FakeFeedback: FeedbackPlaying {
    private(set) var played: [PaceStatus] = []

    func play(_ status: PaceStatus) { played.append(status) }
}
```

Replace the whole of `ios/KeepThePaceTests/Launch.swift` with the version below. `Launch` gains `activity` and `feedback` and passes them to `WalkSession`:

```swift
import Foundation
import PaceKit
@testable import KeepThePace

/// The walk the tests take: from 300 m due south of Bryant Park, straight to it.
enum TestWalk {
    static let park = Place(name: "Bryant Park", area: "Manhattan", coordinate: LatLon(lat: 40.7536, lon: -73.9832))
    static let start = Geo.destinationPoint(from: park.coordinate, bearingDeg: 180, distanceM: 300)

    static func fix(walked metres: Double, at time: Date) -> GPSFix {
        GPSFix(
            coordinate: Geo.moveTowards(from: start, to: park.coordinate, distanceM: metres), speedMps: 1.3,
            accuracyM: 5, timestamp: time)
    }
}

/// One app launch: a `WalkSession` wired to fakes, with the ticker off (tests call `tick()`).
@MainActor
struct Launch {
    let clock: TestClock
    let defaults: UserDefaults
    let saved: SavedData
    let location = FakeLocation()
    let routes = FakeRoutes()
    let activity = FakeLiveActivity()
    let feedback = FakeFeedback()
    let walk: WalkSession

    /// Each launch gets empty storage of its own. Pass an earlier launch's `defaults` and `clock`
    /// to open the app again with what that launch saved.
    init(defaults: UserDefaults = UserDefaults(suiteName: "KeepThePaceTests.\(UUID().uuidString)")!,
         clock: TestClock = TestClock()) {
        self.clock = clock
        self.defaults = defaults
        saved = SavedData(defaults: defaults)
        walk = WalkSession(
            saved: saved, location: location, routes: routes, liveActivity: activity, feedback: feedback,
            clock: { [clock] in clock.now }, tickInterval: nil)
    }

    /// A GPS reading `metres` along the test walk, stamped now.
    func fix(walked metres: Double) -> GPSFix {
        TestWalk.fix(walked: metres, at: clock.now)
    }

    /// GPS ready at the start point, the park picked, the walk started.
    func startWalk() async {
        location.send(fix(walked: 0))
        walk.choose(TestWalk.park)
        await settle()
        walk.startWalking()
    }
}

/// Lets tasks the session started (route requests) run to completion.
@MainActor
func settle() async {
    for _ in 0..<10 { await Task.yield() }
}
```

Create `ios/KeepThePaceTests/LiveActivityAlertTests.swift`:

```swift
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
        launch.clock.advance(31)  // standing still: 31 s behind
        launch.walk.tick()
        #expect(launch.activity.shown.last?.alert == .behind)
        #expect(launch.activity.shown.last?.state.status == .behind)
        #expect(launch.feedback.played.isEmpty)
    }

    @Test func aStatusChangeInTheAppPlaysAHaptic() async {
        let launch = Launch()
        await launch.startWalk()
        launch.clock.advance(31)
        launch.walk.tick()
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
        launch.walk.tick()
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
```

Run: `cd ios && make test-app > /tmp/ktp-t7.log 2>&1; echo "exit $?"; grep -oE "cannot find type '[A-Za-z]+' in scope" /tmp/ktp-t7.log | sort -u`
Expected: a non-zero exit, `cannot find type 'FeedbackPlaying' in scope` and `cannot find type 'LiveActivityControlling' in scope`.

- [ ] **Step 2: Add the seams for the Live Activity and haptics**

Replace the whole of `ios/KeepThePace/WalkServices.swift` with:

```swift
import Foundation
import PaceKit

/// Whether the app may use location.
enum LocationAccess {
    case notDetermined, allowed, denied
}

/// The live GPS as `WalkSession` sees it: `LocationService` in the app, a fake in tests.
@MainActor
protocol LocationProviding: FixSource {
    var access: LocationAccess { get }
    /// False when Precise Location is off; fixes are then too coarse to use.
    var precise: Bool { get }
    /// The latest accepted fix, or nil until one arrives.
    var latestFix: GPSFix? { get }
    /// Keeps location updates coming while the app is in the background, for the length of a walk.
    func setBackgroundTracking(_ on: Bool)
    /// Asks for precise location for this walk when Precise Location is off.
    func requestPrecise()
}

/// Walking distance along streets: `RouteService` (Apple Maps) in the app, a fake in tests.
@MainActor
protocol RouteProviding {
    func walkingDistanceM(from start: LatLon, to end: LatLon) async -> Double?
}

/// The walk's Live Activity: `LiveActivityController` (ActivityKit) in the app, a fake in tests.
@MainActor
protocol LiveActivityControlling: AnyObject {
    /// Shows `state` for `session`: starts the Live Activity on the first call (or adopts the one
    /// an earlier launch left for the same walk), then updates it. `alert` lights up the lock
    /// screen and buzzes for that status change.
    func show(_ state: PaceActivityState, for session: Session, alert: PaceStatus?)
    /// Ends the walk's Live Activity showing `state`. It stays on the lock screen for
    /// `dismissAfter` seconds, or goes at once when that is nil.
    func end(_ state: PaceActivityState?, dismissAfter: TimeInterval?)
    /// Ends every Live Activity an earlier launch left behind.
    func endAll()
}

/// In-app haptics for status changes: `FeedbackController` (Core Haptics) in the app.
@MainActor
protocol FeedbackPlaying: AnyObject {
    func play(_ status: PaceStatus)
}
```

- [ ] **Step 3: The ActivityKit controller**

Create `ios/KeepThePace/LiveActivityController.swift`:

```swift
// ActivityKit's `Activity` isn't marked Sendable, but its async update and end are made to be called
// from tasks; `@preconcurrency` lets Swift 6 hand it to them.
@preconcurrency import ActivityKit
import Foundation
import OSLog
import PaceKit

/// Starts, updates and ends the walk's Live Activity (spec §1). Each update is marked stale two
/// minutes on, so a Live Activity left behind by a force-quit shows that it stopped updating
/// (spec §2).
@MainActor
final class LiveActivityController: LiveActivityControlling {
    static let staleAfterSec: TimeInterval = 120

    private var activity: Activity<PaceActivityAttributes>?
    private let log = Logger(subsystem: "com.iliasrafailidis.delta", category: "liveActivity")

    func show(_ state: PaceActivityState, for session: Session, alert: PaceStatus?) {
        let content = ActivityContent(state: state, staleDate: .now + Self.staleAfterSec)
        if activity == nil {
            activity = Self.running(for: session)
        }
        guard let activity else {
            start(session, content)
            return
        }
        var alertConfiguration: AlertConfiguration?
        if let alert {
            let title = PaceActivityState.alertTitle(for: alert)
            log.info("Status alert: \(title, privacy: .public), \(state.alertBody, privacy: .public)")
            alertConfiguration = AlertConfiguration(title: "\(title)", body: "\(state.alertBody)", sound: .default)
        }
        Task { await activity.update(content, alertConfiguration: alertConfiguration) }
    }

    func end(_ state: PaceActivityState?, dismissAfter: TimeInterval?) {
        guard let activity else { return }
        self.activity = nil
        let content = state.map { ActivityContent(state: $0, staleDate: nil) }
        let policy: ActivityUIDismissalPolicy = dismissAfter.map { .after(.now + $0) } ?? .immediate
        Task { await activity.end(content, dismissalPolicy: policy) }
    }

    func endAll() {
        activity = nil
        for leftover in Activity<PaceActivityAttributes>.activities {
            Task { await leftover.end(nil, dismissalPolicy: .immediate) }
        }
    }

    private func start(_ session: Session, _ content: ActivityContent<PaceActivityState>) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = PaceActivityAttributes(
            destinationName: session.dest.name, arriveBy: session.arriveBy, startedAt: session.startAt)
        do {
            activity = try Activity.request(attributes: attributes, content: content)
        } catch {
            log.error("Couldn't start the Live Activity: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// The Live Activity an earlier launch started for this walk, if it is still up.
    private static func running(for session: Session) -> Activity<PaceActivityAttributes>? {
        Activity<PaceActivityAttributes>.activities.first {
            abs($0.attributes.startedAt.timeIntervalSince(session.startAt)) < 1
                && ($0.activityState == .active || $0.activityState == .stale)
        }
    }
}
```

**About `@preconcurrency`:** without it, Swift 6 rejects `Task { await activity.update(…) }` with "sending 'activity' risks causing data races". `Activity` isn't marked `Sendable`, but its async `update` and `end` are made to be called from tasks.

**Adopting after a force-quit:** `running(for:)` finds a Live Activity started by an earlier launch for the same walk, matched by its `startedAt`, so Resume (Task 8) updates it rather than starting a second one.

- [ ] **Step 4: Haptics**

Create `ios/KeepThePace/FeedbackController.swift`:

```swift
import CoreHaptics
import PaceKit

/// Buzzes on status changes while the app is open (spec §1). The patterns follow the Watch's:
/// falling behind steps down, getting ahead steps up, back on pace is one soft tap. Phones
/// without haptics, and the simulator, stay silent.
@MainActor
final class FeedbackController: FeedbackPlaying {
    private var engine: CHHapticEngine?

    func play(_ status: PaceStatus) {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let engine = try self.engine ?? CHHapticEngine()
            engine.isAutoShutdownEnabled = true
            self.engine = engine
            try engine.start()
            let pattern = try CHHapticPattern(events: Self.taps(for: status), parameters: [])
            try engine.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
        } catch {
            // Haptics are a nicety: a failure here must never disturb the walk.
        }
    }

    static func taps(for status: PaceStatus) -> [CHHapticEvent] {
        switch status {
        case .behind: [tap(at: 0, intensity: 1, sharpness: 0.8), tap(at: 0.18, intensity: 0.6, sharpness: 0.2)]
        case .ahead: [tap(at: 0, intensity: 0.6, sharpness: 0.2), tap(at: 0.18, intensity: 1, sharpness: 0.8)]
        case .onTime: [tap(at: 0, intensity: 0.5, sharpness: 0.5)]
        }
    }

    private static func tap(at time: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: time)
    }
}
```

The simulator has no haptics, so these patterns are first felt on the device walk (Task 9's checklist).

- [ ] **Step 5: Wire it into `WalkSession`**

Replace the whole of `ios/KeepThePace/WalkSession.swift` with the version below. Compared with Task 6:
- `init` takes `liveActivity` and `feedback`.
- `sceneChanged` also records whether the app is active.
- `begin` starts a fresh `WalkAlerts` with the user's threshold.
- `tick()` applies its decision.
- `finish()` removes the Live Activity when a walk is ended early.

```swift
import Foundation
import Observation
import PaceKit
import SwiftUI

/// The app's walk flow: setup → walk → arrived. Planning, pace maths, arrival and alert rules live
/// in PaceKit (`WalkPlanner`, `Session.begin`, `WalkEngine`, `WalkAlerts`); this class wires them to
/// the GPS, the demo walk, Apple Maps routing, the Live Activity, haptics and a one-second clock.
/// Every one of those can be replaced by a fake in tests.
@MainActor
@Observable
final class WalkSession {
    enum Phase {
        case setup, walk, arrived
    }

    /// How long an arrived walk's Live Activity stays on the lock screen (spec §2).
    static let arrivedActivitySec: TimeInterval = 4 * 60

    private(set) var phase: Phase = .setup
    private(set) var planner = WalkPlanner()
    private(set) var engine: WalkEngine?
    private(set) var metrics: WalkMetrics?

    let location: any LocationProviding
    let search: PlaceSearchService
    @ObservationIgnored private let routes: any RouteProviding
    @ObservationIgnored private let saved: SavedData
    @ObservationIgnored private let liveActivity: any LiveActivityControlling
    @ObservationIgnored private let feedback: any FeedbackPlaying
    @ObservationIgnored private let clock: () -> Date
    @ObservationIgnored private let tickInterval: Duration?
    @ObservationIgnored private var demo: DemoLocationSource?
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var walkID = 0
    @ObservationIgnored private var refreshingRoute = false
    @ObservationIgnored private var alerts = WalkAlerts(thresholdSec: AlertThreshold.thirty.seconds)
    @ObservationIgnored private var appActive = true

    /// `clock` and `tickInterval` exist for tests: a test passes its own clock and a nil interval,
    /// and calls `tick()` itself.
    init(
        saved: SavedData, location: any LocationProviding = LocationService(),
        search: PlaceSearchService = PlaceSearchService(), routes: any RouteProviding = RouteService(),
        liveActivity: any LiveActivityControlling = LiveActivityController(),
        feedback: any FeedbackPlaying = FeedbackController(), clock: @escaping () -> Date = { .now },
        tickInterval: Duration? = .seconds(1)
    ) {
        self.saved = saved
        self.location = location
        self.search = search
        self.routes = routes
        self.liveActivity = liveActivity
        self.feedback = feedback
        self.clock = clock
        self.tickInterval = tickInterval
        location.onFix = { [weak self] fix in self?.liveFix(fix) }
    }

    /// The latest live GPS fix, used as the walk's start point.
    var origin: GPSFix? { location.latestFix }

    var canStart: Bool { planner.canStart(hasLocation: origin != nil) }

    // MARK: Setup

    /// Starts GPS for the setup screen if the user already allowed it. The permission prompt
    /// waits until they search or tap Start.
    func setupAppeared() {
        if location.access == .allowed { location.start() }
    }

    /// Starts GPS, asking for permission first if needed. Called on the first search and from the
    /// "Enable location" prompt (spec: location is requested at the moment it's needed).
    func requestLocation() {
        location.start()
    }

    /// The app moved to or from the foreground. Status changes buzz in the app only while it is
    /// active. In setup, GPS stops in the background, so an old fix is never a walk's start point.
    func sceneChanged(_ scene: ScenePhase) {
        appActive = scene == .active
        guard phase == .setup else { return }
        switch scene {
        case .background: location.stop()
        case .active: setupAppeared()
        default: break
        }
    }

    func choose(_ place: Place) {
        let from = origin?.coordinate
        guard let planID = planner.choose(place, from: from, now: clock()), let from else { return }
        routePlan(planID, from: from, to: place.coordinate)
    }

    /// Upgrades the plan to the walking-route distance when Apple Maps answers.
    private func routePlan(_ planID: Int, from: LatLon, to: LatLon) {
        Task {
            let distance = await routes.walkingDistanceM(from: from, to: to)
            planner.routeResolved(planID: planID, distanceM: distance, now: clock())
        }
    }

    func bumpArriveBy(minutes: Int) {
        planner.bump(minutes: minutes, now: clock())
    }

    func setArriveBy(_ picked: Date) {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: picked)
        planner.setArriveBy(hour: parts.hour ?? 0, minute: parts.minute ?? 0, now: clock(), calendar: .current)
    }

    // MARK: Walking

    func startWalking() {
        guard let fix = origin, let session = planner.beginSession(from: fix.coordinate, now: clock()) else {
            location.start()
            return
        }
        begin(session, firstFix: fix)
    }

    /// A simulated walk to the chosen destination (or the default demo destination), 280 m away.
    func startDemo() {
        let dest = planner.destination ?? DemoWalk.defaultDestination
        let start = DemoWalk.startPoint(for: dest.coordinate)
        let now = clock()
        let session = Session.begin(
            dest: dest, from: start, plannedDistanceM: nil,
            arriveBy: DemoWalk.arriveBy(start: start, dest: dest.coordinate, now: now),
            now: now, demo: true, routed: false)
        location.stop()
        let source = DemoLocationSource(start: start, dest: dest.coordinate, now: now)
        source.onFix = { [weak self] fix in self?.walkFix(fix) }
        demo = source
        begin(session, firstFix: nil)
        source.start()
    }

    /// Ends the walk (End) or leaves the arrived screen (Done).
    func finish() {
        if phase == .walk { liveActivity.end(nil, dismissAfter: nil) }
        stopWalk()
        engine = nil
        metrics = nil
        phase = .setup
        if location.access == .allowed { location.start() }
    }

    private func begin(_ session: Session, firstFix: GPSFix?) {
        walkID += 1
        refreshingRoute = false
        engine = WalkEngine(session: session)
        alerts = WalkAlerts(thresholdSec: saved.settings.alertThreshold.seconds)
        saved.recents.record(session.dest)
        phase = .walk
        if !session.demo { location.setBackgroundTracking(true) }
        if let firstFix { walkFix(firstFix) }
        guard let tickInterval else { return }
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: tickInterval)
                self?.tick()
            }
        }
    }

    private func liveFix(_ fix: GPSFix) {
        switch phase {
        case .setup:
            // A place picked before the first fix is planned from here.
            if let planID = planner.originFound(fix.coordinate, now: clock()), let dest = planner.destination {
                routePlan(planID, from: fix.coordinate, to: dest.coordinate)
            }
        case .walk:
            guard engine?.session.demo == false else { return }
            walkFix(fix)
            refreshRouteIfDue()
        case .arrived:
            break
        }
    }

    private func walkFix(_ fix: GPSFix) {
        engine?.ingest(fix)
        tick()
    }

    /// Location is paused when the user turns it off during a real walk (spec §2).
    private var locationPaused: Bool {
        engine?.session.demo == false && location.access == .denied
    }

    /// Recomputes the walk's numbers and applies `WalkAlerts`' decision: a haptic, or a Live Activity
    /// update (with an alert when the status changed while the app was in the background). Runs on
    /// every fix and once a second.
    func tick() {
        guard phase == .walk, let session = engine?.session, let metrics = engine?.metrics(now: clock()) else { return }
        self.metrics = metrics
        let decision = alerts.update(
            metrics, units: saved.units, locationPaused: locationPaused, now: clock(), appActive: appActive,
            hapticsOn: saved.settings.phoneHaptics)
        if let haptic = decision.haptic { feedback.play(haptic) }
        if let state = decision.activity {
            if metrics.arrived {
                liveActivity.end(state, dismissAfter: Self.arrivedActivitySec)
            } else {
                liveActivity.show(state, for: session, alert: decision.alert)
            }
        }
        if metrics.arrived {
            stopWalk()
            phase = .arrived
        }
    }

    private func refreshRouteIfDue() {
        guard !refreshingRoute, let engine, engine.needsRouteRefresh(now: clock()), let from = engine.lastFix else { return }
        refreshingRoute = true
        let id = walkID
        let to = engine.session.dest.coordinate
        Task {
            let distance = await routes.walkingDistanceM(from: from.coordinate, to: to)
            guard id == walkID else { return }
            if let distance {
                self.engine?.routeRefreshed(distanceM: distance, from: from.coordinate, now: clock())
            } else {
                self.engine?.routeRefreshFailed(now: clock())
            }
            refreshingRoute = false
        }
    }

    private func stopWalk() {
        ticker?.cancel()
        ticker = nil
        demo?.stop()
        demo = nil
        if engine?.session.demo == false {
            location.setBackgroundTracking(false)
            location.stop()
        }
    }
}
```

- [ ] **Step 6: The Alerts section in Settings**

In `ios/KeepThePace/SettingsView.swift`, replace:

```swift
            .listRowBackground(Theme.surface)

            Section("About") {
```

with:

```swift
            .listRowBackground(Theme.surface)

            Section {
                Picker("Alert threshold", selection: $saved.settings.alertThreshold) {
                    ForEach(AlertThreshold.allCases, id: \.self) { threshold in
                        Text("\(threshold.rawValue) s").tag(threshold)
                    }
                }
                .pickerStyle(.segmented)
                Toggle("iPhone haptics", isOn: $saved.settings.phoneHaptics)
            } header: {
                Text("Alerts")
            } footer: {
                Text("Buzz when you fall this far behind or get this far ahead, and when you're back on pace. With the phone locked, the buzz comes from the Live Activity.")
            }
            .listRowBackground(Theme.surface)

            Section("About") {
```

- [ ] **Step 7: Run the tests to see them pass**

Run each:
1. `cd ios && make test-app > /tmp/ktp-t7.log 2>&1; echo "exit $?"; grep -E "Test run with|TEST SUCCEEDED|TEST FAILED|error:|warning:" /tmp/ktp-t7.log | grep -v appintentsmetadataprocessor`: `exit 0`, `✔ Test run with 13 tests in 3 suites passed`, `** TEST SUCCEEDED **`, and no warnings.
2. `cd ios && make build-ios > /tmp/ktp-b7.log 2>&1; echo "exit $?"; grep -E "error:|warning:" /tmp/ktp-b7.log | grep -v appintentsmetadataprocessor`: `exit 0` and no grep output.
3. `cd ios && make test-ui > /tmp/ktp-ui7.log 2>&1; echo "exit $?"; grep -E "Test Case|TEST SUCCEEDED|TEST FAILED|error:" /tmp/ktp-ui7.log`: `exit 0`, the demo-walk test passed and `** TEST SUCCEEDED **`. The demo now starts a Live Activity too. This takes 4–6 minutes: use the Bash tool's 600000 ms timeout, or run it in the background and read the log afterwards. Never `sleep`.

- [ ] **Step 8: Commit**

```bash
git add ios/KeepThePace ios/KeepThePaceTests
git commit -m "iOS: Live Activity updates and status alerts, with alert settings

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Task 8: Resume after a force-quit

Spec §2: "On the next launch, the saved `activeWalk` is offered as Resume or End."
- A real walk saves itself whenever it updates the Live Activity, which is at most every 10 s.
- The next launch offers it at the top of the setup screen.
- Resume carries on with the same schedule and the same Live Activity, without buzzing again for a status it already announced.
- A walk whose arrive-by passed over an hour ago is dropped without asking. On a launch with nothing to resume, leftover Live Activities are ended.

**Files:**
- Create: `ios/KeepThePaceTests/ResumeTests.swift`
- Modify: `ios/KeepThePace/SavedData.swift` (four edits), `ios/KeepThePace/SetupView.swift` (two edits)
- Modify (full replacement): `ios/KeepThePace/WalkSession.swift`

**Interfaces:**
- Consumes:
  - Task 3: `ActiveWalk(engine:status:)` and `isResumable(now:)`
  - Task 4: `WalkAlerts(thresholdSec:status:)` and `WalkAlerts.status`
  - Task 7: `LiveActivityControlling.endAll()`, and `show(_:for:alert:)` adopting a running Live Activity
- Produces:
  - `SavedData.activeWalk: ActiveWalk?`, stored under `activeWalk.v1`
  - `WalkSession.pendingResume: ActiveWalk?`, `resume()` and `discardResume()`

- [ ] **Step 1: Write the failing tests**

Create `ios/KeepThePaceTests/ResumeTests.swift`:

```swift
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
```

`Launch(defaults: first.defaults, clock: first.clock)` opens the app again after a force-quit: new services and a new `SavedData`, reading what the first launch stored.

Run: `cd ios && make test-app > /tmp/ktp-t8.log 2>&1; echo "exit $?"; grep -oE "has no member '[A-Za-z]+'" /tmp/ktp-t8.log | sort -u`
Expected: a non-zero exit, with `has no member 'activeWalk'` and `has no member 'pendingResume'` among the errors.

- [ ] **Step 2: Store the walk in progress**

In `ios/KeepThePace/SavedData.swift`, make these four replacements.

Replace:

```swift
/// Settings, favorites and recents, kept in the App Group's defaults so the Live Activity
/// extension can read them later. Every change is saved immediately.
```

with:

```swift
/// Settings, favorites, recents and the walk in progress, kept in the App Group's defaults so the
/// Live Activity extension can read them later. Every change is saved immediately.
```

Replace:

```swift
        static let recents = "recents.v1"
    }
```

with:

```swift
        static let recents = "recents.v1"
        static let activeWalk = "activeWalk.v1"
    }
```

Replace:

```swift
    var recents: Recents {
        didSet { save(recents, forKey: Key.recents) }
    }
```

with:

```swift
    var recents: Recents {
        didSet { save(recents, forKey: Key.recents) }
    }

    /// The real walk in progress, so it can be resumed after a force-quit; nil when none is running.
    @ObservationIgnored var activeWalk: ActiveWalk? {
        didSet {
            if let activeWalk {
                save(activeWalk, forKey: Key.activeWalk)
            } else {
                defaults.removeObject(forKey: Key.activeWalk)
            }
        }
    }
```

Replace:

```swift
        recents = Self.load(Recents.self, from: defaults, forKey: Key.recents) ?? Recents()
    }
```

with:

```swift
        recents = Self.load(Recents.self, from: defaults, forKey: Key.recents) ?? Recents()
        activeWalk = Self.load(ActiveWalk.self, from: defaults, forKey: Key.activeWalk)
    }
```

Setting a property in its own class's `init` doesn't run `didSet`, so loading doesn't write the walk back.

- [ ] **Step 3: Save, offer and resume in `WalkSession`**

Replace the whole of `ios/KeepThePace/WalkSession.swift` with the version below. Compared with Task 7:
- `init` offers a resumable walk, or ends leftover Live Activities.
- `resume()` and `discardResume()` are new.
- `begin` takes an engine and a starting status, so a resumed walk carries on where it left off. It discards a pending walk when a new one starts.
- `tick()` saves real walks when it updates the Live Activity.
- Arrival and `finish()` clear the saved walk.

```swift
import Foundation
import Observation
import PaceKit
import SwiftUI

/// The app's walk flow: setup → walk → arrived. Planning, pace maths, arrival and alert rules live
/// in PaceKit (`WalkPlanner`, `Session.begin`, `WalkEngine`, `WalkAlerts`); this class wires them to
/// the GPS, the demo walk, Apple Maps routing, the Live Activity, haptics and a one-second clock.
/// Every one of those can be replaced by a fake in tests.
@MainActor
@Observable
final class WalkSession {
    enum Phase {
        case setup, walk, arrived
    }

    /// How long an arrived walk's Live Activity stays on the lock screen (spec §2).
    static let arrivedActivitySec: TimeInterval = 4 * 60

    private(set) var phase: Phase = .setup
    private(set) var planner = WalkPlanner()
    private(set) var engine: WalkEngine?
    private(set) var metrics: WalkMetrics?
    /// A walk the app was force-quit during, offered as Resume or End (spec §2).
    private(set) var pendingResume: ActiveWalk?

    let location: any LocationProviding
    let search: PlaceSearchService
    @ObservationIgnored private let routes: any RouteProviding
    @ObservationIgnored private let saved: SavedData
    @ObservationIgnored private let liveActivity: any LiveActivityControlling
    @ObservationIgnored private let feedback: any FeedbackPlaying
    @ObservationIgnored private let clock: () -> Date
    @ObservationIgnored private let tickInterval: Duration?
    @ObservationIgnored private var demo: DemoLocationSource?
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var walkID = 0
    @ObservationIgnored private var refreshingRoute = false
    @ObservationIgnored private var alerts = WalkAlerts(thresholdSec: AlertThreshold.thirty.seconds)
    @ObservationIgnored private var appActive = true

    /// `clock` and `tickInterval` exist for tests: a test passes its own clock and a nil interval,
    /// and calls `tick()` itself.
    init(
        saved: SavedData, location: any LocationProviding = LocationService(),
        search: PlaceSearchService = PlaceSearchService(), routes: any RouteProviding = RouteService(),
        liveActivity: any LiveActivityControlling = LiveActivityController(),
        feedback: any FeedbackPlaying = FeedbackController(), clock: @escaping () -> Date = { .now },
        tickInterval: Duration? = .seconds(1)
    ) {
        self.saved = saved
        self.location = location
        self.search = search
        self.routes = routes
        self.liveActivity = liveActivity
        self.feedback = feedback
        self.clock = clock
        self.tickInterval = tickInterval
        location.onFix = { [weak self] fix in self?.liveFix(fix) }
        if let active = saved.activeWalk, active.isResumable(now: clock()) {
            pendingResume = active
        } else {
            saved.activeWalk = nil
            liveActivity.endAll()
        }
    }

    /// The latest live GPS fix, used as the walk's start point.
    var origin: GPSFix? { location.latestFix }

    var canStart: Bool { planner.canStart(hasLocation: origin != nil) }

    // MARK: Setup

    /// Starts GPS for the setup screen if the user already allowed it. The permission prompt
    /// waits until they search or tap Start.
    func setupAppeared() {
        if location.access == .allowed { location.start() }
    }

    /// Starts GPS, asking for permission first if needed. Called on the first search and from the
    /// "Enable location" prompt (spec: location is requested at the moment it's needed).
    func requestLocation() {
        location.start()
    }

    /// The app moved to or from the foreground. Status changes buzz in the app only while it is
    /// active. In setup, GPS stops in the background, so an old fix is never a walk's start point.
    func sceneChanged(_ scene: ScenePhase) {
        appActive = scene == .active
        guard phase == .setup else { return }
        switch scene {
        case .background: location.stop()
        case .active: setupAppeared()
        default: break
        }
    }

    func choose(_ place: Place) {
        let from = origin?.coordinate
        guard let planID = planner.choose(place, from: from, now: clock()), let from else { return }
        routePlan(planID, from: from, to: place.coordinate)
    }

    /// Upgrades the plan to the walking-route distance when Apple Maps answers.
    private func routePlan(_ planID: Int, from: LatLon, to: LatLon) {
        Task {
            let distance = await routes.walkingDistanceM(from: from, to: to)
            planner.routeResolved(planID: planID, distanceM: distance, now: clock())
        }
    }

    func bumpArriveBy(minutes: Int) {
        planner.bump(minutes: minutes, now: clock())
    }

    func setArriveBy(_ picked: Date) {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: picked)
        planner.setArriveBy(hour: parts.hour ?? 0, minute: parts.minute ?? 0, now: clock(), calendar: .current)
    }

    // MARK: Walking

    func startWalking() {
        guard let fix = origin, let session = planner.beginSession(from: fix.coordinate, now: clock()) else {
            location.start()
            return
        }
        begin(WalkEngine(session: session), status: .onTime, firstFix: fix)
    }

    /// A simulated walk to the chosen destination (or the default demo destination), 280 m away.
    func startDemo() {
        let dest = planner.destination ?? DemoWalk.defaultDestination
        let start = DemoWalk.startPoint(for: dest.coordinate)
        let now = clock()
        let session = Session.begin(
            dest: dest, from: start, plannedDistanceM: nil,
            arriveBy: DemoWalk.arriveBy(start: start, dest: dest.coordinate, now: now),
            now: now, demo: true, routed: false)
        location.stop()
        let source = DemoLocationSource(start: start, dest: dest.coordinate, now: now)
        source.onFix = { [weak self] fix in self?.walkFix(fix) }
        demo = source
        begin(WalkEngine(session: session), status: .onTime, firstFix: nil)
        source.start()
    }

    /// Picks up the walk the app was force-quit during.
    func resume() {
        guard let active = pendingResume else { return }
        pendingResume = nil
        location.start()
        begin(active.engine, status: active.status, firstFix: nil)
    }

    /// Ends the walk the app was force-quit during, without resuming it.
    func discardResume() {
        pendingResume = nil
        saved.activeWalk = nil
        liveActivity.endAll()
    }

    /// Ends the walk (End) or leaves the arrived screen (Done).
    func finish() {
        if phase == .walk { liveActivity.end(nil, dismissAfter: nil) }
        stopWalk()
        saved.activeWalk = nil
        engine = nil
        metrics = nil
        phase = .setup
        if location.access == .allowed { location.start() }
    }

    private func begin(_ engine: WalkEngine, status: PaceStatus, firstFix: GPSFix?) {
        if pendingResume != nil { discardResume() }
        walkID += 1
        refreshingRoute = false
        self.engine = engine
        alerts = WalkAlerts(thresholdSec: saved.settings.alertThreshold.seconds, status: status)
        saved.recents.record(engine.session.dest)
        phase = .walk
        if !engine.session.demo { location.setBackgroundTracking(true) }
        if let firstFix {
            walkFix(firstFix)
        } else {
            tick()
        }
        guard let tickInterval else { return }
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: tickInterval)
                self?.tick()
            }
        }
    }

    private func liveFix(_ fix: GPSFix) {
        switch phase {
        case .setup:
            // A place picked before the first fix is planned from here.
            if let planID = planner.originFound(fix.coordinate, now: clock()), let dest = planner.destination {
                routePlan(planID, from: fix.coordinate, to: dest.coordinate)
            }
        case .walk:
            guard engine?.session.demo == false else { return }
            walkFix(fix)
            refreshRouteIfDue()
        case .arrived:
            break
        }
    }

    private func walkFix(_ fix: GPSFix) {
        engine?.ingest(fix)
        tick()
    }

    /// Location is paused when the user turns it off during a real walk (spec §2).
    private var locationPaused: Bool {
        engine?.session.demo == false && location.access == .denied
    }

    /// Recomputes the walk's numbers and applies `WalkAlerts`' decision: a haptic, a Live Activity
    /// update (with an alert when the status changed while the app was in the background), and the
    /// saved walk for resuming. Runs on every fix and once a second.
    func tick() {
        guard phase == .walk, let session = engine?.session, let metrics = engine?.metrics(now: clock()) else { return }
        self.metrics = metrics
        let decision = alerts.update(
            metrics, units: saved.units, locationPaused: locationPaused, now: clock(), appActive: appActive,
            hapticsOn: saved.settings.phoneHaptics)
        if let haptic = decision.haptic { feedback.play(haptic) }
        if let state = decision.activity {
            if metrics.arrived {
                liveActivity.end(state, dismissAfter: Self.arrivedActivitySec)
            } else {
                liveActivity.show(state, for: session, alert: decision.alert)
                if !session.demo, let engine { saved.activeWalk = ActiveWalk(engine: engine, status: alerts.status) }
            }
        }
        if metrics.arrived {
            stopWalk()
            saved.activeWalk = nil
            phase = .arrived
        }
    }

    private func refreshRouteIfDue() {
        guard !refreshingRoute, let engine, engine.needsRouteRefresh(now: clock()), let from = engine.lastFix else { return }
        refreshingRoute = true
        let id = walkID
        let to = engine.session.dest.coordinate
        Task {
            let distance = await routes.walkingDistanceM(from: from.coordinate, to: to)
            guard id == walkID else { return }
            if let distance {
                self.engine?.routeRefreshed(distanceM: distance, from: from.coordinate, now: clock())
            } else {
                self.engine?.routeRefreshFailed(now: clock())
            }
            refreshingRoute = false
        }
    }

    private func stopWalk() {
        ticker?.cancel()
        ticker = nil
        demo?.stop()
        demo = nil
        if engine?.session.demo == false {
            location.setBackgroundTracking(false)
            location.stop()
        }
    }
}
```

- [ ] **Step 4: The Resume card**

In `ios/KeepThePace/SetupView.swift`, replace:

```swift
            VStack(alignment: .leading, spacing: 24) {
                searchField
```

with:

```swift
            VStack(alignment: .leading, spacing: 24) {
                if let active = walk.pendingResume {
                    resumeCard(active)
                }
                searchField
```

In `ios/KeepThePace/SetupView.swift`, replace:

```swift
    // MARK: Start
```

with:

```swift
    // MARK: Resume

    /// A walk the app was force-quit during (spec §2): resume it or end it.
    private func resumeCard(_ active: ActiveWalk) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            MetricLabel("Walk in progress")
            Text(active.engine.session.dest.name)
                .font(.title3.weight(.medium))
                .foregroundStyle(Theme.foreground)
            Text("Arrive by \(Format.clock(active.engine.session.arriveBy))")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Theme.muted)
            HStack(spacing: 12) {
                Button("Resume") { walk.resume() }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("resumeButton")
                Button("End walk") { walk.discardResume() }
                    .buttonStyle(OutlineButtonStyle())
                    .accessibilityIdentifier("endResumedWalkButton")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
    }

    // MARK: Start
```

- [ ] **Step 5: Run the tests to see them pass**

Run each:
1. `cd ios && make test-app > /tmp/ktp-t8.log 2>&1; echo "exit $?"; grep -E "Test run with|TEST SUCCEEDED|TEST FAILED|error:|warning:" /tmp/ktp-t8.log | grep -v appintentsmetadataprocessor`: `exit 0`, `✔ Test run with 18 tests in 4 suites passed`, `** TEST SUCCEEDED **`, and no warnings.
2. `cd ios && make build-ios > /tmp/ktp-b8.log 2>&1; echo "exit $?"; grep -E "error:|warning:" /tmp/ktp-b8.log | grep -v appintentsmetadataprocessor`: `exit 0` and no grep output.

- [ ] **Step 6: Commit**

```bash
git add ios/KeepThePace ios/KeepThePaceTests
git commit -m "iOS: resume a walk after a force-quit

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Simulated walks, the device-walk checklist, docs and full verification

**Files:**
- Modify: `ios/Makefile` (`sim-start` and `sim-walk`)
- Create: `docs/checklists/m3-device-walk.md`
- Modify: `CLAUDE.md` (the iOS section)

**Interfaces:**
- Consumes: everything above.
- Produces:
  - `make sim-start` and `make sim-walk`, with `SIM_FROM`, `SIM_TO` and `SIM_SPEED` overridable
  - the M3 device-walk checklist

- [ ] **Step 1: Simulated walks**

In `ios/Makefile`, replace:

```make
.PHONY: generate test golden build-ios build-watch test-app test-ui
```

with:

```make
.PHONY: generate test golden build-ios build-watch test-app test-ui sim-start sim-walk
```

Append to `ios/Makefile`:

```make

# Simulated GPS for the booted iPhone simulator. `make sim-start` puts it near Grand Central, about
# 500 m from Bryant Park. Start a walk to Bryant Park in the app, then `make sim-walk` walks there at
# SIM_SPEED m/s. Try SIM_SPEED=0.6 to fall behind and SIM_SPEED=3 to get ahead.
SIM_FROM ?= 40.7527,-73.9772
SIM_TO ?= 40.75377,-73.98358
SIM_SPEED ?= 1.4

sim-start:
	xcrun simctl location booted set $(SIM_FROM)

sim-walk:
	xcrun simctl location booted start --speed=$(SIM_SPEED) $(SIM_FROM) $(SIM_TO)
```

`booted` is used rather than the device name because two simulators may both be called "iPhone 17". `SIM_TO` is within the 18 m arrival radius of Apple Maps' Bryant Park pin.

- [ ] **Step 2: The device-walk checklist**

Create `docs/checklists/m3-device-walk.md`:

````markdown
# M3 device walk: checklist

This is the M3 exit check (spec §5): a real walk with the phone locked, where the Live Activity stays current and the phone buzzes on status changes. Allow about 25 minutes, including a 10-minute walk.

## Before you go

- [ ] Install the app on your iPhone:
  - In `ios/`, run `make generate`, open `KeepThePace.xcodeproj` in Xcode, choose your iPhone and press Run.
  - Signing is automatic with team 3DLV25C9VK.
  - The first install may ask you to trust the developer in Settings › General › VPN & Device Management.
- [ ] In the app, open Settings › Alerts: set the threshold to 30 s and turn iPhone haptics on.
- [ ] Silent mode is fine either way. When silent, lock-screen alerts vibrate as long as Settings › Sounds & Haptics lets haptics play in silent mode.

## The walk (about 10 minutes)

Pick a place 0.5–0.8 mi (800–1300 m) away, and keep the arrive-by time the app suggests.

1. [ ] Type in the search field. The location prompt appears now, not at launch. Choose Allow While Using App, with Precise on.
2. [ ] The destination card shows "X mi walk · ~N min" and the line above Start says "GPS ready". Tap Start walking.
3. [ ] The first time, iOS asks on the lock screen whether to allow Live Activities from Keep the Pace. Choose Allow, and later Always Allow.
4. [ ] Lock the phone and walk normally for a minute, then look. The lock screen shows the destination, the ±m:ss in the pace colour, the distance left and the arrive-by time. The location indicator is on.
5. [ ] Stand still for about a minute. The phone buzzes and the lock screen lights up with "Falling behind", the ±m:ss and the distance to go.
6. [ ] Walk briskly until you are back within 25 s. It buzzes again: "Back on pace".
7. [ ] Unlock and keep the app open through the next status change. You feel a haptic instead of the lock-screen alert:
   - falling behind: two taps, stepping down
   - getting ahead: two taps, stepping up
   - back on pace: one soft tap
8. [ ] On the home screen, the Dynamic Island shows the ±m:ss on the left and the distance on the right. Touch and hold it for the full view.
9. [ ] Arrive. The lock screen shows "ARRIVED m:ss EARLY" (or LATE, or ON TIME) and "Target h:mm". It disappears about 4 minutes later, and the location indicator goes off.

## Force-quit and resume (about 5 minutes)

10. [ ] Start another walk, then swipe the app away in the app switcher.
11. [ ] After 2–3 minutes, the lock screen says "Not updating. Open Keep the Pace."
12. [ ] Open the app. A "Walk in progress" card offers Resume and End walk. Tap Resume: the walk carries on with the same arrive-by, and the same Live Activity updates again. There is no second one.
13. [ ] End the walk. The Live Activity disappears at once.

## Edge cases

14. [ ] During a walk, set Settings › Privacy & Security › Location Services › Keep the Pace to Never. The walk screen shows the "Location paused" banner and the Live Activity says "Location paused". Set it back to While Using the App: tracking carries on.
15. [ ] Turn Precise Location off for Keep the Pace. The setup screen shows "Precise Location is off. Tap to allow it for this walk." Tap it and allow: "GPS ready" follows.
16. [ ] Turn off Settings › Alerts › iPhone haptics in the app. Status changes no longer buzz, in the app or on the lock screen. The Live Activity still updates.

## If something is off

Note the time and what you saw. With the phone connected to the Mac:
1. Open Console.app and select the phone.
2. Turn on Action › Include Info Messages and Include Debug Messages.
3. Search for `com.iliasrafailidis.delta`.

You'll see three kinds of line:
- "Status alert: …" for each alert the app sent.
- "Dropped a stale reading" or "Dropped an inaccurate reading" for each GPS reading it ignored.
- "No walking route: …" when Apple Maps couldn't route, so the distance fell back to the straight line.

Many stale drops while you walk mean the 1 s stale-fix limit (spec §1) needs tuning.

## Results

| Steps | Pass? | Notes |
|---|---|---|
| 1–9 walk | | |
| 10–13 resume | | |
| 14–16 edge cases | | |
````

- [ ] **Step 3: Update CLAUDE.md**

In `CLAUDE.md`, replace:

```markdown
- **Targets:** `KeepThePace` (iOS app), `PaceActivity` (Live Activity extension), `KeepThePaceWatch` (watchOS app, embedded in the iOS app) and `PaceComplication` (watch widget extension) all depend on the local package `ios/PaceKit`. `KeepThePaceUITests` holds the demo-walk UI test that `make test-ui` runs.
```

with:

```markdown
- **Targets:** `KeepThePace` (iOS app), `PaceActivity` (Live Activity extension), `KeepThePaceWatch` (watchOS app, embedded in the iOS app) and `PaceComplication` (watch widget extension) all depend on the local package `ios/PaceKit`. `KeepThePaceTests` holds the app's unit tests (`make test-app`) and `KeepThePaceUITests` the demo-walk UI test (`make test-ui`). `ios/Shared/` is compiled into both `KeepThePace` and `PaceActivity`: the theme and the Live Activity's `PaceActivityAttributes`.
```

In `CLAUDE.md`, replace:

```markdown
- **The iPhone app** (`ios/KeepThePace/`): `WalkSession` runs setup → walk → arrived by wiring PaceKit's `WalkPlanner`, `Session.begin` and `WalkEngine` to `LocationService` (foreground GPS through `SpeedEstimator`), `DemoLocationSource`, `RouteService` (MapKit walking distance) and `PlaceSearchService` (MapKit type-ahead). `SavedData` keeps settings, favorites and recents in the App Group's defaults. Put rules in PaceKit, where `swift test` covers them; the app layer only wires and draws.
```

with:

```markdown
- **The iPhone app** (`ios/KeepThePace/`): `WalkSession` runs setup → walk → arrived by wiring PaceKit's `WalkPlanner`, `Session.begin`, `WalkEngine` and `WalkAlerts` to the services behind the protocols in `WalkServices.swift`: `LocationService` (GPS through `SpeedEstimator`, kept running in the background during walks), `RouteService` (MapKit walking distance), `LiveActivityController` (ActivityKit) and `FeedbackController` (Core Haptics). `DemoLocationSource` drives demo walks and `PlaceSearchService` the MapKit type-ahead. `SavedData` keeps settings, favorites, recents and the walk in progress (for Resume after a force-quit) in the App Group's defaults. `KeepThePaceTests` drives `WalkSession` with fakes. Put rules in PaceKit, where `swift test` covers them; the app layer only wires and draws.
```

In `CLAUDE.md`, replace:

```
make build-watch   # generate + build the watch app for the simulator
make test-ui       # demo-walk UI test on the iPhone simulator (about 3 minutes)
```

with:

```
make build-watch   # generate + build the watch app for the simulator
make test-app      # app unit tests: WalkSession with fake GPS, routing, Live Activity and haptics
make test-ui       # demo-walk UI test on the iPhone simulator (about 3 minutes)
make sim-start     # put the booted simulator's GPS near Grand Central, about 500 m from Bryant Park
make sim-walk      # walk it to Bryant Park at SIM_SPEED m/s (default 1.4; 0.6 falls behind, 3 gets ahead)
```

In `CLAUDE.md`, replace:

```markdown
Makefile simulator builds carry no entitlements, so check App Group or HealthKit behaviour in a build run from Xcode.
```

with:

```markdown
Makefile simulator builds carry no entitlements, so check App Group or HealthKit behaviour in a build run from Xcode.

The simulator shows the Live Activity and runs background location: use `make sim-start` and `make sim-walk`, and lock it with Device › Lock. It has no haptics, though, so judge alerts and haptics on a real iPhone with `docs/checklists/m3-device-walk.md`.
```

- [ ] **Step 4: Full verification**

Run each of these and check the result:
1. `cd ios && make test 2>&1 | tail -1`: `Test run with 109 tests in 17 suites passed`, with no warnings.
2. `cd ios && make test-app > /tmp/ktp-t9.log 2>&1; echo "exit $?"; grep -E "Test run with|TEST SUCCEEDED|TEST FAILED|warning:" /tmp/ktp-t9.log | grep -v appintentsmetadataprocessor`: `exit 0`, `✔ Test run with 18 tests in 4 suites passed` and `** TEST SUCCEEDED **`.
3. `cd ios && make build-ios > /tmp/ktp-b9.log 2>&1; echo "exit $?"; grep -E "error:|warning:" /tmp/ktp-b9.log | grep -v appintentsmetadataprocessor`: `exit 0` and no grep output.
4. `cd ios && make build-watch > /tmp/ktp-w9.log 2>&1; echo "exit $?"; grep -E "error:|warning:" /tmp/ktp-w9.log | grep -v appintentsmetadataprocessor`: `exit 0` and no grep output.
5. Launch the watch app on its simulator. The M1 review asked every plan to launch it, not only build it. Two simulators may share the name, so this takes the first by its ID:

```bash
cd ios
WATCH=$(xcrun simctl list devices available | grep -m1 "Apple Watch Series 11 (46mm)" | grep -oE "[0-9A-F-]{36}")
xcrun simctl boot "$WATCH" 2>/dev/null; xcrun simctl bootstatus "$WATCH" -b > /dev/null
xcrun simctl install "$WATCH" build/Build/Products/Debug-watchsimulator/KeepThePaceWatch.app
xcrun simctl launch "$WATCH" com.iliasrafailidis.delta.watchkitapp
```

Expected: the last line prints `com.iliasrafailidis.delta.watchkitapp:` followed by a process ID. The watch app is still M0's placeholder until M5.

6. `cd ios && make test-ui > /tmp/ktp-ui9.log 2>&1; echo "exit $?"; grep -E "Test Case|TEST SUCCEEDED|TEST FAILED|error:" /tmp/ktp-ui9.log`: `exit 0`, the demo walk passed and `** TEST SUCCEEDED **`. This takes 4–6 minutes: use the Bash tool's 600000 ms timeout, or run it in the background. Never `sleep`.
7. `git status --short`: only this task's three files, plus the untracked `.claude/`.

- [ ] **Step 5: Simulated locked walk**

This step needs someone who can tap in the simulator. If your tools can't tap, say so in your report and the controller will run it.
1. Make sure exactly one simulator is booted, because `booted` in the commands below means that one. `xcrun simctl list devices booted` lists them. Shut down any extra ones, or boot an iPhone 17 by its ID from `xcrun simctl list devices available`. Then run `cd ios && make sim-start`, and from the repo root `xcrun simctl install booted ios/build/Build/Products/Debug-iphonesimulator/KeepThePace.app && xcrun simctl launch booted com.iliasrafailidis.delta`.
2. In the app:
   - Tap the search field and allow location (While Using the App).
   - Type `Bryant Park` and pick the Manhattan result.
   - Once the card shows its walk distance, tap Start walking.
3. Lock the simulator (Device › Lock). Then run `cd ios && make sim-walk SIM_SPEED=0.6` and wait about a minute. If iOS asks whether to allow Live Activities, choose Allow.
4. Run `xcrun simctl io booted screenshot /tmp/ktp-lock.png` and look at it. The Live Activity shows "Bryant Park", "… left · by …" and a ±m:ss LATE in the late colour.
5. Run `xcrun simctl spawn booted log show --last 5m --info --predicate 'subsystem == "com.iliasrafailidis.delta"' | grep "Status alert"`. It shows a line like `Status alert: Falling behind, −0:30 · 0.4 mi to go`.
6. Unlock the simulator and End the walk. The Live Activity disappears.

- [ ] **Step 6: Commit**

```bash
git add ios/Makefile docs/checklists/m3-device-walk.md CLAUDE.md
git commit -m "iOS: simulated walks, the M3 device-walk checklist, docs

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

After this task, M3's exit check is yours: walk with `docs/checklists/m3-device-walk.md` on your iPhone.
