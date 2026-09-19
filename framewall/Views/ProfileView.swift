import SwiftUI

/// Profile screen — the artist, and a grid of their framed works.
/// (Figma `03 Profile`, 100:947)
///
/// code.md §4 calls the profile a room you curate rather than a grid you fill.
/// This is the grid form; Rooms (screen 7) is the curated one.
struct ProfileView: View {
    var profile: Profile = .sample

    @State private var isFollowing = false

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
        }
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
                    // The component's own guidance: View=Front for profile grids.
                    // At this size every measurement is exactly half the 360 pt
                    // component, which the static frame already handles by scaling.
                    StaticFramedArtwork(artwork: artwork)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Metrics.worksTop)
        .padding(.bottom, Metrics.worksBottom)
        .padding(.horizontal, Metrics.screenInset)
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
