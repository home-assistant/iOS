import Foundation
import GRDB

/// Object that represents iOS item that can be displayed in Watch and Widgets and perform different action types
public struct MagicItem: Codable, Equatable {
    public static func == (lhs: MagicItem, rhs: MagicItem) -> Bool {
        lhs.id == rhs.id
    }

    /// Id match it's type Id, e.g. "script.open_gate"
    public let id: String
    public let serverId: String
    public let type: ItemType
    public var customization: Customization?

    /// Server unique ID - e.g. "EB1364-script.open_gate"
    public var serverUniqueId: String {
        "\(serverId)-\(id)"
    }

    /// Domain retrieved from id when item is entity else nil
    public var domain: Domain? {
        if let domainString = id.split(separator: ".").first, let domain = Domain(rawValue: String(domainString)) {
            return domain
        } else {
            return nil
        }
    }

    public init(id: String, serverId: String, type: ItemType, customization: Customization? = .init()) {
        self.id = id
        self.serverId = serverId
        self.type = type
        self.customization = customization
    }

    public enum ItemType: String, Codable {
        case action
        case script
        case scene
        case entity
    }

    public struct Customization: Codable, Equatable {
        public var iconColor: String?
        public var textColor: String?
        public var backgroundColor: String?
        /// If true, execution will request confirmation before running
        public var requiresConfirmation: Bool

        public init(
            iconColor: String? = nil,
            textColor: String? = nil,
            backgroundColor: String? = nil,
            requiresConfirmation: Bool = true
        ) {
            self.iconColor = iconColor
            self.textColor = textColor
            self.backgroundColor = backgroundColor
            self.requiresConfirmation = requiresConfirmation
        }
    }

    public struct Info: WatchCodable, Equatable {
        /// Server unique ID - "\(serverId)-(entityId)"
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

    /// Icon for given magic item type
    public func icon(info: Info) -> MaterialDesignIcons {
        var icon: MaterialDesignIcons
        switch type {
        case .action, .scene:
            icon = MaterialDesignIcons(named: info.iconName, fallback: .scriptTextOutlineIcon)
        case .script, .entity:
            icon = MaterialDesignIcons(
                serversideValueNamed: info.iconName,
                fallback: .dotsGridIcon
            )
        }

        return icon
    }
}

public enum MagicItemError: Error {
    case unknownDomain
}
