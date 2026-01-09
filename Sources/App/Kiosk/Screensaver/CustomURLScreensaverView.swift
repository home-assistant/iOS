import Combine
import Shared
import SwiftUI
import WebKit

// MARK: - Custom URL Screensaver View

/// A screensaver that displays a custom URL (e.g., a custom HA dashboard) in a WebView
public struct CustomURLScreensaverView: View {
    @ObservedObject private var manager = KioskModeManager.shared
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var pixelShiftOffset: CGSize = .zero

    public init() {}

    public var body: some View {
        GeometryReader { _ in
            ZStack {
                // Background
                Color.black
                    .edgesIgnoringSafeArea(.all)

                // WebView content
                if let url = screensaverURL {
                    ScreensaverWebView(
                        url: url,
                        isLoading: $isLoading,
                        loadError: $loadError
                    )
                    .offset(pixelShiftOffset)
                    .edgesIgnoringSafeArea(.all)
                } else {
                    noURLConfiguredView
                }

                // Loading overlay
                if isLoading {
                    loadingOverlay
                }

                // Error overlay
                if let error = loadError {
                    errorOverlay(error)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .kioskPixelShiftTick)) { _ in
            applyPixelShift()
        }
    }

    private var screensaverURL: URL? {
        let urlString = manager.settings.screensaverCustomURL
        guard !urlString.isEmpty else { return nil }

        // If it's a relative path, construct full URL from server
        if urlString.hasPrefix("/") {
            if let server = Current.servers.all.first,
               let baseURL = server.info.connection.activeURL() {
                return URL(string: baseURL.absoluteString + urlString)
            }
        }

        return URL(string: urlString)
    }

    private var noURLConfiguredView: some View {
        VStack(spacing: 16) {
            Image(systemName: "globe")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.6))

            Text("No URL Configured")
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))

            Text("Set a custom URL in kiosk screensaver settings")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text("Loading...")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }

    private func errorOverlay(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Failed to Load")
                .font(.headline)
                .foregroundColor(.white)

            Text(message)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private func applyPixelShift() {
        guard manager.settings.pixelShiftEnabled else { return }

        let amount = manager.settings.pixelShiftAmount

        withAnimation(.easeInOut(duration: 1.0)) {
            pixelShiftOffset = CGSize(
                width: CGFloat.random(in: -amount...amount),
                height: CGFloat.random(in: -amount...amount)
            )
        }
    }
}

// MARK: - Screensaver WebView

/// A UIViewRepresentable wrapper for WKWebView optimized for screensaver display
struct ScreensaverWebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var loadError: String?

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // Disable user interaction for screensaver mode
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black

        // Disable scrolling and interactions
        webView.scrollView.isScrollEnabled = false
        webView.isUserInteractionEnabled = false

        // Hide scrollbars
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.showsVerticalScrollIndicator = false

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Only load if URL changed
        if webView.url != url {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: ScreensaverWebView

        init(_ parent: ScreensaverWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
                self.parent.loadError = nil
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.loadError = error.localizedDescription
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.loadError = error.localizedDescription
            }
        }
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview {
    CustomURLScreensaverView()
}
