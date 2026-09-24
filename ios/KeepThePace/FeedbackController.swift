import CoreHaptics
import PaceKit

/// Buzzes on status changes while the app is open (spec §1). The patterns follow the Watch's:
/// falling behind steps down, getting ahead steps up, back on pace is one soft tap. Phones
/// without haptics, and the simulator, stay silent.
@MainActor
final class FeedbackController: FeedbackPlaying {
    private var engine: CHHapticEngine?

    func play(_ status: PaceStatus) {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let engine = try self.engine ?? CHHapticEngine()
            engine.isAutoShutdownEnabled = true
            self.engine = engine
            try engine.start()
            let pattern = try CHHapticPattern(events: Self.taps(for: status), parameters: [])
            try engine.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
        } catch {
            // Haptics are a nicety: a failure here must never disturb the walk. Drop the engine so
            // the next status change starts a fresh one.
            engine = nil
        }
    }

    static func taps(for status: PaceStatus) -> [CHHapticEvent] {
        switch status {
        case .behind: [tap(at: 0, intensity: 1, sharpness: 0.8), tap(at: 0.18, intensity: 0.6, sharpness: 0.2)]
        case .ahead: [tap(at: 0, intensity: 0.6, sharpness: 0.2), tap(at: 0.18, intensity: 1, sharpness: 0.8)]
        case .onTime: [tap(at: 0, intensity: 0.5, sharpness: 0.5)]
        }
    }

    private static func tap(at time: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: time)
    }
}
