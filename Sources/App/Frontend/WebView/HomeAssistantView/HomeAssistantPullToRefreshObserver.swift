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
    }

    private weak var scrollView: UIScrollView?
    private let maximumThreshold: CGFloat
    private let onStateChange: (CGFloat, Bool) -> Void
    private let onRefresh: () -> Void

    private let progressFeedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    private let refreshFeedbackGenerator = UINotificationFeedbackGenerator()
    private var contentOffsetObservation: NSKeyValueObservation?
    private var isLoadingObservation: NSKeyValueObservation?
    private var isRefreshing = false
    private var didCrossThreshold = false
    private var lastHapticProgressStep: Int?

    init(
        webView: WKWebView,
        maximumThreshold: CGFloat,
        onStateChange: @escaping (CGFloat, Bool) -> Void,
        onRefresh: @escaping () -> Void
    ) {
        self.scrollView = webView.scrollView
        self.maximumThreshold = maximumThreshold
        self.onStateChange = onStateChange
        self.onRefresh = onRefresh

        super.init()

        progressFeedbackGenerator.prepare()
        refreshFeedbackGenerator.prepare()

        let scrollView = webView.scrollView
        scrollView.bounces = true
        scrollView.alwaysBounceVertical = true
        scrollView.panGestureRecognizer.addTarget(self, action: #selector(handlePanGesture(_:)))
        self.contentOffsetObservation = scrollView
            .observe(\.contentOffset, options: [.new]) { [weak self] scrollView, _ in
                Task { @MainActor in
                    self?.handleContentOffset(scrollView.contentOffset)
                }
            }
        self.isLoadingObservation = webView
            .observe(\.isLoading, options: [.new]) { [weak self] webView, _ in
                guard !webView.isLoading else { return }
                Task { @MainActor in
                    self?.finishRefreshing()
                }
            }
    }

    deinit {
        contentOffsetObservation?.invalidate()
        isLoadingObservation?.invalidate()
        MainActor.assumeIsolated {
            scrollView?.panGestureRecognizer.removeTarget(self, action: #selector(handlePanGesture(_:)))
        }
    }

    func finishRefreshing() {
        guard isRefreshing else { return }
        isRefreshing = false
        didCrossThreshold = false
        lastHapticProgressStep = nil
        progressFeedbackGenerator.prepare()
        refreshFeedbackGenerator.prepare()
        onStateChange(0, false)
    }

    /// Recomputed on every read so rotating the device immediately adopts the new viewport's threshold.
    private var currentThreshold: CGFloat {
        guard let scrollView, scrollView.bounds.height > 0 else { return maximumThreshold }
        let heightBased = scrollView.bounds.height * Constants.thresholdHeightFraction
        return min(maximumThreshold, max(Constants.minimumThreshold, heightBased))
    }

    private func handleContentOffset(_ contentOffset: CGPoint) {
        guard let scrollView else { return }

        let topInset = scrollView.adjustedContentInset.top
        let pullDistance = max(0, -(contentOffset.y + topInset))
        let progress = min(1, pullDistance / currentThreshold)

        if !isRefreshing {
            emitPullProgressHapticIfNeeded(progress: progress, pullDistance: pullDistance)
            didCrossThreshold = didCrossThreshold || progress >= 1
            onStateChange(progress, false)
        }

        if pullDistance == 0, !isRefreshing {
            didCrossThreshold = false
            lastHapticProgressStep = nil
            progressFeedbackGenerator.prepare()
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

    private func resetScrollPosition() {
        guard let scrollView else { return }
        let restingOffset = CGPoint(x: scrollView.contentOffset.x, y: -scrollView.adjustedContentInset.top)
        UIView.performWithoutAnimation {
            scrollView.setContentOffset(restingOffset, animated: false)
            scrollView.layoutIfNeeded()
        }
    }

    @objc private func handlePanGesture(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .ended:
            guard didCrossThreshold, currentPullDistance() >= currentThreshold, !isRefreshing else {
                didCrossThreshold = false
                return
            }
            isRefreshing = true
            didCrossThreshold = false
            lastHapticProgressStep = nil
            refreshFeedbackGenerator.notificationOccurred(.success)
            refreshFeedbackGenerator.prepare()
            resetScrollPosition()
            onStateChange(1, true)
            onRefresh()
        case .cancelled, .failed:
            didCrossThreshold = false
        default:
            break
        }
    }
}
