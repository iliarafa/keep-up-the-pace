import Testing
@testable import PaceKit

@Suite struct LatLonTests {
    @Test func storesCoordinates() {
        let p = LatLon(lat: 40.74551, lon: -73.95875)
        #expect(p.lat == 40.74551)
        #expect(p.lon == -73.95875)
    }
}
