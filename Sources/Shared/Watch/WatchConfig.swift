import Foundation
import GRDB

public struct WatchConfig: WatchCodable, FetchableRecord, PersistableRecord {
    public static var watchConfigId: String { "watch-config" }
    public var id = WatchConfig.watchConfigId
    public var assist: Assist = .init(showAssist: true)
    public var items: [MagicItem] = []

    public init(
        id: String = UUID().uuidString,
        assist: Assist = Assist(showAssist: true),
        items: [MagicItem] = []
    ) {
        self.id = id
        self.assist = assist
        self.items = items
    }

    public struct Assist: Codable, Equatable {
        public var showAssist: Bool
        public var serverId: String?
        public var pipelineId: String?

        public init(showAssist: Bool, serverId: String? = nil, pipelineId: String? = nil) {
            self.showAssist = showAssist
            self.serverId = serverId
            self.pipelineId = pipelineId
        }
    }

    public static func config() throws -> WatchConfig? {
        try Current.database().read({ db in
            try WatchConfig.fetchOne(db)
        })
    }

    /// Returns all items (including items inside folders) that have `showInSmartStack` enabled.
    public static func smartStackItems() -> [MagicItem] {
        guard let config = try? config() else { return [] }
        return config.allSmartStackItems()
    }

    /// Collects all items (including folder children) with `showInSmartStack` enabled.
    public func allSmartStackItems() -> [MagicItem] {
        var result: [MagicItem] = []
        for item in items {
            if item.customization?.showInSmartStack == true {
                result.append(item)
            }
            if item.type == .folder, let children = item.items {
                for child in children where child.customization?.showInSmartStack == true {
                    result.append(child)
                }
            }
        }
        return result
    }

    /// Returns smart stack items filtered by domain (e.g. `.script`, `.scene`).
    public static func smartStackItems(for domain: Domain) -> [MagicItem] {
        smartStackItems().filter { $0.domain == domain }
    }

    /// Returns smart stack items filtered by item type.
    public static func smartStackItems(for type: MagicItem.ItemType) -> [MagicItem] {
        smartStackItems().filter { $0.type == type }
    }
}

public protocol WatchCodable: Codable {
    func encodeForWatch() -> Data
    static func decodeForWatch(_ data: Data) -> Self?
}

public extension WatchCodable {
    func encodeForWatch() -> Data {
        do {
            return try PropertyListEncoder().encode(self)
        } catch {
            fatalError("Faield to encode watch config for watch transfer, error: \(error.localizedDescription)")
        }
    }

    static func decodeForWatch(_ data: Data) -> Self? {
        do {
            return try PropertyListDecoder().decode(Self.self, from: data)
        } catch {
            Current.Log.error("Failed to decode watch config for watch, error: \(error.localizedDescription)")
            return nil
        }
    }
}
