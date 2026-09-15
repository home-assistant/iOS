import Combine
import Foundation
import Shared

/// Whether the native home is switched on, which the App Labs toggle decides.
///
/// Mirrors ``NativeTabBarState``: one object watching the labs store so every scene sees the same
/// answer, and sees it change without being rebuilt.
final class NativeHomeState: ObservableObject {
    static let shared = NativeHomeState()

    @Published private(set) var isEnabled: Bool

    private var cancellables = Set<AnyCancellable>()

    init() {
        self.isEnabled = AppLabsFeature.nativeHomeDashboard.isEnabled

        Current.appLabs.enabledFeatureIdsPublisher
            .map { AppLabsFeature.nativeHomeDashboard.isEnabled(in: $0) }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isEnabled in
                self?.isEnabled = isEnabled
            }
            .store(in: &cancellables)
    }

    /// Whether the native home belongs over the frontend right now: the feature is on and the
    /// frontend is showing the built-in Overview.
    ///
    /// Covering rather than replacing is deliberate. The web view stays loaded underneath, so a tap
    /// that the native screen hands back — a summary, a panel, a more-info dialog — lands on a
    /// frontend that is already where it was, and the home comes back the moment it returns.
    func covers(path: String?, homePanelPath: String?) -> Bool {
        guard isEnabled, let path, let homePanelPath else {
            return false
        }
        // `/home` itself, and the area subviews under it. Anything deeper into the frontend is the
        // web view's.
        return path == "/\(homePanelPath)" || path.hasPrefix("/\(homePanelPath)/")
    }
}
