import Combine
import Shared

/// Observes the settings that drive system-chrome hiding (full-screen, kiosk hide-status-bar) so
/// `HomeAssistantView` can hide the status bar / home indicator in SwiftUI. `WebViewController` mirrors
/// `resolveStatusBarHidden()` in its `prefersStatusBarHidden` override: SwiftUI defers status-bar
/// appearance to the embedded web view controller, so the UIKit override is what actually takes effect.
@MainActor
final class WebViewChromeState: ObservableObject {
    @Published private(set) var statusBarHidden: Bool
    @Published private(set) var homeIndicatorHidden: Bool

    private var cancellables = Set<AnyCancellable>()

    init() {
        self.statusBarHidden = Self.resolveStatusBarHidden()
        self.homeIndicatorHidden = Current.settingsStore.fullScreen

        Current.kiosk.settingsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: SettingsStore.webViewRelatedSettingDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)
    }

    private func refresh() {
        statusBarHidden = Self.resolveStatusBarHidden()
        homeIndicatorHidden = Current.settingsStore.fullScreen
    }

    static func resolveStatusBarHidden() -> Bool {
        Current.settingsStore.fullScreen
            || (Current.kioskSettings.enabled && Current.kioskSettings.hideStatusBar)
    }
}
