import Foundation
import GRDB

public struct CarPlayConfig: Codable, FetchableRecord, PersistableRecord, Equatable {
    public static var carPlayConfigId = "carplay-config"
    public var id = CarPlayConfig.carPlayConfigId
    public var tabs: [CarPlayTab] = [.quickAccess, .areas, .domains, .settings]
    public var quickAccessItems: [MagicItem] = []

    public init(
        id: String = CarPlayConfig.carPlayConfigId,
        tabs: [CarPlayTab] = [.quickAccess, .areas, .domains, .settings],
        quickAccessItems: [MagicItem] = []
    ) {
        self.tabs = tabs
        self.quickAccessItems = quickAccessItems
    }

    public static func config() throws -> CarPlayConfig? {
        try Current.database.read({ db in
            try CarPlayConfig.fetchOne(db)
        })
    }
}

public enum CarPlayTab: String, Codable, CaseIterable, DatabaseValueConvertible, Equatable {
    case quickAccess
    case areas
    case domains
    case settings

    public var name: String {
        switch self {
        case .quickAccess:
            return L10n.CarPlay.Navigation.Tab.quickAccess
        case .areas:
            return L10n.CarPlay.Navigation.Tab.areas
        case .domains:
            return L10n.CarPlay.Navigation.Tab.domains
        case .settings:
            return L10n.CarPlay.Navigation.Tab.settings
        }
    }
}
