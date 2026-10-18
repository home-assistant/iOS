import Foundation
@testable import HomeAssistant
import Testing
import UIKit

@MainActor
struct NativeTabBarButtonLocatorTests {
    @Test("A tab is found through its title label and the search-role slot through the trailing control")
    func locatesTabButtons() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let controller = UITabBarController()
        controller.viewControllers = ["Overview", "Map", "Assist"].map { title in
            let child = UIViewController()
            child.tabBarItem = UITabBarItem(title: title, image: nil, tag: 0)
            return child
        }
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.layoutIfNeeded()
        controller.tabBar.layoutIfNeeded()

        let map = try #require(NativeTabBarButtonLocator.frame(ofButtonTitled: "Map", trailing: false, in: window))
        let assist = try #require(NativeTabBarButtonLocator.frame(
            ofButtonTitled: "Assist",
            trailing: false,
            in: window
        ))
        #expect(map.width > 0)
        #expect(assist.minX > map.minX)

        let trailing = try #require(NativeTabBarButtonLocator.frame(
            ofButtonTitled: "Missing",
            trailing: true,
            in: window
        ))
        #expect(trailing.maxX >= assist.maxX)
        #expect(NativeTabBarButtonLocator.frame(ofButtonTitled: "Missing", trailing: false, in: window) == nil)
    }
}
