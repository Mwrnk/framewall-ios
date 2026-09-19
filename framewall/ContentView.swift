import SwiftUI

/// Root of the app — tab navigation between the three main screens.
///
/// The glyphs are deliberately not the default house/plus/person: a framed picture
/// on a nail, a paintbrush, and a signature. (code.md §5, Figma `Tab Icon` 104:297)
/// They are vectors rather than SF Symbols, exported from the design and stored as
/// template images so the system tints them for selected and unselected states.
struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Feed", image: "TabIconFeed") {
                FeedView()
            }
            Tab("Post", image: "TabIconPost") {
                PostView()
            }
            Tab("Profile", image: "TabIconProfile") {
                ProfileView()
            }
        }
    }
}

#Preview {
    ContentView()
}
