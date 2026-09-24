import SwiftUI

/// Feed screen — chronological posts, each a framed piece on a white stage.
/// (Figma `01 Feed`, 100:917)
///
/// No algorithm, no ads, no like counts. code.md §4.
struct FeedView: View {
    var artworks: [Artwork] = .init(Artwork.sampleFeed)

    /// Ties each post's frame to the viewer it opens, so the piece travels out
    /// of the feed rather than a new screen sliding over it.
    @Namespace private var hero
    /// The piece currently open in the viewer; `nil` is the feed itself.
    @State private var opened: Artwork.ID?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Metrics.postSpacing) {
                    ForEach(artworks) { artwork in
                        FeedPost(
                            artwork: artwork,
                            hero: hero,
                            // Under Reduce Motion the viewer fades in over the
                            // piece instead of carrying it, so the tile stays.
                            isAway: opened == artwork.id && !reduceMotion,
                            open: { open(artwork) }
                        )
                    }
                }
                .padding(.horizontal, Metrics.screenInset)
                .padding(.top, Metrics.contentTop)
                .padding(.bottom, Metrics.contentBottom)
            }
            .navigationTitle(Self.title)
        }
        // Outside the stack, so the viewer covers the navigation bar too. The
        // viewer swipes the feed itself — the artist changes as you go, and the
        // title follows the piece.
        .overlay {
            if opened != nil {
                ArtworkView(
                    works: artworks,
                    selection: $opened,
                    hero: hero,
                    close: { opened = nil }
                )
            }
        }
        .toolbarVisibility(opened == nil ? .automatic : .hidden, for: .tabBar)
    }

    /// Not animated: the viewer runs the flight itself, starting from exactly
    /// where this tile is, so opening is an instant hand-over.
    private func open(_ artwork: Artwork) {
        opened = artwork.id
    }

    /// The design's toolbar reads "Salon", the provisional name from code.md §1.
    /// The project has since settled on Framewall — bundle `com.mateuswerneck.framewall`,
    /// display name Framewall — so the shipped title follows the project, not the
    /// stale label in the file.
    private static let title = "Framewall"

    private enum Metrics {
        /// Figma `Content`: 28 between posts, 8 top, 16 either side.
        static let postSpacing: CGFloat = 28
        static let screenInset: CGFloat = 16
        static let contentTop: CGFloat = 8
        /// 140 of bottom padding clears the floating glass tab bar so the last
        /// caption can scroll clear of it.
        static let contentBottom: CGFloat = 140
    }
}

/// One post: the piece on its stage, then title and byline.
/// (Figma `Post`, 101:1856)
private struct FeedPost: View {
    let artwork: Artwork
    /// The namespace the piece travels through on its way to the viewer.
    let hero: Namespace.ID
    /// True while this piece is the one open in the viewer.
    let isAway: Bool
    let open: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.stageToCaption) {
            Button { open() } label: { stage }
                .buttonStyle(.plain)
                .accessibilityLabel("\(artwork.title) by \(artwork.artist)")
            caption
        }
    }

    /// Figma `Stage`: a 360 pt square, centred, full width.
    ///
    /// The design is drawn for the 402 pt iPhone 17 Pro, where 360 fits inside the
    /// 16 pt insets. Capping rather than hardcoding lets narrower phones shrink the
    /// piece instead of clipping it.
    ///
    /// While the piece is away in the viewer its tile stays put, transparent,
    /// as the frame the travelling copy leaves from and lands back on. Removing
    /// it instead would make SwiftUI cross-fade two copies mid-flight.
    private var stage: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: Metrics.stage, maxHeight: Metrics.stage)
            .overlay {
                StaticFramedArtwork(artwork: artwork)
                    .matchedGeometryEffect(id: ArtworkHero.tile(artwork.id), in: hero)
                    .opacity(isAway ? 0 : 1)
            }
            .frame(maxWidth: .infinity)
    }

    /// Figma `Caption`: 8 pt of its own horizontal inset, 2 pt between the lines.
    private var caption: some View {
        VStack(alignment: .leading, spacing: Metrics.captionSpacing) {
            Text(artwork.title)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            Text(artwork.byline)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Metrics.captionInset)
    }

    private enum Metrics {
        static let stage: CGFloat = 360
        static let stageToCaption: CGFloat = 10
        static let captionSpacing: CGFloat = 2
        static let captionInset: CGFloat = 8
    }
}

#Preview {
    FeedView()
}
