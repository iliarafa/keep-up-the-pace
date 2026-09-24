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
