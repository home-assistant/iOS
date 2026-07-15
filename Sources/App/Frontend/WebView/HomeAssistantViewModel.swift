import Combine
import Shared
import SwiftUI
import UIKit

@MainActor
final class HomeAssistantViewModel: ObservableObject {
    private enum Constants {
        static let minimumLoaderDuration: Duration = .seconds(1.8)
        static let loaderFadeOutDuration: Duration = .seconds(0.4)
    }

    let server: Server
    let overlayState: WebFrontendOverlayState
    let chrome: WebViewChromeState
    let reconnectManager: WebViewReconnectManager

    @Published var webViewResetID = UUID()
    @Published var webViewController: WebViewController?
    @Published var contentOpacity: Double = 0
    @Published var isFullScreenLoaderMounted = true
    @Published var isFullScreenLoaderVisible = true
    @Published var loaderMinimumDurationElapsed = false

    private let onWebViewController: ((WebViewController) -> Void)?
    private var loaderCycleID = UUID()
    private var loaderMinimumDurationTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init(
        server: Server,
        overlayState: WebFrontendOverlayState? = nil,
        chrome: WebViewChromeState? = nil,
        reconnectManager: WebViewReconnectManager? = nil,
        onWebViewController: ((WebViewController) -> Void)? = nil
    ) {
        self.server = server
        self.overlayState = overlayState ?? WebFrontendOverlayState()
        self.chrome = chrome ?? WebViewChromeState()
        self.reconnectManager = reconnectManager ?? WebViewReconnectManager()
        self.onWebViewController = onWebViewController

        bindObservableChildren()
        bindOverlayState()
    }

    deinit {
        loaderMinimumDurationTask?.cancel()
    }

    var webViewIgnoredSafeAreaEdges: Edge.Set {
        overlayState.statusBarColor == nil ? .all : [.horizontal, .bottom]
    }

    var shouldShowStandByView: Bool {
        isFullScreenLoaderMounted || overlayState.emptyState != nil
    }

    var displayedEmptyState: WebFrontendOverlayState.EmptyStateContent? {
        guard let emptyState = overlayState.emptyState else { return nil }
        guard isFullScreenLoaderMounted else { return emptyState }
        return loaderMinimumDurationElapsed ? emptyState : nil
    }

    var standByOpacity: Double {
        overlayState.emptyState == nil && !isFullScreenLoaderVisible ? 0 : 1
    }

    func fade(to opacity: Double, reduceMotion: Bool) {
        guard !reduceMotion else {
            contentOpacity = opacity
            return
        }
        withAnimation(DesignSystem.Animation.easeInOutSlower) {
            contentOpacity = opacity
        }
    }

    func disappear(reduceMotion: Bool) {
        loaderMinimumDurationTask?.cancel()
        fade(to: 0, reduceMotion: reduceMotion)
    }

    func resetWebFrontend() {
        overlayState.emptyState = nil
        overlayState.showsNoActiveURL = false
        webViewController = nil
        beginFullScreenLoaderCycle()
        webViewResetID = UUID()
    }

    func handleWebViewController(_ controller: WebViewController) {
        webViewController = controller
        onWebViewController?(controller)
    }

    private func bindObservableChildren() {
        overlayState.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        chrome.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    private func bindOverlayState() {
        overlayState.$isLoading
            .sink { [weak self] isLoading in
                if isLoading {
                    self?.beginFullScreenLoaderCycle()
                }
            }
            .store(in: &cancellables)

        overlayState.$connectionState
            .sink { [weak self] _ in self?.updateFullScreenLoaderVisibility() }
            .store(in: &cancellables)

        overlayState.$emptyState
            .sink { [weak self] _ in self?.updateFullScreenLoaderVisibility() }
            .store(in: &cancellables)
    }

    private func beginFullScreenLoaderCycle() {
        let cycleID = UUID()
        loaderMinimumDurationTask?.cancel()
        isFullScreenLoaderMounted = true
        withAnimation(DesignSystem.Animation.default) {
            isFullScreenLoaderVisible = true
        }
        loaderMinimumDurationElapsed = false
        overlayState.connectionState = .unknown
        loaderCycleID = cycleID
        loaderMinimumDurationTask = Task { @MainActor in
            try? await Task.sleep(for: Constants.minimumLoaderDuration)
            guard !Task.isCancelled, loaderCycleID == cycleID else { return }
            withAnimation(DesignSystem.Animation.default) {
                loaderMinimumDurationElapsed = true
            }
            updateFullScreenLoaderVisibility()
        }
    }

    private func updateFullScreenLoaderVisibility() {
        guard isFullScreenLoaderMounted, loaderMinimumDurationElapsed else { return }

        if overlayState.emptyState != nil {
            withAnimation(DesignSystem.Animation.default) {
                isFullScreenLoaderVisible = true
            }
            return
        }

        guard isFullScreenLoaderVisible, overlayState.connectionState == .connected else { return }

        let finishingCycleID = loaderCycleID
        withAnimation(DesignSystem.Animation.default) {
            isFullScreenLoaderVisible = false
        }

        Task { @MainActor in
            try? await Task.sleep(for: Constants.loaderFadeOutDuration)
            guard loaderCycleID == finishingCycleID, !isFullScreenLoaderVisible else { return }
            isFullScreenLoaderMounted = false
        }
    }
}
