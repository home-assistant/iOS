import Foundation

/// What sits to the right of a heading: a reading, or a button.
public enum HomeHeadingBadgeConfig: Identifiable, Equatable, Sendable {
    /// An entity's state, shown small — the battery of the device this section is about.
    case entity(HomeEntityBadgeConfig)
    /// A button whose presence depends on what the room is doing, like "turn the lights off".
    case button(HomeHeadingButtonBadgeConfig)

    public var id: String {
        switch self {
        case let .entity(config): "entity:\(config.entityId)"
        case let .button(config): "button:\(config.id)"
        }
    }
}
