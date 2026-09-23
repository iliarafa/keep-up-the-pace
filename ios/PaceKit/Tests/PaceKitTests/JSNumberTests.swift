import Testing
@testable import PaceKit

@Suite struct JSNumberTests {
    @Test func roundSendsHalvesTowardPositiveInfinity() {
        #expect(JSNumber.round(2.5) == 3)
        #expect(JSNumber.round(-2.5) == -2)
        #expect(JSNumber.round(-2.6) == -3)
    }

    @Test func toFixedRoundsTiesLikeJavaScript() {
        #expect(JSNumber.toFixed(0.25, 1) == "0.3")   // String(format:) gives "0.2"
        #expect(JSNumber.toFixed(1.005, 2) == "1.00") // binary value is just below the tie
        #expect(JSNumber.toFixed(-73.958751, 5) == "-73.95875")
        #expect(JSNumber.toFixed(12.5, 0) == "13")
        #expect(JSNumber.toFixed(-0.0, 1) == "0.0")
    }

    @Test func toFixedFiveDecimalsMatchesWeb() {
        for c in GoldenFixture.shared.toFixed5 {
            #expect(JSNumber.toFixed(c.x, 5) == c.out, "\(c)")
        }
    }
}
