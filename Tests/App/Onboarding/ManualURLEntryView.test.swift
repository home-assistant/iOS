@testable import HomeAssistant
import SnapshotTesting
import SwiftUI
import Testing

struct ManualURLEntryViewTests {
    @MainActor @Test func testEmptyStateSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }
        let view = AnyView(
            ManualURLEntryView { _ in
                // Action for testing
            }
            .toolbarVisibility(.hidden, for: .navigationBar)
        )
        assertLightDarkSnapshots(of: view, named: "empty-state")
    }

    @MainActor @Test func testWithTextEntrySnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }
        let view = AnyView(
            ManualURLEntryView(initialURL: "homeassistant.local") { _ in
                // Action for testing
            }
            .toolbarVisibility(.hidden, for: .navigationBar)
        )
        assertLightDarkSnapshots(of: view, named: "with-text-entry")
    }

    @MainActor @Test func testWithHttpSuggestionsSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }
        let view = AnyView(
            ManualURLEntryView(initialURL: "homeassistant.local:8123") { _ in
                // Action for testing
            }
            .toolbarVisibility(.hidden, for: .navigationBar)
        )
        assertLightDarkSnapshots(of: view, named: "with-http-suggestions")
    }
}
