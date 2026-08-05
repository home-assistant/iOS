import Shared
import UIKit
import WebKit

/// A transparent, non-interactive `WKWebView` that renders an animated SVG bundled with the app and
/// keeps it animating. WebKit plays the document's CSS keyframe and SMIL animations natively, which
/// SVGKit cannot do.
///
/// Keeping it animating is the hard part. The instance vended by `AnimatedSVGWebViewCache` is
/// preloaded off-screen at launch and is unparented again every time the loading logo goes away, and
/// WebKit does not keep an off-screen page running: it pauses the page's animations, and it may
/// suspend or terminate the web content process backing the view. That leaves the document frozen
/// mid-loop, stalled mid-load, or blank — and none of those states recover on their own. Because the
/// loading logo draws a pixel-identical static logo behind this view, they all look the same to the
/// user: a logo that simply does not animate. It shows up most on a cold launch over a slow
/// connection, where the loader stays up long enough to notice and the busier launch makes WebKit
/// more likely to suspend or reclaim the off-screen page in the first place.
///
/// So the view re-checks itself whenever it is attached to a window or the app returns to the
/// foreground: it resumes animations that are not running and reloads the document when the page is
/// gone. A watchdog covers loads that never finish, since a load interrupted by process suspension
/// neither completes nor fails.
final class AnimatedSVGWebView: WKWebView {
    private enum State {
        /// A load is in flight and the watchdog is armed.
        case loading
        /// The document finished loading; its animations may still need resuming.
        case loaded
        /// The load failed or stalled, or its web content process died — only a fresh load recovers.
        case needsReload
    }

    /// How long a load may take before it counts as stalled. Generous enough for a cold launch
    /// spinning up WebKit, short enough that a stuck logo heals while the loader is still on screen.
    private static let loadTimeout: Duration = .seconds(2)
    /// Stops a document that cannot render (missing resource, repeatedly crashing content process)
    /// from reloading forever behind the loading logo. Reset once the document is confirmed animating.
    private static let maximumConsecutiveLoads = 3

    /// Name of the `.svg` resource in the main bundle (without extension).
    let resourceName: String

    private var state: State = .needsReload
    private var consecutiveLoads = 0
    private var loadWatchdog: Task<Void, Never>?

    init(resourceName: String) {
        self.resourceName = resourceName
        super.init(frame: .zero, configuration: WKWebViewConfiguration())
        isOpaque = false
        backgroundColor = .clear
        scrollView.backgroundColor = .clear
        scrollView.isScrollEnabled = false
        // Let taps fall through to the logo dismiss gesture behind the view.
        isUserInteractionEnabled = false
        navigationDelegate = self
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        load()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        resumeAnimationIfNeeded()
    }

    /// Gets the document animating again now that it can be seen. Safe to call repeatedly: a running
    /// animation is left untouched, so this never restarts a healthy loop from its first frame.
    func resumeAnimationIfNeeded() {
        guard window != nil else { return }
        switch state {
        case .loading:
            // A load that stalled off-screen never fails, so give it a deadline rather than
            // restarting a load that may be one frame away from painting.
            startLoadWatchdog()
        case .loaded:
            Task { await resumeAnimation() }
        case .needsReload:
            load()
        }
    }

    private func resumeAnimation() async {
        do {
            let hasAnimations = try await evaluateJavaScript(Self.resumeAnimationsScript) as? Bool
            if hasAnimations == true {
                // Confirmed animating: whatever it took to get here worked, so the retry budget is
                // free again for the next time WebKit stops the page.
                consecutiveLoads = 0
                return
            }
            // The page answered but has nothing to animate: the SVG never parsed, or the document
            // was replaced.
            Current.Log.error("Animated SVG \(resourceName) has no animations to resume, reloading")
            load()
        } catch {
            // Evaluation fails outright when the web content process is gone: the page is blank and
            // only a fresh load brings it back.
            let reason = error.localizedDescription
            Current.Log.error("Animated SVG \(resourceName) failed to resume (\(reason)), reloading")
            load()
        }
    }

    /// (Re)loads the bundled SVG document. Also used as the recovery path, since a page whose content
    /// process died cannot be revived any other way.
    private func load() {
        guard consecutiveLoads < Self.maximumConsecutiveLoads else {
            Current.Log.error("Giving up on animated SVG \(resourceName) after \(consecutiveLoads) failed loads")
            return
        }
        guard
            let url = Bundle.main.url(forResource: resourceName, withExtension: "svg"),
            let svg = try? String(contentsOf: url, encoding: .utf8) else {
            state = .needsReload
            Current.Log.error("Missing or unreadable animated SVG resource \(resourceName).svg")
            return
        }
        consecutiveLoads += 1
        state = .loading
        loadHTMLString(Self.html(embedding: svg), baseURL: Bundle.main.bundleURL)
        startLoadWatchdog()
    }

    /// WebKit suspends — and under memory pressure terminates — the web content process of a view
    /// that is not on screen, which is exactly where the preloaded instance waits between launch and
    /// the loading logo appearing. A load interrupted that way neither finishes nor fails, so only a
    /// timeout notices it.
    private func startLoadWatchdog() {
        loadWatchdog?.cancel()
        loadWatchdog = Task { [weak self] in
            try? await Task.sleep(for: Self.loadTimeout)
            guard !Task.isCancelled, let self, state == .loading else { return }
            Current.Log.error("Animated SVG \(resourceName) did not finish loading in time")
            markNeedsReload()
        }
    }

    private func markNeedsReload() {
        loadWatchdog?.cancel()
        state = .needsReload
        // Reloading off-screen would only stall again; the next attach picks it up.
        guard window != nil else { return }
        load()
    }

    @objc private func applicationWillEnterForeground() {
        // WebKit is free to reclaim the page while the app is backgrounded, so never assume the
        // document that was animating at suspension is still there.
        resumeAnimationIfNeeded()
    }

    /// Resumes every animation the document is not currently running, and reports whether it has any
    /// animations at all — an empty list means there is no SVG left to animate.
    private static let resumeAnimationsScript = """
    (function() {
        var animations = document.getAnimations ? document.getAnimations() : [];
        animations.forEach(function(animation) {
            if (animation.playState !== 'running') {
                animation.play();
            }
        });
        return animations.length > 0;
    })()
    """

    private static func html(embedding svg: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
        <style>
        html, body { margin: 0; padding: 0; height: 100%; width: 100%; background: transparent; overflow: hidden; }
        body { display: flex; align-items: center; justify-content: center; }
        svg { width: 100%; height: 100%; display: block; }
        </style>
        </head>
        <body>
        \(svg)
        </body>
        </html>
        """
    }
}

extension AnimatedSVGWebView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadWatchdog?.cancel()
        state = .loaded
        // The document may have loaded while the page was hidden, which leaves its animations
        // paused; this is a no-op when they are already running.
        resumeAnimationIfNeeded()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Current.Log.error("Animated SVG \(resourceName) failed to load: \(error.localizedDescription)")
        markNeedsReload()
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        Current.Log.error("Animated SVG \(resourceName) failed provisional load: \(error.localizedDescription)")
        markNeedsReload()
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        Current.Log.error("Animated SVG \(resourceName) web content process terminated")
        markNeedsReload()
    }
}
