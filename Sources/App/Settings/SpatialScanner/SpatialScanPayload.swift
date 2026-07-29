#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation
import RoomPlan
import Shared
import UIKit

struct SpatialScanPayload: Encodable {
    let schemaVersion: Int
    let id: UUID
    let capturedAt: Date
    let source: Source
    let room: CapturedRoom

    struct Source: Encodable {
        let appVersion: String
        let device: String
        let systemVersion: String

        enum CodingKeys: String, CodingKey {
            case appVersion = "app_version"
            case device
            case systemVersion = "system_version"
        }
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case id
        case capturedAt = "captured_at"
        case source
        case room
    }

    init(room: CapturedRoom, id: UUID = UUID(), capturedAt: Date = Current.date()) {
        self.schemaVersion = 1
        self.id = id
        self.capturedAt = capturedAt
        self.source = Source(
            appVersion: HomeAssistantAPI.clientVersionDescription,
            device: UIDevice.current.model,
            systemVersion: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
        )
        self.room = room
    }

    func jsonObject() throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SpatialScannerAPI.Error.invalidPayload
        }
        return object
    }
}
#endif
