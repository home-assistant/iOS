import Foundation
@testable import HomeAssistant
import SwiftUI
import Testing

struct HomeAssistantStandByViewOffsetTests {
    @Test("While loading, the content is pulled to the full-screen centre whatever the safe area cuts off")
    func loadingContentIsCentredOnTheScreen() {
        let insets = EdgeInsets(top: 0, leading: 0, bottom: 34, trailing: 84)
        let offset = HomeAssistantStandByView.contentOffset(
            safeAreaInsets: insets,
            layoutDirection: .leftToRight,
            showsEmptyState: false
        )
        #expect(offset.width == 42)
        #expect(offset.height == 17 + LaunchSplashOverlayView.Constants.splashLogoCenterYOffset)

        let mirrored = EdgeInsets(top: 34, leading: 84, bottom: 0, trailing: 0)
        let mirroredOffset = HomeAssistantStandByView.contentOffset(
            safeAreaInsets: mirrored,
            layoutDirection: .leftToRight,
            showsEmptyState: false
        )
        #expect(mirroredOffset.width == -42)
        #expect(mirroredOffset.height == -17 + LaunchSplashOverlayView.Constants.splashLogoCenterYOffset)
    }

    @Test("In a right-to-left layout the trailing inset sits on the left, so the shift flips")
    func rightToLeftLayout() {
        let insets = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 84)
        let offset = HomeAssistantStandByView.contentOffset(
            safeAreaInsets: insets,
            layoutDirection: .rightToLeft,
            showsEmptyState: false
        )
        #expect(offset.width == -42)
    }

    @Test("The empty state stays inside the safe area")
    func emptyStateKeepsTheSafeArea() {
        let insets = EdgeInsets(top: 59, leading: 0, bottom: 34, trailing: 84)
        let offset = HomeAssistantStandByView.contentOffset(
            safeAreaInsets: insets,
            layoutDirection: .leftToRight,
            showsEmptyState: true
        )
        #expect(offset == .zero)
    }
}
