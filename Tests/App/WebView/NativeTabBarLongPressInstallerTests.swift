@testable import HomeAssistant
import Testing
import UIKit

@MainActor
struct NativeTabBarLongPressInstallerTests {
    @Test("A long press on the tab bar opens Customize once per press and never blocks the bar's own gestures")
    func longPressOpensCustomize() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let controller = UITabBarController()
        controller.viewControllers = [UIViewController(), UIViewController()]
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.layoutIfNeeded()

        var presses = 0
        let installer = NativeTabBarLongPressInstaller.InstallerView()
        installer.onLongPress = { presses += 1 }
        installer.installIfNeeded(in: window)
        installer.installIfNeeded(in: window)

        let recognizer = try #require(installer.recognizer)
        #expect(controller.tabBar.gestureRecognizers?.filter { $0 === recognizer }.count == 1)
        #expect(recognizer.minimumPressDuration == NativeTabBarLongPressInstaller.InstallerView.minimumPressDuration)
        #expect(installer.gestureRecognizer(recognizer, shouldRecognizeSimultaneouslyWith: UITapGestureRecognizer()))

        installer.handle(state: .began)
        installer.handle(state: .changed)
        installer.handle(state: .ended)
        installer.handleRecognizer(recognizer)
        #expect(presses == 1)

        let detached = NativeTabBarLongPressInstaller.InstallerView()
        detached.installIfNeeded(in: UIWindow(frame: .zero))
        #expect(detached.recognizer == nil)
    }
}
