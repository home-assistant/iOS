import SwiftUI
import WebKit

/// Renders an animated SVG bundled with the app inside a transparent, non-interactive
/// `WKWebView`. WebKit plays the document's CSS keyframe and SMIL animations natively,
/// which SVGKit cannot do. Used for the loading logo on `HomeAssistantStandByView`.
///
/// The view is vended by `AnimatedSVGWebViewCache`, which keeps it warm (preloaded at
/// launch) so it appears without WKWebView's cold-start delay. The SVG should declare a
/// `viewBox` so it scales to fill; the wrapper HTML forces it to 100% width/height on a
/// transparent background.
struct AnimatedSVGView: UIViewRepresentable {
    /// Name of the `.svg` resource in the main bundle (without extension).
    let resourceName: String

    func makeUIView(context: Context) -> WKWebView {
        AnimatedSVGWebViewCache.shared.webView(for: resourceName)
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

#Preview {
    AnimatedSVGView(resourceName: "home-assistant-logo-loading")
        .frame(width: 110, height: 110)
}
