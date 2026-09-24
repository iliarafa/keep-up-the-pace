import Foundation

/// A walk in progress, saved so it can be resumed after the app is force-quit (spec §1 `Stores`,
/// §2 failure cases). Demo walks are never saved.
public struct ActiveWalk: Codable, Equatable, Sendable {
    /// A walk whose arrive-by passed longer ago than this is not offered again.
    public static let resumeWindowSec: TimeInterval = 60 * 60

    public var engine: WalkEngine
    /// The last alert status, so a resumed walk doesn't buzz again for a change it already announced.
    public var status: PaceStatus

    public init(engine: WalkEngine, status: PaceStatus) {
        self.engine = engine
        self.status = status
    }

    /// Whether to offer Resume on launch: the walk hasn't arrived, and arrive-by is less than an
    /// hour ago.
    public func isResumable(now: Date) -> Bool {
        !engine.arrived && now.timeIntervalSince(engine.session.arriveBy) < Self.resumeWindowSec
    }
}
