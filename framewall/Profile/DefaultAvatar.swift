import SwiftUI

/// The painterly stand-ins for people who have not uploaded a photo.
/// (Figma `Default Avatar`, 114:417 — code.md §5)
///
/// The case names nod to painters. code.md §8 is explicit that these are
/// **internal names only** and must never reach the UI, which is why this type
/// deliberately has no display name — there is nothing here to accidentally render.
enum DefaultAvatar: Int, CaseIterable, Identifiable, Sendable {
    case rothko = 1
    case mondrian
    case matisse
    case bauhaus
    case malevich
    case miro
    case kandinsky
    case vanGogh

    var id: Int { rawValue }

    var imageName: String { "DefaultAvatar\(rawValue)" }

    var image: Image { Image(imageName) }

    /// Picks a stable avatar for someone with no photo, so the same handle always
    /// gets the same one rather than shuffling between launches.
    static func deterministic(for handle: String) -> DefaultAvatar {
        let hash = handle.unicodeScalars.reduce(into: 0) { total, scalar in
            total = (total &* 31 &+ Int(scalar.value)) % 1_000_003
        }
        let all = allCases
        return all[abs(hash) % all.count]
    }
}

/// A circular profile picture: the person's photo when they have one, otherwise
/// their default. The design's 96 pt circle. (Figma `Profile picture`, 102:1660)
struct AvatarView: View {
    let profile: Profile
    var diameter: CGFloat = 96

    var body: some View {
        Group {
            if let photo = profile.photo {
                Image(decorative: photo, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                profile.defaultAvatar.image
                    .resizable()
                    .interpolation(.high)
            }
        }
        .frame(width: diameter, height: diameter)
        .clipShape(.circle)
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 12) {
        ForEach(DefaultAvatar.allCases) { avatar in
            avatar.image
                .resizable()
                .frame(width: 56, height: 56)
                .clipShape(.circle)
        }
    }
    .padding()
}
