@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// The selector lays every alternate icon out, one section each.
@Suite(.isolatedEnvironment)
struct AppIconSelectorViewTests {
    @Test @MainActor func selectorListsEveryIcon() async {
        let harness = await SettingsScreenHarness.show(AppIconSelectorView(), size: CGSize(width: 390, height: 6000))
        // The explanation, then one section per icon.
        await #expect(harness.waitUntil { (harness.list?.numberOfSections ?? 0) >= AppIcon.allCases.count })
        await harness.close()
    }
}
