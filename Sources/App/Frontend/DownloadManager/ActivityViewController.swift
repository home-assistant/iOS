import Foundation
import Shared
import SwiftUI

struct ShareWrapper: Identifiable {
    let id = UUID()
    let url: URL
}

#if os(macOS)
/// A Mac shares from a menu attached to the control that opens it rather than from a sheet of its own, so
/// the sheet this is shown in names the file and offers that control.
struct ActivityViewController: View {
    @Environment(\.dismiss) private var dismiss

    let shareWrapper: ShareWrapper

    var body: some View {
        VStack(spacing: DesignSystem.Spaces.three) {
            Label(shareWrapper.url.lastPathComponent, systemSymbol: .doc)
                .lineLimit(1)
                .truncationMode(.middle)
            HStack(spacing: DesignSystem.Spaces.two) {
                Button(L10n.doneLabel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                ShareLink(item: shareWrapper.url)
            }
        }
        .padding(DesignSystem.Spaces.three)
    }
}

#Preview {
    ActivityViewController(shareWrapper: ShareWrapper(url: URL(fileURLWithPath: "/tmp/home-assistant.log")))
}
#else
struct ActivityViewController: UIViewControllerRepresentable {
    let shareWrapper: ShareWrapper
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [shareWrapper.url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
