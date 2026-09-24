import SwiftUI

/// One sticker, drawn at its design size: the size it has in a 360 pt stage.
/// Callers scale it with the stage. (Framewall Design System, `Sticker`)
///
/// Every style is its own view so each carries only the inputs it reads.
struct StickerView: View {
    let sticker: Sticker
    /// The work's archive number, for the inventory tag.
    var number: Int?
    /// "Oil · 60 × 60 cm", for the inventory tag.
    var facts: String = ""

    var body: some View {
        content
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Sticker: \(spokenText)")
    }

    @ViewBuilder
    private var content: some View {
        switch sticker.style {
        case .dieCut: DieCutSticker(word: sticker.word)
        case .tape: TapeSticker(word: sticker.word)
        case .redDot: RedDotSticker(word: sticker.word)
        case .starburst: StarburstSticker(word: sticker.word)
        case .stamp: StampSticker(word: sticker.word, date: sticker.date)
        case .tag: TagSticker(number: archiveNumber, facts: facts)
        case .peel: PeelSticker(word: sticker.word)
        case .seal: SealSticker(word: sticker.word)
        case .chip: ChipSticker(word: sticker.word, swatch: sticker.swatch, number: archiveNumber)
        case .riso: RisoSticker(word: sticker.word)
        }
    }

    /// "No. 014" — three digits reads as an archive, not a count.
    private var archiveNumber: String {
        "No. " + String(format: "%03d", number ?? 1)
    }

    private var spokenText: String {
        switch sticker.style {
        case .tag: archiveNumber
        case .stamp: "\(sticker.word) \(sticker.date.formatted(date: .abbreviated, time: .omitted))"
        default: sticker.word
        }
    }
}

// MARK: - 01 Die-cut vinyl

/// A cadmium pill with a thick white kiss-cut edge.
private struct DieCutSticker: View {
    let word: String

    var body: some View {
        Text(word.uppercased())
            .font(.display(13))
            .tracking(0.26)
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Palette.cadmium, in: .capsule)
            .padding(5)
            .background(Palette.paper, in: .capsule)
            .shadow(color: .black.opacity(0.16), radius: 5, y: 4)
            .rotationEffect(.degrees(-6))
    }
}

// MARK: - 02 Masking tape

/// A torn strip of tape, typed in mono, lower case.
private struct TapeSticker: View {
    let word: String

    var body: some View {
        Text(word.lowercased())
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .tracking(0.5)
            .foregroundStyle(.primary)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Palette.cadmiumWash, in: TornStrip())
            .opacity(0.94)
            .rotationEffect(.degrees(3))
    }
}

/// A rectangle with zig-zag torn ends.
private struct TornStrip: Shape {
    func path(in rect: CGRect) -> Path {
        let teeth = 6
        let depth: CGFloat = 4
        let step = rect.height / CGFloat(teeth)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + depth, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - depth, y: rect.minY))
        for i in 1...teeth {
            let x = i.isMultiple(of: 2) ? rect.maxX - depth : rect.maxX
            path.addLine(to: CGPoint(x: x, y: rect.minY + step * CGFloat(i)))
        }
        path.addLine(to: CGPoint(x: rect.minX + depth, y: rect.maxY))
        for i in stride(from: teeth - 1, through: 0, by: -1) {
            let x = i.isMultiple(of: 2) ? rect.minX + depth : rect.minX
            path.addLine(to: CGPoint(x: x, y: rect.minY + step * CGFloat(i)))
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - 03 Red dot

/// The gallery's sold dot, glossy. The only sticker that means sold.
private struct RedDotSticker: View {
    let word: String

    var body: some View {
        Text(word.uppercased())
            .font(.display(13))
            .foregroundStyle(Palette.onVermilion)
            .frame(width: 62, height: 62)
            .background {
                Circle()
                    .fill(Palette.vermilion)
                    .overlay {
                        Circle().fill(
                            RadialGradient(
                                colors: [.white.opacity(0.38), .white.opacity(0)],
                                center: UnitPoint(x: 0.34, y: 0.28),
                                startRadius: 0,
                                endRadius: 26
                            )
                        )
                    }
                    .overlay {
                        Circle().strokeBorder(.black.opacity(0.14), lineWidth: 1.5)
                    }
            }
            .shadow(color: .black.opacity(0.22), radius: 2.5, y: 2)
    }
}

// MARK: - 04 Starburst

/// The shop-window price burst, played straight.
private struct StarburstSticker: View {
    let word: String

    var body: some View {
        Text(word.uppercased())
            .font(.display(15))
            .multilineTextAlignment(.center)
            .lineSpacing(-3)
            .foregroundStyle(Palette.ink)
            .frame(width: 66)
            .frame(width: 80, height: 80)
            .background(Palette.cadmium, in: Starburst(points: 14, innerRatio: 0.76))
            .shadow(color: .black.opacity(0.2), radius: 1.5, y: 2)
            .rotationEffect(.degrees(12))
    }
}

private struct Starburst: Shape {
    let points: Int
    let innerRatio: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        var path = Path()
        for i in 0..<(points * 2) {
            let radius = i.isMultiple(of: 2) ? outer : outer * innerRatio
            let angle = Double(i) * .pi / Double(points) - .pi / 2
            let point = CGPoint(
                x: center.x + radius * CGFloat(cos(angle)),
                y: center.y + radius * CGFloat(sin(angle))
            )
            i == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - 05 Rubber stamp

/// A double-ruled ultramarine stamp with the date the sticker went on.
private struct StampSticker: View {
    let word: String
    let date: Date

    var body: some View {
        VStack(spacing: 1) {
            Text(word.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(1.4)
            Text(stampDate)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .tracking(1)
        }
        .foregroundStyle(Palette.ultramarine)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .overlay { RoundedRectangle(cornerRadius: 3).strokeBorder(Palette.ultramarine, lineWidth: 2) }
        .padding(4)
        .overlay { RoundedRectangle(cornerRadius: 4).strokeBorder(Palette.ultramarine, lineWidth: 1) }
        // Ink never lands evenly on a hand stamp.
        .opacity(0.88)
        .rotationEffect(.degrees(-9))
    }

    /// "24·09·2026": the day, month and year in the order the artist's locale uses.
    private var stampDate: String {
        date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year())
            .replacingOccurrences(of: "/", with: "·")
            .replacingOccurrences(of: ".", with: "·")
            .replacingOccurrences(of: "-", with: "·")
    }
}

// MARK: - 06 Inventory tag

/// The luggage tag an archive ties to a work: its number and its facts.
private struct TagSticker: View {
    let number: String
    let facts: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(number)
                .font(.display(17))
                .tracking(-0.34)
            Text(facts)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
        }
        .foregroundStyle(Palette.ink)
        .padding(.leading, 26)
        .padding(.trailing, 12)
        .padding(.vertical, 8)
        .background(Palette.paper, in: TagShape(point: 14))
        .overlay(alignment: .leading) {
            // The punched hole the string runs through.
            Circle()
                .strokeBorder(Color(hex: 0xAE8B5B), lineWidth: 1.5)
                .frame(width: 7, height: 7)
                .padding(.leading, 10)
        }
        .overlay(alignment: .leading) {
            Capsule()
                .fill(Color(hex: 0xAE8B5B))
                .frame(width: 26, height: 1.5)
                .rotationEffect(.degrees(-18), anchor: .trailing)
                .offset(x: -12)
        }
        .shadow(color: .black.opacity(0.22), radius: 1.5, y: 2)
        .rotationEffect(.degrees(-5))
    }
}

/// A rectangle whose leading edge comes to a point.
private struct TagShape: Shape {
    let point: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + point, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + point, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

// MARK: - 07 Peeling corner

/// A vermilion label lifting at one corner to show the white paper underneath.
private struct PeelSticker: View {
    let word: String
    private let fold: CGFloat = 15

    var body: some View {
        Text(word.uppercased())
            .font(.display(15))
            .foregroundStyle(Palette.onVermilion)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(Palette.vermilion, in: CornerCut(size: fold))
            .overlay(alignment: .bottomTrailing) {
                FoldFlap()
                    .fill(
                        LinearGradient(
                            colors: [Palette.paperShade, Palette.paper],
                            startPoint: .bottomTrailing,
                            endPoint: .topLeading
                        )
                    )
                    .frame(width: fold, height: fold)
            }
            .shadow(color: .black.opacity(0.2), radius: 1.5, y: 2)
            .rotationEffect(.degrees(2))
    }
}

/// A rectangle with its bottom-trailing corner cut off diagonally.
private struct CornerCut: Shape {
    let size: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - size))
        path.addLine(to: CGPoint(x: rect.maxX - size, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// The folded-back corner: the triangle above the cut's diagonal.
private struct FoldFlap: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - 08 Seal

/// An ultramarine disc with its word set round the rim, like a studio's ink seal.
private struct SealSticker: View {
    let word: String
    private let diameter: CGFloat = 88
    private let textRadius: CGFloat = 32

    var body: some View {
        ZStack {
            Circle().fill(Palette.ultramarine)
            Circle()
                .strokeBorder(Palette.onUltramarine.opacity(0.5), lineWidth: 1)
                .frame(width: 44, height: 44)
            FourPointStar()
                .fill(Palette.cadmium)
                .frame(width: 26, height: 28)
            ForEach(Array(ring.enumerated()), id: \.offset) { index, character in
                Text(String(character))
                    .font(.system(size: 8.6, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Palette.onUltramarine)
                    .offset(y: -textRadius)
                    .rotationEffect(.degrees(Double(index) * 360 / Double(ring.count)))
            }
        }
        .frame(width: diameter, height: diameter)
        .shadow(color: .black.opacity(0.2), radius: 1.5, y: 2)
        .rotationEffect(.degrees(-14))
    }

    /// The word repeated round the circle. About 30 characters fill a 32 pt
    /// radius at this size without crowding.
    private var ring: [Character] {
        let unit = word.uppercased() + " · "
        let repeats = max(1, Int((30.0 / Double(unit.count)).rounded()))
        return Array(String(repeating: unit, count: repeats))
    }
}

private struct FourPointStar: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let waist = min(rect.width, rect.height) * 0.12
        var path = Path()
        path.move(to: CGPoint(x: c.x, y: rect.minY))
        path.addLine(to: CGPoint(x: c.x + waist, y: c.y - waist))
        path.addLine(to: CGPoint(x: rect.maxX, y: c.y))
        path.addLine(to: CGPoint(x: c.x + waist, y: c.y + waist))
        path.addLine(to: CGPoint(x: c.x, y: rect.maxY))
        path.addLine(to: CGPoint(x: c.x - waist, y: c.y + waist))
        path.addLine(to: CGPoint(x: rect.minX, y: c.y))
        path.addLine(to: CGPoint(x: c.x - waist, y: c.y - waist))
        path.closeSubpath()
        return path
    }
}

// MARK: - 09 Paint chip

/// The swatch card from a paint shop.
private struct ChipSticker: View {
    let word: String
    let swatch: FramePaint
    let number: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(swatch.color)
                .frame(height: 54)
                .padding([.horizontal, .top], 5)
            VStack(alignment: .leading, spacing: 3) {
                Text(word.uppercased())
                    .font(.display(12))
                Text(number)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
            }
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 7)
            .padding(.top, 6)
            .padding(.bottom, 7)
        }
        .frame(width: 86, alignment: .leading)
        .background(Palette.paper)
        .shadow(color: .black.opacity(0.18), radius: 3, y: 2)
        .rotationEffect(.degrees(5))
    }
}

// MARK: - 10 Risograph

/// Two inks printed slightly out of register on a halftone ground.
private struct RisoSticker: View {
    let word: String

    var body: some View {
        ZStack {
            Text(lines).foregroundStyle(Palette.ultramarine).offset(x: 2.5, y: 2)
            Text(lines).foregroundStyle(Palette.vermilion)
        }
        .font(.display(22))
        .lineSpacing(-4)
        .padding(.horizontal, 13)
        .padding(.top, 10)
        .padding(.bottom, 11)
        .background {
            Palette.cadmiumWash.overlay { Halftone() }
        }
        .rotationEffect(.degrees(-3))
    }

    /// Two short words stack, the way a poster sets them.
    private var lines: String {
        word.uppercased().replacingOccurrences(of: " ", with: "\n")
    }
}

/// Cadmium dots on a 6 pt grid, the riso's halftone.
private struct Halftone: View {
    var body: some View {
        Canvas { context, size in
            let pitch: CGFloat = 6
            let dot: CGFloat = 2.4
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: dot, height: dot)),
                        with: .color(Palette.cadmium)
                    )
                    x += pitch
                }
                y += pitch
            }
        }
    }
}

#Preview("All ten") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 40) {
            ForEach(StickerStyle.allCases) { style in
                StickerView(sticker: Sticker(style: style), number: 14, facts: "Oil · 60 × 60 cm")
                    .frame(height: 110)
            }
        }
        .padding(24)
    }
}
