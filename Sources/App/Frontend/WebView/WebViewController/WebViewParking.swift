import UIKit
import WebKit

/// Keeps a web view out of its window while nobody can see that window.
///
/// WebKit calls a page visible for as long as its web view is in a window of a scene in the foreground.
/// A Mac window that other windows cover completely keeps its scene in the foreground, so its page goes
/// on rendering every frame and running its timers at full rate. A web view that is in no window has a
/// hidden page instead: no frames, timers once a second, and a frontend that closes its connection to
/// the server after five minutes. Hiding the web view does not do that, only taking it out of the
/// window does.
@MainActor
final class WebViewParking {
    typealias TimerScheduler = @MainActor (TimeInterval, @escaping @MainActor () -> Void) -> () -> Void

    /// Long enough that switching to another app and back does not park anything, and short next to the
    /// minutes and hours a covered window stays covered.
    static let defaultDelay: TimeInterval = 30

    private let delay: TimeInterval
    private let scheduleTimer: TimerScheduler

    private(set) var isParked: Bool = false
    private var cancelTimer: (() -> Void)?
    private var index: Int = 0
    private var hadFirstResponder: Bool = false

    init(
        delay: TimeInterval = WebViewParking.defaultDelay,
        scheduleTimer: @escaping TimerScheduler = WebViewParking.defaultScheduleTimer
    ) {
        self.delay = delay
        self.scheduleTimer = scheduleTimer
    }

    deinit {
        cancelTimer?()
    }

    /// Runs `action` after the delay, unless `cancelScheduled()` comes first. One at a time: asking again
    /// while one is pending, or while the web view is parked, changes nothing.
    func schedule(_ action: @escaping @MainActor () -> Void) {
        guard !isParked, cancelTimer == nil else { return }
        cancelTimer = scheduleTimer(delay) { [weak self] in
            self?.cancelTimer = nil
            action()
        }
    }

    func cancelScheduled() {
        cancelTimer?()
        cancelTimer = nil
    }

    /// Takes `webView` out of its superview.
    /// - Returns: Whether this call took the web view out. One that is in no view cannot be parked.
    @discardableResult
    func park(_ webView: WKWebView) -> Bool {
        guard !isParked, let container = webView.superview else { return false }
        isParked = true
        index = container.subviews.firstIndex(of: webView) ?? 0
        // Leaving the window costs the web view the keyboard, and nothing gives it back on its own.
        hadFirstResponder = webView.containsFirstResponder
        webView.removeFromSuperview()
        return true
    }

    /// Puts `webView` back where `park(_:)` took it from. Constraints between the web view and its
    /// siblings went with it, and are the caller's to restore.
    /// - Returns: Whether this call put the web view back.
    @discardableResult
    func unpark(_ webView: WKWebView, into container: UIView) -> Bool {
        guard isParked else { return false }
        isParked = false
        container.insertSubview(webView, at: min(index, container.subviews.count))
        if hadFirstResponder {
            webView.becomeFirstResponder()
        }
        return true
    }

    private static func defaultScheduleTimer(
        delay: TimeInterval,
        action: @escaping @MainActor () -> Void
    ) -> () -> Void {
        // On the main run loop, so the action runs as the timer fires: one that is queued instead could
        // still run after its timer was cancelled.
        let timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            MainActor.assumeIsolated {
                action()
            }
        }
        return {
            timer.invalidate()
        }
    }
}

private extension UIView {
    var containsFirstResponder: Bool {
        isFirstResponder || subviews.contains { $0.containsFirstResponder }
    }
}
