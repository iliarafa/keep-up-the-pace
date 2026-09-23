import Testing
@testable import PaceKit

@Suite struct CoordinateParserTests {
    @Test func parsesCommaAndSpaceSeparated() {
        let place = CoordinateParser.parse(" 40.7, -73.9 ")
        #expect(place?.name == "40.70000, -73.90000")
        #expect(place?.area == "Coordinates")
        #expect(place?.coordinate == LatLon(lat: 40.7, lon: -73.9))
        #expect(CoordinateParser.parse("40.7 -73.9")?.coordinate == LatLon(lat: 40.7, lon: -73.9))
        #expect(CoordinateParser.parse("-0.0, 5.0")?.name == "0.00000, 5.00000")
    }

    @Test func rejectsOutOfRangeAndNonCoordinates() {
        #expect(CoordinateParser.parse("91.0, 0.0") == nil)
        #expect(CoordinateParser.parse("0.0, 180.5") == nil)
        #expect(CoordinateParser.parse("40, -73") == nil)   // decimals are required, as on the web
        #expect(CoordinateParser.parse("Times Square") == nil)
    }
}
