import Foundation
import PaceKit

/// Outputs recorded from the web app's TypeScript by `Scripts/make-golden.mjs`.
struct GoldenFixture: Decodable, Sendable {
    struct Point: Decodable, Sendable {
        let lat: Double
        let lon: Double
        var latLon: LatLon { LatLon(lat: lat, lon: lon) }
    }
    struct Haversine: Decodable, Sendable { let a: Point; let b: Point; let out: Double }
    struct Bearing: Decodable, Sendable { let from: Point; let to: Point; let out: Double }
    struct DestinationPoint: Decodable, Sendable { let from: Point; let bearing: Double; let dist: Double; let out: Point }
    struct MoveTowards: Decodable, Sendable { let from: Point; let to: Point; let dist: Double; let out: Point }
    struct Cardinal: Decodable, Sendable { let deg: Double; let out: String }
    struct WalkEstimate: Decodable, Sendable { let dist: Double; let pace: Double; let out: Double }
    struct RoundUp: Decodable, Sendable { let ms: Double; let out: Double }
    struct ScheduleDelta: Decodable, Sendable {
        let startDistanceM: Double; let remainingM: Double
        let startAt: Double; let arriveBy: Double; let now: Double
        let out: Double
    }
    struct Speed: Decodable, Sendable { let mps: Double; let units: String; let value: String; let unit: String }
    struct Distance: Decodable, Sendable { let m: Double; let units: String; let out: String }
    struct Duration: Decodable, Sendable { let ms: Double; let out: String }
    struct Delta: Decodable, Sendable { let sec: Double; let sign: String; let clock: String; let label: String; let tone: String }
    struct Heading: Decodable, Sendable { let deg: Double; let out: String }
    struct ToFixed: Decodable, Sendable { let x: Double; let out: String }

    let haversine: [Haversine]
    let bearing: [Bearing]
    let destinationPoint: [DestinationPoint]
    let moveTowards: [MoveTowards]
    let cardinal: [Cardinal]
    let walkEstimateMs: [WalkEstimate]
    let roundUpToMinute: [RoundUp]
    let scheduleDelta: [ScheduleDelta]
    let speed: [Speed]
    let distance: [Distance]
    let duration: [Duration]
    let delta: [Delta]
    let heading: [Heading]
    let toFixed5: [ToFixed]

    static let shared: GoldenFixture = {
        let url = Bundle.module.url(forResource: "golden", withExtension: "json", subdirectory: "Fixtures")!
        return try! JSONDecoder().decode(GoldenFixture.self, from: Data(contentsOf: url))
    }()
}

/// Equal within `tolerance`, scaled up for large magnitudes.
func close(_ a: Double, _ b: Double, _ tolerance: Double = 1e-9) -> Bool {
    abs(a - b) <= tolerance * max(1, abs(b))
}

func date(ms: Double) -> Date { Date(timeIntervalSince1970: ms / 1000) }
