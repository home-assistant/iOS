import SafariServices
import SwiftUI

#if os(macOS)
/// A Mac has no in-app Safari: the page opens in the default browser and the sheet this was presented
/// in closes again, which is what `SFSafariViewController` does under Mac Catalyst.
struct SafariWebView: View {
    let url: URL

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .task {
                openURL(url)
                dismiss()
            }
    }
}
#else
struct SafariWebView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
#endif
