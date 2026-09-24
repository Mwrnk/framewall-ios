import ImageIO
import PhotosUI
import SwiftUI

/// Edit Profile — photo, a default avatar, the profile fields, and the bio.
/// (Figma `05 Edit Profile`, 100:977)
///
/// Edits go to a draft. Save writes it back; Back discards it.
struct EditProfileView: View {
    @Binding var profile: Profile

    @State private var draft: Profile

    @Environment(\.dismiss) private var dismiss

    init(profile: Binding<Profile>) {
        _profile = profile
        _draft = State(initialValue: profile.wrappedValue)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                EditablePhoto(profile: draft)
                    .padding(.top, Metrics.contentTop)

                PhotoSourceButtons(photo: $draft.photo)
                    .padding(.top, Metrics.photoToButtons)

                DefaultAvatarPicker(
                    // Nothing is ringed while an uploaded photo is in use.
                    selected: draft.photo == nil ? draft.defaultAvatar : nil,
                    select: { avatar in
                        draft.photo = nil
                        draft.chosenAvatar = avatar
                    }
                )
                .padding(.top, Metrics.buttonsToDefaults)

                ProfileFieldsCard(
                    name: $draft.name,
                    handle: $draft.handle,
                    location: $draft.location.orEmpty,
                    website: $draft.website.orEmpty
                )
                .padding(.top, Metrics.defaultsToFields)

                BioCard(bio: $draft.bio)
                    .padding(.top, Metrics.fieldsToBio)
            }
            .padding(.horizontal, Metrics.screenInset)
            .padding(.bottom, Metrics.contentBottom)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarVisibility(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            SaveButton(isEnabled: draft.isSavable) {
                profile = draft.trimmed
                dismiss()
            }
        }
    }

    private enum Metrics {
        /// Figma `Content` (119:459): 20 either side, 12 above the photo, and 14
        /// between the bio card and the Save button.
        static let screenInset: CGFloat = 20
        static let contentTop: CGFloat = 12
        static let contentBottom: CGFloat = 14

        static let photoToButtons: CGFloat = 28
        static let buttonsToDefaults: CGFloat = 16
        static let defaultsToFields: CGFloat = 20
        static let fieldsToBio: CGFloat = 16
    }
}

// MARK: - Photo

/// Figma `Photo` (119:460): the 96 pt avatar with a camera badge overhanging its
/// lower right. The badge marks the photo as editable; the buttons beneath do
/// the editing, so it is not itself tappable.
private struct EditablePhoto: View {
    let profile: Profile

    var body: some View {
        AvatarView(profile: profile)
            // Figma drop shadow y 4, blur 10 — halved to the sigma SwiftUI takes.
            .shadow(color: .black.opacity(0.12), radius: 5, y: 4)
            .overlay(alignment: .topLeading) {
                BadgeGlyph(glyph: "BadgeIconCamera", diameter: 30, glyphSize: 14)
                    // Badge centre at (83, 83) in the 96 pt circle, so its 34 pt
                    // outline starts at 66 and overhangs the circle by 2.
                    .offset(x: 66, y: 66)
            }
    }
}

/// Figma `Take Photo` (118:398) and `Choose from Library` (118:411): Liquid
/// Glass buttons, Small, 12 apart.
private struct PhotoSourceButtons: View {
    @Binding var photo: CGImage?

    @State private var isShowingCamera = false
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        HStack(spacing: Metrics.spacing) {
            Button {
                isShowingCamera = true
            } label: {
                label("Take Photo")
            }
            .disabled(!CameraPicker.isAvailable)

            PhotosPicker(selection: $pickerItem, matching: .images) {
                label("Choose from Library")
            }
        }
        .buttonStyle(.glass)
        .controlSize(.small)
        // The design's labels are black, not the accent tint.
        .foregroundStyle(.primary)
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraPicker { photo = $0 }
                .ignoresSafeArea()
        }
        .task(id: pickerItem) { await loadPickedPhoto() }
    }

    private func label(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.footnote)
            .fontWeight(.semibold)
    }

    private func loadPickedPhoto() async {
        guard
            let pickerItem,
            let data = try? await pickerItem.loadTransferable(type: Data.self),
            let source = CGImageSourceCreateWithData(data as CFData, nil)
        else { return }

        // A thumbnail rather than the full image: it applies the EXIF rotation,
        // which a plain decode ignores, and caps the size in the same pass.
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: ProfilePhoto.maxPixelSize
        ]
        if let decoded = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
            photo = decoded
        }
    }

    private enum Metrics {
        static let spacing: CGFloat = 12
    }
}

// MARK: - Default avatars

/// "OR PICK A DEFAULT" and Figma `Default avatars` (118:424): four across, 56 pt
/// each with 12 between, the chosen one ringed and checked.
private struct DefaultAvatarPicker: View {
    let selected: DefaultAvatar?
    let select: (DefaultAvatar) -> Void

    var body: some View {
        VStack(spacing: Metrics.headerSpacing) {
            Text("OR PICK A DEFAULT")
                .font(.footnote)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Metrics.columns, spacing: Metrics.spacing) {
                ForEach(DefaultAvatar.allCases) { avatar in
                    DefaultAvatarOption(avatar: avatar, isSelected: avatar == selected) {
                        select(avatar)
                    }
                }
            }
            .frame(width: Metrics.gridWidth)
        }
    }

    private enum Metrics {
        static let headerSpacing: CGFloat = 8
        static let avatar: CGFloat = 56
        static let spacing: CGFloat = 12
        static let gridWidth: CGFloat = avatar * 4 + spacing * 3

        static let columns = Array(
            repeating: GridItem(.fixed(avatar), spacing: spacing),
            count: 4
        )
    }
}

/// Figma `Avatar Rothko` (118:425) for the selected state.
private struct DefaultAvatarOption: View {
    let avatar: DefaultAvatar
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            avatar.image
                .resizable()
                .interpolation(.high)
                .frame(width: Metrics.avatar, height: Metrics.avatar)
                .clipShape(.circle)
                .overlay {
                    // 2 pt ring on a 64 pt circle: a 2 pt gap around the avatar.
                    Circle()
                        .strokeBorder(Color.accentColor, lineWidth: Metrics.ringWidth)
                        .frame(width: Metrics.ring, height: Metrics.ring)
                        .opacity(isSelected ? 1 : 0)
                }
                .overlay(alignment: .topLeading) {
                    BadgeGlyph(glyph: "BadgeIconCheck", diameter: 18, glyphSize: 10)
                        // Badge centre at (51, 51), so its 22 pt outline starts at 40.
                        .offset(x: 40, y: 40)
                        .opacity(isSelected ? 1 : 0)
                }
        }
        .buttonStyle(.plain)
        // Numbered, never named: the case names are internal. (code.md §8)
        .accessibilityLabel("Default avatar \(avatar.rawValue)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private enum Metrics {
        static let avatar: CGFloat = 56
        static let ring: CGFloat = 64
        static let ringWidth: CGFloat = 2
    }
}

/// A small accent circle with a white glyph, cut out from what it sits on by a
/// 2 pt outline in the background colour — Figma's 2 pt outside white stroke.
private struct BadgeGlyph: View {
    let glyph: String
    let diameter: CGFloat
    let glyphSize: CGFloat

    var body: some View {
        Circle()
            .fill(Color.accentColor)
            .frame(width: diameter, height: diameter)
            .overlay {
                Image(glyph)
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: glyphSize, height: glyphSize)
                    .foregroundStyle(.white)
            }
            .padding(Metrics.outline)
            .background(Color(.systemBackground), in: .circle)
            .accessibilityHidden(true)
    }

    private enum Metrics {
        static let outline: CGFloat = 2
    }
}

// MARK: - Fields

/// "PROFILE" and Figma `Profile card` (118:496): four 44 pt rows, labels in a
/// 100 pt column, values from 128.
private struct ProfileFieldsCard: View {
    @Binding var name: String
    @Binding var handle: String
    @Binding var location: String
    @Binding var website: String

    var body: some View {
        VStack(alignment: .leading, spacing: CardMetrics.headerSpacing) {
            Text("PROFILE")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, CardMetrics.inset)

            VStack(spacing: 0) {
                FieldRow(label: "Name", text: $name)
                    .textContentType(.name)
                RowSeparator()
                FieldRow(label: "Username", text: $handle, prefix: "@")
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                RowSeparator()
                FieldRow(label: "Location", text: $location)
                    .textContentType(.addressCityAndState)
                RowSeparator()
                FieldRow(label: "Website", text: $website)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: CardMetrics.cornerRadius))
        }
        // Handles have no "@" or spaces and are lowercase — strip what gets
        // typed or pasted rather than rejecting it.
        .onChange(of: handle) { _, newValue in
            let cleaned = newValue.filter { $0 != "@" && !$0.isWhitespace }.lowercased()
            if cleaned != newValue { handle = cleaned }
        }
    }
}

private struct FieldRow: View {
    let label: LocalizedStringKey
    @Binding var text: String
    var prefix: String?

    var body: some View {
        HStack(spacing: Metrics.columnGap) {
            Text(label)
                .frame(width: Metrics.labelWidth, alignment: .leading)

            HStack(spacing: 0) {
                if let prefix {
                    Text(prefix)
                }
                TextField(label, text: $text, prompt: nil)
                    .labelsHidden()
            }
        }
        .font(.body)
        .foregroundStyle(.primary)
        .padding(.horizontal, CardMetrics.inset)
        .frame(minHeight: Metrics.height)
    }

    private enum Metrics {
        static let height: CGFloat = 44
        static let labelWidth: CGFloat = 100
        static let columnGap: CGFloat = 12
    }
}

/// Hairline between rows, inset to the text and running to the card's edge.
private struct RowSeparator: View {
    var body: some View {
        Rectangle()
            .fill(Color(.separator))
            .frame(height: 0.5)
            .padding(.leading, CardMetrics.inset)
    }
}

// MARK: - Bio

/// "BIO" with its counter, and Figma `Bio card` (118:500): at least two lines,
/// growing with the text.
private struct BioCard: View {
    @Binding var bio: String

    var body: some View {
        VStack(alignment: .leading, spacing: CardMetrics.headerSpacing) {
            HStack {
                Text("BIO")
                Spacer()
                Text("\(bio.count)/\(Profile.bioLimit)")
                    .monospacedDigit()
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.horizontal, CardMetrics.inset)

            TextField("Bio", text: $bio, prompt: nil, axis: .vertical)
                .labelsHidden()
                .lineLimit(Metrics.minLines...)
                .font(.body)
                .padding(.horizontal, CardMetrics.inset)
                .padding(.vertical, Metrics.verticalInset)
                .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: CardMetrics.cornerRadius))
        }
        .onChange(of: bio) { _, newValue in
            if newValue.count > Profile.bioLimit {
                bio = String(newValue.prefix(Profile.bioLimit))
            }
        }
    }

    private enum Metrics {
        /// 11 + two 22 pt lines + 11 = Figma's 66 pt card.
        static let verticalInset: CGFloat = 11
        static let minLines = 2
    }
}

/// Shared by both cards.
private enum CardMetrics {
    static let inset: CGFloat = 16
    static let cornerRadius: CGFloat = 20
    /// Section label to card.
    static let headerSpacing: CGFloat = 6
}

// MARK: - Save

/// Figma `Save` (104:387): pinned, 50 tall, 16 either side and 16 above the
/// home indicator.
private struct SaveButton: View {
    let isEnabled: Bool
    let save: () -> Void

    var body: some View {
        Button(action: save) {
            Text("Save")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, minHeight: Metrics.height)
        }
        .buttonStyle(.glassProminent)
        .disabled(!isEnabled)
        .padding(.horizontal, Metrics.inset)
        .padding(.bottom, Metrics.inset)
    }

    private enum Metrics {
        static let height: CGFloat = 50
        static let inset: CGFloat = 16
    }
}

// MARK: - Helpers

private extension Profile {
    /// A name and a handle are the two things a profile cannot be without.
    var isSavable: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !handle.isEmpty
    }

    /// Whitespace trimmed, and optional fields left blank stored as `nil`.
    var trimmed: Profile {
        var copy = self
        copy.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.bio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.location = location?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        copy.website = website?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        return copy
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

private extension Binding where Value == String? {
    /// Edits an optional string in a text field, where empty means `nil`.
    var orEmpty: Binding<String> {
        Binding<String>(
            get: { wrappedValue ?? "" },
            set: { wrappedValue = $0.isEmpty ? nil : $0 }
        )
    }
}

#Preview {
    @Previewable @State var profile = Profile.sample
    NavigationStack {
        EditProfileView(profile: $profile)
    }
}
