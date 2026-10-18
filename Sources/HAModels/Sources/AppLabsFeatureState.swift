import Foundation
import GRDB

/// Whether an App Labs (experimental) feature is enabled, keyed by the feature identifier.
public struct AppLabsFeatureState: Codable, FetchableRecord, PersistableRecord, Equatable {
    public var id: String
    public var isEnabled: Bool

    public init(id: String, isEnabled: Bool) {
        self.id = id
        self.isEnabled = isEnabled
    }
}
