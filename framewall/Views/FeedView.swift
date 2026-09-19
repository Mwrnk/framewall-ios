import SwiftUI

/// Feed screen — chronological posts, each a framed piece on a white stage.
/// (Figma `01 Feed`, 100:917)
///
/// No algorithm, no ads, no like counts. code.md §4.
struct FeedView: View {
    var artworks: [Artwork] = .init(Artwork.sampleFeed)

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Metrics.postSpacing) {
                    ForEach(artworks) { artwork in
                        FeedPost(artwork: artwork)
                    }
                }
                .padding(.horizontal, Metrics.screenInset)
                .padding(.top, Metrics.contentTop)
                .padding(.bottom, Metrics.contentBottom)
            }
            .navigationTitle(Self.title)
        }
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

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.stageToCaption) {
            stage
            caption
        }
    }

    /// Figma `Stage`: a 360 pt square, centred, full width.
    ///
    /// The design is drawn for the 402 pt iPhone 17 Pro, where 360 fits inside the
    /// 16 pt insets. Capping rather than hardcoding lets narrower phones shrink the
    /// piece instead of clipping it.
    private var stage: some View {
        FramedArtworkView(artwork: artwork)
            .aspectRatio(1, contentMode: .fit)
            // Both bounds, not just the width: inside a ScrollView the height is
            // unbounded, so a width-only cap lets the scene claim whatever it likes.
            .frame(maxWidth: Metrics.stage, maxHeight: Metrics.stage)
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

/// Note: previews don't render RealityKit, so each stage shows a spinner rather
/// than the frame. Layout and typography are verifiable here; the frame itself has
/// to be judged on a device.
#Preview {
    FeedView()
}
