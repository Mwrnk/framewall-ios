import SwiftUI

/// The Post screen's sticker section, below its section label: a sideways row of
/// None plus the ten styles, then the chosen style's words. (Framewall Design
/// System, `StickerPicker`)
struct StickerPicker: View {
    @Binding var selection: Sticker?
    /// The screen's content inset. The rows scroll out to the screen edges, so
    /// they undo the inset and put it back as a content margin.
    var edgeInset: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.rowSpacing) {
            ScrollView(.horizontal) {
                HStack(spacing: Metrics.tileSpacing) {
                    StickerTile(isSelected: selection == nil) {
                        Text("None")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } select: {
                        selection = nil
                    }
                    .accessibilityLabel("No sticker")

                    ForEach(StickerStyle.allCases) { style in
                        StickerTile(isSelected: selection?.style == style) {
                            StickerView(
                                sticker: sample(for: style),
                                facts: "Oil · 60 × 60 cm"
                            )
                            .fixedSize()
                            .scaleEffect(Metrics.tileScale)
                        } select: {
                            if selection?.style != style {
                                selection = Sticker(style: style)
                            }
                        }
                        .accessibilityLabel(style.displayName)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, edgeInset, for: .scrollContent)
            .padding(.horizontal, -edgeInset)

            if let sticker = selection, sticker.style.words.count > 1 {
                WordRow(words: sticker.style.words, selected: sticker.word) { word in
                    selection?.word = word
                }
                .contentMargins(.horizontal, edgeInset, for: .scrollContent)
                .padding(.horizontal, -edgeInset)
            }

            if let sticker = selection, sticker.style == .chip {
                PaintSwatchRow(selected: sticker.swatch) { paint in
                    selection?.swatch = paint
                }
            }

            Text("One per work. You can change or remove it later.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .animation(.snappy, value: selection?.style)
    }

    /// Each tile shows its style with the word the artist has picked, if that
    /// style is the current one, so the row previews the real sticker.
    private func sample(for style: StickerStyle) -> Sticker {
        if let selection, selection.style == style { return selection }
        return Sticker(style: style)
    }

    private enum Metrics {
        static let rowSpacing: CGFloat = 12
        static let tileSpacing: CGFloat = 8
        /// A sticker at 62% sits inside a 96 × 88 tile with room for its tilt.
        static let tileScale: CGFloat = 0.62
    }
}

/// One tile in the row: 96 × 88 on the grouped background, ringed when selected
/// like a frame option.
private struct StickerTile<Content: View>: View {
    let isSelected: Bool
    @ViewBuilder let content: Content
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            content
                .frame(width: 96, height: 88)
                .clipShape(.rect(cornerRadius: 14))
                .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// The chosen style's words as capsules; the picked one is filled with the tint.
private struct WordRow: View {
    let words: [String]
    let selected: String
    let select: (String) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(words, id: \.self) { word in
                    let isSelected = word == selected
                    Button(word) { select(word) }
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .foregroundStyle(isSelected ? Color(.systemBackground) : .primary)
                        .background {
                            Capsule().fill(isSelected ? Color.accentColor : .clear)
                        }
                        .overlay {
                            Capsule().strokeBorder(isSelected ? .clear : Color(.separator), lineWidth: 1)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

/// The four pigments as swatches: the Painted frame's lacquer, and the paint
/// chip sticker's card.
struct PaintSwatchRow: View {
    let selected: FramePaint
    let select: (FramePaint) -> Void

    var body: some View {
        HStack(spacing: 12) {
            ForEach(FramePaint.allCases) { paint in
                let isSelected = paint == selected
                Button {
                    select(paint)
                } label: {
                    Circle()
                        .fill(paint.color)
                        .frame(width: 28, height: 28)
                        .padding(3)
                        .overlay {
                            Circle().strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(paint.displayName)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
    }
}

#Preview {
    @Previewable @State var sticker: Sticker? = Sticker(style: .peel)
    StickerPicker(selection: $sticker)
        .padding(20)
}
