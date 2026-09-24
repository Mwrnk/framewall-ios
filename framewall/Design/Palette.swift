import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// Framewall's pigments and the fixed materials frames and stickers are made of.
/// Values are the design system's tokens (Framewall Design System, `tokens.json`).
///
/// The pigments shift in dark mode so they stay legible on black. The materials
/// (`paint*`, `mat`, `ink`, `paper`) don't: a frame or a printed sticker is an
/// object, and an object doesn't change colour with the phone's theme.
enum Palette {
    // MARK: Pigments, light / dark

    static let ultramarine = Color(light: 0x1F4E9C, dark: 0x7FA3FF)
    static let onUltramarine = Color(light: 0xFFFFFF, dark: 0x000000)
    static let vermilion = Color(light: 0xCC3024, dark: 0xFF6B57)
    static let onVermilion = Color(light: 0xFFFFFF, dark: 0x000000)
    static let cadmium = Color(light: 0xF2B633, dark: 0xFFC94A)
    static let cadmiumWash = Color(light: 0xFBE3A6, dark: 0x4A3A10)
    static let viridian = Color(light: 0x2E7D32, dark: 0x5CC46A)
    static let onViridian = Color(light: 0xFFFFFF, dark: 0x000000)

    // MARK: Materials, fixed

    /// The pigment black from the default avatars; text on cadmium and on paper.
    static let ink = Color(hex: 0x141414)
    /// Sticker paper and the die-cut edge. White in both themes.
    static let paper = Color(hex: 0xFFFFFF)
    /// The underside of a peeling sticker, and the gallery wall's edge.
    static let paperShade = Color(hex: 0xE2E2E6)
    /// Passe-partout board inside the Limed oak frame.
    static let mat = Color(hex: 0xF7F5EF)
}

extension Color {
    /// A colour that follows the light / dark appearance, from two `0xRRGGBB` literals.
    init(light: UInt32, dark: UInt32) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
        })
        #else
        self.init(hex: light)
        #endif
    }
}

extension Font {
    /// The display face, Bricolage Grotesque, for names of things and stickers.
    ///
    /// Until the font file is bundled this is heavy SF Pro. `Font.custom` alone
    /// would fall back to the system font at *regular* weight, losing the weight.
    static func display(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        #if canImport(UIKit)
        if UIFont(name: displayFamily, size: size) != nil {
            return .custom(displayFamily, size: size).weight(weight)
        }
        #endif
        return .system(size: size, weight: weight)
    }

    private static let displayFamily = "Bricolage Grotesque"
}
