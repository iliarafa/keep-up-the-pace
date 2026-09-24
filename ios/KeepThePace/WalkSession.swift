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
        // Judge the pace from where the walker is now when GPS already has a fix. The saved fix is
        // from before the force-quit, and WalkAlerts won't judge by it.
        begin(active.engine, status: active.status, firstFix: origin)
    }

    /// Ends the walk the app was force-quit during, without resuming it.
    func discardResume() {
        pendingResume = nil
        saved.activeWalk = nil
        liveActivity.endAll()
    }

    /// Ends the walk (End) or leaves the arrived screen (Done).
    func finish() {
        if phase == .walk, let session = engine?.session { liveActivity.end(nil, for: session, dismissAfter: nil) }
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
        guard let tickInterval, phase == .walk else { return }  // the first fix may already have arrived
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
    var locationPaused: Bool {
        engine?.session.demo == false && location.access == .denied
    }

    /// Recomputes the walk's numbers and applies `WalkAlerts`' decision: a haptic, a Live Activity
    /// update (with an alert when the status changed while the app was in the background), and the
    /// saved walk for resuming. Runs on every fix and once a second.
    func tick() {
        guard phase == .walk, let session = engine?.session, let fixAt = engine?.lastFix?.timestamp,
              let metrics = engine?.metrics(now: clock()) else { return }
        self.metrics = metrics
        let decision = alerts.update(
            metrics, fixAt: fixAt, units: saved.units, locationPaused: locationPaused, now: clock(),
            appActive: appActive, hapticsOn: saved.settings.phoneHaptics)
        if let haptic = decision.haptic { feedback.play(haptic) }
        if let state = decision.activity {
            if metrics.arrived {
                liveActivity.end(state, for: session, dismissAfter: Self.arrivedActivitySec)
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
