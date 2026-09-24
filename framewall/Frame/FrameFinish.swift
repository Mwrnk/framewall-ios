import SwiftUI

#if canImport(UIKit)
import UIKit
typealias PlatformColor = UIColor
#elseif canImport(AppKit)
import AppKit
typealias PlatformColor = NSColor
#endif

/// The lacquer colours a Painted frame comes in: the four pigments, fixed.
enum FramePaint: String, CaseIterable, Identifiable, Hashable, Sendable {
    case vermilion
    case cadmium
    case ultramarine
    case viridian

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vermilion: "Vermilion"
        case .cadmium: "Cadmium"
        case .ultramarine: "Ultramarine"
        case .viridian: "Viridian"
        }
    }

    /// Design system `paint-*` tokens. Fixed in both themes: a painted frame is an
    /// object, so it doesn't follow the UI's appearance.
    var hex: UInt32 {
        switch self {
        case .vermilion: 0xCC3024
        case .cadmium: 0xF2B633
        case .ultramarine: 0x1F4E9C
        case .viridian: 0x2E7D32
        }
    }

    var color: Color { Color(hex: hex) }
}

/// The moulding finishes a piece can be framed in. (Framewall Design System,
/// `FramedArtwork`; the first two are code.md §2's.)
enum FrameFinish: Hashable, Identifiable, Sendable {
    case oak
    case black
    case gilded
    case limedOak
    case walnut
    case oval
    case painted(FramePaint)

    /// The options the frame picker offers, in order. Painted appears once; its
    /// colour is chosen in a second row.
    static let allCases: [FrameFinish] = [
        .oak, .black, .gilded, .limedOak, .walnut, .oval, .painted(.vermilion)
    ]

    /// Identifies the *style*, so every paint colour is the same picker option.
    var id: String {
        switch self {
        case .oak: "oak"
        case .black: "black"
        case .gilded: "gilded"
        case .limedOak: "limedOak"
        case .walnut: "walnut"
        case .oval: "oval"
        case .painted: "painted"
        }
    }

    var displayName: String {
        switch self {
        case .oak: "Natural oak"
        case .black: "Black"
        case .gilded: "Gilded"
        case .limedOak: "Limed oak"
        case .walnut: "Carved walnut"
        case .oval: "Oval"
        case .painted: "Painted"
        }
    }

    var isPainted: Bool {
        if case .painted = self { true } else { false }
    }

    // MARK: - Proportions

    /// Visible moulding as a share of the frame's outer width.
    ///
    /// Oak and black keep the design's 16 / 272. The others are the design
    /// system's: a wide gilded frame, a thin limed moulding that leaves the room
    /// to its mat, and the carved and painted ones in between.
    var borderRatio: CGFloat {
        switch self {
        case .oak, .black: 16.0 / 272.0
        case .gilded: 0.12
        case .limedOak: 0.035
        case .walnut, .oval: 0.09
        case .painted: 0.07
        }
    }

    /// The passe-partout between moulding and canvas, as a share of the frame's
    /// width. Only the Limed oak frame carries one.
    var matRatio: CGFloat {
        self == .limedOak ? 0.13 : 0
    }

    var isOval: Bool { self == .oval }

    // MARK: - Colour

    /// The moulding gradient, drawn at 135° from the upper left.
    ///
    /// Three stops, not two — the midpoint at 55% is what gives the moulding its
    /// turn from lit face to shadowed face. Oak and black are the Figma component
    /// `Framed Artwork` (101:1762); code.md §2 quotes a simplified two-stop version.
    var gradientStops: [Gradient.Stop] {
        let hexes: (UInt32, UInt32, UInt32) = switch self {
        case .oak: (0xDCC199, 0xC9A97C, 0xAE8B5B)
        case .black: (0x3C3C3F, 0x232326, 0x101012)
        case .gilded: (0xF4DC93, 0xCFA64E, 0x8C6A24)
        case .limedOak: (0xEFE8DC, 0xDDD2BF, 0xC0B39B)
        case .walnut: (0x84583A, 0x5A3822, 0x301D11)
        case .oval: (0x3C3C3F, 0x301D11, 0x101012)
        case .painted(let paint): (paint.hex, paint.hex, paint.hex)
        }
        return [
            .init(color: Color(hex: hexes.0), location: 0),
            .init(color: Color(hex: hexes.1), location: 0.55),
            .init(color: Color(hex: hexes.2), location: 1)
        ]
    }

    /// The flat base colour for the RealityKit moulding.
    ///
    /// The design's gradient is a painted-on fake of a light raking across the
    /// moulding from the upper left. In the 3D scene the key light does that job
    /// for real, so tinting with a gradient texture would double the effect and
    /// read as dirty. This is the gradient's 55% stop; the light supplies the
    /// falloff.
    var sceneTint: PlatformColor {
        let hex: UInt32 = switch self {
        case .oak: 0xC9A97C
        case .black: 0x232326
        case .gilded: 0xCFA64E
        case .limedOak: 0xDDD2BF
        case .walnut: 0x5A3822
        case .oval: 0x301D11
        case .painted(let paint): paint.hex
        }
        return PlatformColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }

    /// Satin, not gloss, for the woods; lacquer and gold leaf are smoother.
    var roughness: Float {
        switch self {
        case .oak: 0.62
        case .black: 0.38
        case .gilded: 0.35
        case .limedOak: 0.7
        case .walnut: 0.5
        case .oval: 0.4
        case .painted: 0.2
        }
    }
}

extension Color {
    /// Builds a colour from a `0xRRGGBB` literal, which is how code.md writes them.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
