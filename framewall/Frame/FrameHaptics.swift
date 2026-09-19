import CoreHaptics
import Foundation

/// The soft thump of a frame coming to rest. (code.md §2, "Haptics")
///
/// "The goal is that a frame feels like it has weight." A single sharp tap reads as
/// a UI click, so this is a muted knock followed by a short decaying body — contact,
/// then the mass behind it settling.
@MainActor
final class FrameHaptics {

    private var engine: CHHapticEngine?
    private var isSupported: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    func prepare() {
        guard isSupported, engine == nil else { return }
        do {
            let engine = try CHHapticEngine()
            // The system stops the engine when the app backgrounds; without these
            // the first haptic after returning is silently dropped.
            engine.resetHandler = { [weak engine] in try? engine?.start() }
            engine.stoppedHandler = { _ in }
            try engine.start()
            self.engine = engine
        } catch {
            // A device without haptics is a soft failure — the frame still works.
            engine = nil
        }
    }

    /// Play when a swiped piece lands.
    func settle() {
        guard let engine else { return }
        do {
            let pattern = try CHHapticPattern(events: Self.settleEvents, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // Dropping a haptic is never worth interrupting the interaction.
        }
    }

    func stop() {
        engine?.stop()
        engine = nil
    }

    private static var settleEvents: [CHHapticEvent] {
        [
            // Contact: dull rather than crisp, so it reads as mass, not a click.
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    .init(parameterID: .hapticIntensity, value: 0.55),
                    .init(parameterID: .hapticSharpness, value: 0.25)
                ],
                relativeTime: 0
            ),
            // The body settling behind it.
            CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    .init(parameterID: .hapticIntensity, value: 0.22),
                    .init(parameterID: .hapticSharpness, value: 0.10)
                ],
                relativeTime: 0.015,
                duration: 0.11
            )
        ]
    }
}
