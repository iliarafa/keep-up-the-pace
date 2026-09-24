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
