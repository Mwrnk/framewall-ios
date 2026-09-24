import CoreText
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
    /// Passe-partout board inside the Limed oak frame, and the artist card's paper.
    static let mat = Color(hex: 0xF7F5EF)
    /// Secondary text on paper and on the gallery wall: `ink` at 0.66, 6.3:1 on
    /// `mat`. `.secondary` would turn light-on-light in dark mode.
    static let inkSecondary = Color(hex: 0x141414).opacity(0.66)
    /// Masking tape on an object: `cadmiumWash` pinned to its light value.
    static let tape = Color(hex: 0xFBE3A6)
    /// `ultramarine` pinned to its light value, for the focus line and caret on paper.
    static let wallTint = Color(hex: 0x1F4E9C)
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
    /// The bundled file is the variable font (OFL, `Fonts/OFL.txt`). Its named
    /// instances carry awkward PostScript names ("…-96ptExtraBold_Bold"), so rather
    /// than look one up by name this sets the weight and optical-size axes on the
    /// file's descriptor directly. Optical size follows the point size, as the
    /// design system asks: 12 pt sticker text gets the open, sturdy 12 pt cut; a
    /// 40 pt masthead the tight 96 pt one.
    static func display(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        guard let base = BricolageGrotesque.descriptor else {
            return .system(size: size, weight: weight)
        }
        let variation: [NSNumber: NSNumber] = [
            BricolageGrotesque.weightAxis: NSNumber(value: BricolageGrotesque.axisValue(for: weight)),
            BricolageGrotesque.opticalSizeAxis: NSNumber(value: Double(min(max(size, 12), 96)))
        ]
        let descriptor = CTFontDescriptorCreateCopyWithAttributes(
            base,
            [kCTFontVariationAttribute: variation] as CFDictionary
        )
        return Font(CTFontCreateWithFontDescriptor(descriptor, size, nil))
    }
}

/// The bundled variable font, read straight from its file — no Info.plist entry
/// or registration needed.
private enum BricolageGrotesque {
    static let descriptor: CTFontDescriptor? = {
        guard
            let url = Bundle.main.url(forResource: "BricolageGrotesque", withExtension: "ttf"),
            let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor]
        else { return nil }
        return descriptors.first
    }()

    /// OpenType axis tags as four-character codes: 'wght' and 'opsz'.
    static let weightAxis = NSNumber(value: 0x7767_6874)
    static let opticalSizeAxis = NSNumber(value: 0x6F70_737A)

    /// The font runs 200–800 on its weight axis.
    static func axisValue(for weight: Font.Weight) -> Double {
        switch weight {
        case .ultraLight, .thin: 200
        case .light: 300
        case .medium: 500
        case .semibold: 600
        case .bold: 700
        case .heavy, .black: 800
        default: 400
        }
    }
}
