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
    /// This walk's readings, for one log line when it ends: used, dropped as stale (with the
    /// oldest), dropped as inaccurate.
    @ObservationIgnored private var tally = (used: 0, stale: 0, oldestStaleSec: 0.0, inaccurate: 0)
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
        if on {
            tally = (0, 0, 0, 0)
        } else {
            log.notice("""
                Walk GPS: \(self.tally.used) readings used, \(self.tally.stale) stale \
                (oldest \(self.tally.oldestStaleSec, format: .fixed(precision: 1)) s), \
                \(self.tally.inaccurate) inaccurate
                """)
        }
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
                switch reason {
                case .stale:
                    tally.stale += 1
                    tally.oldestStaleSec = max(tally.oldestStaleSec, age)
                case .inaccurate:
                    tally.inaccurate += 1
                }
                log.debug("""
                    Dropped reading (\(reason.rawValue, privacy: .public)): \
                    accuracy \(location.horizontalAccuracy, format: .fixed(precision: 0)) m, \
                    age \(age, format: .fixed(precision: 1)) s
                    """)
            }
            return
        }
        tally.used += 1
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
