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
    /// Ends the walk's Live Activity showing `state`, adopting it first if an earlier launch
    /// started it. It stays on the lock screen for `dismissAfter` seconds, or goes at once when
    /// that is nil.
    func end(_ state: PaceActivityState?, for session: Session, dismissAfter: TimeInterval?)
    /// Ends every Live Activity an earlier launch left behind.
    func endAll()
}

/// In-app haptics for status changes: `FeedbackController` (Core Haptics) in the app.
@MainActor
protocol FeedbackPlaying: AnyObject {
    func play(_ status: PaceStatus)
}
