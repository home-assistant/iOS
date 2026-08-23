import UIKit
import WebKit

@MainActor
final class HomeAssistantPullToRefreshObserver: NSObject {
    private enum Constants {
        static let hapticStepCount = 8
        static let minimumHapticIntensity: CGFloat = 0.35
        /// UIScrollView's rubber-banding resists proportionally to the scroll view's height, so a fixed
        /// threshold tuned for portrait needs an impossible single swipe on a short landscape viewport.
        /// Scaling with the height keeps the required finger travel at a constant fraction of the screen.
        static let thresholdHeightFraction: CGFloat = 0.2
        static let minimumThreshold: CGFloat = 64
        /// Horizontal travel that means this pan is a canvas/map drag, not a page-level pull.
        static let substantialHorizontalDistance: CGFloat = 24
        static let atTopTolerance: CGFloat = 1
        static let scrollableContentTolerance: CGFloat = 1
    }

    private weak var scrollView: UIScrollView?
    private weak var loadingWebView: WKWebView?
    private let maximumThreshold: CGFloat
    private let onStateChange: (CGFloat, Bool) -> Void
    private let onRefresh: () -> Void

    private let progressFeedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    private let refreshFeedbackGenerator = UINotificationFeedbackGenerator()
    private var contentOffsetObservation: NSKeyValueObservation?
    private var contentSizeObservation: NSKeyValueObservation?
    private var isLoadingObservation: NSKeyValueObservation?
    private var isRefreshing = false
    private var didCrossThreshold = false
    private var lastHapticProgressStep: Int?
    /// Pan began with the web view already at rest at the top, and is a page-level pull rather than an
    /// in-page canvas/map drag.
    private var isTrackingEligiblePull = false
    private var panBeganAtTop = false
    /// Read from the scroll-view KVO callback, which is not isolated to the main actor.
    private nonisolated(unsafe) var isResettingOffset = false
    private var lastPublishedProgress: CGFloat = 0
    private var lastPublishedIsRefreshing = false

    convenience init(
        webView: WKWebView,
        maximumThreshold: CGFloat,
        onStateChange: @escaping (CGFloat, Bool) -> Void,
        onRefresh: @escaping () -> Void
    ) {
        self.init(
            scrollView: webView.scrollView,
            loadingWebView: webView,
            maximumThreshold: maximumThreshold,
            onStateChange: onStateChange,
            onRefresh: onRefresh
        )
    }

    /// Testable entry point that can be driven with a fake `UIScrollView`.
    init(
        scrollView: UIScrollView,
        loadingWebView: WKWebView? = nil,
        maximumThreshold: CGFloat,
        onStateChange: @escaping (CGFloat, Bool) -> Void,
        onRefresh: @escaping () -> Void
    ) {
        self.scrollView = scrollView
        self.loadingWebView = loadingWebView
        self.maximumThreshold = maximumThreshold
        self.onStateChange = onStateChange
        self.onRefresh = onRefresh

        super.init()

        progressFeedbackGenerator.prepare()
        refreshFeedbackGenerator.prepare()

        scrollView.bounces = true
        updateVerticalBounce()
        scrollView.panGestureRecognizer.addTarget(self, action: #selector(handlePanGesture(_:)))
        self.contentOffsetObservation = scrollView
            .observe(\.contentOffset, options: [.new]) { [weak self] scrollView, _ in
                // Skip before the MainActor hop: `resetScrollPosition()` clears `isResettingOffset`
                // immediately after `setContentOffset`, so a deferred Task would still see the
                // synthetic offset and republish progress.
                if self?.isResettingOffset == true { return }
                let offset = scrollView.contentOffset
                Task { @MainActor in
                    guard let self, !self.isResettingOffset else { return }
                    self.handleContentOffset(offset)
                }
            }
        self.contentSizeObservation = scrollView
            .observe(\.contentSize, options: [.new]) { [weak self] _, _ in
                Task { @MainActor in
                    self?.updateVerticalBounce()
                }
            }
        if let loadingWebView {
            self.isLoadingObservation = loadingWebView
                .observe(\.isLoading, options: [.new]) { [weak self] webView, _ in
                    guard !webView.isLoading else { return }
                    Task { @MainActor in
                        self?.finishRefreshing()
                    }
                }
        }
    }

    deinit {
        contentOffsetObservation?.invalidate()
        contentSizeObservation?.invalidate()
        isLoadingObservation?.invalidate()
        MainActor.assumeIsolated {
            scrollView?.panGestureRecognizer.removeTarget(self, action: #selector(handlePanGesture(_:)))
        }
    }

    func finishRefreshing() {
        isRefreshing = false
        didCrossThreshold = false
        lastHapticProgressStep = nil
        isTrackingEligiblePull = false
        panBeganAtTop = false
        progressFeedbackGenerator.prepare()
        refreshFeedbackGenerator.prepare()
        // A leftover negative offset after reload is the stuck gap that intercepts hits (#5432).
        resetScrollPosition()
        updateVerticalBounce()
        publish(progress: 0, isRefreshing: false)
    }

    /// Recomputed on every read so rotating the device immediately adopts the new viewport's threshold.
    private var currentThreshold: CGFloat {
        guard let scrollView, scrollView.bounds.height > 0 else { return maximumThreshold }
        let heightBased = scrollView.bounds.height * Constants.thresholdHeightFraction
        return min(maximumThreshold, max(Constants.minimumThreshold, heightBased))
    }

    func handleContentOffset(_ contentOffset: CGPoint) {
        guard let scrollView, !isResettingOffset else { return }

        updateVerticalBounce()

        let topInset = scrollView.adjustedContentInset.top
        let pullDistance = max(0, -(contentOffset.y + topInset))
        let progress = min(1, pullDistance / currentThreshold)

        if isRefreshing { return }

        let isActivelyDragging = scrollView.isDragging || scrollView.isTracking
        if !isActivelyDragging {
            clearLeftoverProgressIfNeeded(pullDistance: pullDistance, isDecelerating: scrollView.isDecelerating)
            return
        }

        guard isTrackingEligiblePull else {
            publish(progress: 0, isRefreshing: false)
            return
        }

        emitPullProgressHapticIfNeeded(progress: progress, pullDistance: pullDistance)
        didCrossThreshold = didCrossThreshold || progress >= 1
        publish(progress: progress, isRefreshing: false)

        if pullDistance == 0 {
            didCrossThreshold = false
            lastHapticProgressStep = nil
            progressFeedbackGenerator.prepare()
        }
    }

    func handlePan(state: UIGestureRecognizer.State, locationInView: CGPoint, translation: CGPoint) {
        switch state {
        case .began:
            beginTracking(locationInView: locationInView)
        case .changed:
            updateTracking(translation: translation)
        case .ended:
            endTracking(translation: translation)
        case .cancelled, .failed:
            cancelTracking()
        default:
            break
        }
    }

    private func beginTracking(locationInView: CGPoint) {
        panBeganAtTop = isAtTop
        let beganInTopSafeArea = isInTopSafeArea(locationInView)
        // PTR is a page-level pull from rest at the top: either from the status-bar/safe-area region, or
        // the scroll view rubber-banding because the document itself can scroll. Middle-of-screen drags
        // on a non-scrolling canvas (Zigbee mesh, maps) must not qualify.
        isTrackingEligiblePull = panBeganAtTop && (beganInTopSafeArea || canScrollVertically)
        didCrossThreshold = false
        lastHapticProgressStep = nil
        if !isTrackingEligiblePull {
            publish(progress: 0, isRefreshing: false)
        }
        updateVerticalBounce()
    }

    private func updateTracking(translation: CGPoint) {
        guard isTrackingEligiblePull, !isRefreshing else { return }
        guard hasSubstantialHorizontalMovement(translation) else { return }
        isTrackingEligiblePull = false
        didCrossThreshold = false
        publish(progress: 0, isRefreshing: false)
        updateVerticalBounce()
    }

    private func endTracking(translation: CGPoint) {
        let shouldRefresh = shouldStartRefresh(translation: translation)
        isTrackingEligiblePull = false
        if shouldRefresh {
            startRefresh()
        } else {
            didCrossThreshold = false
        }
        updateVerticalBounce()
    }

    private func cancelTracking() {
        isTrackingEligiblePull = false
        didCrossThreshold = false
        lastHapticProgressStep = nil
        panBeganAtTop = false
        if !isRefreshing {
            publish(progress: 0, isRefreshing: false)
        }
        updateVerticalBounce()
    }

    private func shouldStartRefresh(translation: CGPoint) -> Bool {
        isTrackingEligiblePull
            && panBeganAtTop
            && didCrossThreshold
            && currentPullDistance() >= currentThreshold
            && !isRefreshing
            && isPrimarilyVertical(translation)
            && !hasSubstantialHorizontalMovement(translation)
    }

    private func startRefresh() {
        isRefreshing = true
        didCrossThreshold = false
        lastHapticProgressStep = nil
        refreshFeedbackGenerator.notificationOccurred(.success)
        refreshFeedbackGenerator.prepare()
        resetScrollPosition()
        publish(progress: 1, isRefreshing: true)
        onRefresh()
    }

    private func clearLeftoverProgressIfNeeded(pullDistance: CGFloat, isDecelerating: Bool) {
        guard pullDistance > 0 || lastPublishedProgress > 0 || didCrossThreshold else { return }
        publish(progress: 0, isRefreshing: false)
        didCrossThreshold = false
        lastHapticProgressStep = nil
        progressFeedbackGenerator.prepare()
        // A bounce-back animation is allowed to settle; a parked negative offset is the stuck gap.
        if pullDistance > 0, !isDecelerating {
            resetScrollPosition()
        }
    }

    private func emitPullProgressHapticIfNeeded(progress: CGFloat, pullDistance: CGFloat) {
        guard pullDistance > 0 else { return }

        let step = Int((progress * CGFloat(Constants.hapticStepCount)).rounded(.down))
        guard step != lastHapticProgressStep else { return }

        if lastHapticProgressStep != nil {
            progressFeedbackGenerator.impactOccurred(intensity: max(Constants.minimumHapticIntensity, progress))
            progressFeedbackGenerator.prepare()
        }
        lastHapticProgressStep = step
    }

    private func currentPullDistance() -> CGFloat {
        guard let scrollView else { return 0 }
        return max(0, -(scrollView.contentOffset.y + scrollView.adjustedContentInset.top))
    }

    private var isAtTop: Bool {
        guard let scrollView else { return false }
        return scrollView.contentOffset.y <= -scrollView.adjustedContentInset.top + Constants.atTopTolerance
    }

    private var canScrollVertically: Bool {
        guard let scrollView, scrollView.bounds.height > 0 else { return false }
        let visibleHeight = scrollView.bounds.height
            - scrollView.adjustedContentInset.top
            - scrollView.adjustedContentInset.bottom
        return scrollView.contentSize.height > visibleHeight + Constants.scrollableContentTolerance
    }

    private func currentTopSafeAreaHeight() -> CGFloat {
        if let loadingWebView, loadingWebView.safeAreaInsets.top > 0 {
            return loadingWebView.safeAreaInsets.top
        }
        return scrollView?.safeAreaInsets.top ?? 0
    }

    private func isInTopSafeArea(_ locationInView: CGPoint) -> Bool {
        locationInView.y <= currentTopSafeAreaHeight()
    }

    private func isPrimarilyVertical(_ translation: CGPoint) -> Bool {
        abs(translation.y) > abs(translation.x)
    }

    private func hasSubstantialHorizontalMovement(_ translation: CGPoint) -> Bool {
        abs(translation.x) >= Constants.substantialHorizontalDistance
            && abs(translation.x) >= abs(translation.y) * 0.5
    }

    private func visibleLocation(from recognizer: UIPanGestureRecognizer) -> CGPoint {
        guard let scrollView else { return recognizer.location(in: nil) }
        let location = recognizer.location(in: scrollView)
        return CGPoint(
            x: location.x - scrollView.bounds.origin.x,
            y: location.y - scrollView.bounds.origin.y
        )
    }

    private func updateVerticalBounce() {
        guard let scrollView else { return }
        scrollView.bounces = true
        // Do not force bounce on short / inner-scrolling frontend pages; that makes canvas drags
        // rubber-band the whole web view and is the aggressive overscroll in #5385 / #5320.
        scrollView.alwaysBounceVertical = canScrollVertically || isTrackingEligiblePull || isRefreshing
    }

    private func resetScrollPosition() {
        guard let scrollView else { return }
        let restingY = -scrollView.adjustedContentInset.top
        // Only snap out of an overscrolled-at-top offset. Never yank a user who has scrolled into
        // the document, even if `finishRefreshing` runs after an unrelated load.
        guard scrollView.contentOffset.y < restingY - 0.5 else { return }
        isResettingOffset = true
        UIView.performWithoutAnimation {
            scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: restingY), animated: false)
            scrollView.layoutIfNeeded()
        }
        isResettingOffset = false
    }

    private func publish(progress: CGFloat, isRefreshing: Bool) {
        guard progress != lastPublishedProgress || isRefreshing != lastPublishedIsRefreshing else { return }
        lastPublishedProgress = progress
        lastPublishedIsRefreshing = isRefreshing
        onStateChange(progress, isRefreshing)
    }

    @objc private func handlePanGesture(_ recognizer: UIPanGestureRecognizer) {
        handlePan(
            state: recognizer.state,
            locationInView: visibleLocation(from: recognizer),
            translation: recognizer.translation(in: scrollView)
        )
    }
}
