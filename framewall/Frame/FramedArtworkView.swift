import RealityKit
import SwiftUI

/// A painting as a real 3D object that responds to how the device is held.
///
/// **Currently unused — shelved, not abandoned.** Every screen now draws
/// ``StaticFramedArtwork`` instead: the flat front view reads better at feed and
/// carousel scale, and it is transparent, which the 3D stage's painted wall is
/// not. The RealityKit stack here — this view, ``FramedArtworkScene`` and
/// ``FrameTilt`` — is kept intact for the 3D treatment to return in another form
/// (the room view and Hang at Home are the obvious homes for it).
///
/// Respects Reduce Motion by falling back to ``StaticFramedArtwork``.
struct FramedArtworkView: View {
    let artwork: Artwork

    /// Play the settle haptic once the piece has arrived — set by a pager when a
    /// swipe lands, not on first appearance.
    var settlesOnAppear: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    /// Shared, not per-view — a feed of posts all read the same device attitude.
    private var tilt: FrameTilt { .shared }

    @State private var haptics = FrameHaptics()
    @State private var frame: Entity?

    var body: some View {
        Group {
            if reduceMotion {
                // code.md §2: "Respect Reduce Motion: fall back to the static front
                // view." Not a degraded 3D scene — the flat one, which is composed
                // for being looked at rather than moved.
                StaticFramedArtwork(artwork: artwork)
            } else {
                realityScene
            }
        }
        .task(id: artwork.id) {
            guard !reduceMotion else { return }
            haptics.prepare()
            tilt.start()
            if settlesOnAppear {
                haptics.settle()
            }
        }
        .onDisappear {
            guard !reduceMotion else { return }
            tilt.release()
            haptics.stop()
        }
        .onChange(of: scenePhase) { _, phase in
            // Motion updates cost power and are meaningless off-screen.
            switch phase {
            case .active where !reduceMotion:
                tilt.recentre()
                tilt.resumeIfNeeded()
            default:
                tilt.stop()
            }
        }
    }

    private var realityScene: some View {
        RealityView { content in
            content.camera = .virtual
            let root = await FramedArtworkScene.makeRoot(for: artwork)
            content.add(root)
            frame = root.findEntity(named: FramedArtworkScene.frameName)
        } update: { _ in
            // Driving the transform from the observable read here keeps the tilt on
            // SwiftUI's update cycle rather than a second animation loop.
            frame?.transform.rotation = tilt.rotation
        }
        .accessibilityElement()
        .accessibilityLabel("\(artwork.title) by \(artwork.artist). \(artwork.caption).")
    }
}

#Preview {
    FramedArtworkView(artwork: .placeholder())
        .background(.background)
}
