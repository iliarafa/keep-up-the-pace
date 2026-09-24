import PaceKit
import SwiftUI

/// The web app's palette (`src/styles.css`). The app is dark-only, like the web.
enum Theme {
    static let background = Color(hex: 0x0C0C0D)
    static let foreground = Color(hex: 0xF3F1EC)
    static let muted = Color(hex: 0x8E8C86)
    static let faint = Color(hex: 0x5C5B57)
    static let surface = Color(hex: 0x161617)
    static let surfaceRaised = Color(hex: 0x1C1C1E)
    static let line = Color(hex: 0x2A2A2C)
    static let accent = Color(hex: 0xE6E2D8)
    static let accentForeground = Color(hex: 0x0C0C0D)
    static let early = Color(hex: 0x8FAD9A)
    static let late = Color(hex: 0xC9897A)
    static let onTime = Color(hex: 0xF3F1EC)

    /// The pace colour: follows the ±m:ss readout's tone (within 3 s is on time), never the
    /// alert threshold.
    static func paceColor(_ tone: DeltaTone) -> Color {
        switch tone {
        case .early: early
        case .late: late
        case .ontime: onTime
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255)
    }
}

/// Small uppercase label above a value, like the web's `MetricLabel`.
struct MetricLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.medium))
            .tracking(2)
            .foregroundStyle(Theme.muted)
    }
}

/// Filled, full-width primary button (web: `Button` default variant).
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(Theme.accentForeground)
            .background(Theme.accent.opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.35))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

/// Outlined, full-width secondary button (web: `Button variant="outline"`).
struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(Theme.foreground)
            .background(configuration.isPressed ? Theme.surfaceRaised : Color.clear)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line))
    }
}
