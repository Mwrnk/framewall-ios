import CoreGraphics
import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// A painting, with the physical size that makes it an object rather than a file.
///
/// code.md §1: uploads declare dimensions in cm, so the work has a true size
/// everywhere it appears — feed, room, widget, AR wall.
struct Artwork: Identifiable, Sendable {
    let id: UUID
    var title: String
    var artist: String
    /// The artist's handle, without the leading `@`.
    var handle: String?
    var year: Int?
    var medium: String?
    /// The artist's own few lines about the work, shown in the viewer.
    /// (Figma `02 Artwork`, 111:374)
    var note: String?
    /// True size in centimetres.
    var size: CGSize
    var finish: FrameFinish
    /// The one sticker the artist chose to put on the wall beside the work, if any.
    var sticker: Sticker?
    /// Its place in the artist's archive, shown on the inventory-tag sticker.
    var number: Int?
    /// The scan. `nil` renders the placeholder — no unlicensed art ships in code.
    var image: CGImage?

    init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        handle: String? = nil,
        year: Int? = nil,
        medium: String? = nil,
        note: String? = nil,
        size: CGSize,
        finish: FrameFinish = .oak,
        sticker: Sticker? = nil,
        number: Int? = nil,
        image: CGImage? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.handle = handle
        self.year = year
        self.medium = medium
        self.note = note
        self.size = size
        self.finish = finish
        self.sticker = sticker
        self.number = number
        self.image = image
    }

    var geometry: FrameGeometry {
        FrameGeometry(artworkSize: size, borderRatio: Float(finish.borderRatio))
    }

    /// "60 × 80 cm" — the declared physical size, which is the one fact every
    /// surface in the app shows.
    var dimensions: String {
        "\(Int(size.width.rounded())) × \(Int(size.height.rounded())) cm"
    }

    /// "Oil on canvas · 60 × 80 cm · 2025", skipping whatever is missing.
    var caption: String {
        var parts: [String] = []
        if let medium { parts.append(medium) }
        parts.append(dimensions)
        if let year { parts.append(String(year)) }
        return parts.joined(separator: " · ")
    }

    /// The viewer's metadata line: "2025  ·  Acrylic on canvas  ·  60 × 60 cm".
    ///
    /// The same facts as ``caption`` in the order the Artwork screen sets them,
    /// and with the double spacing the design uses around the middots — at
    /// Footnote size a single space runs the three facts together.
    /// (Figma `02 Artwork`, 102:1513)
    var viewerCaption: String {
        var parts: [String] = []
        if let year { parts.append(String(year)) }
        if let medium { parts.append(medium) }
        parts.append(dimensions)
        return parts.joined(separator: "  ·  ")
    }

    /// The feed's second caption line: "Mateus Werneck  ·  @mwrnk".
    ///
    /// The design sets two spaces either side of the middot, not one — at
    /// Footnote size the single-spaced version reads as one run-on name.
    var byline: String {
        guard let handle else { return artist }
        return "\(artist)  ·  @\(handle)"
    }
}

// MARK: - Sample content

extension Artwork {
    /// A stand-in for previews and for pieces still uploading.
    ///
    /// Deliberately generated rather than bundled: code.md §8 records that every
    /// placeholder in the design is unlicensed, so none of it belongs in the repo.
    static func placeholder(
        size: CGSize = CGSize(width: 60, height: 80),
        finish: FrameFinish = .oak
    ) -> Artwork {
        Artwork(
            title: "Untitled",
            artist: "—",
            size: size,
            finish: finish,
            image: CGImage.softFieldGradient()
        )
    }

    /// The two posts in the Feed design (Figma `01 Feed`, 100:917).
    ///
    /// Only the first carries its real painting. The second's artwork in the design
    /// is an album cover standing in for a work that does not exist, so it gets the
    /// generated placeholder — see the note on ``campusBloom``.
    static var sampleFeed: [Artwork] { [.theOtherSideOffAFlower, .campusBloom] }

    /// Mateus's own painting — the one piece in the design that is genuinely his
    /// and therefore the only bundled artwork. (code.md §8)
    static let theOtherSideOffAFlower = Artwork(
        title: "The Other Side Off a Flower",
        artist: "Mateus Werneck",
        handle: "mwrnk",
        year: 2025,
        medium: "Acrylic on canvas",
        note: """
            Painted from the back of the garden, at the hour the light stops \
            being useful. The frame is the one it will ship in.
            """,
        size: CGSize(width: 60, height: 60),
        finish: .oak,
        sticker: Sticker(style: .peel, word: "Framed"),
        number: 1,
        image: CGImage.named("TheOtherSideOffAFlower")
    )

    /// The design fills this post with an album cover. code.md §8 is explicit that
    /// those are unlicensed stand-ins to be replaced before anything ships, so the
    /// artwork is generated here rather than bundled. Everything else — title,
    /// artist, handle, black frame — matches the design.
    static let campusBloom = Artwork(
        title: "Campus Bloom",
        artist: "Ana Ribeiro",
        handle: "anarib",
        size: CGSize(width: 60, height: 60),
        finish: .black,
        image: CGImage.softFieldGradient(
            top: (0.55, 0.30, 0.68),
            bottom: (0.24, 0.13, 0.42)
        )
    )
}

extension CGImage {
    /// Loads a bundled artwork out of the asset catalogue.
    static func named(_ name: String) -> CGImage? {
        #if canImport(UIKit)
        UIImage(named: name)?.cgImage
        #elseif canImport(AppKit)
        NSImage(named: name)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        #else
        nil
        #endif
    }

    /// Two soft bands of colour bleeding into each other — enough to read as a
    /// painting at frame scale without pretending to be one.
    static func softFieldGradient(
        pixelSize: Int = 512,
        top: (CGFloat, CGFloat, CGFloat) = (0.78, 0.30, 0.19),
        bottom: (CGFloat, CGFloat, CGFloat) = (0.38, 0.16, 0.22)
    ) -> CGImage? {
        let space = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: pixelSize,
            height: pixelSize,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        let colors = [
            CGColor(colorSpace: space, components: [top.0, top.1, top.2, 1]),
            CGColor(colorSpace: space, components: [bottom.0, bottom.1, bottom.2, 1])
        ].compactMap { $0 } as CFArray

        guard let gradient = CGGradient(
            colorsSpace: space,
            colors: colors,
            locations: [0, 1]
        ) else { return nil }

        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: pixelSize),
            end: CGPoint(x: 0, y: 0),
            options: []
        )
        return context.makeImage()
    }
}
