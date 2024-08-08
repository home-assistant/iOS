import Foundation
import GRDB
import Shared

/// Object that represents iOS item that can be displayed in Watch and Widgets and perform different action types
struct MagicItem: Codable, Equatable {
    static func == (lhs: MagicItem, rhs: MagicItem) -> Bool {
        lhs.id == rhs.id
    }

    let id: String
    let type: WatchItemType

    enum WatchItemType: Codable {
        case action(GenericItem, Customization)
        case script(GenericItem, Customization)
    }

    struct GenericItem: Codable {
        let id: String
        let title: String
        let subtitle: String?
        let iconName: String
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
}

struct WatchConfig: Codable, FetchableRecord, PersistableRecord {
    var id = UUID().uuidString
    var showAssist: Bool = true
    var items: [MagicItem] = []
}
