#if os(macOS)
import WebKit

extension WKWebView {
    /// AppKit's web view has no `isOpaque`; `drawsBackground` is the private setting that lets what is
    /// behind the view show through while a page loads. It is only set where WebKit still answers to it.
    func makeBackgroundTransparent() {
        guard responds(to: Selector(("setDrawsBackground:"))) else { return }
        setValue(false, forKey: "drawsBackground")
    }
}
#endif
