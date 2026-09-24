import Foundation
import Testing
@testable import PaceKit

@Suite struct ActiveWalkTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let dest = Place(name: "Bryant Park", area: "Manhattan", coordinate: LatLon(lat: 40.7536, lon: -73.9832))

    func walk(arriveIn seconds: TimeInterval, routed: Bool = false) -> ActiveWalk {
        let start = Geo.destinationPoint(from: dest.coordinate, bearingDeg: 180, distanceM: 800)
        let session = Session(
            dest: dest, start: start, startDistanceM: routed ? 950 : 800, startAt: now - 300,
            arriveBy: now + seconds, demo: false, routed: routed)
        var engine = WalkEngine(session: session)
        engine.ingest(GPSFix(coordinate: start, speedMps: 1.3, accuracyM: 5, timestamp: now - 300))
        engine.ingest(GPSFix(
            coordinate: Geo.moveTowards(from: start, to: dest.coordinate, distanceM: 350), speedMps: 1.3,
            accuracyM: 5, timestamp: now - 10))
        return ActiveWalk(engine: engine, status: .behind)
    }

    @Test func resumableUntilAnHourAfterArriveBy() {
        #expect(walk(arriveIn: 600).isResumable(now: now))
        #expect(walk(arriveIn: -3599).isResumable(now: now))
        #expect(!walk(arriveIn: -3600).isResumable(now: now))
    }

    @Test func arrivedWalkIsNotResumable() {
        var active = walk(arriveIn: 600)
        active.engine.ingest(GPSFix(coordinate: dest.coordinate, speedMps: 1.3, accuracyM: 5, timestamp: now))
        _ = active.engine.metrics(now: now)
        #expect(!active.isResumable(now: now))
    }

    @Test func roundTripsThroughJSON() throws {
        let active = walk(arriveIn: 600, routed: true)
        let decoded = try JSONDecoder().decode(ActiveWalk.self, from: JSONEncoder().encode(active))
        #expect(decoded == active)
        var a = active.engine
        var b = decoded.engine
        #expect(a.metrics(now: now) == b.metrics(now: now))
        #expect(decoded.status == .behind)
    }
}
