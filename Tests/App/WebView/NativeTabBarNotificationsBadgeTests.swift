@testable import HomeAssistant
import SwiftUI
import Testing
import UIKit

@MainActor
struct NativeTabBarNotificationsBadgeTests {
    @Test func formatsTheCountAndStaysSilentWithoutNotifications() {
        #expect(NativeTabBarNotificationsBadge.text(for: 0) == "")
        #expect(NativeTabBarNotificationsBadge.text(for: 3) == "3")
        #expect(!NativeTabBarNotificationsBadge.text(for: 1234).isEmpty)
    }

    @Test func drawsACapsuleOnlyWhenThereAreNotifications() {
        let few = fittingSize(count: 3)
        #expect(few.height == 16)
        #expect(few.width >= few.height)

        let none = fittingSize(count: 0)
        #expect(none.width < few.width)
        #expect(none.height < few.height)

        let many = fittingSize(count: 1234)
        #expect(many.height == few.height)
        #expect(many.width > few.width)
    }

    private func fittingSize(count: Int) -> CGSize {
        let controller = UIHostingController(rootView: NativeTabBarNotificationsBadge(
            count: count,
            color: .red,
            textColor: .white
        ))
        return controller.sizeThatFits(in: CGSize(width: 1000, height: 1000))
    }
}
