import SwiftUI

/// Profile screen — the artist, and a grid of their framed works.
/// (Figma `03 Profile`, 100:947)
///
/// code.md §4 calls the profile a room you curate rather than a grid you fill.
/// This is the grid form; Rooms (screen 7) is the curated one.
struct ProfileView: View {
    /// State rather than a constant so Edit Profile can write back to it.
    @State private var profile: Profile

    @State private var isFollowing = false

    /// Ties each grid tile to the viewer it opens, so the piece travels out of
    /// the grid rather than a new screen sliding over it.
    @Namespace private var hero
    /// The piece currently open in the viewer; `nil` is the profile itself.
    @State private var opened: Artwork.ID?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(profile: Profile = .sample) {
        _profile = State(initialValue: profile)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    header
                    works
                }
            }
            .navigationTitle(profile.handle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Not in the design: Figma's trailing toolbar slot holds only a
                // hidden placeholder, so this is the least intrusive way in.
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink("Edit") {
                        EditProfileView(profile: $profile)
                    }
                }
            }
        }
        // Outside the stack, so the viewer covers the navigation bar too.
        .overlay {
            if opened != nil {
                ArtworkView(
                    works: profile.works,
                    selection: $opened,
                    hero: hero,
                    close: { opened = nil }
                )
            }
        }
        .toolbarVisibility(opened == nil ? .automatic : .hidden, for: .tabBar)
    }

    // MARK: - Header

    /// Figma `Header` (102:1659): centred stack, 10 between every child,
    /// 20 above, 8 below, 24 either side.
    private var header: some View {
        VStack(spacing: Metrics.headerSpacing) {
            AvatarView(profile: profile)

            Text(profile.name)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            Text(profile.handleAndLocation)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text(profile.bio)
                .font(.body)
                .foregroundStyle(.primary)

            Text(profile.stats)
                .font(.footnote)
                .foregroundStyle(.secondary)

            followButton
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.top, Metrics.headerTop)
        .padding(.bottom, Metrics.headerBottom)
        .padding(.horizontal, Metrics.headerInset)
    }

    /// Figma `Follow` (102:1665): a Liquid Glass button, Glass Prominent style.
    /// The system supplies the material — nothing to hand-roll.
    private var followButton: some View {
        Button {
            isFollowing.toggle()
        } label: {
            Text(isFollowing ? "Following" : "Follow")
                .fontWeight(.semibold)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.regular)
    }

    // MARK: - Works

    /// Figma `Works` (103:400): section label, then a two-up grid of front-view
    /// frames. 140 of bottom padding clears the floating tab bar.
    private var works: some View {
        VStack(alignment: .leading, spacing: Metrics.worksSpacing) {
            Text("WORKS")
                .font(.footnote)
                .tracking(Metrics.sectionTracking)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Metrics.columns, spacing: Metrics.gridSpacing) {
                ForEach(profile.works) { artwork in
                    // The viewer swipes through the whole body of work, so it gets
                    // the full list and opens on the piece that was tapped.
                    Button {
                        // Not animated: the viewer runs the flight itself.
                        opened = artwork.id
                    } label: {
                        tile(for: artwork)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(artwork.title)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Metrics.worksTop)
        .padding(.bottom, Metrics.worksBottom)
        .padding(.horizontal, Metrics.screenInset)
    }

    /// One grid tile. The component's own guidance is View=Front for profile
    /// grids; at this size every measurement is exactly half the 360 pt
    /// component, which the static frame already handles by scaling.
    ///
    /// The square is held open by an empty view rather than by the piece, because
    /// the piece leaves the hierarchy while it is away being the hero — that
    /// departure is what gives `matchedGeometryEffect` something to animate from,
    /// and without the placeholder the grid would reflow under it.
    private func tile(for artwork: Artwork) -> some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                // Kept in place while away, transparent, as the frame the viewer's
                // travelling copy leaves from and lands back on. Under Reduce
                // Motion the viewer fades in over it instead, so it stays.
                StaticFramedArtwork(artwork: artwork, showsSticker: false)
                    .matchedGeometryEffect(id: ArtworkHero.tile(artwork.id), in: hero)
                    .opacity(opened == artwork.id && !reduceMotion ? 0 : 1)
            }
    }

    private enum Metrics {
        static let headerSpacing: CGFloat = 10
        static let headerTop: CGFloat = 20
        static let headerBottom: CGFloat = 8
        static let headerInset: CGFloat = 24

        static let worksSpacing: CGFloat = 10
        static let worksTop: CGFloat = 12
        static let worksBottom: CGFloat = 140
        static let screenInset: CGFloat = 16
        static let gridSpacing: CGFloat = 8

        /// "WORKS" is letterspaced in the design — 0.78 on a 13 pt footnote.
        static let sectionTracking: CGFloat = 0.78

        static let columns = [
            GridItem(.flexible(), spacing: gridSpacing),
            GridItem(.flexible(), spacing: gridSpacing)
        ]
    }
}

#Preview {
    ProfileView()
}
