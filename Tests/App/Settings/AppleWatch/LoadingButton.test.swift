@testable import HomeAssistant
import SharedTesting
import SwiftUI
import Testing

/// The complication screens' row button: it runs its action, and shows a spinner (and turns
/// itself off) while loading.
@MainActor
struct LoadingButtonTests {
    @Test func runsItsActionUnlessLoading() async {
        var taps = 0
        let driver = await SwiftUIScreenDriver.show(List {
            LoadingButton(title: "Update", isLoading: false) { taps += 1 }
            LoadingButton(title: "Updating", isLoading: true) { taps += 100 }
        })
        defer { driver.close() }
        #expect(driver.rowCount(inSection: 0) == 2)

        await driver.tapRow(IndexPath(item: 0, section: 0))
        #expect(taps == 1)
    }
}
