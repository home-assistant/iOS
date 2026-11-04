import SwiftUI

/// Renders an animated SVG bundled with the app inside a transparent, non-interactive
/// `AnimatedSVGWebView`. WebKit plays the document's CSS keyframe and SMIL animations natively,
/// which SVGKit cannot do. Used for the loading logo on `HomeAssistantStandByView`.
///
/// The view is vended by `AnimatedSVGWebViewCache`, which keeps it warm (preloaded at launch) so it
/// appears without WKWebView's cold-start delay. The SVG should declare a `viewBox` so it scales to
/// fill; the wrapper HTML forces it to 100% width/height on a transparent background.
struct AnimatedSVGView: UIViewRepresentable {
    /// Name of the `.svg` resource in the main bundle (without extension).
    let resourceName: String

    func makeUIView(context: Context) -> AnimatedSVGWebView {
        AnimatedSVGWebViewCache.shared.webView(for: resourceName)
    }

    func updateUIView(_ uiView: AnimatedSVGWebView, context: Context) {
        // Another chance to catch a page WebKit stopped or reclaimed while it was off-screen; it
        // costs nothing when the animation is already running.
        uiView.resumeAnimationIfNeeded()
    }
}

#Preview {
    AnimatedSVGView(resourceName: "home-assistant-logo-loading")
        .frame(width: 110, height: 110)
}
