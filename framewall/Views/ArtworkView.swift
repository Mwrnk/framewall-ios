import SwiftUI
import UIKit

/// Artwork viewer — the piece alone, its neighbours peeking in to signal the
/// swipe, then what the work is, and the way through to the room view.
/// (Figma `02 Artwork`, 100:932)
///
/// **Presented as an overlay, not pushed.** A push swaps one screen for another;
/// the system's `.zoom` transition can't help because the painting is the same
/// 272 pt in the feed as it is here, so a zoom has to shrink it to 68% and grow
/// it back. Instead the piece itself travels, on its own layer, out of the tile
/// it was tapped in and into the carousel — the same object moved to a different
/// place, which is the premise of the app taken literally. (code.md §1)
///
/// There is only ever one visible copy of the piece. The host keeps its tile in
/// place but transparent while the viewer is open, and the viewer's travelling
/// copy borrows that tile's frame (`isSource: false`) to start from and return
/// to. Nothing is inserted or removed mid-flight, so nothing cross-fades.
struct ArtworkView: View {
    /// The collection the viewer swipes, in order: a profile passes that artist's
    /// body of work, the feed passes the feed.
    let works: [Artwork]

    /// The piece on screen, owned by the presenting screen so it can keep the
    /// matching tile out of the way. Swiping here changes which tile the piece
    /// flies back to on close. `nil` is closed.
    @Binding var selection: Artwork.ID?

    /// Shared with the presenting screen's tiles. The piece in flight is
    /// whichever one is selected.
    let hero: Namespace.ID

    let close: () -> Void

    /// True once the piece has left its tile for the carousel. Drives the flight
    /// and the wall behind it.
    @State private var isOut = false
    /// True once the flight has fully settled. The travelling copy then hands
    /// over to the carousel — instantly, because the two sit on the same pixels
    /// — and the chrome arrives around it.
    @State private var hasLanded = false
    @State private var haptics = FrameHaptics()
    /// Where the finger has carried the piece during a pull-to-close. Zero
    /// outside one.
    @State private var drag: CGSize = .zero
    /// True once a drag has committed to closing rather than to the pager.
    @State private var isPulling = false
    /// Whether the description is scrolled to its top. Only then does a pull
    /// on the piece close the viewer; otherwise it scrolls back up.
    @State private var isAtTop = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Opaque, and faded in on its own schedule: the wall arrives while
            // the piece is still in the air, so the feed dissolves behind it
            // rather than being slapped over.
            Color(.systemBackground)
                .ignoresSafeArea()
                .opacity(backdropOpacity)

            VStack(spacing: 0) {
                toolbar
                content
            }
            .safeAreaInset(edge: .bottom) { viewOnWall }

            // Last in the stack, so the piece flies above the wall and the
            // chrome rather than under them, and outside the scroll views so
            // neither clips it on the way.
            travellingPiece
        }
        // Reduce Motion keeps the piece still and fades the viewer instead.
        .opacity(reduceMotion && !isOut ? 0 : 1)
        .onAppear(perform: arrive)
        .onDisappear { haptics.stop() }
        .onChange(of: selection) { _, _ in
            // The pager owns the settle rather than the frame: a peeking
            // neighbour is built long before it becomes the hero, so nothing
            // tied to the piece appearing would fire when the swipe lands.
            haptics.settle()
        }
    }

    private var current: Artwork? {
        works.first { $0.id == selection } ?? works.first
    }

    private var index: Int {
        works.firstIndex { $0.id == selection } ?? 0
    }

    private func show(_ target: Int) {
        guard works.indices.contains(target) else { return }
        withAnimation(.artworkSettle) { selection = works[target].id }
    }

    /// The wall arrives with the piece, and pulling down thins it so the feed
    /// reads through — the further you have pulled, the more you have left.
    private var backdropOpacity: Double {
        guard isOut else { return 0 }
        return 1 - pullProgress
    }

    /// 0 at rest, 1 once the piece has been pulled a full `dismissFade` down.
    /// Pulling up counts for nothing.
    private var pullProgress: Double {
        min(max(Double(drag.height / Metrics.dismissFade), 0), 1)
    }

    /// The piece shrinks as it is pulled, like a photo being put back — it is
    /// already on its way to the smaller tile it came from.
    private var pullScale: CGFloat {
        1 - (1 - Metrics.pulledScale) * pullProgress
    }

    // MARK: - Flight

    private func arrive() {
        haptics.prepare()
        // `.removed`, not the default `.logicallyComplete`: the hand-over to the
        // carousel is a hard swap, so it has to wait out the spring's tail or
        // the two copies would briefly sit a pixel apart.
        withAnimation(reduceMotion ? .artworkSettle : .artworkTravel, completionCriteria: .removed) {
            isOut = true
        } completion: {
            hasLanded = true
        }
    }

    // MARK: - Chrome

    /// Figma `Toolbar` (102:1415): a circular glass back button, the artist's
    /// name centred. Hand-drawn because an overlay has no navigation bar to
    /// configure — the glass itself still comes from the system button style.
    private var toolbar: some View {
        ZStack {
            Text(current?.artist ?? "")
                .font(.body)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Back")

                Spacer()
            }
        }
        .padding(.horizontal, Metrics.toolbarInset)
        .frame(height: Metrics.toolbar)
        .opacity(hasLanded ? 1 : 0)
        .animation(.artworkSettle, value: hasLanded)
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 0) {
                carousel

                pageControl
                    .padding(.top, Metrics.carouselToDots)
                    .opacity(hasLanded ? 1 : 0)
                    .animation(.artworkSettle, value: hasLanded)

                if let current {
                    info(for: current)
                        .padding(.top, Metrics.dotsToInfo)
                        .opacity(hasLanded ? 1 : 0)
                        // Reduce Motion keeps the fade and drops the travel — a
                        // cross-fade is the standard substitute for a slide.
                        .offset(y: hasLanded || reduceMotion ? 0 : Metrics.infoRise)
                        .animation(.artworkSettle.delay(Metrics.infoStagger), value: hasLanded)
                }
            }
        }
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top <= 1
        } action: { _, atTop in
            isAtTop = atTop
        }
    }

    // MARK: - Carousel

    /// Figma `Carousel` (102:1459): the hero centred on a 360 pt stage, with a
    /// neighbour 262 pt either side at 45% peeking in to signal the swipe.
    ///
    /// The stages deliberately overlap — 262 pt of pitch carrying a 360 pt stage
    /// — which is exactly what the design draws. It works because
    /// ``StaticFramedArtwork`` is transparent outside the frame and its wall
    /// shadow, so a neighbour passes behind the hero rather than blanking it.
    private var carousel: some View {
        GeometryReader { proxy in
            // Narrower phones shrink the whole carousel rather than clipping it,
            // so the peek keeps its proportion instead of eating the hero.
            let scale = min(proxy.size.width / Metrics.designWidth, 1)
            let stage = Metrics.stage * scale
            let pitch = Metrics.pitch * scale

            ZStack {
                // No animation on this swap, ever: the pager takes over from
                // the travelling copy on exactly the same pixels.
                pager(stage: stage, pitch: pitch, size: proxy.size)
                    .opacity(hasLanded ? 1 : 0)

                // Where the piece lands: the hero cell's exact frame, marked
                // for the travelling copy to fly to. Kept off the pager itself,
                // where it would fight the neighbours' own placement.
                Color.clear
                    .frame(width: stage, height: stage)
                    .matchedGeometryEffect(id: ArtworkHero.slot, in: hero)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: Metrics.carousel)
        .gesture(
            PullGesture(
                isEnabled: hasLanded && isAtTop,
                onChange: pullChanged,
                onEnd: pullEnded
            )
        )
    }

    /// The one piece that moves. It never lays itself out: it borrows the frame
    /// of the tile it came from, or of the carousel slot, and switching which
    /// one it borrows is the flight.
    @ViewBuilder
    private var travellingPiece: some View {
        if let current {
            StaticFramedArtwork(artwork: current)
                // Inside the matched effect, so the piece shrinks about its own
                // centre wherever the flight has put it. The flight home animates
                // both back to rest in step with the frame, which is what lets
                // it leave from under the finger rather than from the carousel.
                .scaleEffect(pullScale)
                .offset(drag)
                .matchedGeometryEffect(
                    id: isOut || reduceMotion ? ArtworkHero.slot : .tile(current.id),
                    in: hero,
                    isSource: false
                )
                // Only a fallback size, for a tile the feed has scrolled out of
                // existence; normally the matched frame overrides it.
                .frame(width: Metrics.stage, height: Metrics.stage)
                .opacity(hasLanded ? 0 : 1)
                .allowsHitTesting(false)
        }
    }

    private func pager(stage: CGFloat, pitch: CGFloat, size: CGSize) -> some View {
        // Read out here: `scrollTransition`'s closure is `Sendable`, so it
        // cannot reach a main-actor-isolated constant.
        let dimmed = Metrics.neighbourOpacity

        return ScrollViewReader { scrollProxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(works) { artwork in
                        StaticFramedArtwork(artwork: artwork)
                            .frame(width: stage, height: stage)
                            // The stage is wider than the pitch, so every cell spills
                            // over the two beside it. That overlap is the design.
                            .frame(width: pitch, height: size.height)
                            // Thresholded on centre, not on visibility: a peeking
                            // work is still part on screen, so the default would
                            // leave it barely dimmed instead of the design's 45%.
                            .scrollTransition(
                                .interactive.threshold(.centered),
                                axis: .horizontal
                            ) { view, phase in
                                view.opacity(phase.isIdentity ? 1 : dimmed)
                            }
                            .zIndex(artwork.id == selection ? 1 : 0)
                    }
                }
                .scrollTargetLayout()
            }
            // Half a pitch of margin either side is what lets the first and last
            // works reach the centre.
            .contentMargins(.horizontal, max(pitchMargin(pitch, in: size.width), 0), for: .scrollContent)
            .scrollTargetBehavior(.viewAligned(anchor: .center))
            .scrollPosition(id: $selection, anchor: .center)
            .scrollIndicators(.hidden)
            // Once a pull has started, the pager must not also scroll sideways
            // under it and change which piece is being put back.
            .scrollDisabled(isPulling)
            .onAppear {
                // `scrollPosition(id:anchor:)` seeds its *initial* jump without
                // accounting for the content margins above, landing the hero a
                // full margin off-centre — a real `scrollTo` goes through the
                // same path a swipe's snap does, which does account for them.
                if let selection {
                    scrollProxy.scrollTo(selection, anchor: .center)
                }
            }
        }
    }

    /// `containerWidth` is the actual carousel width, not the design's — on a
    /// screen wider than 402 pt (an iPad, say) the scale above tops out at 1 and
    /// the margin has to centre against the real container or the carousel
    /// drifts off to one side.
    private func pitchMargin(_ pitch: CGFloat, in containerWidth: CGFloat) -> CGFloat {
        (containerWidth - pitch) / 2
    }

    // MARK: - Dismissal

    /// Pull the piece down to put it back. Bound to the carousel rather than the
    /// whole viewer so it cannot fight the vertical scroll the description needs
    /// at large Dynamic Type sizes.
    ///
    /// Only the piece moves: it leaves the carousel for the travelling layer and
    /// follows the finger freely, sideways too, while the wall and chrome fade.
    /// Let go and it either flies home from right there or springs back.
    private func pullChanged(_ translation: CGSize) {
        if !isPulling {
            isPulling = true
            // Same pixels, so the hand-over is instant.
            hasLanded = false
        }
        drag = translation
    }

    private func pullEnded(_ translation: CGSize, velocity: CGSize) {
        guard isPulling else { return }
        if translation.height > Metrics.dismissThreshold || velocity.height > Metrics.dismissVelocity {
            dismiss()
        } else {
            withAnimation(.artworkTravel, completionCriteria: .removed) {
                drag = .zero
            } completion: {
                isPulling = false
                hasLanded = true
            }
        }
    }

    /// Hands the piece back to the travelling copy — instantly, on the same
    /// pixels as the carousel's — then flies it home. The host only closes once
    /// it has landed on its tile, so the swap back is invisible too.
    private func dismiss() {
        hasLanded = false
        withAnimation(reduceMotion ? .artworkSettle : .artworkTravel, completionCriteria: .removed) {
            isOut = false
            drag = .zero
        } completion: {
            close()
        }
    }

    // MARK: - Page control

    /// Figma `Page Control` (102:1481): an 80 × 24 glass capsule of 8 pt dots on
    /// 16 pt centres.
    ///
    /// Drawn by hand because SwiftUI only exposes a page control through
    /// `TabView`'s page style, and that style cannot show the neighbouring works.
    /// The appearance is `UIPageControl`'s own: one colour, inactive dots faded.
    private var pageControl: some View {
        HStack(spacing: Metrics.dotSpacing) {
            ForEach(works) { artwork in
                Circle()
                    .fill(.primary)
                    .opacity(artwork.id == selection ? 1 : Metrics.inactiveDot)
                    .frame(width: Metrics.dot, height: Metrics.dot)
            }
        }
        .padding(.horizontal, Metrics.dotsInsetH)
        .padding(.vertical, Metrics.dotsInsetV)
        .glassEffect()
        .animation(.default, value: selection)
        .frame(height: Metrics.pageControl)
        .accessibilityElement()
        .accessibilityLabel("Work")
        .accessibilityValue("\(index + 1) of \(works.count)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: show(index + 1)
            case .decrement: show(index - 1)
            @unknown default: break
            }
        }
    }

    // MARK: - Info

    /// Figma `Info` (102:1511): 12 above, 20 either side, 6 between the lines.
    private func info(for artwork: Artwork) -> some View {
        VStack(alignment: .leading, spacing: Metrics.infoSpacing) {
            Text(artwork.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            Text(artwork.viewerCaption)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let note = artwork.note {
                Text(note)
                    .font(.body)
                    .foregroundStyle(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Metrics.infoTop)
        .padding(.horizontal, Metrics.infoInset)
    }

    // MARK: - View on wall

    /// Figma `View on wall` (120:465): a Liquid Glass text button, centred well
    /// clear of the home indicator. The system draws the glass.
    private var viewOnWall: some View {
        Button {
            // TODO: open the room view (Figma `06 Wall`, 115:358) — build step 3.
        } label: {
            Text("View on wall")
                .fontWeight(.semibold)
        }
        .buttonStyle(.glass)
        .padding(.top, Metrics.buttonTop)
        .padding(.bottom, Metrics.buttonBottom)
        .opacity(hasLanded ? 1 : 0)
        .animation(.artworkSettle, value: hasLanded)
    }

    private enum Metrics {
        /// The design is drawn for the 402 pt iPhone 17 Pro.
        static let designWidth: CGFloat = 402

        static let toolbar: CGFloat = 54
        static let toolbarInset: CGFloat = 16

        static let stage: CGFloat = 360
        /// Figma sets the neighbours ±262 from the frame's origin; the hero's own
        /// +21 is only what centres a 360 pt stage in 402, so 262 is the pitch.
        static let pitch: CGFloat = 262
        static let carousel: CGFloat = 420
        /// Figma `Previous work` / `Next work`: 45%.
        static let neighbourOpacity: Double = 0.45

        static let carouselToDots: CGFloat = 4
        static let dotsToInfo: CGFloat = 6

        static let pageControl: CGFloat = 44
        static let dot: CGFloat = 8
        static let dotSpacing: CGFloat = 8
        static let dotsInsetH: CGFloat = 12
        static let dotsInsetV: CGFloat = 8
        /// `UIPageControl` fades its inactive dots rather than recolouring them.
        static let inactiveDot: Double = 0.25

        static let infoSpacing: CGFloat = 6
        static let infoTop: CGFloat = 12
        static let infoInset: CGFloat = 20

        /// How far the description travels up as it arrives. Small on purpose —
        /// enough to read as movement, not as a separate screen sliding in.
        static let infoRise: CGFloat = 16
        /// The words trail the rest of the chrome by a beat.
        static let infoStagger: Double = 0.08

        static let buttonTop: CGFloat = 16
        /// The design leaves 48 between the button and the home indicator.
        static let buttonBottom: CGFloat = 48

        static let dismissThreshold: CGFloat = 120
        /// Points per second downward at release that count as a flick.
        static let dismissVelocity: CGFloat = 800
        /// Distance over which the wall thins out completely while dragging.
        static let dismissFade: CGFloat = 400
        /// How small the piece gets at a full pull — roughly a profile tile's
        /// share of the carousel stage, so it is visibly on its way back.
        static let pulledScale: CGFloat = 0.6
    }
}

/// A pan that claims a downward drag before the scroll views around it can.
///
/// `DragGesture` can't do this: the carousel sits inside a vertical scroll view,
/// and a downward drag is exactly what that scroll view bounces on, so it won
/// the touch more often than not. Here every enclosing scroll view's pan is made
/// to wait for this one, and this one only begins for a mostly-downward drag —
/// anything sideways fails it at once and the pager swipes as normal. The same
/// arrangement Photos uses to put a photo back.
private struct PullGesture: UIGestureRecognizerRepresentable {
    var isEnabled: Bool
    var onChange: (CGSize) -> Void
    var onEnd: (_ translation: CGSize, _ velocity: CGSize) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        return pan
    }

    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        context.coordinator.isEnabled = isEnabled
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let t = recognizer.translation(in: recognizer.view)
        let translation = CGSize(width: t.x, height: t.y)
        switch recognizer.state {
        case .began, .changed:
            onChange(translation)
        case .ended, .cancelled:
            let v = recognizer.velocity(in: recognizer.view)
            onEnd(translation, CGSize(width: v.x, height: v.y))
        default:
            break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var isEnabled = true

        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard isEnabled, let pan = recognizer as? UIPanGestureRecognizer else { return false }
            let v = pan.velocity(in: pan.view)
            return v.y > 0 && v.y > abs(v.x)
        }

        func gestureRecognizer(
            _ recognizer: UIGestureRecognizer,
            shouldBeRequiredToFailBy other: UIGestureRecognizer
        ) -> Bool {
            other.view is UIScrollView
        }
    }
}

/// The places a piece can be in the shared namespace: its tile on the screen
/// that opened the viewer, or the viewer's carousel slot.
enum ArtworkHero: Hashable {
    case tile(Artwork.ID)
    case slot
}

extension Animation {
    /// The piece moving between places. Weighted rather than snappy — a hung
    /// object being carried, with just enough bounce to land rather than stop.
    static let artworkTravel = Animation.spring(duration: 0.42, bounce: 0.14)

    /// Everything that arrives around the piece once it has landed.
    static let artworkSettle = Animation.smooth(duration: 0.34)
}

#Preview {
    ArtworkViewerPreview()
}

/// The viewer is opened by its host, so the preview supplies one — a tile to fly
/// out of, and the state the real screens own.
private struct ArtworkViewerPreview: View {
    @Namespace private var hero
    @State private var selection: Artwork.ID? = Profile.sample.works.first?.id

    var body: some View {
        ZStack {
            if selection != nil {
                ArtworkView(
                    works: Profile.sample.works,
                    selection: $selection,
                    hero: hero,
                    close: { selection = nil }
                )
            }
        }
    }
}
