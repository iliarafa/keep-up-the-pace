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
