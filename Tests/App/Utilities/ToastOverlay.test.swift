@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing
import UIKit

/// Renders the Dynamic Island toast and drives the overlay that hosts it in its own window. The
/// overlay follows `ToastPresenter.shared`, a process-wide singleton, so the suite serializes with
/// other shared-state tests and always hides what it showed.
@MainActor
@Suite(.sharedState)
struct ToastOverlayTests {
    private var appScene: UIWindowScene? {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    }

    private func host(_ view: some View, inScene: Bool) -> UIWindow {
        let window: UIWindow
        if inScene, let appScene {
            window = UIWindow(windowScene: appScene)
        } else {
            window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        }
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        window.rootViewController = UIHostingController(rootView: view)
        window.isHidden = false
        settle(window)
        return window
    }

    private func settle(_ window: UIWindow, turns: Int = 3) {
        for _ in 0 ..< turns {
            window.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
    }

    private func tearDown(_ window: UIWindow) {
        window.isHidden = true
        window.rootViewController = nil
    }

    @available(iOS 18, *)
    @Test func toastViewRendersExpandedCollapsedAndEmpty() {
        for inScene in [false, true] {
            for (toast, expanded) in [(Toast.example1, true), (Toast.example2, false), (nil, false)] {
                for direction in [LayoutDirection.leftToRight, .rightToLeft] {
                    let window = host(
                        ToastView(toast: toast, isExpanded: expanded).environment(\.layoutDirection, direction),
                        inScene: inScene
                    )
                    tearDown(window)
                }
            }
        }
        #expect(Toast.example1.title != Toast.example2.title)
        #expect(Toast.example1.symbol != Toast.example2.symbol)
    }

    @available(iOS 18, *)
    @Test func overlayInstallsItsWindowAndFollowsThePresenter() {
        let presenter = ToastPresenter.shared
        presenter.hideCurrent()
        defer { presenter.hideCurrent() }

        let window = host(Color.clear.toastOverlay(), inScene: true)
        defer { tearDown(window) }

        presenter.show(
            id: "overlay-test",
            symbol: .applewatch,
            symbolForegroundStyle: (.white, .blue),
            title: "Title",
            message: "Message"
        )
        settle(window)
        #expect(presenter.toast?.title == "Title")

        presenter.hide(id: "another-toast")
        #expect(presenter.toast != nil)
        presenter.hide(id: "overlay-test")
        settle(window)
        #expect(presenter.toast == nil)

        // Showing again before the hide delay elapses cancels the pending hide.
        presenter.show(toast: .example1)
        settle(window)
        presenter.hideCurrent()
        settle(window)
        #expect(presenter.toast == nil)
    }

    @available(iOS 18, *)
    @Test func overlayOutsideAWindowSceneStaysInert() {
        let window = host(Color.clear.toastOverlay(), inScene: false)
        defer { tearDown(window) }
        #expect(window.rootViewController != nil)
    }
}
