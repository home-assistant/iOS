import Foundation
import HAKit

public struct HAUsagePredictionCommonControl: Codable, HADataDecodable {
    /// The largest `limit` core accepts.
    public static let maximumLimit = 50

    /// [EntityId]
    public let entities: [String]

    public init(data: HAData) throws {
        self.entities = try data.decode("entities")
    }
}
