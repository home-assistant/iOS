import Combine
import Foundation
import Shared

/// Shared state of the App Labs native iOS tab bar.
final class NativeTabBarState: ObservableObject {
    static let shared = NativeTabBarState()

    @Published private(set) var isEnabled: Bool
    let moreRequests = PassthroughSubject<Void, Never>()

    private var cancellables = Set<AnyCancellable>()

    init() {
        self.isEnabled = AppLabsFeature.iosNativeTabBar.isEnabled

        Current.appLabs.enabledFeatureIdsPublisher
            .map { AppLabsFeature.iosNativeTabBar.isEnabled(in: $0) }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isEnabled in
                self?.isEnabled = isEnabled
            }
            .store(in: &cancellables)
    }

    /// The frontend's `sidebar/show`: the hamburger with no sidebar of its own to open.
    func requestMore() {
        moreRequests.send()
    }
}
