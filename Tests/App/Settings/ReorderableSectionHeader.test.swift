@testable import HomeAssistant
import Shared
import SharedTesting
import SwiftUI
import Testing

@MainActor
struct ReorderableSectionHeaderTests {
    @Test func headerOffersEditWhileResting() {
        assertLightDarkSnapshots(of: header(title: "Items", isEditing: false), drawHierarchyInKeyWindow: true)
    }

    @Test func headerOffersDoneWhileEditing() {
        assertLightDarkSnapshots(of: header(title: "Items", isEditing: true), drawHierarchyInKeyWindow: true)
    }

    /// A section with nothing to title, like a folder's, keeps only the link.
    @Test func headerWithoutATitleKeepsOnlyTheLink() {
        assertLightDarkSnapshots(of: header(title: nil, isEditing: false), drawHierarchyInKeyWindow: true)
    }

    /// Tapping the link is what turns the handles on, and tapping it again turns them off.
    @Test func tappingTheLinkTogglesEditing() {
        var isEditing = false
        let header = ReorderableSectionHeader(
            title: "Items",
            isEditing: Binding(get: { isEditing }, set: { isEditing = $0 })
        )
        header.toggleEditing()
        #expect(isEditing)
        header.toggleEditing()
        #expect(!isEditing)
    }

    private func header(title: String?, isEditing: Bool) -> some View {
        List {
            Section {
                Text(verbatim: "Kitchen light")
            } header: {
                ReorderableSectionHeader(title: title, isEditing: .constant(isEditing))
            }
        }
    }
}
