@testable import HomeAssistant

import Shared

import SwiftUI
import Testing
import UIKit

/// The Quick Access list of the CarPlay configuration screen.
@MainActor
struct CarPlayConfigurationViewTests {
    /// Two servers can hold the same entity id — two homes, each with a `cover.garage_door`. The
    /// rows are keyed by the item's server unique id so each keeps an identity of its own; sharing
    /// one makes the rows render each other's content.
    @Test func quickAccessRowsKeepOneIdentityPerServerSharingAnEntityId() {
        let previousProvider = Current.magicItemProvider
        Current.magicItemProvider = { CarPlayConfigurationMagicItemProvider() }
        defer { Current.magicItemProvider = previousProvider }

        let viewModel = CarPlayConfigurationViewModel()
        viewModel.addItem(.init(id: "cover.garage_door", serverId: "1", type: .entity))
        viewModel.addItem(.init(id: "cover.garage_door", serverId: "2", type: .entity))

        // Read before rendering: the screen reloads its configuration from the database as it appears.
        let identities = viewModel.config.quickAccessItems.map(\.serverUniqueId)

        let controller = UIHostingController(rootView: CarPlayConfigurationView(viewModel: viewModel))
        controller.view.frame = .init(x: 0, y: 0, width: 390, height: 844)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        #expect(identities == ["1-cover.garage_door", "2-cover.garage_door"])
    }
}

/// Stands in for the database-backed provider so building the screen resolves item names without
/// reading — or migrating — the shared configuration tables.
private final class CarPlayConfigurationMagicItemProvider: MagicItemProviderProtocol {
    func loadInformation(completion: @escaping ([String: [HAAppEntity]]) -> Void) {
        completion([:])
    }

    func loadInformation() async -> [String: [HAAppEntity]] {
        [:]
    }

    func getInfo(for item: MagicItem) -> MagicItem.Info? {
        .init(id: item.serverUniqueId, name: "Garage Door", iconName: "mdi:garage")
    }

    func getAreaName(for item: MagicItem) -> String? {
        nil
    }
}
