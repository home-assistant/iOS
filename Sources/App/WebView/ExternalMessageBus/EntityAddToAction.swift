import Foundation
@preconcurrency import Shared

/// Represents an action that allows users to add a Home Assistant entity to various iOS
/// platform features (widgets, shortcuts, etc.) or connected devices (Watch, CarPlay).
///
/// This protocol is used for bidirectional communication between the iOS app and the
/// Home Assistant frontend. The frontend can query available actions, and the user can select
/// which action to perform for a specific entity.
protocol EntityAddToAction: Codable {
    /// The Material Design Icon identifier for this action, used for visual representation in the UI.
    ///
    /// The format must be `mdi:NAME_OF_ASSET`, for example `mdi:car`.
    var mdiIcon: String { get }

    /// Indicates whether this action is currently available for use. The frontend is going to display
    /// this action but it won't be usable.
    ///
    /// Some actions may be disabled based on system limitations or device state.
    var enabled: Bool { get }

    /// Returns the localized display text for this action.
    ///
    /// This text is shown to the user in the action selection UI and should clearly describe
    /// what the action will do.
    func text() -> String

    /// Returns optional additional details or status information about this action.
    ///
    /// This can be used to provide context about why an action might be disabled or other
    /// relevant information.
    func details() -> String?

    /// Returns the action type identifier for serialization
    var actionType: String { get }
}

extension EntityAddToAction {
    var enabled: Bool { true }
    func details() -> String? { nil }
}

/// Concrete action types that can be performed
enum EntityAddToActionType: String, Codable {
    case carPlayQuickAccess
    case watchItem
    case customWidget
}

// MARK: - Action Implementations

/// Action to add an entity to CarPlay quick access
struct CarPlayQuickAccessAction: EntityAddToAction {
    var mdiIcon: String { "mdi:car" }
    var actionType: String { EntityAddToActionType.carPlayQuickAccess.rawValue }

    func text() -> String {
        L10n.WebView.AddTo.Option.CarPlay.title
    }
}

/// Action to add an entity to Watch favorites
struct WatchItemAction: EntityAddToAction {
    var mdiIcon: String { "mdi:watch" }
    var actionType: String { EntityAddToActionType.watchItem.rawValue }

    func text() -> String {
        L10n.WebView.AddTo.Option.AppleWatch.title
    }
}

/// Action to add a custom widget
struct CustomWidgetAction: EntityAddToAction {
    var mdiIcon: String { "mdi:shape" }
    var actionType: String { EntityAddToActionType.customWidget.rawValue }

    func text() -> String {
        L10n.WebView.AddTo.Option.Widget.title
    }
}
// MARK: - External Representation

/// External representation of an action for communication with the frontend
struct ExternalEntityAddToAction: Codable {
    let appPayload: String
    let enabled: Bool
    let name: String
    let details: String?
    let mdiIcon: String

    /// Creates an external representation from an action
    static func from(action: any EntityAddToAction) throws -> ExternalEntityAddToAction {
        // Encode the action to JSON
        let encoder = JSONEncoder()
        let actionData = try encoder.encode(AnyEntityAddToAction(action))

        // Convert to base64 to ensure data integrity when round-tripping through the frontend
        let appPayload = actionData.base64EncodedString()

        return ExternalEntityAddToAction(
            appPayload: appPayload,
            enabled: action.enabled,
            name: action.text(),
            details: action.details(),
            mdiIcon: action.mdiIcon
        )
    }

    /// Decodes an action from the app payload
    static func toAction(from appPayload: String) throws -> any EntityAddToAction {
        guard let data = Data(base64Encoded: appPayload) else {
            throw EntityAddToError.invalidPayload
        }

        let decoder = JSONDecoder()
        let anyAction = try decoder.decode(AnyEntityAddToAction.self, from: data)
        return anyAction.action
    }
}

// MARK: - Type Erasure Helper

/// Type-erased wrapper for EntityAddToAction to enable encoding/decoding
private struct AnyEntityAddToAction: Codable {
    let action: any EntityAddToAction

    init(_ action: any EntityAddToAction) {
        self.action = action
    }

    enum CodingKeys: String, CodingKey {
        case type
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(EntityAddToActionType.self, forKey: .type)

        switch type {
        case .carPlayQuickAccess:
            self.action = try container.decode(CarPlayQuickAccessAction.self, forKey: .data)
        case .watchItem:
            self.action = try container.decode(WatchItemAction.self, forKey: .data)
        case .customWidget:
            self.action = try container.decode(CustomWidgetAction.self, forKey: .data)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        guard let type = EntityAddToActionType(rawValue: action.actionType) else {
            throw EntityAddToError.encodingFailed
        }
        try container.encode(type, forKey: .type)

        switch type {
        case .carPlayQuickAccess:
            if let typed = action as? CarPlayQuickAccessAction {
                try container.encode(typed, forKey: .data)
            } else {
                throw EntityAddToError.encodingFailed
            }
        case .watchItem:
            if let typed = action as? WatchItemAction {
                try container.encode(typed, forKey: .data)
            } else {
                throw EntityAddToError.encodingFailed
            }
        case .customWidget:
            if let typed = action as? CustomWidgetAction {
                try container.encode(typed, forKey: .data)
            } else {
                throw EntityAddToError.encodingFailed
            }
        }
    }
}

enum EntityAddToError: Error {
    case invalidPayload
    case encodingFailed
    case decodingFailed
}

