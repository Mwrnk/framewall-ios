import CoreGraphics
import simd

/// Every dimension of a framed piece, derived from the artwork's true physical size.
///
/// code.md §2 measures the frame against a 360 x 360 pt container: a 272 pt frame
/// holding a 240 pt artwork, so 16 pt of visible moulding — **5.9% of the frame's
/// outer width**. That ratio is the thing to preserve, not the pt values, so
/// everything here is computed from it.
///
/// Units are metres, because that is what RealityKit works in. Artwork sizes come
/// in as centimetres, which is how a painter declares them.
struct FrameGeometry: Equatable, Sendable {

    /// Visible moulding as a fraction of the frame's outer width: 16 / 272.
    static let borderRatio: Float = 16.0 / 272.0

    /// The rebate lip is 244 pt against a 240 pt artwork — a 2 pt sliver of dark on
    /// each side, which is 1/8 of the 16 pt moulding.
    static let rebateRatio: Float = 2.0 / 16.0

    /// Width and height of the painting itself.
    let artwork: SIMD2<Float>
    /// Width and height of the frame's outer edge.
    let outer: SIMD2<Float>
    /// Width of the visible moulding on one side.
    let border: Float
    /// Front-to-back thickness of the moulding.
    let depth: Float
    /// The dark plate behind the canvas, whose edge shows as the rebate lip.
    let rebate: SIMD2<Float>

    /// - Parameter artworkSize: the painting's true size in **centimetres**.
    init(artworkSize: CGSize) {
        let width = Float(artworkSize.width) / 100
        let height = Float(artworkSize.height) / 100
        artwork = [width, height]

        // outer = artwork + 2·border, where border = outer · borderRatio.
        // Solving for outer gives this scale factor — 1.1333… , so 240 → 272.
        let scale = 1 / (1 - 2 * Self.borderRatio)
        outer = [width * scale, height * scale]
        border = (outer.x - width) / 2

        rebate = [
            width + 2 * border * Self.rebateRatio,
            height + 2 * border * Self.rebateRatio
        ]

        // The design is a front elevation, so it has nothing to say about depth.
        // Twice the moulding width matches the proportions of a real gallery frame
        // and gives the perspective view a thickness face worth seeing.
        depth = border * 2
    }

    // MARK: - Layer positions along z

    /// z = 0 is the back of the frame; z = ``depth`` is the front face.

    /// The moulding bars are centred through the full depth.
    var mouldingZ: Float { depth / 2 }

    /// The canvas sits recessed, so the moulding can cast onto it. code.md §2 calls
    /// for an inner shadow here; in 3D the recess produces it.
    var canvasZ: Float { depth * 0.30 }

    /// The dark rebate plate sits immediately behind the canvas.
    var rebateZ: Float { canvasZ - 0.0015 }

    /// Glass sits just inside the front face.
    var glassZ: Float { depth * 0.92 }

    /// Thin slabs still want real thickness, or they z-fight with their neighbours.
    var slabDepth: Float { 0.002 }

    /// How far back to pull the camera so the frame fills a comfortable amount of
    /// the viewport, whatever size the piece is.
    var cameraDistance: Float { max(outer.x, outer.y) * 2.1 }
}
