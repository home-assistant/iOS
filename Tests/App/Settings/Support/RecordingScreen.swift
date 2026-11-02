import SwiftUI
import UIKit

/// A hosting controller that records what is presented on it instead of letting UIKit present it,
/// so share sheets and document pickers a screen opens from its window's root stay inert.
final class RecordingHostingController<Content: View>: UIHostingController<Content> {
    private(set) var presentedControllers: [UIViewController] = []

    override func present(_ controller: UIViewController, animated: Bool, completion: (() -> Void)? = nil) {
        presentedControllers.append(controller)
        completion?()
    }
}

/// Hosts a SwiftUI view in an off-screen window whose root records presentations (see
/// `RecordingHostingController`), and presses its toolbar buttons.
@MainActor
final class RecordingScreen {
    let window: UIWindow
    let host: RecordingHostingController<AnyView>

    init(_ view: some View, size: CGSize = CGSize(width: 390, height: 1600)) {
        self.host = RecordingHostingController(rootView: AnyView(view))
        self.window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = host
        window.isHidden = false
        host.view.layoutIfNeeded()
    }

    static func show(_ view: some View, size: CGSize = CGSize(width: 390, height: 1600)) async -> RecordingScreen {
        let screen = RecordingScreen(view, size: size)
        await screen.settle()
        return screen
    }

    func close() {
        window.isHidden = true
        window.rootViewController = nil
    }

    /// Lays the screen out and gives the main actor back for a few turns.
    func settle(_ turns: Int = 3) async {
        for _ in 0 ..< turns {
            window.setNeedsLayout()
            window.layoutIfNeeded()
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    /// Polls `condition` while the screen keeps updating, up to `timeout` seconds.
    @discardableResult
    func waitUntil(timeout: TimeInterval = 10, _ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { return false }
            await settle(1)
        }
        return true
    }

    /// The navigation bar buttons of every navigation stack on screen (SwiftUI toolbar items).
    var barButtons: [UIBarButtonItem] {
        var stack: [UIViewController] = [host]
        var items: [UIBarButtonItem] = []
        while let next = stack.popLast() {
            if let navigation = next as? UINavigationController,
               let item = navigation.topViewController?.navigationItem {
                items += (item.rightBarButtonItems ?? []) + (item.leftBarButtonItems ?? [])
                items += (item.trailingItemGroups + item.leadingItemGroups).flatMap(\.barButtonItems)
            }
            stack.append(contentsOf: next.children)
        }
        return items
    }

    /// Presses the toolbar button titled `title` through its target and action, waiting up to
    /// `timeout` for it to appear. Returns whether there was one.
    @discardableResult
    func pressBarButton(_ title: String, timeout: TimeInterval = 5) async -> Bool {
        await waitUntil(timeout: timeout) {
            guard let item = barButtons.first(where: { $0.title == title || $0.accessibilityLabel == title }),
                  let action = item.action else { return false }
            return UIApplication.shared.sendAction(action, to: item.target, from: item, for: nil)
        }
    }

    /// Controllers the screen asked its root to present, of type `T`.
    func presented<T: UIViewController>(_ type: T.Type) -> [T] {
        host.presentedControllers.compactMap { $0 as? T }
    }
}
