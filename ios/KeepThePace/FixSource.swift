import PaceKit

/// Where a walk's fixes come from: the real GPS or the demo walk.
@MainActor
protocol FixSource: AnyObject {
    var onFix: ((GPSFix) -> Void)? { get set }
    func start()
    func stop()
}
