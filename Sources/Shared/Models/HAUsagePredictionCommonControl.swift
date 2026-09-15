import Foundation
import HAKit

public struct HAUsagePredictionCommonControl: Codable, HADataDecodable {
    /// [EntityId]
    public let entities: [String]

    public init(data: HAData) throws {
        self.entities = try data.decode("entities")
    }
}
