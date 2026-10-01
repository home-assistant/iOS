#if os(macOS)
import AppKit
import Combine

/// The window the user is working in, published as it changes so menu commands can follow it.
final class MacKeyWindowObserver: ObservableObject {
    static let shared = MacKeyWindowObserver()

    @Published private(set) var window: NSWindow?

    private var cancellables: Set<AnyCancellable> = []

    private init() {
        self.window = NSApp.keyWindow
        for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification] {
            NotificationCenter.default.publisher(for: name)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.window = NSApp.keyWindow
                }
                .store(in: &cancellables)
        }
    }
}
#endif
