import UIKit

@MainActor
final class HomeAssistantPullToRefreshObserver: NSObject {
    private weak var scrollView: UIScrollView?
    private let threshold: CGFloat
    private let onStateChange: (CGFloat, Bool) -> Void
    private let onRefresh: () -> Void

    private var contentOffsetObservation: NSKeyValueObservation?
    private var isRefreshing = false
    private var didCrossThreshold = false

    init(
        scrollView: UIScrollView,
        threshold: CGFloat,
        onStateChange: @escaping (CGFloat, Bool) -> Void,
        onRefresh: @escaping () -> Void
    ) {
        self.scrollView = scrollView
        self.threshold = threshold
        self.onStateChange = onStateChange
        self.onRefresh = onRefresh

        super.init()

        scrollView.bounces = true
        scrollView.alwaysBounceVertical = true
        scrollView.panGestureRecognizer.addTarget(self, action: #selector(handlePanGesture(_:)))
        contentOffsetObservation = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] scrollView, _ in
            Task { @MainActor in
                self?.handleContentOffset(scrollView.contentOffset)
            }
        }
    }

    deinit {
        contentOffsetObservation?.invalidate()
    }

    func finishRefreshing() {
        guard isRefreshing else { return }
        isRefreshing = false
        didCrossThreshold = false
        onStateChange(0, false)
    }

    private func handleContentOffset(_ contentOffset: CGPoint) {
        guard let scrollView else { return }

        let topInset = scrollView.adjustedContentInset.top
        let pullDistance = max(0, -(contentOffset.y + topInset))
        let progress = min(1, pullDistance / threshold)

        if !isRefreshing {
            didCrossThreshold = didCrossThreshold || progress >= 1
            onStateChange(progress, false)
        }

        if pullDistance == 0, !isRefreshing {
            didCrossThreshold = false
        }
    }

    @objc private func handlePanGesture(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .ended, .cancelled, .failed:
            guard didCrossThreshold, !isRefreshing else {
                didCrossThreshold = false
                return
            }
            isRefreshing = true
            onStateChange(1, true)
            onRefresh()
        default:
            break
        }
    }
}
