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
