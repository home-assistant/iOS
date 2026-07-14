import Foundation
import GRDB

public struct WatchConfig: WatchCodable, FetchableRecord, PersistableRecord {
    public static var watchConfigId: String { "watch-config" }
    public var id = WatchConfig.watchConfigId
    public var assist: Assist = .init(showAssist: true)
    public var items: [MagicItem] = []
    public var layout: WatchLayout?
    /// Epoch (seconds) of the last edit, on either the iPhone or the watch. Used for last-writer /
    /// conflict resolution when the watch is configured offline. Optional so rows created before this
    /// column existed decode as `nil`.
    public var lastModified: Double?

    public init(
        id: String = UUID().uuidString,
        assist: Assist = Assist(showAssist: true),
        items: [MagicItem] = [],
        layout: WatchLayout? = nil,
        lastModified: Double? = nil
    ) {
        self.id = id
        self.assist = assist
        self.items = items
        self.layout = layout
        self.lastModified = lastModified
    }

    public var resolvedLayout: WatchLayout {
        layout ?? .list
    }

    /// Stamp `lastModified` with the current time. Call whenever the config is edited before saving.
    public mutating func stampModified() {
        lastModified = Current.date().timeIntervalSince1970
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
}

public enum WatchLayout: String, Codable, CaseIterable, DatabaseValueConvertible, Equatable {
    case list
    case grid

    public var name: String {
        switch self {
        case .list:
            return L10n.HomeView.Customization.AreasLayout.List.title
        case .grid:
            return L10n.HomeView.Customization.AreasLayout.Grid.title
        }
    }
}

public protocol WatchCodable: Codable {
    func encodeForWatch() throws -> Data
    static func decodeForWatch(_ data: Data) -> Self?
}

public extension WatchCodable {
    /// Encode for a WatchConnectivity transfer. A failure throws so the sender can skip the
    /// transfer (and log why) instead of crashing — a codec problem in a communication path must
    /// never take the app down.
    func encodeForWatch() throws -> Data {
        try PropertyListEncoder().encode(self)
    }

    static func decodeForWatch(_ data: Data) -> Self? {
        do {
            return try PropertyListDecoder().decode(Self.self, from: data)
        } catch {
            Current.Log.error("Failed to decode watch config for watch, error: \(error.localizedDescription)")
            return nil
        }
    }

    /// Throwing variant so callers can surface *why* a decode failed (e.g. to the watch client-event
    /// log) instead of only seeing a `nil`.
    static func decodeForWatchThrowing(_ data: Data) throws -> Self {
        try PropertyListDecoder().decode(Self.self, from: data)
    }
}
