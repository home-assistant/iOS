import Foundation
@testable import HomeAssistant
import SnapshotTesting
import SwiftUI
import Testing
import UIKit

@MainActor
struct ManageStorageViewTests {
    private func makeViewModel() async -> ManageStorageViewModel {
        let viewModel = ManageStorageViewModel(
            paths: .rooted(at: URL(fileURLWithPath: "/tmp/manage-storage-snapshot")),
            isCatalyst: false,
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
            drawHierarchyInKeyWindow: true
        )
    }

    @Test func testUIWithNoMatches() async throws {
        let viewModel = await makeViewModel()
        viewModel.filter.searchTerm = "zzzzz-no-such-row"

        assertLightDarkSnapshots(
            of: NavigationView { ManageStorageView(viewModel: viewModel) },
            drawHierarchyInKeyWindow: true
        )
    }

    // TEMPORARY: attaches CI's renders so the references can be refreshed; removed before merge.
    @Test func harvestRenders() async throws {
        let states: [(String, (ManageStorageViewModel) -> Void)] = [
            ("testUI", { _ in }),
            ("testUIFilteredToRemovableRows", { $0.filter.onlyDeletable = true; $0.sortOrder = .name }),
            ("testUIWithNoMatches", { $0.filter.searchTerm = "zzzzz-no-such-row" }),
        ]
        for (name, configure) in states {
            for style in [UIUserInterfaceStyle.light, .dark] {
                let viewModel = await makeViewModel()
                configure(viewModel)
                let view = AnyView(NavigationView { ManageStorageView(viewModel: viewModel) })
                let image: UIImage = await withCheckedContinuation { continuation in
                    Snapshotting<AnyView, UIImage>.image(
                        drawHierarchyInKeyWindow: true,
                        layout: .device(config: .iPhone13(.portrait)),
                        traits: .init(userInterfaceStyle: style)
                    ).snapshot(view).run { continuation.resume(returning: $0) }
                }
                Attachment.record(image, named: "\(name).\(style == .light ? "light" : "dark").png")
            }
        }
    }
}
