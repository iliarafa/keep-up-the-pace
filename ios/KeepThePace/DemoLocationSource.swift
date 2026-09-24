import Foundation
import PaceKit

/// The demo walk as a fix source: PaceKit's `DemoWalk`, one step every 250 ms.
@MainActor
final class DemoLocationSource: FixSource {
    var onFix: ((GPSFix) -> Void)?
    private let dest: LatLon
    private var current: GPSFix
    private var task: Task<Void, Never>?

    init(start: LatLon, dest: LatLon, now: Date) {
        self.dest = dest
        current = DemoWalk.firstFix(start: start, now: now)
    }

    func start() {
        onFix?(current)
        task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(DemoWalk.tickInterval))
                guard let self, !Task.isCancelled else { return }
                current = DemoWalk.step(from: current, toward: dest, now: .now)
                onFix?(current)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
