import Foundation
@testable import HomeAssistant
import SwiftUI
import Testing

struct SafeAreaCenteringOffsetTests {
    @Test("A trailing inset shifts content right in left-to-right layouts and left in right-to-left ones")
    func horizontal() {
        let insets = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 84)
        #expect(SafeAreaCenteringOffset.horizontal(safeAreaInsets: insets, layoutDirection: .leftToRight) == 42)
        #expect(SafeAreaCenteringOffset.horizontal(safeAreaInsets: insets, layoutDirection: .rightToLeft) == -42)
    }

    @Test("A taller top inset shifts content up by half the difference")
    func vertical() {
        let insets = EdgeInsets(top: 59, leading: 0, bottom: 34, trailing: 0)
        #expect(SafeAreaCenteringOffset.vertical(safeAreaInsets: insets) == -12.5)
    }
}
