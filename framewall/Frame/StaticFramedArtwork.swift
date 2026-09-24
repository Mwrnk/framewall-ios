import SwiftUI

/// The straight-on framed painting, drawn in 2D. (code.md §2, "Front view")
///
/// This is not only the Reduce Motion fallback. It is also what the profile grid,
/// the widget and StandBy need, since none of them can run RealityKit.
///
/// It draws all seven finishes (Framewall Design System, `FramedArtwork`) and, when
/// asked, the work's sticker in its slot on the wall.
struct StaticFramedArtwork: View {
    let artwork: Artwork
    /// The sticker slot sits in the stage's margin, so it only makes sense where
    /// the frame has its full stage. The profile grid turns it off.
    var showsSticker = true

    /// The design measures a 272 pt frame inside a 360 pt container, leaving room
    /// for the wall shadow to fall outside the frame.
    private static let frameToContainer: CGFloat = 272.0 / 360.0

    var body: some View {
        GeometryReader { proxy in
            let container = min(proxy.size.width, proxy.size.height)
            let outer = outerSize(fitting: container * Self.frameToContainer)

            FrameBody(finish: artwork.finish, image: artwork.image, outer: outer)
                .frame(width: outer.width, height: outer.height)
                .modifier(WallShadow(scale: container / 360))
                .frame(width: proxy.size.width, height: proxy.size.height)
                .overlay(alignment: .bottomTrailing) {
                    if showsSticker, let sticker = artwork.sticker {
                        // Stickers are drawn at their size in a 360 pt stage, so they
                        // scale with the stage like everything else here.
                        let scale = container / 360
                        StickerView(sticker: sticker, number: artwork.number, facts: tagFacts)
                            .scaleEffect(scale, anchor: .bottomTrailing)
                            .padding(6 * scale)
                    }
                }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(accessibilityDescription)
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

    /// "Acrylic · 60 × 60 cm": the inventory tag has room for one word of medium.
    private var tagFacts: String {
        [artwork.medium?.split(separator: " ").first.map(String.init), artwork.dimensions]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private var accessibilityDescription: String {
        var description = "\(artwork.title) by \(artwork.artist). \(artwork.caption). "
            + "\(artwork.finish.displayName) frame."
        if showsSticker, let sticker = artwork.sticker {
            description += " Sticker: \(sticker.style == .tag ? "inventory tag" : sticker.word)."
        }
        return description
    }
}

// MARK: - The frame itself

/// Moulding, ornament, rebate or mat, canvas, the moulding's cast and the glass.
private struct FrameBody: View {
    let finish: FrameFinish
    let image: CGImage?
    let outer: CGSize

    /// The oak and black border at this size. Wider finishes keep this lip rather
    /// than growing it with their border, or a gilded frame's rebate reads as a
    /// second black frame.
    private var standardBorder: CGFloat { outer.width * 16 / 272 }
    private var border: CGFloat { outer.width * finish.borderRatio }
    private var lip: CGFloat { min(border, standardBorder) * CGFloat(FrameGeometry.rebateRatio) }
    private var mat: CGFloat { outer.width * finish.matRatio }

    private var shape: AnyShape {
        finish.isOval ? AnyShape(Ellipse()) : AnyShape(Rectangle())
    }

    /// The opening inside the moulding.
    private var opening: CGSize {
        CGSize(width: outer.width - 2 * border, height: outer.height - 2 * border)
    }

    private var canvas: CGSize {
        CGSize(width: opening.width - 2 * mat, height: opening.height - 2 * mat)
    }

    var body: some View {
        ZStack {
            shape.fill(
                LinearGradient(stops: finish.gradientStops, startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            MouldingDetail(finish: finish, outer: outer, border: border)
            if mat > 0 {
                matAndCanvas
            } else {
                rebateAndCanvas
            }
        }
        .clipShape(shape)
    }

    /// The dark lip where the moulding steps down to the canvas, or on the oval
    /// a thin gilt one.
    private var rebateAndCanvas: some View {
        let goldLip = outer.width * 0.018
        let ring = finish.isOval ? goldLip : lip
        return shape
            .fill(finish.isOval ? AnyShapeStyle(LinearGradient(
                colors: [Color(hex: 0xF4DC93), Color(hex: 0x8C6A24)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )) : AnyShapeStyle(.black.opacity(0.42)))
            .frame(width: opening.width + 2 * ring, height: opening.height + 2 * ring)
            .overlay {
                CanvasLayer(image: image, shape: shape, scale: opening.width / 240)
                    .frame(
                        width: opening.width - (finish.isOval ? 2 * ring : 0),
                        height: opening.height - (finish.isOval ? 2 * ring : 0)
                    )
            }
    }

    /// Limed oak: the moulding casts onto a wide off-white mat, and the canvas sits
    /// in a bevel-cut window whose cut edge catches the light.
    private var matAndCanvas: some View {
        Rectangle()
            .fill(Palette.mat.shadow(.inner(color: .black.opacity(0.18), radius: 2.5, x: 2, y: 3)))
            .frame(width: opening.width, height: opening.height)
            .overlay {
                CanvasLayer(image: image, shape: AnyShape(Rectangle()), scale: canvas.width / 240, castStrength: 0.25)
                    .frame(width: canvas.width, height: canvas.height)
                    .padding(2)
                    .background(Palette.paper)
                    .shadow(color: .black.opacity(0.08), radius: 0.5)
            }
    }
}

/// Carving, fluting and lacquer drawn over the moulding's gradient.
private struct MouldingDetail: View {
    let finish: FrameFinish
    let outer: CGSize
    let border: CGFloat

    var body: some View {
        switch finish {
        case .gilded:
            ZStack {
                // The fluted band: a dashed stroke as wide as the band draws each
                // flute square to the moulding, the way a carver cuts them.
                Rectangle()
                    .inset(by: border * 0.3)
                    .strokeBorder(
                        Color(hex: 0x8C6A24),
                        style: StrokeStyle(lineWidth: border * 0.34, dash: [flute, flute * 1.3])
                    )
                    .opacity(0.8)
                Rectangle()
                    .inset(by: border * 0.12)
                    .strokeBorder(.white.opacity(0.45), lineWidth: hairline)
                Rectangle()
                    .strokeBorder(.white.opacity(0.5), lineWidth: hairline)
            }
        case .walnut:
            ZStack {
                // A row of gilt beads, set halfway across the moulding.
                Rectangle()
                    .inset(by: border * 0.5)
                    .strokeBorder(
                        Color(hex: 0xCFA64E),
                        style: StrokeStyle(lineWidth: bead, lineCap: .round, dash: [0, bead * 2.5])
                    )
                Rectangle()
                    .inset(by: border * 0.22)
                    .strokeBorder(.white.opacity(0.12), lineWidth: hairline)
                Rectangle()
                    .strokeBorder(.white.opacity(0.14), lineWidth: hairline * 2)
            }
        case .oval:
            Ellipse()
                .strokeBorder(.white.opacity(0.18), lineWidth: hairline * 2)
        case .painted:
            // Lacquer: a bright sheen from the upper left, falling off to the lower right.
            LinearGradient(
                stops: [
                    .init(color: .white.opacity(0.32), location: 0),
                    .init(color: .white.opacity(0), location: 0.4),
                    .init(color: .black.opacity(0), location: 0.6),
                    .init(color: .black.opacity(0.22), location: 1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay { Rectangle().strokeBorder(.white.opacity(0.45), lineWidth: hairline) }
        case .oak, .black, .limedOak:
            EmptyView()
        }
    }

    /// Detail sizes follow the frame, so a thumbnail's carving is a thumbnail's.
    private var hairline: CGFloat { max(0.5, outer.width / 272) }
    private var flute: CGFloat { max(0.8, outer.width * 0.006) }
    private var bead: CGFloat { max(1, outer.width * 0.008) }
}

/// The painting, the moulding's cast onto it, and the glass over it.
private struct CanvasLayer: View {
    let image: CGImage?
    let shape: AnyShape
    /// The design's shadow values are quoted against a 240 pt canvas, so they have
    /// to be scaled or a thumbnail wears a full-size inner shadow.
    let scale: CGFloat
    var castStrength: Double = 0.38

    var body: some View {
        artwork
            .clipShape(shape)
            .overlay { mouldingCast }
            .overlay { glassHighlight.clipShape(shape) }
    }

    @ViewBuilder
    private var artwork: some View {
        if let image {
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
    private var mouldingCast: some View {
        shape.fill(
            .clear.shadow(
                .inner(
                    color: .black.opacity(castStrength),
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

#Preview("All seven finishes") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170))], spacing: 8) {
            ForEach(
                [FrameFinish.oak, .black, .gilded, .limedOak, .walnut, .oval,
                 .painted(.vermilion), .painted(.cadmium), .painted(.ultramarine), .painted(.viridian)],
                id: \.self
            ) { finish in
                StaticFramedArtwork(
                    artwork: .placeholder(
                        size: finish.isOval ? CGSize(width: 48, height: 60) : CGSize(width: 60, height: 60),
                        finish: finish
                    )
                )
            }
        }
        .padding(16)
    }
    .background(.background)
}

#Preview("With a sticker") {
    StaticFramedArtwork(artwork: .theOtherSideOffAFlower)
        .padding(20)
        .background(.background)
}
