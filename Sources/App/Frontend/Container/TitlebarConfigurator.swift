import SwiftUI

#if targetEnvironment(macCatalyst)
/// Hides the macOS window titlebar for the SwiftUI-hosted primary window, replicating what
/// `WebViewSceneDelegate` did before SwiftUI took ownership of this scene. Without it the window title
/// overlaps the WebView's custom status-bar buttons.
private struct TitlebarConfigurator: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView { TitlebarConfiguringView() }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

private final class TitlebarConfiguringView: UIView {
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard let titlebar = window?.windowScene?.titlebar else { return }
        // Disabling this also hides the window's "show tab bar" tab bar (matching WebViewSceneDelegate).
        titlebar.titleVisibility = .hidden
        titlebar.toolbar = nil
    }
}
#endif
