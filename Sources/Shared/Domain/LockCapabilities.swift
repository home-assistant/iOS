import Foundation
import HAKit

/// What a lock entity can do beyond lock/unlock, parsed from its state attributes.
///
/// Mirrors Home Assistant's frontend (`more-info-lock`): the open ("unlatch") action is
/// advertised through the `supported_features` bitmask as `LockEntityFeature.OPEN` (bit 1).
public struct LockCapabilities: Equatable {
    /// `supported_features` bits, as defined by Home Assistant's lock entity model.
    public enum Feature: Int {
        case open = 1
    }

    /// Whether the lock supports `lock.open` — e.g. a latch the lock can pull open.
    public let supportsOpen: Bool

    public init(entity: HAEntity) {
        self.init(attributes: entity.attributes.dictionary)
    }

    public init(attributes: [String: Any]) {
        let features = (attributes["supported_features"] as? Int) ?? 0
        self.supportsOpen = features & Feature.open.rawValue != 0
    }
}
