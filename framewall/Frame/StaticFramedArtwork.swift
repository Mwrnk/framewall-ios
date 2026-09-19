import SwiftUI

/// The straight-on framed painting, drawn in 2D. (code.md §2, "Front view")
///
/// This is not only the Reduce Motion fallback. It is also what the profile grid,
/// the widget and StandBy need, since none of them can run RealityKit.
struct StaticFramedArtwork: View {
    let artwork: Artwork

    /// The design measures a 272 pt frame inside a 360 pt container, leaving room
    /// for the wall shadow to fall outside the frame.
    private static let frameToContainer: CGFloat = 272.0 / 360.0

    var body: some View {
        GeometryReader { proxy in
            let container = min(proxy.size.width, proxy.size.height)
            let outer = outerSize(fitting: container * Self.frameToContainer)
            let border = outer.width * CGFloat(FrameGeometry.borderRatio)

            ZStack {
                moulding(size: outer)
                rebateAndCanvas(outer: outer, border: border)
            }
            .frame(width: outer.width, height: outer.height)
            .modifier(WallShadow(scale: container / 360))
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Layers

    private func moulding(size: CGSize) -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    stops: artwork.finish.gradientStops,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size.width, height: size.height)
    }

    private func rebateAndCanvas(outer: CGSize, border: CGFloat) -> some View {
        // The lip is the 2 pt sliver of dark between moulding and canvas.
        let lip = border * CGFloat(FrameGeometry.rebateRatio)
        let canvas = CGSize(
            width: outer.width - 2 * border,
            height: outer.height - 2 * border
        )
        // The design's shadow values are quoted against a 240 pt canvas, so they
        // have to be scaled or a thumbnail wears a full-size inner shadow.
        let designScale = canvas.width / 240

        return Rectangle()
            .fill(.black.opacity(0.42))
            .frame(width: canvas.width + 2 * lip, height: canvas.height + 2 * lip)
            .overlay {
                artworkLayer
                    .frame(width: canvas.width, height: canvas.height)
                    .clipped()
                    .overlay { mouldingCast(scale: designScale) }
                    .overlay { glassHighlight }
                    .frame(width: canvas.width, height: canvas.height)
            }
    }

    @ViewBuilder
    private var artworkLayer: some View {
        if let image = artwork.image {
            Image(decorative: image, scale: 1)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Rectangle().fill(.quaternary)
        }
    }

    /// The moulding casting onto the canvas surface.
    ///
    /// Figma `Artwork` layer: `inset 3px 4px 6px rgba(0,0,0,0.38)`. SwiftUI's
    /// shadow radius is a Gaussian sigma where CSS quotes a diameter, so the 6
    /// becomes 3 — the same halving the wall shadow needs.
    private func mouldingCast(scale: CGFloat) -> some View {
        Rectangle()
            .fill(
                .clear.shadow(
                    .inner(
                        color: .black.opacity(0.38),
                        radius: 3 * scale,
                        x: 3 * scale,
                        y: 4 * scale
                    )
                )
            )
    }

    /// Figma `Glass highlight` layer: a 135° white ramp, 0.18 → 0.04 at 42% → 0.
    private var glassHighlight: some View {
        LinearGradient(
            stops: [
                .init(color: .white.opacity(0.18), location: 0),
                .init(color: .white.opacity(0.04), location: 0.42),
                .init(color: .white.opacity(0), location: 1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Helpers

    /// Fits the frame's outer rectangle into a square of `side`, preserving the
    /// artwork's aspect ratio.
    private func outerSize(fitting side: CGFloat) -> CGSize {
        let aspect = artwork.size.width / max(artwork.size.height, 1)
        return aspect >= 1
            ? CGSize(width: side, height: side / aspect)
            : CGSize(width: side * aspect, height: side)
    }

    private var accessibilityDescription: String {
        "\(artwork.title) by \(artwork.artist). \(artwork.caption)."
    }
}

/// The three stacked black drop shadows that make a frame read as hanging on a wall
/// rather than pasted onto one.
///
/// Values are the Figma `Body` layer's front-view drop shadows verbatim:
/// `0 2 2 / 0.16`, `8 14 13 / 0.20`, `0 36 40 / 0.10`. Note that these are half the
/// blur numbers code.md §2 quotes, because Figma's blur is a diameter and both CSS
/// `drop-shadow` and SwiftUI's `radius` take the sigma.
///
/// The perspective view carries a *different*, heavier stack — `2 3 2 / 0.16`,
/// `14 20 15 / 0.22`, `0 44 45 / 0.10` — which is what a turned frame needs. It
/// lives in the RealityKit scene, so it isn't modelled here.
private struct WallShadow: ViewModifier {
    /// Shadows do not scale with the view, so they have to be scaled by hand or a
    /// thumbnail ends up wearing a full-size shadow.
    let scale: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(color: .black.opacity(0.16), radius: 2 * scale, x: 0, y: 2 * scale)
            .shadow(color: .black.opacity(0.20), radius: 13 * scale, x: 8 * scale, y: 14 * scale)
            .shadow(color: .black.opacity(0.10), radius: 40 * scale, x: 0, y: 36 * scale)
    }
}

#Preview("Oak") {
    StaticFramedArtwork(artwork: .placeholder())
        .padding(40)
        .background(.background)
}

#Preview("Black, landscape") {
    StaticFramedArtwork(
        artwork: .placeholder(size: CGSize(width: 90, height: 60), finish: .black)
    )
    .padding(40)
    .background(.background)
}
