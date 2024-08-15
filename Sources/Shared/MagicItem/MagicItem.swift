import Foundation
import GRDB

/// Object that represents iOS item that can be displayed in Watch and Widgets and perform different action types
public struct MagicItem: Codable, Equatable {
    public static func == (lhs: MagicItem, rhs: MagicItem) -> Bool {
        lhs.id == rhs.id
    }

    /// Id match it's type Id
    public let id: String
    public let serverId: String
    public let type: WatchItemType
    public var customization: Customization?

    public init(id: String, serverId: String, type: WatchItemType, customization: Customization? = nil) {
        self.id = id
        self.serverId = serverId
        self.type = type
        self.customization = customization
    }

    public enum WatchItemType: String, Codable {
        case action
        case script
    }

    public struct Customization: Codable {
        public let iconColor: String?
        public let textColor: String?
        public let backgroundColor: String?
        /// If true, execution will request confirmation before running
        public let requiresConfirmation: Bool

        public init(
            iconColor: String? = nil,
            textColor: String? = nil,
            backgroundColor: String? = nil,
            requiresConfirmation: Bool = false
        ) {
            self.iconColor = iconColor
            self.textColor = textColor
            self.backgroundColor = backgroundColor
            self.requiresConfirmation = requiresConfirmation
        }
    }

    public struct Info: WatchCodable {
        public let id: String
        public let name: String
        public let iconName: String
        public let customization: Customization?

        public init(id: String, name: String, iconName: String, customization: Customization? = nil) {
            self.id = id
            self.name = name
            self.iconName = iconName
            self.customization = customization
        }
    }
}
