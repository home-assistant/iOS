import Foundation
import Shared

/// A `MagicItemProviderProtocol` that resolves only `WidgetPreviewSample` items, from memory.
///
/// The real provider loads every entity, area, device and floor of every server out of the
/// database before it can name a single item. Gallery previews render sample items whose names are
/// already known, so they use this instead and never open the database.
final class WidgetPreviewMagicItemProvider: MagicItemProviderProtocol {
    private let infoByServerUniqueId: [String: MagicItem.Info] = Dictionary(
        uniqueKeysWithValues: WidgetPreviewSample.entities.map { ($0.magicItem.serverUniqueId, $0.info) }
    )

    func loadInformation(completion: @escaping ([String: [HAAppEntity]]) -> Void) {
        completion([:])
    }

    func loadInformation() async -> [String: [HAAppEntity]] {
        [:]
    }

    func getInfo(for item: MagicItem) -> MagicItem.Info? {
        infoByServerUniqueId[item.serverUniqueId]
    }

    func getAreaName(for item: MagicItem) -> String? {
        nil
    }
}
