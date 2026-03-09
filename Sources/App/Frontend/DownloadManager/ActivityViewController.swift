import Foundation
import SwiftUI

struct ShareWrapper: Identifiable {
    let id = UUID()
    let url: URL
}

struct ActivityViewController: UIViewControllerRepresentable {
    let shareWrapper: ShareWrapper
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [shareWrapper.url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
