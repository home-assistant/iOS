import Foundation
@testable import HomeAssistant
import SwiftUI
import Testing

@MainActor
struct ManageStorageViewTests {
    private func makeViewModel() async -> ManageStorageViewModel {
        let viewModel = ManageStorageViewModel(
            paths: .rooted(at: URL(fileURLWithPath: "/tmp/manage-storage-snapshot")),
            isCatalyst: false,
            hasCompletedLegacyStoreMigration: true,
            measurer: ManageStorageSampleMeasurer(),
            cleaner: ManageStorageSampleCleaner()
        )
        await viewModel.load()
        return viewModel
    }

    @Test func testUI() async throws {
        let viewModel = await makeViewModel()

        assertLightDarkSnapshots(
            of: NavigationView { ManageStorageView(viewModel: viewModel) },
            drawHierarchyInKeyWindow: true
        )
    }

    @Test func testUIFilteredToRemovableRows() async throws {
        let viewModel = await makeViewModel()
        viewModel.filter.onlyDeletable = true
        viewModel.sortOrder = .name

        assertLightDarkSnapshots(
            of: NavigationView { ManageStorageView(viewModel: viewModel) },
            drawHierarchyInKeyWindow: true,
            named: "removable"
        )
    }

    @Test func testUIWithNoMatches() async throws {
        let viewModel = await makeViewModel()
        viewModel.filter.searchTerm = "zzzzz-no-such-row"

        assertLightDarkSnapshots(
            of: NavigationView { ManageStorageView(viewModel: viewModel) },
            drawHierarchyInKeyWindow: true,
            named: "no-matches"
        )
    }
}
