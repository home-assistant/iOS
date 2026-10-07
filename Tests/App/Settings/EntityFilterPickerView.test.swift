@testable import HomeAssistant
import SFSafeSymbols
import SwiftUI
import Testing

struct EntityFilterPickerViewTests {
    @MainActor
    @Test func testFiltersBar() async throws {
        // Mirrors the filters row shown at the top of the entity picker: each capsule keeps its
        // icon (and title when nothing is selected) so the filtered dimension stays recognisable.
        let view = VStack(alignment: .leading, spacing: 12) {
            EntityFilterPickerView(
                title: "Servers",
                icon: .serverRack,
                pickerItems: [.init(id: "1", title: "Home"), .init(id: "2", title: "Office")],
                selectedItemId: .constant("1")
            )
            EntityFilterPickerView(
                title: "Area",
                icon: .houseFill,
                pickerItems: [.init(id: "", title: "All areas"), .init(id: "kitchen", title: "Kitchen")],
                selectedItemId: .constant(nil)
            )
            EntityFilterPickerView(
                title: "Domain",
                icon: .tag,
                pickerItems: [.init(id: "", title: "All domains"), .init(id: "light", title: "Light")],
                selectedItemId: .constant("light")
            )
            EntityFilterPickerView(
                title: "Group by",
                icon: .listBulletRectangle,
                pickerItems: [
                    .init(id: "area", title: "Group by Area"),
                    .init(id: "domain", title: "Group by Domain"),
                ],
                selectedItemId: .constant("domain")
            )
        }
        .padding()
        assertLightDarkSnapshots(of: view, drawHierarchyInKeyWindow: true)
    }
}
