import CoreGraphics
import Foundation

/// An artist, and the room they curate. (Figma `03 Profile`, 100:947)
struct Profile: Identifiable, Sendable {
    let id: UUID
    var name: String
    /// Without the leading `@`.
    var handle: String
    var location: String?
    var bio: String
    /// The uploaded photo. `nil` falls back to ``defaultAvatar``.
    var photo: CGImage?
    /// Total works, which is not the same as `works.count` — the grid shows only
    /// what has loaded.
    var worksCount: Int
    var followers: Int
    var following: Int
    var works: [Artwork]

    init(
        id: UUID = UUID(),
        name: String,
        handle: String,
        location: String? = nil,
        bio: String,
        photo: CGImage? = nil,
        worksCount: Int,
        followers: Int,
        following: Int,
        works: [Artwork]
    ) {
        self.id = id
        self.name = name
        self.handle = handle
        self.location = location
        self.bio = bio
        self.photo = photo
        self.worksCount = worksCount
        self.followers = followers
        self.following = following
        self.works = works
    }

    var defaultAvatar: DefaultAvatar { .deterministic(for: handle) }

    /// "@mwrnk  ·  Minas Gerais, Brazil"
    var handleAndLocation: String {
        guard let location else { return "@\(handle)" }
        return "@\(handle)  ·  \(location)"
    }

    /// "12 works  ·  1.2k followers  ·  180 following"
    var stats: String {
        [
            "\(worksCount.abbreviated) works",
            "\(followers.abbreviated) followers",
            "\(following.abbreviated) following"
        ].joined(separator: "  ·  ")
    }
}

private extension Int {
    /// 1200 → "1.2k". The design lowercases the suffix; `.compactName` uppercases
    /// it, so this trims it back down.
    ///
    /// Pinned to English because every string around it is an English literal —
    /// on a pt-BR device the device locale would render "1,2k" next to "followers".
    /// **Delete the `.locale` once the app adopts String Catalogs**, so the count
    /// follows whatever language the rest of the sentence is in.
    var abbreviated: String {
        formatted(.number.notation(.compactName).locale(Locale(identifier: "en_US")))
            .lowercased()
    }
}

// MARK: - Sample content

extension Profile {
    /// The profile in the design, with its four works.
    ///
    /// Only the first work carries real art. The other three are album covers in
    /// the design — unlicensed stand-ins per code.md §8 — so they get generated
    /// placeholders. The design's profile photo is an album cover too, so `photo`
    /// is left nil and the painterly default stands in, which is what the app does
    /// for anyone who hasn't uploaded one.
    static let sample = Profile(
        name: "Mateus Werneck",
        handle: "mwrnk",
        location: "Minas Gerais, Brazil",
        bio: "creative developer. i paint, listen to good music, and play video games.",
        worksCount: 12,
        followers: 1_200,
        following: 180,
        works: [
            .theOtherSideOffAFlower,
            Artwork(
                title: "Untitled",
                artist: "Mateus Werneck",
                handle: "mwrnk",
                size: CGSize(width: 60, height: 60),
                finish: .black,
                image: CGImage.softFieldGradient(
                    top: (0.55, 0.30, 0.68), bottom: (0.24, 0.13, 0.42)
                )
            ),
            Artwork(
                title: "Untitled",
                artist: "Mateus Werneck",
                handle: "mwrnk",
                size: CGSize(width: 60, height: 60),
                finish: .oak,
                image: CGImage.softFieldGradient(
                    top: (0.30, 0.42, 0.72), bottom: (0.12, 0.16, 0.38)
                )
            ),
            Artwork(
                title: "Untitled",
                artist: "Mateus Werneck",
                handle: "mwrnk",
                size: CGSize(width: 60, height: 60),
                finish: .black,
                image: CGImage.softFieldGradient(
                    top: (0.42, 0.52, 0.46), bottom: (0.18, 0.22, 0.24)
                )
            )
        ]
    )
}
