import Foundation
import HAKit

/// What a cover entity can do beyond toggling, parsed from its state attributes.
///
/// Home Assistant advertises cover capabilities through the `supported_features` bitmask. The
/// watch uses this to decide whether a cover row opens the controls screen (position slider,
/// open/stop/close) or just toggles.
public struct CoverCapabilities: Equatable {
    /// `supported_features` bits, as defined by Home Assistant's cover entity model.
    public enum Feature: Int {
        case open = 1
        case close = 2
        case setPosition = 4
        case stop = 8
    }

    public let supportsOpen: Bool
    public let supportsClose: Bool
    public let supportsStop: Bool
    public let supportsSetPosition: Bool
    /// Current position as 0 (closed) – 100 (open); nil when the cover doesn't report one.
    public let currentPosition: Double?

    /// Whether the cover offers anything beyond toggling. Stop counts: halting a moving cover
    /// midway is impossible from a plain toggle row.
    public var hasAdjustableControls: Bool {
        supportsSetPosition || supportsStop
    }

    public init(entity: HAEntity) {
        self.init(attributes: entity.attributes.dictionary)
    }

    public init(attributes: [String: Any]) {
        let features = (attributes["supported_features"] as? Int) ?? 0
        self.supportsOpen = features & Feature.open.rawValue != 0
        self.supportsClose = features & Feature.close.rawValue != 0
        self.supportsStop = features & Feature.stop.rawValue != 0
        self.supportsSetPosition = features & Feature.setPosition.rawValue != 0
        if let position = attributes["current_position"] as? NSNumber {
            self.currentPosition = position.doubleValue
        } else {
            self.currentPosition = nil
        }
    }
}
