import Foundation
import GRDB

public struct WatchConfig: WatchCodable, FetchableRecord, PersistableRecord {
    public var id = UUID().uuidString
    public var showAssist: Bool = true
    public var items: [MagicItem] = []

    public init(id: String = UUID().uuidString, showAssist: Bool = true, items: [MagicItem] = []) {
        self.id = id
        self.showAssist = showAssist
        self.items = items
    }
}

public protocol WatchCodable: Codable {
    func encodeForWatch() -> Data
    static func decodeForWatch(_ data: Data) -> Self
}

public extension WatchCodable {
    func encodeForWatch() -> Data {
        do {
            return try PropertyListEncoder.init().encode(self)
        } catch {
            fatalError("Faield to encode watch config for watch transfer, error: \(error.localizedDescription)")
        }
    }

    static func decodeForWatch(_ data: Data) -> Self {
        do {
            return try PropertyListDecoder.init().decode(Self.self, from: data)
        } catch {
            fatalError("Faield to decode watch config for watch, error: \(error.localizedDescription)")
        }
    }
}
