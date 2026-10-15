import Foundation
@testable import HomeAssistant
import Testing
import UIKit

/// Covers the UIKit side of `View.shareSheet(item:)`: the activity controller is presented from the
/// top-most controller of the anchor's window, once per item, and the item is cleared on dismissal.
@Suite(.serialized)
@MainActor
struct ShareSheetPresenterTests {
    private func makeWindow() -> (UIWindow, UIView) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let root = UIViewController()
        window.rootViewController = root
        window.makeKeyAndVisible()
        let anchor = UIView(frame: .zero)
        root.view.addSubview(anchor)
        return (window, anchor)
    }

    private func settle() async throws {
        try await Task.sleep(for: .milliseconds(300))
    }

    @Test func presentsOnceAndClearsOnCompletion() async throws {
        let (window, anchor) = makeWindow()
        defer { window.isHidden = true }
        let coordinator = ShareSheetPresenter.Coordinator()
        let item = ShareWrapper(items: ["hello"])
        var cleared = 0
        var dismissed = 0

        coordinator.present(item, from: anchor, clear: { cleared += 1 }, onDismiss: { dismissed += 1 })
        coordinator.present(item, from: anchor, clear: { cleared += 1 }, onDismiss: { dismissed += 1 })
        try await settle()

        let presented = window.rootViewController?.presentedViewController
        let activity = try #require(presented as? UIActivityViewController)
        #expect(window.rootViewController?.presentedViewController?.presentedViewController == nil)

        activity.completionWithItemsHandler?(nil, false, nil, nil)
        #expect(cleared == 1)
        #expect(dismissed == 1)

        coordinator.present(nil, from: anchor, clear: {}, onDismiss: nil)
        activity.dismiss(animated: false)
        try await settle()
    }

    @Test func presentsFromTheTopMostController() async throws {
        let (window, anchor) = makeWindow()
        defer { window.isHidden = true }
        let sheet = UIViewController()
        window.rootViewController?.present(sheet, animated: false)
        try await settle()

        let coordinator = ShareSheetPresenter.Coordinator()
        coordinator.present(ShareWrapper(items: ["hello"]), from: anchor, clear: {}, onDismiss: nil)
        try await settle()

        #expect(sheet.presentedViewController is UIActivityViewController)
        sheet.presentedViewController?.dismiss(animated: false)
        sheet.dismiss(animated: false)
        try await settle()
    }

    @Test func doesNothingWithoutAWindow() async throws {
        let coordinator = ShareSheetPresenter.Coordinator()
        var cleared = false
        coordinator.present(ShareWrapper(items: ["hello"]), from: UIView(), clear: { cleared = true }, onDismiss: nil)
        try await settle()
        #expect(!cleared)
    }
}
