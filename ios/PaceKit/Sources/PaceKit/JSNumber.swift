import Foundation

/// Number rounding and formatting that match JavaScript exactly, so the Swift
/// output equals what the web app shows for the same input.
enum JSNumber {
    /// `Math.round`: halves round toward +∞.
    static func round(_ x: Double) -> Double {
        let f = x.rounded(.down)
        return x - f >= 0.5 ? f + 1 : f
    }

    /// `Number.prototype.toFixed`. Ties go to the larger magnitude, judged on
    /// the exact binary value — unlike `String(format:)`, which rounds ties to even.
    static func toFixed(_ x: Double, _ digits: Int) -> String {
        if x < 0 { return "-" + toFixed(-x, digits) }
        let p = pow(10.0, Double(digits))
        let s = x * p
        let err = (-s).addingProduct(x, p)  // exact rounding error of x * p
        var n = s.rounded(.down)
        let frac = s - n
        if frac > 0.5 || (frac == 0.5 && err >= 0) { n += 1 }
        return String(format: "%.\(digits)f", n / p)
    }
}
