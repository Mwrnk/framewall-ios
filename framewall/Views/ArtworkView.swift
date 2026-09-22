import SwiftUI

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

    /// False while the piece is still travelling: the carousel and the words
    /// wait for it to land rather than arriving on top of it.
    @State private var hasLanded = false
    @State private var haptics = FrameHaptics()
    @State private var dragOffset: CGFloat = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Opaque, and faded in on its own schedule: the wall arrives while
            // the piece is still in the air, so the feed dissolves behind it
            // rather than being slapped over.
            Color(.systemBackground)
                .ignoresSafeArea()
                .opacity(backdropOpacity)
                .transition(.opacity)

            VStack(spacing: 0) {
                toolbar
                content
            }
            .safeAreaInset(edge: .bottom) { viewOnWall }
        }
        // The drag carries the whole viewer, so the piece stays put relative to
        // its chrome and the gesture reads as peeling the screen away.
        .offset(y: dragOffset)
        .task {
            haptics.prepare()
            try? await Task.sleep(for: .seconds(Metrics.landingDelay))
            withAnimation(.artworkSettle) { hasLanded = true }
        }
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

    /// Pulling down thins the wall so the feed reads through it — the further
    /// you have pulled, the more you have already left.
    private var backdropOpacity: Double {
        max(0, 1 - Double(dragOffset / Metrics.dismissFade))
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
        .transition(.opacity)
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 0) {
                carousel

                pageControl
                    .padding(.top, Metrics.carouselToDots)
                    .opacity(hasLanded ? 1 : 0)

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
                pager(stage: stage, pitch: pitch, size: proxy.size)
                    .opacity(hasLanded ? 1 : 0)

                // The piece in flight, on its own layer. Keeping the matched
                // geometry off the pager matters: inside the scroll view it
                // would fight the neighbours' own placement, and every cell that
                // wasn't the hero would need an inert copy of the effect to
                // avoid claiming the same id.
                travellingPiece(stage: stage)
                    .opacity(hasLanded ? 0 : 1)
            }
        }
        .frame(height: Metrics.carousel)
        .gesture(dismissDrag)
    }

    @ViewBuilder
    private func travellingPiece(stage: CGFloat) -> some View {
        if let current {
            StaticFramedArtwork(artwork: current)
                .frame(width: stage, height: stage)
                .matchedGeometryEffect(id: current.id, in: hero)
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
    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: Metrics.dismissMinimum)
            .onChanged { value in
                // Downward only — pulling up shouldn't peel the screen off.
                dragOffset = max(0, value.translation.height)
            }
            .onEnded { value in
                let thrown = value.predictedEndTranslation.height > Metrics.dismissThrow
                if value.translation.height > Metrics.dismissThreshold || thrown {
                    dismiss()
                } else {
                    withAnimation(.artworkSettle) { dragOffset = 0 }
                }
            }
    }

    /// Hands the piece back to the travelling layer before closing, so what flies
    /// home is the frame the eye has been following rather than an invisible
    /// stand-in behind the carousel.
    private func dismiss() {
        hasLanded = false
        withAnimation(.artworkTravel) { close() }
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
        .transition(.opacity)
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
        /// Roughly the length of the travel, so the two don't overlap.
        static let landingDelay: Double = 0.34

        static let buttonTop: CGFloat = 16
        /// The design leaves 48 between the button and the home indicator.
        static let buttonBottom: CGFloat = 48

        static let dismissMinimum: CGFloat = 12
        static let dismissThreshold: CGFloat = 120
        static let dismissThrow: CGFloat = 320
        /// Distance over which the wall thins out completely while dragging.
        static let dismissFade: CGFloat = 400
    }
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
