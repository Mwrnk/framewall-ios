import CoreMotion
import Foundation
import simd

/// Device attitude, damped and clamped, for tilting a framed piece.
///
/// code.md §2: "Clamp the rotation to roughly ±8 degrees and damp it, or it feels
/// twitchy." Both halves matter — raw attitude is jittery enough to look broken.
///
/// **Use ``shared``.** Every frame on screen tilts by the same device attitude, and
/// Core Motion expects one `CMMotionManager` per app — a feed of posts each holding
/// its own would fight over the sensor and burn power for identical readings.
@Observable
@MainActor
final class FrameTilt {

    static let shared = FrameTilt()

    /// code.md §2. Past this the illusion breaks: you see the frame is a thin slab.
    static let maxAngle: Float = 8 * .pi / 180

    /// Fraction of the remaining distance to close each update. Low enough that the
    /// frame lags the device slightly, which is what gives it apparent weight.
    private static let damping: Float = 0.10

    private static let updateInterval: TimeInterval = 1.0 / 60.0

    /// Current smoothed rotation, radians. x is pitch, y is yaw.
    private(set) var pitch: Float = 0
    private(set) var yaw: Float = 0

    private let manager = CMMotionManager()
    private var reference: CMAttitude?
    private var targetPitch: Float = 0
    private var targetYaw: Float = 0

    /// How many frames are currently on screen. Updates run while this is above
    /// zero, so one post scrolling away doesn't freeze the rest of the feed.
    private var subscribers = 0

    private init() {}

    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    /// The rotation to apply to the frame entity.
    var rotation: simd_quatf {
        simd_quatf(angle: pitch, axis: [1, 0, 0]) * simd_quatf(angle: yaw, axis: [0, 1, 0])
    }

    /// Balance every call with ``release()``.
    func start() {
        subscribers += 1
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = Self.updateInterval
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            MainActor.assumeIsolated {
                self.ingest(motion.attitude)
            }
        }
    }

    /// Drops one subscriber, stopping the sensor once the last frame goes away.
    func release() {
        subscribers = max(0, subscribers - 1)
        guard subscribers == 0 else { return }
        stop()
    }

    /// Stops immediately regardless of subscriber count — for backgrounding.
    func stop() {
        manager.stopDeviceMotionUpdates()
        reference = nil
        targetPitch = 0
        targetYaw = 0
        pitch = 0
        yaw = 0
    }

    /// Restarts after a ``stop()`` if anything is still on screen.
    func resumeIfNeeded() {
        guard subscribers > 0, !manager.isDeviceMotionActive else { return }
        subscribers -= 1
        start()
    }

    /// Recentres on the current attitude, so the frame sits straight on from
    /// wherever the person is actually holding the phone.
    func recentre() {
        reference = nil
    }

    private func ingest(_ attitude: CMAttitude) {
        // The first sample becomes "straight on". Without this the frame starts
        // skewed by however the device happened to be held.
        guard let reference else {
            self.reference = attitude.copy() as? CMAttitude
            return
        }

        let relative = attitude.copy() as? CMAttitude ?? attitude
        relative.multiply(byInverseOf: reference)

        targetPitch = clamp(Float(relative.pitch))
        // Device roll turns the frame about its vertical axis — tip the phone left
        // and you look at the frame's left edge, as if leaning around it.
        targetYaw = clamp(Float(relative.roll))

        step()
    }

    private func step() {
        pitch += (targetPitch - pitch) * Self.damping
        yaw += (targetYaw - yaw) * Self.damping
    }

    private func clamp(_ angle: Float) -> Float {
        min(max(angle, -Self.maxAngle), Self.maxAngle)
    }
}
