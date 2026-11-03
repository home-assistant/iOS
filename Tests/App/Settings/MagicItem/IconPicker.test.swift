@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// The icon pickers' triggers, in both styles, and the row each icon is listed with. The searchable
/// lists themselves open in sheets.
@MainActor
struct IconPickerTests {
    @Test func triggersOpenTheirLists() async {
        let driver = await SwiftUIScreenDriver.show(List {
            IconPicker(
                selectedIcon: .constant(.lightbulbIcon),
                selectedColor: .constant(.orange),
                style: .row(title: "Icon")
            )
            IconPicker(selectedIcon: .constant(nil), selectedColor: .constant(.blue))
            IconSearchPicker(selectedIcon: .constant(.thermometerIcon), tintColor: .red, title: "Icon")
        })
        defer { driver.close() }
        #expect(driver.rowCount(inSection: 0) == 3)

        for row in 0 ..< 3 {
            await driver.tapRow(IndexPath(item: row, section: 0))
            await driver.dismissPresented()
        }
    }

    @Test func iconRowsShowTheIconOnceOnScreen() async {
        let driver = await SwiftUIScreenDriver.show(List {
            IconPickerRow(icon: .lightbulbIcon)
            IconPickerRow(icon: .thermometerIcon)
        })
        defer { driver.close() }
        #expect(driver.rowCount(inSection: 0) == 2)
    }
}
