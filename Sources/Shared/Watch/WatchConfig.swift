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
        public var serverId: String
        public var pipelineId: String

        public init(showAssist: Bool, serverId: String = "", pipelineId: String = "") {
            self.showAssist = showAssist
            self.serverId = serverId
            self.pipelineId = pipelineId
        }
    }

    public static func config() throws -> WatchConfig? {
        try Current.database.read({ db in
            try WatchConfig.fetchOne(db)
        })
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
