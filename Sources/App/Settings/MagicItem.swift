import Foundation
import GRDB
import Shared

/// Object that represents iOS item that can be displayed in Watch and Widgets and perform different action types
struct MagicItem: Codable, Equatable {
    static func == (lhs: MagicItem, rhs: MagicItem) -> Bool {
        lhs.id == rhs.id
    }

    /// Id match it's type Id
    let id: String
    let serverId: String?
    let type: WatchItemType
    var customization: Customization?

    init(id: String, serverId: String? = nil, type: WatchItemType, customization: Customization? = nil) {
        self.id = id
        self.serverId = serverId
        self.type = type
        self.customization = customization
    }

    enum WatchItemType: Codable {
        case action
        case script
    }

    struct Customization: Codable {
        let iconColor: String?
        let textColor: String?
        let backgroundColor: String?
        /// If true, execution will request confirmation before running
        let requiresConfirmation: Bool

        init(
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

    struct Info {
        let id: String
        let name: String
        let iconName: String
        let customization: Customization?

        init(id: String, name: String, iconName: String, customization: Customization? = nil) {
            self.id = id
            self.name = name
            self.iconName = iconName
            self.customization = customization
        }
    }
}

struct WatchConfig: Codable, FetchableRecord, PersistableRecord {
    var id = UUID().uuidString
    var showAssist: Bool = true
    var items: [MagicItem] = []
}
