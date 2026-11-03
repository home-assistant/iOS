import GRDB
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// Lays the import/export screen out over an in-memory database holding some custom widgets, so each
/// category row shows one of its three states (not configured, included, item count).
///
/// `.sharedState`: the test swaps `Current.database`, which the screen reads from `onAppear`.
@Suite(.sharedState)
@MainActor
struct ImportExportConfigurationViewTests {
    @Test func listsEveryCategoryWithItsState() async throws {
        try await SettingsTestDatabase.with({ db in
            try CustomWidget(id: "w1", name: "One", items: []).insert(db)
            try CustomWidget(id: "w2", name: "Two", items: []).insert(db)
        }) { _ in
            let harness = await SettingsScreenHarness.show(ImportExportConfigurationView())
            // The header, every category, the never-exported items and the action buttons.
            await #expect(harness.waitUntil {
                harness.rows.count >= AppConfigurationCategory.allCases.count + 4
            })

            let viewModel = ImportExportConfigurationViewModel()
            viewModel.refreshEntryCounts()
            #expect(viewModel.entryCount(for: .customWidgets) == 2)
            #expect(viewModel.entryCount(for: .macToolbar) == 0)
            #expect(!viewModel.isBusy)
            await harness.close()
        }
    }
}
