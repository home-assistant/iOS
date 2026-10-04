@testable import Shared

/// Answers the Quick Access template's item lookups without reading the app's entity cache, so the
/// rows it renders are the ones a test describes.
final class StubCarPlayMagicItemProvider: MagicItemProviderProtocol {
    /// Names returned for items, keyed by `MagicItem.serverUniqueId`. Items missing from it have no
    /// info, which is what an item whose entity the app hasn't cached looks like.
    var namesByServerUniqueId: [String: String] = [:]
    private(set) var loadCount = 0

    func loadInformation(completion: @escaping ([String: [HAAppEntity]]) -> Void) {
        loadCount += 1
        completion([:])
    }

    func loadInformation() async -> [String: [HAAppEntity]] {
        loadCount += 1
        return [:]
    }

    func getInfo(for item: MagicItem) -> MagicItem.Info? {
        guard let name = namesByServerUniqueId[item.serverUniqueId] else { return nil }
        return .init(id: item.serverUniqueId, name: name, iconName: "mdi:lightbulb", customization: item.customization)
    }

    func getAreaName(for item: MagicItem) -> String? {
        nil
    }
}
