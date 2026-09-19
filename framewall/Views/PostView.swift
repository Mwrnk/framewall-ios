import CoreGraphics
import ImageIO
import PhotosUI
import SwiftUI

/// New Post screen — live preview, frame picker, size picker, pinned Post button.
/// (Figma `04 New Post`, 100:962)
///
/// The preview is the real 3D frame rather than a thumbnail, so the piece is seen
/// as the object it will become before it is posted. (code.md §4)
struct PostView: View {
    @State private var finish: FrameFinish = .oak
    @State private var size: PostSize = .square
    @State private var image: CGImage?
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
                    preview
                    choosePhoto
                    framePicker
                    sizePicker
                }
                .padding(.horizontal, Metrics.screenInset)
                .padding(.bottom, Metrics.contentBottom)
            }
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) { postButton }
        }
        .task(id: pickerItem) { await loadPickedImage() }
    }

    /// The piece as it will appear, updating as the frame and shape change.
    private var draft: Artwork {
        Artwork(
            title: "",
            artist: "",
            size: size.physicalSize,
            finish: finish,
            image: image ?? CGImage.softFieldGradient()
        )
    }

    // MARK: - Preview

    /// Figma `Live preview` (103:452): 270 pt, centred — the perspective frame at
    /// three quarters of the component's size.
    private var preview: some View {
        FramedArtworkView(artwork: draft)
            .aspectRatio(1, contentMode: .fit)
            // Both bounds, not just the width: inside a ScrollView the height is
            // unbounded, so a width-only cap lets the scene claim whatever it likes.
            .frame(maxWidth: Metrics.preview, maxHeight: Metrics.preview)
            .frame(maxWidth: .infinity)
    }

    private var choosePhoto: some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            Text("Choose from Library")
                .font(.footnote)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
    }

    // MARK: - Frame

    /// Figma `Frame picker` (103:459).
    private var framePicker: some View {
        VStack(alignment: .leading, spacing: Metrics.labelSpacing) {
            SectionLabel("FRAME")

            HStack(spacing: Metrics.optionSpacing) {
                ForEach(FrameFinish.allCases) { option in
                    FrameOption(
                        finish: option,
                        artwork: draft,
                        isSelected: option == finish
                    ) {
                        finish = option
                    }
                }
            }
        }
    }

    // MARK: - Size

    /// Figma `Size picker` (104:354). The segmented control is the system one —
    /// iOS 26 already draws it as a capsule with a pill-shaped selection.
    private var sizePicker: some View {
        VStack(alignment: .leading, spacing: Metrics.labelSpacing) {
            SectionLabel("SIZE")

            Picker("Size", selection: $size) {
                ForEach(PostSize.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.small)
            .labelsHidden()

            Text(size.requirements)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Post

    /// code.md §3: the pinned primary button is 50 tall with 16 either side —
    /// a tighter inset than the 20 the content uses.
    private var postButton: some View {
        Button {
            // TODO: hand the draft to the upload flow (build step 2).
        } label: {
            Text("Post")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, minHeight: Metrics.postButtonHeight)
        }
        .buttonStyle(.glassProminent)
        .disabled(image == nil)
        .padding(.horizontal, Metrics.postButtonInset)
        .padding(.bottom, Metrics.labelSpacing)
    }

    private func loadPickedImage() async {
        guard let pickerItem else { return }
        guard
            let data = try? await pickerItem.loadTransferable(type: Data.self),
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let decoded = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return }
        image = decoded
    }

    private enum Metrics {
        /// Figma `Content`: 12 between sections, 20 either side, 40 below.
        static let sectionSpacing: CGFloat = 12
        static let screenInset: CGFloat = 20
        static let contentBottom: CGFloat = 40

        static let preview: CGFloat = 270
        static let labelSpacing: CGFloat = 8
        static let optionSpacing: CGFloat = 16

        static let postButtonHeight: CGFloat = 50
        static let postButtonInset: CGFloat = 16
    }
}

/// The letterspaced uppercase run-in used above each section.
private struct SectionLabel: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.footnote)
            .tracking(0.78)
            .foregroundStyle(.secondary)
    }
}

/// One choice in the frame picker: the piece at 108 pt with its finish's name,
/// ringed in the accent colour when selected. (Figma `Option Natural oak`, 103:462)
private struct FrameOption: View {
    let finish: FrameFinish
    let artwork: Artwork
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button {
            select()
        } label: {
            VStack(spacing: Metrics.spacing) {
                StaticFramedArtwork(artwork: preview)
                    .frame(width: Metrics.thumbnail, height: Metrics.thumbnail)

                Text(finish.displayName)
                    .font(.footnote)
                    .foregroundStyle(.primary)
                    .frame(width: Metrics.thumbnail, alignment: .leading)
            }
            .padding(Metrics.padding)
            .overlay {
                RoundedRectangle(cornerRadius: Metrics.cornerRadius)
                    .strokeBorder(
                        isSelected ? Color.accentColor : .clear,
                        lineWidth: Metrics.ringWidth
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(finish.displayName)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// The thumbnail shows the same painting in this option's finish, so the two
    /// sit side by side as a genuine comparison.
    private var preview: Artwork {
        var copy = artwork
        copy.finish = finish
        return copy
    }

    private enum Metrics {
        static let thumbnail: CGFloat = 108
        static let spacing: CGFloat = 2
        static let padding: CGFloat = 8
        static let cornerRadius: CGFloat = 14
        static let ringWidth: CGFloat = 2
    }
}

#Preview {
    PostView()
}
