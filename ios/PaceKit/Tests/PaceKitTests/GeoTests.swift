import Foundation
import Testing
@testable import PaceKit

@Suite struct GeoTests {
    let golden = GoldenFixture.shared

    @Test func haversineMatchesWeb() {
        for c in golden.haversine {
            #expect(close(Geo.haversineM(c.a.latLon, c.b.latLon), c.out), "\(c)")
        }
    }

    @Test func bearingMatchesWeb() {
        for c in golden.bearing {
            #expect(close(Geo.bearingDeg(from: c.from.latLon, to: c.to.latLon), c.out), "\(c)")
        }
    }

    @Test func destinationPointMatchesWeb() {
        for c in golden.destinationPoint {
            let p = Geo.destinationPoint(from: c.from.latLon, bearingDeg: c.bearing, distanceM: c.dist)
            #expect(close(p.lat, c.out.lat) && close(p.lon, c.out.lon), "\(c)")
        }
    }

    @Test func moveTowardsMatchesWeb() {
        for c in golden.moveTowards {
            let p = Geo.moveTowards(from: c.from.latLon, to: c.to.latLon, distanceM: c.dist)
            #expect(close(p.lat, c.out.lat) && close(p.lon, c.out.lon), "\(c)")
        }
    }

    @Test func cardinalMatchesWeb() {
        for c in golden.cardinal {
            #expect(Geo.cardinal(c.deg) == c.out, "\(c)")
        }
    }

    @Test func cardinalOfNonFiniteIsNorth() {
        #expect(Geo.cardinal(.nan) == "N")
        #expect(Geo.cardinal(.infinity) == "N")
    }

    @Test func walkEstimateMatchesWeb() {
        for c in golden.walkEstimateMs {
            #expect(close(Geo.walkEstimateSec(distanceM: c.dist, paceMps: c.pace) * 1000, c.out), "\(c)")
        }
    }

    @Test func roundUpToMinuteMatchesWeb() {
        for c in golden.roundUpToMinute {
            let ms = (Geo.roundUpToMinute(date(ms: c.ms)).timeIntervalSince1970 * 1000).rounded()
            #expect(ms == c.out, "\(c)")
        }
    }
}
