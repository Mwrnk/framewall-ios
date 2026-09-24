import CoreGraphics
import SwiftUI
import UIKit

/// The artist card on Edit Profile: the profile's fields typed onto ruled lines
/// of a paper card, with the photo taped to its corner.
/// (Framewall Edit Profile design system, `ArtistCard` — option B)
///
/// The card is paper, so it keeps its colours in dark mode: `mat` ground, `ink`
/// text, and `wallTint` for the focus line and caret.
struct ArtistCard: View {
    @Binding var name: String
    @Binding var handle: String
    @Binding var location: String
    @Binding var website: String
    @Binding var bio: String
    let photo: CGImage?
    let avatar: DefaultAvatar

    @FocusState private var focus: CardFieldID?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardHeader()

            // The print sits beside Name and Username; at accessibility sizes the
            // fields need the full width, so it drops below them.
            let top = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: Metrics.gap))
                : AnyLayout(HStackLayout(alignment: .top, spacing: Metrics.gap))
            top {
                VStack(alignment: .leading, spacing: Metrics.fieldSpacing) {
                    CardField(label: "Name", text: $name, id: .name, focus: $focus)
                        .textContentType(.name)
                    CardField(
                        label: "Username", text: $handle, id: .handle, focus: $focus,
                        prefix: "@", help: "Lowercase, no spaces."
                    )
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                }
                TapedPrint(photo: photo, avatar: avatar)
                    .padding(.top, 2)
            }
            .padding(.top, Metrics.headerToFields)

            VStack(alignment: .leading, spacing: Metrics.fieldSpacing) {
                CardField(label: "Studio", text: $location, id: .location, focus: $focus)
                    .textContentType(.addressCityAndState)
                CardField(label: "Website", text: $website, id: .website, focus: $focus)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                StatementField(bio: $bio, focus: $focus)
            }
            .padding(.top, Metrics.fieldSpacing)
        }
        .foregroundStyle(Palette.ink)
        .tint(Palette.wallTint)
        .padding(.top, 16)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .background {
            // Shadows on the paper only, so the text on it stays crisp. CSS blurs
            // 2 / 32 halved to the sigma SwiftUI takes; black ground needs more.
            RoundedRectangle(cornerRadius: Metrics.cornerRadius)
                .fill(Palette.mat)
                .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.14), radius: 1, y: 1)
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.6 : 0.12), radius: 16, y: 12)
        }
    }

    private enum Metrics {
        static let cornerRadius: CGFloat = 6
        static let gap: CGFloat = 18
        static let headerToFields: CGFloat = 18
        static let fieldSpacing: CGFloat = 14
    }
}

enum CardFieldID: Hashable {
    case name, handle, location, website, statement
}

// MARK: - Header

/// A punched hole, "Artist card" in mono, the wordmark, and a double rule.
private struct CardHeader: View {
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                HStack(spacing: 10) {
                    PunchedHole()
                    Text("Artist card")
                        .font(.footnote.monospaced())
                        .fontWeight(.semibold)
                        .tracking(0.26)
                }
                Spacer()
                Text(verbatim: "Framewall")
                    .font(.display(17))
                    .tracking(-0.34)
            }
            // A 3 pt double rule: two 1 pt lines, 1 pt apart.
            VStack(spacing: 1) {
                Rectangle().frame(height: 1)
                Rectangle().frame(height: 1)
            }
            .foregroundStyle(Palette.ink.opacity(0.72))
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// The hole shows whatever is behind the card, so it takes the screen's ground.
private struct PunchedHole: View {
    var body: some View {
        Circle()
            .fill(Color(.systemBackground).shadow(.inner(color: .black.opacity(0.35), radius: 1, x: 1, y: 1.5)))
            .frame(width: 11, height: 11)
    }
}

// MARK: - Fields

/// A mono label over an SF Pro value on a ruled line. The line turns
/// `wallTint` and thickens to 2 pt while the field is focused.
private struct CardField: View {
    let label: LocalizedStringKey
    @Binding var text: String
    let id: CardFieldID
    var focus: FocusState<CardFieldID?>.Binding
    var prefix: String?
    var help: LocalizedStringKey?

    var body: some View {
        let isFocused = focus.wrappedValue == id

        VStack(alignment: .leading, spacing: 3) {
            CardLabel(text: label)

            HStack(spacing: 0) {
                if let prefix {
                    Text(verbatim: prefix)
                }
                TextField(label, text: $text, prompt: nil)
                    .labelsHidden()
                    .focused(focus, equals: id)
            }
            .font(.body)
            .padding(.top, 2)
            .padding(.bottom, 6)
            .overlay(alignment: .bottom) {
                // 0.46 ink is the lightest line that still reads 3:1 on `mat`.
                Rectangle()
                    .fill(isFocused ? Palette.wallTint : Palette.ink.opacity(0.46))
                    .frame(height: isFocused ? 2 : 1)
            }

            if isFocused, let help {
                Text(help)
                    .font(.footnote)
                    .foregroundStyle(Palette.inkSecondary)
                    .padding(.top, 3)
            }
        }
        // The label is part of the target: tapping it focuses the field.
        .contentShape(.rect)
        .onTapGesture { focus.wrappedValue = id }
    }
}

private struct CardLabel: View {
    let text: LocalizedStringKey

    var body: some View {
        Text(text)
            .font(.footnote.monospaced())
            .fontWeight(.medium)
            .foregroundStyle(Palette.inkSecondary)
            .accessibilityHidden(true)
    }
}

/// The bio, written on ruled lines like the rest of the card, with a counter.
/// At least two lines, growing with the text.
private struct StatementField: View {
    @Binding var bio: String
    var focus: FocusState<CardFieldID?>.Binding

    /// Space between lines of text; the rule sits in the middle of it.
    @ScaledMetric(relativeTo: .body) private var leading: CGFloat = 6
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // The rules are drawn at the text's own line pitch, so they have to know
        // the body font's line height at the current Dynamic Type size.
        let lineHeight = UIFont.preferredFont(
            forTextStyle: .body,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicTypeSize))
        ).lineHeight

        VStack(alignment: .leading, spacing: 3) {
            CardLabel(text: "Statement")

            TextField("Statement", text: $bio, prompt: nil, axis: .vertical)
                .labelsHidden()
                .focused(focus, equals: .statement)
                .lineLimit(2...)
                .font(.body)
                .lineSpacing(leading)
                .padding(.bottom, leading)
                .background(alignment: .top) {
                    RuledLines(lineHeight: lineHeight, pitch: lineHeight + leading)
                }

            Text("\(bio.count)/\(Profile.bioLimit)")
                .font(.footnote.monospaced())
                .monospacedDigit()
                .foregroundStyle(Palette.inkSecondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityLabel("\(bio.count) of \(Profile.bioLimit) characters")
        }
    }
}

/// One hairline under each line of text, half the leading below it.
private struct RuledLines: View {
    let lineHeight: CGFloat
    let pitch: CGFloat

    var body: some View {
        Canvas { context, size in
            var y = lineHeight + (pitch - lineHeight) / 2
            while y <= size.height {
                context.fill(Path(CGRect(x: 0, y: y - 0.5, width: size.width, height: 1)), with: .color(Palette.ink.opacity(0.46)))
                y += pitch
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Photo

/// The photo as a small print with a white border, turned 2.5° and held on by a
/// strip of masking tape.
private struct TapedPrint: View {
    let photo: CGImage?
    let avatar: DefaultAvatar

    var body: some View {
        portrait
            .frame(width: Metrics.imageWidth, height: Metrics.imageHeight)
            .clipped()
            .padding([.horizontal, .top], Metrics.border)
            .padding(.bottom, Metrics.bottomBorder)
            .background {
                // CSS blurs 2 / 14, halved.
                Rectangle()
                    .fill(Palette.paper)
                    .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
                    .shadow(color: .black.opacity(0.12), radius: 7, y: 6)
            }
            .overlay(alignment: .top) {
                TornStrip()
                    .fill(Palette.tape.opacity(0.92))
                    .frame(width: 62, height: 20)
                    .rotationEffect(.degrees(-7))
                    .offset(y: -11)
            }
            .rotationEffect(.degrees(2.5))
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var portrait: some View {
        if let photo {
            Image(decorative: photo, scale: 1)
                .resizable()
                .scaledToFill()
        } else {
            avatar.image
                .resizable()
                .interpolation(.high)
                .scaledToFill()
        }
    }

    /// A 108 × 132 print: 6 pt border on three sides, a 22 pt foot.
    private enum Metrics {
        static let border: CGFloat = 6
        static let bottomBorder: CGFloat = 22
        static let imageWidth: CGFloat = 96
        static let imageHeight: CGFloat = 104
    }
}

#Preview {
    @Previewable @State var profile = Profile.sample
    ScrollView {
        ArtistCard(
            name: $profile.name,
            handle: $profile.handle,
            location: Binding(get: { profile.location ?? "" }, set: { profile.location = $0 }),
            website: Binding(get: { profile.website ?? "" }, set: { profile.website = $0 }),
            bio: $profile.bio,
            photo: nil,
            avatar: profile.defaultAvatar
        )
        .padding(20)
    }
}
