@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing
import UIKit

/// Renders the permission request screen with each combination of skip and close buttons, and the
/// Bluetooth variant built on it, and runs the action its skip and close buttons share.
///
/// The buttons are not pressed through the hosted view: SwiftUI builds no accessibility elements in a
/// hosted unit test (no assistive technology is running, so the hosting view reports none), and there
/// is no other public way to tap a SwiftUI button from here.
@MainActor
struct PermissionRequestViewTests {
    private final class Calls {
        var continued = 0
        var dismissed = 0
    }

    private func host(_ view: some View) -> (UIWindow, UIViewController) {
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        return (window, controller)
    }

    private func close(_ window: UIWindow) {
        window.isHidden = true
        window.rootViewController = nil
    }

    private func requestView(skip: Bool, close: Bool, calls: Calls) -> PermissionRequestView {
        PermissionRequestView(
            icon: .bluetoothIcon,
            title: "Bluetooth",
            subtitle: "Find devices nearby",
            reasons: [
                .init(icon: .accessPointIcon, text: "Configure Improv devices"),
                .init(icon: .wifiIcon, text: "Set up Wi-Fi"),
            ],
            showSkipButton: skip,
            showCloseButton: close,
            continueAction: { calls.continued += 1 },
            dismissAction: { calls.dismissed += 1 }
        )
    }

    @Test(arguments: [(false, false), (true, false), (false, true), (true, true)])
    func rendersEachButtonCombination(_ skip: Bool, _ showClose: Bool) {
        let calls = Calls()
        let (window, controller) = host(requestView(skip: skip, close: showClose, calls: calls))
        defer { close(window) }

        #expect(controller.view.bounds.width == 390)
        // Rendering alone runs neither action.
        #expect(calls.continued == 0)
        #expect(calls.dismissed == 0)
    }

    @Test func skippingOrClosingRunsTheDismissActionOnce() {
        let calls = Calls()
        let view = requestView(skip: true, close: true, calls: calls)

        view.dismissTapped()
        #expect(calls.dismissed == 1)
        #expect(calls.continued == 0)

        // Without a dismiss action the buttons only dismiss the screen.
        let withoutAction = PermissionRequestView(
            icon: .bluetoothIcon,
            title: "Bluetooth",
            subtitle: "",
            reasons: [],
            showSkipButton: true,
            showCloseButton: false,
            continueAction: { calls.continued += 1 },
            dismissAction: nil
        )
        withoutAction.dismissTapped()
        #expect(calls.dismissed == 1)
        #expect(calls.continued == 0)
    }

    @Test func theBluetoothScreenRenders() {
        let (window, controller) = host(BluetoothPermissionView())
        defer { close(window) }
        #expect(controller.view.bounds.width == 390)
    }
}
