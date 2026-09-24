import SwiftUI

/// Edit Profile — the artist card, the Take Photo button, and the default avatars
/// as a sheet of stickers. (Framewall Edit Profile design system, option B
/// `ArtistCard`; supersedes Figma `05 Edit Profile`, 100:977)
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
                ArtistCard(
                    name: $draft.name,
                    handle: $draft.handle,
                    location: $draft.location.orEmpty,
                    website: $draft.website.orEmpty,
                    bio: $draft.bio,
                    photo: draft.photo,
                    avatar: draft.defaultAvatar
                )
                .padding(.top, Metrics.contentTop)

                TakePhotoButton(photo: $draft.photo)
                    .padding(.top, Metrics.cardToButtons)

                DefaultAvatarPicker(
                    // Nothing is ringed while an uploaded photo is in use.
                    selected: draft.photo == nil ? draft.defaultAvatar : nil,
                    select: { avatar in
                        draft.photo = nil
                        draft.chosenAvatar = avatar
                    }
                )
                .padding(.top, Metrics.buttonsToDefaults)
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
        // Handles have no "@" or spaces and are lowercase — strip what gets
        // typed or pasted rather than rejecting it.
        .onChange(of: draft.handle) { _, newValue in
            let cleaned = newValue.filter { $0 != "@" && !$0.isWhitespace }.lowercased()
            if cleaned != newValue { draft.handle = cleaned }
        }
        .onChange(of: draft.bio) { _, newValue in
            if newValue.count > Profile.bioLimit {
                draft.bio = String(newValue.prefix(Profile.bioLimit))
            }
        }
    }

    private enum Metrics {
        /// 20 either side, as before; the card starts 10 below the nav bar.
        static let screenInset: CGFloat = 20
        static let contentTop: CGFloat = 10
        static let contentBottom: CGFloat = 14

        static let cardToButtons: CGFloat = 24
        static let buttonsToDefaults: CGFloat = 26
    }
}

// MARK: - Photo

/// Figma `Take Photo` (118:398): a small Liquid Glass button under the card.
/// Camera only — profile photos, like works, are photographed in the app, so
/// there is no library button. (Framewall Design System, Imagery)
private struct TakePhotoButton: View {
    @Binding var photo: CGImage?

    @State private var isShowingCamera = false

    var body: some View {
        Button {
            isShowingCamera = true
        } label: {
            Text("Take Photo")
                .font(.footnote)
                .fontWeight(.semibold)
        }
        .buttonStyle(.glass)
        .controlSize(.small)
        // The design's labels are black, not the accent tint.
        .foregroundStyle(.primary)
        .disabled(!CameraPicker.isAvailable)
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraPicker { photo = $0 }
                .ignoresSafeArea()
        }
    }
}

// MARK: - Default avatars

/// "OR PICK A DEFAULT" and the eight defaults as a sheet of round die-cut
/// stickers, four across, each turned a few degrees. The chosen one is ringed
/// and checked.
private struct DefaultAvatarPicker: View {
    let selected: DefaultAvatar?
    let select: (DefaultAvatar) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.headerSpacing) {
            Text("Or pick a default")
                .font(.footnote)
                .tracking(0.78)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .padding(.horizontal, Metrics.labelInset)

            LazyVGrid(columns: Metrics.columns, spacing: Metrics.rowSpacing) {
                ForEach(DefaultAvatar.allCases) { avatar in
                    DefaultAvatarOption(avatar: avatar, isSelected: avatar == selected) {
                        select(avatar)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private enum Metrics {
        static let headerSpacing: CGFloat = 8
        static let labelInset: CGFloat = 16
        static let rowSpacing: CGFloat = 16
        static let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
    }
}

/// One default as a sticker: the 54 pt avatar on a 62 pt disc of paper — a 4 pt
/// die-cut edge — lifted off the page by a soft shadow.
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
                .frame(width: Metrics.sticker, height: Metrics.sticker)
                .background {
                    // CSS blurs 2 / 8, halved.
                    Circle()
                        .fill(Palette.paper)
                        .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
                        .shadow(color: .black.opacity(0.12), radius: 4, y: 3)
                }
                .overlay {
                    // 2 pt ring 3 pt outside the sticker's edge.
                    Circle()
                        .strokeBorder(Color.accentColor, lineWidth: Metrics.ringWidth)
                        .frame(width: Metrics.ring, height: Metrics.ring)
                        .opacity(isSelected ? 1 : 0)
                }
                .overlay(alignment: .bottomTrailing) {
                    BadgeGlyph(glyph: "BadgeIconCheck", diameter: 18, glyphSize: 10)
                        .offset(x: 5, y: 5)
                        .opacity(isSelected ? 1 : 0)
                }
                // A sheet of stickers is never quite square; the tilt is fixed
                // per avatar so the sheet doesn't reshuffle.
                .rotationEffect(.degrees(Metrics.tilt[(avatar.rawValue - 1) % Metrics.tilt.count]))
        }
        .buttonStyle(.plain)
        // Numbered, never named: the case names are internal. (code.md §8)
        .accessibilityLabel("Default avatar \(avatar.rawValue)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private enum Metrics {
        static let avatar: CGFloat = 54
        static let sticker: CGFloat = 62
        static let ring: CGFloat = 72
        static let ringWidth: CGFloat = 2
        static let tilt: [Double] = [-4, 3, -2, 5, 2, -5, 4, -3]
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
