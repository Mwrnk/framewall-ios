import CoreGraphics
import Foundation

/// The shape a piece is posted in. (Figma `Size picker`, 104:354)
///
/// This is the aspect ratio, not the true size. code.md §1 wants real centimetres
/// declared on upload; those come from the metadata form in build step 2, so the
/// values here are sensible defaults the artist can correct later.
enum PostSize: String, CaseIterable, Identifiable, Sendable {
    case square
    case portrait
    case landscape

    var id: String { rawValue }

    var label: String {
        switch self {
        case .square: "Square"
        case .portrait: "Portrait"
        case .landscape: "Landscape"
        }
    }

    /// Width ÷ height.
    var aspectRatio: CGFloat {
        switch self {
        case .square: 1
        case .portrait: 3.0 / 4.0
        case .landscape: 4.0 / 3.0
        }
    }

    /// A plausible canvas in centimetres, pending the real declared dimensions.
    var physicalSize: CGSize {
        switch self {
        case .square: CGSize(width: 60, height: 60)
        case .portrait: CGSize(width: 60, height: 80)
        case .landscape: CGSize(width: 80, height: 60)
        }
    }

    /// The design states the square case as 2048 × 2048. The others hold 2048 on
    /// the short edge so every shape carries the same detail per centimetre.
    var minimumPixels: (width: Int, height: Int) {
        let short = 2048
        switch self {
        case .square: return (short, short)
        case .portrait: return (short, Int((CGFloat(short) / aspectRatio).rounded()))
        case .landscape: return (Int((CGFloat(short) * aspectRatio).rounded()), short)
        }
    }

    /// "Square  ·  at least 2048 × 2048 px  ·  JPG or PNG"
    var requirements: String {
        let pixels = minimumPixels
        return "\(label)  ·  at least \(pixels.width) × \(pixels.height) px  ·  JPG or PNG"
    }
}
