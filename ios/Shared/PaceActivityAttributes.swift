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
