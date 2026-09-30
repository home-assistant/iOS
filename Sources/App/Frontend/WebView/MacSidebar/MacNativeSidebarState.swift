import Combine
import Foundation
import Shared
#if os(iOS)
import UIKit
#endif

/// Shared state of the App Labs native macOS sidebar: whether the feature is on and whether the
/// column is currently shown. Driven by the toolbar, the View menu and the frontend's `sidebar/show`.
final class MacNativeSidebarState: ObservableObject {
    static let shared = MacNativeSidebarState()

    @Published private(set) var isEnabled: Bool
    @Published var isVisible: Bool {
        didSet {
            guard isVisible != oldValue else { return }
            Current.settingsStore.macNativeSidebarVisible = isVisible
            #if os(iOS)
            UIMenuSystem.main.setNeedsRebuild()
            #endif
        }
    }

    private var cancellables = Set<AnyCancellable>()

    init() {
        self.isEnabled = AppLabsFeature.macNativeSidebar.isEnabled
        self.isVisible = Current.settingsStore.macNativeSidebarVisible

        Current.appLabs.enabledFeatureIdsPublisher
            .map { AppLabsFeature.macNativeSidebar.isEnabled(in: $0) }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isEnabled in
                self?.isEnabled = isEnabled
                if isEnabled {
                    self?.isVisible = true
                }
                #if os(iOS)
                UIMenuSystem.main.setNeedsRebuild()
                #endif
            }
            .store(in: &cancellables)
    }

    func show() {
        isVisible = true
    }

    func toggle() {
        isVisible.toggle()
    }
}
