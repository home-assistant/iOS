import Combine
import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Whether an on-screen keyboard is up, as opposed to a hardware keyboard driving a focused field.
@MainActor
final class SoftwareKeyboardObserver: ObservableObject {
    static let minimumHeight: CGFloat = 100

    @Published private(set) var isShown = false

    #if !os(macOS)
    private var cancellables = Set<AnyCancellable>()
    #endif

    #if os(macOS)
    /// A Mac has no on-screen keyboard, so there is nothing to observe and `isShown` stays false.
    init() {}
    #else
    /// Keyboard notifications carry the screen the keyboard appears on as their object, which is also the
    /// coordinate space the end frame is expressed in. UIKit posts them on the main actor.
    init(
        notificationCenter: NotificationCenter = .default,
        screenHeight: @escaping (Notification) -> CGFloat? = { notification in
            MainActor.assumeIsolated { (notification.object as? UIScreen)?.bounds.height }
        }
    ) {
        notificationCenter.publisher(for: UIResponder.keyboardWillChangeFrameNotification)
            .map { notification in
                Self.isShown(
                    endFrame: notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                    screenHeight: screenHeight(notification)
                )
            }
            .merge(with: notificationCenter.publisher(for: UIResponder.keyboardWillHideNotification).map { _ in false })
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] isShown in
                self?.isShown = isShown
            }
            .store(in: &cancellables)
    }
    #endif

    static func isShown(endFrame: CGRect?, screenHeight: CGFloat?) -> Bool {
        guard let endFrame, let screenHeight, endFrame.height >= minimumHeight else { return false }
        return endFrame.minY < screenHeight
    }
}
