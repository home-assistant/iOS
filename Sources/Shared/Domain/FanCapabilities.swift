import Foundation
import HAKit

/// What a fan entity can do beyond toggling, parsed from its state attributes.
///
/// Home Assistant advertises fan capabilities through the `supported_features` bitmask. The
/// watch uses this to decide whether a fan row opens the controls screen (speed slider) or just
/// toggles.
public struct FanCapabilities: Equatable {
    /// `supported_features` bits, as defined by Home Assistant's fan entity model.
    public enum Feature: Int {
        case setSpeed = 1
    }

    public let supportsSpeedPercentage: Bool
    /// Current speed as 0–100; nil when off or not reported.
    public let speedPercentage: Double?
    /// The fan's speed granularity — e.g. 25 for a fan with four speeds. Defaults to 1.
    public let percentageStep: Double

    /// Whether the fan offers anything beyond toggling.
    public var hasAdjustableControls: Bool {
        supportsSpeedPercentage
    }

    public init(entity: HAEntity) {
        self.init(attributes: entity.attributes.dictionary)
    }

    public init(attributes: [String: Any]) {
        let features = (attributes["supported_features"] as? Int) ?? 0
        self.supportsSpeedPercentage = features & Feature.setSpeed.rawValue != 0
        if let percentage = attributes["percentage"] as? NSNumber {
            self.speedPercentage = percentage.doubleValue
        } else {
            self.speedPercentage = nil
        }
        if let step = attributes["percentage_step"] as? NSNumber, step.doubleValue > 0 {
            self.percentageStep = step.doubleValue
        } else {
            self.percentageStep = 1
        }
    }
}
