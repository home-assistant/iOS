import Foundation
@testable import HomeAssistant
import Testing
import UIKit

/// Records what is presented on it instead of letting UIKit do it, so the share presenter can be
/// checked without a real activity sheet coming up.
private final class RecordingViewController: UIViewController {
    private(set) var presentedControllers: [UIViewController] = []

    override func present(_ controller: UIViewController, animated: Bool, completion: (() -> Void)? = nil) {
        presentedControllers.append(controller)
        completion?()
    }
}

/// Covers the UIKit side of `View.shareSheet(item:)`: the activity controller is presented from the
/// top-most controller of the anchor's window, once per item, and the item is cleared on dismissal.
@Suite(.serialized)
@MainActor
struct ShareSheetPresenterTests {
    private func settle() async throws {
        try await Task.sleep(for: .milliseconds(200))
    }

    @Test func presentsTheItemsAndClearsOnCompletion() throws {
        let coordinator = ShareSheetPresenter.Coordinator()
        let presenter = RecordingViewController()
        let anchor = UIView(frame: CGRect(x: 10, y: 20, width: 30, height: 40))
        var cleared = 0
        var dismissed = 0

        coordinator.presentActivity(
            for: ShareWrapper(items: ["hello"]),
            on: presenter,
            anchor: anchor,
            clear: { cleared += 1 },
            onDismiss: { dismissed += 1 }
        )

        let activity = try #require(presenter.presentedControllers.first as? UIActivityViewController)
        #expect(activity.popoverPresentationController?.sourceView === anchor)
        activity.completionWithItemsHandler?(nil, false, nil, nil)
        #expect(cleared == 1)
        #expect(dismissed == 1)
    }

    @Test func presentsOncePerItemFromTheTopMostController() async throws {
        let scene = try #require(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        let root = RecordingViewController()
        window.rootViewController = root
        window.isHidden = false
        defer { window.isHidden = true }
        let anchor = UIView(frame: .zero)
        root.view.addSubview(anchor)

        let coordinator = ShareSheetPresenter.Coordinator()
        let item = ShareWrapper(items: ["hello"])
        coordinator.present(item, from: anchor, clear: {}, onDismiss: nil)
        coordinator.present(item, from: anchor, clear: {}, onDismiss: nil)
        try await settle()
        #expect(root.presentedControllers.count == 1)
        #expect(root.presentedControllers.first is UIActivityViewController)

        coordinator.present(nil, from: anchor, clear: {}, onDismiss: nil)
        coordinator.present(ShareWrapper(items: ["again"]), from: anchor, clear: {}, onDismiss: nil)
        try await settle()
        #expect(root.presentedControllers.count == 2)
    }

    @Test func doesNothingWithoutAWindow() async throws {
        let coordinator = ShareSheetPresenter.Coordinator()
        var cleared = false
        coordinator.present(ShareWrapper(items: ["hello"]), from: UIView(), clear: { cleared = true }, onDismiss: nil)
        try await settle()
        #expect(!cleared)
    }
}
