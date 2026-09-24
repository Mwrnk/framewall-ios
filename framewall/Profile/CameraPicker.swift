import SwiftUI
import UIKit

/// The system camera, for taking a profile photo in Edit Profile.
///
/// SwiftUI has no camera picker of its own (checked against the iOS 27 SDK), so
/// this wraps `UIImagePickerController`. The painting scanner (build step 2) is a
/// different job — VisionKit's document camera — and does not share this.
struct CameraPicker: UIViewControllerRepresentable {
    let onCapture: (CGImage) -> Void

    @Environment(\.dismiss) private var dismiss

    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraDevice = .front
        // The system's square crop, so the photo is framed for the circle it lands in.
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var parent: CameraPicker

        init(parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage
            if let photo = image?.uprightAvatar() {
                parent.onCapture(photo)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

extension UIImage {
    /// Redrawn upright and downsized. A camera `UIImage` keeps its rotation in
    /// `imageOrientation`, which its raw `cgImage` drops — without the redraw a
    /// portrait photo lands on its side.
    func uprightAvatar(maxPixelSize: CGFloat = ProfilePhoto.maxPixelSize) -> CGImage? {
        let longest = max(size.width, size.height)
        guard longest > 0 else { return nil }
        let scale = min(1, maxPixelSize / longest)
        let target = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format)
            .image { _ in draw(in: CGRect(origin: .zero, size: target)) }
            .cgImage
    }
}

enum ProfilePhoto {
    /// The largest avatar is 96 pt — 288 px at 3x. Twice that leaves room for
    /// zoomed displays without keeping a 12 MP photo in memory.
    static let maxPixelSize: CGFloat = 600
}
