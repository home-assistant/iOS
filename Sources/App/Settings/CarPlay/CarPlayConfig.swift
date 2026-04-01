import Foundation
import GRDB

public struct CarPlayConfig: Codable, FetchableRecord, PersistableRecord, Equatable {
    public static var carPlayConfigId = "carplay-config"
    public var id = CarPlayConfig.carPlayConfigId
    public var tabs: [CarPlayTab] = [.quickAccess, .areas, .domains, .settings]
    public var quickAccessItems: [MagicItem] = []
    public var quickAccessLayout: CarPlayQuickAccessLayout?

    public init(
        id: String = CarPlayConfig.carPlayConfigId,
        tabs: [CarPlayTab] = [.quickAccess, .areas, .domains, .settings],
        quickAccessItems: [MagicItem] = [],
        quickAccessLayout: CarPlayQuickAccessLayout? = nil
    ) {
        self.id = id
        self.tabs = tabs
        self.quickAccessItems = quickAccessItems
        self.quickAccessLayout = quickAccessLayout
    }

    public var resolvedQuickAccessLayout: CarPlayQuickAccessLayout {
        if let quickAccessLayout {
            return quickAccessLayout
        }

        return quickAccessItems.isEmpty ? .grid : .list
    }

    public static func config() throws -> CarPlayConfig? {
        try Current.database().read({ db in
            try CarPlayConfig.fetchOne(db)
        })
    }
}

public enum CarPlayQuickAccessLayout: String, Codable, CaseIterable, DatabaseValueConvertible, Equatable {
    case grid
    case list

    public var name: String {
        switch self {
        case .grid:
            return L10n.HomeView.Customization.AreasLayout.Grid.title
        case .list:
            return L10n.HomeView.Customization.AreasLayout.List.title
        }
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
