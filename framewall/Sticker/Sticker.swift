import Foundation

/// The ten sticker styles an artist can put beside a work. Each borrows a real
/// object from a studio, a gallery or a print shop. (Framewall Design System,
/// `Sticker`)
enum StickerStyle: String, CaseIterable, Identifiable, Sendable {
    case dieCut
    case tape
    case redDot
    case starburst
    case stamp
    case tag
    case peel
    case seal
    case chip
    case riso

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dieCut: "Die-cut vinyl"
        case .tape: "Masking tape"
        case .redDot: "Red dot"
        case .starburst: "Starburst"
        case .stamp: "Rubber stamp"
        case .tag: "Inventory tag"
        case .peel: "Peeling corner"
        case .seal: "Seal"
        case .chip: "Paint chip"
        case .riso: "Risograph"
        }
    }

    /// The words the artist can pick from, first one the default.
    ///
    /// There is no free text on purpose: a sticker names a state of the work, never
    /// a count or praise, and a fixed list keeps it short enough for the slot. The
    /// inventory tag has no word; the app fills in the work's number and facts.
    var words: [String] {
        switch self {
        case .dieCut: ["Just scanned", "Fresh", "Studio day"]
        case .tape: ["still wet", "study", "sketch", "wip"]
        case .redDot: ["Sold"]
        case .starburst: ["New work", "New series", "Revisited"]
        case .stamp: ["Scanned", "Started", "Finished"]
        case .tag: []
        case .peel: ["Framed", "Commission", "Gift"]
        case .seal: ["Made by hand", "From life", "Plein air"]
        case .chip: ["First work", "Last of the series"]
        case .riso: ["Opening night", "On show", "Open studio"]
        }
    }
}

/// The sticker an artist chose for a work: a style, one of its words and, for
/// the paint chip, a swatch.
struct Sticker: Hashable, Sendable {
    var style: StickerStyle
    var word: String
    /// The paint chip's swatch.
    var swatch: FramePaint
    /// When it went on; the rubber stamp prints it.
    var date: Date

    init(
        style: StickerStyle,
        word: String? = nil,
        swatch: FramePaint = .viridian,
        date: Date = .now
    ) {
        self.style = style
        self.word = word ?? style.words.first ?? ""
        self.swatch = swatch
        self.date = date
    }
}
