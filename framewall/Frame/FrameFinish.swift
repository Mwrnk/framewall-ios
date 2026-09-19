import SwiftUI

#if canImport(UIKit)
import UIKit
typealias PlatformColor = UIColor
#elseif canImport(AppKit)
import AppKit
typealias PlatformColor = NSColor
#endif

/// The moulding finishes a piece can be framed in. (code.md §2, "Frame finishes")
enum FrameFinish: String, CaseIterable, Identifiable, Sendable {
    case oak
    case black

    var id: String { rawValue }

    /// Neutral, user-facing name.
    var displayName: String {
        switch self {
        case .oak: "Natural oak"
        case .black: "Black"
        }
    }

    /// The moulding gradient, taken from the Figma component `Framed Artwork`
    /// (101:1762), Front face layer.
    ///
    /// Three stops at 135°, not two — the midpoint at 55% is what gives the
    /// moulding its turn from lit face to shadowed face. code.md §2 quotes a
    /// simplified two-stop version with different endpoints; these are the values
    /// actually in the file.
    var gradientStops: [Gradient.Stop] {
        switch self {
        case .oak:
            [
                .init(color: Color(hex: 0xDCC199), location: 0),
                .init(color: Color(hex: 0xC9A97C), location: 0.55),
                .init(color: Color(hex: 0xAE8B5B), location: 1)
            ]
        case .black:
            [
                .init(color: Color(hex: 0x3C3C3F), location: 0),
                .init(color: Color(hex: 0x232326), location: 0.55),
                .init(color: Color(hex: 0x101012), location: 1)
            ]
        }
    }

    /// The flat base colour for the RealityKit moulding.
    ///
    /// The design's gradient is a painted-on fake of a light raking across the
    /// moulding from the upper left. In the 3D scene the key light does that job
    /// for real, so tinting with a gradient texture would double the effect and
    /// read as dirty. This is the gradient's 55% stop; the light supplies the
    /// falloff.
    var sceneTint: PlatformColor {
        switch self {
        case .oak: PlatformColor(red: 201 / 255, green: 169 / 255, blue: 124 / 255, alpha: 1)
        case .black: PlatformColor(red: 35 / 255, green: 35 / 255, blue: 38 / 255, alpha: 1)
        }
    }

    /// Satin, not gloss — oak is the rougher of the two.
    var roughness: Float {
        switch self {
        case .oak: 0.62
        case .black: 0.38
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
